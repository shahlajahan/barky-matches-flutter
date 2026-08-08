# Promotion Engine M10.5 — Final Production Readiness Gate

## Result

The local Promotion implementation passes its focused test and Rules gates,
but production rollout is **NO-GO until external production configuration and
plan provisioning are completed and verified**. No production data was read or
changed by this milestone.

The former 35/36 failure was a test-fixture assertion defect. The fixture had a
valid campaign/target/owner/business/interaction relationship and supplied a
USD source against a TRY campaign, so `currency_mismatch` is the intended
specific rejection. The test now asserts that result. A clean combined run is
38/38.

## PRE-DEPLOY checklist

- [x] Promotion server contract, M3–M10, and M10.5 provisioning tests pass.
- [x] Rules emulator coverage passes for Promotion, Pet migration, and analytics.
- [x] Promotion queries require no composite index beyond Firestore automatic
  single-field indexes; no index was added.
- [x] Owner and admin callable authorization was audited.
- [x] Client writes to campaign, plan, projection, event, stats, attribution,
  and reconciliation collections are blocked.
- [x] PET, PRODUCT, VET, and GROOMER ownership/eligibility tests pass.
- [x] Expiry is checked at ranking, projection/event, and attribution paths;
  cleanup is storage hygiene, not correctness.
- [x] Overlap and idempotency protections are covered.
- [x] Performance reader is owner-scoped and aggregate-only.
- [x] Provider endpoint is explicit for Promotion iyzico; sandbox remains the
  safe default.
- [ ] Provision production secrets/configuration and verify them without
  logging values.
- [ ] Provision approved production plans using the dry-run/idempotent script.
- [ ] Verify provider callback URLs and live merchant endpoint with payment
  operations.

## Payment and provider configuration

Promotion reuses existing İş Bank and iyzico primitives. It does not add a
second merchant configuration. Required configuration is:

- iyzico: `IYZICO_API_KEY`, `IYZICO_SECRET_KEY`, and
  `PROMOTION_IYZICO_API_URI`; the code default is sandbox and must be replaced
  explicitly for live Promotion.
- İş Bank: existing `ISBANK_CLIENT_ID`, `ISBANK_STORE_KEY`, API credentials,
  gateway/API URLs, callback base URL, store type, currency code, and
  installment settings. Production values must be provisioned through the
  existing secret/configuration system.
- `PAYMENT_PROVIDER` selects the existing adapter.

The checkout server selects plan price/currency, binds the deterministic
campaign ID and provider order ID, and verifies provider amount, currency,
transaction identity, and status before atomic activation. Browser return is
never activation authority. Repeated callbacks are idempotent.

The iyzico Promotion buyer payload no longer uses placeholder identity, phone,
address, city, or IP values. Checkout now fails safely when required verified
billing/profile data or the callable request IP is unavailable. This is a
deliberate fail-closed production condition, not a client-controlled fallback.

## Production plan provisioning

`functions/scripts/provisionPromotionPlans.js` defines canonical, deterministic
V1 documents:

| Target | Plan IDs | Prices (24h / 3d / 7d) |
| --- | --- | --- |
| PET | `pet_24h_v1`, `pet_3d_v1`, `pet_7d_v1` | 29 / 69 / 129 TRY |
| PRODUCT | `product_24h_v1`, `product_3d_v1`, `product_7d_v1` | 39 / 89 / 169 TRY |
| SERVICE | `service_24h_v1`, `service_3d_v1`, `service_7d_v1` | 49 / 119 / 219 TRY |
| BUSINESS | reserved V1 IDs | disabled |

Every plan includes `FIXED_DURATION`, TRY, `pricingVersion: 1`, enabled state,
bounded ranking lift, display order, and concurrency limits. The script is
dry-run by default, refuses mismatches/overwrites, refuses enabled BUSINESS,
and requires `PROMOTION_PLAN_PROVISION_CONFIRM=I_UNDERSTAND` for apply. It was
not run against production.

Campaigns snapshot price, currency, duration, and pricing version. Later plan
changes cannot change historical campaign economics.

## Rules, exports, and indexes

Rules permit safe plan/projection reads and owner campaign/stats reads. They
deny all client writes to authoritative Promotion collections. Raw events,
attributions, and reconciliation cases are backend/admin-only.

Exports audited:

- authenticated owner: `createPromotionCheckout`,
  `verifyPromotionPayment`, `readPromotionPaymentStatus`,
  `readPromotionCampaignStats`, and best-effort `recordPromotionEvent`;
- admin only: `readPromotionReconciliationHealth`;
- internal backend triggers: Product, Vet, and Groomy reconciliation document
  handlers;
- provider callback: existing `isbank3DPayHostingCallback`, which routes
  Promotion callbacks through the shared verified path.

No accidental test/debug Promotion export was found. Promotion queries use
document IDs or single-field filters (`targetId`, `campaignId`, `status`), so
no Promotion composite index is currently required. No index was added.

## Correctness and failure review

- Expired/future projections receive no lift; delayed cleanup cannot preserve
  ranking eligibility.
- PET Promotion and legacy Pet fallback do not stack.
- PRODUCT and SERVICE active overlap is rejected server-side.
- Expired campaigns permit future promotion.
- Deleted/disabled targets fail eligibility and cannot be activated through a
  client redirect.
- Provider timeout, missing return, and downstream analytics failure are
  retryable without changing payment truth.
- Wrong amount/currency/provider identity, unauthorized owner, malformed target,
  and invalid callback are blocked.
- Missing stats produce safe normalized semantics; they do not expose raw
  financial records.
- Pending/failed/ambiguous reconciliation remains non-final and observable
  through bounded admin health. Ambiguous cases are never guessed.

## Logging and secrets

Promotion operational logs use stable campaign/target/source identifiers and
status/error categories. The Promotion path does not log secrets, card data,
customer PII, or provider secret values. Shared legacy İş Bank diagnostic code
has forensic capture disabled; the normal safe callback log is allow-listed.
Provider transaction IDs are operational identifiers, not owner-facing data.

## DEPLOY (not executed)

The future rollout must use a scoped deployment manifest, never a broad
`firebase deploy`:

- Functions: the Promotion callables, three reconciliation triggers, and the
  existing İş Bank callback listed above.
- Rules: deploy only after reviewing the mixed `firestore.rules` diff.
- Indexes: no Promotion index deployment currently required.
- Plans: run the provisioning script only after a production dry-run review.
- Flutter: release the client only if the matching server callable/config
  versions are deployed; no separate web deployment is required for the
  current performance page.

## POST-DEPLOY VERIFY (not executed)

Verify a controlled internal campaign: server-priced checkout, provider
verification, atomic activation, projection visibility, expiry, owner stats
read, reconciliation health, and callback retry. Monitor unauthorized checkout
attempts, callback failures, activation failures, stuck projections,
reconciliation health, owner read authorization, and unexpected Rules denials.

## Rollback / kill switch

New purchases can be stopped by backend/admin disabling all enabled PET,
PRODUCT, and SERVICE plan documents through the provisioning/admin workflow.
This preserves existing campaigns, snapshots, stats, and owner reads. There
is no client-only kill switch and no destructive campaign rollback. A future
global atomic kill switch may improve emergency response, but it is not
required to preserve financial truth for this gate.

## Controlled rollout design

1. **Stage 0 — configuration:** provision and verify live provider settings
   and plans; no customer availability.
2. **Stage 1 — internal PET:** one controlled owner, validate payment,
   projection, expiry, and performance read.
3. **Stage 2 — limited PET:** expand only after no authorization, callback,
   or reconciliation anomalies.
4. **Stage 3 — limited PRODUCT:** selected sellers and products, verify stock,
   overlap, item-level attribution, and owner stats.
5. **Stage 4 — limited VET/GROOMY:** selected businesses, verify exact service
   identity, availability, and booking reconciliation.
6. **Stage 5 — broader rollout:** only after operations accepts payment,
   Rules, expiry, reconciliation, and performance-read monitoring.

Each stage has a stop condition for unauthorized campaigns, payment/provider
verification errors, stuck active projections, unresolved reconciliation
growth, owner isolation failures, or unexpected Rules denials. No numeric
threshold is invented here; operations must approve the baseline and alert
thresholds before rollout.

## M11 recommendation

M11 should be **controlled production rollout and operations acceptance**. The
technical local gate is green, but production GO remains blocked until live
provider configuration, callback verification, and plan provisioning are
explicitly completed outside this no-deploy milestone.
