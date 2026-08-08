# Promotion Engine M11 — Controlled Production Rollout

Status: **PREPARED LOCALLY; PRODUCTION NO-GO**

M11 closes the local rollout-preparation work for the fixed-duration Promotion
Engine. It does not authorize production writes, payment tests, or deployment.
The local server matrix is green, but provider configuration, production plan
provisioning, callback acceptance, and operations acceptance remain external
gates.

## Scope and safety boundary

Enabled rollout targets are PET, PRODUCT, VET SERVICE, and GROOMY SERVICE.
BUSINESS, HOTEL, and TAXI remain disabled. M11 does not add dashboards,
auction/bidding, CPC/CPA, dynamic pricing, or new target types.

No command in this document should be run against production until the
preflight checklist is complete. Never use a broad `firebase deploy`.

## Prerequisites

- Confirm the intended Firebase project with `firebase use --json` and the
  checked-in `firebase.json`; do not infer it from the repository name.
- Obtain approved production provider configuration through the existing
  PetSupo secret/configuration mechanism. Never put secret values in source,
  logs, or this runbook.
- Confirm the public callback route and HTTPS hosting rewrite.
- Run all Promotion server, Rules, provisioning, Flutter, syntax, and diff
  checks with zero known Promotion failures.
- Confirm the Android/iOS client release containing M4–M10 is available before
  enabling owner-facing purchases.
- Obtain operations acceptance for reconciliation health inspection.

## Provider configuration

Promotion reuses the existing İş Bank and iyzico provider identities. Required
values are presence/configuration checks only:

- İş Bank: client identity, store-key/secret references, gateway/API URLs,
  callback base URL, store type, currency, installment setting, and Hash V3
  inputs.
- iyzico: API key/secret references and an explicitly provisioned API URI.

`PROMOTION_IYZICO_API_URI` defaults to the sandbox endpoint for local safety.
The new guard rejects sandbox or non-HTTPS endpoints outside emulator
execution, so production must explicitly provision a live approved endpoint.

## Firebase project and callback verification

The local configuration currently resolves to project `barkymatches-new`.
Before rollout, the operator must independently confirm the active account has
access to that intended production project:

```sh
firebase use --json
firebase functions:list --json
```

Promotion callables and triggers use region `europe-west3`. The İş Bank hosted
callback is the exported `isbank3DPayHostingCallback`, routed by Hosting at:

```text
https://<approved-host>/isbank/3d-callback
```

The handler accepts POST, validates the provider order identity, amount,
currency, merchant identity, Hash V3, and idempotency before atomic campaign
activation. Do not send a fabricated callback. A safe reachability check must
not initiate a payment or mutate Firestore.

## Plan dry-run and provisioning

The deterministic script is:

```sh
FIREBASE_CONFIG='{"projectId":"barkymatches-new"}' \
  node functions/scripts/provisionPromotionPlans.js \
  --project=barkymatches-new
```

This is read-only. It reports missing plans as `created` in dry-run mode,
existing exact plans as `unchanged`, and refuses mismatches. It must complete
cleanly before any apply step.

Only after human review of that output, and only with explicit authorization,
the narrowly scoped write is:

```sh
PROMOTION_PLAN_PROVISION_CONFIRM=I_UNDERSTAND \
FIREBASE_CONFIG='{"projectId":"barkymatches-new"}' \
  node functions/scripts/provisionPromotionPlans.js \
  --project=barkymatches-new --apply
```

Canonical V1 plans are TRY, pricing version 1, fixed duration, ranking lift
40:

| Target | 24 hours | 3 days | 7 days |
|---|---:|---:|---:|
| PET | 29 | 69 | 129 |
| PRODUCT | 39 | 89 | 169 |
| SERVICE | 49 | 119 | 219 |

The three reserved BUSINESS documents are disabled. No enabled HOTEL or TAXI
plans exist. The script never overwrites a mismatched document and never
changes historical campaign snapshots.

## Deployment scope

The exact Promotion Functions scope is:

```text
functions:createPromotionCheckout
functions:verifyPromotionPayment
functions:readPromotionPaymentStatus
functions:recordPromotionEvent
functions:readPromotionCampaignStats
functions:readPromotionReconciliationHealth
functions:reconcilePromotionSellerOrder
functions:reconcilePromotionVetAppointment
functions:reconcilePromotionGroomyAppointment
functions:isbank3DPayHostingCallback
```

The operator must verify the current exported names before using an explicit
`--only` deployment command. Firestore Rules and indexes must be deployed
separately only after their complete diffs are reviewed. The current dirty
`firestore.rules` contains unrelated changes, so a Rules deployment is not
safe until those changes are separated or explicitly reviewed.

No Hosting or Flutter deployment is implied by M11. The client release is a
separate dependency.

## Controlled stages

### Stage 0 — infrastructure only

Verify project, secrets/configuration, callback routing, provider mode, plan
dry-run, Rules/index review, and operations access. No customer purchase.

### Stage 1 — internal PET smoke test

Use one deliberately selected internal-owned Pet; never fabricate a target.
Use the approved 24-hour PET plan at **29 TRY**, if real payment execution is
authorized. Verify server plan pricing, checkout amount/currency, verified
payment, one ACTIVE campaign, one `promotion_active` projection, no legacy
stacking, owner performance read, exposure events, expiry, and repurchase after
expiry. Do not replay callbacks manually.

### Stage 2 — limited PET

Enable only the approved PET owner population. Stop immediately for any
unauthorized campaign, activation/projection mismatch, expiry defect, provider
validation pattern, or reconciliation corruption.

### Stage 3 — selected PRODUCT sellers

Enable only selected sellers after Product ownership, stock/availability,
item-level attribution, and performance-read checks remain green.

### Stage 4 — selected VET/GROOMY businesses

Enable only approved businesses whose service identity, availability, payment,
and reconciliation lifecycle have been accepted independently.

### Stage 5 — broader availability

Expand only after monitoring shows no stop condition and operations can inspect
PENDING, FAILED, and AMBIGUOUS reconciliation health. BUSINESS, HOTEL, and
TAXI remain disabled regardless of rollout stage.

## Monitoring and stop conditions

Operations use the admin-only `readPromotionReconciliationHealth` callable to
inspect bounded counts, oldest unresolved age, affected campaigns, source
types, last attempts, and safe error categories. Raw attribution and provider
payloads are not required for routine monitoring.

Stop new purchases by disabling all enabled Promotion plans if any of these
occur: payment activates the wrong campaign; wrong amount/currency is accepted;
an unauthorized owner succeeds; duplicate active campaigns appear; an expired
projection remains eligible; callbacks fail validation systematically; traffic
uses sandbox; activation occurs without verified payment; clients can mutate
financial fields; reconciliation corrupts totals; cross-owner stats are
readable; or BUSINESS/HOTEL/TAXI becomes purchasable.

## Rollback and kill switch

The V1 kill switch is server-side plan disablement. First disable enabled plans,
then verify checkout rejects new purchases. Do not delete or rewrite campaigns,
stats, attribution records, provider records, or immutable price snapshots.
Existing paid campaigns remain readable and follow their legitimate lifecycle;
any customer-facing handling must be an explicit operations decision.

## Post-deploy verification

For one controlled campaign, inspect only expected safe fields in
`promotion_campaigns/{campaignId}`, the matching `promotion_active` document,
and normalized `promotion_campaign_stats`. Confirm target identity, owner,
historical plan/price/currency/pricing version, payment/campaign state, dates,
projection expiry, and aggregate semantics. Never print provider secrets,
tokens, card data, or customer PII.

## Client release dependency and limitations

M0–M10 remain local/uncommitted in this worktree, so production Android/iOS
client inclusion cannot be proven from this checkout. Backend rollout must stay
dark until the matching client release is verified. There is no time-series
chart/history surface, and production provider/operations acceptance remains
outside this repository-only milestone.
