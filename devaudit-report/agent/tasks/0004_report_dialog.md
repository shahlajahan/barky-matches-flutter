# Task 0004: lib/ui/common/report_dialog.dart

## Target file

lib/ui/common/report_dialog.dart

## Findings

- `38:51` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Report submitted") `[flutter.localization.hardcoded-ui-string]`
- `45:25` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Report") `[flutter.localization.hardcoded-ui-string]`
- `68:57` **warning** Probable user-visible hardcoded string in InputDecoration(hintText: ...). ("Optional description") `[flutter.localization.hardcoded-ui-string]`
- `77:29` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Cancel") `[flutter.localization.hardcoded-ui-string]`
- `82:29` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Submit") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
