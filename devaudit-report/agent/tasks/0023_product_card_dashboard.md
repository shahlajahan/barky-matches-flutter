# Task 0023: lib/ui/petshop/widgets/product_card_dashboard.dart

## Target file

lib/ui/petshop/widgets/product_card_dashboard.dart

## Findings

- `99:28` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Barcode: ${p.barcode}") `[flutter.localization.hardcoded-ui-string]`
- `102:28` **warning** Probable user-visible hardcoded string in Text(data: ...). ("SKU: ${p.sku}") `[flutter.localization.hardcoded-ui-string]`
- `181:20` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Stock: ${p.stock}") `[flutter.localization.hardcoded-ui-string]`
- `187:21` **warning** Probable user-visible hardcoded string in Text(data: ...). ("⚠ Low") `[flutter.localization.hardcoded-ui-string]`
- `274:48` **warning** Probable user-visible hardcoded string in Text(data: ...). ("Media not ready yet") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
