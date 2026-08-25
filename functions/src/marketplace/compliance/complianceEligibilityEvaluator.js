"use strict";

// Petsupo Marketplace P1-A compliance foundation — Slice 4.3 (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §8/§10.1/§13.1): `evaluateLiveProductEligibility` — the single
// authoritative freshness/eligibility check shared by every path that
// admits or excludes a product (listing, detail, add-to-cart,
// reservation, checkout, and `reviewProductModeration`'s own approval
// check, §8/§10.1). Not wired into functions/index.js — no onCall/HTTP/
// trigger entry point exists for this module; it is an internal shared
// module only, exactly like the plan's own "not independently exported"
// note (§8).
//
// Every call independently reads the product, the decision, the policy
// pointer/version, and the business epoch FRESH — no TTL cache, no
// module-level mutable state, no fallback to a previously resolved
// value (§10.1, Revision 4 correction 27). Eligibility requires
// EQUALITY between the stored decision and freshly-read live state,
// never a same-document cached field trusted alone. Any mismatch
// excludes the candidate — false exclusion is the safe, accepted
// failure direction; false inclusion is impossible by construction.
//
// Never reads `productEvidenceLinks` (performance/reconciliation index
// only, §4/§10.1) and never queries `complianceDocumentScopes` — this
// module re-verifies only the already-computed decision against fresh
// scalar/pointer state, it never re-runs matching.

const {
  PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS,
} = require("./complianceConstants");
const {
  isValidSellerRelationship,
  isProductComplianceEligibleStatus,
  hasOnlyAllowedProductComplianceDecisionFields,
  isWithinActiveEvidenceRefsBound,
  isWithinRequiredEvidenceSlotsBound,
} = require("./complianceValidators");
const { resolveActivePolicy } = require("./compliancePolicyRegistryOperations");
const { computeDecisionHash } = require("./complianceProductRecompute");

const PRODUCTS_COLLECTION = "businesses";
const EPOCHS_COLLECTION = "businessComplianceEpochs";
const DECISIONS_COLLECTION = "productComplianceDecisions";

const REASON = Object.freeze({
  PRODUCT_NOT_FOUND: "eligibility_product_not_found",
  PRODUCT_BUSINESS_ID_MISMATCH: "eligibility_product_business_id_mismatch",
  SELLER_RELATIONSHIP_INVALID: "eligibility_seller_relationship_invalid",
  DECISION_NOT_FOUND: "eligibility_decision_not_found",
  DECISION_MALFORMED: "eligibility_decision_malformed",
  DECISION_STATUS_INELIGIBLE: "eligibility_decision_status_ineligible",
  POLICY_VERSION_MISMATCH: "eligibility_policy_version_mismatch",
  EVIDENCE_REVISION_MISMATCH: "eligibility_evidence_revision_mismatch",
  PRODUCT_INPUT_REVISION_MISMATCH: "eligibility_product_input_revision_mismatch",
  SELLER_RELATIONSHIP_SNAPSHOT_MISMATCH: "eligibility_seller_relationship_snapshot_mismatch",
  VALID_UNTIL_MISSING_OR_EXPIRED: "eligibility_valid_until_missing_or_expired",
  ACTIVE_EVIDENCE_REFS_OUT_OF_BOUND: "eligibility_active_evidence_refs_out_of_bound",
  DECISION_HASH_MISMATCH: "eligibility_decision_hash_mismatch",
});

function ineligible(reason) {
  return { eligible: false, reason };
}

function productRef(db, businessId, productId) {
  return db.collection(PRODUCTS_COLLECTION).doc(businessId).collection("products").doc(productId);
}

function epochRef(db, businessId) {
  return db.collection(EPOCHS_COLLECTION).doc(businessId);
}

function decisionRef(db, productId) {
  return db.collection(DECISIONS_COLLECTION).doc(productId);
}

function toMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (typeof value === "number") return value;
  return NaN;
}

function normalizedProductInputRevision(product) {
  return typeof product.productInputRevision === "number" ? product.productInputRevision : 0;
}

async function evaluateLiveProductEligibility({ db, businessId, productId, now = new Date() }) {
  if (typeof businessId !== "string" || businessId.length === 0) {
    throw new Error("evaluateLiveProductEligibility: businessId is required");
  }
  if (typeof productId !== "string" || productId.length === 0) {
    throw new Error("evaluateLiveProductEligibility: productId is required");
  }
  const nowMs = now instanceof Date ? now.getTime() : Number(now);

  // Fresh product read.
  const productSnap = await productRef(db, businessId, productId).get();
  if (!productSnap.exists) return ineligible(REASON.PRODUCT_NOT_FOUND);
  const product = productSnap.data();
  if (product.businessId !== businessId) return ineligible(REASON.PRODUCT_BUSINESS_ID_MISMATCH);
  if (!isValidSellerRelationship(product.sellerRelationship)) {
    return ineligible(REASON.SELLER_RELATIONSHIP_INVALID);
  }

  // Fresh decision read.
  const decisionSnap = await decisionRef(db, productId).get();
  if (!decisionSnap.exists) return ineligible(REASON.DECISION_NOT_FOUND);
  const decision = decisionSnap.data();
  if (
    !decision ||
    typeof decision !== "object" ||
    !hasOnlyAllowedProductComplianceDecisionFields(decision) ||
    typeof decision.businessId !== "string" ||
    typeof decision.policyVersion !== "string" ||
    typeof decision.evidenceRevision !== "number" ||
    typeof decision.productInputRevisionSnapshot !== "number" ||
    // Revision 9 correction 51 — sellerRelationshipSnapshot is
    // structurally required on every decision, independent of
    // productInputRevisionSnapshot. A decision written before this field
    // existed (`undefined`), or carrying any non-enum value (including
    // the writer's own `null` sentinel for an invalid live relationship
    // at compute time), is malformed and fails closed here — not a
    // distinct, more lenient failure mode than any other required field.
    typeof decision.sellerRelationshipSnapshot !== "string" ||
    !isValidSellerRelationship(decision.sellerRelationshipSnapshot) ||
    !Array.isArray(decision.requiredEvidenceSlots) ||
    !isWithinRequiredEvidenceSlotsBound(decision.requiredEvidenceSlots) ||
    !Array.isArray(decision.satisfiedEvidenceSlots) ||
    !Array.isArray(decision.activeEvidenceRefs) ||
    !isWithinActiveEvidenceRefsBound(decision.activeEvidenceRefs) ||
    typeof decision.effectiveStatus !== "string" ||
    typeof decision.decisionHash !== "string"
  ) {
    return ineligible(REASON.DECISION_MALFORMED);
  }
  if (decision.businessId !== businessId) return ineligible(REASON.DECISION_MALFORMED);
  if (decision.activeEvidenceRefs.length > PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS) {
    return ineligible(REASON.ACTIVE_EVIDENCE_REFS_OUT_OF_BOUND);
  }

  if (!isProductComplianceEligibleStatus(decision.effectiveStatus)) {
    return ineligible(REASON.DECISION_STATUS_INELIGIBLE);
  }

  // Fresh policy pointer/version resolution — never cached, matching
  // resolveActivePolicy's own designed usage exactly. A throw here
  // (no active policy) fails this evaluation closed.
  let activeVersionId;
  try {
    ({ activeVersionId } = await resolveActivePolicy({ db, now }));
  } catch (err) {
    return ineligible(REASON.POLICY_VERSION_MISMATCH);
  }
  if (decision.policyVersion !== activeVersionId) return ineligible(REASON.POLICY_VERSION_MISMATCH);

  // Fresh business epoch read.
  const epochSnap = await epochRef(db, businessId).get();
  const epoch = epochSnap.exists && typeof epochSnap.data().epoch === "number" ? epochSnap.data().epoch : 0;
  if (decision.evidenceRevision !== epoch) return ineligible(REASON.EVIDENCE_REVISION_MISMATCH);

  // productInputRevision equality — catches every matching-field
  // change, including a sellerRelationship change, since Rules require
  // any such change to bump productInputRevision (§9's matching-field
  // set, Revision 7 correction 43).
  if (decision.productInputRevisionSnapshot !== normalizedProductInputRevision(product)) {
    return ineligible(REASON.PRODUCT_INPUT_REVISION_MISMATCH);
  }

  // sellerRelationshipSnapshot equality — independent of, not subsumed
  // by, the productInputRevisionSnapshot check above (Revision 9
  // correction 51, §10.1). Under the already-committed dormant Rules
  // (row A), a product may legally transition sellerRelationship: X -> Y
  // while productInputRevision remains absent on both sides — both
  // normalize to 0 regardless of the relationship change, so the
  // revision check alone cannot detect this. This comparison uses only
  // the live `product.sellerRelationship` already read above (the same
  // field the SELLER_RELATIONSHIP_INVALID check already validated) — no
  // extra read, and does not rely on productInputRevisionSnapshot at
  // all. This does NOT forbid eligibility while productInputRevision
  // itself remains absent — only additionally requires that the
  // relationship the decision was computed under still match live state.
  if (decision.sellerRelationshipSnapshot !== product.sellerRelationship) {
    return ineligible(REASON.SELLER_RELATIONSHIP_SNAPSHOT_MISMATCH);
  }

  // Strict validUntil > now.
  const validUntilMs = toMillis(decision.validUntil);
  if (!Number.isFinite(validUntilMs) || !(validUntilMs > nowMs)) {
    return ineligible(REASON.VALID_UNTIL_MISSING_OR_EXPIRED);
  }

  // Final consistency signal: recompute the decision's own content hash
  // and compare.
  const recomputedHash = computeDecisionHash({
    businessId: decision.businessId,
    policyVersion: decision.policyVersion,
    evidenceRevision: decision.evidenceRevision,
    productInputRevisionSnapshot: decision.productInputRevisionSnapshot,
    sellerRelationshipSnapshot: decision.sellerRelationshipSnapshot,
    requiredEvidenceSlots: decision.requiredEvidenceSlots,
    satisfiedEvidenceSlots: decision.satisfiedEvidenceSlots,
    activeEvidenceRefs: decision.activeEvidenceRefs,
    validUntil: decision.validUntil,
    effectiveStatus: decision.effectiveStatus,
  });
  if (recomputedHash !== decision.decisionHash) return ineligible(REASON.DECISION_HASH_MISMATCH);

  return { eligible: true, reason: null };
}

module.exports = {
  evaluateLiveProductEligibility,
  REASON,
};
