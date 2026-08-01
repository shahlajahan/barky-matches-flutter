# Task 0007: lib/ui/green_memorial/green_memorial_page.dart

## Target file

lib/ui/green_memorial/green_memorial_page.dart

## Findings

- `44:48` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Memorial created.') `[flutter.localization.hardcoded-ui-string]`
- `110:19` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Green Memorial') `[flutter.localization.hardcoded-ui-string]`
- `118:13` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Plant a tree in memory of your beloved pet.') `[flutter.localization.hardcoded-ui-string]`
- `127:33` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Create Memorial') `[flutter.localization.hardcoded-ui-string]`
- `308:23` **warning** Probable user-visible hardcoded string in Text(data: ...). ('In memory of $petName 🌱') `[flutter.localization.hardcoded-ui-string]`
- `335:21` **warning** Probable user-visible hardcoded string in Text(data: ...). ('By $ownerName') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
