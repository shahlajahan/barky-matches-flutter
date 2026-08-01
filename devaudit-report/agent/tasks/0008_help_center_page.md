# Task 0008: lib/ui/help/help_center_page.dart

## Target file

lib/ui/help/help_center_page.dart

## Findings

- `280:23` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Help Center") `[flutter.localization.hardcoded-ui-string]`
- `291:23` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Need help with PetSupo? Find answers and contact support easily.") `[flutter.localization.hardcoded-ui-string]`
- `335:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Frequently Asked Questions") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
