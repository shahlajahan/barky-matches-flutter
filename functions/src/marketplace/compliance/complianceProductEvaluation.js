"use strict";

// Marketplace Revision 30 §J Slice 5 — first-decision reachability.
//
// THE DEFECT THIS CLOSES. Before this module the ONLY production caller of
// `recomputeProductComplianceStatus` was the hourly sweep
// (`complianceProductRecomputeSweep.js`), whose candidate query is:
//
//     .where("isActive", "==", true)
//     .where("moderationStatus", "==", MODERATION_STATUS_APPROVED)
//
// That is correct for its own job — keeping ALREADY-LIVE products fresh
// against the current epoch and policy pointer — but it means a product that
// is intentionally `isActive: false, moderationStatus: 'pending_review'`
// never receives a first `productComplianceDecision`. Revision 30 §H makes an
// eligible decision a precondition of approval, and a product is pending
// exactly when it is being approved, so nothing could ever satisfy that gate.
// `productModeration.js` and `pilotProductApproval.js` both state in their own
// comments that they never call the recompute; they only read its output.
//
// WHAT THIS IS. One explicit, bounded, admin-only server operation that
// evaluates ONE product. It computes a decision and nothing else: it does not
// approve, activate, classify, make eligible, make effective, link into
// publication, or touch the product document at all. The engine is reused
// unchanged — this module adds a reachable entry point, not new logic.
//
// WHAT IS DELIBERATELY NOT DONE HERE. Revision 30 does not freeze an
// automatic first-evaluation trigger — it does not say that approving a
// document, creating a scope, or submitting a product must fan out into
// evaluating that business's products. Inventing such a fan-out would be
// inventing policy, and an unbounded one at that. Automatic invalidation and
// re-evaluation on expiry, revocation and product change are Revision 30 §J
// slice 6. This operation is the explicit backend path; the automatic ones
// remain open and are reported, not silently implied.

const { HttpsError } = require("firebase-functions/v2/https");

const { requireAdmin } = require("../../moderation/adminAuth");
const { recomputeProductComplianceStatus } = require("./complianceProductRecompute");

const EVALUATION_REQUEST_ALLOWED_FIELDS = Object.freeze(["businessId", "productId"]);

function assertNonEmptyId(value, field) {
  if (typeof value !== "string" || value.length === 0 || value.includes("/")) {
    throw new HttpsError("invalid-argument", `${field} is required`);
  }
  return value;
}

/// Evaluates one product's compliance decision.
///
/// Every authoritative input — the product, the business epoch, the active
/// policy, the scopes, the documents — is re-read by the engine inside its own
/// transaction. Nothing about the outcome is accepted from the caller: there
/// is no way to pass an effective status, a policy result, an evidence
/// sufficiency claim, a generation, a reviewer identity or a timestamp.
async function evaluateProductComplianceDecision({ db, auth, data, now, logger = console }) {
  await requireAdmin(db, { auth });

  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", "Request must be an object");
  }
  for (const key of Object.keys(data)) {
    if (!EVALUATION_REQUEST_ALLOWED_FIELDS.includes(key)) {
      // A caller trying to supply a decision, status, policy version or
      // generation is refused outright rather than having it ignored.
      throw new HttpsError("invalid-argument", "Request contains an unsupported field");
    }
  }
  const businessId = assertNonEmptyId(data.businessId, "businessId");
  const productId = assertNonEmptyId(data.productId, "productId");

  const result = await recomputeProductComplianceStatus({
    db,
    businessId,
    productId,
    ...(now ? { now } : {}),
  });

  // Identifier-free: no business, product, document, hash or policy version.
  logger.info("compliance_product_evaluation_completed", { actorRole: "admin" });

  // Only the resulting status is returned. The caller learns what the server
  // decided; it never gets to influence it, and no evidence detail leaks.
  return {
    productId,
    effectiveStatus:
      result && result.decision ? result.decision.effectiveStatus : null,
  };
}

module.exports = {
  evaluateProductComplianceDecision,
  EVALUATION_REQUEST_ALLOWED_FIELDS,
};
