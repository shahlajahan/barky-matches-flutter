# Task 0014: lib/ui/pet_taxi/pet_taxi_booking_detail_page.dart

## Target file

lib/ui/pet_taxi/pet_taxi_booking_detail_page.dart

## Findings

- `32:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Cancel booking?') `[flutter.localization.hardcoded-ui-string]`
- `33:29` **warning** Probable user-visible hardcoded string in Text(data: ...). ('The taxi business will be notified.') `[flutter.localization.hardcoded-ui-string]`
- `37:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Keep') `[flutter.localization.hardcoded-ui-string]`
- `41:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Cancel booking') `[flutter.localization.hardcoded-ui-string]`
- `118:55` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Payment successful') `[flutter.localization.hardcoded-ui-string]`
- `138:55` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Payment successful') `[flutter.localization.hardcoded-ui-string]`
- `142:55` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Payment cancelled') `[flutter.localization.hardcoded-ui-string]`
- `151:53` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Payment cancelled') `[flutter.localization.hardcoded-ui-string]`
- `158:47` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Payment failed: $e') `[flutter.localization.hardcoded-ui-string]`
- `179:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ('No') `[flutter.localization.hardcoded-ui-string]`
- `183:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Yes') `[flutter.localization.hardcoded-ui-string]`
- `215:40` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Pet Taxi Booking') `[flutter.localization.hardcoded-ui-string]`
- `223:39` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Booking error: ${snapshot.error}') `[flutter.localization.hardcoded-ui-string]`
- `229:45` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Booking not found') `[flutter.localization.hardcoded-ui-string]`
- `293:36` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Updating...') `[flutter.localization.hardcoded-ui-string]`
- `294:36` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Cancel booking') `[flutter.localization.hardcoded-ui-string]`
- `370:13` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Pet Taxi payment') `[flutter.localization.hardcoded-ui-string]`
- `374:16` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Final price: ${_finalPriceText(data)}') `[flutter.localization.hardcoded-ui-string]`
- `377:13` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Payment is required before the trip starts. Provider payout is prepared after trip completion.') `[flutter.localization.hardcoded-ui-string]`
- `395:37` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Reject') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
