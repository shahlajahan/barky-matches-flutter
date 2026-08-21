"use strict";

// Petsupo Marketplace P1-A compliance foundation — trusted server
// operation for creating a compliance upload session (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// Slice 2). This module exports a plain async function; the
// Cloud-Functions-framework wiring (onCall) lives in functions/index.js
// only, per "limit functions/index.js changes to explicit export wiring
// only" — no business logic is duplicated there.

const crypto = require("node:crypto");
const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");

const {
  COMPLIANCE_UPLOAD_SESSION_STATUS,
  COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES,
  COMPLIANCE_UPLOAD_SESSION_DEFAULT_EXPIRY_MINUTES,
  COMPLIANCE_UPLOAD_SESSION_MAX_SIZE_BYTES,
  COMPLIANCE_UPLOAD_SESSION_MAX_ORIGINAL_FILENAME_LENGTH,
  COMPLIANCE_DOCUMENT_TYPE,
} = require("./complianceConstants");
const {
  hasOnlyAllowedComplianceUploadSessionRequestFields,
  isAllowedComplianceUploadMimeType,
  isValidComplianceDocumentType,
  buildComplianceQuarantineObjectPath,
  buildComplianceDocsObjectPath,
  buildComplianceUploadObjectId,
  doesRequestMatchStoredSession,
  isComplianceUploadCanaryEnabledForBusiness,
} = require("./complianceValidators");
const { checkAndReserveUploadQuota } = require("./complianceUploadQuota");

// Established, repository-wide business-authorization pattern (matches
// e.g. functions/index.js:21501-21518 and the many equivalent checks
// throughout that file): read the canonical businesses/{businessId}
// document via Admin SDK and require ownerUid === the caller's uid. This
// is server-side, not the Firestore Rules isBusinessOwner() helper —
// Cloud Functions run with Admin SDK privileges and must perform this
// check themselves rather than relying on Rules, which never apply to
// Admin SDK writes.
async function assertCallerOwnsBusiness({ db, businessId, uid }) {
  if (typeof businessId !== "string" || businessId.length === 0) {
    throw new HttpsError("invalid-argument", "businessId is required");
  }
  const businessSnap = await db.collection("businesses").doc(businessId).get();
  if (!businessSnap.exists) {
    throw new HttpsError("not-found", "Business not found");
  }
  const businessData = businessSnap.data() || {};
  if (businessData.ownerUid !== uid) {
    throw new HttpsError(
      "permission-denied",
      "You are not the owner of this business"
    );
  }
}

function assertValidRequestShape(data) {
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", "Request must be an object");
  }
  if (!hasOnlyAllowedComplianceUploadSessionRequestFields(data)) {
    throw new HttpsError(
      "invalid-argument",
      "Request contains an unrecognized field"
    );
  }
  const { businessId, originalFilename, declaredMimeType, declaredSizeBytes, documentType, clientIdempotencyKey } = data;

  if (typeof businessId !== "string" || businessId.length === 0) {
    throw new HttpsError("invalid-argument", "businessId is required");
  }
  if (
    typeof originalFilename !== "string" ||
    originalFilename.length === 0 ||
    originalFilename.length > COMPLIANCE_UPLOAD_SESSION_MAX_ORIGINAL_FILENAME_LENGTH
  ) {
    throw new HttpsError("invalid-argument", "originalFilename is invalid");
  }
  if (!isAllowedComplianceUploadMimeType(declaredMimeType)) {
    throw new HttpsError("invalid-argument", "declaredMimeType is not supported");
  }
  if (
    typeof declaredSizeBytes !== "number" ||
    !Number.isInteger(declaredSizeBytes) ||
    declaredSizeBytes <= 0 ||
    declaredSizeBytes > COMPLIANCE_UPLOAD_SESSION_MAX_SIZE_BYTES
  ) {
    throw new HttpsError("invalid-argument", "declaredSizeBytes is invalid");
  }
  if (!isValidComplianceDocumentType(documentType)) {
    throw new HttpsError("invalid-argument", "documentType is not recognized");
  }
  if (
    clientIdempotencyKey !== undefined &&
    (typeof clientIdempotencyKey !== "string" ||
      clientIdempotencyKey.length === 0 ||
      clientIdempotencyKey.length > 128)
  ) {
    throw new HttpsError("invalid-argument", "clientIdempotencyKey is invalid");
  }

  // Sanitize the display-only filename: strip any path separators so it
  // can never be mistaken for — or later misused to construct — a path,
  // even though the actual objectId is always server-generated and never
  // derived from this value.
  const sanitizedFilename = originalFilename.replace(/[\\/]/g, "_");

  return {
    businessId,
    originalFilename: sanitizedFilename,
    declaredMimeType,
    declaredSizeBytes,
    documentType,
    clientIdempotencyKey: clientIdempotencyKey || null,
  };
}

// A deterministic sessionId when a client idempotency key is supplied
// (same repository convention as the composite-doc-ID idempotency
// pattern documented in the architecture, e.g. functions/index.js:728) —
// a retried call with the same key resolves to the same document instead
// of requiring a query. Without a key, each call gets a fresh,
// cryptographically unpredictable sessionId.
function deriveSessionId({ businessId, uid, clientIdempotencyKey }) {
  if (!clientIdempotencyKey) {
    return crypto.randomUUID();
  }
  return crypto
    .createHash("sha256")
    .update(`compliance_upload_session:${businessId}:${uid}:${clientIdempotencyKey}`)
    .digest("hex");
}

async function createComplianceUploadSession({ db, auth, data, now, canaryAllowlist }) {
  if (!auth || !auth.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }

  const request = assertValidRequestShape(data);
  await assertCallerOwnsBusiness({ db, businessId: request.businessId, uid: auth.uid });

  // Slice 2.1 correction (part G) — server-side, default-deny canary
  // boundary. Checked AFTER auth/ownership (so a stranger still gets
  // "not the owner", not a canary-specific error that would leak
  // whether a given businessId exists as a distinct signal) and BEFORE
  // any quota/session-creation work — canary eligibility is an
  // additional gate, never a bypass of anything below it. `canaryAllowlist`
  // is the raw deploy-time config string; a missing/empty/malformed
  // value denies every business, including this one, by construction of
  // isComplianceUploadCanaryEnabledForBusiness itself.
  if (!isComplianceUploadCanaryEnabledForBusiness(request.businessId, canaryAllowlist)) {
    throw new HttpsError(
      "failed-precondition",
      "Compliance document uploads are not yet enabled for this business"
    );
  }

  const sessionId = deriveSessionId({
    businessId: request.businessId,
    uid: auth.uid,
    clientIdempotencyKey: request.clientIdempotencyKey,
  });
  const sessionRef = db.collection("complianceUploadSessions").doc(sessionId);

  const nowMs = typeof now === "function" ? now() : Date.now();
  const expiresAtMs = nowMs + COMPLIANCE_UPLOAD_SESSION_DEFAULT_EXPIRY_MINUTES * 60 * 1000;

  const documentId = crypto.randomUUID();
  const objectId = buildComplianceUploadObjectId(
    crypto.randomBytes(24).toString("hex"),
    request.declaredMimeType
  );
  const objectPath = buildComplianceQuarantineObjectPath({
    businessId: request.businessId,
    sessionId,
    objectId,
  });
  // Computed once, up front, and persisted on the session — the eventual
  // promotion step (complianceScanOrchestration.js) uses this exact,
  // already-recorded value rather than recomputing it later, so the
  // destination path a reconciliation resume targets is always
  // identical to the one the original attempt targeted.
  const destinationPath = buildComplianceDocsObjectPath({
    businessId: request.businessId,
    documentId,
    objectId,
  });

  const sessionDoc = {
    businessId: request.businessId,
    sessionId,
    documentId,
    objectId,
    objectPath,
    destinationPath,
    originalFilename: request.originalFilename,
    declaredMimeType: request.declaredMimeType,
    declaredSizeBytes: request.declaredSizeBytes,
    documentType: request.documentType,
    sellerRelationship: null, // captured later, at submit time (Slice 3)
    clientIdempotencyKey: request.clientIdempotencyKey,
    allowedMimeTypes: COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES,
    maxSizeBytes: COMPLIANCE_UPLOAD_SESSION_MAX_SIZE_BYTES,
    // Persisted directly at upload_authorized — see complianceConstants.js's
    // COMPLIANCE_UPLOAD_SESSION_ALLOWED_TRANSITIONS comment: every check
    // above already ran before this write, so "created" is never itself an
    // observable Firestore state in this implementation.
    status: COMPLIANCE_UPLOAD_SESSION_STATUS.UPLOAD_AUTHORIZED,
    issuedBy: auth.uid,
    issuedAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: new Date(expiresAtMs),
    uploadedAt: null,
    uploadedGeneration: null,
    finalizedAt: null,
    contentHash: null,
    actualContentType: null,
    actualSizeBytes: null,
    validationFailureReason: null,
    scanAttempts: 0,
    scanVerdict: null,
    scanEngineVersion: null,
    scanSignatureVersion: null,
    scannedAt: null,
    scanFailureReason: null,
    promotedGeneration: null,
    promotedAt: null,
    consumedAt: null,
    consumedByDocumentId: null,
    leaseOwner: null,
    leaseExpiresAt: null,
    reconciliationAttempts: 0,
    lastReconciledAt: null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.runTransaction(async (tx) => {
    const existing = await tx.get(sessionRef);
    if (existing.exists) {
      // Idempotent retry: a session already exists for this exact
      // (businessId, uid, clientIdempotencyKey) triple.
      const existingData = existing.data();

      // Slice 2 correction (adversarial review 2026-08-21, finding C):
      // a retry is only "the same request" if its immutable fields
      // actually match the originally-stored session. A retry that
      // reuses the key but changes filename/mimeType/size/documentType
      // must be rejected outright — it must never silently return the
      // stale original session, and it must never consume quota (this
      // check runs, and can throw, before any quota read/write below).
      if (!doesRequestMatchStoredSession(existingData, request)) {
        throw new HttpsError(
          "failed-precondition",
          "idempotency_conflict: a different upload session already exists for this idempotency key"
        );
      }

      // If it is still usable, this is a safe no-op — return the
      // existing session rather than creating a duplicate or touching
      // quota again. If it has already moved past upload_authorized (or
      // expired), the client must request a fresh session; retrying
      // with the same idempotency key after real progress has happened
      // is not treated as "the same request".
      if (existingData.status !== COMPLIANCE_UPLOAD_SESSION_STATUS.UPLOAD_AUTHORIZED) {
        throw new HttpsError(
          "already-exists",
          "An upload session already exists for this request and is no longer reusable"
        );
      }
      return; // no-op; existing session is reused as-is, no quota consumed
    }

    // Quota is checked and reserved in the SAME transaction as session
    // creation (Slice 2 correction, finding B) — never a separate
    // read-then-write, so concurrent creation attempts for the same
    // scope cannot race past the limit (Firestore retries the losing
    // transaction against the updated counter).
    const quota = await checkAndReserveUploadQuota({
      tx,
      db,
      businessId: request.businessId,
      uid: auth.uid,
      declaredSizeBytes: request.declaredSizeBytes,
      now: nowMs,
    });

    tx.create(sessionRef, sessionDoc);
    quota.apply(tx);
  });

  const finalSnap = await sessionRef.get();
  const finalData = finalSnap.data();

  return {
    sessionId,
    objectPath: finalData.objectPath,
    expiresAt: finalData.expiresAt,
    maxSizeBytes: finalData.maxSizeBytes,
    allowedMimeTypes: finalData.allowedMimeTypes,
    status: finalData.status,
  };
}

module.exports = {
  createComplianceUploadSession,
  assertCallerOwnsBusiness,
  assertValidRequestShape,
  deriveSessionId,
};
