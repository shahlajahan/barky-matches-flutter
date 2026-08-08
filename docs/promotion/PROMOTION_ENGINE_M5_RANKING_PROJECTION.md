# Promotion Engine M5 — Central Ranking and Projection Integration

Status: implemented locally. PET is the first consumer. Product and Service
purchase/UI flows, Business Boost, production migration, and later commercial
ranking models remain disabled.

## 1. Ranking/discovery audit

| Surface | Target | Current inputs/mechanism | Source/sort | Pagination | M5 scope |
|---|---|---|---|---|---|
| Playmate discovery | PET | activity recency, premium owner, legacy Boost; now normalized Promotion state | `dogs` snapshot, client sort | bounded snapshot/local filters | migrated |
| DogCard surfaces | PET | legacy Boost display fields | supplied Dog model | none | compatibility display only |
| Offers manager | non-Promotion offers | `isSponsored`, `priorityScore`, clicks, CTA priority | offers query/client sort | local list | unchanged |
| Featured deals carousel | editorial deal | `featured_deals.order`, active state | Firestore `orderBy` | carousel window | unchanged |
| Vet/Groomy/Hotel/Taxi | SERVICE/domain | `isFeatured`, availability, `sortOrder`, sector logic | surface-specific | surface-specific | unchanged |
| Business discovery | BUSINESS/domain | business `featured`/`featuredScore` and publication fields | surface-specific | surface-specific | unchanged |
| Adoption surfaces | editorial/domain | adoption `isFeatured` and availability | surface-specific | surface-specific | unchanged |

Only Playmate currently consumes Promotion Engine state. The other mechanisms
are not assumed to be paid advertising: they remain editorial, administrative,
availability, or domain-priority behavior until separately approved.

## 2. Central normalized state

`PromotionRankingState` is target-agnostic and supports PET, PRODUCT, SERVICE,
and BUSINESS through the existing `PromotionTargetType` enum. It contains only:

```text
targetType, targetId, isPromoted, campaignId,
rankingWeight, startsAt, expiresAt, source
```

`source` is `PROMOTION_ENGINE`, `LEGACY_COMPATIBILITY`, or `ORGANIC`. It has no
price, payment status, provider data, merchant data, or secret payload.
`PetPromotionState` is now only a compatibility adapter around this generic
state; it is not a second ranking engine.

## 3. Validity and precedence

`promotion_active` is a query/index projection, not proof by document
existence. The normalized state requires matching target type and ID, valid
`startsAt` and `expiresAt`, and `startsAt <= now < expiresAt`. Expiry therefore
remains correct when cleanup is delayed.

For PET, valid Promotion Engine projections win. If none is valid, a valid
unexpired legacy Pet Boost is used. Otherwise the target is organic. Multiple
valid projections for one target select one highest-weight campaign with a
stable campaign-ID tie-breaker; weights never stack.

## 4. Bounded ranking policy

`PromotionRankingEngine` applies the deterministic V1 formula:

```text
finalScore = organicScore + min(validPromotionWeight, 40)
```

Organic relevance remains the base score. The cap prevents an arbitrary or
unbounded sponsored result from becoming an unconditional first-place result.
Equal final scores are ordered by target ID for deterministic behavior within
the loaded bounded set. No auction, bid, dynamic pricing, quality model, or ML
scoring is introduced.

The existing Pet organic inputs remain activity recency and premium-owner
state. Legacy raw Boost values are normalized through the same cap, while their
expiry and Promotion precedence are enforced centrally.

## 5. Diversity and stacking

M5 provides the reusable state and policy boundary for future owner/business
saturation constraints. Playmate has reliable Pet owner IDs, but its current
bounded discovery behavior has no approved product-level diversity policy or
stable cross-surface candidate window. M5 therefore does not silently reorder
or penalize unrelated owners. A future surface may pass owner/business metadata
to the ranking API and add an explicitly configured cap.

Paid Promotion does not absorb editorial `featured`, offer sponsorship,
business flags, adoption flags, availability, or domain priority. Those
semantics remain separate. In particular, an offer's `isSponsored` is not a
Promotion Engine state.

## 6. PET integration

```text
promotion_active
       ↓ one preloaded PET projection query
normalized PromotionRankingState
       ↑
legacy Pet fields (fallback only)
       ↓
PromotionRankingEngine
       ↓
Playmate's existing bounded discovery ordering
```

The Playmate consumer preloads all safe PET projections once per dogs snapshot,
groups them by `targetId`, and performs in-memory normalization/ranking. It
does not read `promotion_campaigns` or payment records per Pet.

## 7. Query complexity and pagination

For N loaded Pets, the current flow performs one `promotion_active` query per
dogs snapshot, zero campaign reads, and zero payment reads. Normalization is
O(N + P) for N Pets and P loaded projections; sorting is O(N log N). The
ranking engine itself performs no network access.

Playmate currently loads a bounded Firestore snapshot and applies local filters
and sorting; it is not a server-paginated promoted search. M5 preserves that
limitation rather than pretending client re-ranking is globally page-correct.
Before Product promotion or hundreds-item server pagination, a shared candidate
projection/query or server-side ranking boundary is required.

## 8. Expiry and clock assumptions

The server assigns campaign timestamps and writes projections atomically. The
client uses its read-time clock only to decide whether a public projection is
currently display/ranking eligible; it does not create financial truth or alter
campaign state. Server-side activation/expiry remains authoritative for paid
state, and cleanup is maintenance only.

## 9. Tests

Focused deterministic tests cover organic/no lift, bounded active lift,
expired/future projections, valid and expired legacy fallback, Promotion
precedence, no stacking, multiple campaigns, stable ties, target identity,
all four target types, and projection financial-data isolation. Existing M3/M4
server and Rules tests remain unchanged and continue to validate the safe
projection contract.

## 10. Known limitations and M6 readiness

No Product, Service, or Business surface consumes this API yet. No owner or
business saturation cap is applied to Playmate because a product-approved
window policy is not present. Large-scale pagination, projection fan-out,
ranking telemetry, and editorial/promotion disclosure remain future work.

M6 can build the next target-specific integration on this normalized state and
ranking boundary without importing Pet models or payment internals.
