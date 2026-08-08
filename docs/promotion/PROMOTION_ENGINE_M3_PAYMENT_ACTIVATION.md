# Promotion Engine M3 — Payment and Server-Authoritative Activation

Status: implemented in the repository as a server-side M3 foundation. No production payment, plan, campaign, migration, ranking rollout, deployment, commit, or push was performed.

## 1. Payment infrastructure audited

The existing Functions payment implementation was traced before M3 changes:

- `createIsbank3DPayHostingCheckoutResult` builds the existing İş Bank 3-D Pay Hosting form and uses the existing configured gateway, callback URLs, store type, currency, and secret parameters.
- `isbank3DPayHostingCallback` validates the existing provider Hash V3 response, merchant identity, order identifier, amount, currency, `mdStatus`, `ProcReturnCode`, and approval response before finalization.
- Existing marketplace and subscription flows contain provider transaction identifiers, callback retry behavior, payment status readers, idempotent callback claims, and amount/currency checks.
- Existing iyzico checkout-form initialization and server-side retrieval/verification are used by the Promotion adapter for V1 provider verification.

### Reused components

- Firebase callable Functions conventions and `HttpsError` handling.
- Existing `PAYMENT_PROVIDER` selection and provider secrets.
- Existing İş Bank checkout builder and callback hash/approval validators.
- Existing `Iyzipay` SDK configuration pattern and checkout-form retrieval API.
- Existing structured `logger` convention.

### Promotion-specific components

- `functions/src/promotion/promotion_engine.js` owns target eligibility, plan resolution, immutable pricing snapshots, idempotency reservation, activation, failure state, and safe status projection.
- `promotion_campaigns/{campaignId}` remains Promotion financial/lifecycle truth.
- `promotion_active/{campaignId}` is created atomically with activation and contains no payment secrets or provider transaction data.
- `createPromotionCheckout`, `verifyPromotionPayment`, and `readPromotionPaymentStatus` are Promotion-specific callable entry points.

### Not reused

Promotion does not write `orders`, `sellerOrders`, subscriptions, inventory, marketplace settlement records, or appointment payment state. Those schemas have unrelated lifecycle semantics and remain unchanged.

## 2. Lifecycle

```text
REQUEST
  ↓ authenticated callable
TARGET OWNERSHIP / ELIGIBILITY
  ↓
AUTHORITATIVE PLAN RESOLUTION
  ↓
IMMUTABLE PRICE + DURATION SNAPSHOT
  ↓
PENDING_PAYMENT + DETERMINISTIC IDEMPOTENCY RESERVATION
  ↓
EXISTING PROVIDER CHECKOUT
  ↓
TRUSTED HASH / PROVIDER VERIFICATION
  ↓
ATOMIC ACTIVATION TRANSACTION
  ├─ promotion_campaigns → ACTIVE
  └─ promotion_active → created
  ↓
SERVER-DERIVED EXPIRY
```

The client never supplies an authoritative amount. Client redirects and client success results are not payment proof.

## 3. Ownership and target resolution

| Target | Resolver | V1 decision |
|---|---|---|
| PET | `dogs/{targetId}`, owner from `ownerId` or legacy `ownerUid`; hidden/removed targets rejected | Supported |
| PRODUCT | `businesses/{businessId}/products/{targetId}`; business owner from `ownerUid`/`uid`/`ownerId`; product must be `isActive == true`; business must be eligible/public according to present fields | Supported |
| SERVICE | `businesses/{businessId}/services/{serviceId}`; Promotion target is the canonical `service/{SECTOR}/{businessId}/{serviceId}` identity; same business-owner check; service must be active | Supported by M7 for Vet/Groomy |
| BUSINESS | Explicitly rejected before purchase; no customer-facing Business plan | Disabled |

Product and Service requests require `businessId` because the repository stores them in nested subcollections and a target ID alone is ambiguous. Ambiguous, missing, mismatched, unpublished, inactive, hidden, or owner-mismatched targets fail closed.

## 4. Price authority and checkout

The request contains `targetType`, `targetId`, `planId`, `idempotencyKey`, and `businessId` where required. The server loads `promotion_plans/{planId}`, validates V1 `FIXED_DURATION`, enabled state, target type, TRY currency, duration, and Business disablement, then snapshots:

- `planId`
- `pricingVersion`
- `durationHours`
- `currency`
- `price`
- server-derived `rankingWeight`

The snapshot is immutable for the payment attempt and is the expected amount for later provider verification. A client-supplied fake price is ignored because no client price field is consumed.

## 5. Idempotency

The campaign ID is deterministic: SHA-256 of `ownerUid|idempotencyKey`, with a stable `promotion_` prefix. A repeated callable request returns the existing pending checkout or active result. A short Firestore checkout lease prevents concurrent duplicate provider initialization; a provider checkout is stored before the response is returned. Provider callbacks use the campaign/provider transaction identity, and activation treats a repeated identical transaction as `already_processed`.

This protects button retries, network retries, duplicate callable invocations, callback retries, and success-page refreshes. A provider-side duplicate-charge guarantee remains a production configuration/reconciliation requirement and must be verified before launch.

## 6. Payment verification

For İş Bank, the existing callback route performs the existing mandatory Hash V3 validation first. Promotion then additionally requires matching campaign order ID, merchant identity, expected amount, TRY currency, provider approval fields, and provider transaction identity.

For iyzico, `verifyPromotionPayment` retrieves the stored checkout token through the server SDK and accepts only a successful provider response. It compares the provider paid amount and currency with the campaign snapshot before activation.

Unverified, failed, mismatched-amount, mismatched-currency, mismatched-order, mismatched-provider, and conflicting-transaction results never activate a campaign. Failure records contain only a bounded normalized failure code; raw callback payloads and secrets are not stored by the Promotion path.

## 7. Atomic activation

`activatePromotionFromVerifiedPayment` uses one Firestore transaction. It reads the campaign, checks the pending state and provider evidence, then writes both:

1. `promotion_campaigns/{campaignId}` as `active`, with `paidAt`, `verifiedAt`, `activatedAt`, `startsAt`, and `expiresAt` assigned by the server; and
2. `promotion_active/{campaignId}` with target identity, bounded ranking weight, placement policy, label, and the same time window.

`startsAt` is the trusted server activation time. `expiresAt` uses the snapshotted duration, not mutable current plan data. The projection contains no price, payment token, provider transaction ID, or raw payment payload. Readers must still enforce the time window; cleanup is not correctness.

## 8. Failure handling and status

Checkout initialization failures and explicit provider failures transition non-terminal campaigns to `failed` with a safe normalized `failureCode`. A failed campaign is never activated or projected. A new attempt uses a new idempotency key, preserving the old campaign audit trail and price snapshot.

`readPromotionPaymentStatus` returns only the authenticated owner’s campaign ID, target identity, campaign status, payment status, and server timestamps. It does not expose provider secrets, hashes, checkout payloads, or other users’ campaigns.

## 9. Security guarantees

M2 Rules remain deny-by-default for campaign, plan, and active-projection writes. The Promotion callables use Admin SDK writes after server validation. Emulator coverage proves unauthenticated creation denial, self-activation denial, authoritative-field denial, private campaign read isolation, and safe plan/projection reads. No Rules relaxation was introduced.

## 10. Tests added

- `functions/test/promotionM3.test.js`: PET/Product/Service ownership, plan pricing, fake-price rejection by omission, Business disablement, missing/ambiguous/non-owner targets, pending checkout, duplicate checkout idempotency, unverified payment, amount/currency mismatch, activation timestamps, immutable snapshot, atomic projection, duplicate callback behavior, failure state, and status-reader isolation.
- `functions/test/promotionRules.test.js`: M3 security cases for unauthenticated writes, self-activation, authoritative fields, private campaign reads, and safe reads.
- Existing `functions/test/promotionContract.test.js` remains green.
- `test/promotion/promotion_models_test.dart` remains green; the client transport is `lib/promotion/services/promotion_checkout_service.dart`.

## 11. Known limitations

- No live provider credentials or real payment request was used.
- The existing provider configuration must be production-verified before enabling customer traffic.
- The Promotion iyzico return is verified by the server callable after the browser flow; a dedicated provider callback endpoint can be added after production callback requirements are confirmed.
- Service eligibility currently fails closed on the concrete nested service model but does not yet model sector-specific capacity/availability rules.
- Business Boost, ranking integration, analytics, refund/reconciliation, migration, and UI remain out of scope.

## 12. Explicit M4 handoff

M4 may migrate legacy Pet Boost only after a separate review. It must not weaken M3 authority, must preserve legacy fields during compatibility rollout, and must replace legacy ranking authority deliberately. M3 does not change the existing Pet Boost UI, legacy sponsorship fields, or ranking behavior.
