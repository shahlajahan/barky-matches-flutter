# Sprint 1 Public Projection Fix Report

Status: **APPROVED**

No deployment or commit was performed.

## Function-name migration

The Firestore background triggers are exported as
`syncUserPublicProjectionTrigger` and `syncBusinessPublicProjectionTrigger`.
Their document paths remain `users/{userId}` and `businesses/{businessId}`.
This avoids changing the trigger type of the existing production HTTPS
function `syncUserPublicProjection` in place.

Deployment is intentionally separate from this code change:

```bash
firebase deploy --only functions:syncUserPublicProjectionTrigger,functions:syncBusinessPublicProjectionTrigger --project barkymatches-new
```

After deployment and verification, the obsolete HTTPS function may be removed
separately:

```bash
firebase functions:delete syncUserPublicProjection --region=europe-west1
```

## 1. Confirmed issues and fixes

| Review issue | Fix |
|---|---|
| Nested `ownerUid` leakage | Replaced arbitrary recursive copying with explicit sector/map schemas and private-key denial. Added builder privacy tests. |
| Groomy/Adoption projection service paths | Restored reads to `businesses/{id}/services`; the existing public-service rule gates reads by approved/published status. |
| Pet Taxi stale `sectorData` parsing | Public map, repository, drivers, resolver, and live status paths now consume `publicSectorData`. |
| Public detail flows expecting canonical sector data | Updated Groomy, Adoption, Pet Hotel, Vet, and related appointment/booking consumers. Private dashboard/edit reads remain canonical. |
| Unnecessary projection writes | Synchronizers compare the next public payload to the current projection, ignoring only projection metadata timestamps. Unchanged writes are skipped. |
| Backfill restart/orphan limitations | Added atomic checkpoint files, resume cursors, dry-run mode, batch statistics, and optional orphan cleanup. Canonical documents are never deleted. |
| Incomplete authorization coverage | Expanded rules tests for owner, other user, anonymous, admin, participants, sender constraints, deletes, projection writes, and social author/admin behavior. |

## 2. Files changed

Core implementation:

- `functions/src/publicProjections.js`
- `functions/scripts/backfillPublicProjections.js`
- `functions/index.js`
- `firestore.rules`
- `firebase.json`

Tests:

- `functions/test/publicProjection.test.js`
- `functions/test/publicProjectionRules.test.js`
- `test/ui/pet_taxi/public_projection_read_test.dart`

Public read-path corrections were limited to the previously identified
Groomy, Adoption, Pet Hotel, Vet, and Pet Taxi screens/repositories.

## 3. Projection schema after the fix

`users_public/{uid}` contains curated identity fields only, plus
`projectionVersion` and `sourceUpdatedAt`.

`businesses_public/{businessId}` contains curated business/profile/contact,
verification, rating, image, capacity, status, and explicitly allowlisted
`publicSectorData`. Nested sector maps are schema-driven; unknown keys are
dropped. Ownership, email, UID fields except the explicit public user UID,
admin, token, finance, payout, payment, legal, moderation, staff, medical,
document, and internal fields are excluded.

## 4. Public/private read-path mapping

- Public profile/search/business-card/detail paths: `users_public` and
  `businesses_public`.
- Public service listings: canonical
  `businesses/{businessId}/services/{serviceId}` with the explicit public
  approved/published read rule; no duplicate service projection exists.
- Owner profile editing, business editing, dashboards, finance, admin, and
  operational subcollections: canonical `users`/`businesses` paths.

## 5. Trigger write suppression

`onDocumentWritten` remains attached only to canonical `users/{uid}` and
`businesses/{businessId}`. Projection writes cannot retrigger these functions.
The synchronizer:

1. builds a deterministic allowlisted projection;
2. deletes only an existing projection when the canonical record is deleted or
   no longer public;
3. reads the current projection;
4. skips `set()` when public data is unchanged;
5. writes only when public data changed or the projection is missing.

`sourceUpdatedAt` is ignored for equality so private timestamp churn does not
force public writes. Tests cover private-only updates, public updates, delete,
retry, and idempotency.

## 6. Backfill behavior

```text
node scripts/backfillPublicProjections.js \
  --collection=all \
  --checkpoint-file=/safe/path/public-projection-checkpoint.json
```

Supported options:

- `--collection=users|businesses|all`
- `--checkpoint-file=...`
- `--resume-cursor=...` for a single selected collection
- `--dry-run`
- `--cleanup-orphans`

Pages contain 200 operations, below Firestore's 500-operation batch limit.
Checkpoint files are atomically replaced after each committed page. Repeated
runs are idempotent. Orphan cleanup checks target IDs against canonical source
documents and never mutates canonical data. Output includes scanned, created,
updated, skipped, deleted-orphan, failed, and resume-cursor values.

## 7. Emulator coverage matrix

| Area | Owner | Other auth | Anonymous | Admin |
|---|---:|---:|---:|---:|
| Canonical users read/write | pass | denied | denied | pass |
| Public user projection read/write | read/pass, write denied | read/pass | read/pass | write denied |
| Canonical businesses read/write | pass | denied | denied | pass |
| Public business projection read/write | read/pass, write denied | read/pass | read/pass | write denied |
| Public service read | pass | pass | pass | pass |
| Personal chat/message sender/delete rules | pass | participant pass | denied | pass |
| Business/vet chat participant/delete rules | pass | participant pass | denied | pass |
| Social post author/other/admin/delete | pass | denied | public read | pass |
| Projection privacy/sync/retry/delete | tested by function tests | — | — | — |

## 8. Validation results

- Firestore rules dry-run: passed.
- Functions deployment dry-run: passed previously; no deployment performed.
- Functions tests: 156 passed.
- Firestore/Auth emulator authorization tests: passed.
- Projection privacy and synchronizer tests: passed.
- Focused Flutter tests: passed, 23 tests.
- Focused Flutter analysis: no errors; existing warnings/info remain in legacy
  touched screens.
- `dart format`: passed.
- `git diff --check`: passed.

## 9. Remaining risks

- Public projection documents remain eventually consistent with canonical
  documents until the synchronization trigger completes. Public collection
  reads remain queryable with public rules; service reads additionally verify
  canonical approved/published state.
- Existing production businesses must be checked for `published: true` before
  rollout, because that is the public projection eligibility gate.
- Backfill must be run with production credentials before tightening/using the
  public read paths in production.

These are rollout checks, not unresolved implementation defects.
