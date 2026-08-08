# Promotion Engine M4 — Legacy Pet Boost Migration

Status: implemented locally. This milestone changes new Pet Boost purchase and
activation authority only. It does not migrate production data, delete legacy
fields, enable Business Boost, or change Product/Service UI.

## 1. Legacy Pet Boost found

The executable path was:

```text
PetCard Boost sheet
  ↓
lib/dog_card.dart _boostDog
  ↓
client update dogs/{dogId}
  ↓
isSponsored / boostScore / boostExpiresAt / sponsorshipType
  ↓
playmate_page.dart _calculateDogScore
```

The old client path did not create a payment attempt. Firestore Rules already
allowed only `ownerProfile`, `ownerProfileUpdatedAt`, and `updatedAt` for
ordinary owner Pet updates, so those legacy promotion fields were not safely
client-writable.

## 2. Legacy fields, writers, and readers

Legacy fields retained for compatibility are:

- `isSponsored`
- `boostScore`
- `boostExpiresAt`
- `sponsorshipType`

The old writer was the Boost action in `lib/dog_card.dart`; it no longer writes
any of these fields. Existing model deserialization remains intact so old
records can be displayed during the compatibility period. The primary ranking
consumer was `lib/playmate_page.dart`; it now uses `PetPromotionState`.

## 3. New M4 purchase path

```text
BEFORE
Pet UI → direct legacy dog update → legacy fields → Pet ranking

AFTER M4
Pet UI
  ↓
server PromotionPlan reader (display only)
  ↓
createPromotionCheckout(targetType=PET, targetId, planId)
  ↓
verified provider payment
  ↓
PromotionCampaign ACTIVE + promotion_active (atomic server write)
  ↓
PetPromotionState compatibility reader
  ↓
existing Pet ranking semantics
             ↖
       legacy fallback
       existing records only
```

The checkout callable ignores client price fields. Price, currency, duration,
pricing version, activation time, expiry, and ranking weight remain server
authoritative. Redirects are only navigation events; the client reads server
payment status before showing an active Boost.

## 4. Compatibility and precedence

`PetPromotionState.resolve` applies this explicit rule:

1. A valid PET Promotion projection whose server timestamps contain `now` wins.
2. Otherwise, an unexpired legacy record with `isSponsored == true` and a
   valid `boostExpiresAt` is the temporary fallback.
3. Otherwise the Pet is organic.

The resolver returns one state and one ranking weight, not an additive list.
Thus a Pet with both a legacy record and a new campaign receives one bounded
promotion lift. Expired Promotion projections and expired legacy records do
not rank as active. Expiry is checked at read/ranking time and does not depend
on cleanup.

## 5. UI integration and states

The existing Boost sheet now reads enabled PET fixed-duration plans and sends
only `targetType`, `targetId`, `planId`, and an idempotency key to the M3
checkout service. The hosted provider flow reuses existing checkout presenters.
The UI prevents duplicate submissions, closes the sheet before payment, and
reconciles the return through `readPromotionPaymentStatus`. A redirect alone
never writes Pet state or displays confirmed activation.

V1 Pet prices remain 29 TRY / 69 TRY / 129 TRY for 24 hours / 3 days / 7 days.

## 6. Security changes

- No client code writes authoritative legacy Boost fields for new purchases.
- Promotion campaign and `promotion_active` writes remain backend-only.
- Existing dog Rules were preserved because they already deny sponsorship-field
  mutation while allowing ordinary owner profile edits.
- Promotion target ownership is resolved server-side from `dogs/{id}.ownerId`.

## 7. Tests

Added/updated focused coverage for normalized precedence, legacy expiry,
Promotion expiry, PET checkout ownership and server pricing, verified PET
activation/projection, duplicate callbacks, direct legacy-field forgery, and
ordinary Pet profile edits. Existing M3 callable and Rules tests remain part of
the focused validation set.

## 8. Retained and non-authoritative legacy components

Legacy Pet fields, model properties, and historical records are intentionally
retained for compatibility. They are no longer authoritative for new purchase
activation and are not written by the new UI. No production backfill or field
deletion was performed.

## 9. Future cleanup

Before removing the compatibility reader, the project still needs a read-only
legacy inventory, support disposition for records without payment evidence,
migration telemetry, ranking-consumer confirmation, and a rollback snapshot.
Only then may legacy fields be made inert or removed.

## 10. M5 handoff

M5 remains the broader Pet ranking/relevance hardening milestone. M4 changes
only the promotion signal source and compatibility precedence; it does not
redesign global ranking, add auctions, or add analytics/attribution.
