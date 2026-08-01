# Task 0022: lib/ui/petshop/seller_offers_page.dart

## Target file

lib/ui/petshop/seller_offers_page.dart

## Findings

- `26:40` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Sellers") `[flutter.localization.hardcoded-ui-string]`
- `32:39` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Error: ${snapshot.error}") `[flutter.localization.hardcoded-ui-string]`
- `42:45` **warning** Probable user-visible hardcoded string in Text(data: ...). ("No sellers found") `[flutter.localization.hardcoded-ui-string]`
- `64:51` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Stock: ${p.stock}") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
