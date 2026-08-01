# Task 0027: lib/ui/screens/dog_parks/saved_parks_page.dart

## Target file

lib/ui/screens/dog_parks/saved_parks_page.dart

## Findings

- `38:19` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Saved Parks') `[flutter.localization.hardcoded-ui-string]`
- `57:23` **warning** Probable user-visible hardcoded string in Text(data: ...). ('No saved parks yet') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
