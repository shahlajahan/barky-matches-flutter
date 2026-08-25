"use strict";

// Petsupo Marketplace P1-A compliance foundation — Slice 4.3 (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §4/§8/§10/§13.1, corrected per Revision 9 corrections 49-52): the
// single system writer of `productComplianceDecisions/{productId}` and
// `productEvidenceLinks`. System-only (§6 trust boundaries) — never
// directly invocable by a seller or admin request; not wired into
// functions/index.js, no onCall/HTTP/trigger entry point exists here.
//
// Exact ordering (§10 "Prior-link cleanup and transaction ordering",
// extended Revision 9 correction 50):
//   1. Resolve the active policy fresh, via `resolveActivePolicy`
//      (Slice 4.1, unmodified) — non-transactional, matching that
//      function's own designed usage pattern. If this throws (no active
//      policy exists at all — a `resolveActivePolicy`-level failure,
//      distinct from "this product's relationship has no configured
//      branch"), the whole recompute throws too and writes nothing —
//      "fails closed... no product can be found eligible" (§10) is
//      satisfied because a product left with no fresh decision is
//      already excluded by the live evaluator's own equality checks.
//   2. Everything else — product, business epoch, all seven matching
//      lookups, source-document verification, and the prior decision —
//      is read inside ONE transaction, via `tx.get()`, before any write.
//   3. Prior links are deleted by ID, re-derived from the prior
//      decision's own `activeEvidenceRefs` — `productEvidenceLinks` is
//      never queried to discover them.
//   4. The decision document is fully replaced (`tx.set()`, not merge).
//   5. Up to 10 new links are written, IDs computed by the same
//      deterministic formula.
//   6. Only if the matching engine reports truncation (Revision 9
//      correction 50): exactly one `complianceReviewEvents` document is
//      created — the transaction's last write, after every read and
//      every other write.

const admin = require("firebase-admin");
const crypto = require("node:crypto");
const { HttpsError } = require("firebase-functions/v2/https");

const {
  PRODUCT_COMPLIANCE_EFFECTIVE_STATUS,
  PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS,
  COMPLIANCE_REVIEW_EVENT_TARGET_TYPE,
  COMPLIANCE_REVIEW_EVENT_ACTION,
  COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE,
} = require("./complianceConstants");
const { isValidSellerRelationship } = require("./complianceValidators");
const { resolveActivePolicy } = require("./compliancePolicyRegistryOperations");
const { runComplianceMatching, deriveEvidenceLinkId, createCounters } = require("./complianceMatching");

const PRODUCTS_COLLECTION = "businesses";
const EPOCHS_COLLECTION = "businessComplianceEpochs";
const DECISIONS_COLLECTION = "productComplianceDecisions";
const LINKS_COLLECTION = "productEvidenceLinks";
const REVIEW_EVENTS_COLLECTION = "complianceReviewEvents";

function failClosed(reason) {
  throw new HttpsError("failed-precondition", reason);
}

function unavailable(reason) {
  throw new HttpsError("unavailable", reason);
}

const REASON = Object.freeze({
  PRODUCT_NOT_FOUND: "recompute_product_not_found",
  PRODUCT_READ_FAILED: "recompute_product_read_failed",
  PRODUCT_BUSINESS_ID_MISMATCH: "recompute_product_business_id_mismatch",
  EPOCH_READ_FAILED: "recompute_epoch_read_failed",
  PRIOR_DECISION_READ_FAILED: "recompute_prior_decision_read_failed",
});

function productRef(db, businessId, productId) {
  return db.collection(PRODUCTS_COLLECTION).doc(businessId).collection("products").doc(productId);
}

function epochRef(db, businessId) {
  return db.collection(EPOCHS_COLLECTION).doc(businessId);
}

function decisionRef(db, productId) {
  return db.collection(DECISIONS_COLLECTION).doc(productId);
}

function linkRef(db, linkId) {
  return db.collection(LINKS_COLLECTION).doc(linkId);
}

function toMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (typeof value === "number") return value;
  return NaN;
}

// Earliest expiresAt among activeEvidenceRefs — the decision's own
// effective validUntil (§4). Null when there are no refs at all.
function computeEffectiveValidUntil(activeEvidenceRefs) {
  if (!activeEvidenceRefs || activeEvidenceRefs.length === 0) return null;
  let earliest = null;
  let earliestMs = Infinity;
  for (const ref of activeEvidenceRefs) {
    const ms = toMillis(ref.expiresAt);
    if (Number.isFinite(ms) && ms < earliestMs) {
      earliestMs = ms;
      earliest = ref.expiresAt;
    }
  }
  return earliest;
}

function normalizedProductInputRevisionSnapshot(product) {
  return typeof product.productInputRevision === "number" ? product.productInputRevision : 0;
}

// Revision 9 correction 51 (§4/§10.1) — the exact live product
// sellerRelationship used for policy selection at compute time,
// snapshotted independently of productInputRevisionSnapshot. When the
// live value is not a valid SELLER_RELATIONSHIP enum member (missing or
// malformed — the decision is already policy_unresolved in that case),
// `null` is written rather than the raw invalid value: this keeps the
// stored field always either a valid enum string or exactly `null`,
// never `undefined` (Firestore-unwritable) and never a garbage value a
// reader would have to separately sanitize. The evaluator's own
// structural check treats both "missing" (a decision written before
// this field existed) and this `null` case identically — fail closed.
function computeSellerRelationshipSnapshot(product) {
  return isValidSellerRelationship(product.sellerRelationship) ? product.sellerRelationship : null;
}

function determineEffectiveStatus({ policyUnresolved, allRequiredSlotsSatisfied }) {
  if (policyUnresolved) return PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.POLICY_UNRESOLVED;
  if (allRequiredSlotsSatisfied) return PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.VERIFIED_VALID;
  return PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.EVIDENCE_MISSING;
}

// ---------------------------------------------------------------------
// decisionHash canonicalization — frozen exactly (master plan §4,
// Revision 9 correction 52). Recursive at every nesting level: arrays
// preserve their existing, already-deterministic order (never re-
// sorted); plain objects have their keys sorted lexicographically at
// EVERY level, not only the top level (the prior implementation's own
// latent gap). `undefined` is forbidden anywhere in the structure,
// including nested — every included top-level field must be present
// and non-undefined before hashing (a genuinely absent optional value,
// e.g. `validUntil` with no evidence, is `null`, never a dropped key).
// Firestore Timestamp -> integer milliseconds via `.toMillis()`.
// Functions, symbols, DocumentReferences, and any other class instance
// besides the accepted Timestamp-like shape are rejected outright.
// ---------------------------------------------------------------------

// Exactly these ten fields, no others (§4 "decisionHash canonicalization
// contract"). `computedAt`/`decisionHash` themselves are excluded — a
// write-time side value and the self-referential digest, respectively.
const DECISION_HASH_INCLUDED_FIELDS = Object.freeze([
  "businessId",
  "policyVersion",
  "evidenceRevision",
  "productInputRevisionSnapshot",
  "sellerRelationshipSnapshot",
  "requiredEvidenceSlots",
  "satisfiedEvidenceSlots",
  "activeEvidenceRefs",
  "validUntil",
  "effectiveStatus",
]);

// Deliberately stricter than a bare `typeof value === "object"` check —
// a class instance (e.g. a Firestore DocumentReference) has
// `typeof === "object"` too, but its prototype is neither `null` nor
// `Object.prototype`, so it is correctly rejected by canonicalizeValue
// below rather than silently treated as a plain map.
function isPlainObject(value) {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return false;
  const proto = Object.getPrototypeOf(value);
  return proto === null || proto === Object.prototype;
}

function canonicalizeValue(value) {
  if (value === undefined) {
    throw new Error("canonicalizeForHash: undefined is forbidden");
  }
  if (value === null) return null;
  if (typeof value === "boolean") return value;
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new Error("canonicalizeForHash: non-finite number is forbidden");
    }
    return value;
  }
  if (typeof value === "string") return value;
  if (value && typeof value === "object" && typeof value.toMillis === "function") {
    // Firestore Timestamp (or any Timestamp-like value) -> integer ms.
    // toMillis() is called exactly once; its result must itself be
    // finite, mirroring the plain `number` branch's own check above —
    // otherwise JSON.stringify would silently coerce NaN/Infinity to
    // `null`, colliding with a genuinely-null value instead of failing
    // closed.
    const millis = value.toMillis();
    if (!Number.isFinite(millis)) {
      throw new Error("canonicalizeForHash: Timestamp-like value's toMillis() must be finite");
    }
    return millis;
  }
  if (Array.isArray(value)) {
    // Preserve the array's existing order exactly — never re-sorted;
    // only its members are recursively canonicalized.
    return value.map((item) => canonicalizeValue(item));
  }
  if (isPlainObject(value)) {
    const sortedKeys = Object.keys(value).sort();
    const stable = {};
    for (const key of sortedKeys) {
      stable[key] = canonicalizeValue(value[key]);
    }
    return stable;
  }
  // function, symbol, DocumentReference, or any other class instance
  // besides the accepted Timestamp-like shape above.
  throw new Error("canonicalizeForHash: unsupported value type");
}

function canonicalizeForHash(decisionContent) {
  const stable = {};
  for (const key of [...DECISION_HASH_INCLUDED_FIELDS].sort()) {
    if (!(key in decisionContent) || decisionContent[key] === undefined) {
      throw new Error(`canonicalizeForHash: required field "${key}" is missing or undefined`);
    }
    stable[key] = canonicalizeValue(decisionContent[key]);
  }
  return JSON.stringify(stable);
}

function computeDecisionHash(decisionContent) {
  return crypto.createHash("sha256").update(canonicalizeForHash(decisionContent), "utf8").digest("hex");
}

// ---------------------------------------------------------------------
// Truncation event (§10 "Truncation event contract", Revision 9
// correction 50) — reuses the existing, already-shipped
// complianceReviewEvents schema/enums exactly; no new constant or field.
// Exact fixed-key, counts-only notes format; no document/scope IDs, no
// evidence content, no free text beyond the fixed keys.
// ---------------------------------------------------------------------

function buildTruncationEventPayload({ productId, businessId, matching }) {
  const notes =
    `candidateRefs=${matching.candidateRefs}; ` +
    `candidateDocuments=${matching.candidateDocuments}; ` +
    `sourceReads=${matching.sourceReads}; ` +
    `activeRefs=${matching.activeRefs}; ` +
    `omittedBySourceReadCap=${matching.omittedBySourceReadCap}; ` +
    `omittedByActiveRefCap=${matching.omittedByActiveRefCap}`;
  return {
    targetType: COMPLIANCE_REVIEW_EVENT_TARGET_TYPE.PRODUCT,
    targetId: productId,
    businessId,
    action: COMPLIANCE_REVIEW_EVENT_ACTION.RECOMPUTED,
    actorUid: "system",
    actorRole: COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE.SYSTEM,
    occurredAt: admin.firestore.FieldValue.serverTimestamp(),
    notes,
  };
}

async function recomputeProductComplianceStatus({ db, businessId, productId, now = new Date() }) {
  if (typeof businessId !== "string" || businessId.length === 0) {
    throw new Error("recomputeProductComplianceStatus: businessId is required");
  }
  if (typeof productId !== "string" || productId.length === 0) {
    throw new Error("recomputeProductComplianceStatus: productId is required");
  }

  // Step 1 — resolve the active policy fresh, non-transactional,
  // exactly matching resolveActivePolicy's own designed usage. Left
  // unguarded: a throw here propagates, and nothing is written.
  const { activeVersionId, version: activePolicyVersion } = await resolveActivePolicy({ db, now });

  const counters = createCounters();
  // resolveActivePolicy's own two point reads (pointer + version) — it
  // is an already-committed, unmodified Slice 4.1 module with no
  // counters parameter of its own, so its known, fixed read
  // contribution is accounted here explicitly rather than left
  // untracked (§10's ≤42-read bound counts these two reads by name).
  counters.pointReads += 2;

  const result = await db.runTransaction(async (tx) => {
    // --- All reads first. ---
    let productSnap;
    try {
      productSnap = await tx.get(productRef(db, businessId, productId));
    } catch (err) {
      unavailable(REASON.PRODUCT_READ_FAILED);
    }
    counters.pointReads += 1;
    if (!productSnap.exists) {
      failClosed(REASON.PRODUCT_NOT_FOUND);
    }
    const product = productSnap.data();
    if (product.businessId !== businessId) {
      failClosed(REASON.PRODUCT_BUSINESS_ID_MISMATCH);
    }

    let epochSnap;
    try {
      epochSnap = await tx.get(epochRef(db, businessId));
    } catch (err) {
      unavailable(REASON.EPOCH_READ_FAILED);
    }
    counters.pointReads += 1;
    const epoch = epochSnap.exists && typeof epochSnap.data().epoch === "number" ? epochSnap.data().epoch : 0;

    const matching = await runComplianceMatching({
      tx,
      db,
      product,
      productId,
      activePolicyVersion,
      now,
      counters,
    });

    let priorDecisionSnap;
    try {
      priorDecisionSnap = await tx.get(decisionRef(db, productId));
    } catch (err) {
      unavailable(REASON.PRIOR_DECISION_READ_FAILED);
    }
    counters.pointReads += 1;
    const priorDecision = priorDecisionSnap.exists ? priorDecisionSnap.data() : null;

    // --- Build the decision document. ---
    const productInputRevisionSnapshot = normalizedProductInputRevisionSnapshot(product);
    const sellerRelationshipSnapshot = computeSellerRelationshipSnapshot(product);
    const effectiveStatus = determineEffectiveStatus({
      policyUnresolved: matching.policyUnresolved,
      allRequiredSlotsSatisfied: matching.allRequiredSlotsSatisfied,
    });
    // Strip the matching engine's internal `matchedVia` tag before this
    // enters the decision/hash — the frozen decision schema's own
    // activeEvidenceRefs shape is exactly {documentId, scopeId,
    // expiresAt}, no fourth field (§4). `matchedVia` is retained
    // separately, on `matching.matchedLinks`, for the productEvidenceLinks
    // writer only, below.
    const activeEvidenceRefs = matching.activeEvidenceRefs.map((ref) => ({
      documentId: ref.documentId,
      scopeId: ref.scopeId,
      expiresAt: ref.expiresAt,
    }));
    const validUntil = computeEffectiveValidUntil(activeEvidenceRefs);

    const decisionContent = {
      businessId,
      policyVersion: activeVersionId,
      evidenceRevision: epoch,
      productInputRevisionSnapshot,
      sellerRelationshipSnapshot,
      requiredEvidenceSlots: matching.requiredEvidenceSlots,
      satisfiedEvidenceSlots: matching.satisfiedEvidenceSlots,
      activeEvidenceRefs,
      validUntil,
      effectiveStatus,
    };
    const decisionHash = computeDecisionHash(decisionContent);
    const decisionDoc = {
      ...decisionContent,
      computedAt: admin.firestore.FieldValue.serverTimestamp(),
      decisionHash,
    };

    // --- Writes: delete prior links (re-derived, no query), replace
    //     the decision, write up to MATCHED_SCOPE_CAP new links, and —
    //     only if truncation occurred — one truncation event. Exactly
    //     this order (§10 "Prior-link cleanup and transaction
    //     ordering", extended Revision 9 correction 50). ---
    if (priorDecision && Array.isArray(priorDecision.activeEvidenceRefs)) {
      for (const ref of priorDecision.activeEvidenceRefs.slice(0, PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS)) {
        if (!ref || typeof ref.documentId !== "string" || typeof ref.scopeId !== "string") continue;
        const oldLinkId = deriveEvidenceLinkId({ productId, documentId: ref.documentId, scopeId: ref.scopeId });
        tx.delete(linkRef(db, oldLinkId));
      }
    }

    tx.set(decisionRef(db, productId), decisionDoc);

    for (const link of matching.matchedLinks.slice(0, PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS)) {
      const newLinkId = deriveEvidenceLinkId({
        productId,
        documentId: link.documentId,
        scopeId: link.scopeId,
      });
      tx.set(linkRef(db, newLinkId), {
        businessId,
        productId,
        documentId: link.documentId,
        scopeId: link.scopeId,
        matchedVia: link.matchedVia,
        linkedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    if (matching.truncationOccurred) {
      const eventRef = db.collection(REVIEW_EVENTS_COLLECTION).doc();
      tx.create(eventRef, buildTruncationEventPayload({ productId, businessId, matching }));
    }

    return { decision: decisionContent, decisionHash, counters, truncationOccurred: matching.truncationOccurred };
  });

  return result;
}

module.exports = {
  recomputeProductComplianceStatus,
  computeDecisionHash,
  canonicalizeForHash,
  computeEffectiveValidUntil,
  determineEffectiveStatus,
  DECISION_HASH_INCLUDED_FIELDS,
};
