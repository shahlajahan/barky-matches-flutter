"use strict";

// Petsupo Marketplace P1-A compliance foundation — server-side upload
// finalization (docs/plans/marketplace_p1a_compliance_review_
// implementation_plan_2026-08-21.md, Slice 2). Storage Rules authorize
// the upload using the session (storage.rules); this module is the
// trusted server-side step that independently verifies the resulting
// object before any scan is even attempted. Nothing here trusts a
// client-supplied hash, MIME type, extension, byte size, or metadata —
// every value used for a security decision is re-derived from the live
// Storage object or the session document, never from what the client
// originally declared.

const crypto = require("node:crypto");
const admin = require("firebase-admin");
const {
  COMPLIANCE_UPLOAD_SESSION_STATUS,
  COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES,
  COMPLIANCE_FILE_SIGNATURES,
} = require("./complianceConstants");
const {
  isAllowedComplianceUploadSessionTransition,
} = require("./complianceValidators");
const { releaseActiveUploadQuota } = require("./complianceUploadQuota");

function bufferStartsWith(buffer, expectedBytes) {
  if (buffer.length < expectedBytes.length) return false;
  for (let i = 0; i < expectedBytes.length; i += 1) {
    if (buffer[i] !== expectedBytes[i]) return false;
  }
  return true;
}

// Structural, dependency-free signature check. This is NOT a full parse
// of the file format — for PDF it additionally requires an "%%EOF"
// marker somewhere in the content as a lightweight sanity check beyond
// the header; for JPEG/PNG it is a magic-byte check only. No image
// decode library is part of this repository's dependencies today, so
// full image-structure validation is not claimed here — this is
// documented as a known limitation, not silently assumed complete.
function verifyFileSignature(contentType, buffer) {
  const signature = COMPLIANCE_FILE_SIGNATURES[contentType];
  if (!signature) return { valid: false, reason: "unsupported_content_type" };
  if (!bufferStartsWith(buffer, signature.magicBytes)) {
    return { valid: false, reason: "magic_byte_mismatch" };
  }
  if (contentType === "application/pdf") {
    const tail = buffer.subarray(Math.max(0, buffer.length - 2048)).toString("latin1");
    if (!tail.includes("%%EOF")) {
      return { valid: false, reason: "pdf_missing_eof_marker" };
    }
  }
  return { valid: true };
}

function computeSha256(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

// Claims the session for this exact object (uploaded_authorized ->
// uploaded), verifying every field a client could have tried to spoof.
// Returns { claimed: true, session } on success, or
// { claimed: false, reason, deleteObject, session? } when the object
// should not be trusted — the caller is responsible for actually
// deleting the Storage object (kept outside the transaction, since
// Storage deletes are not part of Firestore transactions).
async function claimUploadedObject({ db, object, expectedBucket, logger }) {
  const filePath = object.name || "";
  const parts = filePath.split("/");
  // compliance_quarantine/{businessId}/{sessionId}/{objectId}
  if (parts.length !== 4 || parts[0] !== "compliance_quarantine") {
    return { claimed: false, reason: "unexpected_path_shape", deleteObject: false };
  }
  const [, pathBusinessId, sessionId] = parts;

  if (expectedBucket && object.bucket !== expectedBucket) {
    logger.error("compliance_finalize_bucket_mismatch", {
      sessionId,
      actualBucket: object.bucket,
    });
    return { claimed: false, reason: "bucket_mismatch", deleteObject: true, sessionId };
  }

  const sessionRef = db.collection("complianceUploadSessions").doc(sessionId);

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(sessionRef);
    if (!snap.exists) {
      return { claimed: false, reason: "session_not_found" };
    }
    const session = snap.data();

    // Idempotency: a session not currently in upload_authorized has
    // already been claimed by a prior delivery of this same event (or
    // this is a genuinely stray/duplicate object) — no-op, do not touch
    // the object (it may already be mid-processing by the first
    // delivery) or the session again.
    if (session.status !== COMPLIANCE_UPLOAD_SESSION_STATUS.UPLOAD_AUTHORIZED) {
      return { claimed: false, reason: "session_not_upload_authorized", alreadyHandled: true };
    }

    if (session.businessId !== pathBusinessId) {
      return { claimed: false, reason: "business_mismatch", session };
    }
    if (session.objectPath !== filePath) {
      return { claimed: false, reason: "path_mismatch", session };
    }
    const expiresAtMs =
      session.expiresAt && typeof session.expiresAt.toMillis === "function"
        ? session.expiresAt.toMillis()
        : new Date(session.expiresAt).getTime();
    if (!Number.isFinite(expiresAtMs) || expiresAtMs <= Date.now()) {
      return { claimed: false, reason: "session_expired", session };
    }

    if (!isAllowedComplianceUploadSessionTransition(session.status, COMPLIANCE_UPLOAD_SESSION_STATUS.UPLOADED)) {
      return { claimed: false, reason: "illegal_transition", session };
    }

    tx.update(sessionRef, {
      status: COMPLIANCE_UPLOAD_SESSION_STATUS.UPLOADED,
      uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
      uploadedGeneration: String(object.generation || ""),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { claimed: true, session: { ...session, sessionId } };
  });

  if (!result.claimed && !result.alreadyHandled) {
    logger.error("compliance_finalize_claim_rejected", {
      sessionId,
      reason: result.reason,
    });
  }
  return { ...result, sessionId };
}

// Performs the actual validation body — download, size/type/signature
// checks, SHA-256 — and writes the terminal outcome (validation_failed or
// scan_pending). Deliberately split out from validateUploadedObject()
// below: this half assumes the session is ALREADY at VALIDATING (it does
// not perform or require the UPLOADED -> VALIDATING transition itself),
// so the reconciler (complianceUploadReconciliation.js) can call this
// directly to resume a session found stuck at VALIDATING after a crash,
// without re-deriving a fake "first" transition for a step that already
// happened.
async function performValidation({ db, bucket, object, session, logger }) {
  const sessionRef = db.collection("complianceUploadSessions").doc(session.sessionId);
  const filePath = object.name;

  const actualSizeBytes = Number(object.size);
  const actualContentType = object.contentType || "";
  const hasDownloadToken = Boolean(
    object.metadata && object.metadata.firebaseStorageDownloadTokens
  );

  let failureReason = null;
  if (hasDownloadToken) {
    failureReason = "unexpected_download_token_present";
  } else if (!Number.isFinite(actualSizeBytes) || actualSizeBytes <= 0 || actualSizeBytes > session.maxSizeBytes) {
    failureReason = "size_out_of_bounds";
  } else if (
    !COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES.includes(actualContentType) ||
    actualContentType !== session.declaredMimeType
  ) {
    failureReason = "content_type_mismatch";
  }

  let buffer = null;
  let sha256 = null;
  let signatureCheck = null;
  if (!failureReason) {
    [buffer] = await bucket.file(filePath).download();
    sha256 = computeSha256(buffer);
    signatureCheck = verifyFileSignature(actualContentType, buffer);
    if (!signatureCheck.valid) {
      failureReason = signatureCheck.reason;
    }
  }

  if (failureReason) {
    const applied = await db.runTransaction(async (tx) => {
      const snap = await tx.get(sessionRef);
      const current = snap.data();
      // Idempotency guard: another delivery/reconciliation attempt may
      // have already resolved this session (e.g. a duplicate Storage
      // event racing a reconciliation resume). Only the first writer
      // transitions the status and releases quota.
      if (current.status !== COMPLIANCE_UPLOAD_SESSION_STATUS.VALIDATING) {
        return false;
      }
      tx.update(sessionRef, {
        status: COMPLIANCE_UPLOAD_SESSION_STATUS.VALIDATION_FAILED,
        validationFailureReason: failureReason,
        finalizedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      releaseActiveUploadQuota({ tx, db, businessId: session.businessId, uid: session.issuedBy });
      return true;
    });
    if (applied) {
      logger.error("compliance_finalize_validation_failed", {
        sessionId: session.sessionId,
        reason: failureReason,
      });
      await bucket
        .file(filePath)
        .delete({ ignoreNotFound: true })
        .catch((err) => logger.error("compliance_finalize_delete_failed", { message: err && err.message }));
    }
    return { status: COMPLIANCE_UPLOAD_SESSION_STATUS.VALIDATION_FAILED, reason: failureReason };
  }

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(sessionRef);
    const current = snap.data();
    if (current.status !== COMPLIANCE_UPLOAD_SESSION_STATUS.VALIDATING) {
      return; // already progressed past this step by another delivery
    }
    tx.update(sessionRef, {
      status: COMPLIANCE_UPLOAD_SESSION_STATUS.SCAN_PENDING,
      contentHash: sha256,
      actualContentType,
      actualSizeBytes,
      finalizedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return {
    status: COMPLIANCE_UPLOAD_SESSION_STATUS.SCAN_PENDING,
    sha256,
    actualContentType,
    actualSizeBytes,
  };
}

// Claims the UPLOADED -> VALIDATING transition, then runs performValidation.
// This is the entry point the finalize Storage trigger uses for a fresh
// object; the reconciler uses performValidation directly for a session
// already at VALIDATING (see its doc comment above).
async function validateUploadedObject({ db, bucket, object, session, logger }) {
  const sessionRef = db.collection("complianceUploadSessions").doc(session.sessionId);

  const claimedValidating = await db.runTransaction(async (tx) => {
    const snap = await tx.get(sessionRef);
    const current = snap.data();
    if (current.status !== COMPLIANCE_UPLOAD_SESSION_STATUS.UPLOADED) {
      return false; // already progressed past this step by another delivery
    }
    tx.update(sessionRef, {
      status: COMPLIANCE_UPLOAD_SESSION_STATUS.VALIDATING,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  });

  if (!claimedValidating) {
    return { status: session.status, reason: "already_progressed" };
  }

  return performValidation({ db, bucket, object, session, logger });
}

// Top-level entry point wired from the Storage trigger in
// functions/index.js. Returns a result object for logging/tests; never
// throws for an expected/handled outcome (invalid object, stale event,
// etc.) — only for genuine infrastructure errors, matching Cloud
// Functions' own retry-on-throw semantics being reserved for real
// transient failures, not for objects this pipeline correctly rejects.
async function processComplianceQuarantineUpload({ db, bucket, object, expectedBucket, logger = console }) {
  const filePath = object && object.name;
  if (!filePath || !filePath.startsWith("compliance_quarantine/")) {
    return { handled: false, reason: "not_quarantine_prefix" };
  }

  const claim = await claimUploadedObject({ db, object, expectedBucket, logger });
  if (!claim.claimed) {
    if (claim.deleteObject) {
      await bucket
        .file(filePath)
        .delete({ ignoreNotFound: true })
        .catch((err) => logger.error("compliance_finalize_delete_failed", { message: err && err.message }));
    }
    return { handled: true, claimed: false, reason: claim.reason };
  }

  const validation = await validateUploadedObject({
    db,
    bucket,
    object,
    session: claim.session,
    logger,
  });

  return { handled: true, claimed: true, sessionId: claim.sessionId, ...validation };
}

module.exports = {
  processComplianceQuarantineUpload,
  claimUploadedObject,
  validateUploadedObject,
  performValidation,
  verifyFileSignature,
  computeSha256,
};
