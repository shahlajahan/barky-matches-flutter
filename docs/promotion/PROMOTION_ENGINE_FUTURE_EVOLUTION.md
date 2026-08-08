# PetSupo Promotion Engine — Future Evolution

This is a strategic product and engineering direction document. It records what V1 intentionally does not build and protects the extension points needed for later commercial models. It is not a release commitment and it is not a generic TODO list.

## 1. V1 baseline

V1 is `FIXED_DURATION` promotion:

| Target | 24 hours | 3 days | 7 days |
|---|---:|---:|---:|
| PET | 29 TRY | 69 TRY | 129 TRY |
| PRODUCT | 39 TRY | 89 TRY | 169 TRY |
| SERVICE | 49 TRY | 119 TRY | 219 TRY |
| BUSINESS | architecture-ready, disabled | architecture-ready, disabled | architecture-ready, disabled |

Product and Service values are versioned V1 commercial starting points. They may change through server-side plan configuration; historical campaign price snapshots remain immutable. Business Boost has no customer-facing V1 plan.

## 2. Why V1 is fixed-duration

The system should collect real marketplace evidence before introducing usage billing. Current traffic, CTR, conversion history, category-level demand, fraud controls, click validation, budget accounting, auction behavior, and payment reconciliation are not yet sufficiently proven for CPC. Fixed duration gives businesses a comprehensible product while producing the event data needed for a responsible decision.

## 3. V2 — CPC_BUDGET

The intended future Product model is:

seller selects product → selects daily/total budget → optionally sets maximum CPC → product enters relevant placements → a valid click consumes budget → campaign pauses or expires when budget is exhausted.

Required future fields and systems include `dailyBudget`, `totalBudget`, `remainingBudget`, `maxCpc`, `effectiveCpc`, `validClicks`, `chargedClicks`, a budget ledger, fraud detection, click deduplication, auction/relevance policy, and billing reconciliation. These must be server-authoritative and are not implemented now.

## 4. Dynamic and suggested bidding

Suggested CPC may eventually use category, city, competition, search demand, CTR, conversion rate, inventory, historical performance, time of day, and placement. Suggestions must be explainable and bounded; they must not silently spend money or change a campaign without explicit authorization.

## 5. Service promotion evolution

Service promotion may not share Product economics. Vet, Groomer, Pet Hotel, and Pet Taxi could eventually use CPC, cost-per-booking, CPA, or a percentage of attributed booking value. The choice requires data on qualified views, booking starts, completed bookings, cancellations, refunds, service capacity, response time, city/category demand, and attribution reliability.

## 6. Business Boost

Business-level promotion may appear in business discovery, category landing pages, nearby results, search, and recommended-business surfaces. It remains disabled in V1. Future eligibility requires approved businesses, quality and rating safeguards, availability, owner/business saturation limits, and placement limits. A payment plan alone must not bypass business publication or suspension state.

## 7. Dynamic pricing

Future plan pricing may vary by target type, sector, category, city, demand, seasonality, duration, inventory, and placement. Pricing changes must create a new plan/pricing version. Campaigns retain their purchase-time price, currency, duration, and pricing version forever.

## 8. Promotion marketplace and auction

A mature marketplace may allocate limited placements using bid, relevance, quality, predicted CTR, predicted conversion, business quality, and user-experience constraints. Highest bid must not automatically win. Pure pay-to-win ranking risks poor results, low trust, abuse, and concentration of visibility.

## 9. Analytics required before V2

Before CPC or CPA decisions, collect reliable events for impressions, clicks, CTR, detail views, add-to-cart, booking starts, completed bookings, orders, conversion rate, attributed GMV, campaign spend, and ROAS. Break down by target type, sector, category, city, placement, plan, and campaign. Raw client telemetry is useful for product analytics but is not financial truth.

## 10. ROI / ROAS

Future campaign reporting should show spend, impressions, clicks, CTR, conversions, attributed revenue, and ROAS. Businesses should be able to distinguish exposure from meaningful commercial value and understand attribution windows, cancellations, refunds, and excluded invalid traffic.

M9.6 confirms that V1 uses same-flow commercial attribution with a technical
correlation TTL, while multi-day and multi-touch attribution remain evidence-
based future decisions. Historical policy versioning, bounded reconciliation
health, and operational handling of ambiguous refunds are prerequisites for
any future policy expansion.

## 11. Recommendation and automation

With sufficient data, the system may recommend “Boost this product,” identify high local demand, show category benchmarks, suggest budget changes, or recommend campaign duration. Recommendations must remain advisory until explicit spend limits and authorization are designed.

## 12. Promotion quality score

Future quality scoring may consider listing completeness, image quality, ratings, reviews, availability, response rate, conversion history, and refund/cancellation behavior. Promotion must not let a low-quality, unavailable, or abusive listing dominate solely because money was spent.

## 13. Fraud and abuse prevention

CPC requires self-click detection, repeated-click suppression, bot and invalid-traffic detection, device/session heuristics, refund/reconciliation handling, and campaign abuse detection. These controls are mandatory before CPC billing, not optional hardening after launch.

## 14. Experimentation

The engine should eventually support A/B tests for ranking lift, pricing, plans, and placements. Experiment assignment and exposure must be auditable, and experiments must never mutate payment truth or make historical campaign economics ambiguous.

## 15. Admin pricing control

Authorized staff should eventually create plan versions, disable plans, schedule future prices, target plans by sector/category, inspect campaign economics, pause promotion globally, and use emergency kill switches. Every change requires actor, reason, effective time, previous value, new value, and audit log.

## 16. Future AI optimization

Long-term AI assistance could recommend budgets, targeting, bid ranges, duration, listing improvements, and conversion predictions. AI must not autonomously spend business money without explicit authorization, hard limits, reviewable decisions, and an emergency stop.

## 17. Migration triggers from V1 to V2

The V2 decision should be evidence-based, not calendar-based. Review:

- sufficient active and completed campaigns across target types;
- enough impressions and valid clicks to estimate CTR with stable confidence;
- enough detail views, bookings, and orders to measure conversion by category/city;
- stable campaign, target, and event attribution;
- proven provider payment and refund reconciliation;
- fraud controls capable of identifying invalid clicks;
- enough traffic in each category/city for meaningful competition signals;
- acceptable user-experience and seller-concentration outcomes;
- support/admin ability to explain spend and attribution.

The review should compare confidence intervals, data quality, missing-event rates, refund rates, invalid-traffic rates, and operational incident history. Do not set arbitrary universal numeric thresholds before those distributions are observed.

## 18. Architecture invariants

Future work must preserve:

- server authority;
- immutable historical price snapshots;
- provider/payment financial truth;
- explicit campaign state transitions;
- expiry correctness independent of cleanup;
- no client activation, ranking, or price control;
- organic relevance protection;
- diversity and owner/business saturation controls;
- idempotent financial operations;
- auditability;
- backward-compatible pricing-model evolution.

## 19. Do-not-build-yet list

Intentionally deferred from V1:

- CPC billing;
- auction engine;
- CPA billing;
- dynamic bidding;
- dynamic pricing;
- AI bid optimization;
- automatic budget spending;
- Business Boost customer UI;
- advanced attribution;
- complex fraud scoring.

These are planned extension points, not missing V1 implementation bugs.

## 20. Evolution map

```text
V1
Fixed Duration
Pet + Product + Service
        ↓
Data Collection / Attribution
        ↓
Commercial Validation
        ↓
V2
Budget + CPC
        ↓
Dynamic Bidding / Quality Score
        ↓
CPA / Booking-Based Promotion where appropriate
        ↓
Business Promotion
        ↓
Optimization / Recommendation
        ↓
Mature Promotion Marketplace
```

This map is strategic direction, not a committed release schedule.

## M4-derived compatibility exit conditions

M4 adds a concrete prerequisite for eventual legacy cleanup: before the
`isSponsored`, `boostScore`, `boostExpiresAt`, and `sponsorshipType` fields can
be ignored or removed, the project must inventory historical records, decide
the disposition of records without payment evidence, confirm every ranking and
admin reader has moved to Promotion state, and collect migration telemetry.
The compatibility reader must remain until those checks and a rollback
snapshot are complete. This is a migration trigger, not an implementation of
future CPC, dynamic pricing, Business Boost, or optimization functionality.
