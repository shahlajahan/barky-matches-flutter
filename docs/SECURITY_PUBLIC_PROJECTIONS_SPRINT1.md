# Public Profile Projections — Sprint 1

Status: implemented locally, not deployed.

## 1. Schema

The canonical documents remain the source of truth:

- `users/{uid}` remains private and contains the account's private profile,
  application state, creator data, and user-owned subcollections.
- `businesses/{businessId}` remains private and contains ownership, finance,
  bank, legal, operational, and moderation data.

The new public projections are:

- `users_public/{uid}` — curated identity/profile fields used by public
  profiles, search, followers, stories, and review attribution. It contains
  only approved public profile fields plus `projectionVersion` and
  `sourceUpdatedAt`.
- `businesses_public/{businessId}` — curated approved/published business
  profile, contact, verification, rating, image, capacity, and public sector
  data. It contains only public fields plus projection metadata.

Projection documents intentionally exclude ownership, bank, payment, finance,
payout, commission, legal, tax, moderation, staff, medical, document, secret,
and token fields. `businesses_public` is created only for businesses whose
canonical document is `status == "approved"` and `published == true`.

Public service documents continue to live at
`businesses/{businessId}/services/{serviceId}` for backward compatibility.
Their read rule is public only when the matching business projection is
approved and published; their writes remain owner/admin-only.

## 2. Synchronization flow

`functions/index.js` exports two Firestore `onDocumentWritten` triggers:

```text
syncUserPublicProjectionTrigger     users/{userId}
  -> synchronizeUserPublicProjection
syncBusinessPublicProjectionTrigger businesses/{businessId}
  -> synchronizeBusinessPublicProjection
```

The trigger export names are intentionally distinct from the pre-existing
production HTTPS function named `syncUserPublicProjection`; Firebase cannot
change that deployed function's trigger type in place.

The projection builders in `functions/src/publicProjections.js` apply explicit
allowlists and private-key filtering. A canonical delete, a hidden user profile,
or a business that is no longer approved/published deletes its projection.
Otherwise the projection is replaced atomically with the latest curated view.
The Admin SDK performs these writes, so existing client writes to canonical
documents continue unchanged and no client can write either public collection.

`functions/scripts/backfillPublicProjections.js` performs the initial additive
backfill in document-ID pages of 200. It also removes stale projections for
canonical documents that no longer qualify.

## 3. Flutter migration

Public list/profile/search paths now read `users_public` and
`businesses_public`, including public business lists, business detail cards,
seller profiles, user search/followers, review attribution, and Pet Taxi live
public location data. Authenticated account editing, private dashboards,
admin screens, finance, and owner settings continue to read canonical
collections.

The existing service/product subcollection paths are retained where the
current business workflow needs them; rules provide the narrowly scoped public
service read path described above.

## 4. Security rules

- `users/{uid}`: owner or admin read/write, with the existing creator-field
  protection preserved.
- `users_public/{uid}`: public read, all client writes denied.
- `businesses/{id}`: canonical owner or admin only.
- `businesses_public/{id}`: public read, all client writes denied.
- `chats/{id}`: participants only, with admin exception; message writes also
  require the authenticated sender for non-admins.
- `business_chats/{id}` and `vet_chats/{id}`: participating customer/business
  staff only, with admin exception.
- `social_posts/{id}`: public reads remain unchanged; only the author or an
  admin may update.

The canonical business recursive wildcard is owner/admin-only. Public business
service reads are granted by the explicit service rule and do not reopen the
canonical business document.

## 5. Rollout plan (no downtime)

1. Deploy the projection triggers while existing canonical reads and rules are
   still active.
2. Run the backfill script with service credentials.
3. Compare canonical eligible-document counts with projection counts and spot
   check that private fields are absent.
4. Deploy the Flutter build that reads projections for public views. Private
   flows remain on canonical documents.
5. Deploy the tightened Firestore rules.
6. Monitor function errors, permission-denied events, projection freshness, and
   public profile/search results.

This order keeps the old reads working until projections exist and avoids a
cutover window with missing public documents.

## 6. Rollback plan

The canonical collections are never deleted or rewritten by this migration.
If a problem is found, first restore the prior client read paths and, if
necessary, temporarily restore the previous public-read rule behavior through
an explicitly reviewed rules change. Leave projections in place for diagnosis;
they are additive and disposable. After the incident is resolved, projection
triggers can be disabled and projection collections can be removed in a
separate approved change. No rollback step deletes canonical user or business
data.

## 7. Compatibility notes and verification

Local Firestore/Auth emulator authorization tests cover owner, other user,
anonymous, admin, public projection reads/writes, public business services,
chat participants, vet chats, and social-post author/admin updates:

```text
firebase emulators:exec --only firestore,auth --project demo-petsupo \
  "node functions/test/publicProjectionRules.test.js"
```

The test passed locally. Function syntax checks, Firestore rules compilation,
focused Flutter analysis, formatting, and diff checks are part of the Sprint 1
validation. Production synchronization and browser verification remain
deployment-stage checks because this change is intentionally not deployed.

No deployment was performed.

## 8. Function-name migration deployment

Deploy only the two new Firestore triggers after validating the projection
backfill and emulator tests:

```bash
firebase deploy --only functions:syncUserPublicProjectionTrigger,functions:syncBusinessPublicProjectionTrigger --project barkymatches-new
```

Do not delete the existing HTTPS function until both triggers are deployed and
verified. The separate post-verification cleanup command is:

```bash
firebase functions:delete syncUserPublicProjection --region=europe-west1
```
