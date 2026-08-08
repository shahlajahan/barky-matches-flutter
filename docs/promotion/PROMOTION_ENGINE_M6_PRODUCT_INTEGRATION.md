# Promotion Engine M6 — Product Boost Integration

Status: implemented locally. M6 adds PRODUCT as the second real Promotion
Engine consumer. Service Boost, Business Boost, migration, deployment, and
production data writes remain out of scope.

## Product domain and identity

The canonical Product is the document at
`businesses/{businessId}/products/{productId}`. `productId` is the Firestore
document ID (and, when present, the stored `productId` is checked against it).
The business document's `ownerUid` is the seller authority used by the server.
The business must be approved, published, active, and not suspended. The
Product must be active, not hidden/removed, and have positive stock at
checkout. The client supplies `businessId` only as a lookup context; ownership
is resolved from Firestore.

## Purchase flow

```text
Seller Product management
        ↓
Boost Product
        ↓
PRODUCT PromotionPlan (server read)
        ↓
createPromotionCheckout
        ↓
İş Bank provider
        ↓
trusted server verification
        ↓
PromotionCampaign ACTIVE
        ↓
promotion_active
```

The seller action is on `ProductCardDashboard`. The generic
`PromotionPlanSheet` and existing `PromotionCheckoutService` are reused; the
sheet supplies only target type, canonical target ID, and business context.
Prices are never accepted from the UI. V1 Product prices remain 39 TRY / 89
TRY / 169 TRY for 24 hours / 3 days / 7 days, respectively.

The existing provider checkout presenter was corrected to accept the M3
`checkoutHtml` field as well as the legacy `html` field. Payment redirect is
not activation proof; the sheet displays success only after the authenticated
status reader reports `active`.

## Discovery and ranking

```text
Eligible Product candidates
        ↓
Existing organic relevance inputs
        ↓
PRODUCT promotion_active projections
        ↓
PromotionRankingEngine (bounded lift ≤ 40)
        ↓
AllProductsPage ordering
```

`AllProductsPage` is currently a bounded Firestore snapshot with local
filters/sorting and no cursor pagination. It loads PRODUCT projections once,
groups them by target ID, and passes normalized `PromotionRankingState` to the
central M5 engine. It does not read campaigns or payments. The engine rejects
expired/future/wrong-target projections and unavailable Products remain
organic; promotion never publishes or resurrects a Product.

Editorial `featured` or domain merchandising signals are not mapped to paid
Promotion. Product has no legacy paid Boost fallback in the audited model.
The V1 repurchase policy rejects a new Product checkout while a valid active
Product projection exists. Duplicate requests with the same idempotency key
return the existing campaign.

## Projection and performance

For N Products in the current snapshot: one PRODUCT projection query per page
instance, zero per-Product PromotionCampaign reads, and zero payment reads.
The projection map is O(N + P), and ranking is O(N log N). The ranking engine
itself performs no network access. This is correct for the current bounded
snapshot, but not a complete large-market pagination solution: future Product
scale requires server-side candidate ranking or a projection-aware paginated
query before hundreds/thousands of results are exposed.

Seller/business identity is carried into the ranking input for future
saturation controls. M6 does not apply a seller cap because the current
surface has no approved pagination-safe saturation policy; it does not guess
at one.

## Security and tests

The existing backend-only Promotion Rules remain unchanged. Server ownership,
eligibility, plan resolution, amount/currency verification, immutable price
snapshot, atomic activation, projection privacy, and idempotency are reused.
Focused M6 tests cover Product pricing, canonical identity, seller ownership,
missing/out-of-stock targets, verified activation, projection privacy, and
overlap/idempotency behavior. Central ranking tests cover Product as a
target-agnostic type; existing Pet tests remain the compatibility regression
suite.

## Known limitations and M7 handoff

- Existing Products are not migrated and no Product legacy paid-promotion
  fallback was found.
- Product search/category surfaces outside `AllProductsPage` are not changed.
- Snapshot-local client ranking is not suitable for large paginated Product
  discovery; server-side ranking/projection placement is required before
  scale-out.
- Business saturation, campaign analytics, and seller-facing analytics remain
  future work.

M7 can address Service integration only after preserving this generic boundary;
it must not copy Pet or Product payment/ranking flows.
