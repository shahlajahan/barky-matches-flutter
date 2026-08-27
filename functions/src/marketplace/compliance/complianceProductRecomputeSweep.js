"use strict";

// Petsupo Marketplace P1-A compliance foundation — Slice 4.7 (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §0.12, Revision 14, committed d4cce74b1df5eb540daa1edb99484090c86cd600):
// the bounded, checkpointed, continuously-cycling recompute sweep. This
// module never re-implements matching/evaluator/decision logic — it only
// decides, in bulk and on a schedule, which existing products are stale
// relative to the live epoch/policy pointer, and dispatches the real,
// unmodified `recomputeProductComplianceStatus` (Slice 4.3) for those.
//
// Frozen file-scope constraint (§0.12 "Frozen production file scope"):
// this module imports nothing from complianceEligibilityEvaluator.js,
// complianceMatching.js, compliancePolicyRegistryOperations.js,
// productModeration.js, or marketplaceListing.js — every well-known
// collection name/field value this module needs is therefore a local
// literal, matching the same self-contained-literal convention
// complianceProductRecompute.js itself already uses for its own
// collection names, rather than importing shared constants from any of
// the five files above.
//
// Exactly one export: `runComplianceRecomputeSweep`. No second entry
// point of any kind — no onCall/HTTP wrapper is defined here or anywhere
// else; the only production trigger is the thin `onSchedule` wiring in
// `functions/index.js`.

const admin = require("firebase-admin");
const { recomputeProductComplianceStatus } = require("./complianceProductRecompute");

const CANDIDATE_COLLECTION_GROUP = "products";
const CHECKPOINT_COLLECTION = "complianceRecomputeSweepCheckpoint";
const CHECKPOINT_DOC_ID = "current";
const DECISIONS_COLLECTION = "productComplianceDecisions";
const EPOCHS_COLLECTION = "businessComplianceEpochs";
const POLICY_POINTER_COLLECTION = "compliancePolicyRegistryPointer";
const POLICY_POINTER_DOC_ID = "current";

// Local literal, not imported from `productModeration.js` (frozen
// verified-only dependency, never imported by this module) — matches
// that module's own `PRODUCT_MODERATION_STATUS.APPROVED` value exactly.
const MODERATION_STATUS_APPROVED = "approved";

const DEFAULT_PAGE_SIZE = 500;
const DEFAULT_MAX_PAGES = 4;
const DEFAULT_MAX_RECOMPUTES = 100;

const CANDIDATE_FAILURE_CODE = Object.freeze({
  INVALID_PRODUCT_PATH: "INVALID_PRODUCT_PATH",
  STALE_CHECK_FAILED: "STALE_CHECK_FAILED",
  RECOMPUTE_FAILED: "RECOMPUTE_FAILED",
});

const INFRASTRUCTURE_FAILURE_CODE = Object.freeze({
  CHECKPOINT_READ_FAILED: "CHECKPOINT_READ_FAILED",
  CANDIDATE_QUERY_FAILED: "CANDIDATE_QUERY_FAILED",
  CHECKPOINT_WRITE_FAILED: "CHECKPOINT_WRITE_FAILED",
});

// ---------------------------------------------------------------------
// Mandatory candidate path-shape validation (§0.12 "Mandatory path-shape
// validation"). `collectionGroup("products")` matches any collection or
// subcollection in the entire database whose final path segment is
// literally `products` — not only `businesses/{businessId}/products/
// {productId}` (confirmed: `functions/index.js`'s own
// `getProductSnapshotOrThrow` reads a top-level `products/{productId}`
// fallback). Accept only exactly four non-empty segments, segment 0
// exactly "businesses", segment 2 exactly "products".
// ---------------------------------------------------------------------
function validateProductPath(path) {
  if (typeof path !== "string" || path.length === 0) {
    return { valid: false };
  }
  const segments = path.split("/");
  if (segments.length !== 4 || segments.some((segment) => segment.length === 0)) {
    return { valid: false };
  }
  if (segments[0] !== "businesses" || segments[2] !== "products") {
    return { valid: false };
  }
  return { valid: true, businessId: segments[1], productId: segments[3] };
}

// A checkpoint's own `lastExaminedPath` is plausible when it is either
// `null` (start of collection) or a string that itself passes the exact
// same four-segment candidate-path validation above.
function isPlausibleCheckpointPath(value) {
  if (value === null) return true;
  return typeof value === "string" && validateProductPath(value).valid;
}

function checkpointRef(db) {
  return db.collection(CHECKPOINT_COLLECTION).doc(CHECKPOINT_DOC_ID);
}

function policyPointerRef(db) {
  return db.collection(POLICY_POINTER_COLLECTION).doc(POLICY_POINTER_DOC_ID);
}

function decisionRef(db, productId) {
  return db.collection(DECISIONS_COLLECTION).doc(productId);
}

function epochRef(db, businessId) {
  return db.collection(EPOCHS_COLLECTION).doc(businessId);
}

// ---------------------------------------------------------------------
// Frozen operational-logging contract (§0.12). Every shape below is a
// fixed, closed object — never extended with dynamic text at the call
// site. `nextCursor`/`lastExaminedPath`/any identity/any raw error
// content is never passed to `logger` anywhere in this module.
// ---------------------------------------------------------------------
// The event name is passed as the descriptive first argument (matching
// the already-committed, verbatim `functions/index.js` completion-log
// call, §0.12) — never duplicated as a second `event:` key inside the
// data object, so every log call in this module follows one single,
// consistent shape.
function logCandidateFailure(logger, failureCode) {
  logger.error("compliance_recompute_sweep_candidate_failed", { failureCode });
}

function logInfrastructureFailure(logger, failureCode) {
  logger.error("compliance_recompute_sweep_infrastructure_failed", { failureCode });
}

function logCheckpointMalformed(logger) {
  logger.error("compliance_recompute_sweep_checkpoint_malformed");
}

// ---------------------------------------------------------------------
// Per-candidate staleness/recompute dispatch (§0.12 "The frozen
// recompute-execution semantics"). Returns one of "fresh" |
// "recomputed" | "failed-check" | "failed-recompute" — the caller
// updates its own counters and cursor tracking from this outcome; this
// function performs no counter/cursor bookkeeping itself. The two
// failure outcomes are kept distinct so the caller can correctly count
// only actual `recomputeProductComplianceStatus` dispatch attempts
// (`"recomputed"` + `"failed-recompute"`) against the frozen
// ≤100-recomputes-dispatched-per-invocation cap (§0.12) — a pre-dispatch
// staleness-check failure (`"failed-check"`) never calls that function
// at all, so it must never count toward that cap.
// ---------------------------------------------------------------------
async function processCandidate({ db, businessId, productId, now, logger, epochCache, getActivePolicyVersionId }) {
  let decisionSnap;
  let epoch;
  let activeVersionId;
  try {
    decisionSnap = await decisionRef(db, productId).get();
    if (epochCache.has(businessId)) {
      epoch = epochCache.get(businessId);
    } else {
      const epochSnap = await epochRef(db, businessId).get();
      epoch = epochSnap.exists && typeof epochSnap.data().epoch === "number" ? epochSnap.data().epoch : 0;
      epochCache.set(businessId, epoch);
    }
    activeVersionId = await getActivePolicyVersionId();
  } catch (err) {
    logCandidateFailure(logger, CANDIDATE_FAILURE_CODE.STALE_CHECK_FAILED);
    return "failed-check";
  }

  const decision = decisionSnap.exists ? decisionSnap.data() : null;
  const stale =
    decision === null ||
    decision.evidenceRevision !== epoch ||
    decision.policyVersion !== activeVersionId;

  if (!stale) {
    return "fresh";
  }

  try {
    await recomputeProductComplianceStatus({ db, businessId, productId, now });
    return "recomputed";
  } catch (err) {
    logCandidateFailure(logger, CANDIDATE_FAILURE_CODE.RECOMPUTE_FAILED);
    return "failed-recompute";
  }
}

// ---------------------------------------------------------------------
// The pure, testable core (§0.12 "The frozen sweep trigger/export
// contract"). Exactly one production entry point into this module's own
// logic — no second export.
// ---------------------------------------------------------------------
async function runComplianceRecomputeSweep({
  db,
  now = new Date(),
  maxPages = DEFAULT_MAX_PAGES,
  pageSize = DEFAULT_PAGE_SIZE,
  maxRecomputes = DEFAULT_MAX_RECOMPUTES,
  logger = console,
}) {
  let checkpointLastExaminedPath = null;
  try {
    const checkpointSnap = await checkpointRef(db).get();
    if (checkpointSnap.exists) {
      const data = checkpointSnap.data();
      const rawPath = data ? data.lastExaminedPath : undefined;
      if (isPlausibleCheckpointPath(rawPath)) {
        checkpointLastExaminedPath = rawPath === undefined ? null : rawPath;
      } else {
        logCheckpointMalformed(logger);
        checkpointLastExaminedPath = null;
      }
    }
  } catch (err) {
    logInfrastructureFailure(logger, INFRASTRUCTURE_FAILURE_CODE.CHECKPOINT_READ_FAILED);
    throw err;
  }

  let cursorRef = checkpointLastExaminedPath ? db.doc(checkpointLastExaminedPath) : null;
  let lastExaminedRef = null;
  let examinedCount = 0;
  let recomputedCount = 0;
  let freshCount = 0;
  let failedCount = 0;
  let pagesFetched = 0;
  let exhausted = false;
  let bounded = false;
  let recomputeCapHit = false;

  let recomputesDispatched = 0; // both successful and failed recomputeProductComplianceStatus calls — never pre-dispatch (STALE_CHECK_FAILED/INVALID_PRODUCT_PATH) failures
  const epochCache = new Map();
  let activeVersionIdCache;
  let activeVersionIdCachePromise = null;
  function getActivePolicyVersionId() {
    if (activeVersionIdCachePromise) return activeVersionIdCachePromise;
    activeVersionIdCachePromise = (async () => {
      const pointerSnap = await policyPointerRef(db).get();
      activeVersionIdCache = pointerSnap.exists ? pointerSnap.data().activeVersionId : undefined;
      return activeVersionIdCache;
    })();
    return activeVersionIdCachePromise;
  }

  for (let page = 0; page < maxPages; page += 1) {
    let docs;
    try {
      let query = db
        .collectionGroup(CANDIDATE_COLLECTION_GROUP)
        .where("isActive", "==", true)
        .where("moderationStatus", "==", MODERATION_STATUS_APPROVED)
        .orderBy(admin.firestore.FieldPath.documentId(), "asc")
        .limit(pageSize);
      if (cursorRef) {
        query = query.startAfter(cursorRef);
      }
      const snap = await query.get();
      docs = snap.docs;
    } catch (err) {
      logInfrastructureFailure(logger, INFRASTRUCTURE_FAILURE_CODE.CANDIDATE_QUERY_FAILED);
      throw err;
    }

    pagesFetched += 1;

    for (const doc of docs) {
      const { valid, businessId, productId } = validateProductPath(doc.ref.path);

      if (!valid) {
        examinedCount += 1;
        failedCount += 1;
        logCandidateFailure(logger, CANDIDATE_FAILURE_CODE.INVALID_PRODUCT_PATH);
        lastExaminedRef = doc.ref;
      } else {
        const outcome = await processCandidate({
          db,
          businessId,
          productId,
          now,
          logger,
          epochCache,
          getActivePolicyVersionId,
        });
        examinedCount += 1;
        lastExaminedRef = doc.ref;
        if (outcome === "fresh") {
          freshCount += 1;
        } else if (outcome === "recomputed") {
          recomputedCount += 1;
          recomputesDispatched += 1;
          if (recomputesDispatched >= maxRecomputes) {
            recomputeCapHit = true;
          }
        } else if (outcome === "failed-recompute") {
          failedCount += 1;
          recomputesDispatched += 1;
          if (recomputesDispatched >= maxRecomputes) {
            recomputeCapHit = true;
          }
        } else {
          // "failed-check" — a pre-dispatch staleness-check failure;
          // recomputeProductComplianceStatus was never called, so this
          // never counts toward the dispatch cap.
          failedCount += 1;
        }
      }

      if (recomputeCapHit) break;
    }

    if (recomputeCapHit) {
      bounded = true;
      exhausted = false;
      break;
    }

    if (docs.length < pageSize) {
      exhausted = true;
      break;
    }

    cursorRef = lastExaminedRef;
  }

  if (!recomputeCapHit && !exhausted) {
    // Exactly `maxPages` full pages were fetched without proving
    // exhaustion and without hitting the recompute cap.
    bounded = true;
  }

  const nextCursor = exhausted ? null : lastExaminedRef ? lastExaminedRef.path : null;

  try {
    await checkpointRef(db).set({
      lastExaminedPath: nextCursor,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    logInfrastructureFailure(logger, INFRASTRUCTURE_FAILURE_CODE.CHECKPOINT_WRITE_FAILED);
    throw err;
  }

  return {
    examinedCount,
    recomputedCount,
    freshCount,
    failedCount,
    nextCursor,
    exhausted,
    pagesFetched,
    bounded,
  };
}

module.exports = {
  runComplianceRecomputeSweep,
};
