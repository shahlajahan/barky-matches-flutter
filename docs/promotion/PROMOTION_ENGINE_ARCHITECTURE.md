# PetSupo Promotion / Boost Engine — Architecture

Status: architectural baseline plus implemented M0–M7 foundation. M3 payment/activation details are in `PROMOTION_ENGINE_M3_PAYMENT_ACTIVATION.md`; M4 Pet, M5 central ranking, M6 Product, and M7 Service details are in their milestone documents. Business rollout, deployment, and data writes remain future work.

## 1. Goals and non-goals

The engine provides one server-authoritative promotion lifecycle for pets, products, services, and future business profiles. V1 supports fixed-duration campaigns only. Pet prices remain 29 TRY/24h, 69 TRY/3d, and 129 TRY/7d. Product and Service pricing is configuration, not a decision in this document. CPC is represented as an extensible model but is not implemented in V1.

The client can request checkout and observe status. It cannot activate a campaign, set payment truth, set ranking weight, set expiry, or write trusted metrics.

## 2. Canonical data model

### `promotion_campaigns/{campaignId}`

```text
campaignId
ownerUid
businessId              // nullable for PET
targetType              // PET | PRODUCT | SERVICE | BUSINESS
targetId
sector                  // nullable, normalized server-side
promotionType           // BOOST in V1; extensible later
pricingModel            // FIXED_DURATION in V1; CPC/CPA later
planId
pricingVersion
durationHours
currency
price
tax
grossAmount
status                  // draft, pending_payment, payment_processing,
                        // active, expired, cancelled, failed, refunded
paymentProvider
paymentId
providerOrderId
paymentStatus
paidAt
verifiedAt
startsAt
expiresAt
rankingWeight           // server-derived from plan and policy
placementPolicy         // server-derived policy version
createdAt
updatedAt
activatedAt
expiredAt
cancelledAt
refundedAt
createdBy
activationSource
version
targetSnapshotVersion
idempotencyKey
```

Financial/provider details that are not needed by public readers should be isolated in a private payment subdocument or `promotion_payments/{paymentId}`. Campaign documents must not be used as an unbounded event log.

### `promotion_plans/{planId}`

```text
planId
targetType
sector                  // optional
pricingModel
durationHours           // required for FIXED_DURATION
price
currency
rankingLiftPolicy
enabled
startsAt
endsAt
displayOrder
maxConcurrentPerOwner
maxConcurrentPerTarget
pricingVersion
createdAt
updatedAt
```

Plans are admin/backend-owned. At checkout, the server validates the plan and snapshots its effective price, currency, duration, and pricing version into the campaign. Historical campaigns never reprice when a plan changes.

### `promotion_active/{campaignId}`

Backend-owned materialized state for efficient reads:

```text
campaignId, targetType, targetId, ownerUid, businessId, sector,
startsAt, expiresAt, rankingLiftPolicy, publicLabel, campaignVersion,
updatedAt
```

Only active, eligible campaigns belong here. Deletion is cleanup, not correctness: readers still check timestamps and target eligibility.

### Events and metrics

Use an append-oriented `promotion_events/{eventId}` or server-ingested event path for impression, click, detail view, add-to-cart, booking start/completion, and order completion. Aggregate counters belong in separate rollups such as `promotion_metrics_daily/{campaignId_yyyyMMdd}`. Do not increment financial or conversion truth directly from an untrusted client.

Firebase Analytics can receive product telemetry; server events and payment/order records remain attribution truth. BigQuery is the later choice for large-scale analysis, not a V1 dependency.

## 3. Lifecycle/state machine

```text
draft -> pending_payment -> payment_processing -> active -> expired
                                      |             |
                                      v             v
                                    failed       cancelled
                                                    |
                                                    v
                                                 refunded
```

- `draft`: validated request, no payment intent yet.
- `pending_payment`: provider checkout created; campaign is not visible.
- `payment_processing`: callback or verification in flight.
- `active`: payment verified, target still eligible, server timestamps set.
- `expired`: terminal duration reached; ranking contribution is zero.
- `cancelled`: user/admin cancellation before or after activation according to refund policy.
- `failed`: payment or activation failure; never ranked.
- `refunded`: financial reversal; never ranked.

Every transition is an authenticated server transaction with a version/compare-and-set guard. Duplicate callbacks return the already-known terminal result. Payment success with activation failure is retained for retry/reconciliation and is visible to operations.

## 4. Functions/API design

Names below are recommendations consistent with existing callable/HTTP patterns; they are not implementation instructions.

### `createPromotionCheckout`

Caller: authenticated owner/business user. Input: target reference, target type, plan ID, client idempotency key. Server validates ownership, publication, target eligibility, plan availability, active-cap limits, and currency; creates `pending_payment`; invokes the existing provider adapter; returns campaign ID, provider checkout data, and status URL/token. It never accepts client price, expiry, or rank.

### `getPromotionStatus`

Caller: campaign owner or authorized admin. Input: campaign ID. Output: redacted state and provider-independent status. It must not expose secrets.

### `promotionPaymentCallback`

Caller: provider signature/authentication. Input: provider callback. Server maps provider order/payment to campaign, verifies signature and payment amount/currency, and transactionally activates or records failure. Callback processing is idempotent by provider event/payment ID.

### `verifyPromotionPayment`

Caller: authenticated owner or controlled internal retry. Input: campaign ID/provider reference. Server re-queries the provider using server credentials, verifies amount/currency/order, and performs the same idempotent transition as the callback.

### `cancelPromotion`

Caller: owner before activation, or admin under policy. Server transitions state and requests provider reversal/refund where applicable. It cannot be used to fake a paid or active campaign.

### `expirePromotionCampaigns`

Scheduled internal Function. Finds due active campaigns, transactionally marks them expired, and removes/updates projections. Delayed execution does not make a campaign eligible because all readers enforce `now < expiresAt`.

### `recordPromotionEvent`

Caller: client telemetry or trusted backend event producer. Server validates campaign/target/publication and deduplicates event IDs. It records marketing events, not settlement truth. Booking/order conversion should be emitted by the booking/order backend with the campaign attribution captured at the eligible interaction.

### Admin operations

Admin-only functions should manage plans, pause a campaign, disable a target type, trigger reconciliation, inspect audit logs, and initiate provider refund workflows. Every action records actor, reason, previous state, new state, and timestamp.

## 5. Payment integration

The repository already has `createCheckoutSession`, İş Bank 3-D Secure functions/callbacks, Iyzico/İş Bank configuration, polling, and verification helpers. The promotion engine should reuse provider adapters and callback signature/verification primitives, while introducing promotion-specific payment references and state transitions.

V1 must select the provider based on the currently configured and production-verified path, not by putting provider logic in Flutter. If the existing `verifyPayment` implementation is sandbox- or marketplace-specific, it must be wrapped or corrected in a separate implementation milestone before promotions launch.

Required invariants:

1. Provider amount, currency, and order ID match the campaign snapshot.
2. Payment verification precedes `active`.
3. A callback can be retried safely.
4. Browser/app disappearance is handled by callback plus status polling.
5. Refund/cancel transitions the campaign out of active and removes its projection.
6. Provider and internal records can be reconciled by immutable references.

## 6. Target eligibility and ownership

The server resolves the target at checkout and activation. It verifies owner/business relationship, target publication, target not deleted/suspended, and sector-specific availability. Promotion cannot revive an unpublished or unavailable target.

The target reference is:

```text
targetType, targetId, ownerUid, businessId?, sector?
```

The server may snapshot target version/publication state to make later reconciliation explainable, but must re-check live eligibility for ranking.

## 7. Ranking policy

Promotion is a bounded relevance feature, not a global “sort sponsored first” switch.

```text
eligible = paidActive
        && now < expiresAt
        && targetPublished
        && targetAvailable
        && targetNotSuspended

finalScore = organicRelevance
           + qualityScore
           + availabilityScore
           + personalizationScore
           + boundedPromotionLift(eligible)
```

Recommended blending:

- build organic and sponsored eligible candidate pools;
- score both using the same hard relevance/availability gates;
- apply a capped lift or reserved blend slots only where the surface needs discoverability;
- never exceed a consecutive-sponsored cap;
- cap active campaigns per owner/business and target;
- apply diversity before final placement;
- label sponsored results internally and expose a future UI label.

For products and services, price/stock/availability/booking eligibility remain hard gates. For pets, the existing relevance/compatibility score remains dominant. Expired, cancelled, refunded, unpublished, deleted, or suspended targets contribute zero regardless of stale projection state.

M5 implements the reusable ranking boundary in `lib/promotion/ranking/`.
`PromotionRankingState` is target-agnostic, applies read-time target identity
and timestamp validation, and exposes only safe ranking metadata. The V1
client policy is `organicScore + min(validPromotionWeight, 40)` with stable
target-ID tie-breaking. PET is the first consumer; legacy Pet sponsorship is
fallback-only. Editorial `featured`, offer sponsorship, availability, and
domain priority remain separate semantics and are not automatically paid
Promotion.

## 8. Read-performance/projection design

Use backend-maintained `promotion_active` as the canonical active-campaign index, joined by server projection jobs into public listing projections where that surface already uses projections. Avoid an N+1 campaign read per result. For a surface that cannot efficiently join, a materialized ranking document can contain campaign IDs and expiration timestamps, but it must be rebuilt transactionally and still enforce time eligibility.

Do not make raw campaign data public. Public projections should contain only campaign ID (or opaque label), target reference, expiration, and policy version needed for display/ranking. Backend triggers or transactional activation update projections; repair jobs reconcile drift.

## 9. Rules model

Design-only Rules boundary:

- `promotion_campaigns`: owner can create a constrained draft/request and read own status; no owner update to payment, activation, price, rank, starts/expiry, or terminal state.
- `promotion_plans`: public read only for enabled safe plans; admin/backend write.
- `promotion_active`: public read of safe projection if needed; backend-only write/delete.
- `promotion_events`: no direct trusted financial writes; use a validated endpoint or server-created event.
- admin audit logs: admin/backend write, authorized read.

Rules must enforce immutable owner/target identity after creation and reject unknown fields or protected-field changes. Existing admin helpers should be reused rather than creating a weaker parallel role check.

## 10. Admin and operations

Operations need campaign search by state, owner, business, provider ID, target, and date; payment/activation mismatch views; pause/cancel/refund controls; plan enable/disable; global kill switch; target-type kill switch; event/metric inspection; and audit log export. A kill switch should make all promotion lift zero without deleting financial history.

## 11. UX architecture

Flutter should use reusable plan cards, a campaign status model, checkout state controller, payment-return handler, and active/expired status widget. Pet, product, and service pages should supply only a target reference and display server-returned status. No page should write sponsorship or ranking fields.

States to show: choose plan → checkout → processing → active with countdown → expired/cancelled/failed. “Active” must mean server-confirmed activation, not checkout button completion.

## 12. Entity-specific support

- **Pet Boost V1:** enable first after replacing legacy dog-field reads/writes and establishing target ownership mapping.
- **Product Boost:** use nested product ID/business ID; require product and business public/active checks plus positive stock at checkout. M6 wires the generic plan/checkout and ranking projection into seller Product management and the bounded marketplace snapshot.
- **Service Boost:** M7 enables Vet/Groomy nested services with canonical `service/{SECTOR}/{businessId}/{serviceId}` identity and business/service eligibility. Hotel remains deferred until service-level discovery is selected; Taxi remains deferred until an individual promotable offering exists.
- **Business Boost:** supported by the common target model but feature-gated until business-discovery ranking and saturation policy are ready.
- **Adoption:** remain editorial until target ownership and paid-placement policy are explicitly approved.

## 13. Fixed-duration V1 and CPC-ready V2

V1 permits only `FIXED_DURATION`, immutable duration/price snapshot, one activation interval, and no usage-based billing. The model remains CPC-ready by retaining `pricingModel`, plan versioning, budget fields reserved in a versioned schema, event IDs, attribution IDs, and an explicit billing state. CPC must later add server-validated click qualification, budget reservation/consumption, fraud controls, and settlement reconciliation; do not add these to V1 by implication.

## 14. Open decisions before implementation

1. Production-approved provider and exact callback/verification contract.
2. Canonical owner field for legacy dogs and immutable service IDs.
3. Public sponsored-label policy and user disclosure wording.
4. Per-target, per-owner, per-business campaign caps.
5. Refund rules after activation and partial-duration treatment.
6. Adoption paid-placement policy.
7. Whether projections are added to each existing public projection or served by a shared backend candidate API.

## 15. M8 measurement foundation

Enabled Promotion surfaces use a single `PromotionEvent` contract and the
backend-owned `promotion_events` / `promotion_campaign_stats` boundary.
Visibility, click, and detail-view telemetry is projection-bound and
idempotent; it is not payment or revenue truth. Spend is always read from the
immutable campaign snapshot. Product order and Vet/Groomy appointment
attribution now use trusted server hooks, the versioned conservative
`m9_same_flow_v1` policy, and delta-based refund/cancellation reconciliation.
The policy is an implementation boundary, not an approved commercial
multi-touch window. PET has engagement measurement but no fabricated financial
revenue or ROAS; Hotel, Taxi, and Business remain disabled.

## 16. M9.5 production-readiness boundary

Trusted attribution exposes server-owned `reconciliationStatus` values
`CONVERGED`, `PENDING`, `AMBIGUOUS`, and `FAILED`, plus
`financialMetricsStatus` values `AVAILABLE`, `PROVISIONAL`, and `UNAVAILABLE`.
The stats read model is the normalized future performance contract; clients do
not read the attribution ledger. A bounded campaign repair recomputes only
financial counters from trusted attributions. The `m9_same_flow_v1` 30-minute
limit remains a technical stale-correlation safeguard, not a commercial
attribution policy. M10 financial UI remains gated on policy approval and
operational handling of unresolved records.

## 17. M9.6 commercial attribution policy

V1 commercial attribution is `petsupo_same_flow_v1`. The existing
`m9_same_flow_v1`/30-minute value is only a technical correlation TTL. It is
not a marketing attribution window. Admin/server health summarizes bounded
pending, failed, ambiguous, and converged reconciliation cases. Historical
attributions preserve the policy versions used at creation, and M10 consumes
only the normalized stats contract.

## 18. M10 owner performance read boundary

Owner-facing performance reads use the single callable
`readPromotionCampaignStats(campaignId)`. The server validates campaign
ownership, joins only the campaign snapshot with its materialized stats, and
returns historical spend, campaign dates, target identity, exposure counters,
and server-derived financial capability/status. The client does not read
`promotion_attributions`, `promotion_events`, payment records, orders,
appointments, or reconciliation cases.

```
promotion_campaigns ───── campaign snapshot ────┐
                                                 ▼
promotion_campaign_stats ─ normalized aggregates → readPromotionCampaignStats
                                                         ▼
                                           PromotionCampaignStats
                                                         ▼
                                      read-only owner performance page
```

`AVAILABLE` permits final supported financial metrics; `PROVISIONAL` presents
financial values as still reconciling and omits final ROAS; `UNAVAILABLE` is
used for PET, unsupported/currency-invalid campaigns, and invalid spend. A
fully reconciled supported campaign with zero conversions may show zero
revenue/ROAS; PET and unsupported cases remain N/A. Campaign summary fields
come from immutable campaign snapshots, never current plan prices.
