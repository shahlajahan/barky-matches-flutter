"use strict";

// Petsupo Marketplace P1-A compliance foundation — Slice 4.10 (docs/
// plans/marketplace_p1a_compliance_review_implementation_plan_2026-08-21
// .md, §0.17, committed Revision 19): `deleteMarketplaceProduct` — the
// sole path by which a seller may delete their own product. Retires
// direct client-initiated product deletion (§0.15/§0.17 Gap B): the
// corresponding `firestore.rules` `allow delete: if false` change
// (§9.E) means no client SDK caller, including admin, may delete a
// product document directly any longer — only this Admin-SDK callable,
// which atomically deletes the product together with its
// `productComplianceDecisions` document (if present) and its complete
// current `productEvidenceLinks` set, may perform a physical deletion.
//
// Authorization is owner-only (§0.17 Phase 5) — never admin, never a
// bypass of any kind. Reuses `assertCallerOwnsBusiness`
// (`complianceUploadSessions.js`) exactly, including its additive `tx`
// parameter (§0.17 Phase 5, corrected by independent review) so the
// business-ownership read genuinely participates in this callable's own
// deletion transaction — never a separate, non-transactional read.
//
// Idempotency is provided by a minimal, server-only, 30-day deletion
// receipt (§0.17 Phase 7), keyed by a deterministic SHA-256 receiptId
// mirroring `complianceUploadSessions.js`'s own `deriveSessionId`
// convention exactly, with a new domain tag.

const crypto = require("node:crypto");
const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");

const { assertCallerOwnsBusiness } = require("./complianceUploadSessions");
const { deriveEvidenceLinkId } = require("./complianceMatching");
const {
  PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS,
} = require("./complianceConstants");
const { REASON_CODE: PILOT_PRODUCT_APPROVAL_REASON_CODE } = require("./pilotProductApproval");
// Revision 33 §A(5) — the single authoritative cleanup primitive, shared
// with the business-deletion cascade so the two can never drift.
const { processPendingMediaCleanup } = require("../product/pendingMediaCleanup");
const {
  cleanupProductFirestoreState,
  MalformedDecisionStateError,
  CLEANUP_SOURCE,
  CLEANUP_OUTCOME,
} = require("../product/productCleanup");

const PRODUCTS_COLLECTION = "businesses";
const DECISIONS_COLLECTION = "productComplianceDecisions";
const LINKS_COLLECTION = "productEvidenceLinks";
const RECEIPTS_COLLECTION = "marketplaceProductDeletionReceipts";

const MAX_ID_LENGTH = 128;
// §0.17 Phase 6, corrected by independent review: mirrors the directly
// on-point, already-established `clientIdempotencyKey` bound in
// `complianceUploadSessions.js`'s own `assertValidRequestShape` exactly
// (128 characters) — not the unrelated Slice 4.5 pagination-cursor bound
// the first-drafted plan text mistakenly cited.
const MAX_IDEMPOTENCY_KEY_LENGTH = 128;
const RECEIPT_TTL_DAYS = 30;
const RECEIPT_TTL_MS = RECEIPT_TTL_DAYS * 24 * 60 * 60 * 1000;

const REQUEST_ALLOWED_FIELDS = Object.freeze([
  "businessId",
  "productId",
  "clientIdempotencyKey",
]);

// §0.17 Phase 6 — one fixed, content-free reason slug per outcome,
// carried in `HttpsError`'s own `details.reasonCode`. Never the
// product/business ID, never SKU, never evidence content.
const REASON = Object.freeze({
  // Revision 33: a product bound to an earlier generation of a recreated
  // business is never removed through the seller-facing path.
  GENERATION_MISMATCH: "generation_mismatch",
  UNAUTHENTICATED: "unauthenticated",
  INVALID_REQUEST: "invalid_request",
  BUSINESS_NOT_FOUND: "business_not_found",
  PRODUCT_NOT_FOUND: "product_not_found",
  NOT_BUSINESS_OWNER: "not_business_owner",
  BUSINESS_ID_MISMATCH: "business_id_mismatch",
  IDEMPOTENCY_KEY_CONFLICT: "idempotency_key_conflict",
  MALFORMED_DECISION_STATE: "malformed_decision_state",
  INTERNAL_ERROR: "internal_error",
});

function productRef(db, businessId, productId) {
  return db
    .collection(PRODUCTS_COLLECTION)
    .doc(businessId)
    .collection("products")
    .doc(productId);
}

function decisionRef(db, productId) {
  return db.collection(DECISIONS_COLLECTION).doc(productId);
}

function linkRef(db, linkId) {
  return db.collection(LINKS_COLLECTION).doc(linkId);
}

// §0.17 Phase 7 — mirrors `deriveSessionId`'s own exact hashing
// convention: SHA-256 hex of a colon-separated domain-tag:businessId:
// uid:clientIdempotencyKey string. A new domain tag distinguishes this
// receipt space from `complianceUploadSessions`' own session-ID space.
function deriveReceiptId({ businessId, uid, clientIdempotencyKey }) {
  return crypto
    .createHash("sha256")
    .update(`marketplace_product_deletion:${businessId}:${uid}:${clientIdempotencyKey}`)
    .digest("hex");
}

function assertValidRequestShape(data) {
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", "Request must be an object", {
      reasonCode: REASON.INVALID_REQUEST,
    });
  }
  const keys = Object.keys(data);
  if (!keys.every((key) => REQUEST_ALLOWED_FIELDS.includes(key))) {
    throw new HttpsError(
      "invalid-argument",
      "Request contains an unrecognized field",
      { reasonCode: REASON.INVALID_REQUEST }
    );
  }
  const { businessId, productId, clientIdempotencyKey } = data;
  if (
    typeof businessId !== "string" ||
    businessId.length === 0 ||
    businessId.length > MAX_ID_LENGTH
  ) {
    throw new HttpsError("invalid-argument", "businessId is invalid", {
      reasonCode: REASON.INVALID_REQUEST,
    });
  }
  if (
    typeof productId !== "string" ||
    productId.length === 0 ||
    productId.length > MAX_ID_LENGTH
  ) {
    throw new HttpsError("invalid-argument", "productId is invalid", {
      reasonCode: REASON.INVALID_REQUEST,
    });
  }
  if (
    typeof clientIdempotencyKey !== "string" ||
    clientIdempotencyKey.length === 0 ||
    clientIdempotencyKey.length > MAX_IDEMPOTENCY_KEY_LENGTH
  ) {
    throw new HttpsError(
      "invalid-argument",
      "clientIdempotencyKey is invalid",
      { reasonCode: REASON.INVALID_REQUEST }
    );
  }
  return { businessId, productId, clientIdempotencyKey };
}

// §0.17 Phase 9 — the link-completeness invariant's own fail-closed
// hard-stop. Validates the current decision's `activeEvidenceRefs`
// (malformed shape, >10 entries, duplicate entries, a wrong-business
// reference, or an un-derivable link ID) and derives every link
// document reference to delete, entirely from already-read data — no
// query, no extra read. "Wrong-business reference": `activeEvidenceRefs`
// entries carry no per-entry `businessId` field in the frozen §4 schema,
// so this is checked once, against the decision's own already-read
// top-level `businessId` field — every ref in a decision is guaranteed,
// by the matching engine's own cross-tenant isolation (already
// established elsewhere in this codebase), to belong to the same
// business as `decision.businessId` itself; this single check therefore
// stands in for a per-ref check without requiring any additional read.
function deriveLinkRefsOrFailClosed({ db, productId, businessId, decision }) {
  if (decision.businessId !== businessId) {
    throw new HttpsError(
      "failed-precondition",
      "Decision state is malformed",
      { reasonCode: REASON.MALFORMED_DECISION_STATE }
    );
  }
  const refs = decision.activeEvidenceRefs;
  if (!Array.isArray(refs)) {
    throw new HttpsError(
      "failed-precondition",
      "Decision state is malformed",
      { reasonCode: REASON.MALFORMED_DECISION_STATE }
    );
  }
  if (refs.length > PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS) {
    throw new HttpsError(
      "failed-precondition",
      "Decision state is malformed",
      { reasonCode: REASON.MALFORMED_DECISION_STATE }
    );
  }
  const seen = new Set();
  const refsToDelete = [];
  for (const ref of refs) {
    if (
      !ref ||
      typeof ref !== "object" ||
      typeof ref.documentId !== "string" ||
      ref.documentId.length === 0 ||
      typeof ref.scopeId !== "string" ||
      ref.scopeId.length === 0
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Decision state is malformed",
        { reasonCode: REASON.MALFORMED_DECISION_STATE }
      );
    }
    const dedupeKey = `${ref.documentId}::${ref.scopeId}`;
    if (seen.has(dedupeKey)) {
      throw new HttpsError(
        "failed-precondition",
        "Decision state is malformed",
        { reasonCode: REASON.MALFORMED_DECISION_STATE }
      );
    }
    seen.add(dedupeKey);
    let linkId;
    try {
      linkId = deriveEvidenceLinkId({
        productId,
        documentId: ref.documentId,
        scopeId: ref.scopeId,
      });
    } catch (err) {
      throw new HttpsError(
        "failed-precondition",
        "Decision state is malformed",
        { reasonCode: REASON.MALFORMED_DECISION_STATE }
      );
    }
    refsToDelete.push(linkRef(db, linkId));
  }
  return refsToDelete;
}

// §0.17 Phases 5/8/9/10/11 — the complete authorization + transaction
// body. Reads: receipt, business (via `assertCallerOwnsBusiness`'s own
// `tx`-aware read), product, decision-if-present — ≤4 total. Writes:
// ≤10 link deletes, 1 decision delete (if present), 1 product delete, 1
// receipt create — ≤13 total. All reads precede all writes.
async function deleteMarketplaceProductCore({
  db,
  auth,
  data,
  now,
  storage = null,
  bucketName = null,
  logger = console,
}) {
  if (!auth || !auth.uid) {
    throw new HttpsError("unauthenticated", "Login required", {
      reasonCode: REASON.UNAUTHENTICATED,
    });
  }
  const request = assertValidRequestShape(data);

  const receiptId = deriveReceiptId({
    businessId: request.businessId,
    uid: auth.uid,
    clientIdempotencyKey: request.clientIdempotencyKey,
  });
  const receiptDocRef = db.collection(RECEIPTS_COLLECTION).doc(receiptId);

  // Firestore and Storage cannot share a transaction. The transaction is the
  // authority: it commits the deletion, and only afterwards are the objects
  // it proved deletable removed. A Storage failure never resurrects the
  // product document — it is reported, best-effort and idempotent.
  let pendingCleanupId = null;

  const result = await db.runTransaction(async (tx) => {
    pendingCleanupId = null;
    const nowMs = typeof now === "function" ? now() : Date.now();

    // Read 1: the deterministic receipt (Case A/B replay short-circuit).
    const receiptSnap = await tx.get(receiptDocRef);
    if (receiptSnap.exists) {
      const receiptData = receiptSnap.data() || {};
      if (
        receiptData.businessId === request.businessId &&
        receiptData.productId === request.productId
      ) {
        return { status: "replayed", productId: request.productId };
      }
      throw new HttpsError(
        "already-exists",
        "This request has already been used for a different product",
        { reasonCode: REASON.IDEMPOTENCY_KEY_CONFLICT }
      );
    }

    // Revision 33: the ownership read's own snapshot is reused below for the
    // generation binding, so the transaction keeps exactly one business read.
    let businessSnapForGeneration = null;
    try {
      businessSnapForGeneration = await assertCallerOwnsBusiness({
        db,
        businessId: request.businessId,
        uid: auth.uid,
        tx,
      });
    } catch (err) {
      if (err instanceof HttpsError && err.code === "not-found") {
        throw new HttpsError("not-found", "Business not found", {
          reasonCode: REASON.BUSINESS_NOT_FOUND,
        });
      }
      if (err instanceof HttpsError && err.code === "permission-denied") {
        throw new HttpsError(
          "permission-denied",
          "You are not the owner of this business",
          { reasonCode: REASON.NOT_BUSINESS_OWNER }
        );
      }
      throw err;
    }

    // Revision 33 §A(5): the destructive half is delegated to the shared
    // cleanup primitive, which both this callable and the business-deletion
    // cascade use. Every outcome below maps back onto this callable's own
    // frozen reason codes, so its public contract is unchanged.
    //
    // `expectedGenerationId` is always derived server-side, never accepted
    // from the client. When the owning business carries no generation
    // binding at all (legacy or pre-Revision-28 data) it is null and
    // generation verification does not apply — recorded as unverified in
    // the cleanup audit rather than silently assumed to match.
    const businessGeneration =
      businessSnapForGeneration && businessSnapForGeneration.exists
        ? (businessSnapForGeneration.data() || {}).marketplaceBusinessGenerationId
        : null;
    const expectedGenerationId =
      typeof businessGeneration === "string" && businessGeneration.length > 0
        ? businessGeneration
        : null;

    let cleanup;
    try {
      cleanup = await cleanupProductFirestoreState({
        db,
        tx,
        businessId: request.businessId,
        productId: request.productId,
        expectedGenerationId,
        source: CLEANUP_SOURCE.MANUAL_DELETE,
        actorUid: auth.uid,
        bucketName,
        businessExists: true,
      });
    } catch (error) {
      if (error instanceof MalformedDecisionStateError) {
        throw new HttpsError("failed-precondition", "Decision state is malformed", {
          reasonCode: REASON.MALFORMED_DECISION_STATE,
        });
      }
      throw error;
    }

    if (cleanup.outcome === CLEANUP_OUTCOME.ALREADY_ABSENT) {
      throw new HttpsError("not-found", "Product not found", {
        reasonCode: REASON.PRODUCT_NOT_FOUND,
      });
    }
    if (cleanup.outcome === CLEANUP_OUTCOME.SKIPPED_BUSINESS_MISMATCH) {
      throw new HttpsError(
        "permission-denied",
        "Product does not belong to the specified business",
        { reasonCode: REASON.BUSINESS_ID_MISMATCH }
      );
    }
    if (cleanup.outcome === CLEANUP_OUTCOME.SKIPPED_GENERATION_MISMATCH) {
      // The product belongs to an earlier generation of a recreated
      // business. It is never deleted through the seller-facing path; the
      // business-deletion cascade owns that cleanup.
      throw new HttpsError(
        "failed-precondition",
        "Product belongs to a previous business generation",
        { reasonCode: REASON.GENERATION_MISMATCH }
      );
    }

    tx.set(receiptDocRef, {
      businessId: request.businessId,
      productId: request.productId,
      actorUid: auth.uid,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      expireAt: new Date(nowMs + RECEIPT_TTL_MS),
    });

    pendingCleanupId = cleanup.pendingCleanupId;

    return { status: "deleted", productId: request.productId };
  });

  // Revision 33 correction: the authoritative record of what must be removed
  // now lives in `marketplacePendingMediaCleanups`, written in the same
  // transaction as the product deletion. This immediate attempt is a latency
  // optimisation only — if it fails, or the process dies here, the scheduled
  // resumer completes the work from the durable record. Nothing is lost.
  if (pendingCleanupId) {
    try {
      await processPendingMediaCleanup({
        db,
        storage,
        cleanupId: pendingCleanupId,
        logger,
      });
    } catch (error) {
      logger.warn("marketplace_pending_media_immediate_attempt_failed", {
        code: (error && error.code) || "unknown",
      });
    }
  }

  return result;
}

// §0.17 Phase 6 — three fixed, content-free structured log shapes; none
// carries `businessId`, `productId`, SKU, evidence, or raw error
// content. `logger` is dependency-injected (default `console`), matching
// the existing `complianceProductRecomputeSweep.js` convention.
async function deleteMarketplaceProduct({
  db,
  auth,
  data,
  now = () => Date.now(),
  logger = console, storage = null, bucketName = null }) {
  try {
    const result = await deleteMarketplaceProductCore({
      db,
      auth,
      data,
      now,
      storage,
      bucketName,
      logger,
    });
    if (result.status === "replayed") {
      logger.log("marketplace_product_deletion_replayed");
    } else {
      logger.log("marketplace_product_deletion_succeeded");
    }
    return result;
  } catch (err) {
    const reasonCode =
      (err && err.details && err.details.reasonCode) || REASON.INTERNAL_ERROR;
    logger.error("marketplace_product_deletion_failed", { reasonCode });
    if (err instanceof HttpsError) {
      throw err;
    }
    throw new HttpsError("internal", "Unable to delete product", {
      reasonCode: REASON.INTERNAL_ERROR,
    });
  }
}

module.exports = {
  deleteMarketplaceProduct,
  deriveReceiptId,
  REASON,
  RECEIPT_TTL_DAYS,
  RECEIPTS_COLLECTION,
};
