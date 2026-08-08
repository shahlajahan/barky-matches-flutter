# Promotion Engine — M0–M3 Implementation Contract

Status: M0–M3 implemented foundation. Pet migration, Product/Service UI, ranking rollout, analytics UI, and deployment are explicitly out of scope.

## Decisions

1. **Campaign truth:** `promotion_campaigns/{campaignId}`.
2. **Plan truth:** `promotion_plans/{planId}`. Plans are Firestore configuration, versioned and backend/admin provisioned. No production plan documents were created in this phase.
3. **Active projection:** `promotion_active/{campaignId}`. It contains only target/ranking/time data needed by later public readers and is backend-owned.
4. **Targets:** one abstraction: `targetType`, `targetId`, `ownerUid`, optional `businessId`, optional `sector`. Supported values are PET, PRODUCT, SERVICE, BUSINESS.
5. **Ownership:** PET ownership is resolved from the dog owner contract; PRODUCT/SERVICE/BUSINESS ownership is resolved through the canonical business owner relationship. Validation belongs to trusted Functions before activation.
6. **Lifecycle:** `draft → pending_payment → payment_processing → active → expired`, with failure/cancellation/refund terminal paths. The Dart and Functions contracts reject unspecified transitions.
7. **Commercial snapshot:** campaign stores `planId`, `pricingVersion`, `durationHours`, `price`, and `currency` copied from the authoritative plan. A later plan version cannot reprice a historical campaign.
8. **Authority:** client reads are constrained to own campaign status and safe plan/projection reads. Client writes to plans, campaigns, and active projections are denied. M3 Functions/provider callbacks use the Admin SDK as the authoritative write path.
9. **Expiry:** later ranking must require trusted `now < expiresAt` and active status. Cleanup is not correctness.
10. **Ranking contract:** future bounded lift only; no automatic promoted-first ordering. Relevance, publication, availability, quality, diversity, and owner/business saturation remain hard policy inputs.
11. **Analytics:** future events carry campaign ID, target type/ID, placement, and optional position. Financial/conversion truth remains server/order/provider-owned.
12. **Pricing extensibility:** the model recognizes `FIXED_DURATION`, `CPC_BUDGET`, and `CPA`, but M1 validation enables only `FIXED_DURATION`. CPC/CPA budgets, bidding, and billing are not implemented.

## V1 plan terms

The approved plan values are configuration requirements, not Flutter constants:

| Target | 24 hours | 3 days | 7 days | V1 customer status |
|---|---:|---:|---:|---|
| PET | 29 TRY | 69 TRY | 129 TRY | eligible for later enablement |
| PRODUCT | 39 TRY | 89 TRY | 169 TRY | configurable, later enablement |
| SERVICE | 49 TRY | 119 TRY | 219 TRY | configurable, later enablement |
| BUSINESS | — | — | — | disabled |

Production plan documents must be provisioned through a reviewed backend/admin operation in a later milestone. This phase does not write production data.

## Implemented boundary

- Dart models and callable transport: `lib/promotion/models/` and `lib/promotion/services/promotion_checkout_service.dart`
- Server validation/state/collection contract: `functions/src/promotion/promotion_contract.js`
- Server target resolution, checkout reservation, verification evidence, activation, projection, failure, and status: `functions/src/promotion/promotion_engine.js` and M3 callables in `functions/index.js`
- Firestore Rules foundation: `firestore.rules` promotion matches
- Unit/contract tests: `test/promotion/`, `functions/test/promotionContract.test.js`, `functions/test/promotionM3.test.js`, and emulator-gated Rules tests

## Deliberate deviations

- M3 checkout, provider verification, activation, projection, failure, and status paths now exist locally; no live provider or production data was used.
- No production plan records are seeded; creating data is prohibited in this phase.
- Target ownership/eligibility resolution is connected to the concrete PET/PRODUCT/SERVICE repository schemas; Business Boost remains disabled and ambiguous nested targets fail closed.
- No ranking code reads `promotion_active` yet; ranking integration remains M4+ work.
