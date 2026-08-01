# Task 0010: lib/ui/legal/terms_page.dart

## Target file

lib/ui/legal/terms_page.dart

## Findings

- `28:49` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Email copied") `[flutter.localization.hardcoded-ui-string]`
- `64:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Terms of Service") `[flutter.localization.hardcoded-ui-string]`
- `76:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ("By using PetSupo, you agree to the following terms:") `[flutter.localization.hardcoded-ui-string]`
- `117:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ("7. Contact") `[flutter.localization.hardcoded-ui-string]`
- `161:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ("We aim to respond within a reasonable timeframe.") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
