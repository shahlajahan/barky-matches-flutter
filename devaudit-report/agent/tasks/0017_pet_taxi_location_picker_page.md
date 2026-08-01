# Task 0017: lib/ui/pet_taxi/pet_taxi_location_picker_page.dart

## Target file

lib/ui/pet_taxi/pet_taxi_location_picker_page.dart

## Findings

- `90:34` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Location search failed: ${e.toString()}') `[flutter.localization.hardcoded-ui-string]`
- `132:34` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Address lookup failed: ${e.toString()}') `[flutter.localization.hardcoded-ui-string]`
- `164:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Could not load current location: ${e.toString()}') `[flutter.localization.hardcoded-ui-string]`
- `205:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Use Selected Location') `[flutter.localization.hardcoded-ui-string]`
- `242:32` **warning** Probable user-visible hardcoded string in InputDecoration(labelText: ...). ('Search real address') `[flutter.localization.hardcoded-ui-string]`
- `243:31` **warning** Probable user-visible hardcoded string in InputDecoration(hintText: ...). ('Street, building, district') `[flutter.localization.hardcoded-ui-string]`
- `336:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Use My Current Location') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
