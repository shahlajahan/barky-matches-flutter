# PetSupo Production QA Audit — 2026-08-02

## 1. Executive summary

This audit covers the checked-out branch `integration/mac-windows-2026-07-22` at commit `6515527` and the current working tree. No application code, configuration, rules, assets, or deployment state was changed during the audit. The only new file is this report.

The release is **NO-GO** until the confirmed P1 security findings and the marketplace payment return URL are resolved and tested. The Web release build, Flutter tests, Functions tests, Firestore rules compilation, Storage rules compilation, and diff check succeeded. Full `flutter analyze` does not pass because archived/exported code under `ai_exports/` is included in the analysis root and contains hundreds of compile errors.

Live browser and authenticated-device verification could not be completed because no browser/device session was available in this environment. All such checks are explicitly marked as runtime verification required; no live production behavior is claimed as verified.

## 2. Release recommendation

**NO-GO**

Required before release:

1. Restrict broad Firestore reads and arbitrary chat/social mutations.
2. Replace and end-to-end test the legacy marketplace payment return URL.
3. Establish a passing analyzer gate by excluding or repairing archived/exported code.
4. Complete authenticated Web, Android, and iOS smoke tests.

## 3. P0 findings

No confirmed P0 findings were established by static inspection and available automated checks.

## 4. P1 findings

### P1-1 — Any signed-in user can read complete user documents

- **Status:** Confirmed defect by rules inspection; runtime data-sensitivity test still required.
- **Location:** `firestore.rules:311-312`.
- **Evidence:** `match /users/{userId}` grants `allow read: if isSignedIn()`, with no owner, field, or public-profile restriction.
- **Reproduction path:** Authenticate as User B, read `/users/UserA` directly through Firestore.
- **Impact:** Any authenticated account can retrieve fields stored on another user document, including fields that may later contain private profile, account, or operational data. The rule grants access regardless of `userId`.
- **Smallest safe fix:** Separate public profile fields from private user data or restrict reads to the owner/admin and expose only an explicitly public projection.
- **Runtime required:** Yes. Run an emulator/auth matrix test against a document containing representative private fields.

### P1-2 — Any signed-in user can read business documents and all recursive subcollections

- **Status:** Confirmed defect by rules inspection; runtime field-sensitivity test still required.
- **Location:** `firestore.rules:496-520`.
- **Evidence:** `/businesses/{businessId}` allows read for every signed-in user, and `/{document=**}` repeats the same broad read permission for every nested document. Business documents commonly contain operational, contact, bank, or configuration fields.
- **Reproduction path:** Authenticate as an unrelated user and read another business document or a nested business-sector document.
- **Impact:** Cross-business disclosure of private business information and nested operational data.
- **Smallest safe fix:** Publish a public business projection and restrict private business documents/subcollections to the owner, authorized staff, or admin; remove the broad recursive read.
- **Runtime required:** Yes. Test owner, unrelated signed-in user, anonymous user, and admin against representative business and nested documents.

### P1-3 — Business and veterinary chat ACLs do not check participants

- **Status:** Confirmed defect by rules inspection; runtime authorization test still required.
- **Location:** `firestore.rules:932-957`.
- **Evidence:** `/business_chats/{chatId}` and `/business_chats/{chatId}/messages/{messageId}` grant read/create/update to any `isRegisteredUser()`. `/vet_chats/{chatId}` grants read/create/update to any registered user. Unlike the `/chats` rules at `894-929`, there is no participant or business-owner condition.
- **Reproduction path:** Authenticate as User B and read, create, or update a chat/message belonging to User A or another business.
- **Impact:** Private conversations can be read or altered; unauthorized messages can be injected.
- **Smallest safe fix:** Apply participant membership and sender ownership checks equivalent to the protected `/chats` rules, with explicit business staff/client authorization where applicable.
- **Runtime required:** Yes. Emulator tests should cover unrelated readers, participants, business owners, and admins.

### P1-4 — Any registered user can update any social post

- **Status:** Confirmed defect by rules inspection; runtime authorization test still required.
- **Location:** `firestore.rules:1044-1057`.
- **Evidence:** `allow update: if isRegisteredUser()` has no author/admin or changed-field restriction.
- **Reproduction path:** Authenticate as User B and update arbitrary fields on User A’s `/social_posts/{postId}`.
- **Impact:** Content tampering, moderation bypass, impersonation, or deletion-by-overwrite of user content.
- **Smallest safe fix:** Permit owner/admin updates only, and use a narrow field-diff rule for approved interaction counters if needed.
- **Runtime required:** Yes. Test owner, unrelated user, and admin update matrices.

### P1-5 — Marketplace checkout uses legacy BarkyMatches callback URLs

- **Status:** Confirmed source defect; payment redirect behavior still requires end-to-end runtime verification.
- **Location:** `lib/ui/petshop/widgets/checkout_button.dart:81-105`.
- **Evidence:** The active checkout call and return verification use `https://barkymatches.app/payment-success` and `https://barkymatches.app/payment-cancel`, while the current branded Hosting configuration is `app.petsupo.com` and `firebase.json` defines the active Isbank callback routes at `/isbank/3d-*`.
- **Reproduction path:** Complete a Pet Shop Web checkout, follow the provider success/cancel redirect, and observe the destination.
- **Impact:** A successful payment may redirect to an obsolete/unowned host, fail to return to the app, or expose legacy branding. This can leave the order/payment UX incomplete even if the provider payment succeeds.
- **Smallest safe fix:** Use the current configured PetSupo callback origin/route and verify provider allowlists and success/cancel handling for Web and native flows.
- **Runtime required:** Yes, with success, cancel, timeout, duplicate callback, and failed callback cases.

## 5. P2 findings

### P2-1 — Full analyzer gate fails on archived/exported code

- **Status:** Confirmed build-quality defect; production Web build is independently successful.
- **Location:** `ai_exports/vet_context/**` (representative errors include invalid imports and undefined symbols throughout that tree).
- **Evidence:** `flutter analyze` reported 1,291 issues, including compile errors in the archived/exported Vet context. The tree is included in the analysis root.
- **Reproduction path:** Run `flutter analyze` from the repository root.
- **Impact:** A release analyzer gate cannot distinguish production defects from archived code and currently fails. This reduces confidence and can hide new production errors.
- **Smallest safe fix:** Exclude archived/exported trees from analysis if they are not build inputs, or repair/remove them under a separate approved change.
- **Runtime required:** No for the analyzer failure itself; required to prove the excluded code is not imported into production.

### P2-2 — Pet Hotel can receive the legacy outer finance section in addition to its shared Revenue destination

- **Status:** Confirmed by render composition; visual duplication requires runtime confirmation.
- **Locations:** `lib/ui/business/dashboard/business_dashboard_page.dart:281-305`; `lib/ui/business/finance/seller_finance_widgets.dart:8-56`; `lib/ui/business/dashboard/pet_hotel/pet_hotel_web_dashboard_page.dart:31-38`; `lib/ui/business/dashboard/pet_hotel/pet_hotel_dashboard_page.dart:134-139`.
- **Evidence:** `_buildDashboardWithFinance` bypasses the outer finance wrapper for Pet Shop, Groomy, Vet, and Adoption, but not Pet Hotel. Pet Hotel itself also exposes `BusinessRevenueDashboard` as its Revenue destination on Web and mobile.
- **Reproduction path:** Open a Pet Hotel dashboard through `BusinessDashboardPage` and inspect the outer content and Revenue destination.
- **Impact:** Potential duplicate/legacy finance UI, duplicate summary listeners, and inconsistent presentation for Pet Hotel.
- **Smallest safe fix:** Route Pet Hotel through the same direct-dashboard path as the other migrated commercial sectors; do not change the shared finance component.
- **Runtime required:** Yes, to confirm the exact desktop/mobile composition and listener count.

### P2-3 — Shared Revenue dashboard creates its finance stream inline during build

- **Status:** Static performance risk; subscription recreation is not proven in this environment.
- **Location:** `lib/ui/business/finance/pet_taxi_revenue_section.dart:37-40`.
- **Evidence:** `StreamBuilder.stream` calls `SellerFinanceRepository().watchSummary(businessId)` inline. A parent rebuild can therefore supply a new Stream object. The repository source is `lib/ui/business/finance/seller_finance_repository.dart:11-17`.
- **Reproduction path:** Enable stream/widget identity logging, trigger parent rebuilds without changing `businessId`, and compare stream identity and subscription cancellation/recreation.
- **Impact:** Possible repeated Firestore listener setup and avoidable rebuilds across all four shared Revenue consumers.
- **Smallest safe fix:** Store the stream in state and recreate only when `businessId` changes, after runtime identity evidence confirms this path.
- **Runtime required:** Yes; do not infer subscription recreation from builder callbacks alone.

### P2-4 — Finance ledger changes do not independently trigger summary projection

- **Status:** Confirmed static freshness gap; production freshness requires runtime verification.
- **Locations:** `functions/index.js:425-435`; `functions/finance/financeSummaryProjector.js:327-358`.
- **Evidence:** `rebuildSellerFinanceSummary` reads `financeLedger` and applies manual adjustments, but the exported trigger listens only to `payoutIndex/{payoutIndexId}`. No `financeLedger` trigger is present in the searched Functions source.
- **Reproduction path:** Write a valid finance-ledger adjustment for an existing business without changing its payoutIndex document, then read `sellerFinanceSummaries/{businessId}`.
- **Impact:** Revenue adjustments and net revenue can remain stale until another payoutIndex write causes a rebuild.
- **Smallest safe fix:** Add an idempotent financeLedger-triggered rebuild keyed by `businessId`, preserving all existing payoutIndex projection behavior.
- **Runtime required:** Yes, with ledger-only write, payoutIndex write, retry, and duplicate-event cases.

### P2-5 — Apple sign-in is disabled in the active authentication UI

- **Status:** Confirmed static limitation; product requirement impact requires product/runtime confirmation.
- **Locations:** `lib/auth_page.dart:464-466`, `2169-2181`.
- **Evidence:** `AuthPage.appleSignInEnabled` is hardcoded `false`, so the Apple button is never rendered even though Apple support exists in dependencies/service code.
- **Reproduction path:** Open the authentication page on iOS or Web and inspect social sign-in options.
- **Impact:** Apple sign-in is unavailable. This is a major onboarding/accessibility issue if Apple authentication is part of the release promise, especially on iOS.
- **Smallest safe fix:** Complete the Apple Developer/provisioning configuration and enable the existing path, or explicitly remove the product promise and document the limitation.
- **Runtime required:** Yes, on iOS and Web with account creation, login, cancel, and missing-profile cases.

### P2-6 — Adoption profile edit still exposes bank-account settings

- **Status:** Confirmed user-visible source defect.
- **Location:** `lib/ui/business/dashboard/adoption_center/edit_adoption_center_profile_page.dart:338-351`.
- **Evidence:** The Adoption Center edit page navigates to `BankAccountSettingsPage` and labels the button with `bankAccountSettingsTitle`, despite the Adoption Center Impact Dashboard being non-commercial.
- **Reproduction path:** Open Adoption Center → edit profile and inspect the actions.
- **Impact:** Finance/bank terminology remains in the non-commercial Adoption experience and can suggest unsupported payout behavior.
- **Smallest safe fix:** Remove or replace this Adoption-only entry point after confirming no required commercial workflow depends on it.
- **Runtime required:** Yes, to verify the reachable navigation paths.

### P2-7 — Preview Hosting origins are not covered by Storage CORS

- **Status:** Confirmed configuration limitation; required only for preview-channel use.
- **Location:** `storage-cors.json`.
- **Evidence:** Production origins `https://app.petsupo.com`, `https://barkymatches-new.web.app`, and `https://barkymatches-new.firebaseapp.com` are present, but preview origins such as `https://barkymatches-new--pre-release-*.web.app` are absent. The configuration lists exact origins rather than a preview-origin strategy.
- **Reproduction path:** Open a preview-channel build and load a Firebase Storage image from Flutter Web.
- **Impact:** Pet/profile images can download at HTTP level but remain unreadable to Flutter Web due to missing CORS authorization.
- **Smallest safe fix:** Add only the approved preview origins or use a controlled preview-hosting policy; do not broaden CORS indiscriminately.
- **Runtime required:** Yes, only if preview channels are supported.

### P2-8 — Storage owner paths have no upload size/content validation

- **Status:** Static risk; abuse impact depends on application upload enforcement.
- **Location:** `storage.rules:18-20`.
- **Evidence:** Authenticated owners can read/write all files under their sector path, with no file size, MIME, or extension constraints in Storage Rules.
- **Reproduction path:** Use an owner account to upload an oversized or non-image file into its permitted sector path.
- **Impact:** Storage cost abuse and invalid media entering downstream image/video pipelines if client validation is bypassed.
- **Smallest safe fix:** Add server-enforced size/content constraints consistent with supported upload types, while preserving legitimate document/video uploads.
- **Runtime required:** Yes, with valid and invalid file types/sizes on Web and mobile.

### P2-9 — Revenue trend date bucketing is UTC-based

- **Status:** Static timezone risk; not a confirmed incorrect user result.
- **Location:** `functions/finance/financeSummaryProjector.js:32-35` and `245-256`.
- **Evidence:** `successfulPaymentAt` is converted with `toISOString().slice(0, 10)`, so a payment near local midnight is assigned to the UTC calendar day. Flutter then displays those buckets as local dates.
- **Impact:** Revenue may appear on the adjacent day for users/businesses operating outside UTC.
- **Smallest safe fix:** Define and consistently apply the product’s finance reporting timezone at projection and display boundaries.
- **Runtime required:** Yes, with timestamps around midnight in Istanbul and another supported timezone.

### P2-10 — Hardcoded English remains in the shared Revenue dashboard

- **Status:** Confirmed user-visible localization defect.
- **Locations:** `lib/ui/business/finance/pet_taxi_revenue_section.dart:214-230`, `637-640`, `669-675`, `973-986`.
- **Evidence:** Labels such as `Bank`, `Net Revenue`, `Waiting Payout`, `Selected period`, `Gross revenue`, `Platform fee`, `Adjustments`, `Net revenue`, and tooltip labels are literal English strings instead of localized keys.
- **Impact:** Turkish, Persian, and Russian users see mixed-language finance screens; long translations and RTL layout are not fully exercised by these labels.
- **Smallest safe fix:** Add localized keys to EN/TR/FA/RU and use them in the shared component.
- **Runtime required:** Yes, for all four locales and RTL layout.

### P2-11 — Pet Boost is a client-writable, unpaid promotion with no verified expiration enforcement

- **Status:** Confirmed unsafe production behavior by source inspection.
- **Locations:** `lib/dog_card.dart:462-535`, `591-625`; `firestore.rules:385-424`; `lib/playmate_page.dart:682`.
- **Evidence:** The Boost sheet presents prices but `_boostDog` directly updates `dogs/{dogId}` with `isSponsored`, `boostScore`, `boostExpiresAt`, and `sponsorshipType`. No payment provider call, purchase record, backend activation, scheduler, refund, or history path is present in the inspected flow. Playmate ranking directly adds `boostScore` when `isSponsored` is true.
- **Impact:** Users can receive paid-looking promotion without a payment transaction, and expired boosts can continue influencing ranking unless another path clears them. This can unfairly alter discovery ranking.
- **Smallest safe fix:** Disable the button until a server-authoritative promotion purchase/activation/expiration flow exists, or route activation through a trusted backend transaction. Do not rely on client expiry fields for ranking.
- **Runtime required:** Yes, to confirm current button visibility and ranking behavior with expired documents; the missing payment/backend path is already confirmed statically.

## 6. P3 findings

### P3-1 — Internal legacy names remain in technical and diagnostic surfaces

- **Status:** Confirmed internal occurrences; no confirmed ordinary user-visible occurrence in the audited Web metadata.
- **Locations:** `pubspec.yaml:1`, `.firebaserc:3`, `firebase.json:45-68`, `lib/firebase_options.dart:47-93`, `web/index.html:60-392`, `web/flutter_bootstrap.js:6-81`, `public/payment-callback.html:21`, iOS URL schemes and bundle metadata, and Functions diagnostic logging.
- **Evidence:** These contain `barky`, `barkymatches`, or `Flutter` identifiers. Web title, manifest, Open Graph/Twitter metadata, and displayed startup text are PetSupo, but DOM IDs, JavaScript globals, package/project identifiers, deep-link schemes, and diagnostic logs retain legacy names.
- **Impact:** Usually no user impact, but legacy names can appear in developer-facing error pages, browser diagnostics, callback URLs, or support screenshots. Internal Firebase IDs/package IDs were explicitly outside the branding requirement unless user-visible.
- **Smallest safe fix:** Rename only genuinely user-visible/externally surfaced technical labels in a separately scoped branding pass; preserve Firebase IDs and package IDs unless a migration is planned.
- **Runtime required:** Yes, browser title/favicon/PWA install/share/permission and error-state checks.

### P3-2 — Adoption trend reuses Vet-named localization keys

- **Status:** Confirmed technical localization inconsistency; displayed text is currently likely generic range text.
- **Location:** `lib/ui/business/dashboard/adoption_center/adoption_impact_dashboard.dart:335-345`.
- **Evidence:** Adoption Trend uses `l10n.vetRevenueRange7Days` and `vetRevenueRange30Days` for its period selector.
- **Impact:** No current finance value is exposed by these keys, but the Adoption feature depends on Vet-specific localization naming and can inherit future Vet wording changes.
- **Smallest safe fix:** Add Adoption-specific timeframe keys and use them in the shared Impact UI.
- **Runtime required:** Yes, verify all locales and range labels.

### P3-3 — Package metadata still describes the old application purpose

- **Status:** Confirmed metadata inconsistency.
- **Location:** `pubspec.yaml:1-3`.
- **Evidence:** Package name is `barky_matches_fixed` and description is “A Flutter application for dog playdates.”
- **Impact:** Store/build tooling, crash reports, or package metadata can expose legacy naming or an incomplete product description even though this is not normally the in-app brand.
- **Smallest safe fix:** Update user-visible distribution metadata in a separately approved packaging/branding change; preserve technical IDs where migration risk exists.
- **Runtime required:** Only distribution/store verification.

## 7. Confirmed working areas

- `flutter test` passed: 150 passed, 9 skipped, 0 failures.
- Functions test suite passed: 150 Node tests, 0 failures.
- `flutter build web --release --no-wasm-dry-run` completed successfully and produced `build/web`.
- Firestore rules dry-run compilation passed.
- Storage rules dry-run compilation passed.
- `git diff --check` passed.
- `xcodebuild -project ios/Runner.xcodeproj -scheme Runner -configuration Debug -sdk iphonesimulator -showBuildSettings` passed, and `ios/Runner/Info.plist` passed `plutil -lint`.
- Hosting configuration has a SPA catch-all rewrite in `firebase.json:20-36`, plus explicit Isbank callback rewrites.
- Web metadata currently uses PetSupo in `web/index.html:40-57` and `web/manifest.json:2-8`.
- Storage CORS includes the three listed production Hosting origins and the two PetSupo custom-domain variants in `storage-cors.json`.
- The shared commercial dashboards use `BusinessRevenueDashboard`: Pet Taxi, Pet Hotel, Pet Shop, Vet, and Groomy wiring all resolve to the shared implementation in source.
- Adoption routes to its Impact dashboard rather than the commercial shared Revenue dashboard in `business_dashboard_page.dart:374-384`.
- Finance projection includes successful-payment trend buckets with `grossRevenue`, `platformFee`, `netRevenue`, and `paymentCount` in `functions/finance/financeSummaryProjector.js:113-133` and `245-256`, and uses `successfulPaymentAt` while excluding refunded/cancelled/reversed records at `109-112`.
- Server-owned finance collections are read-only to clients in `firestore.rules:789-852`; seller finance summaries are owner/finance-viewer readable and client-write protected.
- Storage fallback is deny-by-default at `storage.rules:34-36`.

## 8. Runtime checks still required

The browser/device connector was unavailable and no authenticated production session was accessible. The following remain required:

- Chrome desktop and Chrome device-toolbar widths 320, 375, 390, 500, 768, 900, 1100, and 1440+.
- Safari mobile width and iOS native build/run.
- Android native build/run; this environment has no Android SDK.
- Production `https://app.petsupo.com` hard reload, direct route refresh, browser history/back, PWA install, and service-worker update behavior.
- Authenticated email, Google, Apple (currently disabled), logout, refresh persistence, guest mode, creator/business protected routes, and same-tab/new-context session restore.
- Profile, pet, business, gallery, document, and video media requests with DevTools Network/Console evidence.
- Each completed dashboard at desktop, tablet, mobile Web, Android, and iOS widths; especially Pet Hotel duplicate finance composition and stream identity.
- Shared Revenue zero, loading, error, one-payment, same-day multi-payment, and 7/30/12-month scenarios.
- Full payment success/cancel/failure/duplicate callback/refund/return flows for Isbank, İyzico, marketplace checkout, subscriptions, Apple IAP, and Google Play Billing.
- Firestore emulator authorization matrix for every P1 rules finding.
- Scroll and tab-switch profiling to compare StreamBuilder widget identity, Stream identity, cancellation, and subscription creation.
- EN/TR/FA/RU finance and Adoption UI, including RTL and long-string overflow checks.
- Branding checks for browser tab, PWA install, startup/error fallback, native splash/icon, notification titles, share metadata, and payment callback screens.

## 9. Security test results

- Firestore rules compiled successfully with Firebase dry-run.
- Storage rules compiled successfully with Firebase dry-run.
- Firestore emulator started and stopped successfully.
- Existing repository tests do not provide a complete negative authorization matrix for the broad user/business/chat/social rules identified above. No new tests were added because this was an audit-only task.
- No production security claim is made without those emulator matrix tests.

## 10. Build and test results

| Check | Result | Notes |
|---|---|---|
| `flutter analyze` | **FAIL** | 1,291 issues; major compile errors are under `ai_exports/vet_context/**`, with additional production warnings/info. |
| `flutter test` | **PASS** | 150 passed, 9 skipped, 0 failed. |
| `flutter build web --release` | **Inconclusive as issued** | The standard command entered the WASM dry-run path and was interrupted after stalling in this environment. |
| `flutter build web --release --no-wasm-dry-run` | **PASS** | Release Web artifact built successfully. |
| Android build check | **NOT AVAILABLE** | Flutter reported no Android SDK configured. No Android compile result can be claimed. |
| iOS configuration check | **PASS** | Xcode project settings and Info.plist lint passed; workspace/simulator runtime compile was not available. |
| Functions syntax check | **PASS** | Node syntax checks completed without reported syntax errors. |
| Functions tests | **PASS** | 150 passed, 0 failed. |
| Firestore rules compile | **PASS** | Firebase dry-run compiled `firestore.rules`. |
| Storage rules compile | **PASS** | Firebase dry-run compiled `storage.rules`. |
| `git diff --check` | **PASS** | No whitespace errors. |

Generated `build/web` output was used for validation and is not treated as a source modification.

## 11. Recommended fix order

1. Lock down Firestore user/business/chat/vet-chat/social-post rules and add emulator denial tests.
2. Correct and end-to-end test the marketplace payment return URLs before enabling production checkout.
3. Disable or server-authorize Pet Boost until payment, entitlement, expiration, ranking, refund, and history behavior exists.
4. Remove the Pet Hotel outer finance wrapper and verify one shared Revenue destination/listener.
5. Fix financeLedger projection freshness and test event retries/idempotency.
6. Establish a clean analyzer gate by excluding or repairing `ai_exports/**`.
7. Complete Apple sign-in configuration or formally remove it from the release promise.
8. Complete authenticated browser/device QA at all required widths and platforms.
9. Finish localization, Adoption finance terminology cleanup, preview CORS policy, and storage upload constraints.

## 12. Files inspected

The audit inspected the following areas and directly related files:

- `pubspec.yaml`, `pubspec.lock`, `firebase.json`, `.firebaserc`, `storage-cors.json`
- `web/index.html`, `web/manifest.json`, `web/flutter_bootstrap.js`, `web/icons/**`, `public/**`
- `android/**`, `ios/**`
- `lib/auth_page.dart`, `lib/home_gate.dart`, `lib/user_profile_page.dart`, `lib/app_state.dart`
- `lib/ui/business/dashboard/business_dashboard_page.dart`
- Pet Taxi, Pet Hotel, Pet Shop, Vet, Groomy, and Adoption Center dashboard pages and directly related tabs
- `lib/ui/business/finance/business_revenue_dashboard.dart` / `pet_taxi_revenue_section.dart`, `seller_finance_repository.dart`, `seller_finance_summary.dart`, `seller_finance_widgets.dart`
- `functions/index.js`, `functions/finance/financeSummaryProjector.js`, `functions/finance/financeLedger.js`, Functions tests
- `firestore.rules`, `firestore.indexes.json`, `storage.rules`
- Checkout/payment services and active checkout widgets, including Isbank/Iyzico and subscription-related paths
- Dog Boost UI/model/ranking paths and relevant localization files
- Existing Flutter and Functions tests

## 13. Commands executed

- `git status --short`, `git branch --show-current`, `git log -1 --oneline`
- `rg`, `nl -ba`, `find`, and targeted source/config inspection commands
- `flutter analyze`
- `flutter test`
- `flutter build web --release`
- `flutter build web --release --no-wasm-dry-run`
- `flutter build apk --debug`
- `xcodebuild -project ios/Runner.xcodeproj -scheme Runner -configuration Debug -sdk iphonesimulator -showBuildSettings`
- `plutil -lint ios/Runner/Info.plist`
- Node syntax checks for Functions JavaScript
- `npm test` in `functions/`
- `firebase deploy --only firestore:rules --dry-run --project barkymatches-new`
- `firebase deploy --only storage --dry-run --project barkymatches-new`
- `firebase emulators:exec --only firestore --project demo-petsupo ...`
- `git diff --check`

## 14. Explicit audit-only statement

No application code, Dart files, Functions, Firestore rules, Storage rules, assets, hosting configuration, or deployment state was modified during this audit. The only file created is this report: `docs/PRODUCTION_QA_AUDIT_2026-08-02.md`.
