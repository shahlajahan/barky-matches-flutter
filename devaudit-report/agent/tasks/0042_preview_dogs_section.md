# Task 0042: lib/ui/welcome/preview_dogs_section.dart

## Target file

lib/ui/welcome/preview_dogs_section.dart

## Findings

- `14:9` **warning** Probable user-visible hardcoded string in Text(data: ...). ("No dogs yet — add yours and start matching! 🐾") `[flutter.localization.hardcoded-ui-string]`
- `35:46` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Create profile to connect 🐾") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
