# Task 0030: lib/ui/setting/privacy_settings_page.dart

## Target file

lib/ui/setting/privacy_settings_page.dart

## Findings

- `92:49` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Privacy settings updated") `[flutter.localization.hardcoded-ui-string]`
- `140:23` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Privacy & Security") `[flutter.localization.hardcoded-ui-string]`
- `151:23` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Control your visibility, data sharing, and account privacy settings.") `[flutter.localization.hardcoded-ui-string]`
- `265:37` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Data export request submitted") `[flutter.localization.hardcoded-ui-string]`
- `339:19` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Delete account") `[flutter.localization.hardcoded-ui-string]`
- `350:19` **warning** Probable user-visible hardcoded string in Text(data: ...). ("This action cannot be undone and all your data will be permanently deleted.") `[flutter.localization.hardcoded-ui-string]`
- `383:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Cancel") `[flutter.localization.hardcoded-ui-string]`
- `414:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Delete") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
