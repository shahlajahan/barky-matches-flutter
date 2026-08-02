# Firestore Security Hardening — Sprint 1

Status: **Phase 1 complete; Phase 2 blocked pending approval of the required data-boundary migration.**

This audit covers only:

- `users`
- `businesses`
- `chats`
- `business_chats`
- `vet_chats`
- `social_posts`

No Flutter code, Cloud Functions, payment code, business logic, deployment, or Firestore rules were modified.

## Executive result

The current rules contain confirmed authorization gaps in all six requested areas. However, the requested `users` and `businesses` behavior cannot be implemented safely with rules-only changes while preserving current public profile and dashboard behavior.

Firestore Security Rules authorize or deny an entire document read; they do not redact private fields from a document returned to a client. The current root documents mix public and private data:

- User documents are read by profile, chat identity, startup recovery, saved-pet/park, subscription, and social flows.
- Business documents are read by public directories, product/service pages, booking pages, dashboards, settings, and admin flows.
- Business documents include `ownerUid`, `legal`, `trust`, `subscription`, `sectorData`, contact data, and `payment` data in the same root document.

Therefore, a rules-only implementation has two unsafe choices:

1. Keep root reads broad, which continues exposing private fields.
2. Restrict root reads to owner/admin, which breaks existing public directories and business/profile flows.

The safe solution is an additive public projection/data boundary followed by rules tightening. That requires a separately approved data migration and client/backend wiring, which is outside the stated “Firestore Security only / no Flutter / no Cloud Functions / no business logic” constraint.

## Phase 1 — audit and migration plan

### 1. `users`

Current rule:

- `firestore.rules:311-312`: any signed-in user can read `/users/{userId}`.
- `firestore.rules:323-327`: owner/admin create/update/delete is restricted, including the existing creator-field protection.
- `firestore.rules:338-348`: nested user paths are owner/admin restricted.

Intended public fields:

- Display identity used in public cards and denormalized chat previews: `username`, `displayName`, `name`, approved profile/avatar URL fields, and possibly public location fields where product behavior requires them.

Private fields observed in current code/data access:

- Subscription/entitlement fields.
- `savedParks` and other personal preferences.
- Marketing consent and terms metadata.
- Creator/admin/referral fields.
- Authentication/provider metadata and operational flags.

Overly broad rule:

- The document-level `allow read: if isSignedIn()` grants the complete document to unrelated users.

Client operations affected by immediate owner/admin-only tightening:

- `lib/services/business_chat_service.dart:190-195` reads a customer’s user document to build chat identity.
- `lib/social/services/pet_story_service.dart` and profile/social overlays read other user documents.
- Profile/social pages resolve display data from root user documents.
- Startup diagnostics in `lib/app_state.dart:3043-3053` intentionally probe another user document.

Migration plan:

1. Add a server-maintained `publicUserProfiles/{uid}` projection containing only approved public identity fields.
2. Migrate public profile, social, and chat-preview reads to that projection or to already-denormalized chat metadata.
3. Keep `/users/{uid}` readable by owner/admin only.
4. Preserve server-only creator/referral fields and prohibit client writes as already intended.
5. Add emulator tests for owner, unrelated authenticated user, anonymous user, and admin.

### 2. `businesses`

Current rule:

- `firestore.rules:496-501`: any signed-in user can read the complete root business document.
- `firestore.rules:516-520`: any signed-in user can read every nested business document through the recursive wildcard.
- Owner/admin write access is at `507-513` and `518-520`.

Intended public fields:

- Approved business identity and discovery fields: display name, category/sectors, public description, public logo/cover/images, public service/contact/location fields, public rating/verification presentation, and public operating information.

Private fields observed in the business creation/settings paths:

- `ownerUid` and ownership metadata.
- `legal` including tax/MERSIS and document metadata.
- `payment` including IBAN, account holder, bank name, billing information, and timestamps.
- `subscription` entitlement/status data.
- `trust` moderation/risk fields.
- `sectorData` containing operational configuration and, for some sectors, private documents/settings.
- Private operational subcollections such as quick replies and sector management data.

Evidence:

- `functions/index.js:10179-10252` creates the root document with public and private maps together.
- `functions/index.js:13935-14020` stores bank data in the root `payment` map.
- `lib/home_page.dart:660-668` reads the entire `businesses` collection for discovery.
- Many sector pages and booking/product pages read complete business documents directly.

Overly broad rules:

- Root read exposes the complete mixed document.
- Recursive wildcard read exposes all nested business documents, including private operational data.

Client operations affected by immediate owner/admin-only tightening:

- Public discovery in `lib/home_page.dart:660-668`.
- Business list/detail pages under `lib/ui/common`, `lib/vet_page.dart`, `lib/groomy_page.dart`, `lib/pet_hotel_page.dart`, `lib/adoption_page.dart`, and related overlays.
- Product, booking, and service pages that read `/businesses/{businessId}`.
- Business dashboards/settings would continue to work for owners, but public customer flows would not.

Migration plan:

1. Add a server-maintained `businesses/{businessId}/publicProfile` projection, or a top-level `publicBusinesses/{businessId}` collection.
2. Define and document the public field allowlist, including nested map allowlists.
3. Migrate public discovery/detail/booking reads to the projection.
4. Restrict `/businesses/{businessId}` and private nested paths to owner, authorized staff, finance roles where applicable, and admin.
5. Remove the broad recursive wildcard read; add explicit rules for any genuinely public subcollection.
6. Add emulator tests proving public profile access does not grant root/private access.

### 3. `chats`

Current rule:

- `firestore.rules:894-906` allows document `get` to every registered user, while list/update are participant-restricted.
- `firestore.rules:911-929` protects message reads/creates/updates using the parent `participants` array and sender ID.

Intended access:

- Only chat participants; admin exception where operational support requires it.

Defect:

- A registered non-participant can directly read any chat document by ID through `allow get: if isRegisteredUser()`.

Compatibility:

- `lib/services/chat_service.dart:42-70` reads a deterministic chat by ID before repairing/creating it. The caller should be a participant or be creating the document with both participants.
- `lib/services/chat_service.dart:143-155` already checks sender membership in client logic; rules must enforce it independently.

Migration plan:

1. Change document get/update to participant or admin.
2. Require both participant IDs on create and require the creator to be in `participants`.
3. Keep message participant/sender checks and add admin exception only if required by an existing admin workflow.
4. Test direct non-participant get, participant get, query/list, create, update, and message operations.

### 4. `business_chats`

Current rule:

- `firestore.rules:932-946` allows any registered user to read/create/update any business chat and any nested message.

Intended access:

- The participating customer (`clientUserId`) and the business owner/authorized business staff for `businessId`; admin exception where already intended.

Current client schema evidence:

- `lib/services/business_chat_service.dart:82-113` stores `businessId`, `clientUserId`, business metadata, client metadata, and unread counters.
- `lib/services/business_chat_service.dart:12-27` queries by `clientUserId` or `businessId`.
- `lib/services/business_chat_service.dart:144-167` writes a message and chat summary in one batch.

Migration plan:

1. Add helper functions for customer participation and business ownership/staff authorization.
2. Restrict document get/list/update to those participants/admins.
3. Restrict create to a registered customer initiating a chat with a valid business, or an explicitly authorized business workflow.
4. Restrict nested message create to the participant whose `senderId` equals the authenticated UID; restrict reads/updates to chat participants/admins.
5. Verify query compatibility for both existing list queries (`clientUserId` and `businessId`).

### 5. `vet_chats`

Current rule:

- `firestore.rules:949-957` allows any registered user to read/create/update any Vet chat.
- No participant field contract or active client writer was found in the inspected Flutter/Functions sources.

Intended access:

- The appointment/client participant and the veterinary business/staff participant; admin exception where already intended.

Migration plan:

1. Confirm the canonical Vet chat document schema in production/emulator fixtures (`participants`, `clientUserId`, `businessId`, or equivalent).
2. Add participant/business-owner checks using that confirmed schema.
3. Add an explicit nested-message rule if messages exist; do not rely on a broad recursive wildcard.
4. Test owner/client/non-participant/admin cases before deployment.

This collection is not safe to tighten against guessed field names.

### 6. `social_posts`

Current rule:

- `firestore.rules:1044-1057` keeps public read (`allow read: if true`) and owner/admin create/delete behavior.
- `firestore.rules:1051` allows any registered user to update any post.

Intended access:

- Public read.
- Author/admin update and delete.
- If likes or counters need public-user writes, permit only narrow changed fields through a field-diff helper.

Client compatibility:

- Social post creation uses the author UID (`lib/social/pages/create_social_post_page.dart:376`).
- Social post service and overlays read public posts and write interaction data through separate collections/services.

Migration plan:

1. Change update to author/admin.
2. If public likes/counters update the post document, replace broad update with an explicit changed-key allowlist.
3. Preserve public reads unchanged.
4. Test author, unrelated authenticated user, anonymous read, admin, and interaction-counter updates.

## Phase 2 — implementation status

Not applied. The requested rules-only implementation is blocked by the mixed public/private root-document schema for `users` and `businesses`.

Applying owner/admin-only root reads now would satisfy confidentiality but break confirmed existing client operations, especially public business discovery and cross-user public identity/chat previews. Leaving root reads broad would not satisfy the requested security objective.

The safe next step is approval for one of these migration choices:

1. **Recommended:** additive public projections plus a small coordinated client/backend migration, then rules tightening.
2. **Strict rules-only:** owner/admin-only root reads now, accepting broken public business/profile flows until a later client migration.
3. **Temporary compatibility compromise:** narrow chat/social rules now, but defer `users`/`businesses` until public projections exist. This does not complete Sprint 1.

No rules were changed because choosing option 2 or 3 without approval would knowingly create a behavior regression, contrary to the requirements.

## Phase 3 — emulator test plan

The following matrix must run after the migration choice is approved:

| Collection | Operation | Owner/participant | Other authenticated | Anonymous | Admin |
|---|---|---:|---:|---:|---:|
| `users` root | read own/other | allow own | deny private/other | deny | allow |
| `businesses` root | public projection read | allow public | allow public only | according to product requirement | allow |
| `businesses` private root/subcollections | read/write | owner/staff only | deny | deny | allow |
| `chats` | document/message read/write | allow participant | deny | deny | allow if intended |
| `business_chats` | document/message read/write | allow customer/business staff | deny | deny | allow if intended |
| `vet_chats` | document/message read/write | allow participants | deny | deny | allow if intended |
| `social_posts` | public read | allow | allow | allow | allow |
| `social_posts` | create/update/delete | author/admin | deny update/delete | deny write | allow |

Required assertions include direct document reads, collection queries, creates, updates, deletes, nested messages, and field-diff restrictions. A rules compile check alone is insufficient.

## Current verification

- This phase was a source/rules audit only.
- No emulator authorization suite was run because no rule changes were applied.
- No deployment occurred.
- No Flutter, Functions, payment, or business-logic files were modified.

