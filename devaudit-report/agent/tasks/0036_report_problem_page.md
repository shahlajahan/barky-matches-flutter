# Task 0036: lib/ui/support/report_problem_page.dart

## Target file

lib/ui/support/report_problem_page.dart

## Findings

- `71:51` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Please enter a title") `[flutter.localization.hardcoded-ui-string]`
- `124:38` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Report submitted successfully") `[flutter.localization.hardcoded-ui-string]`
- `133:45` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Failed to send report: $e") `[flutter.localization.hardcoded-ui-string]`
- `205:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Attach screenshot") `[flutter.localization.hardcoded-ui-string]`
- `214:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Optional, but helps us understand the issue faster.") `[flutter.localization.hardcoded-ui-string]`
- `350:29` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Report a Problem") `[flutter.localization.hardcoded-ui-string]`
- `362:29` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Tell us what went wrong. Your report helps us improve PetSupo.") `[flutter.localization.hardcoded-ui-string]`
- `397:39` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Bug report") `[flutter.localization.hardcoded-ui-string]`
- `402:39` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Abuse / harassment") `[flutter.localization.hardcoded-ui-string]`
- `407:39` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Incorrect information") `[flutter.localization.hardcoded-ui-string]`
- `412:39` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Payment issue") `[flutter.localization.hardcoded-ui-string]`
- `415:70` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Other") `[flutter.localization.hardcoded-ui-string]`
- `510:37` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Submit Report") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
