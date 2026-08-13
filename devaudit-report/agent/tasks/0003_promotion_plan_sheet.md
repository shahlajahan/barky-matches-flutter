# Task 0003: lib/promotion/widgets/promotion_plan_sheet.dart

## Target file

lib/promotion/widgets/promotion_plan_sheet.dart

## Findings

- `149:45` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Promotion failed: $error') `[flutter.localization.hardcoded-ui-string]`
- `170:41` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Promotion plans are unavailable.') `[flutter.localization.hardcoded-ui-string]`
- `185:26` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Choose a fixed-duration promotion plan.') `[flutter.localization.hardcoded-ui-string]`
- `192:34` **warning** Probable user-visible hardcoded string in Text(data: ...). ('Server plan ${plan.planId}') `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
