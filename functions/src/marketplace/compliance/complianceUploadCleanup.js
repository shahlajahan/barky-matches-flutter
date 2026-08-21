"use strict";

// Petsupo Marketplace P1-A compliance foundation — quarantine cleanup
// and expiry (docs/plans/marketplace_p1a_compliance_review_
// implementation_plan_2026-08-21.md, Slice 2). Two concerns, kept
// separate: (1) sessions that were never uploaded to before their
// upload_authorized window expired; (2) quarantine objects left behind
// by a terminal failure outcome (validation_failed / scan_failed /
// infected), retained for a bounded investigation window before final
// deletion. This never touches complianceDocuments — once an object is
// promoted to compliance_docs/ and a document exists, it has left this
// module's boundary entirely (docs/plans/... explicit instruction: "Do
// not delete evidence that has reached an active compliance/evidence
// lifecycle outside this Slice 2 quarantine boundary").

const admin = require("firebase-admin");
const {
  COMPLIANCE_UPLOAD_SESSION_STATUS,
  COMPLIANCE_UPLOAD_ORPHAN_RETENTION_DAYS,
  COMPLIANCE_CLEANUP_PAGE_SIZE,
} = require("./complianceConstants");
const { buildComplianceQuarantineObjectPath } = require("./complianceValidators");
const { releaseActiveUploadQuota } = require("./complianceUploadQuota");

// Slice 2 correction (adversarial review 2026-08-21, finding G): never
// trust session.objectPath merely because it appears in Firestore —
// re-derive it from the session's own immutable identity fields
// (businessId/sessionId/objectId, the exact same builder Storage Rules'
// own path documentation and session creation both use) and require an
// exact match before ever deleting anything at that path.
function verifiedObjectPath(session) {
  if (!session || !session.objectPath) return null;
  const rederived = buildComplianceQuarantineObjectPath({
    businessId: session.businessId,
    sessionId: session.sessionId,
    objectId: session.objectId,
  });
  return rederived === session.objectPath ? session.objectPath : null;
}

// Sessionless orphans (Slice 2 correction, finding G) — a quarantine
// object whose owning session document was deleted or never existed.
// Storage Rules make client-side creation of such an object impossible
// (every write requires a live, matching, upload_authorized session —
// see storage.rules and the emulator test proving this); the only way
// one could exist is an operational anomaly (e.g. a session document
// manually deleted out from under a live object). A full-bucket listing
// to find these is DELIBERATELY NOT implemented here — an unbounded
// `bucket.getFiles({ prefix: 'compliance_quarantine/' })` scan is
// exactly the unbounded-cost pattern this correction removes elsewhere,
// and would only grow more expensive as the prefix accumulates objects
// over time. Documented operational procedure instead: if a sessionless
// orphan is ever suspected, run a bounded, prefix- and time-scoped
// `bucket.getFiles({ prefix, maxResults, startOffset })` listing by hand
// (paged, with an explicit stop condition) via an authenticated
// operator, cross-reference each result's businessId/sessionId path
// segments against complianceUploadSessions, and delete generation-
// pinned matches with no owning document. This is intentionally a
// manual/audited procedure, not an automated recurring sweep, until real
// operational volume justifies building a bounded automated one.
async function deleteObjectIfExists({ bucket, objectPath, logger }) {
  if (!objectPath) return false;
  try {
    const [exists] = await bucket.file(objectPath).exists();
    if (!exists) return false;
    await bucket.file(objectPath).delete({ ignoreNotFound: true });
    return true;
  } catch (err) {
    logger.error("compliance_cleanup_delete_failed", {
      objectPath,
      message: err && err.message,
    });
    return false;
  }
}

// (1) upload_authorized sessions whose expiresAt has passed with no
// upload ever claimed. Idempotent: the transactional status check means
// a session already moved on (by a late-arriving upload) is left alone.
async function expireStaleUploadSessions({ db, bucket, now, logger = console }) {
  const nowDate = now instanceof Date ? now : new Date(now || Date.now());
  // Slice 2 correction (finding G): bounded, deterministically-ordered
  // page instead of an unbounded snapshot — matches the existing
  // [status ASC, expiresAt ASC] composite index. A backlog larger than
  // one page is simply picked up again on the next scheduled run (every
  // status-transition here is itself idempotent, so partial progress
  // across runs is always safe to resume).
  const snap = await db
    .collection("complianceUploadSessions")
    .where("status", "==", COMPLIANCE_UPLOAD_SESSION_STATUS.UPLOAD_AUTHORIZED)
    .where("expiresAt", "<=", nowDate)
    .orderBy("expiresAt", "asc")
    .limit(COMPLIANCE_CLEANUP_PAGE_SIZE)
    .get();

  let expiredCount = 0;
  for (const doc of snap.docs) {
    const ref = doc.ref;
    const claimed = await db.runTransaction(async (tx) => {
      const fresh = await tx.get(ref);
      const data = fresh.data();
      if (data.status !== COMPLIANCE_UPLOAD_SESSION_STATUS.UPLOAD_AUTHORIZED) {
        return null; // already progressed since the query ran
      }
      tx.update(ref, {
        status: COMPLIANCE_UPLOAD_SESSION_STATUS.EXPIRED,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      releaseActiveUploadQuota({ tx, db, businessId: data.businessId, uid: data.issuedBy });
      return { ...data, sessionId: doc.id };
    });
    if (!claimed) continue;
    expiredCount += 1;
    // Defensive check only — no object should exist for a session that
    // never left upload_authorized, since Storage Rules require exactly
    // that status to authorize a create. Guards against a theoretical
    // Rules/session-state race, not an expected case. objectPath is
    // re-derived and verified, never trusted blindly (finding G).
    const objectPath = verifiedObjectPath(claimed);
    if (objectPath) {
      await deleteObjectIfExists({ bucket, objectPath, logger });
    } else if (claimed.objectPath) {
      logger.error("compliance_cleanup_object_path_mismatch", { sessionId: claimed.sessionId });
    }
  }
  return { expiredCount, candidateCount: snap.docs.length };
}

// (2) terminal-failure sessions (validation_failed / scan_failed /
// infected) whose quarantine object is still present after the
// retention window. validation_failed and infected objects are already
// deleted synchronously at the point of failure (see
// complianceUploadFinalization.js / complianceScanOrchestration.js) —
// this is the eventual-consistency safety net for that deletion, plus
// the primary deletion point for scan_failed, whose object is
// deliberately retained for the full window in case of investigation or
// a future manual re-scan.
async function cleanupTerminalFailureObjects({ db, bucket, now, logger = console }) {
  const nowMs = now instanceof Date ? now.getTime() : now || Date.now();
  const cutoff = new Date(nowMs - COMPLIANCE_UPLOAD_ORPHAN_RETENTION_DAYS * 24 * 60 * 60 * 1000);

  // Slice 2 correction (finding G): bounded, deterministically-ordered
  // page (matches the existing [status ASC, updatedAt ASC] composite
  // index) instead of an unbounded snapshot.
  const snap = await db
    .collection("complianceUploadSessions")
    .where("status", "in", [
      COMPLIANCE_UPLOAD_SESSION_STATUS.VALIDATION_FAILED,
      COMPLIANCE_UPLOAD_SESSION_STATUS.SCAN_FAILED,
      COMPLIANCE_UPLOAD_SESSION_STATUS.INFECTED,
    ])
    .where("updatedAt", "<=", cutoff)
    .orderBy("updatedAt", "asc")
    .limit(COMPLIANCE_CLEANUP_PAGE_SIZE)
    .get();

  let deletedCount = 0;
  for (const doc of snap.docs) {
    const data = { ...doc.data(), sessionId: doc.id };
    const objectPath = verifiedObjectPath(data);
    if (!objectPath) {
      if (data.objectPath) {
        logger.error("compliance_cleanup_object_path_mismatch", { sessionId: doc.id });
      }
      continue;
    }
    const deleted = await deleteObjectIfExists({ bucket, objectPath, logger });
    if (deleted) deletedCount += 1;
  }
  return { deletedCount, candidateCount: snap.docs.length };
}

// Orphan cleanup never touches a session/business it does not itself
// scope the query to — every operation above resolves objectPath from
// the session document itself (never a client-supplied path), so a
// cleanup run can only ever delete an object that a specific session it
// already read genuinely owns; there is no code path that accepts an
// externally-supplied businessId/path to delete.
async function complianceUploadOrphanCleanup({ db, bucket, now, logger = console }) {
  const [expired, terminalCleanup] = await Promise.all([
    expireStaleUploadSessions({ db, bucket, now, logger }),
    cleanupTerminalFailureObjects({ db, bucket, now, logger }),
  ]);
  logger.info("compliance_upload_orphan_cleanup_run", { expired, terminalCleanup });
  return { expired, terminalCleanup };
}

module.exports = {
  complianceUploadOrphanCleanup,
  expireStaleUploadSessions,
  cleanupTerminalFailureObjects,
  deleteObjectIfExists,
  verifiedObjectPath,
};
