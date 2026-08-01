# Task 0021: lib/ui/petshop/petshop_dashboard_page.dart

## Target file

lib/ui/petshop/petshop_dashboard_page.dart

## Findings

- `187:14` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Revenue") `[flutter.localization.hardcoded-ui-string]`
- `192:14` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Daily Summary") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
