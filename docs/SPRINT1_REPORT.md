# Creator Referral Engine — Sprint 1 Report

**Sprint goal:** Build the Creator Foundation only.
**Reference:** `docs/architecture/creator-referral-engine.md`
**Date:** 2026-08-01

---

## Implemented

### 1. SEC-1 fix (`firestore.rules`) — highest priority, completed first

The `creator` map on `users/{uid}` is now server-authoritative. Neither
the document owner nor an admin acting through the client SDK can create
or modify it — only the four Cloud Functions below (Admin SDK, which
bypasses these rules) can.

**This was verified against a running Firestore emulator, not just code
review** — and the first version of the fix was wrong. Details in Known
Limitations below; the fix that's actually in the repo now has been
empirically confirmed to work with four separate emulator tests:

| Test | Actor | Action | Result |
|---|---|---|---|
| A | Self (non-admin) | Write `creator.enabled=true` on own doc (the exact exploit) | **403 — denied** |
| B | Self (non-admin) | Write an unrelated field (`username`) on own doc | **200 — allowed** (fix is surgical) |
| C | Self (non-admin) | Create a brand-new own doc with `creator` baked in | **403 — denied** |
| D | Admin (via client SDK) | Write `creator` on someone else's doc | **403 — denied** (per ADR Design Invariant: never client-writable, by anyone) |

### 2. Firestore — only the Sprint 1 collections

- `users/{uid}.creator` map (`enabled`, `status`, `referralCode`,
  `currentCampaign` — no `referralLink` field; see AppState changes below).
- `referralCodes/{code}` collection — public read, Functions-only write.

No `creatorApplications`, `referralClicks`, `referralAttributions`,
`referralCampaigns`, or `referralDailyStats` — all correctly out of scope
per the ADR's later sprints.

### 3. Cloud Functions (`functions/index.js`) — exactly the four requested

All four are admin-only (`isAdminUser`), region `europe-west3`, and are
the *only* code path that can touch `users/{uid}.creator`:

- **`createCreatorProfile`** — bootstraps `creator: { enabled: false,
  status: 'inactive', referralCode: null }`. Idempotent (calling twice is
  a no-op, not an error).
- **`assignReferralCode`** — generates a unique, permanent code (username-
  derived prefix + random suffix), using the ADR's documented uniqueness
  idiom: the code as the `referralCodes/{code}` document ID, with
  `transaction.create()` failing on collision and a retry loop. Idempotent
  if a code already exists.
- **`activateCreator`** — sets `enabled: true`, `status: 'active'`.
  Refuses to activate a profile that has no referral code yet.
- **`deactivateCreator`** — sets `enabled: false`, `status: 'inactive'`.
  Does **not** clear the referral code (permanent per the ADR; history
  isn't rewritten).

No referral tracking, no rewards, no payouts, no applications, no admin
review UI — none of these functions are wired to any UI trigger yet, by
design (see Known Limitations).

`npm run lint` (syntax check) and the existing `npm test` suite —
**147/147 passing**, unaffected — both pass.

### 4 & 5. Flutter + Web — real Firestore reads for exactly 4 fields

| Field | Source | Status |
|---|---|---|
| Creator Name | `AppState.username` | Already real (pre-dates this sprint) |
| Status | `AppState.creatorStatus` ← `creator.status` | **New this sprint** |
| Referral Code | `AppState.creatorReferralCode` ← `creator.referralCode` | Already wired; now has a real writer (`assignReferralCode`) for the first time |
| Referral Link | `AppState.creatorReferralLink` — **now computed**, not stored: `https://petsupo.com/r/{code}` | **Changed this sprint** — the ADR flagged the old stored-field version as a two-sources-of-truth risk; removed the Firestore-read path, replaced with a pure derivation |

Both dashboards (mobile lightweight, Web full) display a `CreatorStatusPill`
showing this real status. Everything else — KPI numbers, activity,
payout, charts, badges/progress — is unchanged mock data from
`CreatorDashboardData.mock()`, and is now **visibly marked**: every
placeholder section (Stats grid, Recent Activity, Upcoming Payout,
Performance chart, Reward Breakdown, Payout History, Badges &
Achievements) carries a small "Sample data" badge
(`CreatorPlaceholderBadge`) in both the mobile and Web dashboards. This
is the user-facing half of "clearly mark placeholder sections"; the
`TODO(creator-backend)` comment in `creator_dashboard_data.dart` is the
code-facing half.

`flutter analyze` on every touched file: **zero new errors** (one
pre-existing, unrelated error in `lib/other_user_dog_page.dart` — not
touched by this sprint, not reachable from the Web build's compile
graph, confirmed in a prior session). Full `flutter test` suite: **all
tests passing**, including the pre-existing `creator_dashboard_data_test.dart`.

---

## Deferred (per the ADR, intentionally not touched)

- Referral attribution (`referralAttributions`)
- Click tracking (`referralClicks`, `trackReferralClick`)
- Campaigns (`referralCampaigns`)
- Rewards (creator sector adapter, canonical payable records)
- Analytics (`referralDailyStats`, real funnel metrics)
- Payouts (any integration with the shared Payout Engine)
- Creator Applications (`creatorApplications` collection, `submitCreatorApplication`)
- Admin Review Flow (any admin UI page for creators)

---

## Known limitations

1. **No way to invoke the four new functions from the app yet.** This is
   by design — the Admin Review Flow that would call them is explicitly
   deferred. Today, running them requires the Firebase Console's function
   tester, `firebase functions:shell`, or a script. A creator cannot be
   onboarded end-to-end without one of these until a later sprint builds
   the admin UI.
2. **`assignReferralCode`'s "does this user already have a code" check is
   not fully transactional** against two concurrent admin calls for the
   same uid — acceptable for an admin-only, low-frequency foundation
   tool; would need hardening (re-checking inside the same transaction as
   the code-collision check) if this ever becomes higher-concurrency.
3. **The SEC-1 fix initially shipped with a real gap**, caught only by
   testing against the emulator, not by code review: `firestore.rules`
   had a nested `match /{document=**}` block under `match
   /users/{userId}`, originally written (before this sprint) to grant
   subcollection access. Firestore's recursive wildcard also matches the
   *parent* document when it matches zero path segments, and rules are
   OR-combined across every matching statement — so that block was
   silently re-granting the exact unrestricted write my new rule was
   supposed to remove. Fixed by applying the identical `creator`-field
   restriction inside that block too. Documented in the rules file itself
   so it isn't lost. This is exactly the kind of gap that "looks correct"
   in review and only shows up under an actual write attempt — worth
   knowing if similar nested-wildcard patterns exist elsewhere in this
   rules file for other collections.
4. **`petsupo.com` (the referral link's domain) is not confirmed to be a
   live, routable site.** The link format follows the ADR exactly; whether
   that marketing domain actually exists and resolves is outside this
   sprint's scope to verify.
5. **Deploy status: nothing in this sprint has been deployed.** `firestore.rules`
   and `functions/index.js` changes exist only in the working tree —
   verified locally (Firestore emulator, `npm test`, `flutter analyze`/`flutter test`)
   but not pushed to `barkymatches-new`. Deploying rules and functions is
   a production-affecting action; doing so wasn't part of this sprint's
   ask.

---

## Files changed

### Firestore
- `firestore.rules` — SEC-1 fix (both the explicit `users/{userId}` rules
  and the nested wildcard); new `referralCodes/{code}` rule.

### Cloud Functions
- `functions/index.js` — added `createCreatorProfile`, `assignReferralCode`,
  `activateCreator`, `deactivateCreator`, and their shared helpers
  (`normalizeCreatorUid`, `randomCreatorCodeSuffix`, `creatorCodeBase`,
  `requireCreatorAdmin`). Purely additive — nothing existing was modified.

### Flutter — AppState
- `lib/app_state.dart` — added `creatorStatus` (field + getter, populated
  in all four places `creatorEnabled` already is: live listener, Hive
  cache, one-shot load, sign-out reset); changed `creatorReferralLink`
  from a stored-field read to a computed getter.

### Flutter — UI
- `lib/ui/creator/creator_dashboard_page.dart` — status pill, placeholder
  badges on Stats/Activity/Payout.
- `lib/ui/creator/creator_dashboard_web_page.dart` — status pill,
  placeholder badges on KPI grid/Timeline/Payout History/Badges section.
- `lib/ui/creator/creator_status_pill.dart` — **new**, shared between
  mobile and Web.
- `lib/ui/creator/creator_placeholder_badge.dart` — **new**, shared
  between mobile and Web.
- `lib/ui/creator/web/creator_performance_chart.dart` — placeholder badge
  added to its header.
- `lib/ui/creator/web/creator_reward_donut.dart` — placeholder badge
  added to its header.

### Localization
- `lib/l10n/app_en.arb`, `app_fa.arb`, `app_ru.arb`, `app_tr.arb` — added
  `creatorStatusLabel`, `creatorStatusActive`, `creatorStatusInactive`,
  `creatorSampleData` (translated into all four already-supported
  locales) plus the previously-added `creator*` keys from the prior
  phase. Regenerated `lib/l10n/app_localizations*.dart` via `flutter gen-l10n`.

### Tests
- `test/ui/creator/creator_dashboard_data_test.dart` — pre-existing,
  unmodified, still passing (currency/date formatting, `generateSeries`).
- No new automated test for the SEC-1 fix or the Cloud Functions is
  checked into the repo — verification was done manually against a local
  Firestore emulator and the existing `functions/test/*.test.js` suite
  (147/147 passing, unaffected). Adding a permanent
  `@firebase/rules-unit-testing`-based regression test for SEC-1 would be
  a reasonable follow-up given how easily the nested-wildcard gap
  reintroduces itself.
