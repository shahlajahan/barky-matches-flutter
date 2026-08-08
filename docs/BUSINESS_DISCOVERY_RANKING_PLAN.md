# Business Discovery Ranking Plan

Status: planning only. No ranking behavior is changed by this document.

## Current verified behavior

Petsupo does not currently have one unified Business Discovery Ranking policy.
The customer-facing sectors use different query and client-ordering paths:

| Sector | Current behavior |
| --- | --- |
| VET | `businesses_public`, approved businesses, then client score `rating * 2 - distanceKm`, descending. Missing coordinates receive a very large distance penalty. Review count is not used and there is no deterministic tie-breaker. |
| PET SHOP | `businesses_public`, approved businesses, then the same client score `rating * 2 - distanceKm`, descending. Review count is not used and there is no deterministic tie-breaker. |
| GROOMY | Approved businesses sorted case-sensitively by business name. Location, rating, and reviews do not affect order. |
| PET HOTEL | Approved businesses sorted case-sensitively by business name. Location, rating, and reviews do not affect order. |
| PET TAXI | No ranked customer business list. Available businesses appear as map markers; booking ultimately selects the nearest available business. Rating, reviews, subscription, and promotion do not determine selection. |
| ADOPTION CENTER | Approved adoption-center businesses with no explicit client or server ordering. The list preserves Firestore snapshot order, so there is no application-defined deterministic ranking contract. |

The source paths audited for this baseline are:

- `lib/vet_page.dart`
- `lib/groomy_page.dart`
- `lib/pet_hotel_page.dart`
- `lib/ui/common/pages/petshop_list_page.dart`
- `lib/ui/pet_taxi/pages/pet_taxi_map_page.dart`
- `lib/ui/pet_taxi/repositories/pet_taxi_business_repository.dart`
- `lib/adoption_page.dart`

Verified status currently does not affect these rankings. Premium, Gold, and
subscription status currently do not affect these rankings. Promotion does not
affect organic business ranking. Search generally filters an already ordered
list and must not silently be treated as a new ranking policy. Firestore
snapshot order is an implementation observation, not a ranking strategy.

## Required product separation

These are three different concepts:

1. **Organic Business Ranking** determines natural discovery order.
2. **Business Promotion** is a possible future paid product and requires an
   explicit, disclosed allocation policy.
3. **Service Promotion** is the current M7 product. It uses bounded paid
   Featured Deal inventory and must not silently manipulate organic business
   ranking.

**Paid promotion must never be disguised as organic ranking.** Any future paid
placement inside a business list must be clearly labeled Sponsored/Promoted
and have an explicit allocation policy.

## Future ranking milestone — planning only

A future milestone should evaluate a unified organic ranking model using the
following inputs where they are meaningful for a sector:

- distance;
- rating;
- review confidence and count;
- business availability/open state;
- profile completeness and data quality;
- verification;
- service/category relevance;
- deterministic tie-breaking;
- cold-start handling for new businesses;
- missing-coordinate handling.

Production weights must not be selected arbitrarily. They require product
agreement, data validation, and evaluation against discovery outcomes.

## Open questions

- Should ranking use city boundaries, a distance radius, or both?
- How should high-review incumbents be prevented from permanently dominating
  new businesses?
- Should ratings use Bayesian/confidence-adjusted scoring instead of raw means?
- What deterministic tie-breaker is acceptable across paginated results?
- How should businesses with missing geolocation be handled?
- Should verified status provide an organic trust signal, and under what rules?
- Should availability affect ranking or only eligibility?
- Should category/service match dominate generic popularity?
- How can ranking remain consistent across pagination and cursors?
- What Firestore indexes and query cost are acceptable?
- Should ranking be server-side, client-side, or hybrid?
- What future Business Promotion inventory and fairness policy would be needed?
- Which analytics are required before tuning ranking weights?

This document does not authorize implementation of any of the above.
