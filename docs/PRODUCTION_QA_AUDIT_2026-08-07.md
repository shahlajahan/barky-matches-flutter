# PetSupo Production QA Audit — 2026-08-10 Update

## 1. Executive Summary

This is a fresh audit of the current repository and the production Web
evidence supplied during the August 2026 regression work. It supersedes the
2026-08-07 conclusions where current evidence differs, while retaining the
historical disposition matrix below.

Current release recommendation: **CONDITIONAL GO**.

The remaining reasons are:

- Functions integration and Rules coverage still require an
  emulator/environment that is unavailable here;
- live acceptance remains pending for selected provider/device surfaces,
  including PET Boost.

The full Flutter test suite is now green: 264 passed, 9 skipped, and 0
failed. The former Pet Taxi failure was a stale time-dependent test fixture,
not a production defect.

No P0 or P1 security/data-loss issue was confirmed. The recommendation is a
conditional release recommendation based on the remaining scope-dependent
validation gaps, not a claim that the manually tested Web application is
currently unusable.

Evidence labels used below:

- **SOURCE** — current repository code inspected at the stated path.
- **TEST** — automated test executed in this audit.
- **PRODUCTION MANUAL** — production behavior manually verified during the
  recent investigation and supplied as current evidence; not an automated
  test.
- **ENVIRONMENT BLOCKED** — validation could not complete because tooling or
  an emulator was unavailable.
- **NOT RE-VERIFIED** — no current runtime evidence was available.

## 2. Current Repository / Release Baseline

| Item | Current result |
|---|---|
| Branch | `integration/mac-windows-2026-07-22` |
| HEAD | `ac6b060cc5206e000cbf477d5d474d21d8b0d75c` |
| HEAD subject | `fix: preserve vet service identity in public projections` |
| Origin relationship | `origin/integration/mac-windows-2026-07-22` points to the same HEAD |
| Existing stashes | Four preserved; none applied, dropped, or modified |
| Production writes | None |
| Deployment performed by this audit edit | None; the FCM worker is independently production-verified below |
| Staging/commit/push | None |

### Worktree classification

Relevant uncommitted worktree changes:

- `lib/services/social_auth_service.dart` — lazy Web GoogleSignIn fix.
- `lib/social/...` — Petplore diagnostic-output cleanup only; upload/schema
  behavior was not changed by the cleanup.
- `web/flutter_bootstrap.js` and `web/index.html` — temporary startup
  diagnostics removed.
- `web/firebase-messaging-sw.js` — new static Firebase Messaging worker,
  not yet committed; its production endpoint is now verified below.

Unrelated dirty files preserved:

- `android/app/google-services.json`
- `lib/ui/business/dashboard/vet/sections/vet_dashboard_services_tab.dart`
- `docs/PRODUCTION_QA_AUDIT_2026-08-07.md` (this report itself is being
  updated)
- the pre-existing formatting changes in `lib/social/pages/social_feed_page.dart`
  are not treated as part of the service-worker fix.

## 3. Changes Since the Previous Audit

Current evidence shows the following material changes since the old report:

- Service Promotion now has backend-owned activation, payment verification,
  projections, expiry checks, Featured Deal delivery, analytics, and owner
  performance access.
- Pet Boost now uses `PromotionCheckoutService` and the server-owned
  `createPromotionCheckout` / payment-verification path rather than a direct
  sponsorship-field write (`lib/dog_card.dart:616-665`,
  `functions/index.js:2783-2865`).
- Promotion ranking rejects expired/future projections at read time
  (`lib/promotion/ranking/promotion_ranking_state.dart:84-112`).
- Vet public service identity is preserved through projections in committed
  HEAD `ac6b060`; Web and mobile Vet detail pages were manually verified.
- GoogleSignIn construction is lazy and skipped on Web
  (`lib/services/social_auth_service.dart:98-120,166-180`).
- The temporary Firestore/Petplore/startup diagnostics were removed.
- `web/firebase-messaging-sw.js` was added after the production MIME defect
  was proven. The local release build copies it into `build/web`, and the
  production endpoint now returns the real JavaScript worker.

## 4. Previous Findings Disposition Matrix

| Previous finding | Current status | Current evidence |
|---|---|---|
| Dashboard RenderFlex overflow | **RESOLVED** | Constraint-aware metric-card implementation remains in current source; prior Android runtime verification remains valid. |
| Marketplace legacy callback | **RESOLVED** | Canonical `app.petsupo.com` callback/cancel paths remain in `lib/ui/petshop/widgets/checkout_button.dart`; automated checkout tests pass. |
| Client-authoritative Pet Boost security | **RESOLVED** | Ordinary clients cannot write sponsorship fields under `firestore.rules`; activation is now server/payment-backed. |
| Pet Boost incomplete payment/activation functionality | **PARTIALLY RESOLVED** | Current source and tests contain the complete checkout/activation path, but no new live Pet Boost payment was executed in this audit. |
| Apple Sign In disabled | **RESOLVED / OBSOLETE** | Apple support remains platform-gated and tested in `SocialAuthService`. |
| Adoption bank-account settings | **OBSOLETE** | No incorrect behavior was demonstrated; it remains an intentional business payout-settings entry point. |
| Unavailable social-post localization | **REGRESSED** | The old seven-warning count is stale. DevAudit now reports 15 hardcoded UI warnings, including the old unavailable-post string and new Promotion/Boost strings. |
| Full Flutter test startup stall | **RESOLVED** | Full tests now run and finish with 264 passed, 9 skipped, and 0 failed. |
| Functions integration test environment | **STILL OPEN / ENVIRONMENT BLOCKED** | The integration test remains pending without a Firestore emulator. |
| Web/PWA runtime not exercised | **RESOLVED** | Production Web was manually exercised, including auth and Petplore post/story flows. |
| Web Firestore ca9/b815 incident | **RESOLVED BY PRODUCTION MANUAL EVIDENCE** | After lazy Web GoogleSignIn, registered-user Web auth and Petplore post publishing were manually verified; no new ca9/b815 failure was observed. |
| Vet services disappearing | **RESOLVED** | `ac6b060` preserves canonical service identity; Vet services were manually verified on mobile and local Web. |
| Featured Deal service delivery/image path | **RESOLVED BY PRODUCTION MANUAL EVIDENCE** | Real promoted service, display image, Sponsored card, analytics/navigation, and bounded inventory were manually verified. |
| Missing FCM service worker / HTML MIME response | **RESOLVED — PRODUCTION VERIFIED** | Production returns HTTP 200 with `text/javascript; charset=utf-8`, 555 bytes, and the actual Firebase Messaging worker; no HTML fallback remains. |
| Pet Taxi revenue widget failure | **RESOLVED** | The production widget was correct. The test used fixed historical dates that fell outside the runtime seven-day window; the fixture now uses relative dates. |

## 5. Current P0 / P1 / P2 / P3

### P0

None confirmed.

### P1

None confirmed for authorization, payment truth, data integrity, or user
content loss.

### P2

1. **Pet Boost lacks a new live payment acceptance run.** The source path is
   now server-owned and tested, but production payment/provider behavior for
   PET was not re-executed in this audit.
2. **Emulator-dependent validation remains incomplete.** Functions integration
   and Rules coverage were not completed in this environment.

### P3

1. DevAudit reports 15 hardcoded UI strings requiring localization.
2. Analyzer backlog remains at 928 warnings/info diagnostics.
3. Hive emits direct dependency debug lines for IndexedDB object stores in
   Web release output. This is dependency-generated output, not a PetSupo
   logging defect; patching Hive was not authorized or justified.
4. Firebase Auth popup flows may emit browser COOP warnings. No functional
   auth defect was demonstrated.

## 6. Web Production Regression Investigation and Resolution

### Lazy GoogleSignIn

**SOURCE:** `lib/services/social_auth_service.dart:98-120,166-180`.

- `SocialAuthService` stores an optional `GoogleSignIn` instance.
- The constructor no longer creates `GoogleSignIn(scopes: ['email'])`.
- Web Google auth uses `GoogleAuthProvider` and Firebase Auth.
- Native Google auth creates the plugin lazily when the native path is used.

**TEST:** `test/services/social_auth_service_test.dart` and
`test/services/web_auth_startup_gate_test.dart` pass in the focused suite.

**PRODUCTION MANUAL:** Registered-user Web authentication, Petplore image
post publishing, Story publishing, and media rendering were manually verified
on `https://app.petsupo.com` after this change.

The historical ca9/b815 Firestore incident is therefore currently classified
as resolved by production evidence. No Firestore listener or persistence
redesign was made as part of this audit.

### Vet services

Committed HEAD `ac6b060` preserves canonical `id`/`serviceId` through public
business projections. The client retains a safe legacy path and never creates
synthetic IDs. The Laboratory target remains compatible with the canonical
form `service/VET/{businessId}/{serviceId}`.

**PRODUCTION MANUAL:** Vet → peteriumvet → Services was verified on mobile and
local Web. No production data was changed.

## 7. Authentication

| Flow | Current status | Evidence |
|---|---|---|
| Email/password login/registration | **SOURCE / TEST** | Current `AuthPage` and social/auth tests pass. |
| Google Web | **SOURCE / TEST / PRODUCTION MANUAL** | Firebase `GoogleAuthProvider` Web path; lazy plugin test; production Web login verified. |
| Google Android/native | **SOURCE / PRIOR DEVICE** | Native lazy path remains; prior physical-device verification is not rerun here. |
| Apple | **SOURCE / TEST** | Platform gating, recovery, linking, and cancellation tests pass. |
| Guest | **SOURCE / NOT RE-VERIFIED** | Existing guest path remains; no new device session. |
| Web redirect recovery | **SOURCE / TEST** | `web_auth_startup_gate_test.dart` passes. |
| Duplicate Web GIS startup | **RESOLVED** | Constructor no longer instantiates Web GoogleSignIn. |

No client IDs, Firebase configuration, or authentication rules were changed in
this audit.

## 8. Android / Firebase Identity

**SOURCE / PRIOR DEVICE VERIFICATION.** Current Android namespace and
application ID remain `com.petsupo.app`. The canonical Firebase Android App ID
and debug/release OAuth client blocks remain in
`android/app/google-services.json`.

The file is currently dirty but is unrelated to this audit and was not
modified. No new Android release build or physical-device run was performed.

## 9. Android Runtime / Build Status

**NOT RE-VERIFIED.** The previous report’s physical-device Google Sign-In and
Android release-build evidence remains historical. This audit performed no
Android build, store upload, or device test.

## 10. Firestore

**SOURCE / TEST / PRODUCTION MANUAL.** Current code still initializes Firebase
and Firestore through the existing startup path. No duplicate initialization,
listener refactor, persistence change, or readiness change was introduced in
this audit.

Current tests cover AppState identity transitions, public projections, social
listeners, Promotion projections, and Web auth startup. The production Web
ca9/b815 incident was manually resolved after the lazy GoogleSignIn change.

Rules continue to make Promotion authoritative collections backend-owned:
`firestore.rules:1251-1298`. Public business projections remain client-read,
not client-written.

Current Rules emulator/dry-run validation did not complete in this environment;
the Functions suite reports emulator-dependent Rules tests as skipped. This is
an environment limitation, not evidence of a Rules defect.

## 11. Storage

**SOURCE / TEST / PRIOR RULES VALIDATION / PRODUCTION MANUAL FOR SOCIAL FLOWS.**

Current social image paths use Web `putData` and native `putFile` in
`lib/social/pages/create_social_post_page.dart`; Story image creation uses the
same platform split in `lib/social/services/pet_story_service.dart`.

The current focused Social suite passes. Registered-user Web image post and
Story publishing were manually verified in production. No destructive Storage
operation occurred.

Storage Rules were not changed. A fresh emulator Rules run was environment
blocked; the prior source/rules validation remains historical rather than a
new clean emulator result.

## 12. Cloud Functions

The current Functions suite reached:

- 227 passed
- 57 skipped
- 0 failed assertions
- 1 cancelled/pending integration test

`test/resolveBusinessRequest.integration.test.js` remains dependent on a
Firestore emulator or configured test environment and was interrupted after
remaining pending. The emulator was not used against production.

Promotion and public-projection tests passed, including display-image
resolution, bounded Featured Deal delivery, circular fairness, backfill
idempotency, and authority checks.

## 13. Payments / Marketplace

**PARTIAL SOURCE/TEST; PRODUCTION MANUAL FOR SERVICE PROMOTION.**

- Service Promotion payment through İş Bank was successfully executed in a
  real production test.
- Campaign activation, timestamps, projection, Featured Deal display, and
  performance access were verified for the VET service flow.
- Marketplace callback and cancellation source contracts remain canonical and
  automated tests pass.
- Marketplace provider end-to-end execution was not rerun in this audit.
- Pet Boost now uses the shared server payment/activation path, but a live PET
  payment was not run.

No payment configuration or production payment data was modified.

## 14. Business / Public Projections

**SOURCE / TEST.** Functions tests pass for public builders, canonical sector
isolation, service identity preservation, logo/display-image normalization,
idempotent synchronization, and legacy service compatibility.

The current Worktree also contains the new `web/firebase-messaging-sw.js`,
which is unrelated to public business projection data.

## 15. Product Verticals

| Area | Current status | Evidence / limitation |
|---|---|---|
| Home / Featured Deal | **RESOLVED BY PRODUCTION MANUAL + TEST** | Sponsored Service Deal, bounded inventory, image, analytics, placeholder behavior, and five-minute refresh tests/manual checks pass. |
| Vet | **RESOLVED FOR RECENT REGRESSION** | Services identity fix in HEAD; mobile/local Web manual verification. Broader booking/provider runtime not rerun. |
| Groomy | **SOURCE / TEST** | Projection, service-card Promotion action, and detail stream tests pass; no new production session. |
| Pet Hotel | **SOURCE / TEST** | Public/detail/booking paths present; no live booking. |
| Pet Taxi | **RESOLVED — SOURCE / TEST / PRODUCTION MANUAL** | Public projection, ride grouping, and revenue-section tests pass. Product-owner manual verification found no runtime revenue defect. |
| Adoption | **SOURCE / TEST** | Public projection/detail paths present; bank settings remains intentional. No live adoption request. |
| Pet Shop | **SOURCE / TEST** | Product, checkout, callback, and Web/native path tests pass; no live purchase. |
| Marketplace | **SOURCE / TEST** | Checkout/payment lifecycle tests pass; no new provider transaction. |
| Creator | **SOURCE / TEST** | Dashboard data/navigation tests pass; no deployed browser session. |
| Finance | **SOURCE / TEST WITH ENVIRONMENT SKIPS** | Finance roles, immutable snapshots, payouts, and reports covered; emulator/storage-dependent cases remain limited. |
| Moderation | **SOURCE / TEST** | Authorization and moderation paths covered; no live moderation action. |
| Notifications | **SOURCE / VALIDATION GAP** | The Messaging service-worker endpoint is production-verified; end-to-end device notification delivery was not rerun. |
| Lost & Found | **SOURCE / NOT RUNTIME-VERIFIED** | No new end-to-end production session. |
| Playmate | **SOURCE / TEST** | Promotion ranking and related paths covered; no new production session. |
| Deep links | **SOURCE / TEST** | Same-origin route tests pass; no full deployed route matrix. |
| PWA | **RESOLVED FOR THE MIME INCIDENT** | Local assets pass and production returns the Firebase Messaging worker as JavaScript; broader PWA behavior remains scope-dependent. |

## 16. Social / Petplore

**PRODUCTION MANUAL / TEST.** The registered-user Web flows were manually
verified after the auth lifecycle fix:

- feed loads;
- image Post publishes;
- image Story publishes;
- uploaded media renders;
- author/profile media can fail independently without blocking the post flow.

Current source retains Web-safe `XFile`/bytes handling and native file handling.
Focused social/auth tests pass. No temporary diagnostic strings remain in
`lib`, `web`, `test`, or the generated Web build:

```text
FirestoreLifecycle
PetplorePostBoundary
PetploreStoryBoundary
DIAGNOSTICS_ENABLED
GOOGLE_SIGNIN_INIT_
petsupo-startup
```

The current worktree still contains ordinary `debugPrint` calls in some
application files, but release startup replaces `debugPrint` with a no-op in
`lib/main.dart:915-916`. The visible `Got object store...` lines come from
Hive 2.2.3’s direct `print` call, not PetSupo source.

## 17. Production Web / PWA

### Local build

The repository workflow is:

```bash
npm run build:web
```

This runs:

```text
flutter build web --release --no-wasm-dry-run
node scripts/sync-assetlinks.js
```

`firebase.json:13` serves `build/web`; the predeploy assetlinks copy is
`scripts/sync-assetlinks.js`. The catch-all SPA rewrite remains unchanged.

The clean local build produced:

```text
build/web/firebase-messaging-sw.js  555 bytes
```

Both `web/firebase-messaging-sw.js` and the generated file pass `node --check`
and contain Firebase Messaging JavaScript rather than HTML.

### Production worker status

Read-only production verification:

```text
GET https://app.petsupo.com/firebase-messaging-sw.js
HTTP/2 200
Content-Type: text/javascript; charset=utf-8
Content-Length: 555
```

The response body was also inspected and contained the actual Firebase
Messaging JavaScript, including Firebase app compat, Firebase messaging
compat, `firebase.initializeApp(...)`, and `firebase.messaging()`. It did not
contain `index.html` or an HTML content type.
The historical SPA-fallback MIME defect is therefore **RESOLVED — PRODUCTION
VERIFIED**. The source/build correction and production artifact agree.

No Hosting rewrite was weakened or removed.

## 18. Production Console / Logging Audit

| Category | Current status | Classification |
|---|---|---|
| Temporary PetSupo diagnostics | Removed from source/build | RESOLVED |
| Hive object-store messages | Still emitted by Hive 2.2.3 direct `print` | Dependency-generated debug noise |
| Auth COOP popup warning | May occur during popup auth | Browser/auth warning; no functional defect proven |
| FCM worker MIME error | Resolved in source, local build, and production | Historical Hosting/build defect; resolved |
| Ordinary release `debugPrint` calls | Suppressed by release override | Not release-visible application telemetry in normal build |

No global browser console override was introduced. No Firestore/auth behavior
was changed for console hygiene.

## 19. Localization

**STILL OPEN, WITH INCREASED COUNT.** `devaudit scan` on the current source
reported 15 warnings, 0 errors, across 559 files. They include:

- six Apple account-recovery strings in `lib/apple_account_recovery_page.dart`;
- `This post is unavailable` in `lib/social/pages/social_post_route_page.dart`;
- Pet Boost fallback text in `lib/dog_card.dart`;
- four Promotion plan/action strings;
- a Pet Shop Boost tooltip.

The prior seven-warning count must not be reused.

## 20. Test / Build Matrix

| Check | Current result |
|---|---|
| `git diff --check` | PASS |
| `flutter analyze --no-pub` | FAIL gate: 928 warnings/info diagnostics, no analyzer errors observed in output |
| `flutter test --no-pub` | PASS: 264 passed, 9 skipped, 0 failed |
| Focused auth + social suite | PASS: 34 tests |
| Functions `npm test` | 227 passed, 57 skipped, 0 assertion failures; one emulator-dependent integration test remained pending and was interrupted |
| `npm run build:web` | PASS |
| `node --check web/firebase-messaging-sw.js` | PASS |
| `node --check build/web/firebase-messaging-sw.js` | PASS |
| Promotion/public-projection Functions tests | PASS within the Functions run |
| DevAudit | PASS command, 15 warnings, 0 errors |
| Firestore Rules dry-run | ENVIRONMENT BLOCKED / not completed cleanly in this audit |
| Storage Rules dry-run | ENVIRONMENT BLOCKED / not completed cleanly in this audit |
| Android release build | NOT RE-VERIFIED |
| Current FCM worker Hosting verification | PASS: HTTP 200, JavaScript MIME, 555-byte real worker body |

The former full Flutter failure was in
`test/ui/business/dashboard/pet_taxi_revenue_section_test.dart`. The test used
fixed August 1/2, 2026 revenue dates while the production widget correctly
filters against `DateTime.now()`; after the dates fell outside the selected
seven-day period, the widget correctly rendered its empty trend state. The
fixture now uses dates relative to the test date. This was classified as a
TEST FIXTURE BUG; no Pet Taxi production code change was required.

## 21. Remaining Release Risks

1. Provide a Firestore/Auth emulator environment and complete the cancelled
   Functions integration/Rules coverage.
2. Re-run live PET Boost, marketplace payment, notification delivery, deep-link
   and Android release checks if those surfaces are in release scope.
3. Reduce the analyzer backlog and localize the 15 hardcoded strings.

## 22. GO / NO-GO

**CONDITIONAL GO.**

This is based on current validation, not on the historical Web application
being unusable. No confirmed P0/P1 production, security, data-integrity,
automated-test, or Pet Taxi runtime blocker remains. The FCM worker defect is
resolved in production. Conditional release requirements remain for
emulator-dependent Functions/Rules coverage and for live acceptance surfaces
that are included in the particular release scope, such as PET Boost. The
analyzer result is technical debt because the current output contains
warnings/info diagnostics and no observed analyzer errors; it is not treated
as an independent blocker here.

The following are not current blockers based on available evidence:

- Web GoogleSignIn eager initialization;
- registered-user Web Petplore publishing;
- the historical Web Firestore ca9/b815 incident;
- Vet service identity disappearance;
- real Service Promotion Featured Deal display;
- Pet Taxi Revenue runtime and automated test coverage;
- Promotion client-write authority.

## 23. Recommended Follow-up Order

1. Run Rules and Functions integration tests with the Firestore/Auth emulator.
2. Perform the remaining live provider, notification, deep-link, Android, and
   PET Boost acceptance checks required by the release scope.
3. Re-run the full Flutter suite and analyzer.
4. Localize the 15 current warnings.

## 24. Audit Limitations

- No source file other than this report was intentionally modified during this
  audit. The pre-existing worktree remains dirty and was preserved.
- No production Firestore, Storage, payment, auth, or other data was written.
- No deployment, commit, push, stage, reset, restore, checkout, or stash
  operation was performed.
- Production Web conclusions are manual verification evidence, not automated
  browser tests.
- Android runtime/build evidence is historical where marked; no new device run
  occurred.
- Rules/emulator validation could not complete in the available environment.
- The current production FCM worker endpoint was independently re-queried and
  verified as described above; this audit-edit task performed no deployment.
