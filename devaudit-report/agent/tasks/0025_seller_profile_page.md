# Task 0025: lib/ui/product/seller_profile_page.dart

## Target file

lib/ui/product/seller_profile_page.dart

## Findings

- `246:59` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Seller rating') `[flutter.localization.hardcoded-ui-string]`
- `469:39` **warning** Probable user-visible hardcoded string in Text(data: ...). ('About Seller') `[flutter.localization.hardcoded-ui-string]`
- `567:33` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Seller Products') `[flutter.localization.hardcoded-ui-string]`
- `572:33` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Newest first') `[flutter.localization.hardcoded-ui-string]`
- `596:39` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Error loading seller products: ${snapshot.error}') `[flutter.localization.hardcoded-ui-string]`
- `632:37` **warning** Probable user-visible hardcoded string in Text(data: ...). ('This seller has no active products') `[flutter.localization.hardcoded-ui-string]`
- `748:11` **warning** Probable user-visible hardcoded string in Text(data: ...). ("KP") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
