# Task 0006: lib/ui/green_memorial/create_memorial_page.dart

## Target file

lib/ui/green_memorial/create_memorial_page.dart

## Findings

- `116:25` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Could not load this image. Please try another photo.') `[flutter.localization.hardcoded-ui-string]`
- `394:40` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Create Memorial') `[flutter.localization.hardcoded-ui-string]`
- `431:62` **warning** Probable user-visible hardcoded string in InputDecoration(labelText: ...). ('Memorial title') `[flutter.localization.hardcoded-ui-string]`
- `445:30` **warning** Probable user-visible hardcoded string in InputDecoration(labelText: ...). ('Story / message') `[flutter.localization.hardcoded-ui-string]`
- `584:62` **warning** Probable user-visible hardcoded string in InputDecoration(labelText: ...). ('City') `[flutter.localization.hardcoded-ui-string]`
- `591:62` **warning** Probable user-visible hardcoded string in InputDecoration(labelText: ...). ('Country') `[flutter.localization.hardcoded-ui-string]`
- `602:34` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Create Memorial') `[flutter.localization.hardcoded-ui-string]`
- `625:16` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Create Memorial') `[flutter.localization.hardcoded-ui-string]`
- `628:13` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Honor your beloved pet by planting a memory through nature.') `[flutter.localization.hardcoded-ui-string]`
- `666:13` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Add a pet before creating a memorial.') `[flutter.localization.hardcoded-ui-string]`
- `674:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Add Pet First') `[flutter.localization.hardcoded-ui-string]`
- `805:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Choose Photo') `[flutter.localization.hardcoded-ui-string]`
- `809:13` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Photo upload will be connected later. Preview is local for now.') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
