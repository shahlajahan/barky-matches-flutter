// Marketplace Revision 33 correction — durable pending media cleanup.
//
// The defect this closes. Product deletion previously computed the deletable
// Storage object paths inside its Firestore transaction, kept them only in
// memory, and deleted the objects after the commit. If the process died — or
// Storage simply failed — between the commit and the deletion, the product
// document was already gone and the paths were unrecoverable: a permanent,
// silent orphan with nothing left to reconstruct it from.
//
// The repair. The exact canonical object paths are now persisted in the SAME
// authoritative transaction that deletes the product document, so the record
// and the deletion commit together or not at all. Storage cleanup then
// becomes an independently resumable job that never again depends on the
// product document existing.
//
// What is deliberately NOT persisted: signed download URLs, download tokens,
// arbitrary external URLs, credentials, or raw exception text. Only canonical
// object paths that already passed every provenance check, plus redacted
// error categories.
const crypto = require("node:crypto");
const admin = require("firebase-admin");

const { classifyMediaReference, resolveProductMediaObjects } = require("./productCleanup");

const PENDING_COLLECTION = "marketplacePendingMediaCleanups";
const BUSINESSES_COLLECTION = "businesses";
const PRODUCTS_SUBCOLLECTION = "products";

// Server-only. There is no Rules block for this collection, exactly as for
// `marketplaceProductDeletionReceipts`: no root catch-all match exists, so
// Firestore's default deny applies and no client can read or write it.

const PENDING_STATUS = Object.freeze({
  PENDING: "pending",
  COMPLETED: "completed",
  REQUIRES_MANUAL_REVIEW: "requires_manual_review",
  FAILED_PERMANENT: "failed_permanent",
});

const PENDING_ERROR = Object.freeze({
  NO_BUCKET: "no_bucket",
  DELETE_FAILED: "delete_failed",
  EXCLUSIVITY_UNPROVEN: "exclusivity_unproven",
});

// A product may carry at most 20 media entries, each contributing at most 3
// URL fields, so 60 canonical paths is the real ceiling. The cap below is
// deliberately far above that and exists only so a malformed or legacy
// oversized product can never produce a record near Firestore's 1 MiB limit:
// 200 paths of ~200 bytes is ~40 KiB, comfortably inside it.
const MAX_PERSISTED_PATHS = 200;

// Bounded exclusivity scan. A business with more live products than this
// cannot be proven exclusive within one invocation's budget, so its objects
// are retained for manual review rather than speculatively deleted.
const EXCLUSIVITY_SCAN_PAGE = 100;
const EXCLUSIVITY_SCAN_MAX_PRODUCTS = 2000;

const MAX_ATTEMPTS = 8;
const BASE_BACKOFF_MS = 60 * 1000;
const MAX_BACKOFF_MS = 6 * 60 * 60 * 1000;
const LEASE_DURATION_MS = 5 * 60 * 1000;

/**
 * Deterministic, server-derived record ID.
 *
 * Derived only from trusted values, never from anything a client chooses, so
 * a retried deletion of the same product in the same generation addresses the
 * same record instead of creating duplicates.
 */
function derivePendingCleanupId({ businessId, productId, expectedGenerationId, source }) {
  return crypto
    .createHash("sha256")
    .update(
      [
        "marketplace_pending_media_cleanup",
        businessId,
        productId,
        expectedGenerationId || "",
        source,
      ].join("\n")
    )
    .digest("hex");
}

function pendingCleanupRef(db, cleanupId) {
  return db.collection(PENDING_COLLECTION).doc(cleanupId);
}

function backoffMsForAttempt(attemptCount) {
  const exponential = BASE_BACKOFF_MS * Math.pow(2, Math.max(0, attemptCount - 1));
  return Math.min(exponential, MAX_BACKOFF_MS);
}

/**
 * Stages the durable pending-cleanup record inside the caller's deletion
 * transaction. Returns the record's id, or null when there is nothing to
 * clean (no provable object paths at all).
 *
 * `tx.set` with merge is used rather than `create` so an at-least-once
 * retried deletion of the same product cannot fail the whole transaction on
 * a pre-existing record.
 */
function stagePendingMediaCleanup({
  db,
  tx,
  businessId,
  productId,
  expectedGenerationId,
  bucketName,
  objectPaths,
  source,
  now = admin.firestore.FieldValue.serverTimestamp(),
  nowMs = Date.now(),
}) {
  const unique = Array.from(new Set(Array.isArray(objectPaths) ? objectPaths : []));
  if (unique.length === 0) return null;

  const cleanupId = derivePendingCleanupId({
    businessId,
    productId,
    expectedGenerationId,
    source,
  });
  const overCap = unique.length > MAX_PERSISTED_PATHS;
  const paths = overCap ? unique.slice(0, MAX_PERSISTED_PATHS) : unique;

  tx.set(
    pendingCleanupRef(db, cleanupId),
    {
      businessId,
      productId,
      expectedGenerationId: expectedGenerationId || null,
      // Bucket name only — never a URL, never a token.
      bucketName: bucketName || null,
      objectPaths: paths,
      remainingPaths: paths,
      truncated: overCap,
      source,
      // An oversized set is never speculatively deleted.
      status: overCap ? PENDING_STATUS.REQUIRES_MANUAL_REVIEW : PENDING_STATUS.PENDING,
      attemptCount: 0,
      lastErrorCode: null,
      leaseOwner: null,
      leaseExpiresAt: null,
      createdAt: now,
      updatedAt: now,
      nextAttemptAt: new Date(nowMs),
      completedAt: null,
    },
    { merge: true }
  );
  return cleanupId;
}

/**
 * Proves that no other LIVE product of this business still references the
 * given object paths.
 *
 * The `products_raw/{businessId}/` prefix proves which business owns an
 * object — never which product does. Media is an array of maps, so absence
 * cannot be established with a simple equality query; this performs a
 * bounded, paginated scan and canonicalizes every reference through the same
 * classifier used to decide deletability in the first place. Products of any
 * generation count, so a recreated business's new products protect their own
 * media from an old generation's cleanup.
 *
 * Returns `{ proven: false }` when the business is too large to scan within
 * budget — the caller then retains the objects for manual review rather than
 * deleting speculatively.
 */
async function findPathsStillReferenced({
  db,
  businessId,
  bucketName,
  candidatePaths,
  excludeProductId = null,
  pageSize = EXCLUSIVITY_SCAN_PAGE,
  maxProducts = EXCLUSIVITY_SCAN_MAX_PRODUCTS,
}) {
  const candidates = new Set(candidatePaths);
  const stillReferenced = new Set();
  if (candidates.size === 0) return { proven: true, stillReferenced };

  const collection = db
    .collection(BUSINESSES_COLLECTION)
    .doc(businessId)
    .collection(PRODUCTS_SUBCOLLECTION);

  let cursor = null;
  let examined = 0;
  for (;;) {
    let query = collection.orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;

    for (const doc of page.docs) {
      examined += 1;
      cursor = doc.id;
      if (excludeProductId && doc.id === excludeProductId) continue;
      const plan = resolveProductMediaObjects({
        product: doc.data() || {},
        businessId,
        bucketName,
      });
      for (const objectPath of plan.deletable) {
        if (candidates.has(objectPath)) stillReferenced.add(objectPath);
      }
      // Every candidate is spoken for; no further scanning can change it.
      if (stillReferenced.size === candidates.size) return { proven: true, stillReferenced };
    }
    if (examined >= maxProducts) return { proven: false, stillReferenced };
    if (page.size < pageSize) break;
  }
  return { proven: true, stillReferenced };
}

module.exports = {
  stagePendingMediaCleanup,
  derivePendingCleanupId,
  pendingCleanupRef,
  findPathsStillReferenced,
  backoffMsForAttempt,
  classifyMediaReference,
  PENDING_COLLECTION,
  PENDING_STATUS,
  PENDING_ERROR,
  MAX_PERSISTED_PATHS,
  MAX_ATTEMPTS,
  LEASE_DURATION_MS,
  EXCLUSIVITY_SCAN_MAX_PRODUCTS,
};

/**
 * Processes one durable pending-cleanup record.
 *
 * Independent of the product document, which is already gone by construction.
 * Every terminal write verifies the worker still owns the lease, so a worker
 * whose lease expired while it was still alive can never clobber the state of
 * the worker that legitimately took over.
 */
async function processPendingMediaCleanup({
  db,
  storage,
  cleanupId,
  now = () => new Date(),
  workerId = `mediaworker-${crypto.randomUUID()}`,
  logger = console,
}) {
  const ref = pendingCleanupRef(db, cleanupId);

  const claim = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return { claimed: false, reason: "absent" };
    const state = snap.data() || {};
    if (state.status !== PENDING_STATUS.PENDING) {
      return { claimed: false, reason: `not_pending:${state.status}` };
    }
    const nowMs = now().getTime();
    const leaseMs = state.leaseExpiresAt
      ? (typeof state.leaseExpiresAt.toMillis === "function"
          ? state.leaseExpiresAt.toMillis()
          : new Date(state.leaseExpiresAt).getTime())
      : 0;
    if (state.leaseOwner && leaseMs > nowMs) {
      return { claimed: false, reason: "leased_by_other_worker" };
    }
    tx.update(ref, {
      leaseOwner: workerId,
      leaseExpiresAt: new Date(nowMs + LEASE_DURATION_MS),
      // Attempts are counted with an increment delta, never a stale absolute
      // read, so overlapping workers cannot lose one another's counts.
      attemptCount: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { claimed: true, state };
  });

  if (!claim.claimed) return { claimed: false, reason: claim.reason };

  const state = claim.state;
  const remaining = Array.isArray(state.remainingPaths) ? state.remainingPaths : [];
  const attemptCount = (Number(state.attemptCount) || 0) + 1;

  /** Terminal/progress write, valid only while this worker still holds the lease. */
  async function settle(update) {
    return db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return { applied: false, reason: "absent" };
      if ((snap.data() || {}).leaseOwner !== workerId) {
        // Lost the lease: another worker owns this record now. Never clear
        // its lease and never overwrite its progress.
        return { applied: false, reason: "lease_lost" };
      }
      tx.update(ref, {
        ...update,
        leaseOwner: null,
        leaseExpiresAt: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { applied: true };
    });
  }

  if (!state.bucketName || !storage) {
    const settled = await settle({
      lastErrorCode: PENDING_ERROR.NO_BUCKET,
      status:
        attemptCount >= MAX_ATTEMPTS
          ? PENDING_STATUS.REQUIRES_MANUAL_REVIEW
          : PENDING_STATUS.PENDING,
      nextAttemptAt: new Date(now().getTime() + backoffMsForAttempt(attemptCount)),
    });
    return { claimed: true, outcome: "no_bucket", ...settled };
  }

  // Exclusivity: the business prefix proves business ownership, not product
  // ownership. Never delete an object another live product still references.
  const exclusivity = await findPathsStillReferenced({
    db,
    businessId: state.businessId,
    bucketName: state.bucketName,
    candidatePaths: remaining,
    excludeProductId: state.productId,
  });

  if (!exclusivity.proven) {
    const settled = await settle({
      status: PENDING_STATUS.REQUIRES_MANUAL_REVIEW,
      lastErrorCode: PENDING_ERROR.EXCLUSIVITY_UNPROVEN,
    });
    return { claimed: true, outcome: "exclusivity_unproven", ...settled };
  }

  const deletable = remaining.filter((p) => !exclusivity.stillReferenced.has(p));
  const retainedShared = remaining.filter((p) => exclusivity.stillReferenced.has(p));

  const bucket = storage.bucket(state.bucketName);
  const stillRemaining = [...retainedShared];
  let deletedCount = 0;
  for (const objectPath of deletable) {
    try {
      // Already absent is idempotent success.
      await bucket.file(objectPath).delete({ ignoreNotFound: true });
      deletedCount += 1;
    } catch (error) {
      // Redacted category only — never the raw message.
      logger.warn("marketplace_pending_media_delete_failed", {
        code: (error && error.code) || "unknown",
      });
      stillRemaining.push(objectPath);
    }
  }

  if (stillRemaining.length === 0) {
    const settled = await settle({
      status: PENDING_STATUS.COMPLETED,
      remainingPaths: [],
      retainedSharedPaths: [],
      lastErrorCode: null,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      nextAttemptAt: null,
    });
    return { claimed: true, outcome: "completed", deletedCount, ...settled };
  }

  // Objects retained because another product still references them are not a
  // failure — they are a settled, auditable outcome, not retried forever.
  if (deletable.length === 0 && retainedShared.length > 0) {
    const settled = await settle({
      status: PENDING_STATUS.COMPLETED,
      remainingPaths: [],
      retainedSharedPaths: retainedShared,
      lastErrorCode: null,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      nextAttemptAt: null,
    });
    return { claimed: true, outcome: "completed_shared_retained", deletedCount, ...settled };
  }

  const terminal = attemptCount >= MAX_ATTEMPTS;
  const settled = await settle({
    status: terminal ? PENDING_STATUS.REQUIRES_MANUAL_REVIEW : PENDING_STATUS.PENDING,
    remainingPaths: stillRemaining,
    retainedSharedPaths: retainedShared,
    lastErrorCode: PENDING_ERROR.DELETE_FAILED,
    nextAttemptAt: terminal
      ? null
      : new Date(now().getTime() + backoffMsForAttempt(attemptCount)),
  });
  return { claimed: true, outcome: terminal ? "manual_review" : "retry_scheduled", deletedCount, ...settled };
}

/**
 * Scheduled resumer.
 *
 * Ordered by `nextAttemptAt` and filtered to records that are actually due,
 * so a poison record with a long backoff cannot occupy the first slots and
 * starve healthy work behind it. Terminal records leave the queue entirely.
 */
async function resumePendingMediaCleanups({
  db,
  storage = null,
  now = () => new Date(),
  limit = 20,
  logger = console,
}) {
  const due = await db
    .collection(PENDING_COLLECTION)
    .where("status", "==", PENDING_STATUS.PENDING)
    .where("nextAttemptAt", "<=", now())
    .orderBy("nextAttemptAt")
    .limit(limit)
    .get();

  const processed = [];
  for (const doc of due.docs) {
    const result = await processPendingMediaCleanup({
      db,
      storage,
      cleanupId: doc.id,
      now,
      logger,
    });
    processed.push({ id: doc.id, outcome: result.outcome || null, claimed: result.claimed });
  }
  return { considered: due.size, processed };
}

module.exports.processPendingMediaCleanup = processPendingMediaCleanup;
module.exports.resumePendingMediaCleanups = resumePendingMediaCleanups;
