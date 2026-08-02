# Sprint 1 Public Projection Implementation Review

Review status: **APPROVED after Sprint 1 fix pass**

Review scope: only the Sprint 1 public projection implementation in the
current working tree. No code was modified during this review.

## Executive summary

The security direction is sound: canonical `users` and `businesses` documents
are restricted, projection collections are client-read-only, and the new chat
rules remove the previous authenticated-user-wide access. The projection
triggers are idempotent and cannot recurse through their own document writes.

The implementation is not ready for approval because several migrated public
flows still consume the old canonical field shape or point at subcollections
under `businesses_public`, where no copied subcollections exist. There is also
a confirmed private-field leak inside recursively projected sector maps, and
the synchronization currently rewrites projections for every canonical write.

## Findings

### P1 — Confirmed: public projection leaks `ownerUid` inside sector data

- File: `functions/src/publicProjections.js:139-164,204-211`
- Evidence: `projectValue` allows arbitrary keys once it enters an allowlisted
  nested map. `ownerUid` is not in `PRIVATE_KEY_PARTS`.
- Reproduction: projecting a sector service containing
  `{ownerUid: "private-owner"}` returns that field in
  `businesses_public/{businessId}.publicSectorData`.
- Impact: a field explicitly intended to remain private is publicly readable.
- Smallest safe fix: deny owner/ownership identifiers and use explicit nested
  allowlists for public sector records instead of allowing arbitrary keys.
- Runtime verification: confirm projection output against representative
  business documents after the fix.

### P1 — Confirmed: Groomy and Adoption service reads use a non-existent public subcollection

- Files:
  - `lib/ui/business/groomy/groomy_details_overlay.dart:1210-1217`
  - `lib/ui/business/adoption_center/adoption_center_details_overlay.dart:1343-1350`
- Evidence: both now query
  `businesses_public/{businessId}/services`, but the projection builder copies
  documents only into `businesses_public/{businessId}`. Existing services remain
  under `businesses/{businessId}/services`.
- Impact: public service lists become empty or unavailable, which can block or
  mislead Groomy and Adoption booking/detail flows.
- Smallest safe fix: keep the service query on the canonical service path,
  relying on the explicit public-service read rule, or implement a separately
  approved service projection.
- Runtime verification: open both public detail overlays and confirm active
  services and booking actions.

### P1 — Confirmed: Pet Taxi public driver list/map still reads `sectorData`

- Files:
  - `lib/ui/pet_taxi/repositories/pet_taxi_business_repository.dart:42-47`
  - `lib/ui/pet_taxi/pages/pet_taxi_map_page.dart:204-207`
- Evidence: those paths query `businesses_public` but parse
  `data['sectorData']`. The projection stores the sector map as
  `publicSectorData` and intentionally omits canonical `sectorData`.
- Impact: Pet Taxi businesses can be filtered out and available drivers/markers
  can disappear from the public driver list and map.
- Smallest safe fix: consume `publicSectorData` in these public consumers.
- Runtime verification: test an approved available Pet Taxi business with a
  current location on the driver list and map.

### P1 — Confirmed: multiple public detail flows still expect canonical sector data

- Files:
  - `lib/ui/business/groomy/groomy_details_overlay.dart:804-810`
  - `lib/ui/business/pet_hotel/pet_hotel_details_overlay.dart:39-43`
  - `lib/ui/business/adoption_center/adoption_center_details_overlay.dart:43-57,80-87`
  - `lib/ui/vet/vet_details_page.dart:49-55,822,1003,1481`
- Evidence: these screens receive data from public list/profile flows but still
  read `rawData['sectorData']` or `businessData['sectorData']`. The projection
  provides `publicSectorData` instead.
- Impact: sector-specific profile content, working hours, galleries, and
  pre-visit/profile details may render empty despite the public document being
  present.
- Smallest safe fix: update only these public consumers to use the projection
  field, while leaving owner/admin dashboard consumers on canonical data.
- Runtime verification: required for each sector because fallback fields differ.

### P2 — Static risk: projection synchronization rewrites on every canonical write

- File: `functions/src/publicProjections.js:227-256`
- Evidence: both triggers always call `set()` for qualifying documents. There is
  no comparison of before/after public fields and no `projectionVersion` or
  source hash check.
- Impact: profile-private updates such as login metadata, client-only state, or
  unrelated operational fields can create an extra public write and trigger
  downstream public listeners.
- Smallest safe fix: build both projections, compare a stable public payload
  hash or use a public-field diff, and skip `set()` when unchanged.
- Runtime verification: measure canonical writes versus projection writes in a
  staging emulator or production-like telemetry.

### P2 — Static risk: backfill is restartable, not checkpoint-resumable

- File: `functions/scripts/backfillPublicProjections.js:10-34`
- Evidence: `lastDoc` exists only in process memory. A failure restarts the
  collection from the beginning. Each batch is atomic and rerunning is safe,
  but no durable checkpoint is stored.
- Impact: large collections may incur repeated reads and writes after a partial
  failure.
- Smallest safe fix: add an explicit document-ID checkpoint/limit option or a
  controlled resume cursor outside the projection collections.
- Runtime verification: interrupt a large backfill between batches and resume.

### P2 — Static risk: backfill does not remove orphan projections

- File: `functions/scripts/backfillPublicProjections.js:20-30`
- Evidence: it iterates canonical documents only. A projection whose canonical
  document was deleted is never visited and therefore is not deleted by the
  backfill. Deletion cleanup depends on the trigger having run.
- Impact: stale public documents can remain after a missed/deferred trigger.
- Smallest safe fix: add a second target scan for orphan IDs or guarantee and
  monitor trigger completion before declaring backfill complete.
- Runtime verification: seed an orphan projection and confirm the chosen
  cleanup path removes it.

### P2 — Runtime verification required: `published == true` is a new eligibility gate

- Files: `functions/src/publicProjections.js:239-256`,
  `functions/scripts/backfillPublicProjections.js:37-47`
- Evidence: approved businesses without an explicit `published: true` are
  deleted from or omitted from `businesses_public`. The previous canonical
  public-read rule allowed approved businesses in some flows without this gate.
- Impact: existing approved businesses may disappear from public search until
  their canonical documents are backfilled with the new field or the eligibility
  policy is clarified.
- Required check: count approved businesses with missing/false `published`
  before rollout and compare public projection counts.

### P2 — Test coverage gap: emulator tests do not cover the full requested matrix

- File: `functions/test/publicProjectionRules.test.js`
- Covered: owner/other/anonymous/admin reads for users and businesses; projection
  read/write denial; business service anonymous read; personal chat reads;
  business-chat reads; vet-chat participant/admin reads; social public read and
  author/other/admin updates.
- Missing: anonymous vet-chat denial, chat/business-chat/vet-chat writes,
  admin writes, projection delete behavior, trigger synchronization, list/query
  authorization, hidden/unpublished projection behavior, and projection field
  privacy assertions.
- Impact: the current passing test result does not prove all modified rule
  operations or synchronization behavior.
- Smallest safe fix: expand emulator tests before approval.
- Runtime verification: emulator verification is required; production rules
  should not be deployed based on the current test set alone.

## Firestore rules review

### Positive results

- `users/{uid}` reads are restricted to the owner/admin; existing creator-field
  write protection remains in place.
- `businesses/{id}` reads and recursive private reads are owner/admin-only.
- `users_public` and `businesses_public` deny all client writes and allow public
  reads.
- Chat, business-chat, and vet-chat reads are participant/admin-gated.
- Social post public reads remain unchanged; updates are author/admin-only.
- The explicit public service rule does not grant access to the canonical
  business parent document.
- The emulator run passed the currently implemented cases.

### Rule concerns

- `isPublicBusiness` trusts the projection's status/published fields. During the
  interval between a canonical unpublish and trigger completion, a stale public
  projection can remain readable. This is an eventual-consistency exposure and
  requires either a documented tolerance or an additional canonical eligibility
  check in the rule.
- Existing owner update permissions remain broad: the owner can update many
  canonical business fields. This was not introduced by the projection code,
  but the new public trigger makes status/published changes externally visible.
- Query/list behavior for all public consumers must be tested against projection
  indexes and empty/missing documents; the current emulator test uses direct
  document REST reads only.

## Cloud Functions review

- Idempotency: yes. Replaying the same canonical event produces the same
  projection payload with `set()`.
- Infinite trigger loop: no. Triggers listen to `users/*` and `businesses/*`;
  their writes target `users_public/*` and `businesses_public/*`.
- Delete handling: yes for normal trigger delivery. Canonical deletes and
  disqualifying updates delete the projection.
- Create/update consistency: qualifying creates and updates set a projection;
  hidden/unpublished/deleted records delete it.
- Public-field-change filtering: no. Every qualifying canonical write rewrites
  the projection, even when the public payload is unchanged.
- Failure handling: individual trigger failures are retried by the platform,
  but there is no explicit freshness metric or reconciliation job.

## Flutter public/private read review

The main public list/search/profile paths were migrated to the two projection
collections. Private account editing, business dashboards, finance, settings,
admin pages, and canonical business/user writes remain on the private paths.

However, the migration is incomplete at the data-shape boundary: several
public consumers now receive projection documents but still expect
`sectorData`, and two service consumers use a projection subcollection that is
never populated. This is the source of the P1 findings above.

## Backfill review

- Batch size is 200, below Firestore's 500-operation batch limit.
- Re-running is safe for visited canonical documents because writes are
  deterministic replacements and disqualified documents are deleted.
- It is not durable-checkpoint resumable.
- It does not independently remove orphan target documents.
- It has no dry-run, progress checkpoint, reconciliation count, or field privacy
  assertion.

## Performance and cost estimate

For each qualifying canonical write, the current design adds approximately:

- one projection document write;
- one additional document write billed by Firestore;
- downstream listener/read activity for clients subscribed to the projection.

For a canonical user and business write rate of `N`, the upper-bound projection
write count is approximately `N` additional writes per collection, excluding
deletes and backfill writes. Because there is no public-field diff, high-volume
private metadata updates can create unnecessary writes. The first optimization
should be public-payload comparison; the second should be batching/reconciliation
only for backfills, not for live triggers.

## Required fix order

1. Stop rollout and fix projection privacy filtering (`ownerUid` and explicit
   nested public schemas).
2. Correct public service paths and all stale `sectorData` consumers.
3. Add trigger diff filtering and orphan/checkpoint backfill handling.
4. Expand emulator coverage for writes, deletes, anonymous denials, admin
   operations, trigger behavior, and privacy assertions.
5. Verify approved/published data coverage, then run sector-by-sector public
   web/mobile smoke tests.

## Original review decision

**CHANGES REQUIRED** (superseded by the fix-pass disposition below)

The rules have no confirmed privilege-escalation path in the tested cases, and
the trigger topology is non-recursive, but the confirmed public data leaks and
public-flow regressions prevent Sprint 1 approval.

No code was modified during the original review.

## Fix-pass disposition

The confirmed findings were addressed in the Sprint 1 fix pass:

- Nested projection values now use explicit map schemas and deny ownership,
  email, UID, admin, token, finance, and other private key patterns.
- Groomy and Adoption service reads use the canonical service subcollection,
  whose read access is explicitly gated by the approved/published public
  business state; no projection subcollection was invented.
- Pet Taxi public consumers use `publicSectorData` consistently.
- Groomy, Adoption, Pet Hotel, and Vet public detail/appointment flows consume
  the projected field shape while private dashboard/edit paths remain canonical.
- Live projection synchronization compares public payloads and skips unchanged
  writes; create, qualifying update, disqualification, delete, and retry paths
  remain covered.
- Backfill now supports checkpoint files, resume cursors, dry-run mode, and
  optional orphan cleanup without touching canonical documents.
- Emulator coverage now includes canonical owner/other/anonymous/admin access,
  projection write denial, chat sender/deletion behavior, social author/admin
  behavior, and projection privacy/synchronization tests.

The remaining warnings in focused Flutter analysis are pre-existing analyzer
warnings/info in the touched legacy screens; no new compile errors were found.

Final decision after the fix pass: **APPROVED**.
