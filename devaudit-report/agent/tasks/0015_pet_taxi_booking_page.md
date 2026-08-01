# Task 0015: lib/ui/pet_taxi/pet_taxi_booking_page.dart

## Target file

lib/ui/pet_taxi/pet_taxi_booking_page.dart

## Findings

- `418:42` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Book Pet Taxi') `[flutter.localization.hardcoded-ui-string]`
- `607:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ('PetSupo only provides booking infrastructure. Transportation responsibility belongs to the provider.') `[flutter.localization.hardcoded-ui-string]`
- `620:29` **warning** Probable user-visible hardcoded string in Text(data: ...). ('I confirm my pet is safe for transportation.') `[flutter.localization.hardcoded-ui-string]`
- `628:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Required') `[flutter.localization.hardcoded-ui-string]`
- `652:14` **warning** Probable user-visible hardcoded string in Semantics(label: ...). ('Pet taxi business summary') `[flutter.localization.hardcoded-ui-string]`
- `736:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ('No pets found. Add a pet profile before booking.') `[flutter.localization.hardcoded-ui-string]`
- `741:14` **warning** Probable user-visible hardcoded string in Semantics(label: ...). ('Select pet for taxi booking') `[flutter.localization.hardcoded-ui-string]`
- `757:54` **warning** Probable user-visible hardcoded string in InputDecoration(labelText: ...). ('Pet') `[flutter.localization.hardcoded-ui-string]`
- `822:20` **warning** Probable user-visible hardcoded string in Semantics(label: ...). ('Select pickup date and time') `[flutter.localization.hardcoded-ui-string]`
- `837:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Select a future pickup date and time') `[flutter.localization.hardcoded-ui-string]`
- `900:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Required') `[flutter.localization.hardcoded-ui-string]`
- `919:14` **warning** Probable user-visible hardcoded string in Semantics(label: ...). ('Booking summary') `[flutter.localization.hardcoded-ui-string]`
- `931:19` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Booking Summary') `[flutter.localization.hardcoded-ui-string]`
- `964:15` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Estimated based on Istanbul taxi tariff + pet transport service premium. Bridge, highway, waiting and provider-specific fees may be added. Final price will be confirmed by provider.') `[flutter.localization.hardcoded-ui-string]`
- `976:14` **warning** Probable user-visible hardcoded string in Semantics(label: ...). ('Estimated pet taxi price range') `[flutter.localization.hardcoded-ui-string]`
- `990:21` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Estimated Price') `[flutter.localization.hardcoded-ui-string]`
- `1000:23` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Select pickup/dropoff locations and pickup time to calculate a real driving-route estimate.') `[flutter.localization.hardcoded-ui-string]`
- `1014:23` **warning** Probable user-visible hardcoded string in Text(data: ...). ('${estimate.approximateDistanceKm} km driving route • ${_routeEstimate?.durationMinutes ?? '-'} min. Estimated based on Istanbul taxi tariff + pet transport service premium. Bridge, highway, waiting and provider-specific fees may be added. Final price will be confirmed by provider.') `[flutter.localization.hardcoded-ui-string]`
- `1066:18` **warning** Probable user-visible hardcoded string in Semantics(label: ...). ('Create pet taxi booking') `[flutter.localization.hardcoded-ui-string]`
- `1107:26` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Creating booking...') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
