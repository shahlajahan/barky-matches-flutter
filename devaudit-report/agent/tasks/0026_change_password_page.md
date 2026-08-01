# Task 0026: lib/ui/profile/change_password_page.dart

## Target file

lib/ui/profile/change_password_page.dart

## Findings

- `71:38` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Password updated successfully") `[flutter.localization.hardcoded-ui-string]`
- `133:13` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Password Strength:") `[flutter.localization.hardcoded-ui-string]`
- `248:23` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Change Password") `[flutter.localization.hardcoded-ui-string]`
- `259:23` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Keep your PetSupo account secure by updating your password regularly.") `[flutter.localization.hardcoded-ui-string]`
- `274:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Current Password") `[flutter.localization.hardcoded-ui-string]`
- `305:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ("New Password") `[flutter.localization.hardcoded-ui-string]`
- `342:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Confirm Password") `[flutter.localization.hardcoded-ui-string]`
- `403:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Update Password") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
