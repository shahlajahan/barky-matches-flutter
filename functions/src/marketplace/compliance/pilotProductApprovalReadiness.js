"use strict";

// Marketplace Revision 36 — the server-authoritative Admin approval
// readiness handshake.
//
// THE DEFECT THIS CLOSES. Slice 6 replaced `approvePilotProduct`'s content
// fingerprint with the full approval fingerprint (content PLUS product
// identity, generation, and the effective compliance decision's hash,
// policy, revision, status, expiry and evidence digest); Slice 7A added
// `pilotProductClass` as its eleventh input. The Admin page was never
// updated and still sent `computePilotProductContentFingerprint(data)` — a
// hash of a DIFFERENT object shape, so the equality at the end of
// `approvePilotProduct` could never hold and every real Approve tap failed
// with `stale-content`.
//
// The client cannot simply be taught to compute the right value: the
// authoritative inputs live in `productComplianceDecisions`, and
// reconstructing an approval fingerprint on the client would make an
// integrity token forgeable by whoever holds the inputs. So the server
// computes it and hands it back.
//
// WHAT THIS IS NOT. The returned fingerprint is an optimistic-concurrency
// token, never publication authority. This module writes nothing, records no
// audit event, approves nothing and activates nothing; a `ready: true`
// response is a statement about a moment that has already passed by the time
// the admin reads it. `approvePilotProduct` re-reads and recomputes the
// entire authoritative state inside its own transaction and compares, so any
// change to content, class, generation, decision, evidence, policy or expiry
// between readiness and approval still fails closed as stale.

const {
  requireAdmin,
} = require("../../moderation/adminAuth");
const { HttpsError } = require("firebase-functions/v2/https");

const {
  assertValidRequestShape,
  assertNonEmptyString,
  businessRef,
  productRef,
  decisionRef,
  isValidGenerationId,
  isCurrentlyActivePilotApproval,
  assertUsableComplianceDecision,
  computeApprovalFingerprint,
  readCounter,
  PILOT_PRODUCT_ACTIVE_LIMIT,
} = require("./pilotProductApproval");
const {
  evaluateLiveProductEligibility,
  REASON: ELIGIBILITY_REASON,
} = require("./complianceEligibilityEvaluator");
const { isValidPilotProductClass } = require("./complianceConstants");

const READINESS_ALLOWED_FIELDS = Object.freeze(["businessId", "productId"]);

// Stable, machine-readable blocking reasons. The Admin UI branches on these
// and nothing else; message text is never parsed.
const READINESS_REASON = Object.freeze({
  MALFORMED_REQUEST: "readiness-malformed-request",
  PRODUCT_NOT_FOUND: "readiness-product-not-found",
  BUSINESS_NOT_FOUND: "readiness-business-not-found",
  PRODUCT_BUSINESS_MISMATCH: "readiness-product-business-mismatch",
  GENERATION_NOT_INITIALIZED: "readiness-generation-not-initialized",
  GENERATION_MISMATCH: "readiness-generation-mismatch",
  CLASS_MISSING: "readiness-class-missing",
  CLASS_UNSUPPORTED: "readiness-class-unsupported",
  DECISION_MISSING: "readiness-decision-missing",
  DECISION_NOT_ELIGIBLE: "readiness-decision-not-eligible",
  DECISION_EXPIRED: "readiness-decision-expired",
  DECISION_PRODUCT_MISMATCH: "readiness-decision-product-mismatch",
  EVIDENCE_STALE: "readiness-evidence-stale",
  POLICY_MISMATCH: "readiness-policy-mismatch",
  MALFORMED_STATE: "readiness-malformed-state",
  SELLER_NOT_ACTIVE: "readiness-seller-not-active",
  INVALID_TRANSITION: "readiness-invalid-transition",
  ALREADY_APPROVED: "readiness-already-approved",
  LIMIT_EXCEEDED: "readiness-limit-exceeded",
});

// `approvePilotProduct`'s own `assertUsableComplianceDecision` reason codes,
// mapped onto this module's vocabulary. Kept as an explicit, exhaustive table
// rather than a string transform so that adding a code there without deciding
// its meaning here degrades to MALFORMED_STATE instead of silently inventing
// a reason.
const APPROVAL_DECISION_REASON_MAP = Object.freeze({
  "compliance-decision-missing": READINESS_REASON.DECISION_MISSING,
  "compliance-decision-malformed": READINESS_REASON.MALFORMED_STATE,
  "compliance-decision-business-mismatch": READINESS_REASON.DECISION_PRODUCT_MISMATCH,
  "compliance-decision-not-eligible": READINESS_REASON.DECISION_NOT_ELIGIBLE,
  "compliance-decision-no-evidence": READINESS_REASON.EVIDENCE_STALE,
  "compliance-decision-expired": READINESS_REASON.DECISION_EXPIRED,
  "compliance-decision-generation-unprovable": READINESS_REASON.GENERATION_MISMATCH,
});

// The canonical evaluator's reasons, mapped the same way. This evaluator is
// the SAME predicate `reviewProductModeration` already gates on, so readiness
// can never be more permissive than the rest of the system.
const ELIGIBILITY_REASON_MAP = Object.freeze({
  [ELIGIBILITY_REASON.PRODUCT_NOT_FOUND]: READINESS_REASON.PRODUCT_NOT_FOUND,
  [ELIGIBILITY_REASON.PRODUCT_BUSINESS_ID_MISMATCH]: READINESS_REASON.PRODUCT_BUSINESS_MISMATCH,
  [ELIGIBILITY_REASON.SELLER_RELATIONSHIP_INVALID]: READINESS_REASON.MALFORMED_STATE,
  [ELIGIBILITY_REASON.DECISION_NOT_FOUND]: READINESS_REASON.DECISION_MISSING,
  [ELIGIBILITY_REASON.DECISION_MALFORMED]: READINESS_REASON.MALFORMED_STATE,
  [ELIGIBILITY_REASON.DECISION_STATUS_INELIGIBLE]: READINESS_REASON.DECISION_NOT_ELIGIBLE,
  [ELIGIBILITY_REASON.POLICY_VERSION_MISMATCH]: READINESS_REASON.POLICY_MISMATCH,
  [ELIGIBILITY_REASON.EVIDENCE_REVISION_MISMATCH]: READINESS_REASON.EVIDENCE_STALE,
  [ELIGIBILITY_REASON.PRODUCT_INPUT_REVISION_MISMATCH]: READINESS_REASON.EVIDENCE_STALE,
  [ELIGIBILITY_REASON.SELLER_RELATIONSHIP_SNAPSHOT_MISMATCH]: READINESS_REASON.EVIDENCE_STALE,
  [ELIGIBILITY_REASON.PILOT_PRODUCT_CLASS_SNAPSHOT_MISMATCH]: READINESS_REASON.EVIDENCE_STALE,
  [ELIGIBILITY_REASON.VALID_UNTIL_MISSING_OR_EXPIRED]: READINESS_REASON.DECISION_EXPIRED,
  [ELIGIBILITY_REASON.ACTIVE_EVIDENCE_REFS_OUT_OF_BOUND]: READINESS_REASON.MALFORMED_STATE,
  [ELIGIBILITY_REASON.DECISION_HASH_MISMATCH]: READINESS_REASON.EVIDENCE_STALE,
});

function blocked(reasonCode, extra = {}) {
  return { ready: false, reasonCode, approvalFingerprint: null, ...extra };
}

function millisOrNull(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  return null;
}

/// Returns whether this product can be approved right now, and — only when it
/// can — the exact approval fingerprint `approvePilotProduct` will expect.
///
/// Read-only by construction: the transaction below performs `tx.get` calls
/// and never a `set`, `update`, `create` or `delete`. Blocking outcomes are
/// returned as data, not thrown, so the Admin screen can render a reason;
/// only authorization and a malformed request throw.
async function getPilotProductApprovalReadiness({ db, auth, data, now = Date.now, logger = console }) {
  // Admin first: nothing about any product — not even whether it exists — is
  // disclosed before authorization. Same posture as
  // `getComplianceDocumentEvidence`.
  await requireAdmin(db, { auth });

  let payload;
  let businessId;
  let productId;
  try {
    payload = assertValidRequestShape(data, READINESS_ALLOWED_FIELDS);
    businessId = assertNonEmptyString(payload.businessId, "businessId");
    productId = assertNonEmptyString(payload.productId, "productId");
  } catch (_error) {
    throw new HttpsError("invalid-argument", "Request is malformed", {
      reasonCode: READINESS_REASON.MALFORMED_REQUEST,
    });
  }

  const nowMs = typeof now === "function" ? now() : now;

  const result = await db.runTransaction(async (tx) => {
    // One consistent read set across business, product, decision, policy and
    // epoch, so the fingerprint handed back is internally coherent rather
    // than stitched from documents read at different instants.
    const bizSnap = await tx.get(businessRef(db, businessId));
    if (!bizSnap.exists) return blocked(READINESS_REASON.BUSINESS_NOT_FOUND);
    const businessData = bizSnap.data() || {};

    const prodSnap = await tx.get(productRef(db, businessId, productId));
    if (!prodSnap.exists) return blocked(READINESS_REASON.PRODUCT_NOT_FOUND);
    const product = prodSnap.data() || {};
    if (product.businessId !== businessId) {
      return blocked(READINESS_REASON.PRODUCT_BUSINESS_MISMATCH);
    }

    // Everything below is reported through `summary`, which carries only
    // admin-facing scalars — never a document path, a URL, an owner uid or
    // raw evidence content.
    const storedClass = product.pilotProductClass;
    const currentClass = isValidPilotProductClass(storedClass) ? storedClass : null;

    const decisionSnap = await tx.get(decisionRef(db, productId));
    const decision = decisionSnap.exists ? decisionSnap.data() : null;

    const summary = {
      pilotProductClass: currentClass,
      decisionStatus:
        decision && typeof decision.effectiveStatus === "string"
          ? decision.effectiveStatus
          : null,
      decisionValidUntilMillis: decision ? millisOrNull(decision.validUntil) : null,
      activeEvidenceCount:
        decision && Array.isArray(decision.activeEvidenceRefs)
          ? decision.activeEvidenceRefs.length
          : 0,
    };

    // --- The approval preconditions, in `approvePilotProduct`'s own order,
    //     evaluated against the same canonical documents. ---

    const activation = businessData.marketplaceSellerActivation;
    const sellerActive = Boolean(
      activation &&
        typeof activation === "object" &&
        !Array.isArray(activation) &&
        activation.active === true
    );
    if (!sellerActive) return blocked(READINESS_REASON.SELLER_NOT_ACTIVE, summary);

    if (isCurrentlyActivePilotApproval(product)) {
      return blocked(READINESS_REASON.ALREADY_APPROVED, summary);
    }

    // An absent class and a present-but-unrecognised one are genuinely
    // different operator situations — one needs classifying, the other needs
    // correcting — so they are never collapsed into one reason.
    if (storedClass === undefined || storedClass === null) {
      return blocked(READINESS_REASON.CLASS_MISSING, summary);
    }
    if (currentClass === null) {
      return blocked(READINESS_REASON.CLASS_UNSUPPORTED, summary);
    }

    // Reused verbatim from the approval path — not a reimplementation. It
    // throws; readiness converts that into a blocking reason.
    try {
      assertUsableComplianceDecision({ decision, businessId, product, now: nowMs });
    } catch (error) {
      const code = error && error.details ? error.details.reasonCode : null;
      return blocked(
        APPROVAL_DECISION_REASON_MAP[code] || READINESS_REASON.MALFORMED_STATE,
        summary
      );
    }

    if (product.moderationStatus !== "pending_review") {
      return blocked(READINESS_REASON.INVALID_TRANSITION, summary);
    }

    const counter = readCounter(businessData);
    if (counter === null) return blocked(READINESS_REASON.MALFORMED_STATE, summary);
    if (counter >= PILOT_PRODUCT_ACTIVE_LIMIT) {
      return blocked(READINESS_REASON.LIMIT_EXCEEDED, summary);
    }

    if (!isValidGenerationId(businessData.marketplaceBusinessGenerationId)) {
      return blocked(READINESS_REASON.GENERATION_NOT_INITIALIZED, summary);
    }
    if (product.marketplaceBusinessGenerationId !== businessData.marketplaceBusinessGenerationId) {
      return blocked(READINESS_REASON.GENERATION_MISMATCH, summary);
    }

    // The canonical live-eligibility predicate, joining the SAME transaction
    // read set. It is strictly stronger than the approval gate above — it
    // additionally re-derives the decision hash and re-checks the active
    // policy pointer, the product input revision and both snapshot fields.
    // Readiness is therefore never more permissive than approval; where the
    // two differ it errs toward blocked, which is the safe direction, and it
    // matches what `reviewProductModeration` already enforces.
    let eligibility;
    try {
      eligibility = await evaluateLiveProductEligibility({
        db,
        businessId,
        productId,
        now: new Date(nowMs),
        tx,
      });
    } catch (_error) {
      // A thrown evaluator is a broken authoritative-state contract, never a
      // reason to proceed.
      return blocked(READINESS_REASON.MALFORMED_STATE, summary);
    }
    if (!eligibility.eligible) {
      return blocked(
        ELIGIBILITY_REASON_MAP[eligibility.reason] || READINESS_REASON.MALFORMED_STATE,
        summary
      );
    }

    // Every gate passed. The fingerprint is computed from the canonical
    // product and decision just read — the identical function, on the
    // identical inputs, that `approvePilotProduct` will recompute inside its
    // own transaction.
    return {
      ready: true,
      reasonCode: null,
      approvalFingerprint: computeApprovalFingerprint(product, decision, productId),
      ...summary,
    };
  });

  // Identifier-free operational log: never the fingerprint, never the ids.
  logger.info("pilot_product_approval_readiness", {
    ready: result.ready,
    reasonCode: result.reasonCode || null,
  });

  return {
    businessId,
    productId,
    ready: result.ready === true,
    reasonCode: result.reasonCode || null,
    approvalFingerprint: result.approvalFingerprint || null,
    pilotProductClass: result.pilotProductClass || null,
    decisionStatus: result.decisionStatus || null,
    decisionValidUntilMillis:
      typeof result.decisionValidUntilMillis === "number"
        ? result.decisionValidUntilMillis
        : null,
    activeEvidenceCount:
      typeof result.activeEvidenceCount === "number" ? result.activeEvidenceCount : 0,
  };
}

module.exports = {
  getPilotProductApprovalReadiness,
  READINESS_ALLOWED_FIELDS,
  READINESS_REASON,
};
