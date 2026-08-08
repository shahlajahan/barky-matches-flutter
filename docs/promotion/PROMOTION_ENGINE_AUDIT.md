# PetSupo Promotion / Boost Engine — Current-State Audit

Audit scope: repository-only, read-only architecture audit. No application code, Rules, production data, deployment, commit, or push was performed.

## 1. Executive summary

The repository has a Pet Boost UI and legacy sponsorship fields on `dogs`, but it does not have a functioning paid promotion lifecycle. The client attempts to write activation and ranking fields directly; current Firestore Rules reject those fields for ordinary dog owners. No verified payment-to-activation path for Pet Boost was found. The current result is a broken priced feature rather than a directly exploitable paid-ranking path.

The recommended replacement is one server-authoritative `promotion_campaigns` engine with a fixed-duration V1, a separate server-maintained active-promotion projection, bounded ranking lift, seller/business saturation caps, and provider-neutral reuse of the existing checkout/callback infrastructure. Product and service prices remain unfinalized.

## 2. Repository state

- Branch: `integration/mac-windows-2026-07-22`
- HEAD: `c16ce1be171ffb8d24e19975683d2166915bdff0`
- HEAD subject: `fix: make dashboard metric cards constraint-safe`
- Working tree includes pre-existing modifications to `android/app/google-services.json` and `firestore.rules`, plus pre-existing untracked `docs/PRODUCTION_QA_AUDIT_2026-08-07.md` and `functions/test/userRoleProtectionRules.test.js`. None was changed by this audit.
- `stash@{0}` was not inspected, applied, popped, dropped, or modified.

## 3. Current Pet Boost trace

| Step | Evidence | Finding |
|---|---|---|
| UI entry | `lib/dog_card.dart:462-527` | Three priced choices: 24h/29 TRY, 3d/69 TRY, 7d/129 TRY. |
| Action | `lib/dog_card.dart:591-626` | `_boostDog()` calculates a local expiry and calls `dogs/{dog.id}.update(...)`. |
| Fields attempted | `lib/dog_card.dart:601-606` | `isSponsored`, `boostScore`, `boostExpiresAt`, `sponsorshipType`, `updatedAt`. |
| Payment | `lib/dog_card.dart:591-626`; repository search | No checkout, provider call, payment verification, or promotion Function in this path. |
| Rules | `firestore.rules:458-494` | Owner updates are limited to `ownerProfile`, `ownerProfileUpdatedAt`, and `updatedAt`; sponsorship writes are rejected. Admin writes bypass the owner restriction. |
| Ranking | `lib/playmate_page.dart:668-685` | `isSponsored` adds `boostScore`; `boostExpiresAt` is not independently checked. |
| UI state | `lib/dog_card.dart:255-293` | Sponsorship badge/highlight is derived from legacy dog fields. |

### Answers

1. Choosing a package attempts a direct dog-document update and shows success only if that write succeeds.
2. Under ordinary owner authentication, only permitted profile/update fields can succeed; the sponsorship update is rejected as a whole by Rules.
3. The four sponsorship fields are not owner-writable under current Rules.
4. No money is charged by the Pet Boost path found.
5. No payment provider is involved in that path.
6. A normal user cannot activate a boost through this UI. An admin could write legacy fields, but that is not a verified paid activation system.
7. Yes. Any legacy state that is present can remain stored unless another trusted process clears it.
8. `boostExpiresAt` is not enforced in `playmate_page.dart`; ranking trusts `isSponsored` and `boostScore`.
9. The legacy fields are `isSponsored`, `boostScore`, `boostExpiresAt`, and `sponsorshipType`. They should become compatibility-only during migration and later be removed or made entirely derived.

**Current verdict: P2 product/security-hardening risk, not P1 authorization escalation.** The Rules prevent ordinary client mutation, but the priced feature is nonfunctional and legacy ranking can outlive its intended duration.

## 4. Existing promotion-like systems

| Concept | Entity/collection | Writer | Reader/ranking | Authority | Disposition |
|---|---|---|---|---|---|
| `isSponsored`, `boostScore`, `boostExpiresAt`, `sponsorshipType` | dogs | `lib/dog_card.dart:591-626` client attempt; admin can write by Rules | `lib/playmate_page.dart:668-685`, `lib/dog_card.dart:255-293` | Rules reject owner writes; not server-activated | Migrate, then remove dependence |
| `isSponsored`, `priorityScore`, `clickCount` | `offers` | Admin plus click-count-limited client update | `lib/offers_manager.dart:240`, `:826-844` | Rules restrict writes; offer logic is separate | Keep as legacy editorial/offers system until replaced |
| `featured_deals`, `order`, `isActive` | featured_deals | Admin | `lib/home_page.dart:162-224` | Admin-only writes | Keep as editorial home content, not paid campaigns |
| `featuredScore` | business marketing model | Mapper/defaults and business data | No complete central paid-ranking consumer found | Unclear/dormant | Deprecate or explicitly map into future engine |
| `isFeatured`, `sortOrder` | business services | Service editor/business owner | Vet services tab and service lists | Business owner/editorial | Keep for editorial ordering initially; do not treat as paid authority |
| `featuredVet` | vet marketingPromotions | Vet form | Vet marketing data | Business-controlled marketing flag | Inventory and replace if intended to mean paid promotion |
| `isFeatured` | adoption center | Adoption model/admin data | Adoption UI where used | Administrative/editorial | Keep separate unless product requirements make adoption promotions paid |
| `canBoostVisibility` | subscription entitlement | Subscription state | `lib/subscription/helpers/subscription_access.dart:34-36` | Entitlement-derived | Capability gate only; not activation or payment |

No existing abstraction was found that safely owns paid activation across these entities. Reusing their field names would preserve ambiguity and client/server authority problems.

## 5. Target and ownership audit

- **PET:** `dogs/{dogId}`; owner is represented by `ownerId` and legacy `ownerUid` variants. Canonical target should use `targetType=PET`, `targetId=dogId`, `ownerUid`, with ownership checked against the authoritative field(s).
- **PRODUCT:** canonical marketplace data is nested under `businesses/{businessId}/products`; `lib/services/product_service.dart:40-110` and `lib/models/product.dart:4-12,29-30,94-100` provide stable product IDs and business ownership. Use `targetType=PRODUCT`, `targetId=productId`, `businessId`.
- **SERVICE:** services are nested under `businesses/{businessId}/services/{serviceId}`. Vet, Groomy, and Hotel booking payloads carry `businessId` and `serviceId`; see `lib/ui/vet/vet_appointment_page.dart:779-805`, `lib/ui/business/groomy/groomy_appointment_page.dart:520-536`, and `lib/ui/business/pet_hotel/pet_hotel_booking_page.dart:551-571`. Service IDs should be immutable and title-independent before paid promotion launches.
- **PET TAXI:** use the service target only after the same stable service identity and booking contract are confirmed for that sector.
- **ADOPTION:** do not enable paid promotion by default. Use `BUSINESS` only if the center is the target; an individual adoption listing needs a stable ID, owner, publication state, and explicit policy.
- **BUSINESS:** `businesses/{businessId}` is the owner/admin source; `businesses_public/{businessId}` is the public projection. Use `targetType=BUSINESS`, `targetId=businessId`, `businessId`.

Recommended target reference: `targetType`, `targetId`, `ownerUid`, optional `businessId`, optional `sector`, plus a server-resolved target version/snapshot.

## 6. Payment infrastructure

The existing Functions contain a regional `createCheckoutSession` at `functions/index.js:13064-13134`, configured for `iyzico` or `isbank`, and the Flutter checkout path is in `lib/services/petshop_checkout_service.dart:46-147` and `lib/ui/petshop/widgets/checkout_button.dart:76-104`. İş Bank 3-D Secure functions and callbacks exist around `functions/index.js:2609-2615` and `:3011-3045`. Payment verification functions include `verifyPaymentByOrderId` and `verifyPayment` around `functions/index.js:15173-16785`.

These are reusable provider/callback primitives, not a promotion lifecycle. V1 should create a promotion-specific payment intent/order reference and use a provider adapter around the existing configured checkout path. Do not copy marketplace order state into campaign state, and do not assume the current verification configuration is production-ready without provider-specific runtime verification.

Required sequence: create pending campaign and payment intent → provider checkout → server callback/status verification → idempotent server activation → projection → expiry. Duplicate callbacks must be no-ops after the campaign/payment transition is terminal. Payment success with activation failure must remain an operationally visible `payment_verified_activation_failed`/retriable state, never silently become active.

## 7. Ranking surface inventory

| Surface | Current inputs found | Promotion design |
|---|---|---|
| Playmates/pets | Activity/recency, premium, legacy sponsorship score (`lib/playmate_page.dart:668-685`) | Bounded lift after eligibility and expiry checks; seller/owner caps. |
| Offers/home | `isSponsored`, `priorityScore`, clicks (`lib/offers_manager.dart:826-844`) | Keep editorial legacy separate until migrated. |
| Products | Active/public product and business ownership paths | Candidate pool plus bounded lift; no promoted inactive product. |
| Vet/Groomy/Hotel | Business/service availability, service IDs, ratings/booking context | Service candidate pool; availability and publication remain hard gates. |
| Taxi | Sector-specific service/availability | Same service policy after identity audit. |
| Adoption | Featured/editorial fields | No paid placement until policy and target contract exist. |
| Business discovery | Public business projection | Business-level promotion later, with sector/relevance caps. |
| Global search | Repository has multiple feature-specific readers rather than one central search scorer | Introduce a shared eligibility/lift helper behind server projections, not client-trusted fields. |

Never sort every sponsored item ahead of all organic results. Use `organicScore + boundedPromotionLift`, separate sponsored labeling, maximum consecutive sponsored placements, and per-owner/business saturation limits.

## 8. Rules and authority audit

Current precedents include backend/admin-only subscription writes (`firestore.rules:672-677`), owner-controlled product writes (`:618-635`), and backend-controlled public business projections (`:593-596`). A future promotion Rules design should apply the stricter pattern:

- clients may create a request/pending checkout with validated target ownership;
- clients may read their own campaigns and safe public active summaries;
- clients may not set `active`, `paid`, `verifiedAt`, price, pricing version, rank weight, or trusted expiry;
- plans are admin/backend writable only;
- active projections are backend-only;
- metrics are append-only through a trusted event endpoint or validated server write;
- admin actions require the existing admin authorization helpers and audit records.

## 9. Current risks

### P2 — Pet Boost is nonfunctional and legacy expiry is not enforced

Evidence: `lib/dog_card.dart:591-626`, `firestore.rules:458-494`, `lib/playmate_page.dart:668-685`. Impact: users see paid-looking options but no payment/activation occurs; any old authorized sponsorship can influence ranking past expiry. Minimal safe fix is the central engine and ranking migration, not a direct Rules relaxation.

### P2 — Promotion semantics are duplicated and ambiguous

Evidence: offers, featured deals, business/service/adoption featured fields above. Impact: future implementation could accidentally create parallel authority or inconsistent ranking. Resolve by documenting ownership and migrating only fields that are intentionally paid.

### P3 — Service target identity is not yet fully normalized

Evidence: nested service documents and title-derived new IDs in the vet service editor. Impact: paid campaigns require immutable target IDs and stable publication/availability checks.

## 10. Architecture decision summary

A. Use one central `promotion_campaigns` collection, not per-target campaign collections.

B. Use one `PromotionCampaign` model with `targetType` and target reference fields for Pet/Product/Service/Business.

C. Project active state into a backend-owned `active_promotions` collection and, where useful, safe public projection fields; do not require per-row campaign reads.

D. Integrate ranking as a bounded lift/blended candidate policy, with hard eligibility gates and saturation caps.

E. Deprecate dog sponsorship fields as authority; keep offers/editorial featured fields separate until deliberately migrated.

F. Reuse the existing server checkout/provider/callback infrastructure through a promotion-specific adapter and state machine; provider choice remains subject to production verification.

G. V1 is fixed-duration only. Pet baseline is 29 TRY/24h, 69 TRY/3d, 129 TRY/7d. Product and Service prices are not finalized.

H. Prepare for CPC by versioning `pricingModel`, campaign state, event schema, and budget fields, without implementing CPC billing in V1.

I. Store plans server-side/admin-owned, snapshot plan ID, price, currency, and pricing version onto each campaign.

J. Expiry is harmless if cleanup fails because every ranking/read eligibility check requires `now < expiresAt`; scheduled cleanup is secondary.

K. Prevent monopolization with per-owner/business active-campaign caps, per-target caps, consecutive-slot caps, and bounded lift.

L. Measure ROI with immutable server-attributed events and provider/order reconciliation; do not treat client counters as financial truth.

M. Migrate Pet Boost by introducing campaign authority, shadowing/compatibility reads, replacing ranking reads, disabling legacy writes, then retiring fields.

N. P0 security requirements before launch are server-authoritative payment verification, activation, price/rank/expiry protection, target ownership/publication checks, idempotent callbacks, and ranking expiry enforcement.

## 11. Audit limitations

This is a static repository audit. No production payment, provider callback, campaign, ranking, or admin workflow was executed. Existing Android runtime claims are historical evidence from the prior audit context, not re-run here. Product and Service prices are intentionally unspecified. Existing provider configuration and `verifyPayment` code require a separate credentialed integration test before launch.

## 12. Foundation implementation status

The M0–M2 foundation now adds shared PET/PRODUCT/SERVICE/BUSINESS target, plan, campaign, state-transition, and deterministic expiry contracts under `lib/promotion/models/`, a server-side Firestore plan/state contract under `functions/src/promotion/promotion_contract.js`, and deny-by-default client Rules for `promotion_plans`, `promotion_campaigns`, and `promotion_active`. No payment, target resolver, ranking rollout, migration, or production plan data was added.
