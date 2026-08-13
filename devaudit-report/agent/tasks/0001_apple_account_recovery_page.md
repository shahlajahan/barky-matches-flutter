# Task 0001: lib/apple_account_recovery_page.dart

## Target file

lib/apple_account_recovery_page.dart

## Findings

- `24:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Welcome to PetSupo') `[flutter.localization.hardcoded-ui-string]`
- `29:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ("This Apple account hasn't been set up yet.") `[flutter.localization.hardcoded-ui-string]`
- `34:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ("If you're new to PetSupo, create a new account.\n\n" "If you've used PetSupo before, sign into your existing account " "and we'll connect your Apple ID.") `[flutter.localization.hardcoded-ui-string]`
- `43:35` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Create New Account') `[flutter.localization.hardcoded-ui-string]`
- `50:35` **warning** Probable user-visible hardcoded string in Text(data: ...). ('I Already Have a PetSupo Account') `[flutter.localization.hardcoded-ui-string]`
- `137:40` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Sign in to PetSupo') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
