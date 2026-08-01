# Task 0005: lib/ui/feedback/feedback_form_page.dart

## Target file

lib/ui/feedback/feedback_form_page.dart

## Findings

- `44:51` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Please select rating") `[flutter.localization.hardcoded-ui-string]`
- `84:38` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Feedback submitted successfully") `[flutter.localization.hardcoded-ui-string]`
- `91:45` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Submission failed: $e") `[flutter.localization.hardcoded-ui-string]`
- `227:25` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Send Feedback") `[flutter.localization.hardcoded-ui-string]`
- `238:25` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Help us improve PetSupo with your feedback, ideas, and suggestions.") `[flutter.localization.hardcoded-ui-string]`
- `271:25` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Rate your experience") `[flutter.localization.hardcoded-ui-string]`
- `290:19` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Feedback Category") `[flutter.localization.hardcoded-ui-string]`
- `313:35` **warning** Probable user-visible hardcoded string in Text(data: ...). ("General Feedback") `[flutter.localization.hardcoded-ui-string]`
- `316:64` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Bug Report") `[flutter.localization.hardcoded-ui-string]`
- `320:35` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Feature Request") `[flutter.localization.hardcoded-ui-string]`
- `335:19` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Your Message") `[flutter.localization.hardcoded-ui-string]`
- `387:29` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Submit Feedback") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
