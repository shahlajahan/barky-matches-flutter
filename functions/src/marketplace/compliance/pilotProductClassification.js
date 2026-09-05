"use strict";

// Marketplace Revision 35 (Slice 7A) — admin pilot-product classification.
//
// THE BLOCKER THIS CLOSES. Revision 31 §C froze the field `pilotProductClass`,
// its exact four values and its server ownership; §D1 froze that the
// determination is an admin's. Neither froze how that determination gets
// recorded, and source at ec37ca0 had ZERO writers for it: rejected from
// seller drafts as server-owned, preserved-but-never-created by
// `firestore.rules`, and absent from every server write path. Slice 7 makes a
// valid class a precondition of publication, so without this module
// publication was permanently unreachable for every product.
//
// This is the sole write authority for `pilotProductClass`. It is a
// PRECONDITION step, not an output of approval: `approvePilotProduct` neither
// selects nor infers a class and fails closed unless one is already recorded
// here (Revision 35 §A4).
//
// It never approves, activates or publishes anything. Its only
// publication-facing effect is subtractive: reclassifying a currently active
// product UNPUBLISHES it, through the one canonical revocation transition.

const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");

const { requireAdmin } = require("../../moderation/adminAuth");
const {
  isValidPilotProductClass,
  PILOT_CLASSIFICATION_MAX_REASON_LENGTH,
} = require("./complianceConstants");
const {
  applyPilotApprovalRevocation,
  assertValidRequestShape,
  assertNonEmptyString,
  businessRef,
  productRef,
  isValidGenerationId,
  isCurrentlyActivePilotApproval,
  REASON_CODE,
} = require("./pilotProductApproval");
const { bumpBusinessComplianceEpoch } = require("./complianceDocumentOperations");

const CLASSIFICATION_AUDIT_COLLECTION = "pilotProductClassificationAuditEvents";

// Closed request schema, in the frozen style of every other compliance
// callable. A caller supplying an owner uid, a generation id, a fingerprint,
// a revision or any approval state is refused outright, never ignored.
const CLASSIFY_ALLOWED_FIELDS = Object.freeze([
  "businessId",
  "productId",
  "pilotProductClass",
  "reason",
]);

// Stable, machine-readable outcome codes. Callers (including the admin UI)
// branch on these, never on message text.
const CLASSIFICATION_REASON_CODE = Object.freeze({
  MALFORMED_REQUEST: "classification-malformed-request",
  UNSUPPORTED_CLASS: "classification-unsupported-class",
  PRODUCT_NOT_FOUND: "classification-product-not-found",
  BUSINESS_NOT_FOUND: "classification-business-not-found",
  GENERATION_NOT_INITIALIZED: "classification-generation-not-initialized",
  STALE_GENERATION: "classification-stale-generation",
  INVALID_TRANSITION: "classification-invalid-transition",
});

function classificationError(code, message, reasonCode) {
  return new HttpsError(code, message, { reasonCode });
}

/// Records or changes a product's authoritative pilot class.
///
/// Every authoritative value — the product, its owning business, the live
/// generation, the current class and the current approval state — is read
/// inside the transaction, so a concurrent approval, revocation or
/// invalidation aborts and retries this call against fresh state rather than
/// committing on top of a stale admin screen.
async function setPilotProductClassification({ db, auth, data, logger = console }) {
  const adminUid = await requireAdmin(db, { auth });

  let payload;
  try {
    payload = assertValidRequestShape(data, CLASSIFY_ALLOWED_FIELDS);
  } catch (_error) {
    throw classificationError(
      "invalid-argument",
      "Request is malformed",
      CLASSIFICATION_REASON_CODE.MALFORMED_REQUEST
    );
  }

  let businessId;
  let productId;
  try {
    businessId = assertNonEmptyString(payload.businessId, "businessId");
    productId = assertNonEmptyString(payload.productId, "productId");
  } catch (_error) {
    throw classificationError(
      "invalid-argument",
      "Request is malformed",
      CLASSIFICATION_REASON_CODE.MALFORMED_REQUEST
    );
  }

  // The class allowlist is exact: no alias table, no case folding, no
  // trimming a near-miss into validity. Revision 31 §C's four values only.
  const pilotProductClass = payload.pilotProductClass;
  if (!isValidPilotProductClass(pilotProductClass)) {
    throw classificationError(
      "invalid-argument",
      "pilotProductClass is not supported",
      CLASSIFICATION_REASON_CODE.UNSUPPORTED_CLASS
    );
  }

  // A recorded rationale is mandatory — Revision 35 requires every
  // classification action to be attributable and explained.
  if (typeof payload.reason !== "string") {
    throw classificationError(
      "invalid-argument",
      "reason is required",
      CLASSIFICATION_REASON_CODE.MALFORMED_REQUEST
    );
  }
  const reason = payload.reason.trim();
  if (reason.length === 0 || reason.length > PILOT_CLASSIFICATION_MAX_REASON_LENGTH) {
    throw classificationError(
      "invalid-argument",
      "reason is required",
      CLASSIFICATION_REASON_CODE.MALFORMED_REQUEST
    );
  }

  const result = await db.runTransaction(async (tx) => {
    const bizRef = businessRef(db, businessId);
    const bizSnap = await tx.get(bizRef);
    if (!bizSnap.exists) {
      throw classificationError(
        "not-found",
        "Business not found",
        CLASSIFICATION_REASON_CODE.BUSINESS_NOT_FOUND
      );
    }
    const businessData = bizSnap.data() || {};

    const prodRef = productRef(db, businessId, productId);
    const prodSnap = await tx.get(prodRef);
    if (!prodSnap.exists) {
      throw classificationError(
        "not-found",
        "Product not found",
        CLASSIFICATION_REASON_CODE.PRODUCT_NOT_FOUND
      );
    }
    const product = prodSnap.data() || {};
    // A product may never be classified through a business it does not
    // belong to, even when both ids exist.
    if (product.businessId !== businessId) {
      throw classificationError(
        "not-found",
        "Product not found",
        CLASSIFICATION_REASON_CODE.PRODUCT_NOT_FOUND
      );
    }

    // Revision 30 §F generation binding, identical in strictness to
    // `approvePilotProduct`: an uninitialized or mismatched generation fails
    // closed, so a product left behind by a previous generation of a
    // same-id business can never be classified into the live one.
    if (!isValidGenerationId(businessData.marketplaceBusinessGenerationId)) {
      throw classificationError(
        "failed-precondition",
        "Business generation is not initialized",
        CLASSIFICATION_REASON_CODE.GENERATION_NOT_INITIALIZED
      );
    }
    const liveGeneration = businessData.marketplaceBusinessGenerationId;
    if (product.marketplaceBusinessGenerationId !== liveGeneration) {
      throw classificationError(
        "failed-precondition",
        "Product generation is stale",
        CLASSIFICATION_REASON_CODE.STALE_GENERATION
      );
    }

    // A soft-deleted product is not classifiable.
    if (product.deletedAt !== undefined && product.deletedAt !== null) {
      throw classificationError(
        "failed-precondition",
        "Product is not classifiable",
        CLASSIFICATION_REASON_CODE.INVALID_TRANSITION
      );
    }

    // Two readings of the same field, deliberately kept apart. `rawPrevious`
    // is what was literally stored — possibly a legacy or unrecognised value
    // — and is what the audit trail records, so a correction shows exactly
    // what it replaced instead of silently erasing it. `previousClass` is
    // that value normalized through the frozen allowlist, and is what every
    // decision below (idempotency, the caller's response) is made on: an
    // unrecognised stored value is not a class, so replacing it is a real
    // change, never an idempotent replay.
    const rawPrevious =
      product.pilotProductClass === undefined ? null : product.pilotProductClass;
    const previousClass = isValidPilotProductClass(rawPrevious) ? rawPrevious : null;

    // Idempotent replay: the identical class is already recorded. Nothing is
    // revoked, no counter moves, no epoch is bumped and — deliberately — no
    // audit event is written, so a retry storm or a double-tapped admin
    // button can neither unpublish a product nor inflate its history.
    if (previousClass === pilotProductClass) {
      return {
        changed: false,
        idempotent: true,
        previousClass,
        pilotProductClass,
        unpublished: false,
        classificationRevision:
          typeof product.pilotProductClassificationRevision === "number"
            ? product.pilotProductClassificationRevision
            : 0,
      };
    }

    // Monotonic, server-owned. A malformed or absent prior revision restarts
    // at 1 rather than propagating garbage; the client never supplies it.
    const priorRevision = product.pilotProductClassificationRevision;
    const classificationRevision =
      typeof priorRevision === "number" && Number.isInteger(priorRevision) && priorRevision > 0
        ? priorRevision + 1
        : 1;

    tx.update(prodRef, {
      pilotProductClass,
      pilotProductClassifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      pilotProductClassifiedByUid: adminUid,
      pilotProductClassificationRevision: classificationRevision,
    });

    // Revision 35 §A10 — changing the class of a currently active product
    // unpublishes it atomically, through the single canonical revocation
    // transition rather than a second copy of it. The already-inactive case
    // is excluded HERE, by the caller, which is exactly what keeps the
    // `pilotActiveProductCount` decrement exactly-once across retries: the
    // helper decrements unconditionally and is only ever reached from a read
    // set that proved the product active.
    const wasActive = isCurrentlyActivePilotApproval(product);
    if (wasActive) {
      applyPilotApprovalRevocation({
        tx,
        db,
        prodRef,
        bizRef,
        businessId,
        productId,
        reasonCode: REASON_CODE.REVOKED_CONTENT_CHANGED,
        actorKind: "admin",
        adminUid,
        extraAuditFields: {
          invalidationReason: "pilot_class_changed",
          previousPilotProductClass: rawPrevious,
          newPilotProductClass: pilotProductClass,
        },
      });
    }

    // The class is a bound input of both `decisionHash` and the approval
    // fingerprint, so every existing decision for this business is now stale.
    // Scheduling happens through the EXISTING mechanism — the business
    // compliance epoch that the recompute sweep already watches — not a new
    // one. Sibling products recompute to their own unchanged result, so this
    // is wasteful at worst and never wrong.
    bumpBusinessComplianceEpoch({ tx, db, businessId });

    // Immutable, server-written audit event, committed in the same
    // transaction as the state change: either both land or neither does.
    tx.create(db.collection(CLASSIFICATION_AUDIT_COLLECTION).doc(), {
      productId,
      businessId,
      marketplaceBusinessGenerationId: liveGeneration,
      previousPilotProductClass: rawPrevious,
      newPilotProductClass: pilotProductClass,
      classificationRevision,
      reason,
      adminUid,
      actorKind: "admin",
      unpublished: wasActive,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      changed: true,
      idempotent: false,
      previousClass,
      pilotProductClass,
      unpublished: wasActive,
      classificationRevision,
    };
  });

  // Identifier-free operational log.
  logger.info("pilot_product_classification", {
    changed: result.changed,
    unpublished: result.unpublished,
  });

  return result;
}

module.exports = {
  setPilotProductClassification,
  CLASSIFY_ALLOWED_FIELDS,
  CLASSIFICATION_AUDIT_COLLECTION,
  CLASSIFICATION_REASON_CODE,
};
