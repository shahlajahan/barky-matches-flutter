# Task 0006: lib/ui/admin/pet_taxi_admin_review_panel.dart

## Target file

lib/ui/admin/pet_taxi_admin_review_panel.dart

## Findings

- `207:13` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Business approval: ${widget.businessData['status'] ?? 'unknown'}') `[flutter.localization.hardcoded-ui-string]`
- `210:13` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Required documents: $approvedCount / ${requiredDocuments.length} approved') `[flutter.localization.hardcoded-ui-string]`
- `212:16` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Compliance: ${_compliance['status'] ?? 'missing'}') `[flutter.localization.hardcoded-ui-string]`
- `213:16` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Pet Taxi active: ${active ? 'active' : 'inactive'}') `[flutter.localization.hardcoded-ui-string]`
- `214:16` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Publication: ${published ? 'published' : 'unpublished'}') `[flutter.localization.hardcoded-ui-string]`
- `229:35` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Approve Pet Taxi compliance') `[flutter.localization.hardcoded-ui-string]`
- `235:35` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Activate & publish') `[flutter.localization.hardcoded-ui-string]`
- `242:15` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Publication blockers:') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
