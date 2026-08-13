# Task 0005: lib/social/pages/social_post_route_page.dart

## Target file

lib/social/pages/social_post_route_page.dart

## Findings

- `44:38` **warning** Probable user-visible hardcoded string in Text(data: ...). ('This post is unavailable') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
