"use strict";

// Petsupo Marketplace P1-A compliance foundation — reconciliation for
// stale intermediate-state upload sessions (Slice 2 correction,
// adversarial review 2026-08-21, finding F/B: "critical, no crash
// recovery for uploaded/validating/scan_pending/promotion_pending").
//
// A Storage-triggered pipeline invocation that crashes mid-flight (or is
// never retried — see the explicit `retry: true` config this correction
// also adds to processComplianceQuarantineUpload in functions/index.js)
// can leave a session parked at one of four intermediate states. This
// module is the authoritative, idempotent recovery mechanism for all
// four — Eventarc/Storage redelivery alone is not relied upon (event
// redelivery is not guaranteed, is not itself bounded/retried by this
// system's own policy beyond the platform default, and cannot resume a
// session whose triggering event was never redelivered at all).
//
// Every resume path reuses the SAME functions the fast path calls
// (validateUploadedObject/performValidation, orchestrateComplianceScan,
// performPromotion) — no separate/duplicated business logic exists here,
// only lease acquisition, staleness selection, and dispatch.
//
// Lease discipline: a crashed worker must never permanently own a
// session. Every resume attempt first acquires a lease (leaseOwner +
// leaseExpiresAt, both server-owned — see COMPLIANCE_UPLOAD_SESSION_
// ALLOWED_FIELDS) transactionally; a lease already held by a still-live
// owner is left alone, but an EXPIRED lease is reclaimed by the next
// invocation exactly as if no lease existed. A bounded reconciliation-
// attempt counter (server-owned, incremented on every claim) protects
// against a session that can never actually be resumed (e.g. its
// underlying Storage object is permanently gone) looping forever —
// once exhausted, the session fails closed to scan_failed and releases
// its quota, rather than being retried indefinitely.

const crypto = require("node:crypto");
const admin = require("firebase-admin");
const {
  COMPLIANCE_UPLOAD_SESSION_STATUS,
  COMPLIANCE_RECONCILIATION_LEASE_DURATION_MS,
  COMPLIANCE_RECONCILIATION_MAX_ATTEMPTS,
  COMPLIANCE_RECONCILIATION_PAGE_SIZE,
  COMPLIANCE_UPLOADED_STALE_MS,
  COMPLIANCE_VALIDATING_STALE_MS,
  COMPLIANCE_SCAN_PENDING_STALE_MS,
  COMPLIANCE_PROMOTION_PENDING_STALE_MS,
} = require("./complianceConstants");
const { performValidation, validateUploadedObject } = require("./complianceUploadFinalization");
const {
  orchestrateComplianceScan,
  performPromotion,
  transitionToTerminalWithQuotaRelease,
  deleteQuarantineIfPresent,
} = require("./complianceScanOrchestration");
const { resolveComplianceScanner } = require("./complianceScanner");

const STALE_MS_BY_STATUS = Object.freeze({
  [COMPLIANCE_UPLOAD_SESSION_STATUS.UPLOADED]: COMPLIANCE_UPLOADED_STALE_MS,
  [COMPLIANCE_UPLOAD_SESSION_STATUS.VALIDATING]: COMPLIANCE_VALIDATING_STALE_MS,
  [COMPLIANCE_UPLOAD_SESSION_STATUS.SCAN_PENDING]: COMPLIANCE_SCAN_PENDING_STALE_MS,
  [COMPLIANCE_UPLOAD_SESSION_STATUS.PROMOTION_PENDING]: COMPLIANCE_PROMOTION_PENDING_STALE_MS,
});

function leaseExpiresAtMs(session, nowMs) {
  if (!session.leaseExpiresAt) return 0;
  const value =
    typeof session.leaseExpiresAt.toMillis === "function"
      ? session.leaseExpiresAt.toMillis()
      : new Date(session.leaseExpiresAt).getTime();
  return Number.isFinite(value) ? value : 0;
}

// Transactionally claims (or reclaims an expired) lease on a single
// candidate session. Returns { claimed: true, session } on success, or
// { claimed: false, reason, session? }. `reason: "attempts_exhausted"`
// carries the session data so the caller can fail it closed outside this
// transaction (Storage/document writes never happen inside a Firestore
// transaction body here beyond the lease fields themselves).
async function tryClaimLease({ db, sessionRef, expectedStatus, workerId, now, logger }) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(sessionRef);
    const current = snap.data();
    if (!current || current.status !== expectedStatus) {
      return { claimed: false, reason: "already_progressed" };
    }
    if (current.leaseOwner && leaseExpiresAtMs(current, now.getTime()) > now.getTime()) {
      return { claimed: false, reason: "leased_by_other_worker" };
    }
    const attempts = current.reconciliationAttempts || 0;
    if (attempts >= COMPLIANCE_RECONCILIATION_MAX_ATTEMPTS) {
      return {
        claimed: false,
        reason: "attempts_exhausted",
        session: { ...current, sessionId: sessionRef.id },
      };
    }
    tx.update(sessionRef, {
      leaseOwner: workerId,
      leaseExpiresAt: new Date(now.getTime() + COMPLIANCE_RECONCILIATION_LEASE_DURATION_MS),
      reconciliationAttempts: attempts + 1,
      lastReconciledAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { claimed: true, session: { ...current, sessionId: sessionRef.id, leaseOwner: workerId } };
  });
}

// Clears the lease only if still held by this exact worker — never
// clobbers a lease a later, different claim attempt may have already
// acquired (e.g. if this worker's own resume action already transitioned
// the session to a new status, whatever wrote that transition is
// responsible for its own lease fields; this is a harmless no-op catch
// for the case where it didn't).
async function releaseLeaseIfOwned({ db, sessionRef, workerId, logger }) {
  await db
    .runTransaction(async (tx) => {
      const snap = await tx.get(sessionRef);
      const current = snap.data();
      if (!current || current.leaseOwner !== workerId) return;
      tx.update(sessionRef, {
        leaseOwner: null,
        leaseExpiresAt: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    })
    .catch((err) =>
      logger.error("compliance_reconciliation_release_lease_failed", {
        sessionId: sessionRef.id,
        message: err && err.message,
      })
    );
}

// Rebuilds a Storage-trigger-event-shaped object descriptor from the
// live object's own metadata, generation-pinned to what was recorded at
// claim time — reconciliation never has a real Storage trigger event to
// resume from, only the session's own record of what it claimed.
async function reconstructObjectDescriptor({ bucket, session }) {
  try {
    const [meta] = await bucket
      .file(session.objectPath, { generation: Number(session.uploadedGeneration) })
      .getMetadata();
    return {
      bucket: bucket.name,
      name: session.objectPath,
      contentType: meta.contentType,
      size: meta.size,
      generation: meta.generation,
      metadata: meta.metadata || {},
    };
  } catch (err) {
    return null;
  }
}

async function failObjectMissing({ db, session, expectedStatus }) {
  const sessionRef = db.collection("complianceUploadSessions").doc(session.sessionId);
  await transitionToTerminalWithQuotaRelease({
    db,
    sessionRef,
    businessId: session.businessId,
    uid: session.issuedBy,
    expectedStatuses: [expectedStatus],
    nextStatus: COMPLIANCE_UPLOAD_SESSION_STATUS.VALIDATION_FAILED,
    extraFields: { validationFailureReason: "object_missing_on_reconciliation" },
  });
}

async function resumeUploaded({ db, bucket, session, logger }) {
  const object = await reconstructObjectDescriptor({ bucket, session });
  if (!object) {
    await failObjectMissing({ db, session, expectedStatus: COMPLIANCE_UPLOAD_SESSION_STATUS.UPLOADED });
    return { outcome: "validation_failed", reason: "object_missing_on_reconciliation" };
  }
  return validateUploadedObject({ db, bucket, object, session, logger });
}

async function resumeValidating({ db, bucket, session, logger }) {
  const object = await reconstructObjectDescriptor({ bucket, session });
  if (!object) {
    await failObjectMissing({ db, session, expectedStatus: COMPLIANCE_UPLOAD_SESSION_STATUS.VALIDATING });
    return { outcome: "validation_failed", reason: "object_missing_on_reconciliation" };
  }
  return performValidation({ db, bucket, object, session, logger });
}

async function resumeScanPending({ db, bucket, session, logger, env }) {
  const scanner = resolveComplianceScanner({ env, logger });
  return orchestrateComplianceScan({ db, bucket, session, scanner, object: null, logger });
}

async function resumePromotionPending({ db, bucket, session, logger }) {
  return performPromotion({ db, bucket, session, logger });
}

const RESUME_ACTION_BY_STATUS = Object.freeze({
  [COMPLIANCE_UPLOAD_SESSION_STATUS.UPLOADED]: resumeUploaded,
  [COMPLIANCE_UPLOAD_SESSION_STATUS.VALIDATING]: resumeValidating,
  [COMPLIANCE_UPLOAD_SESSION_STATUS.SCAN_PENDING]: resumeScanPending,
  [COMPLIANCE_UPLOAD_SESSION_STATUS.PROMOTION_PENDING]: resumePromotionPending,
});

// Sweeps a single status's stale candidates: bounded (.limit()), paged,
// deterministically ordered by updatedAt (matches the existing
// [status ASC, updatedAt ASC] Firestore index — no new index required).
// One item's failure (claim error, resume throw) never aborts the rest
// of the page.
async function reconcileStateOnce({ db, bucket, status, staleMs, workerId, now, env, logger }) {
  const cutoff = new Date(now.getTime() - staleMs);
  const snap = await db
    .collection("complianceUploadSessions")
    .where("status", "==", status)
    .where("updatedAt", "<=", cutoff)
    .orderBy("updatedAt", "asc")
    .limit(COMPLIANCE_RECONCILIATION_PAGE_SIZE)
    .get();

  let resumed = 0;
  let skipped = 0;
  let failedClosed = 0;

  for (const doc of snap.docs) {
    const sessionRef = doc.ref;
    let claim;
    try {
      claim = await tryClaimLease({ db, sessionRef, expectedStatus: status, workerId, now, logger });
    } catch (err) {
      logger.error("compliance_reconciliation_claim_failed", {
        sessionId: doc.id,
        status,
        message: err && err.message,
      });
      skipped += 1;
      continue;
    }

    if (!claim.claimed) {
      if (claim.reason === "attempts_exhausted" && claim.session) {
        try {
          await transitionToTerminalWithQuotaRelease({
            db,
            sessionRef,
            businessId: claim.session.businessId,
            uid: claim.session.issuedBy,
            expectedStatuses: [status],
            nextStatus: COMPLIANCE_UPLOAD_SESSION_STATUS.SCAN_FAILED,
            extraFields: { scanFailureReason: "reconciliation_attempts_exhausted" },
          });
          failedClosed += 1;
        } catch (err) {
          logger.error("compliance_reconciliation_fail_closed_failed", {
            sessionId: doc.id,
            message: err && err.message,
          });
        }
      } else {
        skipped += 1;
      }
      continue;
    }

    try {
      const resume = RESUME_ACTION_BY_STATUS[status];
      const result = await resume({ db, bucket, session: claim.session, logger, env });
      logger.info("compliance_reconciliation_resumed", {
        sessionId: claim.session.sessionId,
        status,
        outcome: result && result.outcome,
      });
      resumed += 1;
    } catch (err) {
      logger.error("compliance_reconciliation_resume_failed", {
        sessionId: doc.id,
        status,
        message: err && err.message,
      });
    } finally {
      await releaseLeaseIfOwned({ db, sessionRef, workerId, logger });
    }
  }

  return { status, candidateCount: snap.docs.length, resumed, skipped, failedClosed };
}

// "consumed with quarantine duplicate: delete exact obsolete quarantine
// generation" — a bounded, paged safety net for the case where a
// promotion's post-transaction quarantine delete (performPromotion, or
// this same function's own resume of it) failed and was only logged, not
// retried inline. Generation-pinned, same as every other delete in this
// boundary — reuses the existing [status ASC, updatedAt ASC] index.
async function cleanupConsumedQuarantineDuplicates({ db, bucket, now, logger }) {
  const cutoff = new Date(now.getTime() - COMPLIANCE_PROMOTION_PENDING_STALE_MS);
  const snap = await db
    .collection("complianceUploadSessions")
    .where("status", "==", COMPLIANCE_UPLOAD_SESSION_STATUS.CONSUMED)
    .where("updatedAt", "<=", cutoff)
    .orderBy("updatedAt", "asc")
    .limit(COMPLIANCE_RECONCILIATION_PAGE_SIZE)
    .get();

  let cleaned = 0;
  for (const doc of snap.docs) {
    const session = { ...doc.data(), sessionId: doc.id };
    if (!session.objectPath || !session.uploadedGeneration) continue;
    const [stillExists] = await bucket
      .file(session.objectPath, { generation: Number(session.uploadedGeneration) })
      .exists()
      .catch(() => [false]);
    if (stillExists) {
      const deleted = await deleteQuarantineIfPresent({ bucket, session, logger });
      if (deleted) cleaned += 1;
    }
  }
  return { candidateCount: snap.docs.length, cleaned };
}

// Top-level entry point, wired from a dedicated onSchedule export in
// functions/index.js. Sweeps all four intermediate states plus the
// consumed-quarantine-duplicate safety net, one bounded page each,
// tolerating any single state's sweep failing without aborting the
// others.
async function reconcileStaleComplianceUploadSessions({
  db,
  bucket,
  now,
  env = process.env,
  logger = console,
  workerId,
}) {
  const nowDate = now instanceof Date ? now : new Date(now || Date.now());
  const effectiveWorkerId = workerId || crypto.randomUUID();

  const results = [];
  for (const status of Object.keys(STALE_MS_BY_STATUS)) {
    const result = await reconcileStateOnce({
      db,
      bucket,
      status,
      staleMs: STALE_MS_BY_STATUS[status],
      workerId: effectiveWorkerId,
      now: nowDate,
      env,
      logger,
    }).catch((err) => {
      logger.error("compliance_reconciliation_state_sweep_failed", { status, message: err && err.message });
      return { status, error: true };
    });
    results.push(result);
  }

  const quarantineCleanup = await cleanupConsumedQuarantineDuplicates({
    db,
    bucket,
    now: nowDate,
    logger,
  }).catch((err) => {
    logger.error("compliance_reconciliation_quarantine_cleanup_failed", { message: err && err.message });
    return { error: true };
  });

  logger.info("compliance_reconciliation_run", { workerId: effectiveWorkerId, results, quarantineCleanup });
  return { workerId: effectiveWorkerId, results, quarantineCleanup };
}

module.exports = {
  complianceUploadReconciliation: reconcileStaleComplianceUploadSessions,
  reconcileStaleComplianceUploadSessions,
  reconcileStateOnce,
  cleanupConsumedQuarantineDuplicates,
  tryClaimLease,
  resumeUploaded,
  resumeValidating,
  resumeScanPending,
  resumePromotionPending,
};
