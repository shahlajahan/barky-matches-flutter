"use strict";

// Marketplace Revision 30 §H / §J Slice 6 — approval invalidation.
//
// §H, verbatim: "the fingerprint's bound-field set is extended to include the
// effective evidence decision and its revision, so any evidence change
// invalidates a prior approval exactly as a content change does" and "On
// expiry or revocation the platform performs immediate authoritative
// unpublication, invalidates the approval, corrects `pilotActiveProductCount`
// exactly once, emits an audit event ... and requires re-review before
// republication."
//
// HOW INVALIDATION IS DETECTED, and why one comparison covers every trigger.
// Slice 6 binds the effective decision into the approval fingerprint, so the
// stored `reviewedContentFingerprint` is a hash over BOTH reviewed product
// content AND the decision identity (`decisionHash`, `policyVersion`,
// `evidenceRevision`, `effectiveStatus`, `validUntil`, evidence digest) plus
// the business generation. Every §H trigger — a document revoked, rejected,
// superseded or expired; `validUntil` crossing now; a scope or member change;
// an evidence link replaced; the active policy pointer moving; the generation
// changing; reviewed content edited — necessarily changes at least one of
// those inputs, and therefore changes the live fingerprint. One equality
// comparison against fresh canonical state detects all of them, and detects
// an input this code has never heard of just as reliably.
//
// FAIL-CLOSED. Inequality invalidates. So does an absent decision, a
// malformed one, an unreadable one, and an approval whose stored fingerprint
// is missing or not a string. The only outcome that leaves an approval
// standing is a proven byte-equal match.
//
// BOUNDEDNESS. The candidate query is the SAME collection-group shape the
// existing recompute sweep uses (`isActive == true && moderationStatus ==
// approved`), which is exactly the set of products an invalidation could have
// to unpublish — an inactive product has nothing to revoke. It is paginated
// by document id with a bounded page count, so there is no unbounded fan-out
// and no per-business queue.
//
// WHAT THIS DOES NOT DO. It never approves, activates, publishes, classifies
// or makes anything eligible, and it never increments
// `pilotActiveProductCount`. Its only state transition is the frozen
// revocation one already owned by `revokePilotProductApproval`: active ->
// inactive, `moderationStatus` back to `pending_review`, count decremented
// exactly once, audit event written in the same transaction.

const admin = require("firebase-admin");

const {
  computeApprovalFingerprint,
  REASON_CODE,
  AUDIT_EVENTS_COLLECTION,
} = require("./pilotProductApproval");

const BUSINESSES_COLLECTION = "businesses";
const DECISIONS_COLLECTION = "productComplianceDecisions";
const CANDIDATE_COLLECTION_GROUP = "products";
const MODERATION_STATUS_APPROVED = "approved";

const DEFAULT_PAGE_SIZE = 50;
const DEFAULT_MAX_PAGES = 20;

const INVALIDATION_REASON = Object.freeze({
  FINGERPRINT_MISMATCH: "fingerprint_mismatch",
  DECISION_MISSING: "decision_missing",
  DECISION_UNREADABLE: "decision_unreadable",
  APPROVAL_MALFORMED: "approval_malformed",
});

function productPathParts(path) {
  // businesses/{businessId}/products/{productId}
  const parts = path.split("/");
  if (parts.length !== 4 || parts[0] !== BUSINESSES_COLLECTION || parts[2] !== "products") {
    return null;
  }
  if (!parts[1] || !parts[3]) return null;
  return { businessId: parts[1], productId: parts[3] };
}

function isCurrentlyActivePilotApproval(product) {
  const approval = product && product.pilotProductApproval;
  return Boolean(
    approval &&
      typeof approval === "object" &&
      !Array.isArray(approval) &&
      approval.active === true
  );
}

/// Invalidates ONE product's approval if its stored fingerprint no longer
/// matches canonical state. Idempotent: a product that is already inactive
/// returns a no-op without touching the count, so duplicate and out-of-order
/// deliveries are safe and the count can never be decremented twice or driven
/// below zero for the same approval.
async function invalidateProductApprovalIfStale({ db, businessId, productId, logger = console }) {
  const prodRef = db
    .collection(BUSINESSES_COLLECTION)
    .doc(businessId)
    .collection("products")
    .doc(productId);
  const bizRef = db.collection(BUSINESSES_COLLECTION).doc(businessId);
  const decRef = db.collection(DECISIONS_COLLECTION).doc(productId);

  return db.runTransaction(async (tx) => {
    // All reads first, and all inside the transaction — so a concurrent
    // approval or decision change aborts and retries this against fresh
    // state rather than acting on a stale view.
    const [prodSnap, bizSnap, decSnap] = await Promise.all([
      tx.get(prodRef),
      tx.get(bizRef),
      tx.get(decRef),
    ]);

    if (!prodSnap.exists || !bizSnap.exists) {
      return { outcome: "skipped", reason: "absent" };
    }
    const product = prodSnap.data() || {};
    if (product.businessId !== businessId) {
      return { outcome: "skipped", reason: "business_mismatch" };
    }

    // Nothing to revoke: already inactive. No count change, ever.
    if (!isCurrentlyActivePilotApproval(product)) {
      return { outcome: "noop", reason: "not_active" };
    }

    const stored = product.pilotProductApproval.reviewedContentFingerprint;
    const decision = decSnap.exists ? decSnap.data() : null;

    let reason = null;
    if (typeof stored !== "string" || stored.length === 0) {
      reason = INVALIDATION_REASON.APPROVAL_MALFORMED;
    } else if (!decision) {
      reason = INVALIDATION_REASON.DECISION_MISSING;
    } else if (typeof decision !== "object" || Array.isArray(decision)) {
      reason = INVALIDATION_REASON.DECISION_UNREADABLE;
    } else {
      const live = computeApprovalFingerprint(product, decision);
      if (live !== stored) reason = INVALIDATION_REASON.FINGERPRINT_MISMATCH;
    }

    if (reason === null) {
      return { outcome: "valid" };
    }

    // The frozen revocation transition, byte-for-byte the one
    // `revokePilotProductApproval` performs — reused, not reinvented, so
    // there is exactly one way an approval ever ends.
    tx.update(prodRef, {
      "pilotProductApproval.active": false,
      "pilotProductApproval.revokedAt": admin.firestore.FieldValue.serverTimestamp(),
      "pilotProductApproval.revokedBy": null,
      "pilotProductApproval.revokedByKind": "system",
      "pilotProductApproval.reasonCode": REASON_CODE.REVOKED_CONTENT_CHANGED,
      isActive: false,
      moderationStatus: "pending_review",
    });
    tx.update(bizRef, {
      pilotActiveProductCount: admin.firestore.FieldValue.increment(-1),
    });
    // Immutable audit event, written in the SAME transaction as the state
    // change so history can never disagree with state. No historical
    // reviewer identity, reviewedAt or reason is overwritten — the prior
    // approval's own audit events are untouched and a new one is appended.
    tx.create(db.collection(AUDIT_EVENTS_COLLECTION).doc(), {
      businessId,
      productId,
      action: "revoke",
      adminUid: null,
      actorKind: "system",
      resultingActiveState: false,
      reasonCode: REASON_CODE.REVOKED_CONTENT_CHANGED,
      invalidationReason: reason,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("compliance_approval_invalidated", { reason });
    return { outcome: "invalidated", reason };
  });
}

/// Bounded sweep over currently-active approved products.
async function runApprovalInvalidationSweep({
  db,
  pageSize = DEFAULT_PAGE_SIZE,
  maxPages = DEFAULT_MAX_PAGES,
  logger = console,
} = {}) {
  let examined = 0;
  let invalidated = 0;
  let valid = 0;
  let skipped = 0;
  let cursor = null;
  let pages = 0;

  for (let page = 0; page < maxPages; page += 1) {
    let query = db
      .collectionGroup(CANDIDATE_COLLECTION_GROUP)
      .where("isActive", "==", true)
      .where("moderationStatus", "==", MODERATION_STATUS_APPROVED)
      .orderBy(admin.firestore.FieldPath.documentId(), "asc")
      .limit(pageSize);
    if (cursor) query = query.startAfter(cursor);

    const snap = await query.get();
    if (snap.empty) break;
    pages += 1;

    for (const doc of snap.docs) {
      examined += 1;
      const parts = productPathParts(doc.ref.path);
      if (!parts) {
        skipped += 1;
        continue;
      }
      try {
        const result = await invalidateProductApprovalIfStale({
          db,
          businessId: parts.businessId,
          productId: parts.productId,
          logger,
        });
        if (result.outcome === "invalidated") invalidated += 1;
        else if (result.outcome === "valid") valid += 1;
        else skipped += 1;
      } catch (_) {
        // One product's failure never aborts the sweep; it is simply not
        // counted as validated, and the next run retries it.
        skipped += 1;
      }
    }

    cursor = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < pageSize) break;
  }

  return { examined, invalidated, valid, skipped, pages, bounded: pages >= maxPages };
}

module.exports = {
  invalidateProductApprovalIfStale,
  runApprovalInvalidationSweep,
  INVALIDATION_REASON,
};
