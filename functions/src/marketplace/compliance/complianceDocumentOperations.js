"use strict";

// Petsupo Marketplace P1-A compliance foundation — Slice 3 (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §8/§13/§16): the document/scope/member review lifecycle that runs
// AFTER a session has already reached `consumed` and a `complianceDocuments`
// record exists at status `clean` (Slice 2's sole writer of that
// collection — complianceScanOrchestration.js's performPromotion()).
// This module exports plain async functions; onCall wiring lives in
// functions/index.js only, matching every other compliance module.
//
// Nine operations, matching the master plan's §8 operation table:
//   submitComplianceDocument, reviewComplianceDocument (approve/reject),
//   requestComplianceInformation, revokeComplianceDocument,
//   supersedeComplianceDocument, addComplianceScope,
//   addComplianceScopeMembers, reviewComplianceScopeMembers,
//   reviewComplianceScope.
//
// Explicitly OUT of scope for this module (later slices, per the
// dependency graph in §16): the real compliancePolicyRegistry-driven
// validation (Slice 4's compliancePolicyRegistry.js does not exist yet,
// and no `active` version can exist until it does), any
// productComplianceDecisions / recomputeProductComplianceStatus write,
// expiry scheduling, checkout changes, Dart models, or any UI. Policy-
// driven scope-type compatibility (`compliancePolicyRegistry...
// acceptedScopeTypes`, §4) is likewise NOT implemented here — no
// fallback for it is invented (see addComplianceScope's own doc
// comment) — which is precisely why Slice 3 is not independently
// deployment-complete without Slice 4 (see the interim-policy note
// immediately below).
//
// INTERIM POLICY FAIL-CLOSED RULE (Slice 3 correction pass,
// 2026-08-24, Correction C — closes the adversarial review's "policy
// fail-open" finding). §5.1/§7 describe `submitComplianceDocument` as
// gaining a `compliancePolicyRegistry`-driven `validUntilRequired`
// check per `documentType` — a real per-type lookup this module cannot
// perform without Slice 4's registry existing. §7 itself already
// commits, in writing, to the conservative fallback for exactly this
// unconfigured-policy case: "the *test/emulator* placeholder... defaults
// every `perDocumentTypePolicy` entry to `validUntilRequired: true`,
// the conservative, safer default... the mechanism fails toward
// requiring more evidence, not less, when unconfigured." Slice 3
// implements that exact fallback directly, hardcoded, universally (not
// per-`documentType`, since no registry exists yet to consult one from):
// `submitComplianceDocument` REQUIRES a structurally-valid `validUntil`
// on every submission, unconditionally, until Slice 4 replaces this
// hardcoded rule with the real per-type registry lookup. This closes
// the concrete gap the review found: a document could previously reach
// `approved` permanently missing `validUntil`, with no correction path,
// if Slice 3 were deployed before Slice 4.
//
// **DEPLOYMENT GATE: Slice 3's callables must NOT be independently
// deployed/activated in production ahead of Slice 4 unless this
// conservative universal `validUntil` requirement remains enforced
// exactly as implemented below.** Removing or weakening it without
// Slice 4's real registry being live simultaneously reopens the
// fail-open gap this correction exists to close.
//
// Two operations named in the master plan's schema/field tables but
// deliberately NOT implemented here, because no Slice 3 operation name
// exists for them anywhere in §8 (see the doc comments at each
// corresponding constants-file transition table for the exact
// reasoning): scope-level revocation, and member-level revocation
// (active -> revoked). Both remain defined-but-unreachable enum values.

const crypto = require("node:crypto");
const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");

const { requireAdmin } = require("../../moderation/adminAuth");
const { assertCallerOwnsBusiness } = require("./complianceUploadSessions");
const {
  COMPLIANCE_DOCUMENT_STATUS,
  COMPLIANCE_SCOPE_STATUS,
  COMPLIANCE_SCOPE_MEMBER_STATUS,
  COMPLIANCE_SCOPE_TYPE,
  SELLER_RELATIONSHIP,
  COMPLIANCE_REVIEW_EVENT_TARGET_TYPE,
  COMPLIANCE_REVIEW_EVENT_ACTION,
  COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE,
} = require("./complianceConstants");
const {
  hasOnlyAllowedKeys,
  isValidSellerRelationship,
  isValidComplianceDocumentType,
  isAllowedComplianceDocumentTransition,
  isDocumentEligibleForScopeCreation,
  isValidComplianceScopeType,
  isAllowedComplianceScopeTransition,
  isScopeEligibleForMemberLifecycle,
  isScopeEligibleForMemberRejection,
  isValidComplianceScopeMemberIdentifierType,
  isAllowedComplianceScopeMemberTransition,
} = require("./complianceValidators");

// ---------------------------------------------------------------------
// Shared request-shape allowlists — private to this module's own
// callables (not a Firestore-collection schema, so these deliberately
// live here rather than in complianceConstants.js, which is reserved
// for collection field/state schemas per its own doc comment).
// ---------------------------------------------------------------------

const SUBMIT_REQUEST_ALLOWED_FIELDS = Object.freeze([
  "documentId",
  "sellerRelationship",
  "issuedAt",
  "validFrom",
  "validUntil",
]);
const REVIEW_DOCUMENT_REQUEST_ALLOWED_FIELDS = Object.freeze([
  "documentId",
  "decision",
  "rejectionReason",
]);
const REQUEST_INFO_REQUEST_ALLOWED_FIELDS = Object.freeze(["documentId", "note", "requestId"]);
const REVOKE_REQUEST_ALLOWED_FIELDS = Object.freeze(["documentId", "revocationReason"]);
const SUPERSEDE_REQUEST_ALLOWED_FIELDS = Object.freeze(["newDocumentId", "oldDocumentId"]);
const ADD_SCOPE_REQUEST_ALLOWED_FIELDS = Object.freeze(["documentId", "scopeType", "scopeValue"]);
const ADD_SCOPE_MEMBERS_REQUEST_ALLOWED_FIELDS = Object.freeze(["scopeId", "members"]);
const SCOPE_MEMBER_ENTRY_ALLOWED_FIELDS = Object.freeze(["identifierType", "identifierValue"]);
const REVIEW_SCOPE_MEMBERS_REQUEST_ALLOWED_FIELDS = Object.freeze([
  "scopeId",
  "memberIds",
  "decision",
]);
const REVIEW_SCOPE_REQUEST_ALLOWED_FIELDS = Object.freeze([
  "scopeId",
  "decision",
  "verifiedBrandId",
]);

const DECISION = Object.freeze({ APPROVE: "approve", REJECT: "reject" });

// Conservative bound on one batch call — mirrors the "bounded, never
// unbounded" philosophy already established by Slice 2's quota work and
// productComplianceDecisions' own 10/5 caps (§4). Not a documented
// master-plan value; a defensive default to prevent one callable
// invocation from writing an unbounded number of documents.
const MAX_MEMBERS_PER_BATCH = 100;

const MAX_NOTE_LENGTH = 2000;
const MAX_REASON_LENGTH = 2000;
const MAX_SCOPE_VALUE_LENGTH = 500;
const MAX_IDENTIFIER_VALUE_LENGTH = 200;
const MAX_VERIFIED_BRAND_ID_LENGTH = 200;
// Same bound as complianceUploadSessions.js's clientIdempotencyKey —
// the one existing client-supplied-idempotency-value precedent in this
// codebase (Slice 2 audited for this before adding a new convention;
// see requestComplianceInformation's own doc comment).
const MAX_REQUEST_ID_LENGTH = 128;

// ---------------------------------------------------------------------
// Small shared helpers
// ---------------------------------------------------------------------

// Marketplace Revision 30 §J Slice 4 — rejection reason normalization.
//
// The frozen contract is a single free-text `rejectionReason`; no category or
// taxonomy exists and none is invented here. What is added is the normal
// form: trim surrounding whitespace, require something left, and apply the
// existing MAX_REASON_LENGTH to the TRIMMED value.
//
// The normalized value is what gets persisted, compared and audited, so
// "  reason  " and "reason" are the same rejection rather than an
// idempotency conflict — the inconsistency that would otherwise appear the
// first time an admin retried with a stray space.
function normalizeRejectionReason(value, fieldName) {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} is required`);
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required`);
  }
  if (trimmed.length > MAX_REASON_LENGTH) {
    throw new HttpsError("invalid-argument", `${fieldName} is too long`);
  }
  return trimmed;
}

function assertNonEmptyString(value, fieldName, maxLength) {
  if (typeof value !== "string" || value.length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required`);
  }
  if (typeof maxLength === "number" && value.length > maxLength) {
    throw new HttpsError("invalid-argument", `${fieldName} is too long`);
  }
  return value;
}

// Structural validation only — never a policy-registry lookup (see this
// module's own top-of-file doc comment). Returns a Date or null.
function parseOptionalDate(value, fieldName) {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string" && !(value instanceof Date)) {
    throw new HttpsError("invalid-argument", `${fieldName} must be a date string`);
  }
  const parsed = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new HttpsError("invalid-argument", `${fieldName} is not a valid date`);
  }
  return parsed;
}

async function requireAdminUid({ db, auth }) {
  return requireAdmin(db, { auth });
}

async function fetchComplianceDocumentOrThrow({ db, documentId }) {
  assertNonEmptyString(documentId, "documentId");
  const ref = db.collection("complianceDocuments").doc(documentId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Compliance document not found");
  }
  return { ref, data: snap.data() };
}

async function fetchComplianceScopeOrThrow({ db, scopeId }) {
  assertNonEmptyString(scopeId, "scopeId");
  const ref = db.collection("complianceDocumentScopes").doc(scopeId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Compliance scope not found");
  }
  return { ref, data: snap.data() };
}

// Deterministic, collision-free member ID (master plan §4: "deterministic
// full-SHA-256 member IDs with post-lookup identifierValue verification")
// — this is what makes addComplianceScopeMembers naturally idempotent: a
// retried call for the exact same (scopeId, identifierType,
// identifierValue) resolves to the same document instead of creating a
// duplicate.
function deriveScopeMemberId({ scopeId, identifierType, identifierValue }) {
  return crypto
    .createHash("sha256")
    .update(`compliance_scope_member:${scopeId}:${identifierType}:${identifierValue}`)
    .digest("hex");
}

// Correction D — deterministic complianceReviewEvents document ID for
// requestComplianceInformation, the one operation in this module with no
// natural target-status to gate idempotent retries against (see its own
// doc comment). Same composite-key-hash convention as deriveSessionId
// (complianceUploadSessions.js) and deriveScopeMemberId above — never a
// timestamp or a random ID alone. Deliberately keyed by (actorUid,
// requestId) only, NOT by documentId or note content: this is what lets
// a reused requestId against a DIFFERENT document/admin/note collide at
// the same event document, so the mismatch is caught as an explicit
// idempotency_conflict (checked by comparing the stored event's own
// targetId/actorUid/notes against the new request) rather than silently
// creating two independent, unrelated events that merely happen to
// share a key.
function deriveInfoRequestEventId({ actorUid, requestId }) {
  return crypto
    .createHash("sha256")
    .update(`compliance_info_request_event:${actorUid}:${requestId}`)
    .digest("hex");
}

// Every state-changing write in this module happens inside the same
// transaction as its review-event write, so "audit event written exactly
// once" and "partial transaction failure leaves no partial writes" are
// the same guarantee, not two separate ones to maintain in sync.
function writeComplianceReviewEvent({
  tx,
  db,
  targetType,
  targetId,
  businessId,
  action,
  actorUid,
  actorRole,
  notes = null,
}) {
  const eventRef = db.collection("complianceReviewEvents").doc();
  tx.create(eventRef, {
    targetType,
    targetId,
    businessId,
    action,
    actorUid,
    actorRole,
    occurredAt: admin.firestore.FieldValue.serverTimestamp(),
    notes,
  });
}

// Slice 4.6 (docs/plans/marketplace_p1a_compliance_review_implementation_
// plan_2026-08-21.md §4/§8): bumps businessComplianceEpochs/{businessId}
// .epoch by exactly one, inside the caller's own already-open transaction,
// on exactly five specific, non-idempotent, real evidence transitions
// named in §8 — never on an idempotent replay, never on a reject/
// non-approve branch. `tx.set(..., {merge:true})`, never `tx.update()`
// (which throws on a nonexistent document, unlike `set`/`merge`) — a
// missing epoch document behaves as baseline 0 -> 1 via
// `FieldValue.increment()`'s own documented "starts from 0 on a missing
// field" semantics (master plan §4), exactly what this collection's
// existing readers (complianceEligibilityEvaluator.js,
// complianceProductRecompute.js) already assume when the document is
// absent. No read of the epoch document is ever performed — the
// increment is blind and atomic, so this call may be placed anywhere
// among a transaction's own writes, after its reads, without disturbing
// the existing reads-before-writes ordering. Private, unexported — this
// module's own transactions are the only legitimate caller; no
// `businessComplianceEpochs` collection-name constant is added to
// complianceConstants.js, matching the same repeated-local-constant
// convention already established by the collection's own readers.
function bumpBusinessComplianceEpoch({ tx, db, businessId }) {
  const epochRef = db.collection("businessComplianceEpochs").doc(businessId);
  tx.set(epochRef, { epoch: admin.firestore.FieldValue.increment(1) }, { merge: true });
}

// ---------------------------------------------------------------------
// 1. submitComplianceDocument (seller)
//    clean -> pending_review. The one and only place
//    sellerRelationship/issuedAt/validFrom/validUntil are ever set —
//    every one of those fields is created `null` by Slice 2's scan-
//    result handler and is classified as immutable-once-set
//    (COMPLIANCE_DOCUMENT_IMMUTABLE_FIELDS); this transaction is that
//    single legitimate "set once" write, gated on the document still
//    being at `clean` (i.e. never having been set before).
//
//    Correction C (interim policy fail-closed rule): `validUntil` is
//    REQUIRED, unconditionally, for every `documentType` — see this
//    module's top-of-file doc comment for the full §7 justification.
//    There is no request field or caller input that can waive this; the
//    only two ways it stops applying are (a) Slice 4 wiring the real
//    per-`documentType` registry lookup in its place, or (b) editing
//    this function directly — never a runtime toggle.
// ---------------------------------------------------------------------

// Same structural rule as parseOptionalDate, but the value is mandatory
// — the interim Correction C fallback. Still never a policy-registry
// lookup: this requires validUntil for EVERY documentType uniformly,
// not per-type, because no registry exists yet to consult one from.
function parseRequiredValidUntil(value) {
  if (value === undefined || value === null || value === "") {
    throw new HttpsError(
      "invalid-argument",
      "validUntil is required (interim Slice 3 conservative policy default, per master plan §7)"
    );
  }
  return parseOptionalDate(value, "validUntil");
}

async function submitComplianceDocument({ db, auth, data }) {
  if (!auth || !auth.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  if (!hasOnlyAllowedKeys(data, SUBMIT_REQUEST_ALLOWED_FIELDS)) {
    throw new HttpsError("invalid-argument", "Request contains an unrecognized field");
  }
  const { documentId, sellerRelationship } = data || {};
  assertNonEmptyString(documentId, "documentId");
  if (!isValidSellerRelationship(sellerRelationship)) {
    throw new HttpsError("invalid-argument", "sellerRelationship is not recognized");
  }
  const issuedAt = parseOptionalDate(data.issuedAt, "issuedAt");
  const validFrom = parseOptionalDate(data.validFrom, "validFrom");
  const validUntil = parseRequiredValidUntil(data.validUntil);
  if (validFrom && validUntil.getTime() < validFrom.getTime()) {
    throw new HttpsError("invalid-argument", "validUntil cannot be before validFrom");
  }
  // Correction 3 (second adversarial-review pass): validUntil >= issuedAt
  // is a basic structural invariant of the data model itself, not a
  // policy-driven one — master plan §4's `.maximumValidityPeriod` field
  // ("If set, validUntil - issuedAt (or validFrom) exceeding this is
  // rejected at submission") only makes sense if validUntil - issuedAt
  // is a meaningful, non-negative quantity to begin with. Same
  // boundary convention as the validFrom check immediately above
  // (strict `<`, so exact equality is accepted) — the plan does not
  // state a boundary rule explicitly, so this mirrors the one
  // structural check already implemented rather than inventing a new,
  // different convention; both boundaries are explicitly tested, never
  // silently assumed. No issuedAt-vs-validFrom ordering is enforced —
  // the plan does not specify one, and none is invented here.
  if (issuedAt && validUntil.getTime() < issuedAt.getTime()) {
    throw new HttpsError("invalid-argument", "validUntil cannot be before issuedAt");
  }

  const { ref: documentRef, data: documentData } = await fetchComplianceDocumentOrThrow({
    db,
    documentId,
  });
  await assertCallerOwnsBusiness({ db, businessId: documentData.businessId, uid: auth.uid });

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(documentRef);
    const current = snap.data();

    if (current.status === COMPLIANCE_DOCUMENT_STATUS.PENDING_REVIEW) {
      // Idempotent retry only if every immutable value set by the
      // original submission matches exactly — never a silent reuse of
      // a genuinely different request (same discipline as
      // doesRequestMatchStoredSession in complianceUploadSessions.js).
      const sameRelationship = current.sellerRelationship === sellerRelationship;
      const sameIssuedAt = sameOptionalTimestamp(current.issuedAt, issuedAt);
      const sameValidFrom = sameOptionalTimestamp(current.validFrom, validFrom);
      const sameValidUntil = sameOptionalTimestamp(current.validUntil, validUntil);
      if (sameRelationship && sameIssuedAt && sameValidFrom && sameValidUntil) {
        return { status: current.status, idempotent: true };
      }
      throw new HttpsError(
        "failed-precondition",
        "idempotency_conflict: this document has already been submitted with different values"
      );
    }

    if (!isAllowedComplianceDocumentTransition(current.status, COMPLIANCE_DOCUMENT_STATUS.PENDING_REVIEW)) {
      throw new HttpsError(
        "failed-precondition",
        `Cannot submit a document in status "${current.status}"`
      );
    }

    tx.update(documentRef, {
      status: COMPLIANCE_DOCUMENT_STATUS.PENDING_REVIEW,
      sellerRelationship,
      issuedAt: issuedAt || null,
      validFrom: validFrom || null,
      validUntil, // never null — parseRequiredValidUntil already guarantees a Date
    });
    writeComplianceReviewEvent({
      tx,
      db,
      targetType: COMPLIANCE_REVIEW_EVENT_TARGET_TYPE.DOCUMENT,
      targetId: documentId,
      businessId: documentData.businessId,
      action: COMPLIANCE_REVIEW_EVENT_ACTION.SUBMITTED,
      actorUid: auth.uid,
      actorRole: COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE.SELLER,
    });
    return { status: COMPLIANCE_DOCUMENT_STATUS.PENDING_REVIEW, idempotent: false };
  });

  return { documentId, ...result };
}

// Firestore Timestamp (already-committed) vs. plain Date (freshly
// parsed from this request) — compare by epoch millis, tolerating
// either representation and null on either side.
function sameOptionalTimestamp(committed, candidateDate) {
  const committedMs = committed && typeof committed.toMillis === "function" ? committed.toMillis() : null;
  const candidateMs = candidateDate ? candidateDate.getTime() : null;
  return committedMs === candidateMs;
}

// ---------------------------------------------------------------------
// 2. reviewComplianceDocument (admin) — approve/reject.
//    pending_review -> approved | rejected.
// ---------------------------------------------------------------------

async function reviewComplianceDocument({ db, auth, data }) {
  const adminUid = await requireAdminUid({ db, auth });
  if (!hasOnlyAllowedKeys(data, REVIEW_DOCUMENT_REQUEST_ALLOWED_FIELDS)) {
    throw new HttpsError("invalid-argument", "Request contains an unrecognized field");
  }
  const { documentId, decision } = data || {};
  assertNonEmptyString(documentId, "documentId");
  if (decision !== DECISION.APPROVE && decision !== DECISION.REJECT) {
    throw new HttpsError("invalid-argument", 'decision must be "approve" or "reject"');
  }
  let rejectionReason = null;
  if (decision === DECISION.REJECT) {
    rejectionReason = normalizeRejectionReason(data.rejectionReason, "rejectionReason");
  } else if (data.rejectionReason !== undefined) {
    throw new HttpsError("invalid-argument", "rejectionReason is only valid when rejecting");
  }

  const { ref: documentRef, data: documentData } = await fetchComplianceDocumentOrThrow({
    db,
    documentId,
  });
  const targetStatus =
    decision === DECISION.APPROVE
      ? COMPLIANCE_DOCUMENT_STATUS.APPROVED
      : COMPLIANCE_DOCUMENT_STATUS.REJECTED;

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(documentRef);
    const current = snap.data();

    if (current.status === targetStatus) {
      const storedReason =
        typeof current.rejectionReason === "string"
          ? current.rejectionReason.trim()
          : current.rejectionReason;
      if (decision === DECISION.REJECT && storedReason !== rejectionReason) {
        throw new HttpsError(
          "failed-precondition",
          "idempotency_conflict: this document was already rejected with a different reason"
        );
      }
      return { status: current.status, idempotent: true };
    }

    if (!isAllowedComplianceDocumentTransition(current.status, targetStatus)) {
      throw new HttpsError(
        "failed-precondition",
        `Cannot move a document from "${current.status}" to "${targetStatus}"`
      );
    }

    const reviewedAt = admin.firestore.FieldValue.serverTimestamp();
    tx.update(documentRef, {
      status: targetStatus,
      reviewedBy: adminUid,
      reviewedAt,
      rejectionReason,
    });
    // Slice 4.6 (§8): bump only on a real approve transition — never on
    // reject, never on the idempotent-replay branch above (already
    // returned by this point).
    if (decision === DECISION.APPROVE) {
      bumpBusinessComplianceEpoch({ tx, db, businessId: documentData.businessId });
    }
    writeComplianceReviewEvent({
      tx,
      db,
      targetType: COMPLIANCE_REVIEW_EVENT_TARGET_TYPE.DOCUMENT,
      targetId: documentId,
      businessId: documentData.businessId,
      action:
        decision === DECISION.APPROVE
          ? COMPLIANCE_REVIEW_EVENT_ACTION.APPROVED
          : COMPLIANCE_REVIEW_EVENT_ACTION.REJECTED,
      actorUid: adminUid,
      actorRole: COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE.ADMIN,
      notes: rejectionReason,
    });
    return { status: targetStatus, idempotent: false };
  });

  return { documentId, ...result };
}

// ---------------------------------------------------------------------
// 3. requestComplianceInformation (admin).
//    pending_review -> pending_review (annotation only — never modeled
//    in the transition table since `status` never changes; see that
//    table's own doc comment in complianceConstants.js).
//
//    Correction D (adversarial review finding — Medium): this operation
//    has no terminal target state to gate a retry against (unlike
//    submit/review/revoke/supersede, each idempotent against its own
//    target status), so it originally wrote a new audit event on every
//    call, including byte-identical retries — violating "no duplicate
//    ...audit records." Repo convention audit (this correction pass):
//    the one existing client-supplied-idempotency precedent is
//    complianceUploadSessions.js's `clientIdempotencyKey` (optional,
//    <=128 chars, used to derive a deterministic document ID, compared
//    field-by-field on collision via doesRequestMatchStoredSession) and
//    addSocialCommentCore.js's `requestId` (client-supplied, used
//    directly as the created document's ID). This function follows the
//    same naming as the latter (`requestId`) and the same deterministic-
//    hash-then-compare mechanics as the former — now REQUIRED (there is
//    no state-based fallback here the way submit/review/revoke have).
//
//    deriveInfoRequestEventId({actorUid, requestId}) — deliberately NOT
//    including documentId or note content in the hash (see that
//    function's own doc comment): this is what lets a requestId reused
//    against a different target/content collide at the same event
//    document, so it can be caught explicitly, below, as
//    idempotency_conflict rather than silently creating two unrelated
//    events that happen to share a key. On collision, the stored
//    event's targetType/action/actorUid/actorRole/notes are compared
//    field-by-field against the new request (Correction 2, second
//    adversarial-review pass — the original comparison omitted
//    action/actorRole, and a planted event with a wrong `action` but
//    every OTHER field matching was empirically confirmed to be
//    accepted as a valid replay while silently skipping the real
//    write) — bound to operation type, target document, admin actor,
//    actor role, and normalized content, exactly as required.
//    `businessId` is intentionally not compared — see the comparison's
//    own inline comment for why that is provably redundant, not an
//    omission. A different requestId always creates a genuinely
//    separate, legitimate request, even with identical note text.
// ---------------------------------------------------------------------

async function requestComplianceInformation({ db, auth, data }) {
  const adminUid = await requireAdminUid({ db, auth });
  if (!hasOnlyAllowedKeys(data, REQUEST_INFO_REQUEST_ALLOWED_FIELDS)) {
    throw new HttpsError("invalid-argument", "Request contains an unrecognized field");
  }
  const { documentId } = data || {};
  assertNonEmptyString(documentId, "documentId");
  const note = assertNonEmptyString(data.note, "note", MAX_NOTE_LENGTH);
  const requestId = assertNonEmptyString(data.requestId, "requestId", MAX_REQUEST_ID_LENGTH);

  const { ref: documentRef } = await fetchComplianceDocumentOrThrow({ db, documentId });
  const eventId = deriveInfoRequestEventId({ actorUid: adminUid, requestId });
  const eventRef = db.collection("complianceReviewEvents").doc(eventId);

  const result = await db.runTransaction(async (tx) => {
    const [docSnap, eventSnap] = await Promise.all([tx.get(documentRef), tx.get(eventRef)]);
    const current = docSnap.data();
    if (!current) {
      throw new HttpsError("not-found", "Compliance document not found");
    }

    if (eventSnap.exists) {
      const existing = eventSnap.data();
      // Second adversarial-review pass (Correction 2): compare every
      // non-redundant immutable semantic field of the stored event —
      // not just a subset. `targetType`/`action`/`actorRole` are all
      // compile-time constants for THIS function's own writes (it only
      // ever writes DOCUMENT/INFO_REQUESTED/ADMIN), so omitting them
      // was previously "safe" only under the assumption that nothing
      // else could ever have written to this deterministic ID — an
      // assumption a corrupted/malformed document should never be
      // allowed to silently satisfy. Confirmed reproducible before this
      // fix: a planted event with a wrong `action` but matching
      // targetType/targetId/actorUid/notes was treated as a valid
      // replay, and the real request's effect (setting
      // `infoRequestNote`) was silently skipped while reporting
      // `idempotent: true` — i.e. a corrupted stored event could
      // swallow a genuine admin action. `businessId` is deliberately
      // NOT compared here: it is derived solely from `current.businessId`
      // (the immutable field of the document identified by the already-
      // compared `targetId`), so once `targetId` matches, `businessId`
      // is guaranteed to match too — comparing it again would be
      // provably redundant, not a gap (see this function's own test
      // "replay comparison treats businessId as redundant... provably
      // bound to targetId").
      const matches =
        existing.targetType === COMPLIANCE_REVIEW_EVENT_TARGET_TYPE.DOCUMENT &&
        existing.targetId === documentId &&
        existing.action === COMPLIANCE_REVIEW_EVENT_ACTION.INFO_REQUESTED &&
        existing.actorUid === adminUid &&
        existing.actorRole === COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE.ADMIN &&
        existing.notes === note;
      if (matches) {
        return { status: current.status, idempotent: true };
      }
      throw new HttpsError(
        "failed-precondition",
        "idempotency_conflict: this requestId was already used for a different request"
      );
    }

    if (current.status !== COMPLIANCE_DOCUMENT_STATUS.PENDING_REVIEW) {
      throw new HttpsError(
        "failed-precondition",
        `Cannot request information on a document in status "${current.status}"`
      );
    }

    const reviewedAt = admin.firestore.FieldValue.serverTimestamp();
    tx.update(documentRef, {
      infoRequestNote: note,
      reviewedBy: adminUid,
      reviewedAt,
    });
    // Append-only, deterministic ID (never an auto-random one) — the
    // mechanism that makes exactly-once-per-requestId a Firestore
    // guarantee (tx.create throws if the ID already exists) rather than
    // an application-level convention that could drift.
    tx.create(eventRef, {
      targetType: COMPLIANCE_REVIEW_EVENT_TARGET_TYPE.DOCUMENT,
      targetId: documentId,
      businessId: current.businessId,
      action: COMPLIANCE_REVIEW_EVENT_ACTION.INFO_REQUESTED,
      actorUid: adminUid,
      actorRole: COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE.ADMIN,
      occurredAt: admin.firestore.FieldValue.serverTimestamp(),
      notes: note,
    });
    return { status: COMPLIANCE_DOCUMENT_STATUS.PENDING_REVIEW, idempotent: false };
  });

  return { documentId, ...result };
}

// ---------------------------------------------------------------------
// 4. revokeComplianceDocument (admin).
//    approved -> revoked only — "no grace, ever" (master plan §5.5)
//    only makes sense for evidence currently counted as active, so
//    revocation is scoped strictly to `approved`.
// ---------------------------------------------------------------------

async function revokeComplianceDocument({ db, auth, data }) {
  const adminUid = await requireAdminUid({ db, auth });
  if (!hasOnlyAllowedKeys(data, REVOKE_REQUEST_ALLOWED_FIELDS)) {
    throw new HttpsError("invalid-argument", "Request contains an unrecognized field");
  }
  const { documentId } = data || {};
  assertNonEmptyString(documentId, "documentId");
  const revocationReason = assertNonEmptyString(data.revocationReason, "revocationReason", MAX_REASON_LENGTH);

  const { ref: documentRef, data: documentData } = await fetchComplianceDocumentOrThrow({
    db,
    documentId,
  });

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(documentRef);
    const current = snap.data();

    if (current.status === COMPLIANCE_DOCUMENT_STATUS.REVOKED) {
      if (current.revocationReason !== revocationReason) {
        throw new HttpsError(
          "failed-precondition",
          "idempotency_conflict: this document was already revoked with a different reason"
        );
      }
      return { status: current.status, idempotent: true };
    }

    if (!isAllowedComplianceDocumentTransition(current.status, COMPLIANCE_DOCUMENT_STATUS.REVOKED)) {
      throw new HttpsError(
        "failed-precondition",
        `Cannot revoke a document in status "${current.status}"`
      );
    }

    const revokedAt = admin.firestore.FieldValue.serverTimestamp();
    tx.update(documentRef, {
      status: COMPLIANCE_DOCUMENT_STATUS.REVOKED,
      revokedBy: adminUid,
      revokedAt,
      revocationReason,
    });
    // Slice 4.6 (§8): every real revoke transition bumps unconditionally
    // (revocation has only one meaning) — never on the idempotent-replay
    // branch above (already returned by this point).
    bumpBusinessComplianceEpoch({ tx, db, businessId: documentData.businessId });
    writeComplianceReviewEvent({
      tx,
      db,
      targetType: COMPLIANCE_REVIEW_EVENT_TARGET_TYPE.DOCUMENT,
      targetId: documentId,
      businessId: documentData.businessId,
      action: COMPLIANCE_REVIEW_EVENT_ACTION.REVOKED,
      actorUid: adminUid,
      actorRole: COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE.ADMIN,
      notes: revocationReason,
    });
    return { status: COMPLIANCE_DOCUMENT_STATUS.REVOKED, idempotent: false };
  });

  return { documentId, ...result };
}

// ---------------------------------------------------------------------
// 5. supersedeComplianceDocument (admin) — a standalone operation, kept
//    separate from submit/review per the master plan's §8 table listing
//    it by its own name alongside requestComplianceInformation/
//    revokeComplianceDocument. Both documents must already be
//    independently `approved` before this links them — a seller cannot
//    unilaterally invalidate their own still-active evidence merely by
//    uploading a new, possibly-bad document; supersession only takes
//    effect once an admin has approved the replacement AND explicitly
//    confirms it supersedes the original.
//    oldDocument: approved -> superseded. newDocument.supersedesDocumentId
//    is set exactly once (it is immutable thereafter).
// ---------------------------------------------------------------------

async function supersedeComplianceDocument({ db, auth, data }) {
  const adminUid = await requireAdminUid({ db, auth });
  if (!hasOnlyAllowedKeys(data, SUPERSEDE_REQUEST_ALLOWED_FIELDS)) {
    throw new HttpsError("invalid-argument", "Request contains an unrecognized field");
  }
  const { newDocumentId, oldDocumentId } = data || {};
  assertNonEmptyString(newDocumentId, "newDocumentId");
  assertNonEmptyString(oldDocumentId, "oldDocumentId");
  if (newDocumentId === oldDocumentId) {
    throw new HttpsError("invalid-argument", "newDocumentId and oldDocumentId must differ");
  }

  const { ref: newRef, data: newData } = await fetchComplianceDocumentOrThrow({
    db,
    documentId: newDocumentId,
  });
  const { ref: oldRef, data: oldData } = await fetchComplianceDocumentOrThrow({
    db,
    documentId: oldDocumentId,
  });
  if (newData.businessId !== oldData.businessId) {
    throw new HttpsError(
      "failed-precondition",
      "Both documents must belong to the same business"
    );
  }

  const result = await db.runTransaction(async (tx) => {
    const [newSnap, oldSnap] = await Promise.all([tx.get(newRef), tx.get(oldRef)]);
    const currentNew = newSnap.data();
    const currentOld = oldSnap.data();

    if (
      currentOld.status === COMPLIANCE_DOCUMENT_STATUS.SUPERSEDED &&
      currentOld.supersededByDocumentId === newDocumentId &&
      currentNew.supersedesDocumentId === oldDocumentId
    ) {
      return { oldStatus: currentOld.status, idempotent: true };
    }

    if (currentNew.status !== COMPLIANCE_DOCUMENT_STATUS.APPROVED) {
      throw new HttpsError(
        "failed-precondition",
        `Replacement document must be approved (was "${currentNew.status}")`
      );
    }
    if (currentNew.supersedesDocumentId) {
      throw new HttpsError(
        "failed-precondition",
        "idempotency_conflict: the replacement document already supersedes a different document"
      );
    }
    if (!isAllowedComplianceDocumentTransition(currentOld.status, COMPLIANCE_DOCUMENT_STATUS.SUPERSEDED)) {
      throw new HttpsError(
        "failed-precondition",
        `Cannot supersede a document in status "${currentOld.status}"`
      );
    }

    tx.update(newRef, { supersedesDocumentId: oldDocumentId });
    tx.update(oldRef, {
      status: COMPLIANCE_DOCUMENT_STATUS.SUPERSEDED,
      supersededByDocumentId: newDocumentId,
    });
    // Slice 4.6 (§8): "the superseded document's own write" — keyed
    // strictly by oldData.businessId (the superseded document's
    // authoritative business), never the replacement document's
    // businessId and never any caller-supplied value; both are already
    // asserted equal above, but this keys off the same field this
    // function's own review event already uses for exactly this reason.
    // Bumps unconditionally on every real supersede transition — never
    // on the idempotent-replay branch above (already returned by this
    // point).
    bumpBusinessComplianceEpoch({ tx, db, businessId: oldData.businessId });
    writeComplianceReviewEvent({
      tx,
      db,
      targetType: COMPLIANCE_REVIEW_EVENT_TARGET_TYPE.DOCUMENT,
      targetId: oldDocumentId,
      businessId: oldData.businessId,
      action: COMPLIANCE_REVIEW_EVENT_ACTION.SUPERSEDED,
      actorUid: adminUid,
      actorRole: COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE.ADMIN,
      notes: `superseded_by:${newDocumentId}`,
    });
    return { oldStatus: COMPLIANCE_DOCUMENT_STATUS.SUPERSEDED, idempotent: false };
  });

  return { newDocumentId, oldDocumentId, ...result };
}

// ---------------------------------------------------------------------
// 6. addComplianceScope (seller).
//    Creates a new complianceDocumentScopes record at pending_review.
//    Requires the referenced document to already be `approved` — only
//    vetted evidence should have scope declared against it (declaring
//    scope against not-yet-reviewed evidence would let a seller build
//    scope/member trees against evidence that later gets rejected). No
//    fallback for policy-driven `acceptedScopeTypes` matching (§4) is
//    implemented or invented here — that remains exclusively Slice 4's
//    responsibility (see this module's top-of-file doc comment); any
//    valid `scopeType` is currently accepted for any approved document.
//    scopeId is a fresh random UUID on every call (same convention as
//    documentId in complianceUploadSessions.js) — NOT content-derived,
//    so repeated calls with identical content create distinct scope
//    records by design; idempotency for this collection is provided at
//    the member level below, where the master plan explicitly documents
//    a deterministic ID scheme.
//
//    Correction B (TOCTOU finding): the document's eligibility is
//    re-checked fresh via tx.get() INSIDE the transaction, immediately
//    before the scope is created — never trusting the earlier,
//    outside-transaction read alone. That earlier read remains only for
//    non-authoritative preparation (a fast 404/permission-denied before
//    ever opening a transaction); it is never the sole gate on the
//    actual write.
//
//    Revision 7 correction 40 (master plan §4/§13.1): the created scope
//    also carries `sellerRelationship`, denormalized server-side from
//    this same authoritative in-transaction read of the source document
//    — never caller-suppliable (absent from ADD_SCOPE_REQUEST_ALLOWED_
//    FIELDS), never defaulted, never inferred. A missing/malformed value
//    on the source document (a stored-data anomaly — unreachable via any
//    correct write path, since submitComplianceDocument already gates
//    this field) fails the whole transaction closed before any write.
//    Immutable thereafter: reviewComplianceScope's own update touches
//    only `status`/`reviewedBy`/`reviewedAt`/`verifiedBrandId`, never
//    this field.
//
//    Revision 9 correction 49 (master plan §4/§13.1, third prerequisite
//    Slice 3 sub-pass): the created scope also carries `documentType`/
//    `validUntil`, denormalized server-side from this same authoritative
//    in-transaction read — never caller-suppliable, never defaulted,
//    never inferred, exactly mirroring `sellerRelationship` immediately
//    above. `documentType` is always a valid `COMPLIANCE_DOCUMENT_TYPE`
//    value on an eligible (`approved`) source document, by the same
//    "immutable, set once at Slice 2 creation" reasoning already
//    established for `sellerRelationship`. `validUntil` is nullable on
//    the source schema (§4) — accepted here as either a valid
//    Timestamp-like value or exactly `null`; `undefined` (a genuinely
//    missing key) is not a legal source state and fails closed, same as
//    a malformed value. Neither value is ever recomputed, normalized, or
//    repaired — copied verbatim. Immutable thereafter: no scope update
//    call in this module touches either field.
// ---------------------------------------------------------------------

function isTimestampLike(value) {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value) &&
    typeof value.toMillis === "function"
  );
}

// `null` is a legal source value (§4: `validUntil` is nullable); a
// genuinely missing key (`undefined`) is not — the source document
// always carries this key, one way or the other, once it exists.
function isValidSourceValidUntil(value) {
  return value === null || isTimestampLike(value);
}

async function addComplianceScope({ db, auth, data }) {
  if (!auth || !auth.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  if (!hasOnlyAllowedKeys(data, ADD_SCOPE_REQUEST_ALLOWED_FIELDS)) {
    throw new HttpsError("invalid-argument", "Request contains an unrecognized field");
  }
  const { documentId, scopeType, scopeValue } = data || {};
  assertNonEmptyString(documentId, "documentId");
  if (!isValidComplianceScopeType(scopeType)) {
    throw new HttpsError("invalid-argument", "scopeType is not recognized");
  }
  assertNonEmptyString(scopeValue, "scopeValue", MAX_SCOPE_VALUE_LENGTH);

  // Non-authoritative preparation only: confirms the document exists and
  // resolves its businessId for the ownership check below. The actual
  // eligibility gate is re-read fresh inside the transaction.
  const { ref: documentRef, data: prelimDocumentData } = await fetchComplianceDocumentOrThrow({
    db,
    documentId,
  });
  await assertCallerOwnsBusiness({ db, businessId: prelimDocumentData.businessId, uid: auth.uid });

  const scopeId = crypto.randomUUID();
  const scopeRef = db.collection("complianceDocumentScopes").doc(scopeId);

  await db.runTransaction(async (tx) => {
    const docSnap = await tx.get(documentRef);
    const current = docSnap.data();
    if (!current) {
      throw new HttpsError("not-found", "Compliance document not found");
    }
    if (!isDocumentEligibleForScopeCreation(current.status)) {
      throw new HttpsError(
        "failed-precondition",
        `Cannot add a scope to a document in status "${current.status}"`
      );
    }
    // Revision 7 correction 40 (docs/plans/marketplace_p1a_compliance_
    // review_implementation_plan_2026-08-21.md §4/§13.1): sellerRelationship
    // is denormalized onto the scope from this same authoritative,
    // in-transaction read of the source document — never from caller
    // data (ADD_SCOPE_REQUEST_ALLOWED_FIELDS has no such key, so a
    // caller-supplied value is already rejected before this point by the
    // closed request-shape check above), never a fallback default, never
    // inferred. A document eligible for scope creation is always
    // `approved`, which is only reachable via submitComplianceDocument's
    // own isValidSellerRelationship gate — so a missing/malformed value
    // here is a stored-data anomaly, not an ordinary caller error; it
    // fails the whole transaction closed, before any write, exactly like
    // the eligibility check immediately above. The generic message below
    // never echoes the document's own field values.
    if (!isValidSellerRelationship(current.sellerRelationship)) {
      throw new HttpsError(
        "failed-precondition",
        "Source document does not carry a valid sellerRelationship"
      );
    }
    // Revision 9 correction 49: documentType/validUntil, same fail-closed
    // treatment as sellerRelationship immediately above — checked before
    // any write, generic message, never echoing the stored value back.
    if (!isValidComplianceDocumentType(current.documentType)) {
      throw new HttpsError(
        "failed-precondition",
        "Source document does not carry a valid documentType"
      );
    }
    if (!("validUntil" in current) || !isValidSourceValidUntil(current.validUntil)) {
      throw new HttpsError(
        "failed-precondition",
        "Source document does not carry a valid validUntil"
      );
    }

    tx.create(scopeRef, {
      documentId,
      businessId: current.businessId,
      scopeType,
      scopeValue,
      sellerRelationship: current.sellerRelationship,
      documentType: current.documentType,
      validUntil: current.validUntil,
      memberCount: 0,
      status: COMPLIANCE_SCOPE_STATUS.PENDING_REVIEW,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: auth.uid,
      reviewedBy: null,
      reviewedAt: null,
      verifiedBrandId: null,
    });
    writeComplianceReviewEvent({
      tx,
      db,
      targetType: COMPLIANCE_REVIEW_EVENT_TARGET_TYPE.SCOPE,
      targetId: scopeId,
      businessId: current.businessId,
      action: COMPLIANCE_REVIEW_EVENT_ACTION.SUBMITTED,
      actorUid: auth.uid,
      actorRole: COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE.SELLER,
    });
  });

  return { scopeId, status: COMPLIANCE_SCOPE_STATUS.PENDING_REVIEW };
}

// ---------------------------------------------------------------------
// 7. addComplianceScopeMembers (seller).
//    Adds one or more members to an existing scope. Allowed while the
//    scope is pending_review OR approved (a scope's own approval
//    represents "is this scope type/value legitimate"; each member's
//    own independent review represents "does this specific identifier
//    really belong under it" — the two are deliberately decoupled, see
//    module doc comment). Rejected only when the scope itself is
//    already `rejected` — nothing legitimate to add members to.
// ---------------------------------------------------------------------

function normalizeScopeMemberEntries(members) {
  if (!Array.isArray(members) || members.length === 0) {
    throw new HttpsError("invalid-argument", "members must be a non-empty array");
  }
  if (members.length > MAX_MEMBERS_PER_BATCH) {
    throw new HttpsError("invalid-argument", `members cannot exceed ${MAX_MEMBERS_PER_BATCH} per call`);
  }
  return members.map((entry, index) => {
    if (!hasOnlyAllowedKeys(entry, SCOPE_MEMBER_ENTRY_ALLOWED_FIELDS)) {
      throw new HttpsError("invalid-argument", `members[${index}] has an unrecognized field`);
    }
    if (!isValidComplianceScopeMemberIdentifierType(entry.identifierType)) {
      throw new HttpsError("invalid-argument", `members[${index}].identifierType is not recognized`);
    }
    assertNonEmptyString(entry.identifierValue, `members[${index}].identifierValue`, MAX_IDENTIFIER_VALUE_LENGTH);
    return { identifierType: entry.identifierType, identifierValue: entry.identifierValue };
  });
}

// Correction B (TOCTOU finding): the scope's own eligibility is
// re-checked fresh via tx.get() INSIDE the transaction, alongside the
// member reads (all reads before any write, per Firestore transaction
// semantics) — never trusting the earlier, outside-transaction read
// alone. That earlier read remains only for non-authoritative
// preparation (a fast 404/permission-denied before ever opening a
// transaction).
async function addComplianceScopeMembers({ db, auth, data }) {
  if (!auth || !auth.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  if (!hasOnlyAllowedKeys(data, ADD_SCOPE_MEMBERS_REQUEST_ALLOWED_FIELDS)) {
    throw new HttpsError("invalid-argument", "Request contains an unrecognized field");
  }
  const { scopeId } = data || {};
  const members = normalizeScopeMemberEntries((data || {}).members);

  const { ref: scopeRef, data: prelimScopeData } = await fetchComplianceScopeOrThrow({ db, scopeId });
  await assertCallerOwnsBusiness({ db, businessId: prelimScopeData.businessId, uid: auth.uid });

  const memberRefs = members.map((m) => ({
    ...m,
    ref: scopeRef
      .collection("members")
      .doc(deriveScopeMemberId({ scopeId, identifierType: m.identifierType, identifierValue: m.identifierValue })),
  }));

  const result = await db.runTransaction(async (tx) => {
    const [scopeSnap, ...existingSnaps] = await Promise.all([
      tx.get(scopeRef),
      ...memberRefs.map((m) => tx.get(m.ref)),
    ]);
    const currentScope = scopeSnap.data();
    if (!currentScope) {
      throw new HttpsError("not-found", "Compliance scope not found");
    }
    if (!isScopeEligibleForMemberLifecycle(currentScope.status)) {
      throw new HttpsError(
        "failed-precondition",
        `Cannot add members to a scope in status "${currentScope.status}"`
      );
    }

    const newOnes = memberRefs.filter((_, i) => !existingSnaps[i].exists);

    if (newOnes.length === 0) {
      // Every requested member already exists — safe, fully idempotent
      // no-op; no memberCount change, no new review event.
      return { addedCount: 0, idempotent: true };
    }

    const addedAt = admin.firestore.FieldValue.serverTimestamp();
    for (const m of newOnes) {
      tx.create(m.ref, {
        identifierType: m.identifierType,
        identifierValue: m.identifierValue,
        status: COMPLIANCE_SCOPE_MEMBER_STATUS.PENDING_REVIEW,
        addedAt,
        addedBy: auth.uid,
        reviewedBy: null,
        reviewedAt: null,
        revokedAt: null,
        revokedBy: null,
      });
    }
    tx.update(scopeRef, {
      memberCount: admin.firestore.FieldValue.increment(newOnes.length),
    });
    writeComplianceReviewEvent({
      tx,
      db,
      targetType: COMPLIANCE_REVIEW_EVENT_TARGET_TYPE.SCOPE_MEMBER_BATCH,
      targetId: scopeId,
      businessId: currentScope.businessId,
      action: COMPLIANCE_REVIEW_EVENT_ACTION.SUBMITTED,
      actorUid: auth.uid,
      actorRole: COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE.SELLER,
      notes: `added:${newOnes.length}`,
    });
    return { addedCount: newOnes.length, idempotent: false };
  });

  return { scopeId, ...result };
}

// ---------------------------------------------------------------------
// 8. reviewComplianceScopeMembers (admin) — batch approve/reject.
//    Atomic all-or-nothing: if any requested member is not currently
//    pending_review, or the parent scope itself is not currently
//    eligible for the requested decision, the whole call fails closed
//    and nothing is written (partial application would leave the
//    batch's own audit event ambiguous about which members it actually
//    covered).
//
//    Correction A (adversarial review finding — High): this function
//    previously never checked the PARENT scope's own status at all,
//    which let a member be approved to `active` beneath an already-
//    `rejected` scope (confirmed reproducible against the emulator).
//    The parent scope is now re-read fresh via tx.get() INSIDE the same
//    transaction as the member reads (all reads before any write, per
//    Firestore transaction semantics).
//
//    Second adversarial-review pass (explicit product decision,
//    decision-aware parent gate): the first fix's blanket allowlist
//    also blocked `reject`, which stranded any still-`pending_review`
//    member beneath a rejected scope permanently — no legal transition
//    existed anywhere in Slice 3. The master plan is silent on this
//    exact scenario (no cascade language, no explicit answer), so
//    rather than inventing cascade behavior, the gate is now
//    decision-aware, per an explicit product decision:
//      - `approve` still requires COMPLIANCE_SCOPE_MEMBER_LIFECYCLE_
//        ELIGIBLE_SCOPE_STATUSES (`pending_review`/`approved` only) —
//        UNCHANGED, unwidened. A rejected parent can never produce an
//        `active` member, without exception.
//      - `reject` now uses the wider COMPLIANCE_SCOPE_MEMBER_
//        REJECTION_ELIGIBLE_SCOPE_STATUSES (adds `rejected`) — since
//        rejecting a member never grants trust, it remains legal even
//        beneath an already-rejected parent, so a pending member can
//        still reach a real terminal state instead of being stranded.
//    No new state, transition, or automatic cascade was introduced:
//    `pending_review -> rejected` is already a member's own existing
//    legal transition (complianceConstants.js's
//    COMPLIANCE_SCOPE_MEMBER_ALLOWED_TRANSITIONS); this only widens
//    WHEN that already-legal transition may be invoked, for `reject`
//    only. `reviewComplianceScope` (which rejects the SCOPE itself)
//    still does not cascade-reject members — that remains a seller/
//    admin-initiated action via this function, not automatic.
//    Any status outside BOTH allowlists (unknown/future/invalid) still
//    fails the ENTIRE call closed for either decision. This check runs
//    BEFORE the idempotent-replay shortcut below, deliberately: a retry
//    must not get a "free pass" around the invariant just because the
//    requested member states happen to already match — this applies to
//    `approve` exactly as before; for `reject`, the wider allowlist
//    means a genuinely idempotent reject-retry beneath a rejected scope
//    now correctly proceeds to the idempotent-match check below, rather
//    than being blocked. Pre-existing contradictory data (members
//    already `active` beneath an already-`rejected` scope from before
//    the first correction) is deliberately left untouched — this slice
//    does not silently repair data, it only prevents new writes.
// ---------------------------------------------------------------------

async function reviewComplianceScopeMembers({ db, auth, data }) {
  const adminUid = await requireAdminUid({ db, auth });
  if (!hasOnlyAllowedKeys(data, REVIEW_SCOPE_MEMBERS_REQUEST_ALLOWED_FIELDS)) {
    throw new HttpsError("invalid-argument", "Request contains an unrecognized field");
  }
  const { scopeId, memberIds, decision } = data || {};
  assertNonEmptyString(scopeId, "scopeId");
  if (decision !== DECISION.APPROVE && decision !== DECISION.REJECT) {
    throw new HttpsError("invalid-argument", 'decision must be "approve" or "reject"');
  }
  if (!Array.isArray(memberIds) || memberIds.length === 0) {
    throw new HttpsError("invalid-argument", "memberIds must be a non-empty array");
  }
  if (memberIds.length > MAX_MEMBERS_PER_BATCH) {
    throw new HttpsError("invalid-argument", `memberIds cannot exceed ${MAX_MEMBERS_PER_BATCH} per call`);
  }
  for (const id of memberIds) {
    if (typeof id !== "string" || id.length === 0) {
      throw new HttpsError("invalid-argument", "memberIds must all be non-empty strings");
    }
  }

  // Non-authoritative preparation only: confirms the scope exists so
  // memberRefs can be built. The actual eligibility gate is re-read
  // fresh inside the transaction below.
  const { ref: scopeRef } = await fetchComplianceScopeOrThrow({ db, scopeId });
  const targetStatus =
    decision === DECISION.APPROVE
      ? COMPLIANCE_SCOPE_MEMBER_STATUS.ACTIVE
      : COMPLIANCE_SCOPE_MEMBER_STATUS.REJECTED;
  const isParentEligible =
    decision === DECISION.APPROVE ? isScopeEligibleForMemberLifecycle : isScopeEligibleForMemberRejection;
  const memberRefs = memberIds.map((id) => scopeRef.collection("members").doc(id));

  const result = await db.runTransaction(async (tx) => {
    const [scopeSnap, ...snaps] = await Promise.all([
      tx.get(scopeRef),
      ...memberRefs.map((ref) => tx.get(ref)),
    ]);
    const currentScope = scopeSnap.data();
    if (!currentScope) {
      throw new HttpsError("not-found", "Compliance scope not found");
    }
    if (!isParentEligible(currentScope.status)) {
      throw new HttpsError(
        "failed-precondition",
        `Cannot ${decision} members of a scope in status "${currentScope.status}"`
      );
    }

    const alreadyAtTarget = snaps.every((s) => s.exists && s.data().status === targetStatus);
    if (alreadyAtTarget) {
      return { updatedCount: 0, idempotent: true };
    }

    snaps.forEach((snap, i) => {
      if (!snap.exists) {
        throw new HttpsError("not-found", `Member "${memberIds[i]}" not found`);
      }
      const currentStatus = snap.data().status;
      if (!isAllowedComplianceScopeMemberTransition(currentStatus, targetStatus)) {
        throw new HttpsError(
          "failed-precondition",
          `Member "${memberIds[i]}" cannot move from "${currentStatus}" to "${targetStatus}"`
        );
      }
    });

    const reviewedAt = admin.firestore.FieldValue.serverTimestamp();
    memberRefs.forEach((ref) => {
      tx.update(ref, { status: targetStatus, reviewedBy: adminUid, reviewedAt });
    });
    // Slice 4.6 (§8): bump only on a real approve transition — never on
    // reject, never on the idempotent-replay branch above (already
    // returned by this point). Keyed by currentScope.businessId, the
    // authoritative in-transaction scope read this function's own review
    // event already uses — no outer-scope businessId exists in this
    // function to prefer instead.
    if (decision === DECISION.APPROVE) {
      bumpBusinessComplianceEpoch({ tx, db, businessId: currentScope.businessId });
    }
    writeComplianceReviewEvent({
      tx,
      db,
      targetType: COMPLIANCE_REVIEW_EVENT_TARGET_TYPE.SCOPE_MEMBER_BATCH,
      targetId: scopeId,
      businessId: currentScope.businessId,
      action:
        decision === DECISION.APPROVE
          ? COMPLIANCE_REVIEW_EVENT_ACTION.APPROVED
          : COMPLIANCE_REVIEW_EVENT_ACTION.REJECTED,
      actorUid: adminUid,
      actorRole: COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE.ADMIN,
      notes: `member_ids:${memberIds.join(",")}`,
    });
    return { updatedCount: memberRefs.length, idempotent: false };
  });

  return { scopeId, status: targetStatus, ...result };
}

// ---------------------------------------------------------------------
// 9. reviewComplianceScope (admin) — approve/reject.
//    pending_review -> approved | rejected. For scopeType: 'brand',
//    approve REQUIRES verifiedBrandId (master plan correction 9,
//    explicit); it is rejected outright for any other scopeType, on
//    either decision, rather than silently ignored.
// ---------------------------------------------------------------------

async function reviewComplianceScope({ db, auth, data }) {
  const adminUid = await requireAdminUid({ db, auth });
  if (!hasOnlyAllowedKeys(data, REVIEW_SCOPE_REQUEST_ALLOWED_FIELDS)) {
    throw new HttpsError("invalid-argument", "Request contains an unrecognized field");
  }
  const { scopeId, decision } = data || {};
  assertNonEmptyString(scopeId, "scopeId");
  if (decision !== DECISION.APPROVE && decision !== DECISION.REJECT) {
    throw new HttpsError("invalid-argument", 'decision must be "approve" or "reject"');
  }

  const { ref: scopeRef, data: scopeData } = await fetchComplianceScopeOrThrow({ db, scopeId });

  let verifiedBrandId = null;
  if (data.verifiedBrandId !== undefined) {
    if (scopeData.scopeType !== COMPLIANCE_SCOPE_TYPE.BRAND || decision !== DECISION.APPROVE) {
      throw new HttpsError(
        "invalid-argument",
        "verifiedBrandId is only valid when approving a brand-type scope"
      );
    }
    verifiedBrandId = assertNonEmptyString(data.verifiedBrandId, "verifiedBrandId", MAX_VERIFIED_BRAND_ID_LENGTH);
  } else if (decision === DECISION.APPROVE && scopeData.scopeType === COMPLIANCE_SCOPE_TYPE.BRAND) {
    throw new HttpsError(
      "invalid-argument",
      "verifiedBrandId is required to approve a brand-type scope"
    );
  }

  const targetStatus =
    decision === DECISION.APPROVE ? COMPLIANCE_SCOPE_STATUS.APPROVED : COMPLIANCE_SCOPE_STATUS.REJECTED;

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(scopeRef);
    const current = snap.data();

    if (current.status === targetStatus) {
      if (targetStatus === COMPLIANCE_SCOPE_STATUS.APPROVED && current.verifiedBrandId !== verifiedBrandId) {
        throw new HttpsError(
          "failed-precondition",
          "idempotency_conflict: this scope was already approved with a different verifiedBrandId"
        );
      }
      return { status: current.status, idempotent: true };
    }

    if (!isAllowedComplianceScopeTransition(current.status, targetStatus)) {
      throw new HttpsError(
        "failed-precondition",
        `Cannot move a scope from "${current.status}" to "${targetStatus}"`
      );
    }

    const reviewedAt = admin.firestore.FieldValue.serverTimestamp();
    tx.update(scopeRef, {
      status: targetStatus,
      reviewedBy: adminUid,
      reviewedAt,
      verifiedBrandId,
    });
    // Slice 4.6 (§8): bump only on a real approve transition — never on
    // reject, never on the idempotent-replay branch above (already
    // returned by this point).
    if (decision === DECISION.APPROVE) {
      bumpBusinessComplianceEpoch({ tx, db, businessId: scopeData.businessId });
    }
    writeComplianceReviewEvent({
      tx,
      db,
      targetType: COMPLIANCE_REVIEW_EVENT_TARGET_TYPE.SCOPE,
      targetId: scopeId,
      businessId: scopeData.businessId,
      action:
        decision === DECISION.APPROVE
          ? COMPLIANCE_REVIEW_EVENT_ACTION.APPROVED
          : COMPLIANCE_REVIEW_EVENT_ACTION.REJECTED,
      actorUid: adminUid,
      actorRole: COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE.ADMIN,
    });
    return { status: targetStatus, idempotent: false };
  });

  return { scopeId, ...result };
}

module.exports = {
  normalizeRejectionReason,
  submitComplianceDocument,
  reviewComplianceDocument,
  requestComplianceInformation,
  revokeComplianceDocument,
  supersedeComplianceDocument,
  addComplianceScope,
  addComplianceScopeMembers,
  reviewComplianceScopeMembers,
  reviewComplianceScope,
  // Shared with `pilotProductClassification.js` — reclassification schedules
  // recomputation through this same existing epoch mechanism.
  bumpBusinessComplianceEpoch,
  // exported for tests only
  deriveScopeMemberId,
  deriveInfoRequestEventId,
  fetchComplianceDocumentOrThrow,
  fetchComplianceScopeOrThrow,
};
