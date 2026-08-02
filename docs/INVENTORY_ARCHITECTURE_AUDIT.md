# Marketplace Inventory Architecture Audit

Date: 2026-08-02
Scope: read-only repository audit. No application code, rules, configuration,
deployment, or production data was modified.

## Executive conclusion

The marketplace has an inventory concept, but not an end-to-end inventory
system.

The authoritative product model contains a finite `stock` field. The Flutter
catalog hides products at or below zero stock, and sellers enter and edit stock
values. However, no marketplace payment path, Firestore trigger, scheduled
job, return flow, or refund flow mutates that field.

Classification: **CRITICAL ARCHITECTURE BUG**.

This is not an unlimited-inventory design and not a false positive. The system
accepts finite stock as a product attribute but does not connect it to paid
orders or returns. Simultaneous purchases can therefore oversell.

## 1. Inventory architecture diagram

```text
Seller product form
  └─ businesses/{businessId}/products/{productId}
       └─ stock: integer

Public/catalog reads
  └─ ProductService.getProducts()
       └─ isActive == true
       └─ Product.stock controls availability display

Buyer cart
  └─ users/{uid}/cart/{productId}
       └─ quantity: requested cart quantity

Checkout
  └─ createMarketplaceOrderV2
       ├─ reads product price/shipping fields
       ├─ does not read/enforce stock
       ├─ creates orders/{orderId}
       └─ creates sellerOrders/{sellerOrderId}

Payment success
  ├─ İş Bank callback → finalizeIsbankPaidOrder
  └─ Iyzico client verification → verifyPaymentByOrderId
       ├─ marks orders and sellerOrders paid
       ├─ removes purchased quantities from buyer cart
       └─ does NOT update product stock

Shipment/delivery
  └─ changes sellerOrder status/shipping fields only

Return/refund
  ├─ creates order_returns/{returnId}
  ├─ processes payment refund and payout reconciliation
  └─ does NOT restore product stock
```

## 2. Complete lifecycle trace

### Product creation

The primary Pet Shop UI writes nested business products:

- `lib/ui/business/petshop/add_product_page.dart:1392-1417`
- Creates `businesses/{businessId}/products/{productId}` inside a Firestore
  transaction.
- The payload contains `stock` from `:1348`.

The shared service also creates nested products:

- `lib/services/product_service.dart:60-116`
- Writes `businesses/{businessId}/products/{productId}`.

There is also a separate legacy/server export:

- `functions/index.js:17685-17717`
- `createProduct` writes top-level `products/{businessId}_{sku}`.

The marketplace checkout does not use that top-level path; it reads nested
business products at `functions/index.js:18440-18457`.

### Product editing and deletion

Primary UI editing is transactional:

- `lib/ui/business/petshop/add_product_page.dart:1411-1438`
- Same-ID edits set the existing nested product.
- SKU changes create the new nested product and delete the old one.

The service implementation uses a merge write:

- `lib/services/product_service.dart:134-158`

Deletion uses:

- `lib/services/product_service.dart:122-129`
- Deletes the nested business product.

Both creation and editing validate non-negative stock, but neither represents
an order reservation or stock ledger.

### Catalog reads

`ProductService.getProducts` reads:

- `lib/services/product_service.dart:40-55`
- `businesses/{businessId}/products`
- filter: `isActive == true`

Product cards use `stock` for availability and low-stock display:

- `lib/ui/petshop/widgets/product_card_shared.dart:206-280`
- `lib/ui/petshop/widgets/product_card_dashboard.dart:161-188`
- `lib/ui/product/product_detail_page.dart:324-429`
- `lib/ui/petshop/all_products_page.dart:1383-1401,1624,1746-1750`

The UI disables purchase when `stock <= 0`, but this is only a client-side
read-time decision.

### Cart

Cart quantity is a buyer-side quantity, not inventory:

- `lib/app_state.dart:367-426`
- `users/{uid}/cart/{productId}` is maintained by the client/cart service.
- The cart permits quantity increases without a stock transaction.

The cart UI similarly changes local/cart quantity only:

- `lib/ui/cart/cart_page.dart:78-100`

No cart write reserves a product quantity.

### Checkout and seller-order creation

Flutter sends item quantities at:

- `lib/ui/checkout/checkout_page.dart:572-618`

`createMarketplaceOrderV2`:

- `functions/index.js:18362-18892`
- Reads each nested product at `:18440-18457`.
- Validates product existence and business ownership.
- Copies requested quantity into order items at `:18498-18517`.
- Recalculates pricing, tax, and shipping.
- Creates root and seller orders in a batch at `:18801-18882`.

There is no `stock` read, no available-quantity validation, no stock write, and
no reservation document.

### Payment success

#### İş Bank

- Callback: `functions/index.js:2820-3481`
- Finalizer: `functions/index.js:1235-1803`
- Seller orders are marked paid in the batch at `:1397-1462`.
- Root order is completed in the transaction at `:1649-1729`.
- Cart quantities are reconciled by `reconcilePaidMarketplaceCart` at
  `:610-705`.

The reconciliation reads seller-order item quantities and updates only
`users/{buyerUid}/cart/{productId}` at `:668-693`.

No product document is written.

#### Iyzico

- Verification: `functions/index.js:14793-15285`
- Root and seller orders are batch-updated at `:15015-15107`.
- Cart reconciliation runs at `:15107-15110`.

Again, no product stock document is read or written.

### Shipment and delivery

Seller order status transitions are handled by an authenticated callable and
transaction:

- `functions/index.js:19390-19507`
- `shipped` updates carrier, tracking number, and shipped timestamp.
- `delivered` updates delivered timestamp.
- `cancelled` and `failed` update seller-order status fields.

These transitions do not touch product documents or inventory quantities.

### Returns and refunds

Return requests use:

- `order_returns/{returnId}`
- creation and item validation around `functions/index.js:20603-20846`
- return review around `functions/index.js:20848-21058`
- automatic overdue return completion around `functions/index.js:21626-21711`
- refund execution in `triggerOrderReturnRefund` around
  `functions/index.js:21713-22350`

Return validation reads the product document to inspect return policy fields:

- `functions/index.js:20641-20656`
- `functions/index.js:20963-20980`

It does not decrement or increment `stock`.

Pre-shipment cancellation refunds are handled around:

- `functions/index.js:19897-20115`

They update cancellation/refund state and seller payout reconciliation, but not
product inventory.

`functions/payout/payoutEngine.js:584-1016` reconciles financial consequences
of refunds and returns. Its scope is payout/ledger/debt state, not product
stock.

## 3. Inventory authority

### Authoritative field

The strongest evidence identifies:

```text
businesses/{businessId}/products/{productId}.stock
```

Evidence:

- `lib/models/product.dart:17-19`
- `lib/models/product.dart:287-288`
- `lib/models/product.dart:374-375`
- `lib/ui/business/petshop/add_product_page.dart:948-967`
- `lib/ui/product/product_detail_page.dart:324-429`

No `variants`, `warehouse`, `reservations`, `availableQuantity`, or inventory
collection was found in the marketplace lifecycle.

### Important path inconsistency

There are two product write models:

1. Nested business products used by the UI and marketplace checkout:
   `businesses/{businessId}/products/{productId}`.
2. Legacy `createProduct` export writing top-level `products/{businessId}_{sku}`:
   `functions/index.js:17685-17717`.

The second path is not used by `createMarketplaceOrderV2`, so it is not a
second inventory authority for the active checkout path; it is a separate
legacy product write path that should be treated as an architectural
ambiguity.

## 4. Reservation and stock mutation findings

### Reservation

No reservation model exists.

Evidence:

- Cart updates only `users/{uid}/cart/{productId}`.
- Checkout creates orders and seller orders but no reservation collection.
- Payment success only reconciles cart quantities.
- No Functions source writes a product stock decrement.

The word `reserved` found in Functions belongs to payout batch reservations,
for example `functions/payout/payoutBatchService.js:314-337`, not marketplace
product inventory.

### Stock decrement

No implementation exists at checkout, payment initiation, callback, payment
verification, shipment, or delivery.

### Stock restoration

No implementation exists for payment failure, cancellation, refund, or return.
The refund/payout code restores financial state only.

## 5. Firestore transactions related to inventory

There is no Firestore transaction that reads or writes a product's `stock`
field.

Related transactions that do not constitute inventory transactions:

| File/function | Collection | Purpose |
|---|---|---|
| `lib/ui/business/petshop/add_product_page.dart:1411-1438` | `businesses/{businessId}/products` | Create/edit/delete product documents and validate IDs |
| `functions/index.js:18523-18529` | `counters/orderCounter` | Allocate order number |
| `functions/index.js:633-705` | buyer cart and root order | Reconcile cart after verified payment |
| `functions/index.js:1283-1373` | root order | Claim İş Bank finalization |
| `functions/index.js:1649-1729` | root order | Complete İş Bank payment |
| `functions/index.js:18935-19015` | orders and sellerOrders | Mark failed checkout atomically |
| `functions/index.js:20919-21033` | `order_returns` | Review return request |
| `functions/index.js:21645-21684` | `order_returns` | Auto-complete overdue return receipt |
| `functions/payout/payoutEngine.js:613-996` | payout/debt/ledger records | Refund and payout reconciliation |

None reads product stock before writing an order or return.

## 6. Firestore security and existing protections

Product rules are in `firestore.rules:605-622`:

- Public/anonymous reads are allowed.
- Admins may write.
- A business owner may create, update, and delete based on the document's
  `businessId`.

Seller orders are server-write-only at `firestore.rules:851-854`.
Orders are client-create-only and server-update-only at `firestore.rules:841-849`.

Existing protections therefore include:

- authenticated callable checkout
- server-side product existence/business checks
- server-side price and shipping recalculation
- seller-order server-only writes
- transactional order-number allocation
- transactional payment-state claims for İş Bank
- transactional cart reconciliation marker
- product form validation for non-negative stock

These protections do not protect stock because no payment flow participates in a
stock transaction.

## 7. Concurrency and oversell analysis

Two buyers can perform this sequence concurrently:

```text
Buyer A reads product.stock = 1
Buyer B reads product.stock = 1
Buyer A creates order and pays
Buyer B creates order and pays
No operation decrements product.stock
```

The product read in `createMarketplaceOrderV2` is not part of a transaction
that also updates the product. Payment finalizers never re-read stock. There
is no reservation lease, quantity ledger, compare-and-set, or decrement.

Therefore simultaneous purchases can oversell finite stock. The client-side
`stock > 0` checks do not prevent this because they are based on stale reads
and are not authoritative.

## 8. Existing tests and missing coverage

### Existing relevant tests

Product/model and UI tests:

- `test/models/product_shipping_serialization_test.dart`
- `test/ui/business/petshop/product_save_plan_test.dart`
- `test/ui/checkout/checkout_order_summary_test.dart`
- `test/ui/checkout/paid_cart_cleanup_test.dart`
- `test/ui/checkout/checkout_completion_guard_test.dart`
- `test/ui/checkout/marketplace_checkout_return_routing_test.dart`
- `test/ui/petshop/marketplace_checkout_platform_test.dart`
- `functions/test/marketplaceCheckoutFailed.test.js`
- `functions/test/marketplaceShipping.test.js`
- `functions/test/isbankPaidFinalization.test.js`
- `functions/test/paymentIntegrity.test.js`
- `functions/test/orderReturnCompletion.test.js`
- `functions/test/orderReturnShipping.test.js`
- `functions/test/preShipmentCancellation.test.js`
- `functions/test/payoutFinancialEvents.test.js`

### Missing inventory coverage

No test was found that proves:

- stock is reserved before payment
- stock is decremented after successful payment
- stock decrement is atomic under concurrent purchases
- duplicate payment callbacks decrement only once
- payment failure releases a reservation
- cancellation restores stock
- approved returns restore stock
- partial returns restore only returned quantity
- stock cannot become negative
- nested product stock and order quantities remain consistent
- the legacy top-level `products` path is excluded from active inventory

The existing paid-cart tests prove cart cleanup, not inventory mutation.

## 9. Documentation consistency

`docs/DASHBOARD_HIERARCHY.md:125` says payment/stock/shipping still require
production verification. This is consistent with the implementation gap.

No authoritative marketplace inventory specification, reservation contract,
stock ledger schema, or restoration policy was found in the repository.

Finance documentation and payout documentation describe payout reservations,
not product inventory reservations:

- `docs/payment/PHAROS-FINANCE-OS.md:1191`
- `functions/payout/payoutBatchService.js:314-337`

The existing payment evidence report correctly recorded the absence of product
stock mutation, but this audit confirms it is an architecture-wide gap rather
than a hidden implementation elsewhere.

## Final assessment

| Question | Finding |
|---|---|
| Is inventory authority identifiable? | Yes: nested product `stock` field |
| Is inventory finite? | Yes; UI and seller tooling treat it as finite |
| Is stock reserved before payment? | No |
| Is stock decremented after payment? | No |
| Is stock restored after refund/return? | No |
| Is there an inventory transaction? | No |
| Can concurrent purchases oversell? | Yes |
| Is another hidden inventory model present? | None found |
| Is this unlimited inventory by design? | No evidence; contradicted by stock UI/model |
| Overall classification | **CRITICAL ARCHITECTURE BUG** |

No code was modified, no tests were added, and nothing was deployed.
