# Task 0040: lib/ui/vet/vet_appointment_page.dart

## Target file

lib/ui/vet/vet_appointment_page.dart

## Findings

- `227:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ("${_safeNum(service['durationMin'])} min") `[flutter.localization.hardcoded-ui-string]`
- `551:49` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Yes') `[flutter.localization.hardcoded-ui-string]`
- `564:49` **warning** Probable user-visible hardcoded string in Text(data: ...). ('No') `[flutter.localization.hardcoded-ui-string]`
- `580:55` **warning** Probable user-visible hardcoded string in InputDecoration(hintText: ...). ('Select an option') `[flutter.localization.hardcoded-ui-string]`
- `630:23` **warning** Probable user-visible hardcoded string in InputDecoration(hintText: ...). ('Enter details') `[flutter.localization.hardcoded-ui-string]`
- `736:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Please select a future date and time.') `[flutter.localization.hardcoded-ui-string]`
- `756:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Please complete required pre-visit questions.') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
