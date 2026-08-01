# Task 0029: lib/ui/setting/delete_account_page.dart

## Target file

lib/ui/setting/delete_account_page.dart

## Findings

- `48:25` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Failed to delete account. Please try again.") `[flutter.localization.hardcoded-ui-string]`
- `97:19` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Delete Account") `[flutter.localization.hardcoded-ui-string]`
- `108:19` **warning** Probable user-visible hardcoded string in Text(data: ...). ("This action is permanent.\n\nAll your dogs, chats, favorites, and activity will be permanently deleted.") `[flutter.localization.hardcoded-ui-string]`
- `141:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Cancel") `[flutter.localization.hardcoded-ui-string]`
- `173:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Delete") `[flutter.localization.hardcoded-ui-string]`
- `199:17` **warning** Probable user-visible hardcoded string in InputDecoration(hintText: ...). ('DELETE') `[flutter.localization.hardcoded-ui-string]`
- `201:18` **warning** Probable user-visible hardcoded string in InputDecoration(labelText: ...). ('Type DELETE to confirm') `[flutter.localization.hardcoded-ui-string]`
- `308:23` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Delete Account") `[flutter.localization.hardcoded-ui-string]`
- `319:23` **warning** Probable user-visible hardcoded string in Text(data: ...). ("This action is permanent and cannot be undone.") `[flutter.localization.hardcoded-ui-string]`
- `367:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ("What will be deleted") `[flutter.localization.hardcoded-ui-string]`
- `394:17` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Confirmation") `[flutter.localization.hardcoded-ui-string]`
- `457:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Delete Account") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
