# Task 0038: lib/ui/vet/suggest_clinic_sheet.dart

## Target file

lib/ui/vet/suggest_clinic_sheet.dart

## Findings

- `57:13` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Help us grow PetSopu') `[flutter.localization.hardcoded-ui-string]`
- `65:13` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Suggest $vetName to join PetSopu and help pet owners book appointments more easily.') `[flutter.localization.hardcoded-ui-string]`
- `105:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Share Invitation') `[flutter.localization.hardcoded-ui-string]`
- `116:15` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Maybe Later') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
