# Task 0043: lib/user_profile_page.dart

## Target file

lib/user_profile_page.dart

## Findings

- `1233:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Unknown business type → $sectors") `[flutter.localization.hardcoded-ui-string]`
- `1733:33` **warning** Probable user-visible hardcoded string in Text(data: ...). ('English') `[flutter.localization.hardcoded-ui-string]`
- `1741:33` **warning** Probable user-visible hardcoded string in Text(data: ...). ('فارسی') `[flutter.localization.hardcoded-ui-string]`
- `1749:33` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Türkçe') `[flutter.localization.hardcoded-ui-string]`
- `1756:33` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Русский') `[flutter.localization.hardcoded-ui-string]`
- `3009:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ('City') `[flutter.localization.hardcoded-ui-string]`
- `3031:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ('District') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
