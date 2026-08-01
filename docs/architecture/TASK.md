# Milestone 1
## Generalize Existing Pet Shop Payout Engine

Status: [x] Completed

Goal

Extract the existing Pet Shop payout engine into a reusable platform engine without changing any runtime behaviour.

This milestone is a pure refactor.

No new features.

No UI changes.

Pet Shop must continue to behave exactly as before.

---

## Tasks

### 1. Audit current payout flow

- [x] Identify every entry point into the payout system.
- [x] Identify every callable, scheduled function and helper involved.
- [x] Verify current payout lifecycle.
- [x] Document dependencies inside the milestone notes.

---

### 2. Generalize payout engine

- [x] Replace sellerOrders-specific assumptions with a generic payable record abstraction.
- [x] Introduce a sector adapter configuration.
- [x] Remove hardcoded sellerOrders references where possible.
- [x] Keep all existing behaviour identical.

---

### 3. Generalize payout operations

Convert existing operations into reusable platform services.

- [x] markSellerPayoutReady()
- [x] markSellerPayoutPaid()
- [x] applyRefundToSellerPayout()
- [x] payout validation
- [x] payout state transitions

These should become sector-independent while preserving Pet Shop behaviour.

---

### 4. Shared configuration

- [x] Create sector adapter structure.
- [x] Register Pet Shop as the first adapter.
- [x] No additional sectors yet.

---

### 5. Backwards compatibility

- [x] Existing Cloud Functions signatures remain compatible.
- [x] Existing Firestore schema remains compatible.
- [x] Existing documents require no migration.
- [x] Existing Admin pages continue to work.

---

### 6. Tests

- [x] Existing payout scenarios still pass.
- [x] Existing refund scenarios still pass.
- [x] Existing seller debt scenarios still pass.
- [x] Emulator tests pass.
- [x] No regression found.

---

## Out of Scope

Do NOT implement:

- Vet
- Grooming
- Hotel
- Taxi
- payoutIndex
- financialEvents
- New schedulers
- UI changes
- Firestore schema changes

Those belong to later milestones.

---

## Definition of Done

This milestone is complete only if:

- Pet Shop behaves exactly as before.
- No user-visible behaviour changes.
- No database migration required.
- One reusable payout engine exists.
- Pet Shop becomes the first implementation of that engine.
- All tests pass.

---

## Implementation Notes

### Summary

**Audit of the pre-existing payout flow (Task 1), before any change was made:**

- **Entry points into the payout system**: two `onCall` Cloud Functions, `exports.markSellerPayoutReady` and `exports.markSellerPayoutPaid` (both admin-only, both operating on a single `sellerOrders/{sellerOrderId}` document), plus one internal, non-exported function, `applyRefundToSellerPayout({db, sellerOrderId, returnId, refundAmount, reason})`, called from exactly one place: `triggerOrderReturnRefund` (the return/refund gateway-confirmation flow), after a refund has already been confirmed at the payment gateway.
- **No scheduled function** touches payout state today. `checkMarketplaceAccountability` (an existing `onSchedule`, every 5 minutes) is a response-delay compliance/penalty cron, unrelated to payouts.
- **Helpers involved**: `migrateMalformedPayoutFields` (the Phase 1.1 hotfix's idempotent repair for a prior dot-notation write bug), `assertSellerOrderPayoutApprovable` (blocked-by-hold/recovery_required check + an `order_returns` active-return check), `assertSellerBankAccountValid` (reads `businesses/{businessId}.payment`, shared with `updateBusinessBankAccount`, untouched).
- **Lifecycle verified**: `payout.status` moves `payment_pending → pending → ready → paid`, with side-states `hold` and `recovery_required` reachable only via `applyRefundToSellerPayout`. `markSellerPayoutPaid` does not call the bank-account check (only `markSellerPayoutReady` does) — this asymmetry was confirmed intentional (existing behavior) and preserved exactly.
- **Admin UI dependency**: `lib/ui/admin/payments/admin_payouts_page.dart` calls `markSellerPayoutReady`/`markSellerPayoutPaid` by name with `{sellerOrderId}` / `{sellerOrderId, reference, note}` and does not read any field from the response beyond a generic success/failure — confirmed no client-side coupling to internal response shape beyond what's still returned.

**Generalization performed (Tasks 2–4):**

A new `functions/payout/` module (mirroring the existing `functions/commission/`, `functions/settlement/`, `functions/revenue/` package-per-concern convention already used in this codebase) now contains a sector-parameterized payout engine:

- `functions/payout/payoutEngine.js` — `migrateMalformedPayoutFields`, `assertPayoutNotBlocked` (the sector-agnostic hold/recovery_required check), `assertBankAccountValid` (now takes a resolved `businessId` instead of a `sellerOrder`-shaped object), `markPayoutReady`, `markPayoutPaid`, `applyRefundToPayout` — all parameterized by `{ db, sector, payableId, ... }` instead of hardcoding `sellerOrders`.
- `functions/payout/sectorAdapters.js` — the sector adapter registry (`getPayoutSectorAdapter(sector)`), with exactly one entry: `petshop`.
- `functions/payout/adapters/petshopPayoutAdapter.js` — Pet Shop's adapter config: `{ collection: "sellerOrders", debtCollection: "sellerDebts", getBusinessId, getRecoverySellerUid, assertNoBlockingEvents }`. `assertNoBlockingEvents` holds the one piece of logic identified as genuinely marketplace-specific (not generalized): the `order_returns` active-return query, which models physical-goods return logistics with no equivalent in any other sector.
- `functions/index.js`'s `markSellerPayoutReady`/`markSellerPayoutPaid` are now thin `onCall` wrappers: unchanged auth/validation/admin-role checks, then a single call into `payoutEngine.markPayoutReady`/`markPayoutPaid` with `sector: "petshop"`, then the exact original response object. `applyRefundToSellerPayout` is now a thin, signature-preserving wrapper around `payoutEngine.applyRefundToPayout`, so its one call site (`triggerOrderReturnRefund`) needed no changes.

### Files Modified

- `functions/index.js` — removed `PAYOUT_BLOCKING_RETURN_STATUSES`, `MALFORMED_PAYOUT_KEYS`, `migrateMalformedPayoutFields`, `assertSellerOrderPayoutApprovable`, `assertSellerBankAccountValid` (moved, not duplicated); `applyRefundToSellerPayout` reduced to a thin wrapper; `markSellerPayoutReady`/`markSellerPayoutPaid` bodies reduced to thin wrappers around the new engine; added `const payoutEngine = require("./payout");`.

### Files Added

- `functions/payout/index.js` — barrel export.
- `functions/payout/payoutEngine.js` — the generalized engine.
- `functions/payout/sectorAdapters.js` — sector adapter registry.
- `functions/payout/adapters/petshopPayoutAdapter.js` — Pet Shop's adapter (collection, debt collection, business-id/seller-uid resolution, the order_returns blocking check).

### Important Decisions

- **The `order_returns` check was kept as a per-sector adapter hook (`assertNoBlockingEvents`), not generalized into the shared engine.** This follows the already-approved architecture review's conclusion that physical-goods-return logistics has no equivalent in Vet/Grooming/Hotel/Taxi, and forcing it into shared logic would model the wrong thing. The shared engine only knows "call `adapter.assertNoBlockingEvents` if the adapter defines one."
- **Auth, request validation, and the admin-role check stayed in the `onCall` wrappers in `index.js`, not in the engine.** The engine's responsibility boundary is the payout state-machine transaction itself (status checks, blocking checks, bank check, the write) — matching how the task describes the operations to generalize (`markSellerPayoutReady()`, `markSellerPayoutPaid()`, `applyRefundToSellerPayout()`, "payout validation", "payout state transitions"). Each future sector is expected to have its own thin `onCall` entry point calling the same shared engine, per the approved architecture's "Sector Adapter" section — this milestone does not need to (and per scope, must not) build those other entry points yet.
- **The `sellerDebts` document's field names (`sellerOrderId`, `returnId`) were kept exactly as before**, even though the engine's own parameters are now generically named (`payableId`, `refundEventId`). Renaming persisted field names is an explicit Firestore-schema change and is out of scope for this milestone ("Existing Firestore schema remains compatible" / "No Firestore schema changes"); the architecture review's suggestion to generalize these names is deferred to whichever later milestone actually onboards a second sector.
- **One pre-existing wording artifact was deliberately left unchanged**: `assertBankAccountValid`'s error message still reads "This seller order has no associated business..." — Pet-Shop-flavored wording baked into what is now sector-agnostic code. Changing it would be a (minor) user-visible behavior change, which this milestone explicitly forbids. Recorded below as a known limitation rather than fixed silently.

### Verification performed

- `node --check` on `index.js` and all four new `functions/payout/**` files — syntax OK.
- `npm test` (existing backend suite) — 25/25 pass, no regressions.
- Firestore Emulator regression pass (never production), reproducing and extending the Phase 1.1 hotfix's proof methodology, run against the real exported `markSellerPayoutReady`/`markSellerPayoutPaid` (via `.run()`) and the now-exported `payoutEngine.applyRefundToPayout`: 18/18 checks passed, covering (a) steady-state ready→paid transition and the double-pay guard, (b) the malformed-legacy-document migration path, (c) the `order_returns` blocking check — both the blocked case and the resolved-and-retried success case — proving the adapter-hook extraction didn't change this behavior, (d) the missing-bank-account precondition, and (e) the refund-to-hold/recovery_required consequence including historical `outstandingDebt`/`relatedReturnIds` preservation and the `sellerDebts` document's unchanged field names.

### Known Limitations

- `assertBankAccountValid`'s error message text is still Pet-Shop-specific wording ("This seller order has no associated business..."); it should become adapter-configurable (e.g. `adapter.messages.noBankAccount`) when a second sector is onboarded, so a vet clinic doesn't see marketplace-order wording. Left as-is this milestone per "no user-visible behaviour changes."
- The `sellerDebts` collection and its `sellerOrderId`/`returnId` field names remain Pet-Shop-specific by name, even though the engine writing to it is now generic. Generalizing this schema (per the earlier architecture review) is deferred to the milestone that onboards the first additional sector, since it is a Firestore schema change and explicitly out of scope here.
- No `payoutIndex` or `financialEvents` exist yet (by design — out of scope for this milestone, per the approved architecture's phased plan).
- This milestone did not touch, and did not need to touch, the payout-*initialization* code paths (`finalizeIsbankPaidOrder`, `createCheckoutSession`, `verifyPaymentByOrderId` in `index.js`) that create the initial `payout` object on a `sellerOrders` document before the engine ever acts on it — those remain sellerOrders-specific and are a natural candidate for their own generalization work when a second sector needs an equivalent "payout object gets created at payment confirmation" step.