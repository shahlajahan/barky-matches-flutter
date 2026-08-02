# Marketplace Inventory Architecture

Status: design only; approval required before implementation.

This document does not modify application code, rules, data, or deployment.

## 1. Executive decision

Choose model **B: reserve before payment, commit after authoritative payment
success**.

The live authority remains:

```text
businesses/{businessId}/products/{productId}.stock
```

Add server-owned `reservedStock` and an auditable reservation/movement state.
Availability is computed as:

```text
available = stock - reservedStock
```

The existing cart is intent only. It is never a reservation.

Provider finalizers share one inventory helper. If a bank/provider payment is
confirmed but inventory work temporarily fails, the order remains paid with
`inventoryStatus: pending` or `manual_review`; it is never silently marked
failed.

## 2. Alternatives

### A — Decrement after payment

Rejected. It is simple, but two buyers can pay for the last unit before either
decrement occurs. It creates an oversold-payment/refund problem and cannot
guarantee the first objective.

### B — Reserve before payment

Recommended. It prevents oversell, releases abandoned checkout holds, supports
both İş Bank and future Iyzico, and provides deterministic retry state. Its
costs are expiry cleanup, recovery for a late provider callback, and more
transactions.

### C — Derive stock only from paid orders

Rejected. It is not atomic at checkout, requires expensive historical queries,
and cannot prevent concurrent payment success.

## 3. Architecture diagram

```text
businesses/{businessId}/products/{productId}
  stock, reservedStock, inventoryVersion
       │
       ├─ reservation transaction
       │    inventoryReservations/{reservationId}
       │
       ├─ payment success
       │    finalizeMarketplaceInventory()
       │    └─ inventoryMovements/{movementId}
       │
       ├─ failure/cancel/expiry
       │    releaseMarketplaceInventory()
       │
       └─ received restockable return
            restoreMarketplaceInventory()
```

## 4. Data model

### Product

`businesses/{businessId}/products/{productId}`:

| Field | Meaning |
|---|---|
| `stock` | Physical on-hand quantity |
| `reservedStock` | Server-owned active holds |
| `inventoryVersion` | Schema/reconciliation version |
| `inventoryUpdatedAt` | Last server inventory mutation |

`availableStock` is not persisted; it is `stock - reservedStock`. Both values
must remain non-negative.

Every modification of `stock`, including seller edits, imports, administrator
adjustments, and bulk updates, must transactionally enforce:

```text
stock >= reservedStock
```

If the proposed modification would violate the invariant, the operation fails
or enters manual review; it cannot write the invalid value.

Migration defaults are additive: `reservedStock: 0`, `inventoryVersion: 1`.

### Reservation

`inventoryReservations/{reservationId}` with deterministic ID:

```text
{orderId}__{sellerOrderId}__{lineId}__{businessId}__{productId}
```

Fields:

```text
orderId, sellerOrderId, lineId, buyerUid, businessId, productId, quantity,
status: reserving | reserved | releasing | released | expired | committed,
expiresAt, createdAt, updatedAt, startedAt, leaseExpiresAt, attempt,
operationVersion, lastOperationId,
releasedReason, committedAt, releasedAt
```

### Movement ledger

`inventoryMovements/{movementId}` with deterministic ID:

```text
{operationId}__{businessId}__{sellerOrderId}__{lineId}__{productId}
```

Fields include:

```text
operationId, operationType, orderId, sellerOrderId, lineId, returnId,
businessId, productId, quantity, beforeStock, afterStock,
beforeReservedStock, afterReservedStock, provider, reason, actor, createdAt
```

Movements are immutable, server-owned audit records. Live availability remains
on the product document.

Every inventory operation carries `orderId`, `sellerOrderId`, `lineId`, and
`productId`. For a non-order stock adjustment, `orderId` and `sellerOrderId`
are explicitly null and `lineId` is the stable adjustment scope; the fields
remain present so operations cannot be ambiguously identified.

### Order state

Root orders and seller orders carry:

```text
inventoryStatus:
not_started | reserving | reserved | committing | committed |
releasing | released | expired | pending | conflict | manual_review
inventoryOperationId
inventoryUpdatedAt, startedAt, leaseExpiresAt, attempt
```

Seller settlement requires the seller order's inventory state to be committed.

## 5. Lifecycle

1. **Add to cart:** read availability for display; write buyer cart only.
2. **Change cart quantity:** update cart intent; server revalidates later.
3. **Checkout:** server reads nested business products, verifies quantity, and
   generates immutable `rootOrderId`, `sellerOrderId`, and
   `sellerOrderLineId` for every line before inventory reservation begins.
   These identifiers remain unchanged through payment, retries, recovery, and
   returns. It then reserves every line before opening a provider session.
4. **Reserve:** each product transaction checks
   `stock - reservedStock >= quantity`, increments `reservedStock`, writes the
   reservation and reserve movement, and updates order state.
5. **Reservation failure:** release all previously acquired lines through the
   same idempotent release operation; do not open payment.
6. **Payment session:** stores operation/reservation IDs; no further stock
   mutation.
7. **Authoritative success:** shared finalizer atomically decrements `stock`,
   decrements `reservedStock`, marks the reservation committed, and writes a
   commit movement.
8. **Failure/cancel:** active reservations release `reservedStock`; cart stays
   intact.
9. **Expiry:** scheduled cleanup releases expired active reservations.
10. **Seller cancellation:** release an active hold; a committed sale is
    restored only according to the physical/cancellation policy.
11. **Return:** approval alone changes no stock. After physical receipt,
    restockable quantity is restored; damaged/lost/non-restockable quantity is
    not restored.
12. **Deletion:** products referenced by active reservations or unresolved
    orders are blocked or soft-deferred; historical references remain.

## 6. Payment integration

Shared server APIs:

```text
finalizeMarketplaceInventory({
  db, orderId, sellerOrderId, lineId, businessId, productId,
  provider, paymentOperationId, buyerUid
}) → {
  status: committed | already_committed | pending | conflict | manual_review,
  committedReservationIds, pendingReservationIds
}

releaseMarketplaceInventory({
  db, orderId, sellerOrderId, lineId, businessId, productId,
  operationId, reason
})

restoreMarketplaceInventory({
  db, orderId, sellerOrderId, lineId, businessId, productId,
  returnId, quantity, restockable, actor
})
```

The helpers do not call payment providers or recalculate prices.

- `finalizeIsbankPaidOrder` calls the finalizer after validated callback claim.
- `verifyPaymentByOrderId` calls the same finalizer after Iyzico verification.
- Provider-specific code contains no product transaction logic.

Payment state is persisted as provider-verified before potentially long
inventory work. Inventory retry/reconciliation then handles transient failure.

`VERIFIED_SUCCESS` is terminal. It can never transition to failure or
cancellation, and a late provider callback must never regress it. Only one
canonical provider payment identity may finalize an order. A second successful
payment identity is classified as a duplicate, does not invoke inventory
finalization, and is routed to the refund/manual-review workflow.

## 7. State and idempotency

```text
none → reserving → reserved → committing → committed
reserved → releasing → released
reserved + expiry → releasing → expired
paid + temporary failure → pending → committing → committed
expired + unavailable stock → conflict → manual_review
committed + restockable received return → restore → movement recorded
```

Operation keys:

| Operation | Key |
|---|---|
| Reserve | `orderId:sellerOrderId:lineId:businessId:productId:reserve:v1` |
| Commit | `orderId:sellerOrderId:lineId:businessId:productId:commit:v1` |
| Release | `orderId:sellerOrderId:lineId:businessId:productId:release:v1` |
| Restore | `orderId:sellerOrderId:lineId:businessId:productId:returnId:restore:v1` |
| Admin correction | `orderId:sellerOrderId:lineId:businessId:productId:adminAdjustmentId:v1` |

Each product/reservation/movement decision is one transaction. A completed
movement or terminal reservation makes a retry a no-op. An expired processing
lease can be reclaimed; a mismatched operation is manual review.

This covers duplicate callbacks, duplicate verification, Cloud Function retry,
release retry, return retry, and admin retry.

## 8. Transactions and concurrency

For one line, one transaction reads product, reservation, and movement state;
then writes product, reservation, movement, and order state.

For multi-line/multi-seller orders, stage transactions by seller-order/product
group. If a later line fails, release prior holds through compensating,
idempotent transactions. Enforce a bounded maximum number of inventory lines so
Firestore transaction/write limits are not exceeded.

Concrete race:

```text
stock = 1, reservedStock = 0
A and B each request quantity 1
```

The first reservation commits `reservedStock = 1`. Firestore retries the other
transaction against the new document version; it then observes
`1 - 1 < 1` and fails. Only one payment session is opened.

## 9. Reservation expiry

Initial design value: 15 minutes from payment-session creation plus a small,
documented provider grace period.

A scheduled server job runs every 1–5 minutes, finds active reservations with
`expiresAt <= serverNow`, and releases each transactionally. It records the
expired state, movement, attempt, and order status.

Every `RESERVING`, `RELEASING`, and `COMMITTING` state records `startedAt`,
`leaseExpiresAt`, and `attempt`. The scheduled recovery job also detects
expired leases in these transient states. Before retrying, it always reloads
the order, reservation, product, and provider payment state. It never assumes
that a prior attempt succeeded; it derives the next action from the durable
records and uses the same operation ID so recovery is idempotent.

If a provider confirms payment after expiry, the finalizer:

1. verifies payment;
2. attempts to reacquire only if stock is still available;
3. commits if reacquisition succeeds;
4. otherwise keeps payment paid and sets `conflict/manual_review` for
   fulfillment, replacement, or refund handling.

It must not silently convert a paid order to failed.

## 10. Returns and restoration

| Event | Inventory effect |
|---|---|
| Payment failure/cancel before commit | Release reservation |
| Expired checkout | Release reservation |
| Return approved, not received | No stock change |
| Received, restockable | Increase stock by bounded accepted quantity |
| Damaged/lost/non-restockable | No stock increase |
| Partial return | Restore only accepted restockable quantity |
| Refund without physical restock | No stock increase |
| Admin correction | Explicit adjustment movement |

The bound is:

```text
0 < acceptedRestockQuantity <= committedQuantity - alreadyRestoredQuantity
```

Each seller-order line maintains a transactionally updated
`restoredQuantity`. For every partial return, the restore transaction reads
the line and verifies:

```text
remaining = committedQuantity - restoredQuantity
```

It must verify that the accepted restockable quantity is within `remaining`,
then atomically update `restoredQuantity`, product `stock`, and the inventory
movement. A duplicate or concurrent restoration therefore cannot restore the
same quantity twice.

Restocking is a physical decision, not an automatic payment-refund side effect.

## 11. Security model

Current `firestore.rules:605-622` allows business owners broad writes to nested
product documents, including `stock`. It would also allow future inventory
fields unless field protection is added.

Target rules, not yet implemented:

- clients cannot write `reservedStock`, inventory states, or movement records;
- clients cannot create completed reservations;
- reservation and movement collections are server-write-only;
- seller product management may edit base stock only through an approved,
  field-limited path;
- admins have explicit correction capability;
- ordinary product edits cannot overwrite server-owned inventory fields.

## 12. Existing data and migration design

No historical stock should be rewritten without evidence.

Existing products receive additive `reservedStock: 0` and `inventoryVersion: 1`
in a dry-run/backfill process. Existing `stock` is preserved. Negative,
missing, or non-numeric values are reported, not silently corrected.

Existing paid orders do not automatically create historical movements. Existing
failed orders create no release because no reservation existed. Existing pending
orders and returns are reported for explicit reconciliation.

The rollout defines a migration cutover timestamp. Orders created before that
timestamp are legacy orders and must never enter the reservation-based
inventory flow. Their callbacks use the legacy compatibility/manual-review
path and cannot infer a reservation or decrement stock through the new
finalizer.

The top-level legacy `products` collection is not active marketplace inventory;
it is not merged into the nested-business authority.

Rollback is feature-flag based and additive. It does not delete reservation or
movement records or rewrite historical stock.

## 13. Observability

Every operation logs:

```text
operationId, orderId, sellerOrderId, lineId, productId, businessId, buyerUid,
provider, operationType, quantity, beforeStock, afterStock,
beforeReservedStock, afterReservedStock, reservationId, reason, attempt
```

Metrics:

- reservation success/failure and expiry counts;
- commit/release latency;
- paid-but-inventory-pending count;
- inventory conflicts and manual-review age;
- duplicate-operation count;
- orphan reservations and movement/order mismatches;
- transaction-abort and negative-stock prevention counts.

Alerts fire on negative values, stuck paid orders, unreleased expired holds,
conflicts above baseline, and repeated transaction aborts for one product.

## 14. Test matrix

### Unit

- quantity and non-negative stock validation;
- availability calculation;
- reserve/commit/release/restore;
- insufficient stock;
- duplicate operations and key collision;
- expiry and non-restockable return behavior.

### Emulator

- two buyers competing for stock 1;
- multi-product and multi-seller orders;
- transaction retries;
- duplicate İş Bank callback and Iyzico verification;
- Cloud Function retry after partial orchestration;
- expiry cleanup and late callback with/without stock;
- partial/full/damaged returns;
- failed/cancelled release;
- malicious client writes;
- product deletion with reservations/orders.

### Integration/runtime

- İş Bank success/failure/cancel/duplicate callback;
- future Iyzico success/failure/duplicate verification;
- paid-but-inventory-pending recovery;
- refund/return and restock policy;
- Flutter Web, Android, iOS, and mobile-width Web checkout.

## 15. Milestone roadmap

| Milestone | Scope | Acceptance |
|---|---|---|
| M1 | Domain fields, states, operation IDs | Schema/state approval; no runtime change |
| M2 | Transactional reserve/commit/release/restore helpers | Emulator concurrency proves no oversell |
| M3 | Checkout reservation before provider session | Only fully reserved orders reach payment |
| M4 | İş Bank commit integration | Success, retry, duplicate, and delayed callback pass |
| M5 | Cancellation, failure, expiry, late-payment recovery | No stuck active holds; paid conflicts visible |
| M6 | Return receipt classification and restock | Partial/damaged returns behave correctly |
| M7 | Rules and seller editing protection | Malicious writes denied; legitimate edits preserved |
| M8 | Dry-run reconciliation/backfill | Resumable, non-destructive report |
| M9 | Metrics, alerts, and canary | Recovery alerts verified with one business |
| M10 | Full rollout | Complete payment/platform/return matrix passes |

Expected implementation areas are the inventory domain/helper, marketplace
checkout, payment finalizers, cancellation/expiry scheduler, return/refund
flow, rules, migration scripts, and focused tests. No files are changed by this
design document.

## 16. Risks and open decisions

- Exact reservation TTL and provider grace period.
- Maximum inventory lines per order within Firestore limits.
- Callable product editing versus field-diff rules for seller stock edits.
- Operational owner/SLA for paid inventory conflicts.
- Full versus partial fulfillment when stock is unavailable after late payment.
- Restock timing after seller receipt versus refund completion.
- Treatment of existing pending orders.
- Retirement/documentation of the legacy top-level product writer.

## 17. Exact implementation order

1. Approve schema, state machine, TTL, and conflict policy.
2. Implement and test transaction primitives without checkout wiring.
3. Add emulator concurrency and malicious-write tests.
4. Add additive fields and a feature flag.
5. Wire reservation into checkout and compensation on failure.
6. Wire commit into İş Bank; reuse for future Iyzico.
7. Add expiry, retry, and late-payment recovery.
8. Add physical return/restock behavior.
9. Apply reviewed rules and seller-edit compatibility.
10. Run dry-run reconciliation.
11. Canary one business/provider configuration.
12. Roll out globally after acceptance and rollback checks.

## 18. Inventory state machine

The product's physical `stock` remains the on-hand quantity. The reservation
record and operation state describe the lifecycle of a specific order line;
they do not replace the product's stock authority.

```text
AVAILABLE
  | checkout accepted; transaction sees stock - reservedStock >= quantity
  v
RESERVING --transaction retry--> RESERVING
  | all product-line reservations written
  v
RESERVED --payment failure/cancel/timeout--> RELEASING
  | payment success
  v
COMMITTING --transaction retry--> COMMITTING
  | stock decremented and reservation committed
  v
COMMITTED
  | duplicate callback/retry after committed
  +------------------------------------------> COMMITTED (idempotent no-op)

Return receipt/restoration uses the independent return state machine in
Section 39; it does not transition the reservation.

RELEASING --release transaction succeeds--> RELEASED
  | retry
  +---------------------------------------> RELEASING
  | reservation deadline passes before cleanup
  +---------------------------------------> EXPIRED

EXPIRED --late payment and stock can be reacquired--> new reservation attempt
EXPIRED --late payment and stock unavailable--> CONFLICT

COMMITTING --payment proven but transaction repeatedly fails--> PENDING
PENDING --automatic retry succeeds--> COMMITTING
PENDING --retry exhausted or data mismatch--> MANUAL_REVIEW

COMMITTED --return approved--> COMMITTED (no stock change)
COMMITTED --return received, damaged/non-restockable--> COMMITTED
COMMITTED --admin correction--> MANUAL_REVIEW or explicit ADJUSTMENT movement
CONFLICT --operator resolves with documented decision--> COMMITTED or RELEASED
MANUAL_REVIEW --operator resolves with documented decision--> COMMITTED,
  RELEASED, or explicit ADJUSTMENT movement

Any state --duplicate operation key--> same terminal state (no second movement)
Any transaction --failed before commit--> prior durable state; safe retry
```

State transition rules:

| From | Event | To | Stock effect | Required evidence |
|---|---|---|---|---|
| Available | Reservation transaction starts | Reserving | None until commit | order and operation ID |
| Reserving | All lines reserve | Reserved | `reservedStock += quantity` | reservation movement |
| Reserving | Any line fails | Releasing | Compensation releases prior lines | failed line and reason |
| Reserved | Provider failure, user cancel, or expiry | Releasing | None yet | provider/cancel/expiry event |
| Releasing | Release succeeds | Released | `reservedStock -= quantity` | release movement |
| Reserved | Authoritative payment success | Committing | None until commit transaction | verified payment |
| Committing | Commit succeeds | Committed | `stock -= quantity`, `reservedStock -= quantity` | commit movement |
| Committing | Retryable failure | Pending | None or prior transaction result | retry marker |
| Pending | Reconciliation cannot prove outcome | Manual review | No blind mutation | mismatch report |
| Committed | Return approved | Committed | None | return approval |
| Committed | Received and restockable | No reservation transition; return becomes Restored | `stock += accepted quantity` | receipt and restock decision |
| Committed | Received damaged/non-restockable | Committed | None | damage/non-restockable decision |
| Expired | Late payment with available stock | New reservation attempt | Reacquire transactionally without reopening the expired record | late-payment operation |
| Expired | Late payment without stock | Conflict | None | paid/conflict record |
| Any | Admin correction | Manual review or explicit adjustment | Only explicit, audited adjustment | admin identity and reason |

`RESTORED` is a terminal state for that return operation, not a promise that
the product is permanently available: a later order creates a new reservation
and movement chain. An expired or released reservation is never reopened; a
late payment may create a new reservation attempt with a new operation ID, or
become a conflict. A duplicate callback never advances a committed operation
again.

## 19. Payment sequence

```text
Flutter App
    | checkout(order lines)
    v
Checkout Function
    | validate product snapshots, reserve every line transactionally
    v
Inventory Reservation
    | RESERVED, reservationId and expiry recorded
    v
Payment Provider
    | İş Bank today; future Iyzico uses same contract
    | 3DS/session result
    v
Payment Callback
    | verify signature, amount, currency, order and provider payment ID
    | duplicate callback is accepted as an idempotent lookup
    v
Shared Inventory Finalizer
    | COMMITTING -> COMMITTED, or PENDING/CONFLICT/MANUAL_REVIEW
    | retries reuse paymentOperationId and movement IDs
    +------------------------------+
    | commit success                | inventory unavailable after late payment
    v                              v
Seller Orders                    Conflict / Manual Review
    | paid only after payment and  | payment remains auditable; operator
    | inventory outcome is recorded | resolves without a blind stock decrement
    v                              |
Notifications <------------------+
    | buyer/seller notification is idempotent and state-gated
    v
Finance
    | payout/ledger projection follows paid seller-order state
    | inventory failure is observable and does not silently become paid stock

Payment failure/cancel/timeout -> release helper -> RELEASED or EXPIRED.
Provider retry -> callback verification -> same shared finalizer operation.
```

Provider-specific code remains responsible for provider authentication and
verification. It must not mutate product stock directly.

## 20. Rollout feature flags

Flags are server-evaluated per environment, with an optional business canary
allow-list. A flag being disabled must not delete durable reservations or
movements; it only stops new behavior and leaves the recovery path available.
The migration cutover timestamp is evaluated before the flags: pre-cutover
orders remain on the legacy compatibility/manual-review path even when the
new reservation flags are enabled.

| Flag | Default before canary | Purpose | Dependencies | Rollback behavior |
|---|---:|---|---|---|
| `inventoryReservationEnabled` | `false` | Reserve nested product stock before creating a payment session | domain fields, reservation transaction, release helper | Stop new reservations; leave active records for controlled release/recovery |
| `inventoryCommitEnabled` | `false` | Commit reserved stock after verified payment | reservation enabled, shared finalizer | Stop commits only after an operator decision; paid orders enter pending/manual review |
| `inventoryReturnEnabled` | `false` | Restore only physically received, restockable returns | movement ledger, return classification | Stop automatic restore; retain return decisions for manual processing |
| `inventoryLedgerEnabled` | `true` in shadow mode | Write immutable movement evidence for each operation | deterministic movement IDs | Stop new writes only if ledger failure blocks startup; never rewrite existing movements |
| `inventoryReconciliationEnabled` | `true` in report-only mode | Compare stock, reservations, movements, orders, and returns | read-only reconciliation job | Disable scheduled report generation without changing inventory |
| `latePaymentRecoveryEnabled` | `false` | Reacquire expired holds or create conflict cases after late payment | conflict workflow, manual review | Keep paid cases pending/manual review; no stock mutation |
| `manualReviewEnabled` | `true` | Persist and expose unresolved conflicts | admin dashboard and audit log | Route unresolved outcomes to an incident queue; never auto-resolve |

The commit flag must not be enabled without reservation and ledger support.
Return handling depends on committed movement history. Reconciliation and
manual review are safety nets and should be enabled before payment cutover.

## 21. Recovery dashboard

The internal dashboard is read-only by default and exposes explicit,
permission-checked actions. Every action requires a reason and writes an audit
event containing the operator, prior state, new state, and operation ID.

| Case | Display | Allowed action | Audit requirement |
|---|---|---|---|
| Paid / Inventory Pending | order, seller order, payment ID, lines, reservation, attempts, age | retry finalizer or escalate | provider evidence and retry result |
| Reservation Expired | reservation, expiry, order/payment status, product stock | release, reacquire after late payment, or review | before/after reserved quantity |
| Inventory Conflict | paid order, requested/available quantity, product, provider | resolve fulfillment/refund/manual decision | resolution code and approver |
| Duplicate Callback Ignored | provider event ID, order, first-seen time, prior terminal state | inspect only; replay verification if authorized | no-op marker and actor |
| Late Payment | payment timestamp, reservation expiry, current stock | reacquire or create conflict | late-payment policy and result |
| Negative Stock Prevented | product, attempted quantity, transaction IDs | inspect and reconcile; no direct client correction | rejected operation and alert link |
| Reservation Cleanup Failure | expired reservations, retry count, error | retry cleanup or manual release | cleanup attempts and final state |
| Inventory Mismatch | product totals, expected versus stored stock, related orders | generate an adjustment proposal; separate approval for adjustment | source records and approved delta |

The dashboard must not offer a generic “set stock” action for recovery. Base
stock corrections are a separate approved product-management operation; all
server-owned reserved quantities and movements remain protected.

## 22. Nightly inventory reconciliation

Run a read-only scheduled job once nightly in the business's operating region,
with a bounded catch-up run after outages. It must never automatically modify
products, reservations, orders, returns, or movements.

For each nested product, compare:

```text
products.stock and reservedStock
        against
active reservations
        against
inventory movements
        against
paid seller orders and their line quantities
        against
approved/received returns and restock decisions
```

The report includes missing reservations or movements, duplicate operation
IDs, orphan reservations, expired active reservations, negative derived
availability, paid-but-uncommitted lines, over-restored quantities, and
products whose stored values do not reconcile with the movement history.

Reconciliation is always read-only. It may detect problems, generate reports,
open mismatch cases, and create reviewed repair proposals. It must never
modify inventory, reservations, orders, returns, or movements. A repair can be
applied only by the explicit reviewed repair workflow, with its own
idempotent operation and audit record.

Operational specification:

- Schedule: nightly, plus an operator-triggered bounded business/product run.
- Runtime: paginated reads with a cursor; partition by business and product
  hash so one large seller cannot exhaust one invocation.
- Output: immutable run summary, per-mismatch records, source document paths,
  expected values, observed values, severity, and recommended operator action.
- Metrics: products scanned, reservations scanned, movements scanned, orders
  scanned, returns scanned, mismatches by type, duration, read failures, and
  cursor progress.
- Alerts: any negative derived availability or paid/uncommitted line is
  immediate; any orphan reservation older than one hour, movement mismatch,
  or cleanup failure is alertable; thresholds are tuned from a baseline and
  never used to auto-mutate data.

## 23. Disaster recovery

Recovery is evidence-first: reconstruct the operation from immutable payment,
order, reservation, movement, and return records before approving a mutation.

| Failure | Recovery | Automatic? |
|---|---|---|
| Missing reservation | If payment is not authoritative, fail/retry checkout; if paid, create a conflict case rather than infer a reservation | Retry only; manual for paid cases |
| Missing inventory movement | Compare transaction state and product values; replay the deterministic operation only when its completion is provable | Safe idempotent replay; otherwise manual |
| Duplicate movement | Mark duplicate operation as ignored and preserve both audit records; never reverse blindly | Detection automatic; resolution manual |
| Failed transaction | Retry with the same operation ID; Firestore transaction outcome determines whether state advanced | Yes, bounded retries |
| Partial transaction | Re-read all expected documents; transaction writes are all-or-nothing, while multi-stage orders use compensation | Compensation automatic; unresolved cases manual |
| Orphan reservation | Verify order/payment state, then release with its deterministic release ID | Automatic after policy threshold |
| Provider callback after database failure | Verify callback again, then run the shared idempotent finalizer; expired/unavailable stock becomes conflict | Retry automatic; conflict manual |
| Corrupted stock | Freeze automatic adjustments for the product and produce a reconciliation proposal | Manual approval required |
| Accidental document deletion | Restore from audit/export only after validating current orders and movements; do not recreate from stale client data | Manual approval required |

Backups and exports should preserve document paths, timestamps, operation IDs,
and provider evidence. Recovery must be replayable in a dry-run mode before a
write is approved.

## 24. Performance and scale limits

Firestore transactions have bounded retries and document read/write limits;
large orders must not be handled as an unbounded single transaction. A
reservation transaction should touch one product, its reservation, its
movement, and the relevant order-line state. Multi-line orders are staged by
bounded groups, with deterministic compensation if a later group fails.

Recommended initial operating limits:

- Maximum **50 distinct products per order**.
- Maximum **10 sellers per order**.
- Maximum **100 quantity units per line**, subject to product policy.

These are safety limits, not Firestore guarantees. Fifty product lines keeps
the transaction and recovery surface bounded; ten sellers keeps seller-order
fan-out and notification/finance follow-up manageable. The checkout rejects
or routes larger orders to a staged workflow before payment creation.

Cleanup scans only active reservations whose expiry is due, use cursors and
small batches, and shard by business/time window. Reconciliation uses the same
partitioning and records a resume cursor. Movement writes are deterministic,
so retries do not create additional writes after the first successful write.
High-contention products are expected to incur transaction retries; metrics
must expose contention rather than bypassing the transaction.

## 25. Versioning strategy

All new documents and server-owned fields carry explicit versions:

| Version | Meaning | Upgrade strategy |
|---|---|---|
| `inventorySchemaVersion` | Product/order inventory field contract | Additive fields first; readers accept the prior version; writers emit the current version |
| `inventoryOperationVersion` | Semantics of reserve/commit/release/restore operations | Operation handlers dispatch by version and reject unknown versions into manual review |
| `movementSchemaVersion` | Immutable movement document shape | Never rewrite history; add readers for old versions and emit current fields |
| `reservationSchemaVersion` | Reservation state, expiry, and ownership contract | Existing active reservations are read with safe defaults; migrate only via reviewed, resumable work |

The initial rollout should use version 1 with `reservedStock` defaulting to
zero only for products that have no field. Unknown higher versions are not
silently downgraded. A migration is additive, resumable, dry-run capable, and
backward-compatible until all readers and recovery tooling support the new
version. Rollback disables new writers through flags; it does not delete or
rewrite versioned reservations or movements.

## 26. Implementation readiness checklist

Each milestone is blocked until its checklist is complete:

| Milestone gate | Required evidence |
|---|---|
| Architecture Approved | chosen model, conflict policy, TTL, and return policy signed off |
| Data Model Approved | product, reservation, movement, order state, and version contracts reviewed |
| State Machine Approved | every success, failure, timeout, retry, return, and correction transition tested on paper and in emulator |
| Security Review | client writes to server-owned inventory fields and documents denied; seller base-stock path preserved |
| Performance Review | order/seller limits, contention behavior, cleanup partitions, and reconciliation runtime measured |
| Migration Reviewed | defaults, pending-order treatment, legacy path treatment, dry-run and rollback approved |
| Tests Ready | unit, emulator, provider integration, return, recovery, and malicious-write suites available |
| Rollback Ready | flags, operator procedures, conflict queue, and no-destructive rollback verified |
| Canary Ready | one business/provider canary, dashboards, alerts, and support owner assigned |
| Production Ready | acceptance matrix passes on Web, Android, iOS, and all active payment outcomes |

No milestone should enable payment reservation or commit until all earlier
gates are satisfied. A failed gate pauses rollout and leaves existing
checkout behavior unchanged.

## 27. Stock adjustment workflow [NEW]

Inventory corrections are first-class domain operations, never direct edits to
the server-owned stock balance. Every adjustment requires an immutable
movement record, an operator or approved system actor, a reason code, the
source reference, and the before/after quantities. A correction may change
physical `stock`, but it must not silently change `reservedStock`.

Supported adjustment reasons:

| Reason | Typical actor | Required evidence | Inventory effect |
|---|---|---|---|
| Damaged goods | Seller or warehouse operator | receipt/inspection reference and quantity | Reduce physical stock; no reservation change |
| Warehouse count correction | Authorized operator | count sheet and location | Set the verified physical delta through an adjustment movement |
| Supplier correction | Seller/admin | supplier document or receiving record | Add or remove the verified supplier delta |
| Picking/packing discrepancy | Seller operator | shipment/order reference | Correct only the physically confirmed quantity |
| Reconciliation correction | Admin | reconciliation run and approved proposal | Apply an explicit delta; never auto-apply the report |
| Fraud or loss investigation | Admin | case reference and dual approval | Hold for manual review before movement |

Adjustment rules:

1. The system reads the product and active reservations transactionally.
2. An adjustment that would make `stock < reservedStock` is rejected and
   becomes a manual-review case; it cannot create negative available stock.
3. The movement records the adjustment type, quantity, reason, source
   document, actor, approval, and before/after values.
4. The deterministic adjustment operation ID makes a retry a no-op.
5. Corrections affecting a committed order or return must reference that order
   or return and use the return/restock policy, not a generic adjustment.

Seller base-stock edits and warehouse corrections are separate capabilities.
Neither may overwrite reservation state, movement history, order state, or
finance fields. A correction is complete only when the movement record and
product update have committed together.

## 28. Payment provider abstraction [NEW]

Payment providers are adapters behind a provider-neutral contract. The
inventory domain receives a normalized, verified payment result and does not
depend on İş Bank, Iyzico, provider SDK types, redirect formats, or callback
field names.

| Provider capability | Responsibility | Inventory interaction |
|---|---|---|
| `createCheckout` | Create a provider payment session from a server-owned order amount/currency snapshot | Receives reservation and expiry references; does not mutate inventory |
| `verifyPayment` | Verify provider status, amount, currency, merchant, order, and payment identity | Produces a normalized authoritative result for the shared finalizer |
| Callback handler | Authenticate and normalize asynchronous provider notifications | Claims provider event idempotently, then invokes verification/finalization |
| Cancellation/failure normalization | Convert provider-specific outcomes into a common terminal or retryable result | Invokes release for an active reservation |
| Refund/return notification | Normalize refund outcome without deciding physical restock | Return workflow decides whether and when stock is restored |

The normalized result contains the internal order identity, provider name,
provider payment/event IDs, verified amount and currency, authoritative status,
event timestamp, and verification evidence. Provider adapters own credential
handling, signature/hash verification, timeout behavior, and retry policy.

The shared payment orchestration owns state claims, idempotency, inventory
reservation/commit/release, seller-order transitions, and normalized events.
Adding a future provider requires a new adapter and conformance tests; it must
not add another inventory implementation. A provider that cannot supply a
stable payment/event identity cannot be enabled for production finalization.

## 29. Future multi-warehouse model [NEW]

The first rollout remains single-stock per nested business product. Warehouse
support is intentionally deferred but the model reserves a clean extension:

```text
businesses/{businessId}/warehouses/{warehouseId}
businesses/{businessId}/products/{productId}/warehouseStock/{warehouseId}
inventoryReservations/{reservationId}/lines/{lineId}
```

Each warehouse-stock record would contain physical stock, server-owned
reserved stock, schema/version fields, and operational status. A reservation
line would identify the selected warehouse and quantity. The product-level
availability would be an aggregate view, not a second mutable authority.

Warehouse allocation would be a server decision based on fulfillment region,
available quantity, serviceability, and seller policy. Allocation and
reservation would occur in the same transaction per warehouse line. Moving
stock between warehouses would be two linked adjustment movements, not a
direct overwrite.

The extension must define split shipments, warehouse failure, substitution,
and cross-warehouse returns before activation. Until then, warehouse fields
must not be inferred from the legacy product document, and a product with
multiple physical locations must use the manual-review path rather than
silently aggregating untracked quantities.

## 30. Inventory event catalog [NEW]

Events are durable domain facts, not commands. Each event is persisted before
publication and contains `eventId`, `status`, `retryCount`, and `createdAt` in
addition to its domain payload. Producers persist the event only after the
corresponding transaction has committed. Consumers are idempotent and must
not mutate inventory except through the inventory domain owner. Failed
deliveries retry automatically; permanent failures enter dead-letter/manual
review. Replay always reads the persisted event and never reconstructs one
from current product or order state.

| Event | Producer | Consumers | Inventory authority |
|---|---|---|---|
| `InventoryReservationRequested` | Checkout orchestration | Reservation worker/metrics | Request only |
| `InventoryReserved` | Reservation transaction | Payment orchestration, notifications, analytics | Reservation transaction |
| `InventoryReservationRejected` | Reservation transaction | Checkout UI, metrics, support | No stock change |
| `PaymentVerificationSucceeded` | Provider adapter | Shared finalizer | No direct stock change |
| `InventoryCommitRequested` | Payment orchestration | Commit worker/retry queue | Request only |
| `InventoryCommitted` | Commit transaction | Seller orders, finance, notifications, analytics | Commit transaction |
| `InventoryCommitPending` | Finalizer | Recovery dashboard, retry worker, alerts | No blind stock change |
| `InventoryConflictDetected` | Finalizer/reconciliation | Admin dashboard, support, alerting | No automatic mutation |
| `InventoryReleaseRequested` | Failure/cancel/expiry flow | Release worker | Request only |
| `InventoryReleased` | Release transaction | Checkout, notifications, metrics | Release transaction |
| `InventoryReservationExpired` | Expiry scheduler | Release worker, alerts | Expiry is a reason; release mutates |
| `InventoryReturnApproved` | Returns workflow | Support, logistics | No stock change |
| `InventoryReturnReceived` | Warehouse/returns workflow | Restock decision | No stock change until classified |
| `InventoryRestored` | Restock transaction | Finance context, seller/buyer notifications, analytics | Restore transaction |
| `InventoryAdjustmentProposed` | Reconciliation/operator | Admin approval workflow | No stock change |
| `InventoryAdjusted` | Approved adjustment transaction | Reconciliation, analytics, audit | Adjustment transaction |
| `InventoryOperationDuplicate` | Idempotency guard | Metrics and audit | No stock change |
| `InventoryReconciliationMismatch` | Read-only reconciliation | Recovery dashboard and alerts | No stock change |

Event names are stable versioned contracts. Events include operation ID,
product/business/order references, quantity, provider where applicable, actor,
event time, and the following version fields:

- `eventVersion` identifies the semantic version of this named event and its
  required fields.
- `schemaVersion` identifies the serialized event envelope and payload shape.
- `producerVersion` identifies the deployed producer release that emitted it,
  allowing replay and compatibility investigation without changing event
  meaning.

Every event must carry all three fields. Consumers dispatch by
`eventVersion`/`schemaVersion`, while `producerVersion` is diagnostic and
operational metadata. Finance consumes committed/restored facts; it does not
produce inventory events or mutate inventory documents.

## 31. Finance boundary [NEW]

Inventory and finance have separate authorities:

```text
Product / reservation / movement domain
              |
              | committed and restored inventory facts
              v
Seller order and payment state
              |
              v
Finance ledger, payout index, and seller summaries
```

Inventory is authoritative for physical quantity and reservation state.
Finance is authoritative for money, commission, payout eligibility, and
financial reconciliation. Finance may consume `InventoryCommitted`, order,
payment, return, and adjustment facts to determine payable status, but finance
must never increment/decrement product stock, reserved stock, or movement
records.

This boundary is normative: Finance never mutates inventory, and Inventory
never mutates finance. The Order Coordinator orchestrates both domains by
advancing seller-order and finance-eligibility state only after each domain's
own transaction succeeds. Refund APIs do not restore stock. Inventory
restoration is performed only by the inventory domain after the independent
return workflow confirms receipt and restockability.

If finance succeeds while inventory is pending, the order enters the explicit
paid/inventory-pending recovery path. If inventory succeeds while a payment is
not authoritative, the reservation must be released and no finance payable is
created. Any cross-domain mismatch is reported and resolved through the
recovery workflow, not by one subsystem silently repairing the other.

## 32. Notification matrix [NEW]

Notifications are state-gated and idempotent. A notification ledger keyed by
event and recipient prevents duplicate messages when a callback or consumer is
retried.

| Event | Buyer | Seller | Admin/support |
|---|---|---|---|
| Reservation succeeded | Checkout hold and expiry time | Optional order-intent visibility | No routine notification |
| Reservation rejected | Out-of-stock and retry guidance | No routine notification | Metrics only |
| Payment succeeded and inventory committed | Order confirmed | New paid order/pick action | Metrics only |
| Payment succeeded, inventory pending | Payment received; fulfillment under review | Action required; do not promise shipment | Immediate recovery alert |
| Payment/inventory conflict | Delay or refund/fulfillment decision | Stock conflict and action required | Manual-review assignment |
| Payment failed/cancelled | Payment failed; cart preserved | No paid-order notification | Metrics only |
| Reservation expired | Checkout expired; retry available | No routine notification | Cleanup alert only on failure |
| Return approved | Return status | Return expected | Case status |
| Return received/restockable | Return/refund status | Stock restored/status | Audit visibility |
| Return damaged/non-restockable | Refund/status without restock promise | Loss/non-restockable status | Review if disputed |
| Stock adjustment | No routine buyer notification | Adjustment reason and result | Approval/audit notification |
| Reconciliation mismatch | None | If seller action is required | Alert and case creation |

Messages must use the normalized internal order/product identity and must not
expose provider secrets, callback payloads, or internal stock diagnostics.

## 33. Audit architecture [NEW]

Inventory movements and operational audit logs are separate records:

- **Inventory movements** are immutable domain facts needed to reconcile
  quantity. They contain before/after stock and reserved values and are keyed
  by deterministic inventory operation ID.
- **Audit logs** record who viewed, approved, retried, released, escalated, or
  corrected an operation. They contain operator identity, role, reason,
  source case, prior/new state, timestamp, and correlation ID.

An audit log does not replace a movement, and a movement does not prove that a
human approved an administrative action. Support investigations may append
notes and links to source records but cannot edit historical movements. Admin
corrections require explicit capability, reason codes, and preferably dual
approval for quantity increases/decreases above a configured threshold.

Retention must cover the product/order/return financial and operational
retention period. Sensitive buyer data is minimized; references and stable IDs
are preferred over copying addresses, payment credentials, or provider
secrets. Audit access is role-scoped and itself observable.

## 34. Production rollout strategy [NEW]

Rollout is additive and reversible through server-side flags. The sequence is:

1. **Schema readiness:** deploy readers and defaults that tolerate missing
   inventory fields; no checkout behavior changes.
2. **Shadow mode:** compute reservation availability and projected movements
   without mutating product stock or blocking checkout. Compare results with
   current orders and report mismatches.
3. **Ledger/report mode:** persist only approved immutable evidence and run
   reconciliation read-only. Verify write cost, contention, and alert quality.
4. **Canary:** enable reservation and commit for one low-risk business and one
   provider path, with an explicit allow-list and manual-review owner.
5. **Gradual enablement:** expand by business cohort, payment provider, and
   traffic percentage only after reservation success, conflict, latency, and
   support metrics remain within thresholds.
6. **Full enablement:** keep recovery, reconciliation, and late-payment flags
   independently controllable after the main path is enabled.

Rollback disables new reservation/commit entry points, preserves active state,
and drains or releases reservations through the recovery procedure. It does
not restore stock by guesswork, delete ledger/audit data, or erase paid order
evidence. A rollback is mandatory when negative availability, paid-but-stuck
orders, unexplained conflict growth, or provider callback regressions exceed
the approved threshold.

## 35. Operational runbooks [NEW]

Every production incident has a correlation ID and follows the same sequence:

1. Identify order, seller order, product, business, provider event, and
   operation IDs.
2. Read the order/payment state, reservation, product quantities, movements,
   returns, notifications, and finance state without editing them.
3. Determine the last committed event and whether any provider payment is
   authoritative.
4. Choose the documented automatic retry, release, conflict, or manual-review
   path; never perform an ad hoc stock write.
5. Record the action, approval, result, and follow-up reconciliation run.

Runbooks must exist for checkout reservation rejection, paid/inventory pending,
expired reservation cleanup failure, late payment, duplicate callback, negative
stock prevention, return/restock disagreement, product deletion, and
reconciliation mismatch. Each runbook defines owner, severity, response target,
safe actions, forbidden actions, escalation path, and closure evidence.

Production troubleshooting starts with metrics and correlation IDs, then
transaction attempts and source documents, then a dry-run replay. Provider
dashboard evidence is required before resolving a paid conflict. The support
operator may retry an idempotent operation; only an authorized inventory/admin
operator may approve a correction, and all corrections require an audit record.

## 36. Disaster recovery and replay [NEW]

Backups must cover product documents, reservations, movements, orders,
seller orders, returns, payment evidence, audit logs, and reconciliation
reports. Use scheduled Firestore exports with retention appropriate to payment
and returns obligations, plus a tested restore project isolated from
production.

Recovery procedure:

1. Freeze affected product/business operations if integrity is uncertain.
2. Restore or read the relevant export into an isolated environment.
3. Reconstruct the event and movement sequence by operation ID and commit time.
4. Run a dry-run reconciliation and replay candidate operations in the
   isolated environment.
5. Approve only deterministic, idempotent repairs in production.
6. Run a post-recovery reconciliation and retain the incident audit record.

Partial failures are handled by re-reading durable transaction state and
replaying only operations whose completion is not already recorded. A provider
callback after a database outage is verified again and routed through the same
finalizer. Missing or contradictory evidence becomes manual review. The
recovery process never reconstructs stock from cart contents or from a stale
client snapshot.

## 37. Scalability review [NEW]

The product document is the unavoidable contention point for a finite stock
item. Firestore transactions serialize competing updates to that document;
high-demand products can therefore experience retries and latency rather than
oversell. Monitoring must distinguish healthy contention from transaction
failure and must not bypass the transaction to improve latency.

Primary risks and controls:

| Risk | Effect | Control |
|---|---|---|
| Hot product document | High retry rate and write contention | bounded retries, backoff, product-level metrics, operational limits |
| Reservation write amplification | Product plus reservation plus movement writes per line | deterministic no-op retries, compact immutable records, batch non-critical notifications |
| Large multi-seller order | Many transactions and compensation paths | explicit line/seller limits and staged orchestration |
| Expiry scan concentration | Cleanup spikes or missed holds | sharded time windows, cursors, bounded batches, retry checkpoints |
| Reconciliation read volume | High read cost and long runtime | partition by business/product, incremental cursors, nightly full report plus targeted runs |
| Movement growth | Long-term storage and query cost | immutable retention policy, indexed operational views, archive/export policy |
| Provider callback burst | Duplicate finalizer contention | provider event claims, queues/retries, deterministic operation IDs |

The initial 50-product and 10-seller order limits remain the recommended
operating envelope. Before increasing them, measure transaction duration,
compensation success, provider timeout behavior, and Firestore cost under peak
load. Multi-warehouse allocation, high-volume flash sales, and variants may
require sharded inventory counters or a dedicated inventory service; they are
not solved by adding more increments to the current product document.

## 38. Production architecture completeness checklist [NEW]

| Area | Missing item found | Improvement made | Status/open decision |
|---|---|---|---|
| Stock corrections | No complete correction taxonomy or approval evidence | Added adjustment workflow, mandatory movement, reason/source/actor rules | Approval thresholds remain open |
| Provider abstraction | Provider contract was only described through shared finalizers | Added adapter capabilities and normalized verification boundary | Provider adapter conformance criteria required |
| Warehouses | No forward-compatible warehouse boundary | Added deferred warehouse/reservation model and allocation constraints | Deferred until split fulfillment is designed |
| Event catalog | Events were not enumerated | Added producer/consumer catalog and ownership rule | Event transport/retention remains open |
| Finance boundary | Consumer-only relationship was implicit | Explicitly prohibited finance inventory mutation | Finance mismatch SLA remains open |
| Notifications | No recipient/event matrix | Added buyer, seller, admin mapping and notification idempotency | Templates and localization are implementation work |
| Audit | Movements and operator audit were conflated | Separated domain movements from audit logs | Retention duration and dual-approval thresholds remain open |
| Rollout | Canary and shadow mode were not detailed | Added staged enablement and rollback gates | Cohort thresholds require operational approval |
| Runbooks | Recovery actions lacked operator sequence | Added incident procedure, cases, owners, and forbidden actions | Named on-call owners remain open |
| Disaster recovery | Backup/replay requirements were incomplete | Added exports, isolated restore, dry-run replay, and evidence rules | RPO/RTO targets remain open |
| Scalability | Limits existed without hot-document analysis | Added contention, write amplification, cleanup, and growth risks | Load-test acceptance thresholds remain open |
| Versioning | Version fields existed but operational compatibility was brief | Preserved versioning and tied it to adapters, events, and recovery | Initial version numbering must be approved |

The document is implementation-ready only after the open decisions above have
owners and acceptance thresholds. No new section changes the selected reserve-
before-payment architecture or the existing milestone order.

## 39. Critical architecture clarifications [REVIEW FIX]

This section is normative for implementation. It resolves the five critical
review findings without changing the reserve-before-payment architecture. The
combined state shorthand in Section 18 is only a summary; the independent
state machines and invariants below are authoritative.

### 39.1 Independent state machines

Reservation, inventory commit, and return are separate state machines. A state
in one machine must not be used as an implicit state transition in another.
Every transient `RESERVING`, `RELEASING`, or `COMMITTING` record carries
`startedAt`, `leaseExpiresAt`, and `attempt`; lease recovery follows the
reload-and-retry procedure in Section 9.

**Reservation state machine** — one state per order line:

```text
NONE
  -> RESERVING
  -> RESERVED
  -> RELEASING -> RELEASED
  -> EXPIRED
  -> COMMITTED

RESERVING -> RELEASED       reservation transaction fails and compensation succeeds
RESERVED  -> RELEASING      payment fails, cancellation, or ordinary expiry cleanup
RESERVED  -> EXPIRED        only through the atomic expiry-release transaction
RESERVED  -> COMMITTED      inventory commit transaction claims the reservation
RELEASING -> RELEASING      retry
RELEASED, EXPIRED, COMMITTED are terminal reservation-reference states
```

`EXPIRED` means the hold has been released and no longer contributes to
`reservedStock`. `COMMITTED` records that the reservation was consumed by the
inventory commit machine; it does not describe a return.

**Inventory commit state machine** — one state per order line:

```text
NOT_STARTED
  -> COMMITTING
  -> COMMITTED

COMMITTING -> PENDING       transaction outcome cannot yet be established
PENDING    -> COMMITTING    idempotent retry
PENDING    -> CONFLICT      stock/reservation/payment evidence disagrees
CONFLICT   -> MANUAL_REVIEW operator must resolve the paid inventory outcome
COMMITTED and MANUAL_REVIEW are terminal for automatic commit
```

An inventory commit may begin only after provider payment is verified
successfully and the reservation is `RESERVED`, or after the defined late-
payment reacquisition succeeds. A duplicate commit request observes the
terminal per-line state and does not change stock.

**Return state machine** — one state per returned order line or return line:

```text
NONE -> REQUESTED -> APPROVED -> RECEIVED
RECEIVED -> RESTOCKABLE -> RESTORED
RECEIVED -> NON_RESTOCKABLE -> NOT_RESTORED
REQUESTED, APPROVED, RECEIVED, RESTORED, and NOT_RESTORED
  advance only through their documented return workflow
```

Return approval never changes inventory. Only a received quantity classified
as restockable enters `RESTORED`; each partial return has its own bounded
quantity and deterministic restore operation. A return state cannot change the
original reservation or commit state.

### 39.2 Expiry invariant and atomic release

The following invariant is mandatory:

```text
reservation.status == EXPIRED
    => reservation.quantity is not included in product.reservedStock
```

The expiry job must not first mark a reservation expired and release stock in a
separate operation. One Firestore transaction reads the product and
reservation, verifies that the reservation is active/reserved and that the
server time is at or beyond `expiresAt`, verifies that the reserved quantity
can be removed without making `reservedStock` negative, then atomically:

1. decreases the product's `reservedStock` by the reservation quantity;
2. marks the reservation `EXPIRED` and records the expiry reason/time;
3. writes the deterministic expiry-release movement; and
4. records the related order-line inventory status.

If the reservation is already `RELEASED`, `EXPIRED`, or `COMMITTED`, the
operation is an idempotent no-op. If product and reservation evidence does not
agree, the transaction does not mutate either document and creates a conflict
for manual review. A transaction retry re-reads both documents, so an expiry
cannot double-release stock. The same invariant applies to ordinary release;
`RELEASED` also means the quantity is absent from `reservedStock`.

### 39.3 Independent payment, inventory, seller-order, and finance states

These states are separate and have separate transition authority.

| Domain | States | Transition authority |
|---|---|---|
| Provider payment | `UNSTARTED`, `CREATED`, `PENDING`, `UNKNOWN`, `PENDING_VERIFICATION`, `VERIFIED_SUCCESS`, `VERIFIED_FAILURE`, `CANCELLED`, `EXPIRED`, `MANUAL_REVIEW` | Provider adapter and verified callback/verification flow |
| Inventory per line | `NOT_STARTED`, `RESERVING`, `RESERVED`, `COMMITTING`, `COMMITTED`, `RELEASING`, `RELEASED`, `EXPIRED`, `PENDING`, `CONFLICT`, `MANUAL_REVIEW` | Inventory transactions and recovery workflow |
| Seller order | `CREATED`, `PAYMENT_PENDING`, `READY_FOR_FULFILLMENT`, `PAYMENT_FAILED`, `CANCELLED`, `PARTIALLY_RESOLVED`, `MANUAL_REVIEW`, `COMPLETED` | Order coordinator and verified payment flow |
| Finance eligibility | `INELIGIBLE`, `BLOCKED`, `ELIGIBLE`, `SETTLED` | Finance projection after seller-order eligibility |

Allowed high-level transitions are:

```text
Provider CREATED -> PENDING -> VERIFIED_SUCCESS
Provider PENDING -> VERIFIED_FAILURE | CANCELLED | EXPIRED | UNKNOWN
Provider UNKNOWN -> PENDING_VERIFICATION
PENDING_VERIFICATION -> VERIFIED_SUCCESS | VERIFIED_FAILURE | MANUAL_REVIEW

Reservation expiry remains independent while payment is
`UNKNOWN` or `PENDING_VERIFICATION`.

VERIFIED_SUCCESS + every line COMMITTED
  -> seller order READY_FOR_FULFILLMENT
  -> finance ELIGIBLE

VERIFIED_FAILURE | CANCELLED | EXPIRED
  -> active reservations RELEASED or EXPIRED
  -> seller order PAYMENT_FAILED or CANCELLED
  -> finance INELIGIBLE

VERIFIED_SUCCESS + line COMMITTING/PENDING/CONFLICT
  -> seller order MANUAL_REVIEW or PARTIALLY_RESOLVED
  -> finance BLOCKED

READY_FOR_FULFILLMENT -> COMPLETED
  -> finance may transition ELIGIBLE -> SETTLED
```

Provider payment success alone never makes a seller order fulfillable and
never makes finance eligible. A provider-verified payment may be recorded for
recovery while the seller order remains `PAYMENT_PENDING` and finance remains
`BLOCKED`. Finance consumes the seller-order eligibility transition; it cannot
create it or mutate inventory. A provider failure/cancellation cannot release
a committed line.

### 39.4 Durable callback claims

Every provider callback is claimed before verification/finalization using a
server-owned durable record:

```text
paymentCallbackClaims/{provider}__{providerEventId}
```

The claim contains provider, provider event ID, canonical order ID, provider
payment ID, received time, normalized status, claim state, lease time,
finalizer operation ID, completion time, and error/retry metadata.

The claim transaction behaves as follows:

- If no claim exists, create it as `PROCESSING` and associate the canonical
  finalizer operation ID.
- If the claim is `COMPLETED`, return the stored outcome without invoking
  finalization again.
- If it is `PROCESSING` with a live lease, return an idempotent in-progress
  result.
- If its lease is stale, reclaim the same operation ID and retry safely.
- If the provider event is associated with a different order, payment ID, or
  amount/currency identity, reject it and create a security/manual-review
  case.

The order also stores the single canonical verified provider payment identity.
If a second verified successful payment is received for the same canonical
order after VERIFIED_SUCCESS has already been recorded:

- inventory finalization MUST NOT run again;
- seller-order state MUST NOT change;
- finance MUST NOT create additional payable records;
- the payment is classified as DUPLICATE_SUCCESS;
- a duplicate-payment audit record is created;
- the duplicate payment is routed to the refund/manual-review workflow.

The first verified successful payment remains the sole authoritative payment
identity for the order.
If a provider cannot supply a stable event ID, the fallback claim key must use
the provider payment ID plus canonical order ID; ambiguous callbacks are
rejected rather than deduplicated heuristically. The claim is completed only
after the shared finalizer records its terminal result. Callback claims are
not inventory movements and do not replace movement idempotency.

Callback claims are retained for the full payment-dispute and operational
replay window: **seven years from the final payment state**, matching the
financial/audit retention baseline. A scheduled cleanup process may archive
claims older than that period only after confirming that the related financial
and audit records remain retained and that no dispute, legal hold, or active
manual-review case references them. Cleanup is paginated, resumable, and does
not delete inventory movements, payment evidence, or audit records.

### 39.5 Order-level coordinator

The coordinator owns the aggregate outcome for all lines and seller orders. It
does not replace the per-line transactions; it sequences them and records the
aggregate state.

Before payment creation, every line must reach `RESERVED`. A failed line
causes idempotent release compensation for all earlier lines and no payment
session is created.

After verified payment, the coordinator commits each line with its canonical
line operation ID. It then resolves the aggregate as follows:

| Outcome | Resolution | Seller order | Finance |
|---|---|---|---|
| Full success | Every line reaches `COMMITTED` | `READY_FOR_FULFILLMENT` | `ELIGIBLE` per seller order |
| Partial success | Some lines commit and others cannot be committed | `PARTIALLY_RESOLVED` for affected seller orders; committed lines remain committed | `BLOCKED` until resolution |
| Partial refund resolution | Operator/provider refund is issued for non-committed lines; committed lines remain fulfillable if policy allows | Resolved seller orders may become ready; unresolved lines remain excluded | Eligible only for the resolved committed seller-order lines |
| Manual review | Commit outcome, payment, or stock evidence cannot be proven | `MANUAL_REVIEW` | `BLOCKED` |

Partial success is not silently treated as full success. The default recovery
decision is manual review. If the approved business policy permits partial
fulfillment, the coordinator records a line-level resolution and uses a
deterministic refund operation for every non-committed paid line. A refund does
not restore stock for a line that never committed. A committed line returned
later follows the independent return state machine.

The root order is complete only when every seller order is either ready and
fulfilled, or has an explicit failed/refunded/manual-review resolution. Seller
orders and finance records are never advanced based on a partial transaction
without that coordinator outcome.

## Decision table

| Decision | Classification |
|---|---|
| Nested product `stock` remains physical authority | Required |
| Server-owned `reservedStock` | Required |
| Computed availability | Required |
| Reserve before payment | Required |
| Shared provider-independent finalizer | Required |
| Deterministic reservation/movement IDs | Required |
| Release on failure/cancel/expiry | Required |
| Physical-return restock policy | Required |
| Paid-but-inventory-pending recovery | Required |
| Expiry scheduler and alerts | Required |
| Persisted `availableStock` | Rejected |
| Inventory derived only from paid orders | Rejected |
| Client-created completed reservations | Rejected |
| Automatic restock for every refund | Rejected |
| Historical stock rewrite without evidence | Rejected |
| Variants and warehouse inventory | Deferred |
| Legacy top-level products integration | Deferred |
| Partial fulfillment policy | Open decision |
| Exact TTL/grace period | Open decision |

No implementation, deployment, rule change, migration, or test addition was
performed. Awaiting approval.
