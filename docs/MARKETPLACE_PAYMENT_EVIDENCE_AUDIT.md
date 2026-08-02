# Marketplace Payment Audit — Evidence Pass

Date: 2026-08-02

Scope: repository, Firebase deployment metadata, existing focused tests, and
the currently deployed Gen 2 function configuration. No application code,
rules, configuration, or production resources were modified.

## Executive summary

The original five findings do not all have the same status:

| Finding | Classification |
|---|---|
| Iyzico production endpoint | FALSE POSITIVE for the currently deployed marketplace provider; dormant code defect if Iyzico is enabled |
| Product inventory | CONFIRMED BLOCKER |
| Marketplace settlement | İş Bank: COMPLETE; Iyzico: CONFIRMED BLOCKER |
| Legacy payment URLs | CONFIRMED BLOCKER for active checkout compatibility/branding paths |
| End-to-end idempotency | CONFIRMED NON-BLOCKER for several paths, but Iyzico notification/finalization races remain RUNTIME VERIFICATION REQUIRED |

The currently deployed `createCheckoutSession` and
`verifyPaymentByOrderId` functions expose `PAYMENT_PROVIDER=isbank` and the
live İş Bank endpoints. The deployed marketplace path therefore does not
currently execute the Iyzico branch.

## 1. Iyzico environment evidence

### Source configuration

Marketplace checkout creation constructs Iyzico with a literal sandbox URL:

- `functions/index.js:13615-13619`
- `functions/index.js:14866-14870`

Both use:

```text
https://sandbox-api.iyzipay.com
```

No `defineString`, environment variable, secret, Firebase runtime config
value, or deployment parameter controls this URI. `functions/package.json`
contains the SDK dependency `iyzipay: ^2.0.67`, but no endpoint setting.

### Current deployment configuration

The deployed Gen 2 functions were inspected with:

```text
gcloud functions describe createCheckoutSession \
  --gen2 --region=europe-west3 --project=barkymatches-new

gcloud functions describe verifyPaymentByOrderId \
  --gen2 --region=europe-west3 --project=barkymatches-new
```

Both deployed functions report:

```text
PAYMENT_PROVIDER=isbank
ISBANK_GATEWAY_URL=https://sanalpos.isbank.com.tr/fim/est3Dgate
ISBANK_API_URL=https://sanalpos.isbank.com.tr/fim/api
ISBANK_CALLBACK_BASE_URL=https://app.petsupo.com
```

The local project environment file also contains `PAYMENT_PROVIDER=isbank`
and the same live İş Bank endpoints. The default source fallback remains
`iyzico` at `functions/index.js:53-55`, so a deployment without the parameter
would select Iyzico and then use the hardcoded sandbox endpoint.

### Verdict

**FALSE POSITIVE for the current production deployment.** Production is
currently configured for İş Bank, not Iyzico.

There is nevertheless a dormant production defect: selecting Iyzico in a
future deployment would use the sandbox API for both creation and verification.

Smallest safe fix if Iyzico is enabled later: make the Iyzico endpoint an
explicit deployment parameter and require a production endpoint in production.

Required runtime verification: a sandbox test deployment and a production
Iyzico test transaction after any provider switch.

## 2. Product inventory evidence

### Inventory model

The authoritative product model uses finite stock:

- `lib/models/product.dart:17-19` — `Product.stock`
- `lib/models/product.dart:287-288` — Firestore parsing of `stock`
- `lib/ui/business/petshop/add_product_page.dart:948-967` — non-negative stock validation
- `lib/ui/business/petshop/add_product_page.dart:1348-1351` — stock persistence

The UI treats `stock <= 0` as unavailable. This is not an intentionally
unlimited-inventory model.

### Payment path

Order creation reads products from:

- `businesses/{businessId}/products/{productId}`
- `functions/index.js:18440-18457`

It reads product quantity and stores the requested quantity in order items,
but does not reserve or decrement stock.

The authoritative paid reconciliation function is:

- `functions/index.js:610-705`
- `reconcilePaidMarketplaceCart`

It decrements or deletes only the buyer's cart documents under
`users/{buyerUid}/cart/{productId}`. It never writes
`businesses/{businessId}/products/{productId}.stock`.

The same is true for:

- İş Bank finalization: `functions/index.js:1235-1803`
- Iyzico verification: `functions/index.js:14793-15285`
- cancellation/failure handling: `functions/index.js:18905-19035`
- return handling: `functions/index.js:20580-21020`

Repository-wide Functions searches found no payment, return, or background
trigger that decrements product stock or restores it. Product-related
Functions update product media/global price data, not inventory.

### Reservation, refund, and concurrency behavior

- No stock reservation occurs before payment.
- Failed/cancelled payment releases no stock because none was reserved.
- Returns validate quantities and calculate refunds, but do not restore stock.
- Concurrent purchases can both pass the product read and complete payment.
- There is no transaction over the product stock field.

### Verdict

**CONFIRMED BLOCKER.** The product catalog exposes finite stock, but paid
orders do not mutate it. Overselling is possible and returns do not restore
stock.

Smallest safe fix: add an idempotent transaction-based inventory reservation or
decrement to the authoritative payment finalizer, with a matching return
restoration path.

Required runtime verification: concurrent checkout, duplicate callback,
cancelled payment, and approved return scenarios.

## 3. Marketplace settlement evidence

### Shared settlement implementation

`settlePayable` is implemented in:

- `functions/settlement/settlementFinalizer.js:101-249`

It verifies payment finalization and financial completeness, guards already
completed settlements at lines `134-137`, claims processing in a transaction,
and writes the payout/settlement result.

Payout indexing and finance projection are separate downstream flows:

- `projectSellerOrderPayoutIndex` is registered for
  `sellerOrders/{sourceDocumentId}` in the generated deployment manifest.
- `projectSellerFinanceSummary` is registered for
  `payoutIndex/{payoutIndexId}` at `functions/index.js:444-455`.
- `functions/payout/payoutIndex.js:350-420` creates ledger entries from the
  payout projection.

No seller-order trigger was found that calls `settlePayable` automatically.
The scheduled settlement batch builder is currently a TODO:

- `functions/settlement/weeklySettlementScheduler.js`
- `functions/settlement/settlementBatchBuilder.js`
- `functions/settlement/settlementBatchExecutor.js`

### İş Bank sequence

1. `isbank3DPayHostingCallback`: `functions/index.js:2820-3481`
2. Hash, order ID, amount, currency, merchant, and approval checks.
3. `finalizeIsbankPaidOrder`: `functions/index.js:1235-1803`
4. Root and seller orders are marked paid.
5. `settlePayable` is called for seller orders at `functions/index.js:1735-1759`.
6. Payout index and finance summary triggers process the updated seller order.

Verdict: **COMPLETE** for direct settlement initiation. Settlement can still
return blocked/failed when financial repair or bank data is missing; that is an
explicit safe state, not silent success.

### Iyzico sequence

1. `verifyPaymentByOrderId`: `functions/index.js:14793-15285`
2. Iyzico token is retrieved and verified.
3. Root and seller orders are batch-updated to paid at `15015-15107`.
4. Cart reconciliation and notifications run at `15108-15271`.
5. No `settlePayable` call occurs in this marketplace success block.
6. Payout-index and finance-summary triggers may project the paid seller order,
   but they do not create/complete the settlement.

Verdict: **MISSING** for marketplace Iyzico settlement.

## 4. Legacy payment URL evidence

| URL/path | File and line | Caller/context | Platform/provider | Runtime classification | Replacement required | Safe target |
|---|---|---|---|---|---|---|
| `barkymatches://payment-success` | `lib/ui/checkout/checkout_page.dart:648-650,687-689` | Marketplace checkout session and result parser | Native Android/iOS; provider-independent client return | Active runtime production path | Yes | Current PetSupo app deep link or HTTPS return route |
| `barkymatches://payment-cancel` | `lib/ui/checkout/checkout_page.dart:650,689` | Marketplace cancellation return | Native Android/iOS | Active runtime production path | Yes | Current PetSupo cancel route |
| `https://barkymatches.app/payment-success` | `lib/ui/petshop/widgets/checkout_button.dart:81,103` | Pet Shop checkout widget | Web/native marketplace checkout | Active code path | Yes | `https://app.petsupo.com/...` |
| `https://barkymatches.app/payment-cancel` | `lib/ui/petshop/widgets/checkout_button.dart:82,104` | Pet Shop checkout widget | Web/native marketplace checkout | Active code path | Yes | `https://app.petsupo.com/...` |
| `barkymatches://payment-success` | `public/payment-callback.html:20-30` | Iyzico callback HTML | Web-to-native bridge | Active hosted callback page | Yes | PetSupo HTTPS/app callback |
| `https://app.petsupo.com/payment-callback` | `functions/index.js:13704,13815` | Iyzico checkout callback URL | Iyzico Web | Active current URL, but no Hosting rewrite to a dedicated backend callback | Runtime verification required | Dedicated server callback or verified app route |
| `/isbank/3d-callback` | `firebase.json:20-24`, `functions/index.js:2382` | İş Bank callback | Web/Android/iOS | Active current route | No | Current PetSupo Hosting route |
| `/isbank/3d-success` | `firebase.json:25-28`, `functions/index.js:2380` | İş Bank browser return | Web/Android/iOS | Active current route | No | Current PetSupo Hosting route |
| `/isbank/3d-fail` | `firebase.json:29-32`, `functions/index.js:2381` | İş Bank browser return | Web/Android/iOS | Active current route | No | Current PetSupo Hosting route |
| `https://barkymatches-new.web.app` | `lib/ui/petshop/isbank_checkout_webview_page.dart:19` | Accepted legacy host in return parser | İş Bank WebView | Backward-compatibility path | No immediate removal | Keep only as compatibility if still needed |
| `https://barkymatches-new.web.app` | `test/ui/creator/creator_dashboard_navigation_test.dart:13,20,54` | Test fixture | Tests only | Test-only | No | None |
| `https://barkymatches-new.firebaseapp.com` | `test/ui/petshop/isbank_checkout_webview_page_test.dart:12` | Test fixture | Tests only | Test-only | No | None |
| `https://isbank3d*.run.app` | `test/ui/petshop/isbank_checkout_webview_page_test.dart:13,29` | Test fixture | Tests only | Test-only | No | None |
| `barkymatches.app` | `functions/index.js:28364,28811` | Older appointment/taxi payment return code | Appointment/taxi flows | Active code occurrence; exact caller requires runtime coverage | Yes if reachable | `https://app.petsupo.com` |

The Firebase project ID, Android package metadata, and internal package names
are technical identifiers. They were not classified as payment URL runtime
paths.

## 5. End-to-end idempotency matrix

| Side effect | İş Bank | Iyzico | Evidence | Risk |
|---|---|---|---|---|
| Root order paid transition | Transactional claim and completion marker | Initial paid-state guard, then batch; no equivalent processing claim | İş Bank `1281-1373,1649-1729`; Iyzico `14840-14863,15015-15107` | Iyzico concurrent verification race |
| Seller orders paid | Batch after claim | Batch after verification | `1397-1462`; `15068-15104` | Iyzico concurrent finalizers can repeat writes |
| Inventory decrement | None | None | No stock mutation found | Confirmed oversell blocker |
| Cart reconciliation | Version marker in transaction | Same | `functions/index.js:640-705` | Low; safe retry |
| Buyer notification | Deterministic notification document | `createNotification` without deterministic ID | `1467-1526`; `15112-15123` | Iyzico duplicate notifications possible |
| Seller notification | Deterministic notification key plus ledger check | Query-then-add `notificationKey` | `1553-1574`; `15141-15186` | Iyzico check/add race |
| FCM | Guarded by deterministic notification creation | Follows non-atomic seller notification path | `1578-1630`; `15188-15256` | Duplicate push possible for concurrent Iyzico calls |
| Email/SMS | External dispatch ledger | External dispatch ledger | `functions/index.js:4281-4473` | Generally protected; provider delivery needs runtime test |
| Settlement/payable | Explicit `settlePayable` call | No marketplace call | `1735-1759`; Iyzico success block `15015-15280` | Iyzico payable missing |
| Invoice initialization | Created in checkout lifecycle batch | Same | `13199-13264` | Initialization is present; actual invoice is later |
| Analytics | No explicit marketplace analytics event found | No explicit marketplace analytics event found | Payment success blocks | Runtime verification required |

### Replay and retry conclusions

- Duplicate İş Bank callbacks are guarded by `finalizationMarker`, processing
  leases, and completed-state checks.
- Duplicate Iyzico client verification returns an already-processed result
  when the order is already paid, but two concurrent requests can pass the
  initial non-transactional read before either batch commits.
- Cloud Function retry is safer for İş Bank because the claim transaction is
  explicit. Iyzico has no equivalent processing claim.
- Partial İş Bank failures can leave seller orders updated before root-order
  completion; later retries are intended to repair the state.
- Partial Iyzico failures after the payment batch can leave cart or
  notifications incomplete; cart retry is idempotent, notifications are not
  fully race-safe.

## Focused validation

Executed without modifying production code:

```text
node --check functions/index.js
node --test \
  functions/test/isbankCallbackHash.test.js \
  functions/test/isbankPaidFinalization.test.js \
  functions/test/marketplaceCheckoutFailed.test.js \
  functions/test/paymentIntegrity.test.js \
  functions/test/settlementFinalizer.test.js \
  functions/test/payoutIndex.test.js
```

Result: **33 tests passed, 0 failed**.

The tests prove callback hashing, İş Bank finalization behavior, failure
transactions, payout-index normalization, and settlement helper behavior. They
do not prove live provider redirects, concurrent Iyzico calls, inventory, or
device/browser behavior.

## Final classification

1. Iyzico environment: **FALSE POSITIVE for current production; dormant defect if enabled**.
2. Product inventory: **CONFIRMED BLOCKER**.
3. Marketplace settlement: **İş Bank COMPLETE; Iyzico CONFIRMED BLOCKER**.
4. Legacy payment URLs: **CONFIRMED BLOCKER** for active legacy checkout paths; individual test/compatibility occurrences are non-blocking.
5. End-to-end idempotency: **RUNTIME VERIFICATION REQUIRED** for concurrent/replay behavior; confirmed missing inventory and Iyzico settlement are separate blockers.

No fixes, deployments, or configuration changes were performed.
