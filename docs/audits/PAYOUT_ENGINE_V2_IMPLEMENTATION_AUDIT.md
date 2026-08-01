# Payout Engine V2 — Implementation Audit

**Audited against:** `docs/architecture/payout-engine-v2.md` (Status: Approved, v2.0, 2026-07-26)
**Audit date:** 2026-07-28
**Method:** Direct inspection of `functions/`, `lib/`, `firestore.rules`, `firestore.indexes.json`. Conclusions are based on actual code (grep/read of every file that touches `payout`, `financialEvents`, `payoutIndex`, `settlement`, `sellerDebts`), not on comments or `docs/architecture/TASK.md` claims. Where a code comment made a claim, it was independently verified against the surrounding code.
**Branch:** `integration/mac-windows-2026-07-22`. Note: `functions/index.js` and `functions/payout/**` currently show as uncommitted working-tree changes (`git status`) — this audit reflects the working tree as it exists on disk right now, not just the last commit.

---

## 1. Executive Summary

The repository has implemented **Milestone 1 only** of what the architecture describes: a real, working, sector-parameterized payout engine (`functions/payout/`), but for **one sector out of five** (Pet Shop), with **neither of the two architecture-mandated collections** (`payoutIndex`, `financialEvents`) created. This matches `docs/architecture/TASK.md`, which explicitly scopes `financialEvents`, `payoutIndex`, Vet/Grooming/Hotel/Taxi, and any new scheduler as "out of scope" for this milestone — so the gap is expected and self-documented, not a surprise regression.

What exists is solid: `functions/payout/payoutEngine.js` is genuinely sector-agnostic (parameterized by `{ db, sector, payableId }`, resolved through `getPayoutSectorAdapter`), contains zero sector-specific branching, and Rule 1 ("business logic reads only from the source document") is honestly followed everywhere it was checked, including client code (`lib/ui/seller/order_card.dart`, `lib/ui/orders/order_detail_page.dart`, `lib/ui/admin/payments/admin_payouts_page.dart`).

The two most consequential gaps are:

1. **No `financialEvents` ledger exists anywhere in the repo.** Every payout transition (`markPayoutReady`, `markPayoutPaid`, `applyRefundToPayout`) completes with zero audit trail. This directly contradicts **Rule 6** ("Every payout transition generates one financial event. No exceptions.") and makes **Rule 5** unenforced by construction (there is nothing to check availability of, so nothing is ever blocked).
2. **A second, dead, competing state machine already exists on the same source documents.** `sellerOrders` checkout code writes a `financial.settlement` object with its own status enum (`SETTLEMENT_STATUS` in `functions/settlement/settlementStatus.js`) alongside the real `payout` object — but the module that's supposed to drive it (`functions/settlement/*`) is entirely `// TODO` stubs, never registered as a scheduled function, and never actually transitions that field. This is scaffolding for what looks like an abandoned or paused parallel design and is a source of future confusion about which field is authoritative.

No `payoutIndex` projection exists; the admin payout page queries the `sellerOrders` source collection directly, which is functionally fine today (no projection to violate) but means the "Admin operates exclusively on `payoutIndex`" rule cannot yet be honored and will require a UI migration later.

---

## 2. Architecture Compliance Table

| Document Section | Status | One-line finding |
|---|---|---|
| Goals — 5 sectors on one engine | 🟡 Partial | Engine is shared/generic; only `petshop` sector registered ([sectorAdapters.js:7-9](../../functions/payout/sectorAdapters.js#L7-L9)) |
| Core Principle 1 — Single Source of Truth | 🟡 Partial | True and honored for `sellerOrders.payout`; no equivalent `.payout` field exists yet on the other 4 sectors' documents |
| Core Principle 2 — Shared Payout Engine | 🟡 Partial | Engine itself is correctly generic; only usable by one sector today |
| Core Principle 3 — Read Projection (`payoutIndex`) | ❌ Missing | Zero references to `payoutIndex` anywhere in the repo |
| Core Principle 4 — Immutable Financial Ledger (`financialEvents`) | ❌ Missing | Zero references to `financialEvents` anywhere in the repo |
| Source of Truth table | 🟡 Partial | Payout/hold/recovery/debt state correctly sourced from documents (petshop only); admin/audit rows have no backing collection |
| Rule 1 (business logic reads source doc only) | ✅ Implemented | Verified in engine and 3 separate UI surfaces |
| Rule 2 (`financialEvents` is history, not state) | ❌ Missing | Not applicable — collection doesn't exist to obey or violate |
| Rule 3 (`payoutIndex` is projection, not state) | ❌ Missing | Not applicable — collection doesn't exist to obey or violate |
| Rule 4 (deleting `payoutIndex` must not break correctness) | ❌ Missing | Untestable — no projection exists |
| Rule 5 (block payouts if `financialEvents` unavailable) | ⚠️ Violates | No such guard exists; `markPayoutReady`/`markPayoutPaid` never check ledger availability |
| Rule 6 (every transition → one financial event) | ⚠️ Violates | All three transition functions complete with no event write |
| Supported State Machine | 🟡 Partial | `pending → ready → paid` (+`hold`, `recovery_required`) implemented; `eligible` and `scheduled` states don't exist anywhere |
| Shared Components | 🟡 Partial | Engine, refund handler, bank validator ✅; scheduler, notifier ❌; validator/calculator/debt-handler exist but not as discrete reusable services |
| Sector Adapter | 🟡 Partial | Adapter shape is real and correctly isolates sector logic; only 1 of 5 adapters registered |
| Refunds | 🟡 Partial | "hold payout" and "create debt" implemented; "reduce payout" and "recover debt" are not implemented anywhere |
| Debts | 🟡 Partial | `sellerDebts` is a genuine independent collection (compliant); no recovery workflow, no UI, petshop-only |
| Weekly Scheduler | ❌ Missing | `weeklySettlementScheduler` exists but its two dependencies are `// TODO` stubs and it is never registered as a Cloud Function |
| Admin (operates exclusively on `payoutIndex`) | ⚠️ Violates (by necessity) | Admin page queries `sellerOrders` directly since `payoutIndex` doesn't exist |
| Business Dashboard | ✅ Implemented | Reads `payout` straight from source documents, exactly as specified |
| Financial Events (field list) | ❌ Missing | No event type exists to check field completeness against |
| Non-Goals (no Event Sourcing/ledger/ERP accidentally built) | ✅ Implemented | Nothing in the repo resembles double-entry accounting or ERP |
| Design Invariants 1–7 | 🟡 Partial | 1, 7 mostly true (for petshop); 2, 3 vacuously true (nothing depends on non-existent projections/events, but only because they don't exist); 4, 5, 6 unverifiable/false |

---

## 3. Completed Items

### 3.1 Single shared, sector-parameterized payout engine core
- **File/function:** `functions/payout/payoutEngine.js` — `markPayoutReady()`, `markPayoutPaid()`, `applyRefundToPayout()`, `assertPayoutNotBlocked()`, `assertBankAccountValid()`
- **Evidence:** Every function takes `{ db, sector, payableId, ... }` and resolves the collection/business-id/debt-collection through `getPayoutSectorAdapter(sector)` ([sectorAdapters.js:11-19](../../functions/payout/sectorAdapters.js#L11-L19)). No sector name is hardcoded anywhere inside `payoutEngine.js`.
- **Why it counts:** Matches "Core Principle 2 — Shared Payout Engine": "The engine is parameterized by: collection, document, sector configuration... The engine never contains sector-specific branching" (Sector Adapter section). Confirmed no `if (sector === "petshop")`-style branch exists inside the engine file itself.

### 3.2 Rule 1 — business logic reads only from the source document
- **Files/functions:**
  - `functions/payout/payoutEngine.js` — all reads are `transaction.get(recordRef)` against the source collection.
  - `lib/ui/seller/order_card.dart:247-254` — `data['payout']` read directly from the `sellerOrders` document stream.
  - `lib/ui/orders/order_detail_page.dart:971-979` — same pattern.
  - `lib/ui/admin/payments/admin_payouts_page.dart:33-38` — `FirebaseFirestore.instance.collection("sellerOrders").where("payout.status", ...)`.
- **Evidence:** No file in the repo reads a `payoutIndex` or `financialEvents` collection to make a business decision (confirmed by repo-wide grep returning zero hits for both terms).
- **Why it counts:** Directly satisfies Rule 1 and Design Invariant 2.

### 3.3 Sector Adapter isolation for the one implemented sector
- **File/function:** `functions/payout/adapters/petshopPayoutAdapter.js` — `assertNoBlockingEvents()`, `getBusinessId()`, `getRecoverySellerUid()`
- **Evidence:** The one genuinely marketplace-specific rule (an unresolved `order_returns` document blocks payout approval) lives entirely inside the adapter, not the engine. The engine only knows "call `adapter.assertNoBlockingEvents` if the adapter defines one" (`payoutEngine.js:158-165`).
- **Why it counts:** Matches "Sector Adapter" section: "The engine never contains sector-specific branching."

### 3.4 Shared bank account validator
- **File/function:** `functions/payout/payoutEngine.js:103-126` — `assertBankAccountValid()`
- **Evidence:** Takes a resolved `businessId` (not a sellerOrder-shaped object), reads `businesses/{businessId}.payment`, validates a Turkish IBAN format. Per `docs/architecture/TASK.md:120`, this same helper is also used by `updateBusinessBankAccount`.
- **Why it counts:** One of the eight "Shared Components" the architecture requires ("bank account validator").

### 3.5 Refund handler — hold + debt-on-refund-after-payout
- **File/function:** `functions/payout/payoutEngine.js:252-411` — `applyRefundToPayout()`; wired from `functions/index.js:13630-13645` (`applyRefundToSellerPayout`) and called from the return/refund flow at `functions/index.js:21410-21421`.
- **Evidence:** Correctly implements two of the four "Refunds" financial consequences: `pending/ready → hold` (line 388-404) and `paid/recovery_required → recovery_required` + a deterministic `sellerDebts/{refundEventId}` debt record (line 308-368, using `refundEventId` as the doc ID so a refund can only ever create one debt record — idempotent by construction).
- **Why it counts:** "These actions are performed through one shared refund pipeline" — there is exactly one call path, not a duplicated one per sector (moot today since only one sector exists, but the design is correct).

### 3.6 Debts as an independent, non-projection entity
- **File/function:** `functions/payout/payoutEngine.js:271, 311-330` — `db.collection(adapter.debtCollection).doc(refundEventId)`, i.e. `sellerDebts`.
- **Evidence:** `sellerDebts` is written directly, is queryable independently of `sellerOrders`, and is never derived/rebuilt from another collection.
- **Why it counts:** "Debts" section: "Debt records are independent financial entities. They are not projections."

### 3.7 Business Dashboard reads source documents directly
- **Files:** `lib/ui/seller/order_card.dart`, `lib/ui/orders/order_detail_page.dart`
- **Evidence:** Both read `data['payout']` and `data['financial']` directly off the `sellerOrders` document snapshot they already hold — no separate reporting collection involved.
- **Why it counts:** Matches "Business Dashboard" section verbatim: "Business users read current payout information directly from their source documents."

---

## 4. Partially Completed Items

### 4.1 Goals — 5 sectors, 1 implemented
- **File/function:** `functions/payout/sectorAdapters.js:7-9` — `PAYOUT_SECTOR_ADAPTERS = { petshop: petshopPayoutAdapter }`
- **Evidence:** Grep for `vet_appointments|groomy_appointments|hotel_bookings|pet_taxi_bookings` combined with `payout` across `functions/` and `lib/` returns **zero matches**. Those four collections get a `financial` object (commission breakdown) written via `calculateAppointmentFinancial()` (`functions/commission/paymentFinancialSnapshot.js:23-56`, called from `functions/index.js:14451`) but **no `.payout` sub-object at all** — no status, no amount, no ready/paid workflow.
- **Explanation:** The architecture requires "Veterinary, Grooming, Pet Hotel, Pet Taxi, Pet Shop... using one shared payout engine." Only Pet Shop has any payout tracking today; the other four sectors have commission math but nothing downstream of it.

### 4.2 Supported State Machine
- **File/function:** `functions/payout/payoutEngine.js` (status values used: `"pending"`, `"ready"`, `"paid"`, `"hold"`, `"recovery_required"`); initial value set at `functions/index.js:13071` (`status: "payment_pending"`)
- **Evidence:** Grep for the literal strings `"eligible"` and `"scheduled"` as payout-status values across `functions/index.js` and `functions/payout/*.js` returns zero matches.
- **Explanation:** The architecture's state machine is `pending → eligible → scheduled → ready → paid`. The implementation has `payment_pending → pending → ready → paid` — it skips `eligible` and `scheduled` entirely. There is no eligibility computation and no payout-date scheduling step; an admin manually flips `pending → ready → paid` via the two `onCall` functions. The two side-states (`hold`, `recovery_required`) are implemented correctly.

### 4.3 Sector Adapter — shape exists, coverage doesn't
- **File/function:** `functions/payout/adapters/petshopPayoutAdapter.js:72-79`
- **Evidence:** The adapter object has `{ sector, collection, debtCollection, getBusinessId, getRecoverySellerUid, assertNoBlockingEvents }`. The architecture's example adapter config additionally lists "anchor timestamp" and "payout eligibility rules" — neither field exists in this adapter, consistent with there being no `eligible`/`scheduled` states or scheduler to consume them yet.
- **Explanation:** The mechanism (a registry + adapter interface) is architecturally correct and extensible; it is simply incomplete relative to both the sector count and the field set an adapter will eventually need.

### 4.4 Refunds — two of four financial consequences implemented
- **File/function:** `functions/payout/payoutEngine.js:252-411` — `applyRefundToPayout()`
- **Evidence:** Implemented: `hold payout` (pending/ready/unknown → `hold`), `create debt` (paid/recovery_required → `sellerDebts` record). Not implemented: `reduce payout` — there is no code path that decrements `payout.amount` for a partial refund on a not-yet-paid order; it always goes to a binary `hold`, regardless of refund size. `recover debt` — see 4.5.
- **Explanation:** Architecture lists all four ("hold payout, reduce payout, create debt, recover debt") as consequences the shared refund pipeline should support. Two exist; two don't.

### 4.5 Debts — created but never resolved
- **File/function:** `functions/payout/payoutEngine.js:311-330` (creation); no corresponding update function found anywhere.
- **Evidence:** `sellerDebts` documents are written with `recovered: false, recoveredAmount: 0` (line 327-328) and never touched again — grep for `recoveredAmount|markDebtRecovered|debtRecovery` outside that one write site returns nothing. Grep for `sellerDebts` in `lib/**/*.dart` returns **zero results** — there is no admin or business UI that even lists debts.
- **Explanation:** The field names (`recovered`, `recoveredAmount`) show recovery was designed for, but per `docs/architecture/TASK.md:130` the actual recovery mechanism is explicitly deferred ("not part of the recovery logic itself (which remains manual / a later phase)"). Today a seller debt, once created, is permanently invisible and unresolvable through the product.

### 4.6 Shared Components — some are real services, some are inline logic, some don't exist
| Component | Status | Evidence |
|---|---|---|
| payout engine | ✅ | `functions/payout/payoutEngine.js` |
| payout scheduler | ❌ | See §5.2 |
| payout validator | 🟡 | `assertPayoutNotBlocked`/`assertBankAccountValid` exist but are inline functions inside `payoutEngine.js`, not a separable "validator" component |
| payout calculator | 🟡 | Commission/amount math lives in `functions/commission/` (`commissionEngine.js`, `paymentFinancialSnapshot.js`), a sibling module, not part of `functions/payout/` — works, but isn't the payout engine's own component |
| refund handler | ✅ | `applyRefundToPayout` |
| debt handler | 🟡 | Debt *creation* only (§4.5); no handler for recovery |
| payout notifier | ❌ | See §5.3 |
| bank account validator | ✅ | `assertBankAccountValid` |

### 4.7 Admin — forced to read the source document instead of a projection
- **File/function:** `lib/ui/admin/payments/admin_payouts_page.dart:33-38`
- **Evidence:** `_queryForStatus()` runs `FirebaseFirestore.instance.collection("sellerOrders").where("payout.status", isEqualTo: status)` directly against the source collection.
- **Explanation:** This is functionally correct today (there is no `payoutIndex` to read instead) but is not what the architecture specifies long-term ("The admin system operates exclusively on `payoutIndex`"). It is listed here rather than in Architecture Violations because there is no projection being bypassed — it simply doesn't exist yet. This page will need a follow-up migration once `payoutIndex` is built. See §7 for the "Admin" row in the violations discussion for why it's flagged there too.

---

## 5. Missing Items

### 5.1 `payoutIndex` (Read Projection)
- **Evidence:** Repo-wide, case-insensitive grep for `payoutIndex` across `functions/`, `lib/`, `firestore.rules`, and `firestore.indexes.json` returns **zero matches**.
- **Explanation:** Core Principle 3 requires a rebuildable, disposable, eventually-consistent read projection for "Admin dashboard, Reporting, Excel export, Weekly payout batches, BI." None of this exists. Every consumer that would read it (admin payout page) reads the source collection directly instead (§4.7).

### 5.2 Weekly Scheduler
- **Files:** `functions/settlement/weeklySettlementScheduler.js`, `functions/settlement/settlementBatchBuilder.js`, `functions/settlement/settlementBatchExecutor.js`
- **Evidence:**
  ```js
  // settlementBatchBuilder.js
  async function buildSettlementBatch() {
      // TODO
      return [];
  }
  ```
  ```js
  // settlementBatchExecutor.js
  async function executeSettlementBatch(batch) {
      // TODO
  }
  ```
  Additionally, `weeklySettlementScheduler` (the only function that calls both) is **never registered** as a Cloud Function — grep for `weeklySettlementScheduler` or any `onSchedule` registration referencing `./settlement` in `functions/index.js` returns nothing; the only `onSchedule` exports present (`cleanupExpiredEmailOtps`, `playdateReminderScheduler`, `expireAwaitingAppointmentPayments`, `checkMarketplaceAccountability`, etc. — `functions/index.js:7988-22359`) are unrelated to payout/settlement.
- **Explanation:** The architecture's "Weekly Scheduler" section requires one scheduler, parameterized by the sector adapter, responsible for "detect eligibility, calculate payout date, prepare payout batch." What exists is an unwired, stubbed skeleton that produces an empty batch and executes nothing, and would not even run in production since it has no trigger. This is scaffolding, not an implementation.

### 5.3 Payout Notifier
- **File/function:** `functions/settlement/settlementNotifier.js`
- **Evidence:**
  ```js
  async function notifyBusinessPayout() {
      // TODO
  }
  ```
  Grep for `notifyBusinessPayout` outside its own file/export returns no call sites.
- **Explanation:** One of the eight required "Shared Components." Entirely unimplemented and uncalled.

### 5.4 `financialEvents` (Immutable Financial Ledger)
- **Evidence:** Repo-wide grep for `financialEvents` (and snake_case `financial_events`) across `functions/`, `lib/`, `firestore.rules`, `firestore.indexes.json` returns **zero matches**.
- **Explanation:** Core Principle 4 requires every financial state transition to create one immutable event in this collection, for audit/accounting/investigations/tax/reconciliation. It does not exist. See §6 for the resulting rule violations.

### 5.5 Financial Events field schema
- **Explanation:** Since no event type exists, the field list the architecture prescribes (event type, source collection/document, sector, business, actor, previous/new state, amount, currency, timestamps, reason, metadata) cannot be evaluated — there is nothing to check it against. Flagged as Missing rather than N/A because it is a direct architectural requirement with zero implementation.

### 5.6 `eligible` and `scheduled` payout states
- Already detailed in §4.2 — listed again here because they are not partially present in any form (no field, no constant, no comment referencing them as planned), unlike, say, the notifier which at least has a named stub.

---

## 6. Architecture Violations

### 6.1 Rule 5 — payouts are never blocked by ledger unavailability
- **File/function:** `functions/payout/payoutEngine.js` — `markPayoutReady()` (line 128-190), `markPayoutPaid()` (line 192-250)
- **Evidence:** Neither function contains any check against a `financialEvents` collection, a health check, or any other ledger-availability gate. Both proceed straight from precondition checks (status, blocking events, bank account) to the Firestore write.
- **Explanation:** Rule 5 states: "If `financialEvents` is unavailable, new payouts must still be blocked until event logging is restored. Financial events are mandatory for auditing." Today there is no ledger at all, and therefore no possible way for it to be "unavailable" in a way the system detects — it is unconditionally treated as available (i.e., irrelevant). This is a violation in effect: the invariant the rule protects (no payout without an audit trail) is currently false for every payout ever marked ready or paid.
- **Verdict:** ⚠️ Violates (by omission — the rule is not merely unimplemented, it is actively contradicted by every successful payout transition today).

### 6.2 Rule 6 — no financial event is ever generated
- **File/function:** `functions/payout/payoutEngine.js` — `markPayoutReady()`, `markPayoutPaid()`, `applyRefundToPayout()`
- **Evidence:** All three functions end their Firestore transaction with only a `transaction.set(recordRef, {...}, {merge: true})` against the source document (and, in the refund case, an additional `transaction.set(debtRef, ...)`). None of them write to any events collection.
- **Explanation:** Rule 6 is unconditional: "Every payout transition generates one financial event. No exceptions." Three transition types exist in the code today (ready, paid, refund-consequence) and none of them produce an event.
- **Verdict:** ⚠️ Violates.

### 6.3 Dead, competing state machine bolted onto the source document
- **File/function:** `functions/index.js:13032-13066` (write site), `functions/settlement/settlementStatus.js:1-19` (`SETTLEMENT_STATUS` enum), `functions/settlement/settlementEngine.js:1-37` (`isEligibleForSettlement`)
- **Evidence:** At order creation, `functions/index.js` writes both the real `payout` object (line 13070-13080) **and** a `financial.settlement` object (line 13056-13065) with its own status field seeded to `"payment_pending"`, alongside a fully separate 9-value enum (`AWAITING_INVOICE`, `INVOICE_UPLOADED`, ..., `DISPUTED`) that is imported into `functions/index.js` (`const { SETTLEMENT_STATUS, isEligibleForSettlement } = require("./settlement");` — line 27-30) but **never referenced again** anywhere in the 25,000+ line file (confirmed by grep: the only other hit for `SETTLEMENT_STATUS` in the entire codebase is inside `functions/settlement/` itself). `isEligibleForSettlement()` is likewise imported but never called.
- **Explanation:** Core Principle 1 states "No other collection is allowed to become authoritative" and Core Principle 2 states "No sector-specific payout implementations should exist." While `financial.settlement` lives inside the same document (not a separate collection, so it's not a literal Principle 1 violation), it is a second, unfinished payout-adjacent state machine sitting next to the real one on every `sellerOrders` document, driven by code (`functions/lifecycle/*`) that is itself all `// TODO` stubs (`markServiceCompleted`, `updateSettlementEligibility` — both empty function bodies). This creates exactly the ambiguity the architecture is designed to prevent: a future engineer reading a `sellerOrders` document sees two status-shaped fields (`payout.status` and `financial.settlement.status`) and has no way to know from the document alone which one is real.
- **Verdict:** ⚠️ Violates the spirit of Core Principles 1 and 2, even though it doesn't violate their literal text (no new collection was created). Recommend treating as legacy/dead code — see §7.

### 6.4 "Admin operates exclusively on `payoutIndex`"
- **File/function:** `lib/ui/admin/payments/admin_payouts_page.dart:33-38`
- **Evidence:** Direct `sellerOrders` collection query, as shown in §4.7.
- **Explanation:** Listed here as well as in §4 because it is a literal, checkable rule in the "Admin" section ("The admin system operates exclusively on `payoutIndex`") that is currently not true. It is a soft violation in the sense that it's the *only* option available today (nothing else exists to query), but it means the moment `payoutIndex` is introduced, this file becomes the concrete migration target, not an already-compliant consumer.
- **Verdict:** ⚠️ Violates the letter of the rule; not a "regression" since there was never a projection to use instead.

---

## 7. Legacy Code That Should Be Migrated

1. **`functions/settlement/` (entire module)** — `settlementStatus.js`, `settlementEngine.js`, `settlementBatchBuilder.js`, `settlementBatchExecutor.js`, `settlementBatchRepository.js`, `settlementNotifier.js`, `weeklySettlementScheduler.js`. Every function beyond the trivial `isEligibleForSettlement`/`SETTLEMENT_STATUS` pair is an unimplemented `// TODO` stub, and the module is not wired to any Cloud Function trigger. Recommendation: either (a) delete it and re-derive a scheduler from scratch as part of the payout-engine milestone that actually builds the Weekly Scheduler, reusing only the `SETTLEMENT_STATUS` naming/state ideas if still relevant, or (b) if this was meant to become the vet/groomy/hotel/taxi settlement mechanism, finish it under the `functions/payout/` sector-adapter pattern instead of as a parallel bespoke module — but not both this and the payout engine.

2. **`functions/lifecycle/` (entire module)** — `lifecycleEngine.js`, `serviceCompletion.js`, `settlementUpdater.js`. `markServiceCompleted()` and `updateSettlementEligibility()` are both empty function bodies with only comments describing intended behavior (`// save completedAt`, `// evaluate settlement`). `updateSettlementEligibility` imports `isEligibleForSettlement` from `../settlement` but never calls it. Same recommendation as above — this is scaffolding for the same abandoned/paused settlement design.

3. **`financial.settlement` object written in `functions/index.js:13056-13065`** — dead data being persisted onto every new `sellerOrders` document for no consumer. Either remove the write (since nothing reads it) or wire it up as part of a deliberate, scoped follow-on milestone. Leaving it as-is risks a future engineer mistaking it for the live payout state machine.

4. **Dead imports in `functions/index.js:27-30`** — `SETTLEMENT_STATUS` and `isEligibleForSettlement` are imported but never used anywhere in the file. Should be removed once the decision on items 1–3 is made (don't remove silently without resolving what the settlement module's fate is, since the import may be a breadcrumb of unfinished work rather than pure dead code).

5. **Known limitation already self-documented in `docs/architecture/TASK.md:159`**: `assertBankAccountValid`'s error message ("This seller order has no associated business...") is Pet-Shop-specific wording baked into now-generic code. Flagged as a real migration item for whenever a second sector is onboarded — a vet clinic or groomer should not see marketplace/order-shaped copy.

6. **`sellerDebts` field names** (`sellerOrderId`, `returnId` — `functions/payout/payoutEngine.js:317-318`) are Pet-Shop-specific names on what is now a sector-generic write path. Also self-documented as deferred in `docs/architecture/TASK.md:148,160`. Should be generalized (e.g. `payableId`, `refundEventId`) when the second sector is onboarded, since it's a Firestore schema change best batched with that work rather than done twice.

7. **`lib/ui/admin/payments/payout_card.dart`** is an empty file (a single blank line). Either dead/never-finished UI or an accidental artifact — worth confirming with whoever added it before the next payout UI change touches this directory, so it isn't mistaken for a real, in-use widget.

---

## 8. Recommended Implementation Order

**P0 — Close the audit-trail gap on what already exists (petshop payouts are live in production today with zero durable audit trail)**
1. Introduce the `financialEvents` collection and have `markPayoutReady`, `markPayoutPaid`, and `applyRefundToPayout` each write exactly one event inside the same Firestore transaction as their state write (satisfies Rule 6, and makes Rule 5 checkable for the first time).
2. Add the Rule 5 guard (block new payout transitions if the event write cannot be verified/completed) now that there's an event system to check against.
3. Resolve the dead `financial.settlement` / `functions/settlement/` / `functions/lifecycle/` scaffolding (§7, items 1–4) — decide keep-and-finish vs. delete before it's built on top of by accident.

**P1 — Build the projection and finish the state machine for the existing sector**
4. Build `payoutIndex` as a genuinely rebuildable projection (e.g. driven off `financialEvents` or Firestore triggers on `sellerOrders`), then migrate `admin_payouts_page.dart` off its direct `sellerOrders` query onto it (closes §6.4/§4.7).
5. Add the missing `eligible` and `scheduled` states plus real eligibility/date-calculation logic, replacing today's manual-only `pending → ready` admin action.
6. Implement the Weekly Scheduler for real (eligibility detection, payout-date calculation, batch prep), parameterized through the sector adapter as the architecture specifies, replacing the stubbed `functions/settlement/weeklySettlementScheduler.js`.
7. Implement `reduce payout` and `recover debt` in the refund/debt pipeline, plus a minimal admin surface for `sellerDebts` (today it's write-only and invisible).
8. Implement the payout notifier (`notifyBusinessPayout` equivalent) so businesses are told when their payout is ready/paid.

**P2 — Onboard the remaining sectors**
9. Add `.payout` initialization to Vet/Grooming/Hotel/Taxi documents at their payment-confirmation step (mirroring what `finalizeIsbankPaidOrder`/`createCheckoutSession` do for `sellerOrders` today — per `docs/architecture/TASK.md:161-162`, this was explicitly never touched in Milestone 1).
10. Register one sector adapter per remaining sector (Vet, Grooming, Pet Hotel, Pet Taxi) in `sectorAdapters.js`, each supplying its own `collection`, `debtCollection`/anchor timestamp/eligibility-rule fields, and any sector-specific blocking-events hook — without adding branching to `payoutEngine.js` itself.
11. Add each sector's own thin `onCall` entry points (mirroring `markSellerPayoutReady`/`markSellerPayoutPaid`) per the architecture's Sector Adapter section, reusing the same shared engine.

**P3 — Hygiene / naming generalization (safe to batch with P2 since both are schema changes)**
12. Generalize `sellerDebts` field names (`sellerOrderId`→`payableId`, `returnId`→`refundEventId`) and make `assertBankAccountValid`'s error copy adapter-configurable, both already flagged as known limitations in `docs/architecture/TASK.md`.
13. Remove or repurpose `lib/ui/admin/payments/payout_card.dart` once its status is confirmed.
