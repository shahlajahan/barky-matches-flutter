# Task 0033: lib/ui/shell/barky_scaffold.dart

## Target file

lib/ui/shell/barky_scaffold.dart

## Findings

- `240:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Exit app?') `[flutter.localization.hardcoded-ui-string]`
- `241:29` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Do you want to close Barky?') `[flutter.localization.hardcoded-ui-string]`
- `245:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Cancel') `[flutter.localization.hardcoded-ui-string]`
- `249:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Exit') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
