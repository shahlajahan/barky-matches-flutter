"use strict";

// Marketplace Revision 30 §J Slice 4 — admin-only evidence viewing.
//
// The narrowly authorized backend prerequisite for the admin review UI. It
// exists because `compliance_docs/**` is `allow read, write: if false` in
// storage.rules and MUST stay that way: no client, admin included, may read a
// promoted evidence object directly. This callable is the only authorized
// route, and it hands back a short-lived signed URL to an object the SERVER
// resolved — never one the caller named.
//
// DELIVERY MECHANISM, and why it is not Base64.
// The frozen upload cap is 15 MiB (COMPLIANCE_UPLOAD_SESSION_MAX_SIZE_BYTES)
// for each of the three allowed types. Base64 inflates that to exactly
// 20 MiB. These are Gen 2 callables (firebase-functions/v2/https, on Cloud
// Run), whose response ceiling is 32 MiB — so a maximum-size document would
// consume 62.5% of the hard limit, a margin of 1.60x, and would not fit at
// all under a Gen 1-style 10 MiB ceiling. Worse, on the client a 20,971,520-
// character Base64 string costs ~40 MiB in the Dart heap (UTF-16), on top of
// the ~20 MiB HTTP body and the 15 MiB decoded bytes: a ~75 MiB transient
// peak to view one document. That is not a safe bound, so Base64 is rejected.
//
// RESIDUAL RISK, stated plainly. A signed URL is a short-lived bearer
// capability: anyone holding it within its lifetime can fetch that one
// object. It is preferred over an oversized callable response because the
// exposure is a single object, for 90 seconds, to an already-authenticated
// admin, and it is bounded by construction — whereas the Base64 path risks
// client OOM on every large document and sits at 62.5% of a hard protocol
// limit with no headroom for future format or size changes. It is NEVER a
// Firebase download token (permanent), never a public ACL, and never stored.

const { HttpsError } = require("firebase-functions/v2/https");

const {
  COMPLIANCE_DOCUMENT_STATUS,
  COMPLIANCE_UPLOAD_SESSION_STATUS,
  COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES,
  COMPLIANCE_UPLOAD_SESSION_MAX_SIZE_BYTES,
} = require("./complianceConstants");
const { requireAdmin } = require("../../moderation/adminAuth");

// The ONLY field a caller may send. Everything that identifies an object —
// path, bucket, business, generation, hash, size, MIME, owner — is derived
// server-side from the canonical record, so there is nothing to substitute.
const EVIDENCE_REQUEST_ALLOWED_FIELDS = Object.freeze(["documentId"]);

// Revision 30 §G's review lifecycle is `clean -> pending_review -> approved |
// rejected`. Slice 4 reviews documents at `pending_review`, so that is the
// one state whose object an admin may open. `approved`/`rejected` history
// viewing is deliberately NOT enabled: Revision 30 freezes no admin viewing
// right for those states and Slice 4 does not need one. Fail closed, and let
// a later slice widen this explicitly rather than inheriting it silently.
const ADMIN_VIEWABLE_DOCUMENT_STATUSES = Object.freeze([
  COMPLIANCE_DOCUMENT_STATUS.PENDING_REVIEW,
]);

// 90 seconds: long enough for one admin to open one document on a slow
// connection, short enough that a leaked URL is worthless almost immediately.
const EVIDENCE_SIGNED_URL_TTL_MS = 90 * 1000;

const COMPLIANCE_DOCS_PREFIX = "compliance_docs/";

// Extension/MIME agreement, mirroring the intake rule so a promoted object
// can never be served as a type its own name contradicts.
const EXTENSION_FOR_CONTENT_TYPE = Object.freeze({
  "application/pdf": [".pdf"],
  "image/jpeg": [".jpg", ".jpeg"],
  "image/png": [".png"],
});

const EVIDENCE_REASON = Object.freeze({
  NOT_FOUND: "document_not_found",
  NOT_VIEWABLE: "document_not_viewable",
  MALFORMED_RECORD: "document_record_malformed",
  BINDING_MISMATCH: "object_binding_mismatch",
  OBJECT_MISSING: "object_missing",
  UNSUPPORTED_TYPE: "unsupported_content_type",
  SIGNING_UNAVAILABLE: "signing_unavailable",
});

function fail(code, message, reasonCode) {
  return new HttpsError(code, message, { reasonCode });
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.length > 0;
}

// A canonical promoted path and nothing else: exactly the prefix the
// promotion step writes, scoped to this document's own business and id, with
// no traversal and no nesting escape. compliance_quarantine can never match.
function isCanonicalDocsPath(path, businessId, documentId) {
  if (!isNonEmptyString(path)) return false;
  if (path.includes("..") || path.includes("//") || path.startsWith("/")) return false;
  const expectedPrefix = `${COMPLIANCE_DOCS_PREFIX}${businessId}/${documentId}/`;
  if (!path.startsWith(expectedPrefix)) return false;
  // Exactly one path segment after the prefix — the objectId, no sub-paths.
  const tail = path.slice(expectedPrefix.length);
  return tail.length > 0 && !tail.includes("/");
}

function extensionAgreesWithContentType(path, contentType) {
  const allowed = EXTENSION_FOR_CONTENT_TYPE[contentType];
  if (!allowed) return false;
  const lower = path.toLowerCase();
  return allowed.some((ext) => lower.endsWith(ext));
}

/// Production signer. Never a Firebase download token (those are permanent
/// and live in object metadata); never a public ACL. A v4 signed URL is
/// generated per request and expires on its own.
async function defaultSigner({ file, expiresAtMs, contentType }) {
  const [url] = await file.getSignedUrl({
    version: "v4",
    action: "read",
    expires: expiresAtMs,
    // Force a download rather than letting a browser decide to execute or
    // frame the response, and pin the type to the one the server verified.
    responseType: contentType,
    responseDisposition: "attachment",
  });
  return url;
}

async function getComplianceDocumentEvidence({
  db,
  bucket,
  auth,
  data,
  signer = defaultSigner,
  now = Date.now,
  logger = console,
}) {
  // Admin first: nothing about any document — not even whether it exists —
  // is disclosed before authorization.
  const adminUid = await requireAdmin(db, { auth });

  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw fail("invalid-argument", "Request must be an object", EVIDENCE_REASON.MALFORMED_RECORD);
  }
  for (const key of Object.keys(data)) {
    if (!EVIDENCE_REQUEST_ALLOWED_FIELDS.includes(key)) {
      // A caller trying to supply storagePath/bucket/businessId/etc. is
      // refused outright rather than having the value quietly ignored.
      throw fail(
        "invalid-argument",
        "Request contains an unsupported field",
        EVIDENCE_REASON.MALFORMED_RECORD
      );
    }
  }
  const { documentId } = data;
  if (!isNonEmptyString(documentId) || documentId.includes("/")) {
    throw fail("invalid-argument", "documentId is required", EVIDENCE_REASON.MALFORMED_RECORD);
  }

  const docSnap = await db.collection("complianceDocuments").doc(documentId).get();
  if (!docSnap.exists) {
    throw fail("not-found", "Document not found", EVIDENCE_REASON.NOT_FOUND);
  }
  const document = docSnap.data() || {};

  // An unknown, malformed or future status is never viewable. Positive
  // allowlist, never a deny-list.
  if (!ADMIN_VIEWABLE_DOCUMENT_STATUSES.includes(document.status)) {
    throw fail(
      "failed-precondition",
      "This document is not available for review",
      EVIDENCE_REASON.NOT_VIEWABLE
    );
  }

  const { businessId, sessionId, storagePath, contentHash, sizeBytes } = document;
  const generationId = document.marketplaceBusinessGenerationId;
  if (
    !isNonEmptyString(businessId) ||
    !isNonEmptyString(sessionId) ||
    !isNonEmptyString(storagePath) ||
    !isNonEmptyString(contentHash) ||
    !isNonEmptyString(generationId) ||
    typeof sizeBytes !== "number" ||
    !Number.isFinite(sizeBytes) ||
    sizeBytes <= 0 ||
    sizeBytes > COMPLIANCE_UPLOAD_SESSION_MAX_SIZE_BYTES
  ) {
    // A record missing a frozen binding is not "mostly fine" — it cannot be
    // bound safely, so nothing is disclosed.
    logger.warn("compliance_evidence_record_malformed", {
      reason: EVIDENCE_REASON.MALFORMED_RECORD,
    });
    throw fail(
      "failed-precondition",
      "This document is not available for review",
      EVIDENCE_REASON.MALFORMED_RECORD
    );
  }

  if (!isCanonicalDocsPath(storagePath, businessId, documentId)) {
    logger.warn("compliance_evidence_path_rejected", {
      reason: EVIDENCE_REASON.BINDING_MISMATCH,
    });
    throw fail(
      "failed-precondition",
      "This document is not available for review",
      EVIDENCE_REASON.BINDING_MISMATCH
    );
  }

  // The session is the second half of the frozen identity chain: it records
  // the verified content type and the promoted object generation, neither of
  // which lives on the document record.
  const sessionSnap = await db.collection("complianceUploadSessions").doc(sessionId).get();
  const session = sessionSnap.exists ? sessionSnap.data() || {} : null;
  const contentType = session ? session.actualContentType : null;
  if (
    !session ||
    session.businessId !== businessId ||
    session.documentId !== documentId ||
    session.marketplaceBusinessGenerationId !== generationId ||
    session.destinationPath !== storagePath ||
    session.contentHash !== contentHash ||
    session.status !== COMPLIANCE_UPLOAD_SESSION_STATUS.CONSUMED
  ) {
    logger.warn("compliance_evidence_session_binding_failed", {
      reason: EVIDENCE_REASON.BINDING_MISMATCH,
    });
    throw fail(
      "failed-precondition",
      "This document is not available for review",
      EVIDENCE_REASON.BINDING_MISMATCH
    );
  }

  if (
    !COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES.includes(contentType) ||
    !extensionAgreesWithContentType(storagePath, contentType)
  ) {
    throw fail(
      "failed-precondition",
      "This document cannot be displayed",
      EVIDENCE_REASON.UNSUPPORTED_TYPE
    );
  }

  // Finally the object itself, addressed only by the server-resolved path.
  const file = bucket.file(storagePath);
  const [exists] = await file.exists();
  if (!exists) {
    throw fail("failed-precondition", "Evidence is unavailable", EVIDENCE_REASON.OBJECT_MISSING);
  }
  const [metadata] = await file.getMetadata();
  const custom = (metadata && metadata.metadata) || {};
  const objectSize = Number(metadata && metadata.size);
  const expectedGeneration = session.promotedGeneration;
  if (
    custom.businessId !== businessId ||
    custom.documentId !== documentId ||
    custom.sessionId !== sessionId ||
    metadata.contentType !== contentType ||
    !Number.isFinite(objectSize) ||
    objectSize !== sizeBytes ||
    // Generation is verified where it was recorded; an absent recorded
    // generation is a malformed binding, not a reason to skip the check.
    !isNonEmptyString(expectedGeneration) ||
    String(metadata.generation) !== String(expectedGeneration)
  ) {
    logger.warn("compliance_evidence_object_binding_failed", {
      reason: EVIDENCE_REASON.BINDING_MISMATCH,
    });
    throw fail(
      "failed-precondition",
      "Evidence is unavailable",
      EVIDENCE_REASON.BINDING_MISMATCH
    );
  }

  const expiresAtMs = now() + EVIDENCE_SIGNED_URL_TTL_MS;
  let downloadUrl;
  try {
    downloadUrl = await signer({ file, expiresAtMs, contentType });
  } catch (error) {
    // A signing failure is an operational fault, never a fallback to a
    // public URL or a token. Nothing about the object is disclosed.
    logger.error("compliance_evidence_signing_failed", {
      reason: EVIDENCE_REASON.SIGNING_UNAVAILABLE,
    });
    throw fail("internal", "Evidence is unavailable", EVIDENCE_REASON.SIGNING_UNAVAILABLE);
  }
  if (!isNonEmptyString(downloadUrl)) {
    throw fail("internal", "Evidence is unavailable", EVIDENCE_REASON.SIGNING_UNAVAILABLE);
  }

  // Identifier-safe only: no path, no URL, no bucket, no hash, no owner.
  logger.info("compliance_evidence_access_granted", { actorRole: "admin" });
  void adminUid;

  // Exactly what the viewer needs, and nothing that would let a caller
  // reconstruct an object address: no bucket, no path, no owner, no session,
  // no nonce, no scanner detail.
  return {
    documentId,
    downloadUrl,
    contentType,
    sizeBytes,
    contentHash,
    expiresAtMs,
  };
}

module.exports = {
  getComplianceDocumentEvidence,
  ADMIN_VIEWABLE_DOCUMENT_STATUSES,
  EVIDENCE_REQUEST_ALLOWED_FIELDS,
  EVIDENCE_SIGNED_URL_TTL_MS,
  EVIDENCE_REASON,
  isCanonicalDocsPath,
  extensionAgreesWithContentType,
};
