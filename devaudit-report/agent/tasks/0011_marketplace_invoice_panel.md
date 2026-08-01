# Task 0011: lib/ui/marketplace/marketplace_invoice_panel.dart

## Target file

lib/ui/marketplace/marketplace_invoice_panel.dart

## Findings

- `109:38` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Invoice number and date are required') `[flutter.localization.hardcoded-ui-string]`
- `127:38` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Invoice uploaded successfully') `[flutter.localization.hardcoded-ui-string]`
- `133:45` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Invoice upload failed: $e') `[flutter.localization.hardcoded-ui-string]`
- `152:45` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Invoice $status') `[flutter.localization.hardcoded-ui-string]`
- `157:45` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Invoice review failed: $e') `[flutter.localization.hardcoded-ui-string]`
- `170:51` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Cannot open invoice file') `[flutter.localization.hardcoded-ui-string]`
- `211:22` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Invoice') `[flutter.localization.hardcoded-ui-string]`
- `224:33` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Open invoice') `[flutter.localization.hardcoded-ui-string]`
- `232:28` **warning** Probable user-visible hardcoded string in InputDecoration(labelText: ...). ('Invoice number') `[flutter.localization.hardcoded-ui-string]`
- `242:28` **warning** Probable user-visible hardcoded string in InputDecoration(labelText: ...). ('Invoice date') `[flutter.localization.hardcoded-ui-string]`
- `250:28` **warning** Probable user-visible hardcoded string in InputDecoration(labelText: ...). ('Invoice system') `[flutter.localization.hardcoded-ui-string]`
- `254:63` **warning** Probable user-visible hardcoded string in Text(data: ...). ('e-Arsiv') `[flutter.localization.hardcoded-ui-string]`
- `255:64` **warning** Probable user-visible hardcoded string in Text(data: ...). ('e-Fatura') `[flutter.localization.hardcoded-ui-string]`
- `265:28` **warning** Probable user-visible hardcoded string in InputDecoration(labelText: ...). ('Invoice type') `[flutter.localization.hardcoded-ui-string]`
- `271:31` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Individual') `[flutter.localization.hardcoded-ui-string]`
- `273:64` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Company') `[flutter.localization.hardcoded-ui-string]`
- `285:28` **warning** Probable user-visible hardcoded string in InputDecoration(labelText: ...). ('Note optional') `[flutter.localization.hardcoded-ui-string]`
- `316:28` **warning** Probable user-visible hardcoded string in InputDecoration(labelText: ...). ('Rejection reason optional') `[flutter.localization.hardcoded-ui-string]`
- `326:39` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Approve') `[flutter.localization.hardcoded-ui-string]`
- `333:39` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Reject') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
