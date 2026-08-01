# Task 0035: lib/ui/support/faq_page.dart

## Target file

lib/ui/support/faq_page.dart

## Findings

- `98:21` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Frequently Asked Questions") `[flutter.localization.hardcoded-ui-string]`
- `109:21` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Find quick answers about PetSupo features, privacy, subscriptions, and safety.") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
