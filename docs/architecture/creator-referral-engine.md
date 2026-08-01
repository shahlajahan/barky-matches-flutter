# Creator Referral Engine

**Status:** Proposed
**Version:** 1.0
**Date:** 2026-07-31

---

# Purpose

This document defines the target architecture for the PetSupo Creator
Program's referral engine: how a user becomes an approved creator, how
referral codes/links are generated and attributed, how a referral becomes
"qualified," how a qualified referral becomes a reward, and how a reward
becomes a payout.

It follows directly from the end-to-end audit of the existing Creator
Program UI (`docs/audits/` — Flutter/Web dashboards are real and correctly
wired; everything upstream of them — application, approval, code
generation, attribution, qualification, rewards, payouts — is currently
absent or mocked).

This document intentionally contains **architecture only**. No
implementation code.

---

# Goals

- Let approved users become "Creators" through a real application/review
  flow, not a manually-edited Firestore field.
- Generate a unique, permanent referral code and link per creator.
- Attribute new users and new verified businesses to the creator who
  referred them, exactly once, resistant to obvious abuse.
- Turn a real, qualifying action (not a raw click, not a bare signup) into
  a reward.
- Pay that reward out using the platform's **existing** shared financial
  infrastructure (Payout Engine V2 — see `docs/architecture/payout-engine-v2.md`),
  not a second, parallel one.
- Give creators and admins accurate analytics without the cost or fraud
  exposure of aggregating raw event data live.
- Do all of the above without weakening any existing security rule or
  payment-integrity guarantee already in production.

---

# Architecture Overview

```
        Applicant                         Referred Visitor
            │                                    │
            ▼                                    ▼
  creatorApplications/{id}            referral link (?ref=CODE)
            │                                    │
     Admin review (Cloud Fn)                     ▼
            │                          trackReferralClick (Fn)
            ▼                                    │
   users/{uid}.creator                 referralClicks/{id} (raw, TTL)
   + referralCodes/{code}                        │
            │                          (rollup, scheduled) 
            │                                    ▼
            │                        referralDailyStats/{creatorUid}_{date}
            │
            │                          visitor signs up / registers a business
            │                                    │
            │                                    ▼
            │                     attributeReferral (Fn) — once per user
            │                                    │
            │                                    ▼
            │                     referralAttributions/{referredUid}
            │                            status: pending
            │                                    │
            │                     evaluateReferralQualification (Fn)
            │                     evaluatePartnerReferralQualification (Fn)
            │                                    │
            │                            status: qualified
            │                                    ▼
            │                       canonical payable record
            │                        (Standardized Payable Contract —
            │                         see payout-engine-v2.md)
            │                                    │
            └───────────────────────►  Shared Payout Engine
                                                  │
                                        ┌─────────┴─────────┐
                                        ▼                   ▼
                                   payoutIndex        financialEvents
                                (same Admin Payouts    (same immutable
                                 page, zero UI change)      ledger)
```

The only genuinely new subsystem is everything **above** "canonical
payable record." Below that line, Creator rewards are just another sector
flowing through infrastructure that already exists and is already audited.

---

# Core Principles

## 1. Reuse the Shared Payout Engine — do not build a second financial system

Payout Engine V2 was explicitly designed to support "future business
sectors" on one shared ledger and one shared read projection
(`payoutIndex`). Creator rewards are a new *source*, not a new *system*.

Concretely: a "qualified referral" or "verified partner referral" becomes
a canonical payable record via a **creator sector adapter**, registered
the same way the vet/groomy/pet_hotel/pet_taxi/pet_shop adapters already
are. It projects into the same `payoutIndex` collection the Admin Payouts
page already reads exclusively (migrated earlier this project). **This
means shipping Creator payouts requires zero Admin UI changes** — the
existing card, the existing weekly batch scheduler, the existing refund/
debt-recovery machinery all apply unchanged.

Anything that duplicates `payoutIndex`, invents a parallel
`creatorPayouts` collection, or bypasses the shared ledger is a
architecture violation, full stop.

## 2. A reward is earned by qualification, never by a click

Clicks are a vanity/diagnostic signal only. They must never influence
reward amount, creator level, or payout eligibility. Only a `qualified`
`referralAttributions` document may ever produce a payable record. This is
enforced structurally (see Firestore Schema), not just by convention.

## 3. Every reward is traceable to exactly one source document

Mirrors the existing payout engine's traceability requirement. A creator
reward must carry a stable reference back to the `referralAttributions`
document (and, for partner referrals, the `businesses/{id}` document) that
produced it — required for clawback, audit, and dispute resolution.

## 4. History is immutable; status changes, facts don't

If a referred user is later banned, or a referred business is later
delisted, the original attribution and qualification facts are not
deleted or rewritten. A new status transition (`invalidated`) is recorded,
and if a reward already entered the payout engine, the *existing*
refund/debt-recovery mechanism handles the clawback — Creator rewards do
not get a bespoke reversal path.

## 5. Writes that change financial or trust state are server-only

No client write ever sets `creatorEnabled`, a creator `level`, a
`referralAttributions.status`, or anything that participates in a reward
calculation. See **Security Rules** — this principle is currently
**violated** in production (see Finding SEC-1) and must be fixed as a
prerequisite, not a nice-to-have.

---

# Firestore Schema

## `creatorApplications/{applicationId}`

The application/review record. Mirrors the existing `businesses/{id}`
approval shape (`status: pending|approved|rejected`, admin-reviewed) so
existing admin-tooling conventions and Firestore rule patterns transfer
directly.

| Field | Type | Notes |
|---|---|---|
| `applicantUid` | string | Owner. One pending application per uid, enforced by the submit function (transactional check), not by rules alone. |
| `displayName`, `handle` | string | Public-facing identity. |
| `role` | string | Pet Influencer / UGC Creator / Veterinarian / Groomer / Trainer / Blogger / Brand Ambassador — enum, not free text. |
| `socialLinks` | map | Instagram/TikTok/YouTube/etc., optional per platform. |
| `audienceSizeEstimate` | number | Self-reported; informational only, never trusted for reward math. |
| `status` | string | `pending` \| `approved` \| `rejected`. |
| `rejectionReason` | string? | Set on reject. |
| `reviewedBy` | string? | Admin uid. |
| `reviewedAt` | timestamp? | |
| `createdAt` / `updatedAt` | timestamp | |

## `users/{uid}.creator` (map, sibling to the existing `business` map)

The contract the Flutter app already reads via `AppState._applyCreatorMap`
(built and shipped in the previous phase of this work).

| Field | Type | Notes |
|---|---|---|
| `enabled` | bool | Gates Profile visibility. Server-set only. |
| `applicationId` | string | Back-reference to the approved application. |
| `referralCode` | string | The single canonical code. See below — **the link is derived, not stored.** |
| `level` | string | `Starter` \| `Rising` \| `Pro` \| `Elite` \| `Legend`. Server-computed by the qualification function, never client-computed. |
| `levelProgress` | number | 0–100, cached, recomputed alongside `level`. |
| `currentCampaignId` | string? | References `referralCampaigns/{id}`. |
| `status` | string | `active` \| `suspended` \| `banned`. Suspension freezes new attributions without deleting history (Principle 4). |
| `suspendedReason` | string? | |
| `createdAt` / `updatedAt` | timestamp | |

**Refinement over the current shipped contract:** `AppState` today also
exposes `creatorReferralLink` as if it were an independently stored field.
It should not be stored at all — the link is always
`https://petsupo.com/r/{referralCode}` (public marketing domain per the
original spec, *not* `app.petsupo.com` — see App Flow) computed from the
one canonical field. Storing both invites drift (code changes, link
doesn't, or vice versa). `AppState` should derive it client-side; this is
a small follow-up change to the already-shipped code, not a new field.

## `referralCodes/{code}` (document ID = the code itself)

Exists purely to get atomic, race-free uniqueness from Firestore, which
has no native unique-constraint mechanism. Using the code as the document
ID and creating it inside the same transaction that approves the
application (`create()`, which fails if the doc exists) is the same idiom
this codebase already relies on for `orders/{orderId}` and
`websub_{...}` deterministic IDs.

| Field | Type | Notes |
|---|---|---|
| `creatorUid` | string | Reverse lookup for click/attribution handling. |
| `active` | bool | Set false on suspension/ban instead of deleting — a dead code should 404 gracefully, not silently vanish from history. |
| `createdAt` | timestamp | |

## `referralClicks/{clickId}` — raw, high-volume, short-lived

Append-only. **Never read directly by any dashboard** — see Analytics.
Should carry a TTL policy (Firestore TTL field) to auto-expire raw rows
after rollup, e.g. 30–90 days, once `referralDailyStats` has absorbed them.

| Field | Type | Notes |
|---|---|---|
| `referralCode` | string | |
| `creatorUid` | string | Denormalized for cheap querying pre-rollup. |
| `timestamp` | timestamp | |
| `ipHash` | string | Hashed, never raw IP — privacy + still usable for velocity heuristics. |
| `userAgentHash` | string | |
| `campaignId` | string? | From `utm`/query params. |
| `landingPath` | string | |

## `referralAttributions/{referredUid}` (document ID = the referred user's uid)

The central join between "someone was referred" and "did it turn into
anything." One-per-referred-user is enforced structurally by using their
uid as the document ID — a second attribution attempt is a no-op create
failure, not a application-level check that can be raced.

| Field | Type | Notes |
|---|---|---|
| `referralCode` | string | |
| `creatorUid` | string | |
| `attributedAt` | timestamp | |
| `source` | string | `link` \| `code_entry` (typed at signup). |
| `kind` | string | `user` \| `business` — which qualification rule applies. |
| `status` | string | `pending` \| `qualified` \| `rewarded` \| `invalidated`. |
| `qualifiedAt` | timestamp? | |
| `invalidatedReason` | string? | `fraud` \| `self_referral` \| `chargeback` \| `account_deleted` \| `manual_review`. |
| `payableRef` | string? | Set once a canonical payable record exists — the traceability link required by Principle 3. |

## `referralCampaigns/{campaignId}` — server-controlled config, not hardcoded constants

| Field | Type | Notes |
|---|---|---|
| `name` | string | e.g. "Summer Tail Wagger Challenge". |
| `active` | bool | |
| `qualifiedUserReward` | number | Amount per qualified user referral. |
| `verifiedPartnerReward` | number | Amount per verified partner referral. |
| `startAt` / `endAt` | timestamp | |

Mirrors the existing `webSubscriptionCatalog()` server-defined-pricing
pattern already used for subscriptions — reward amounts must be changeable
by ops without a redeploy, and must never be trusted from the client.

## `referralDailyStats/{creatorUid}_{yyyy-mm-dd}` — aggregated rollup

| Field | Type | Notes |
|---|---|---|
| `clicks`, `attributions`, `qualified`, `rewardedAmount` | number | Written only by the scheduled rollup function. |

This is what both the mobile and Web dashboards should read for
"Performance Overview" once real data exists — never the raw
`referralClicks` collection.

## Explicitly *not* a new collection: rewards/payouts

Per Core Principle 1, a "qualified" attribution produces a canonical
payable record consumed by the **existing** Payout Engine V2 pipeline
(`payoutIndex`, `financialEvents`) via a new `creator` sector adapter. See
that document's "Sector Adapter" and "Phase 1 — Standardized Payable
Contract" sections for the exact shape the creator adapter must conform
to; this document does not redefine it.

---

# Cloud Functions

Design only — triggers, contracts, and authorization, no code.

| Function | Trigger | Auth | Responsibility |
|---|---|---|---|
| `submitCreatorApplication` | `onCall` | Authenticated, non-guest | Validates required fields; rejects if an existing `pending` application exists for the uid (transactional read-then-write); creates `creatorApplications/{id}`. |
| `reviewCreatorApplication` | `onCall` | Admin only (`isAdminUser`) | Approve or reject. **Approve**, in one transaction: generate a unique code (retry-on-collision against `referralCodes` doc-create), create `referralCodes/{code}`, write `users/{uid}.creator` (`enabled: true`, `status: active`, `level: 'Starter'`), update the application to `approved`. **Reject**: update status + reason only. |
| `trackReferralClick` | `onRequest`, public | None — unauthenticated by necessity (visitor isn't signed in yet); **must** be behind App Check (see Fraud Prevention, FRAUD-1) | Validates the code resolves to an `active` `referralCodes` doc; writes one `referralClicks` row; never writes to `users` or `payoutIndex`. |
| `attributeReferral` | `onCall` | Authenticated (called right after the referred user's own account creation completes) | Validates code is active; rejects if `referralAttributions/{callerUid}` already exists (idempotent no-op, not an error, in case of client retry); rejects self-referral (`creatorUid == callerUid` after resolving both to the same underlying identity where linkable); creates the attribution as `pending`. |
| `attributePartnerReferral` | Same shape, invoked from the existing business-registration flow if a code was entered | Authenticated | Same as above with `kind: 'business'`; the qualifying event is the *existing* business-approval flow, not a new one. |
| `evaluateReferralQualification` | Scheduled (e.g. daily) | System | Scans `pending`, `kind: 'user'` attributions; applies the qualification business rule (see Business Rules); on pass, transitions to `qualified`, emits the canonical payable record, stamps `payableRef`. |
| `evaluatePartnerReferralQualification` | Firestore trigger on `businesses/{id}` status transitioning to `approved` | System | If that business's registration recorded a referring code, transitions the matching attribution to `qualified` and emits a payable record — event-driven, not polling, since the qualifying moment (business approval) already exists as a discrete event. |
| `invalidateReferralReward` | `onCall` (admin) **and** internal trigger from existing refund/chargeback/account-deletion flows | Admin, or system-internal | Marks an attribution `invalidated`; if a payable record was already emitted, hands off to the **existing** payout-engine refund/debt-recovery mechanism rather than inventing a second reversal path. |
| `suspendCreator` / `reinstateCreator` | `onCall` | Admin only | Sets `users/{uid}.creator.status`; suspension immediately stops new attributions/qualifications for that code without touching history. |

All admin-authorization checks reuse the existing `isAdminUser(db, uid)`
helper already used throughout `functions/index.js` — no new admin-role
concept.

---

# Security Rules

## Finding SEC-1 — must fix before any of this ships

`firestore.rules:311` currently grants:

```
match /users/{userId} {
  allow read: if isSignedIn();
  allow create, update, delete: if isOwnUserDoc(userId) || isAdmin();
  ...
}
```

This is a **whole-document** write grant with no field restriction. Once a
`creator` map exists on this schema, any signed-in user can write
`creator.enabled = true`, `creator.level = 'Legend'`, or any other field
on themselves directly from the client. Today this only fabricates UI
state (harmless, since rewards are mocked); the moment qualification
starts producing real payable records gated on `creator.enabled`, **this
becomes a direct path to financial fraud** — self-granting creator status
and farming referral rewards with no application, no review, no
qualification.

This must be closed with a field-level restriction (Firestore rules
support this via `request.resource.data.diff(resource.data).affectedKeys()`)
that denies client writes to the `creator` key specifically, while leaving
the rest of the self-service user-doc update path intact. This is a
required rule change, not an implementation detail of this feature — it's
called out here because it's the single highest-severity issue this
document surfaces.

## New collection rules

| Path | Read | Write |
|---|---|---|
| `creatorApplications/{id}` | Owner (`applicantUid`) or admin | **Create**: owner only, and only fields matching the schema. **Update/delete**: admin only (status transitions are Functions-only in practice, but the rule should not rely on that alone). |
| `referralCodes/{code}` | Public (unauthenticated) — the click-tracking landing page must resolve a code's validity before the visitor has any account | Functions-only (Admin SDK bypasses rules; client rule denies all writes). |
| `referralClicks/{id}` | Creator (own) or admin — dashboards should prefer rollups, this is for debugging/support tooling | Functions-only. |
| `referralAttributions/{uid}` | The referred user (their own), the referring creator, or admin | Functions-only. |
| `referralCampaigns/{id}` | Public read (creators need to see active campaign name/terms) | Admin only. |
| `referralDailyStats/{id}` | Creator (own) or admin | Functions-only. |

---

# App Flow

## A. Creator onboarding (Flutter, mobile + web — same as Business)

1. Profile → **"Become a Creator"** (new entry point — does not exist
   today; sibling to the existing "Register your business" flow).
2. Application form → `submitCreatorApplication`.
3. Profile shows a pending-state card (mirrors `_WaitingForApprovalCard`).
4. Admin reviews in the Admin panel (new page, same shape as existing
   business-approval admin tooling) → `reviewCreatorApplication`.
5. On approval, `users/{uid}.creator.enabled` flips true via the live
   Firestore listener `AppState` already has wired — the Profile Creator
   card appears with **zero additional client-side work**, since this
   reactive path was built and verified in the previous phase.

## B. Referred-user flow

1. Visitor clicks `https://petsupo.com/r/{code}` (public marketing domain
   — see note below) → redirects to the actual signup surface with the
   code preserved (query param + first-party storage for the attribution
   window).
2. `trackReferralClick` fires (fire-and-forget, never blocks the visitor).
3. Visitor signs up normally through the existing auth flow.
4. Immediately after account creation succeeds, the client calls
   `attributeReferral` with whatever code it's holding (if any).
5. User proceeds normally. No visible change to their experience.
6. `evaluateReferralQualification` (scheduled) later checks whether they
   completed a real qualifying action (Business Rules) and, if so,
   transitions the attribution and emits a payable record.

## C. Referred-business flow

1. Same click/landing/attribution capture as above, but the visitor
   proceeds to the **existing** business registration flow instead of a
   normal signup.
2. `attributePartnerReferral` records the pending attribution.
3. The **existing** business-approval admin flow runs unchanged.
4. The moment that business's `status` becomes `approved`,
   `evaluatePartnerReferralQualification` fires automatically (Firestore
   trigger — no polling) and emits the payable record.

## D. Reward → payout

1. Payable record lands in the shared Payout Engine (creator sector
   adapter).
2. It projects into `payoutIndex` — the **same collection** the Admin
   Payouts page already reads exclusively.
3. It rides the **same** weekly batch payout scheduler as every other
   sector.
4. Creator's mobile/Web dashboard "Pending Rewards" / "Paid Rewards" /
   "Upcoming Payout" cards — already built — start reading real numbers
   the moment `CreatorDashboardData.mock()` is swapped for a real read of
   `referralDailyStats` + `payoutIndex`, exactly the swap point already
   flagged with `TODO(creator-backend)` in the shipped code.

**Domain note:** the referral link should use the public marketing domain
(`petsupo.com`), not `app.petsupo.com` (the Flutter Web app domain used
for the dashboard itself and for payment callbacks). A referral link's job
is to be shareable and land a *logged-out* visitor on a conversion page —
that's a marketing-site concern, separate from the authenticated Flutter
Web app. This document does not assume `petsupo.com` and `app.petsupo.com`
are the same deployment; if they are, the distinction still matters
logically even if collapsed technically.

---

# Business Rules

- **Qualification, "user" kind:** signup alone is *not* qualification.
  Requires one real, defined activity within the attribution window (e.g.
  first completed profile + one meaningful action: first playdate
  request, first order, first appointment booked, first adoption
  inquiry — exact list is a product decision, but it must be an action
  that costs the fraudster real effort to fake, not a passive flag).
- **Qualification, "business" kind:** the business reaches
  `businesses/{id}.status == 'approved'` through the existing, unmodified
  approval flow. No new criteria — reuses trust already established
  elsewhere.
- **Attribution window:** referral code must be captured within a bounded
  window before signup (industry-standard 30 days is a reasonable
  default); expired attribution attempts are rejected, not silently
  discarded, so support can explain "why didn't this count."
- **Attribution model:** last-click. If a visitor uses two different
  creators' links before signing up, the most recent one wins. This is a
  explicit, documented choice — first-click is a legitimate alternative
  but materially changes payout outcomes, so it must be picked
  deliberately, not left implicit.
- **One code per creator, permanent.** Codes are not rotated except for
  cause (fraud); rotating a healthy code breaks every link already shared
  publicly.
- **Levels are server-computed**, recalculated by the qualification
  function from cumulative qualified referrals + verified partners.
  Thresholds are a growth/marketing decision, not an architecture one —
  but the *mechanism* (never client-set, always derived) is fixed here.
- **Reward amounts live in `referralCampaigns`**, not in function code —
  changeable without a deploy, same pattern as subscription pricing.
- **Minimum payout threshold** is whatever the shared Payout Engine
  already enforces platform-wide — Creator rewards must not get a
  bespoke, inconsistent threshold.

---

# Edge Cases

| Scenario | Handling |
|---|---|
| Referred user is later refunded / banned / deletes their account | If reward not yet paid: invalidate via the existing clawback path. If already paid: flag for manual reversal — same as any other sector's post-payout dispute. |
| Referred user already existed under a different account (re-signup) | Not fully solvable from Firestore data alone. Mitigate with device/account signals where available; accept and document as a known limitation with a manual-review escape hatch, rather than promising perfect prevention. |
| Creator account suspended/banned mid-cycle | New attributions stop immediately. Attributions already `qualified` but not yet paid go to **manual admin review**, not auto-pay and not auto-forfeit. |
| Multi-touch (two different creators' links) | Last-click wins (Business Rules). |
| Code collision on generation | Prevented structurally by `referralCodes/{code}` doc-ID uniqueness + retry-on-conflict in `reviewCreatorApplication`. |
| Visitor types a code manually instead of clicking a link | Fully supported — `source: 'code_entry'` on the attribution, same downstream handling as `source: 'link'`. |
| Creator leaves the platform after some referrals already paid | History stands untouched (Principle 4) — past rewards are not retroactively invalidated by a later status change. |
| Business referral where the business is later found fraudulent and removed | Reward reversed via the same path as a refunded qualified-user reward — traceable because the payable record carries a reference to the source business doc. |

---

# Fraud Prevention

- **FRAUD-0 (highest severity — see SEC-1):** close the client-writable
  `creator` field gap before anything else in this document is built.
  Without it, every other control here is moot.
- **FRAUD-1 — click endpoint abuse:** `trackReferralClick` is
  unauthenticated by necessity. It must sit behind App Check. This app
  already has an App Check integration point (`_activateAppCheck()` in
  `lib/main.dart`) that is currently a **no-op stub** — re-enabling it for
  real is a prerequisite for this endpoint, not optional hardening.
  Layer with IP+code velocity limiting.
- **Self-referral:** reject the obvious cases automatically (matching
  linked-auth-provider identity, matching payment fingerprint reused from
  the existing İş Bank fraud signals, matching device ID where available).
  Flag ambiguous cases for manual review rather than either ignoring
  self-referral or overclaiming perfect detection.
- **Click farming / bot traffic:** clicks are explicitly non-financial
  (Core Principle 2) — the worst a click-flood achieves is a misleading
  vanity number, not a fraudulent reward. This is a structural defense,
  not just a monitoring one.
- **Fake/farmed accounts:** the real-activity qualification requirement
  (Business Rules) is the primary defense — an empty account that never
  does anything real never qualifies, regardless of how many were
  created.
- **Chargeback-driven reward fraud** (e.g. referring a business that
  itself turns out to be fraudulent to farm the partner reward): traced
  and reversible because every reward carries a reference back to its
  source document (Principle 3).
- **Rate limits:** `submitCreatorApplication` and `attributeReferral`
  should be rate-limited per uid/IP to blunt spam and enumeration
  attempts, consistent with how this codebase already rate-limits other
  public-facing callables.
- **Admin audit trail:** every approve/reject/suspend/reinstate/invalidate
  action logs the acting admin's uid and timestamp, matching the
  `logger.info(...)` conventions already used throughout
  `functions/index.js` for payment-related events.

---

# Analytics

- **Never aggregate `referralClicks` live.** It's an append-only,
  high-volume, short-retention collection by design. All dashboard
  reads — mobile and Web — go through `referralDailyStats` rollups,
  written by one scheduled function, not computed per-request.
- **Funnel, not vanity metrics:** clicks → attributions → qualified →
  rewarded → paid, each stage counted, so "Conversion Rate" (currently a
  mocked constant in `CreatorDashboardData`) becomes a real
  qualified-over-clicks ratio.
- **Per-campaign breakdown:** `campaignId` tagged at click time and
  attribution time enables campaign-level reporting without a schema
  change later.
- **Admin-side analytics** reuse whatever cross-sector reporting the
  Payout Engine's "Future Extensions" (accounting, tax reporting, bank
  reconciliation) already plans — Creator payouts inherit this for free
  by living in `payoutIndex`.

---


# Deferred Features (Post-MVP)

The following features were intentionally deferred from the first production release.

They are NOT rejected.

They are postponed because they add implementation complexity without providing proportional business value during the initial Creator Program rollout.

The MVP is expected to onboard only a small number of creators (approximately 5–10 creators during the first months). Therefore simplicity, maintainability and rapid delivery are prioritized over automation.

Each deferred feature should be reconsidered once the Creator Program reaches meaningful scale.

---

## DF-1 Creator Application Workflow

Status: Deferred

Reason:

Creators are personally recruited by the PetSupo team.

Applications are reviewed manually through email and direct communication.

Building a complete application workflow, review queue and approval system provides little value while onboarding volume remains low.

Current MVP:

- Creator Guide PDF
- Email communication
- Manual review
- Manual approval
- Manual creator activation

Revisit when:

- More than 30 creator applications per month.

---

## DF-2 Public Website → Firebase Integration

Status: Deferred

Reason:

The Creator landing page is intentionally informational only.

The website does not currently submit applications directly to Firestore.

This avoids unnecessary backend complexity during the MVP.

Current MVP:

Interested creators contact PetSupo directly.

Revisit when:

Application volume no longer allows manual processing.

---

## DF-3 Referral Link Attribution

Status: Deferred

Reason:

Referral Codes alone are sufficient for the initial launch.

Deep links, QR codes, cookies and click attribution significantly increase complexity.

Current MVP:

Users enter an optional Referral Code during registration.

Revisit when:

Creator traffic becomes marketing-driven rather than manually recruited.

---

## DF-4 Click Tracking

Status: Deferred

Reason:

Raw click analytics do not directly generate business value during the MVP.

Qualified referrals are the only metric that impacts payouts.

Current MVP:

No click tracking.

Only qualified referrals are counted.

Revisit when:

Marketing campaigns require funnel analysis.

---

## DF-5 Creator Levels

Status: Deferred

Reason:

There is insufficient production data to define meaningful progression thresholds.

Introducing levels prematurely risks future redesign.

Current MVP:

All approved creators start with the same level.

Revisit when:

Real performance data is available.

---

## DF-6 Campaign Management

Status: Deferred

Reason:

Campaign infrastructure introduces unnecessary operational complexity.

During MVP all creators participate in the same default campaign.

Revisit when:

Multiple concurrent creator campaigns are required.

---

## DF-7 Automated Creator Approval

Status: Deferred

Reason:

Creator approval is a trust-based business decision.

Manual approval provides higher quality control while the creator network is small.

Revisit when:

Manual review becomes a bottleneck.


# Future Scalability

- **Multi-tier referrals** (a creator refers another creator): the
  `referralAttributions` schema is generic enough (`creatorUid` +
  `referredUid`, `kind`) to extend to this later without a schema
  migration. Reward-splitting rules for a tier structure are explicitly
  **out of scope for v1** and must be a deliberate future decision, not
  an accidental side effect of a flexible schema.
- **Public leaderboard:** reads from `referralDailyStats` rollups only,
  never raw collections — no new scalability risk if built this way.
- **External/affiliate partner API:** `referralCodes` and the attribution
  contract are already partner-agnostic; a future public API for
  non-PetSupo affiliates would reuse this schema rather than needing a
  parallel one.
- **Hot-document risk:** if a single creator's click volume becomes very
  high, a single `referralDailyStats` doc per creator per day could
  become a write hotspot. Standard mitigation (sharded counters) is a
  known, deferrable pattern — not needed at expected launch volume, but
  the schema doesn't preclude adding it later.
- **BigQuery export:** once volume justifies it, export
  `referralDailyStats` (not raw clicks) to BigQuery for growth/marketing
  self-serve analysis, off the production Firestore read path entirely.

---

# Non-Goals

- Not building a second payout/ledger system. Creator rewards are a
  sector within the existing one.
- Not supporting multi-level/pyramid referral structures in v1.
- Not providing real-time (sub-minute) click analytics — rollups are
  scheduled, not live.
- Not claiming to fully solve referral fraud — mitigating and flagging
  for human review, with the structural guarantee that raw clicks can
  never directly produce a reward regardless of how fraud detection
  performs.
- Not modifying the existing business-approval flow — the partner-referral
  path observes it, it does not change it.

---

# Design Invariants

- A creator's referral code is unique platform-wide (enforced via
  document-ID creation) and permanent absent cause for rotation.
- `users/{uid}.creator` is never client-writable, in any field, for any
  reason (Finding SEC-1 must be fixed for this invariant to actually
  hold).
- A payable record is created only from a `qualified` attribution — never
  from a click, never from a bare signup.
- Every payable record traces back to exactly one `referralAttributions`
  document (and, for partner rewards, one `businesses/{id}` document).
- Creator payouts use the same `payoutIndex` / shared Payout Engine rails
  as every other sector — no parallel financial system.
- History is never rewritten; status transitions forward, and reversal
  goes through the existing refund/debt-recovery mechanism, not a
  bespoke one.

---

# Final Decision

Build the Creator Referral Engine as a **new source feeding the existing
Payout Engine V2**, not a parallel product. The only net-new financial
surface is the creator sector adapter's canonical payable record; the
schema, functions, and rules above exist to produce that record honestly
and defensibly. **Finding SEC-1 (client-writable `users/{uid}` document)
must be fixed before `users/{uid}.creator` is treated as trustworthy by
anything downstream** — every fraud and business-rule guarantee in this
document assumes that field is server-authoritative, which it is not
today.
