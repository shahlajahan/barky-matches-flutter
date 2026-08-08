# PetSupo Promotion / Boost Engine — Implementation Roadmap

Roadmap only. M0–M6 work is now implemented locally; M7 and all later
milestones remain future work. See the milestone documents under
`docs/promotion/` for the exact boundaries.

## Common delivery gate

Every milestone requires code review, emulator/Rules tests where applicable, structured logs, a kill switch, documented rollback, and no client authority over payment or activation. Existing legacy fields remain untouched until their migration milestone.

## M0 — ADR and contracts

- **Scope/areas:** finalize target identity, campaign state machine, public labels, caps, provider, service ID contract; `docs/promotion/*`.
- **Backend:** approve API/state/ledger contracts.
- **Client:** no runtime change.
- **Rules:** threat-model review only.
- **Indexes:** design campaign/status/expiry indexes.
- **Tests:** architecture examples and threat model.
- **Risk/rollback:** low; reject the ADR without runtime impact.
- **Done:** signed decisions for open questions and no conflicting legacy authority.

## M1 — Promotion core models and plans

- **Scope/areas:** campaign/plan models, validators, fixed-duration Pet plans, versioned price snapshots.
- **Backend:** create/read internal model and plan repository.
- **Client:** status model only, behind flag.
- **Rules:** draft/read boundaries specified and tested in emulator.
- **Indexes:** campaign owner/status, target/status, expiry/status.
- **Tests:** model, validation, price snapshot, unknown-field tests.
- **Risk/rollback:** schema-only; disable feature flag.
- **Done:** no client can supply authoritative price/rank/expiry.

## M2 — Rules and backend authority

- **Scope/areas:** campaign Rules, admin helpers, protected fields, public active projection boundary.
- **Backend:** trusted write helpers and audit records.
- **Client:** request/status reads only.
- **Rules:** owner protected-field denial; admin/backend positive cases.
- **Indexes:** Rules query requirements reviewed.
- **Tests:** emulator matrix for owner/admin/public/anonymous cases.
- **Risk/rollback:** high security risk; keep collection disabled until green.
- **Done:** malicious client cannot activate, reprice, extend, or rank a campaign.

## M3 — Payment and activation state machine — IMPLEMENTED LOCALLY

- **Scope/areas:** promotion checkout, provider adapter, callback, verification, idempotency, reconciliation.
- **Backend:** reuse existing checkout/provider primitives; promotion-specific order references.
- **Client:** checkout return and polling/status UX.
- **Rules:** payment fields backend-only.
- **Indexes:** provider order ID/idempotency key.
- **Tests:** success, duplicate/out-of-order callback, timeout, mismatch, app close, refund.
- **Risk/rollback:** highest financial risk; disable checkout and reconcile before rollback.
- **Done:** only verified payment reaches active, exactly once; campaign and `promotion_active` projection are written atomically. See `PROMOTION_ENGINE_M3_PAYMENT_ACTIVATION.md`.

## M4 — Pet Boost migration — IMPLEMENTED LOCALLY

- **Scope/areas:** replace `lib/dog_card.dart` direct write, dog compatibility, Pet plans, legacy inventory.
- **Backend:** PET ownership/eligibility and campaign activation.
- **Client:** reusable Pet Boost checkout/status components.
- **Rules:** retain denial of legacy sponsorship mutation.
- **Indexes:** dog target lookup and active campaign lookup.
- **Tests:** full Pet purchase and legacy disposition.
- **Risk/rollback:** high product/support risk; kill lift and preserve legacy data.
- **Done:** new Pet Boosts use server plans, verified Promotion activation, the
  active projection, and a single expiry-aware compatibility reader. Legacy
  fields and historical records remain for the compatibility period; no
  production migration was performed. See `PROMOTION_ENGINE_M4_PET_MIGRATION.md`.

## M5 — Central ranking and projection integration — IMPLEMENTED LOCALLY

- **Scope/areas:** target-agnostic normalized ranking state, bounded lift policy,
  projection preload, and `playmate_page.dart` Pet integration.
- **Backend:** active projection and repair.
- **Client:** no trusted ranking fields.
- **Rules:** projection backend-owned.
- **Indexes:** active target/type/expiry.
- **Tests:** expiry, relevance, caps, diversity, stale projection.
- **Risk/rollback:** high discoverability risk; global zero-lift switch.
- **Done:** central ranking state supports PET/PRODUCT/SERVICE/BUSINESS;
  Playmate uses one projection query plus in-memory ranking with expiry and
  legacy fallback safeguards. Product, Service, and Business consumers remain
  disabled. See `PROMOTION_ENGINE_M5_RANKING_PROJECTION.md`.

## M6 — Product Boost — IMPLEMENTED LOCALLY

PRODUCT is now the second real consumer of the target-agnostic Promotion
Engine. Seller Product management uses the generic plan/checkout boundary;
the server resolves nested Product ownership and eligibility, and
`AllProductsPage` consumes PRODUCT projections through the M5 bounded ranking
engine. V1 prices remain 39 / 89 / 169 TRY. Product discovery is currently a
bounded snapshot without pagination; large-scale server-side placement remains
future work. Service and Business Boost remain disabled.

- **Scope/areas:** nested product target, business ownership, active/public product checks.
- **Backend:** PRODUCT validation and campaign activation.
- **Client:** product plan/status UI.
- **Rules:** product owner cannot activate or alter campaign authority.
- **Indexes:** product/business target projection.
- **Tests:** inactive/deleted product, seller caps, order attribution.
- **Risk/rollback:** disable PRODUCT target type.
- **Done:** one product can be promoted without bypassing stock/publication rules.

## M7 — Service Boost integration — IMPLEMENTED LOCALLY

Vet and Groomer/Groomy are enabled as SERVICE consumers using nested service
records and the canonical `service/{SECTOR}/{businessId}/{serviceId}` identity.
The generic plan sheet, M3 checkout/verification, `promotion_active`, and M5
ranking engine are reused. Pet Hotel remains partially ready because its
primary discovery is business-level; Pet Taxi remains deferred because no
individual promotable service entity was found. Business Boost remains
disabled.

- **Scope/areas:** future large-scale Product ranking and pagination-safe
  candidate placement.
- **Status:** not part of M7; Product remains on its bounded M6 surface.

## M8 — Analytics & attribution foundation — IMPLEMENTED LOCALLY

Promotion now has one validated measurement contract for PET, PRODUCT, VET,
and GROOMY. Visibility-based impressions, meaningful clicks, detail views,
projection-bound campaign attribution, immutable raw events, transactional
campaign counters, owner-isolated stats, and snapshot-derived spend are in
place. Product/Vet/Groomy financial conversion triggers remain deliberately
deferred until a versioned attribution window and trusted finalization hooks
are approved. PET revenue is not applicable. Hotel, Taxi, and Business are
rejected as analytics-enabled Promotion targets.

## M9 — Trusted conversion, reconciliation, and performance surface — IMPLEMENTED LOCALLY

- **Scope/areas:** Product order-item attribution, Vet/Groomy appointment
  finalization, refunds, and trusted reconciliation.
- **Backend:** trusted conversion hooks, `promotion_attributions`, and
  delta-based updates to `promotion_campaign_stats`.
- **Client:** no financial event authority.
- **Tests:** order/booking identity, cancellation/refund, attribution, privacy.
- **Risk/rollback:** disable attribution aggregation while preserving payment truth.
- **Done:** supported attributable revenue is explainable without
  client-declared money. No owner dashboard is included; the commercial
  attribution window, ambiguous multi-line refunds, and cross-currency
  attribution remain explicit limitations.

## M10 — Read-only performance UI — IMPLEMENTED LOCALLY

M10 provides an owner-scoped, campaign-centered read-only performance page
using only `readPromotionCampaignStats`. The UI exposes exposure metrics for
PET, PRODUCT, VET, and GROOMY, and shows financial metrics only according to
the server-derived `AVAILABLE`, `PROVISIONAL`, or `UNAVAILABLE` status. It
does not read raw attribution, payment, order, appointment, or operational
reconciliation records. Pet revenue and ROAS remain not applicable.

The first entry point is the confirmed-active post-checkout flow. A broader
campaign history/list and time-series charts remain future work; no raw-event
scan is introduced.

## M10.5 — Final production readiness gate — BLOCKED PENDING EXTERNAL CONFIG

The local Promotion matrix is green and the Rules/export/expiry/ownership
audits pass. M10.5 added a dry-run/idempotent plan provisioning mechanism and
made the Promotion iyzico endpoint an explicit deployment setting. Production
GO remains blocked until live provider secrets/endpoints, callback URLs, and
the approved V1 plan documents are provisioned and verified. No production
data or configuration was changed locally.

M11 remains controlled production rollout and operations acceptance; no rollout
is executed by M10.5.

## M11 — Controlled production rollout — BLOCKED PENDING EXTERNAL GATES

Local M11 preparation is complete: activation revalidates PET, PRODUCT, VET,
and GROOMY eligibility immediately before verified-payment activation;
ownership/availability changes fail closed; the iyzico sandbox endpoint is
rejected outside emulator execution; the combined Promotion server matrix is
45/45 and Rules coverage is 4/4. Production execution remains blocked until
live provider configuration, callback verification, clean plan dry-run and
approved provisioning, matching mobile client release, and operations
acceptance are completed. No production data, plans, Rules, or Functions were
deployed by M11.

- **Scope/areas:** Hotel/Taxi domain readiness, server-side candidate ranking,
  raw-event retention and larger-scale aggregates.
- **Backend:** only after each sector has a canonical promotable entity.
- **Client:** no deferred-sector Promotion UI by implication.
- **Done:** enable sectors independently without weakening the common engine.

## M11 — Admin operations

- **Scope/areas:** campaign console, plans, pause/refund, kill switches, audit logs.
- **Backend:** admin Functions and reconciliation views.
- **Client:** no end-user authority expansion.
- **Rules:** admin role tests.
- **Indexes:** state/owner/provider/date filters.
- **Tests:** authorization, audit completeness, emergency pause.
- **Risk/rollback:** restrict to read-only operations.
- **Done:** support can diagnose and stop any campaign safely.

## M12 — Hardening and release gate

- **Scope/areas:** security, payment, ranking, load/cost, localization, failure recovery.
- **Backend:** alarms, repair jobs, provider reconciliation.
- **Client:** accessibility and failure UX.
- **Rules:** full emulator matrix.
- **Indexes:** explain/query cost review.
- **Tests:** unit, Functions, Rules, integration, abuse/fairness, chaos cases.
- **Risk/rollback:** staged target enablement and kill switch.
- **Done:** P0 security and financial invariants pass; release approval recorded.

## M13 — CPC readiness, not CPC launch

- **Scope/areas:** versioned pricing model, budget/event contracts, fraud/settlement design.
- **Backend:** design only until separately approved.
- **Client:** no CPC UI.
- **Rules:** budget and billing fields protected.
- **Indexes:** event/budget planning.
- **Tests:** contract tests and abuse model, no live billing.
- **Risk/rollback:** omit entirely if fixed-duration needs are sufficient.
- **Done:** future CPC can be added without changing V1 campaign identity or payment truth.
