# Task 0037: lib/ui/vet/edit_vet_profile_page.dart

## Target file

lib/ui/vet/edit_vet_profile_page.dart

## Findings

- `94:45` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Load error: $e') `[flutter.localization.hardcoded-ui-string]`
- `174:38` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Vet profile updated successfully') `[flutter.localization.hardcoded-ui-string]`
- `181:45` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Save error: $e') `[flutter.localization.hardcoded-ui-string]`
- `231:40` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Edit Vet Profile') `[flutter.localization.hardcoded-ui-string]`
- `268:38` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Save') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
