# Task 0019: lib/ui/pet_taxi/widgets/pet_taxi_bottom_sheet.dart

## Target file

lib/ui/pet_taxi/widgets/pet_taxi_bottom_sheet.dart

## Findings

- `102:21` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Pet Taxi") `[flutter.localization.hardcoded-ui-string]`
- `111:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Safe & trusted transportation for your pet") `[flutter.localization.hardcoded-ui-string]`
- `158:35` **warning** Probable user-visible hardcoded string in Text(data: ...). ('No pets found') `[flutter.localization.hardcoded-ui-string]`
- `166:35` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Add a pet to request a Pet Taxi ride.') `[flutter.localization.hardcoded-ui-string]`
- `224:37` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Continue") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
