# PetSupo Production QA Audit — 2026-08-03

## Executive Summary

This is a fresh audit of the repository at `integration/mac-windows-2026-07-22`,
HEAD `286df4c`, plus the current working tree. The previous audit is not used as
the source of current findings.

The publication and projection work is complete. The recorded production
verification states that the publication migration, both rollback backups,
Pet Taxi contamination cleanup, projection regeneration, Functions deployment,
Firestore Rules deployment, and `businesses_public` verification all completed
successfully. The recorded deployment result is 177 Functions updated, zero
failed Functions, and no rollback.

Current static audit results do not confirm a publication, projection, sector,
moderation-function, region, or deployment defect.

The release remains **NO-GO** for the current audit scope because the active
marketplace checkout source still uses the legacy payment callback origin and
Pet Boost activation is client-authoritative and not connected to a verified
payment/backend activation path. Apple Sign In is also deliberately disabled;
whether that is release-blocking is a product decision, not a code defect.

The full Flutter test command did not complete: it remained loading the first
test for more than two minutes and was stopped. Functions tests passed. Focused
navigation analysis/tests, Firestore Rules compilation, Storage Rules
compilation, and `git diff --check` passed.

## Release Recommendation

**NO-GO until the marketplace callback origin and Pet Boost authorization model
are resolved or explicitly accepted by product/security.**

No production data, Rules, Functions, Hosting, Indexes, or migrations were
modified during this audit.

## GO / NO-GO Decision

**NO-GO** for a release decision based on this audit.

The decision is not caused by the completed publication or Pet Taxi work. It is
based only on the current findings in this document and the incomplete full
Flutter test run.

## Completed Since the Previous Audit

The following are current completed results and are not open findings:

- Firestore publication architecture is implemented.
- Legacy approved businesses were backfilled.
- `published=true` was added only where required.
- `businesses_public` regeneration completed.
- Canonical sector projection was verified.
- Pet Taxi contamination cleanup completed.
- Non-Pet-Taxi businesses no longer contain `pet_taxi` projection data.
- Projection synchronization was verified.
- `reviewModerationCase` was removed and replaced by `reviewReport`,
  `restoreModerationTarget`, and `reactivateUser`.
- Functions deployed successfully.
- Firestore Rules deployed successfully.
- 177 Cloud Functions were updated successfully.
- No Functions failed.
- No deployment rollback was required.
- Production migration completed successfully.
- Publication migration backup was created.
- Pet Taxi contamination backup was created.
- All migration candidates completed successfully.
- `businesses_public` verification passed.
- Verified sectors: veterinary, groomer, `pet_hotel`, `adoption_center`,
  `pet_shop`, and `pet_taxi`.
- Projection verification passed.
- No duplicate projections were found.
- No invalid `pet_taxi` projection exists on a non-Pet-Taxi business.

## Current Findings

### P1 — Marketplace checkout uses a legacy payment callback origin

- **Status:** Confirmed in current source; payment-provider runtime verification
  remains required.
- **Evidence:** The active Pet Shop checkout sends both callback URLs to
  `https://barkymatches.app/payment-success` and
  `https://barkymatches.app/payment-cancel`.
- **Exact file and line:**
  `lib/ui/petshop/widgets/checkout_button.dart:81-82,103-104`.
- **Reproduction:** Complete a Pet Shop checkout and follow the provider
  success or cancel redirect.
- **Impact:** The provider may return to a legacy or unavailable origin, leaving
  the payment flow outside the current PetSupo callback surface.
- **Minimal safe fix:** Replace the two callback origins with the currently
  approved production callback origin and verify provider allowlists before any
  payment deployment.
- **Runtime verification required:** Yes; success, cancel, timeout, duplicate
  callback, and failed callback cases are required.

### P1 — Pet Boost activation is client-authoritative

- **Status:** Confirmed in current source; production abuse and expiry behavior
  require runtime verification.
- **Evidence:** The UI presents priced boost options, while `_boostDog()` writes
  `isSponsored`, `boostScore`, `boostExpiresAt`, and `sponsorshipType` directly
  to the dog document. Ranking adds `boostScore` whenever `isSponsored` is true.
- **Exact files and lines:**
  `lib/dog_card.dart:494-527,591-608`;
  `lib/playmate_page.dart:681-682`.
- **Reproduction:** Open a dog card, select a priced boost option, and inspect
  the direct Firestore update and resulting Playmate ranking.
- **Impact:** A client can obtain promotion state without a server-verified
  payment/activation record; expired or forged fields can affect ranking.
- **Minimal safe fix:** Disable activation until a server-authoritative purchase,
  activation, and expiry path exists, or move the state transition behind an
  authenticated backend transaction. Ranking must validate server-owned state.
- **Runtime verification required:** Yes for current visibility and ranking;
  the missing trusted activation path is already proven statically.

### P2 — Apple Sign In is disabled by configuration

- **Status:** Confirmed current limitation; release impact is a product decision.
- **Evidence:** `appleSignInEnabled` is hardcoded to `false`, so the Apple button
  is not rendered.
- **Exact file and lines:**
  `lib/auth_page.dart:464-466,2169-2181`.
- **Reproduction:** Open the authentication page on iOS or Web and inspect the
  available social providers.
- **Impact:** Apple authentication is unavailable.
- **Minimal safe fix:** Complete Apple Developer/provisioning configuration and
  enable the existing path, or document Apple Sign In as intentionally
  unsupported for this release.
- **Runtime verification required:** Yes if enabled: iOS/Web sign-in, cancel,
  account creation, and missing-profile cases.

### P2 — Adoption profile edit exposes bank-account settings

- **Status:** Confirmed current UI path.
- **Evidence:** The Adoption Center profile editor navigates to
  `BankAccountSettingsPage` and displays the bank-account label.
- **Exact file and lines:**
  `lib/ui/business/dashboard/adoption_center/edit_adoption_center_profile_page.dart:338-350`.
- **Reproduction:** Open Adoption Center → Edit Profile.
- **Impact:** A non-commercial Adoption workflow exposes unsupported finance
  terminology and a potentially misleading bank-settings entry point.
- **Minimal safe fix:** Remove or replace this Adoption-only entry point after
  confirming no approved commercial workflow depends on it.
- **Runtime verification required:** Yes, to confirm all reachable Adoption
  navigation paths.

### P3 — Social post unavailable message is not localized

- **Status:** Confirmed by current static scan.
- **Evidence:** `SocialPostRoutePage` renders the literal string
  `This post is unavailable`.
- **Exact file and line:**
  `lib/social/pages/social_post_route_page.dart:44`.
- **Reproduction:** Open an unavailable public post link.
- **Impact:** Users in Turkish, Persian, or Russian may see an English error
  message.
- **Minimal safe fix:** Add a localization key in all supported ARB files and
  use it in the error state.
- **Runtime verification required:** Yes, for all supported locales and RTL.

## Current Security Audit

### Firestore Rules

Current source evidence shows the principal previously reviewed authorization
boundaries are present:

- User documents are owner/admin readable and creator data is protected:
  `firestore.rules:379-413`.
- Business documents are not broadly readable; public reads use the public
  projection and private nested business data is owner/admin controlled:
  `firestore.rules:569-602`.
- Business creation requires the authenticated owner UID, pending status, and
  `published == false`, and rejects protected moderation fields:
  `firestore.rules:571-582`.
- Business and veterinary chat access is participant-scoped:
  `firestore.rules:1015-1054`.
- Social post updates are owner/admin scoped:
  `firestore.rules:1141-1165`.
- Financial collections are server-owned and client writes are denied:
  `firestore.rules:869-932`.
- Public projections are public-read and client-write denied:
  `firestore.rules:416-419` and `firestore.rules:593-596`.

No current Rules defect was confirmed by static inspection. The Rules source
compiled successfully in a Firebase dry run. A complete production identity
matrix was not executed in this audit.

### Storage Rules

Current Storage Rules enforce authenticated owner/admin access and upload
constraints for media and documents:

- Media constraints: `storage.rules:13-21`.
- Document constraints: `storage.rules:24-32`.
- Sector document access: `storage.rules:35-50`.
- User/profile and social media access: `storage.rules:53-80`.
- Default deny: `storage.rules:83-85`.

Storage Rules compiled successfully in a Firebase dry run. No current Storage
authorization defect was confirmed statically. Upload matrix runtime testing is
still required.

## Publication, Businesses, and Public Projections

Current source and recorded production verification show:

- Canonical membership is derived from normalized `sectors` only:
  `functions/src/businessSectorMembership.js:47-61`.
- Publication backfill accepts only approved businesses with missing/null
  `published`, validates supported canonical sectors, refuses contamination,
  creates a complete backup before writes, performs narrow `published` updates,
  and resynchronizes projections:
  `functions/scripts/backfillPublishedBusinesses.js:62-207`.
- Pet Taxi publication defaults missing `published` to false and non-Pet-Taxi
  publication defaults missing `published` to true:
  `functions/src/businessPublication.js:7-34`.
- Public projection writes are Functions-only and projection data is canonical
  sector filtered:
  `functions/src/publicProjections.js` and
  `firestore.rules:593-596`.

The recorded production verification passed for veterinary, groomer,
`pet_hotel`, `adoption_center`, `pet_shop`, and `pet_taxi`. No current
publication or projection defect was confirmed.

## Moderation and Cloud Functions

Current Functions source contains the replacement moderation callables:

- `reviewReport`: `functions/index.js:11812-11928`.
- `restoreModerationTarget`: `functions/index.js:11936-11992`.
- `reactivateUser`: `functions/index.js:11996` onward.

No current source reference to `reviewModerationCase` was found. The recorded
production deployment states that Functions completed successfully with 177
updated and no failures. A fresh live `firebase functions:list` query failed
with `Failed to list functions for barkymatches-new`; therefore the current
live function inventory was not independently re-read during this audit.

The recorded deployment result remains the production source of truth for this
report; the failed inventory query is an audit limitation, not a production
failure finding.

## Feature and Surface Re-audit

| Area | Current result | Evidence / limitation |
|---|---|---|
| Flutter | Focused changed-route analysis passed; full suite incomplete | `flutter analyze` focused pass; full `flutter test` stalled during first test |
| Functions | Current source and Functions test suite pass | `npm test` exit 0; 177 deployed per recorded production verification |
| Firestore Rules | No current static defect confirmed | `firestore.rules` dry-run compiled successfully |
| Storage Rules | No current static defect confirmed | `storage.rules` dry-run compiled successfully |
| Hosting | No current configuration defect confirmed | `firebase.json`; runtime custom-domain/redirect checks not executed |
| Payments | Current marketplace callback finding remains open | `checkout_button.dart:81-104`; end-to-end payment verification required |
| Marketplace | Current callback finding remains open | Same as Payments; other current source tests passed |
| Creator | No current defect confirmed | Creator rules and referral functions inspected; runtime verification not executed |
| Business dashboards | No current publication/projection defect confirmed | Dashboard routing and shared finance components inspected |
| Vet | Canonical projection verified | Recorded production projection verification passed |
| Groomy | No current defect confirmed by this audit | Current source and Functions projection tests inspected |
| Hotel | No current publication/projection defect confirmed | Current dashboard and projection paths inspected |
| Pet Taxi | Contamination guards and projection verification passed | Current helper, repository, booking, repair, and projection tests passed |
| Pet Shop | No current projection defect; payment callback remains open | Current checkout and projection paths inspected |
| Adoption | Bank-settings entry point remains open | `edit_adoption_center_profile_page.dart:338-350` |
| Social | Unavailable-post message localization finding remains open | `social_post_route_page.dart:44`; share/navigation tests passed |
| Authentication | Apple Sign In intentionally disabled | `auth_page.dart:464-466` |
| Subscriptions | No current defect confirmed statically | Source/tests inspected; provider runtime flows not executed |
| Revenue | No publication defect; client-side Pet Boost remains open | `dog_card.dart:591-608`; finance sources inspected |
| Finance | Functions tests pass; live report/storage runtime not re-executed | `functions/finance/**`; current static path inspected |
| Localization | One confirmed social hardcoded string; Apple/Adoption product decisions noted | DevAudit reported one warning |
| SEO | Not confirmed | No authenticated production browser audit was available |
| Web | Build/runtime result not freshly established in this audit | Hosting config inspected; full browser verification not available |
| PWA | Not confirmed | Service worker/install/update behavior not exercised |
| Deep links | External Petplore Back guard is implemented and focused-tested | `main.dart:1434-1438,1580-1584`; focused navigation tests pass |
| Apple | Sign In disabled by configuration | `auth_page.dart:464-466` |
| Android | Not confirmed | No device/runtime session available |
| iOS | Focused Dart navigation path verified; native runtime not re-executed | No iOS device session available |
| Cloud Functions | Recorded deployment passed; fresh inventory query unavailable | 177 updated per recorded production verification |
| Security | Rules source compiled; Boost is current authorization concern | Full production identity matrix not executed |
| Firestore indexes | No current defect confirmed statically | `firestore.indexes.json` inspected; query runtime not exhaustively exercised |
| Storage | Rules compile; upload runtime not exercised | `storage.rules` and CORS config inspected |
| Cloud Scheduler | No current defect confirmed statically | Scheduled exports inspected; runtime execution not observed |
| Public projections | Verification passed | Recorded production verification and current projection tests |
| Businesses | Publication migration and sector verification passed | Recorded production verification |
| User privacy | No current broad-read defect confirmed in current Rules source | `firestore.rules:379-419,569-602` |
| Moderation | Replacement Functions present; old function absent in source | `functions/index.js:11812-12000` |
| Notifications | No current defect confirmed statically | Notification paths inspected; delivery runtime not exercised |
| AppState | No current defect confirmed in this audit | Static inspection only |
| Performance | No current defect confirmed by automated evidence | Runtime profiling not performed |
| Memory | Not confirmed | No profiling session available |
| Build system | Full Flutter test process stalled; focused analysis passed | See Build/Test Results |

## Runtime Verification

Completed or recorded production verification:

- Publication migration completed.
- Publication backup created.
- Pet Taxi contamination backup created.
- Projection synchronization completed.
- `businesses_public` verification passed for all six canonical sectors.
- No duplicate projections.
- No invalid non-Pet-Taxi `publicSectorData.pet_taxi` projection.
- External Petplore Back navigation focused tests passed for warm and cold
  navigation paths; authentication state was not changed by the implementation.

Still required:

- Authenticated production identity matrix for Firestore and Storage Rules.
- Marketplace payment provider success/cancel/failure/duplicate callbacks.
- Pet Boost payment, authorization, expiry, and ranking behavior.
- Apple Sign In if the feature is enabled.
- Browser Hosting, SEO, PWA, and deep-link refresh/back checks.
- Native iOS and Android smoke tests.
- Finance, notification delivery, scheduler, memory, and performance profiling.

## Build and Test Results

- `npm test` in `functions`: passed, exit 0. The suite includes publication,
  projection, Pet Taxi guard, finance, marketplace, and moderation coverage.
- Focused Flutter navigation tests: passed, 4 tests.
- Focused Flutter analyze for changed navigation files: passed, no issues.
- `devaudit scan`: 536 files scanned, 1 warning, 0 errors. The warning is the
  hardcoded unavailable-post message recorded above.
- Firestore Rules dry run: passed; rules compiled successfully.
- Storage Rules dry run: passed; rules compiled successfully.
- `git diff --check`: passed.
- Full `flutter test`: incomplete; remained loading
  `test/ui/creator/creator_dashboard_data_test.dart` for more than two minutes
  and was stopped. No pass/fail result is claimed.
- Full `flutter analyze`: not used as a release result in this audit; focused
  changed-file analysis passed.

## Security Section

No current Firestore Rules or Storage Rules defect was confirmed statically.
Public projections and migration writes are server-owned. Business creation and
owner updates use protected-field restrictions. The remaining confirmed
security concern is client-authoritative Pet Boost activation described above.

## Recommended Fix Order

1. Resolve the marketplace callback origin and run provider end-to-end tests.
2. Move Pet Boost activation and ranking authority behind verified backend state.
3. Decide whether Apple Sign In is required for this release; enable or document
   it accordingly.
4. Remove or replace the Adoption bank-settings entry point.
5. Localize the unavailable-post error message.
6. Diagnose the full Flutter test startup stall and restore a passing complete
   test gate.
7. Complete authenticated production, browser, iOS, Android, payment,
   notification, scheduler, and performance verification.

## Files Inspected

- `firestore.rules`
- `storage.rules`
- `firebase.json`
- `firestore.indexes.json`
- `storage-cors.json`
- `functions/index.js`
- `functions/src/businessSectorMembership.js`
- `functions/src/businessPublication.js`
- `functions/src/publicProjections.js`
- `functions/scripts/backfillPublishedBusinesses.js`
- `functions/finance/**`
- `lib/main.dart`
- `lib/social/pages/social_post_route_page.dart`
- `lib/social/pages/social_post_detail_page.dart`
- `lib/social/services/social_post_share.dart`
- `lib/auth_page.dart`
- `lib/dog_card.dart`
- `lib/playmate_page.dart`
- `lib/ui/petshop/widgets/checkout_button.dart`
- `lib/ui/business/dashboard/adoption_center/edit_adoption_center_profile_page.dart`
- `lib/ui/business/finance/**`
- business dashboard, Vet, Groomy, Hotel, Pet Taxi, Pet Shop, Adoption, Social,
  subscription, notification, AppState, Web, iOS, Android, Hosting, and PWA
  source/configuration paths found by repository search.

## Commands Executed

- `git status --short`
- `git log -8 --oneline --decorate`
- `rg --files`
- `rg`/`nl` read-only source and rules inspections
- `devaudit scan`
- `npm test` in `functions`
- `flutter test` (stopped after startup stall)
- focused `flutter analyze`
- `firebase deploy --only firestore:rules --project barkymatches-new --dry-run`
- `firebase deploy --only storage --project barkymatches-new --dry-run`
- `firebase functions:list --project barkymatches-new --json` (failed to list;
  no production mutation occurred)
- `git diff --check`

## Audit Limitations

The following are explicitly **Not confirmed** in this session: live browser
behavior, authenticated production Rules matrix, payment-provider callbacks,
Apple/Google native authentication, Android/iOS device behavior, Hosting/PWA
install/update behavior, SEO rendering, notification delivery, scheduler
execution, memory, performance, and live Firestore document re-reads.

The recorded production verification supplied for this audit is the source of
truth for completed publication, migration, projection, deployment, and
cleanup work. The failed current function inventory query does not overturn
those recorded results.
