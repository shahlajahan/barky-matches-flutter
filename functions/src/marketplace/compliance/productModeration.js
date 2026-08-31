"use strict";

// Petsupo Marketplace P1-A compliance foundation — Slice 4.4 (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §8/§9/§10.1/§11/§13.1/§16): `reviewProductModeration` — the sole
// *general-launch-path* mechanism by which a product's `moderationStatus`
// may become `'approved'`. Every client-SDK write attempting that
// transition is denied by `firestore.rules` (§9's approval-transition
// lock, deployed at Slice 4.9) — only this Admin-SDK callable may
// perform it. Revision 28 (§10.1 "Pilot Product Approval contract") adds
// a second, narrow, structurally-independent path to the same field —
// `approvePilotProduct`/`revokePilotProductApproval`/
// `unpublishPilotProductForRevision` (`pilotProductApproval.js`) — never
// routed through this function, never touching `PRODUCT_MODERATION_REVIEW_ENABLED`,
// and proven never to conflict with or reactivate anything this function
// governs.
//
// Calls `evaluateLiveProductEligibility` (§10.1) with its own transaction's
// `tx`, a fresh per-attempt `now`, and its own already-read `productSnapshot`
// — no non-transactional pre-read of any kind precedes `db.runTransaction`
// (Revision 10 correction 53). Never calls `recomputeProductComplianceStatus`
// itself — this module only re-verifies an already-computed decision, it
// never (re)computes one. Never trusts any client-supplied compliance
// status, decision data, evidence reference, policy version, epoch,
// revision, relationship snapshot, timestamp, or hash — only the request's
// own `businessId`/`productId` identify the target; everything else is read
// fresh from the server, inside the same transaction that commits the
// approval.
//
// Deployed exported, behind a disabled-by-default feature flag (§16/§17)
// — injected as a plain boolean `featureEnabled` parameter, exactly like
// `complianceUploadSessions.js`'s own `canaryAllowlist` injection, so
// this module never reads `defineString`/`process.env` directly (the
// caller — `functions/index.js` — resolves the deploy-time flag value
// and passes it in). Checked as the literal first line of
// `reviewProductModeration`, per §17 step 6's exact requirement.

const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");

const { requireAdmin } = require("../../moderation/adminAuth");
const {
  COMPLIANCE_REVIEW_EVENT_TARGET_TYPE,
  COMPLIANCE_REVIEW_EVENT_ACTION,
  COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE,
} = require("./complianceConstants");
const { evaluateLiveProductEligibility } = require("./complianceEligibilityEvaluator");

const PRODUCTS_COLLECTION = "businesses";
const REVIEW_EVENTS_COLLECTION = "complianceReviewEvents";

// `moderationStatus` is a pre-existing product field, predating P1-A —
// today only these two values are ever written anywhere in this
// codebase (`firestore.rules`, `lib/models/product.dart`): sellers may
// only ever submit `'pending_review'`; `'approved'` is the sole
// admin-reachable target this operation writes. No third value
// (`'rejected'` or similar) exists in the live schema — the plan itself
// never describes one either, only ever "the sole path by which
// moderationStatus may become 'approved'".
const PRODUCT_MODERATION_STATUS = Object.freeze({
  PENDING_REVIEW: "pending_review",
  APPROVED: "approved",
});

const REQUEST_ALLOWED_FIELDS = Object.freeze(["businessId", "productId"]);

const REASON = Object.freeze({
  FEATURE_DISABLED: "product_moderation_feature_disabled",
  BUSINESS_ID_MISMATCH: "product_moderation_business_id_mismatch",
  PRODUCT_NOT_FOUND: "product_moderation_product_not_found",
  INVALID_TRANSITION: "product_moderation_invalid_transition",
});

function assertNonEmptyString(value, fieldName) {
  if (typeof value !== "string" || value.length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required`);
  }
  return value;
}

function productRef(db, businessId, productId) {
  return db.collection(PRODUCTS_COLLECTION).doc(businessId).collection("products").doc(productId);
}

// Reuses the existing, already-shipped complianceReviewEvents schema/
// enums exactly (`targetType: 'product'`, `action: 'approved'`, both
// already reserved by the shared constant, `actorRole: 'admin'`) — no
// new event vocabulary, mirroring complianceProductRecompute.js's own
// truncation-event convention.
function buildApprovalEventPayload({ productId, businessId, adminUid }) {
  return {
    targetType: COMPLIANCE_REVIEW_EVENT_TARGET_TYPE.PRODUCT,
    targetId: productId,
    businessId,
    action: COMPLIANCE_REVIEW_EVENT_ACTION.APPROVED,
    actorUid: adminUid,
    actorRole: COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE.ADMIN,
    occurredAt: admin.firestore.FieldValue.serverTimestamp(),
    notes: null,
  };
}

async function reviewProductModeration({ db, auth, data, nowFactory = () => new Date(), featureEnabled }) {
  // Checked first, literally — §17 step 6. A disabled flag fails closed
  // before any auth/read/write, regardless of caller identity.
  if (featureEnabled !== true) {
    throw new HttpsError("failed-precondition", "This feature is not yet enabled.");
  }

  const adminUid = await requireAdmin(db, { auth });

  const payload = data || {};
  if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
    throw new HttpsError("invalid-argument", "Request contains an unrecognized field");
  }
  if (!Object.keys(payload).every((key) => REQUEST_ALLOWED_FIELDS.includes(key))) {
    throw new HttpsError("invalid-argument", "Request contains an unrecognized field");
  }
  const businessId = assertNonEmptyString(payload.businessId, "businessId");
  const productId = assertNonEmptyString(payload.productId, "productId");

  // Revision 10 correction 53 (§10.1) — the exact 14-step approval
  // transaction sequence. No non-transactional product pre-read of any
  // kind precedes this: idempotency routing, error routing, and the
  // live eligibility re-verification all happen exclusively inside this
  // one transaction's own reads, so nothing that authorizes an approval
  // can ever be satisfied by a value read outside its own read set.
  const result = await db.runTransaction(async (tx) => {
    // A fresh `now` every attempt — a Firestore retry re-runs this whole
    // callback body, and each re-run gets its own, later `now`; never a
    // value captured before `runTransaction` opened (§10.1 "Per-attempt
    // clock rule").
    const now = nowFactory();

    const ref = productRef(db, businessId, productId);
    const productSnapshot = await tx.get(ref);
    if (!productSnapshot.exists) {
      throw new HttpsError("not-found", "Product not found");
    }
    if (productSnapshot.ref.path !== ref.path) {
      throw new HttpsError("failed-precondition", "Product reference mismatch");
    }
    const product = productSnapshot.data();
    if (!product || typeof product !== "object" || Array.isArray(product)) {
      throw new HttpsError("failed-precondition", "Product data is malformed");
    }
    if (product.businessId !== businessId) {
      throw new HttpsError("failed-precondition", "Product does not belong to the specified business");
    }

    // --- Idempotent replay: already in the target state. A pure
    //     stored-moderation-state read — never a live-eligibility claim
    //     (§10.1 "Already-approved idempotent replay"). Calls no
    //     evaluator, performs no write, creates no event. ---
    if (product.moderationStatus === PRODUCT_MODERATION_STATUS.APPROVED) {
      return { moderationStatus: PRODUCT_MODERATION_STATUS.APPROVED, idempotent: true };
    }

    // --- The only legal starting state for this transition. ---
    if (product.moderationStatus !== PRODUCT_MODERATION_STATUS.PENDING_REVIEW) {
      throw new HttpsError(
        "failed-precondition",
        `Cannot approve a product in moderation status "${product.moderationStatus}"`
      );
    }

    // --- Live eligibility re-verification, inside this same
    //     transaction, using this same `tx`, this same per-attempt
    //     `now`, and the product snapshot already read above (no second
    //     `tx.get()` on the same document path). Never trusts any
    //     cached/client-supplied compliance field. Never calls
    //     recomputeProductComplianceStatus; only re-verifies the
    //     already-computed decision against fresh live state (§10.1). ---
    const eligibility = await evaluateLiveProductEligibility({
      db,
      businessId,
      productId,
      now,
      tx,
      productSnapshot,
    });
    const reason =
      eligibility && typeof eligibility === "object" ? eligibility.reason : undefined;
    if (!eligibility || typeof eligibility !== "object" || eligibility.eligible !== true) {
      throw new HttpsError("failed-precondition", `Product is not eligible for approval: ${reason}`);
    }

    // --- Write: the sole moderationStatus mutation, plus its audit
    //     event, atomically. No other product field is touched — never
    //     productInputRevision, sellerRelationship, isActive, or any of
    //     the five server-owned compliance fields. ---
    tx.update(ref, {
      moderationStatus: PRODUCT_MODERATION_STATUS.APPROVED,
    });
    const eventRef = db.collection(REVIEW_EVENTS_COLLECTION).doc();
    tx.create(eventRef, buildApprovalEventPayload({ productId, businessId, adminUid }));

    return { moderationStatus: PRODUCT_MODERATION_STATUS.APPROVED, idempotent: false };
  });

  return { productId, ...result };
}

module.exports = {
  reviewProductModeration,
  PRODUCT_MODERATION_STATUS,
  REQUEST_ALLOWED_FIELDS,
  REASON,
};
