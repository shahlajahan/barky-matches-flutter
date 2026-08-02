# Marketplace Inventory Implementation

Status: M1, M2, M3 and M4 complete; M5 IN_PROGRESS.

Frozen architecture reference:

```text
docs/MARKETPLACE_INVENTORY_ARCHITECTURE.md
```

This implementation is additive and dormant by default. M3 adds a canary-gated
reservation path before payment-session creation. M5 adds canary-gated failure,
cancellation, expiry and recovery paths; return/restock, rules, backfills and
production deployment remain unchanged.

## Milestone status

| Milestone | Status | Scope |
|---|---|---|
| M1 — domain model and contracts | COMPLETE | States, versions, canonical line identities, deterministic IDs, repository paths, errors, event contract |
| M2 — transactional primitives | COMPLETE | Reserve, commit, release, expiry-release, return restoration, stock adjustment, leases, atomic outbox writes, focused tests |
| M3 — checkout reservation integration | COMPLETE | Canary-gated reservation before payment-session creation; payment commit remains deferred |
| M4 — payment verification and inventory commit | COMPLETE | İş Bank/Iyzico verified-payment claims and provider-independent commit; release/expiry/returns remain deferred |
| M5 — failure, cancellation, expiry and recovery | IN_PROGRESS | Canary-gated release coordination, bounded expiry/lease recovery, and deterministic manual-review evidence |

## Contracts implemented

- Product authority remains `businesses/{businessId}/products/{productId}`.
- Product inventory fields are additive: `reservedStock`,
  `inventorySchemaVersion`, and `inventoryUpdatedAt`.
- Canonical line identity includes `rootOrderId`, `sellerOrderId`, `lineId`,
  `businessId`, and `productId`.
- Reservation, inventory commit, return, provider payment, seller-order, and
  finance eligibility constants are separate.
- Deterministic IDs exist for reservations, reserve/commit/release/expiry/
  restore/adjustment operations, movements, and events.
- Version constants cover inventory schema, operation, movement, reservation,
  event, payload schema, and producer versions.
- Durable inventory event documents include identity, operation, status,
  retries, timestamps, versions, and payload.

## Transactional primitives

Implemented in `functions/src/inventory/`:

- `reserveInventory`
- `commitInventory`
- `releaseInventory`
- `expireAndReleaseInventory`
- `restoreReturnedInventory`
- `applyStockAdjustment`
- lease validation/reclaim helpers

Each mutation reads its product, reservation/evidence, movement, and event
documents inside the transaction before writing. Required movement and event
documents are written atomically with the product/reservation mutation.

## Files changed

- `functions/index.js`
- `functions/src/inventory/inventoryConstants.js`
- `functions/src/inventory/inventoryErrors.js`
- `functions/src/inventory/inventoryEvents.js`
- `functions/src/inventory/inventoryIdentity.js`
- `functions/src/inventory/inventoryRepository.js`
- `functions/src/inventory/inventoryTransactions.js`
- `functions/src/inventory/inventoryCheckoutCoordinator.js`
- `functions/src/inventory/index.js`
- `functions/src/inventory/inventoryReleaseCoordinator.js`
- `functions/src/inventory/inventoryExpiryScheduler.js`
- `functions/src/inventory/paymentCallbackClaims.js`
- `functions/test/inventoryTransactions.test.js`
- `functions/test/inventoryCheckoutCoordinator.test.js`
- `functions/test/marketplaceM3.test.js`
- `functions/test/inventoryM5.test.js`
- `lib/services/order_service.dart`
- `lib/ui/checkout/checkout_page.dart`
- `docs/MARKETPLACE_INVENTORY_IMPLEMENTATION.md`

No return/restock function, Firestore rule, deployment file, or production
feature setting was modified. The M5 scheduled function is registered but its
worker is dormant unless both its feature flag and explicit scheduler canary
gate are enabled.

## Validation results

- New JavaScript syntax checks: passed.
- `FIREBASE_CONFIG='{"projectId":"demo-petsupo"}' node -e
  "require('./functions/index.js')"`: passed.
- Dependency validation with `npm --prefix functions ls --depth=0`: passed;
  no new dependency was added.
- Focused Firestore Emulator suite:
  - 32 passed
  - 0 failed
  - 0 skipped
- Full Functions suite:
  - 223 total
  - 178 passed
  - 0 failed
  - 45 skipped because the Firestore/Auth emulator was not running
- M5 focused suite: included in the full suite; emulator-backed M5 cases are
  present but were not executed because the local Firestore emulator binary
  was unavailable to download in this environment.
- M5 transaction acceptance: NOT YET VERIFIED; M5 therefore remains
  `IN_PROGRESS`.
- `git diff --check`: passed.
- No Firebase deployment or production backfill was performed.
- No production feature flag was enabled. The M5 recovery schedule is present
  only as a disabled-by-default Gen 2 registration.
- Focused Flutter analysis: no errors; existing deprecation infos only.

## Inventory-owned field boundary

The following fields are server-owned and must not be writable by ordinary
client product-edit paths:

- `reservedStock`
- `inventorySchemaVersion`
- `inventoryOperationVersion`
- `inventoryUpdatedAt`

The current rules remain unchanged and rule deployment is intentionally
deferred to M7. Before M3 is enabled, M7 must add field-level protection so
seller product editing can continue for ordinary catalog fields while these
inventory fields are writable only by trusted server operations. The M2
transactions enforce the same boundary internally and reject invariant
violations, but Firestore rules are the final client-write boundary.

## Known gaps and boundaries

These are intentionally deferred by the frozen milestone scope:

- Provider callback claim implementation.
- Reservation expiry scheduler and production recovery worker.
- Notification, analytics, and finance consumers.
- Firestore rule hardening and client-write protection (M7); the exact
  server-owned field set is isolated above.
- Production migration/backfill and feature-flag enablement.
- Payment commit and verified-success state integration.
- Return restoration and refund-to-stock integration.
- Firestore rule hardening and production migration/backfill.
- Production canary enablement.

M5 has a safe late-payment boundary: an expired/released reservation is never
reopened. When verified payment arrives after expiry, the system records a
deterministic `inventoryLatePaymentRecoveries/{operationId}` record, preserves
verified payment, blocks finance, and routes the case to manual review. This
does not mutate stock or reopen the terminal reservation. A future approved
reacquisition flow must use a new reservation-attempt contract before it can
automatically reacquire and commit stock.

The current marketplace remains on its existing inventory behavior while the
M3 gate is disabled.

## M3 implementation

### Audited live checkout insertion point

The Flutter checkout calls `OrderService.createMarketplaceOrderV2`, then passes
its response to `createCheckoutSession`. M3 is inserted at the end of
`createMarketplaceOrderV2`, after the root/seller-order batch and before the
callable returns. When enabled, the callable returns only after every line is
reserved, so the existing payment-session call cannot run first.

The Flutter caller persists one stable `checkoutAttemptId` per authenticated
buyer/cart fingerprint using `SharedPreferences`. It survives widget/page and
process recreation and is cleared only after successful completion, explicit
cancellation/failure, or a cart mutation. The field is additive and ignored
while M3 is disabled.

### Checkout attempt and canonical identities

Claims are stored at:

```text
marketplaceCheckoutAttempts/{buyerUid}__{checkoutAttemptId}
```

The claim stores buyer, attempt, cart fingerprint, canonical amount/currency,
deterministic root order ID, lease, attempt counter, status, and result/error
metadata. Matching retries return the same reserved result or resume the same
order tree after a stale lease. Live processing returns
`reservation_in_progress`; changed cart, amount, currency, buyer, or identity
returns `checkout_attempt_conflict`.

For enabled attempts:

```text
rootOrderId   = deterministic(buyerUid, checkoutAttemptId)
sellerOrderId = deterministic(rootOrderId, businessId)
lineId        = deterministic(rootOrderId, sellerOrderId, product snapshot, duplicate index)
```

Each seller order receives additive `inventoryLines`. Each line contains the
complete M1/M2 identity, immutable product/price snapshot, quantity,
`inventoryStatus`, and `inventoryOperationVersion`. Existing `items` and
legacy payment/status fields remain unchanged for the disabled path. For
M3-enabled attempts, all legacy payment fields start in an unpaid/pending state
regardless of client input; only later payment verification may change them.
The initial and resumed callable responses use the same `{ok, orderId,
orderNumber, sellerOrderIds, sellerCount, inventoryStatus}` contract.

### Reservation coordinator and compensation

`inventoryCheckoutCoordinator.js` orders lines deterministically and calls
`reserveInventory()` for each one. It records line outcomes and updates root,
seller-order, and attempt aggregate status. The attempt becomes `reserved`
only after every line is reserved. If a later line fails, earlier successful
holds are released through `releaseInventory()` with deterministic operation
IDs. The attempt becomes `released` only when all compensation is terminal;
otherwise it becomes `compensation_pending` and no payment session is opened.
The same checkout attempt can retry `compensation_pending`: it reloads the
canonical order tree, reuses the same deterministic release operation IDs, and
never creates another order, reservation, movement, or event. It reaches
`released` only after all holds are terminal; an unrecoverable conflict is
explicitly escalated to `manual_review`. Cart data is never deleted.

Before any resume reservation or compensation retry, the callable validates
the complete root order, every expected seller order, every immutable
seller-order line, buyer identity, and order number. An incomplete tree is
persisted as `manual_review` and is never partially resumed.

### Feature gate

The gate is disabled by default. It requires:

```text
M3_INVENTORY_RESERVATION_ENABLED=true
M3_INVENTORY_CANARY_BUYERS=uid-a,uid-b
M3_INVENTORY_CANARY_BUSINESSES=business-a,business-b
```

At least one explicit buyer/business allow-list must match. With the gate
disabled, the existing order path and response remain active and no inventory
reservation or hidden stock mutation occurs. No production setting was
enabled.

### M4 payment verification and commit

`paymentCallbackClaims.js` stores one durable claim per provider/order/payment
identity. A live claim prevents concurrent finalization, duplicate callbacks
return the stored completed result, and stale or `commit_pending` claims can be
reclaimed. `inventoryPaymentCoordinator.js` is the only M4 integration point
that calls `commitInventory()`.

Both İş Bank's verified hosted callback and Iyzico's successful verification
path use the claim and coordinator. Verified payment state is stored
additively as `providerPaymentStatus`/`providerPaymentState: verified_success`;
legacy `paid` fields remain compatible. Each canonical line commits with the
existing deterministic operation, movement, and event IDs. A partial commit
or missing canonical evidence persists `inventoryStatus: commit_pending` and
is retryable without losing the verified payment.

After all lines commit, root and seller orders are marked `committed`, finance
eligibility becomes `eligible`, seller inventory state becomes `paid_ready`,
and the callback claim is completed. Legacy orders without M3 inventory lines
remain on their existing provider behavior.

M4 tests cover concurrent callback claims, duplicate provider success,
verified commit, duplicate commit, commit failure, and commit recovery.

### M5 failure, cancellation, expiry and recovery

`inventoryReleaseCoordinator.js` is the provider-independent release boundary.
It validates the explicit managed-order marker and complete canonical line set,
releases only active reservations through `releaseInventory()`, records
per-line outcomes, and updates root/seller/attempt recovery state. Committed
lines are never released. Manual-review/conflict evidence is terminal for the
automatic release path; only transient release failures remain
`release_pending`.

`markMarketplaceCheckoutFailed`, the İş Bank terminal-failure path, the Iyzico
terminal-failure path, buyer cancellation before verified payment, and seller
cancellation before payment call the coordinator only when the corresponding
M5 flag and canary allow-list match. With flags disabled they retain the
existing legacy behavior. Post-payment seller cancellation is recorded as
manual review and does not restore committed stock.

`recoverMarketplaceInventoryM5` is a bounded Gen 2 schedule in
`europe-west3` running every five minutes. It processes expired reserved
reservations using `expireAndReleaseInventory()` atomically and separately
reclaims stale `reserving`, `releasing`, and `committing` leases. It persists a
cursor for expiry scans, continues after individual failures, logs canonical
identity and operation metadata, and is dormant unless the relevant flag plus
`INVENTORY_M5_SCHEDULER_CANARY=true` are set. Recovery reloads durable order,
seller, reservation, product, evidence and payment state; it never assumes a
previous attempt succeeded and advances attempts through the M2 primitives.
Verified committing leases resume the existing M4 provider-independent commit
coordinator; unverified committing leases do not commit.

Payment callback claims gain a `manual_review` terminal status for M5 evidence
conflicts. A late verified payment after an expired reservation is preserved
as verified but creates deterministic recovery evidence and keeps finance
blocked, rather than reopening the expired reservation.

M5 feature flags are disabled by default and require an explicit canary:

```text
INVENTORY_FAILURE_RELEASE_ENABLED
INVENTORY_CANCELLATION_RELEASE_ENABLED
INVENTORY_EXPIRY_SCHEDULER_ENABLED
INVENTORY_LEASE_RECOVERY_ENABLED
LATE_PAYMENT_RECOVERY_ENABLED
M5_CANARY_BUYERS
M5_CANARY_BUSINESSES
INVENTORY_M5_SCHEDULER_CANARY
```

M5 tests cover idempotent failure release, verified-payment protection,
feature-gate dormancy, and the scheduler contract. Firestore emulator
execution remains required for the transaction cases before M5 can be marked
complete.

### Deferred M6/M7 work

M5 does not implement return restoration, refund-to-stock behavior, notification
consumers, finance consumers, Firestore rule deployment, production migration,
or production feature enablement.

## Next milestone

M5 remains IN_PROGRESS until emulator transaction tests and the full M5
acceptance matrix pass. The next milestone is M6 only after M5 completion;
M6 must not add return/restock behavior unless separately approved by the
frozen architecture.
