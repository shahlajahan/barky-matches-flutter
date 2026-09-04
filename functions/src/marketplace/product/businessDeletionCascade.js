// Marketplace Revision 33 §A(6)/§E — the generation-safe business-deletion
// cascade.
//
// It replaces the previous deactivate-only trigger behaviour, which left
// every product document in place and therefore left every deterministic
// product ID occupied: a business recreated under the same ID could never
// reuse its own SKUs, and submission would fail closed forever with
// `previous_generation_cleanup_pending`.
//
// The dangerous case this module exists to get right: a business is deleted
// and recreated under the SAME document ID while cleanup is still running.
// The cascade must never touch the new generation's products, evidence or
// media. It therefore takes its authority from the DELETED snapshot's own
// `marketplaceBusinessGenerationId` — never from the live business document,
// which may be absent or may already belong to a newer generation — and the
// shared cleanup primitive re-proves that binding on every single product
// inside the transaction that deletes it.
const admin = require("firebase-admin");

const {
  cleanupProductFirestoreState,
  CLEANUP_SOURCE,
  CLEANUP_OUTCOME,
} = require("./productCleanup");
const { processPendingMediaCleanup } = require("./pendingMediaCleanup");

const BUSINESSES_COLLECTION = "businesses";
const PRODUCTS_SUBCOLLECTION = "products";
const CASCADE_STATE_COLLECTION = "marketplaceBusinessDeletionCascades";

const DEFAULT_PAGE_SIZE = 50;
// Leaves headroom inside a 540s trigger budget; the reconciler resumes.
const DEFAULT_DEADLINE_MS = 240 * 1000;
const LEASE_DURATION_MS = 5 * 60 * 1000;
// Bounded backoff so an unfinished or repeatedly failing cascade cannot hold
// the head of the resumer queue and starve healthy work behind it.
const RESUME_BACKOFF_MS = 60 * 1000;

const CASCADE_STATUS = Object.freeze({
  IN_PROGRESS: "in_progress",
  COMPLETED: "completed",
  FAILED_RETRYABLE: "failed_retryable",
});

function isNonEmptyString(value) {
  return typeof value === "string" && value.length > 0;
}

// One state document per (business, deleted generation). Keyed so a later
// generation's own deletion can never collide with, resume or overwrite an
// earlier generation's outstanding cleanup.
function cascadeStateId(businessId, generationId) {
  return `${businessId}__${generationId || "no_generation"}`;
}

function cascadeStateRef(db, businessId, generationId) {
  return db.collection(CASCADE_STATE_COLLECTION).doc(cascadeStateId(businessId, generationId));
}

function toMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  const parsed = new Date(value).getTime();
  return Number.isFinite(parsed) ? parsed : 0;
}

/**
 * Processes one bounded page-loop of an outstanding cascade.
 *
 * Pagination is by document ID with `startAfter`, so it never loads the
 * whole subcollection into memory, never fans out with an unbounded
 * `Promise.all`, and resumes deterministically from the persisted cursor.
 * Products are cleaned one at a time: each gets its own transaction, so a
 * single failure cannot roll back or block the rest, and a retry re-runs
 * only what is left.
 */
async function runBusinessDeletionCascade({
  db,
  storage = null,
  bucketName = null,
  businessId,
  deletedGeneration,
  now = () => new Date(),
  pageSize = DEFAULT_PAGE_SIZE,
  deadlineMs = DEFAULT_DEADLINE_MS,
  logger = console,
  workerId = `worker-${Math.random().toString(36).slice(2)}`,
}) {
  const startedAtMs = now().getTime();
  const stateRef = cascadeStateRef(db, businessId, deletedGeneration);

  // At-least-once delivery: a duplicate invocation must not double-process.
  // An expired lease is reclaimable exactly as if none existed.
  const claim = await db.runTransaction(async (tx) => {
    const snap = await tx.get(stateRef);
    const state = snap.exists ? snap.data() || {} : {};
    if (state.status === CASCADE_STATUS.COMPLETED) {
      return { claimed: false, reason: "already_completed" };
    }
    const nowMs = now().getTime();
    if (isNonEmptyString(state.leaseOwner) && toMillis(state.leaseExpiresAt) > nowMs) {
      return { claimed: false, reason: "leased_by_other_worker" };
    }
    tx.set(
      stateRef,
      {
        businessId,
        deletedGeneration: deletedGeneration || null,
        status: CASCADE_STATUS.IN_PROGRESS,
        leaseOwner: workerId,
        leaseExpiresAt: new Date(nowMs + LEASE_DURATION_MS),
        startedAt: state.startedAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return { claimed: true, cursor: isNonEmptyString(state.cursor) ? state.cursor : null, state };
  });

  if (!claim.claimed) {
    return { claimed: false, reason: claim.reason };
  }

  // `deltas` counts only this run's work and is written with
  // FieldValue.increment, so overlapping workers can never clobber one
  // another with stale absolute totals. `totals` is the caller-facing view.
  const prior = {
    examined: Number(claim.state.examinedCount) || 0,
    deleted: Number(claim.state.deletedCount) || 0,
    skippedGenerationMismatch: Number(claim.state.skippedGenerationMismatch) || 0,
    skippedBusinessMismatch: Number(claim.state.skippedBusinessMismatch) || 0,
    alreadyAbsent: Number(claim.state.alreadyAbsentCount) || 0,
    mediaDeleted: Number(claim.state.mediaDeletedCount) || 0,
    mediaFailed: Number(claim.state.mediaFailedCount) || 0,
    productFailures: Number(claim.state.productFailureCount) || 0,
  };
  const deltas = {
    examined: 0, deleted: 0, skippedGenerationMismatch: 0,
    skippedBusinessMismatch: 0, alreadyAbsent: 0, mediaDeleted: 0,
    mediaFailed: 0, productFailures: 0,
  };
  const totals = new Proxy(deltas, {
    get: (target, key) =>
      typeof key === "string" && key in target ? target[key] + (prior[key] || 0) : target[key],
  });

  let cursor = claim.cursor;
  let exhausted = false;
  let deadlineReached = false;

  const productsCollection = db
    .collection(BUSINESSES_COLLECTION)
    .doc(businessId)
    .collection(PRODUCTS_SUBCOLLECTION);

  while (!exhausted && !deadlineReached) {
    let query = productsCollection.orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) {
      exhausted = true;
      break;
    }

    for (const doc of page.docs) {
      deltas.examined += 1;
      cursor = doc.id;
      try {
        const result = await db.runTransaction((tx) =>
          cleanupProductFirestoreState({
            db,
            tx,
            businessId,
            productId: doc.id,
            // Authority comes from the deleted snapshot, never the live
            // business document — which may already be a new generation.
            expectedGenerationId: deletedGeneration || null,
            source: CLEANUP_SOURCE.BUSINESS_DELETION_CASCADE,
            actorUid: null,
            bucketName,
          })
        );

        if (result.outcome === CLEANUP_OUTCOME.DELETED) {
          deltas.deleted += 1;
          // The durable pending-cleanup record was committed with the
          // deletion; this immediate attempt is opportunistic only, and the
          // scheduled media resumer owns anything it does not finish.
          if (result.pendingCleanupId) {
            try {
              const media = await processPendingMediaCleanup({
                db, storage, cleanupId: result.pendingCleanupId, now, logger,
              });
              if (media.outcome === "completed" || media.outcome === "completed_shared_retained") {
                deltas.mediaDeleted += media.deletedCount || 0;
              } else {
                deltas.mediaFailed += 1;
              }
            } catch (error) {
              deltas.mediaFailed += 1;
              logger.warn("marketplace_cascade_media_attempt_failed", {
                code: (error && error.code) || "unknown",
              });
            }
          }
        } else if (result.outcome === CLEANUP_OUTCOME.SKIPPED_GENERATION_MISMATCH) {
          // A product of the NEW generation, or one whose binding cannot be
          // proven. Never deleted; recorded so the skip is auditable.
          deltas.skippedGenerationMismatch += 1;
        } else if (result.outcome === CLEANUP_OUTCOME.SKIPPED_BUSINESS_MISMATCH) {
          deltas.skippedBusinessMismatch += 1;
        } else {
          deltas.alreadyAbsent += 1;
        }
      } catch (error) {
        // One product's failure must not abort the cascade. The cursor still
        // advances; the product stays non-public (its document is untouched)
        // and the failure count makes the incomplete cleanup admin-visible.
        deltas.productFailures += 1;
        logger.warn("marketplace_business_cascade_product_failed", {
          code: (error && error.code) || "unknown",
        });
      }

      if (now().getTime() - startedAtMs >= deadlineMs) {
        deadlineReached = true;
        break;
      }
    }

    if (page.size < pageSize && !deadlineReached) exhausted = true;

    // Renew per page. A lease shorter than the uninterrupted work interval
    // would otherwise expire mid-run and let a second worker start while this
    // one is still writing.
    if (!exhausted && !deadlineReached) {
      const renewed = await db.runTransaction(async (tx) => {
        const snap = await tx.get(stateRef);
        if (!snap.exists || (snap.data() || {}).leaseOwner !== workerId) return false;
        tx.update(stateRef, {
          leaseExpiresAt: new Date(now().getTime() + LEASE_DURATION_MS),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (!renewed) {
        // Lost the lease to another worker. Stop immediately and write
        // nothing further: the owner is authoritative from here.
        return { claimed: true, status: CASCADE_STATUS.IN_PROGRESS, lostLease: true, ...totals };
      }
    }
  }

  const complete = exhausted && !deadlineReached;
  const status = complete
    ? totals.productFailures > 0 || totals.mediaFailed > 0
      ? CASCADE_STATUS.FAILED_RETRYABLE
      : CASCADE_STATUS.COMPLETED
    : CASCADE_STATUS.IN_PROGRESS;

  // The terminal write is transactional and verifies this worker still owns
  // the lease, so a worker that lost it can never clear the current owner's
  // lease, regress its cursor, or overwrite its counters. Counters are
  // written as increments of this run's own deltas rather than stale
  // absolute totals read at claim time.
  const settled = await db.runTransaction(async (tx) => {
    const snap = await tx.get(stateRef);
    if (!snap.exists || (snap.data() || {}).leaseOwner !== workerId) {
      return false;
    }
    tx.update(stateRef, {
      businessId,
      deletedGeneration: deletedGeneration || null,
      status,
      cursor: complete ? null : cursor,
      examinedCount: admin.firestore.FieldValue.increment(deltas.examined),
      deletedCount: admin.firestore.FieldValue.increment(deltas.deleted),
      skippedGenerationMismatch: admin.firestore.FieldValue.increment(deltas.skippedGenerationMismatch),
      skippedBusinessMismatch: admin.firestore.FieldValue.increment(deltas.skippedBusinessMismatch),
      alreadyAbsentCount: admin.firestore.FieldValue.increment(deltas.alreadyAbsent),
      mediaDeletedCount: admin.firestore.FieldValue.increment(deltas.mediaDeleted),
      mediaFailedCount: admin.firestore.FieldValue.increment(deltas.mediaFailed),
      productFailureCount: admin.firestore.FieldValue.increment(deltas.productFailures),
      attemptCount: admin.firestore.FieldValue.increment(1),
      // Deterministic ordering key for the resumer, with bounded backoff so a
      // poison cascade cannot hold the head of the queue forever.
      nextAttemptAt: complete ? null : new Date(now().getTime() + RESUME_BACKOFF_MS),
      leaseOwner: null,
      leaseExpiresAt: null,
      completedAt:
        status === CASCADE_STATUS.COMPLETED
          ? admin.firestore.FieldValue.serverTimestamp()
          : null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  });

  if (!settled) {
    return { claimed: true, status: CASCADE_STATUS.IN_PROGRESS, lostLease: true, ...totals };
  }

  return { claimed: true, status, ...totals, exhausted: complete };
}

/**
 * Scheduled resumption, mirroring the established
 * `complianceUploadReconciliation` shape: pick a bounded page of cascades
 * that are not finished and whose lease is free or expired, and resume each.
 */
async function resumeIncompleteBusinessDeletionCascades({
  db,
  storage = null,
  bucketName = null,
  now = () => new Date(),
  limit = 5,
  logger = console,
  pageSize = DEFAULT_PAGE_SIZE,
  deadlineMs = DEFAULT_DEADLINE_MS,
}) {
  // Ordered by `nextAttemptAt` and filtered to records actually due, so a
  // repeatedly failing cascade backs off and cannot occupy the first slots
  // indefinitely while healthy cascades wait behind it.
  const pending = await db
    .collection(CASCADE_STATE_COLLECTION)
    .where("status", "in", [CASCADE_STATUS.IN_PROGRESS, CASCADE_STATUS.FAILED_RETRYABLE])
    .where("nextAttemptAt", "<=", now())
    .orderBy("nextAttemptAt")
    .limit(limit)
    .get();

  const resumed = [];
  for (const doc of pending.docs) {
    const state = doc.data() || {};
    const result = await runBusinessDeletionCascade({
      db,
      storage,
      bucketName,
      businessId: state.businessId,
      deletedGeneration: state.deletedGeneration || null,
      now,
      pageSize,
      deadlineMs,
      logger,
    });
    resumed.push({ id: doc.id, claimed: result.claimed, status: result.status || null });
  }
  return { considered: pending.size, resumed };
}

module.exports = {
  runBusinessDeletionCascade,
  resumeIncompleteBusinessDeletionCascades,
  cascadeStateRef,
  cascadeStateId,
  CASCADE_STATUS,
  CASCADE_STATE_COLLECTION,
  DEFAULT_PAGE_SIZE,
};
