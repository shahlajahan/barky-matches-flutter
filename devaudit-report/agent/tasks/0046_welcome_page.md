# Task 0046: lib/welcome_page.dart

## Target file

lib/welcome_page.dart

## Findings

- `246:13` **warning** Probable user-visible hardcoded string in Text(data: ...). ("How would you like to start?") `[flutter.localization.hardcoded-ui-string]`
- `320:29` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Welcome to PetSupo 👋") `[flutter.localization.hardcoded-ui-string]`
- `406:45` **warning** Probable user-visible hardcoded string in Text(data: ...). ("More than an app.\nA home for pets and their people.") `[flutter.localization.hardcoded-ui-string]`
- `499:33` **warning** Probable user-visible hardcoded string in Text(data: ...). ("View Premium Plans") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
