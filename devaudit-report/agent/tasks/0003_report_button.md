# Task 0003: lib/ui/common/report_button.dart

## Target file

lib/ui/common/report_button.dart

## Findings

- `33:29` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Report") `[flutter.localization.hardcoded-ui-string]`
- `41:38` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Select reason") `[flutter.localization.hardcoded-ui-string]`
- `62:34` **warning** Probable user-visible hardcoded string in InputDecoration(labelText: ...). ("Additional details (optional)") `[flutter.localization.hardcoded-ui-string]`
- `73:33` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Cancel") `[flutter.localization.hardcoded-ui-string]`
- `80:33` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Submit") `[flutter.localization.hardcoded-ui-string]`
- `84:50` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Please select a reason") `[flutter.localization.hardcoded-ui-string]`
- `125:59` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Report submitted") `[flutter.localization.hardcoded-ui-string]`
- `129:40` **warning** Probable user-visible hardcoded string in Text(data: ...). ("You already reported this item") `[flutter.localization.hardcoded-ui-string]`
- `136:40` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Too many reports. Try again later.") `[flutter.localization.hardcoded-ui-string]`
- `143:40` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Please login first") `[flutter.localization.hardcoded-ui-string]`
- `149:32` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Report failed: ${e.message}") `[flutter.localization.hardcoded-ui-string]`
- `152:59` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Unexpected error") `[flutter.localization.hardcoded-ui-string]`
- `160:16` **warning** Probable user-visible hardcoded string in IconButton(tooltip: ...). ("Report") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
