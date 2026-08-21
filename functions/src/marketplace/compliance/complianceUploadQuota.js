"use strict";

// Petsupo Marketplace P1-A compliance foundation — upload session quota
// (Slice 2 correction, adversarial review 2026-08-21 finding B: "no
// abuse/cost controls"). Two independent, server-only counters, scoped
// to (businessId, uid):
//
//   - complianceUploadQuotaScopes/{scopeId}: `activeSessionCount`, a
//     concurrent-cap counter incremented when a session is created and
//     decremented exactly once when that same session first reaches any
//     terminal status (expired/validation_failed/scan_failed/infected/
//     cancelled/consumed). Not day-scoped — it reflects "how many
//     sessions are this business's owner currently occupying a slot
//     with right now", not a rate.
//   - complianceUploadQuotaDaily/{dailyDocId}: `createdSessionCount` and
//     `declaredBytesCreated`, a UTC-calendar-day rate/volume bucket.
//     Incremented only at creation, never decremented — the bucket
//     "resets" simply because a new UTC day produces a new document id
//     (see getUtcDateKey in complianceValidators.js). No cron/reset job
//     exists or is needed for this.
//
// Both checks and both increments happen inside the SAME Firestore
// transaction that creates the session document (see
// complianceUploadSessions.js) — never a separate read-then-write, so a
// burst of concurrent identical-scope requests cannot race past the
// limit (Firestore serializes conflicting transactions on the same
// document; a losing transaction is retried by the SDK against the
// now-updated counter, never blind-overwrites it).
//
// No exports.* Cloud Function, no onCall endpoint exists for this module
// — quota is enforced only as a side effect of session creation, per the
// explicit instruction not to expose a generic quota-update endpoint.

const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");
const {
  COMPLIANCE_MAX_ACTIVE_UPLOAD_SESSIONS_PER_SCOPE,
  COMPLIANCE_MAX_UPLOAD_SESSIONS_PER_SCOPE_PER_UTC_DAY,
  COMPLIANCE_MAX_UPLOAD_BYTES_PER_SCOPE_PER_UTC_DAY,
  COMPLIANCE_UPLOAD_QUOTA_SCOPE_COLLECTION,
  COMPLIANCE_UPLOAD_QUOTA_DAILY_COLLECTION,
} = require("./complianceConstants");
const {
  getUtcDateKey,
  buildComplianceUploadQuotaScopeId,
  buildComplianceUploadQuotaDailyDocId,
} = require("./complianceValidators");

// Reads both quota documents (inside the caller's transaction), checks
// every limit, and returns the exact writes the caller must perform if
// (and only if) it goes on to actually create the session. Throws a
// stable HttpsError('resource-exhausted', ...) — never partially applies
// a write — if any limit would be exceeded. Callers must invoke this
// BEFORE any session-creation write in the same transaction, and must
// not call it at all on an idempotent no-op reuse (a retry that resolves
// to the existing session must never consume quota twice).
async function checkAndReserveUploadQuota({ tx, db, businessId, uid, declaredSizeBytes, now }) {
  const scopeId = buildComplianceUploadQuotaScopeId({ businessId, uid });
  const utcDateKey = getUtcDateKey(now instanceof Date ? now : new Date(now || Date.now()));
  const dailyDocId = buildComplianceUploadQuotaDailyDocId({ businessId, uid, utcDateKey });

  const scopeRef = db.collection(COMPLIANCE_UPLOAD_QUOTA_SCOPE_COLLECTION).doc(scopeId);
  const dailyRef = db.collection(COMPLIANCE_UPLOAD_QUOTA_DAILY_COLLECTION).doc(dailyDocId);

  const [scopeSnap, dailySnap] = await Promise.all([tx.get(scopeRef), tx.get(dailyRef)]);
  const scopeData = scopeSnap.exists ? scopeSnap.data() : null;
  const dailyData = dailySnap.exists ? dailySnap.data() : null;

  const activeSessionCount = (scopeData && scopeData.activeSessionCount) || 0;
  const createdSessionCount = (dailyData && dailyData.createdSessionCount) || 0;
  const declaredBytesCreated = (dailyData && dailyData.declaredBytesCreated) || 0;

  if (activeSessionCount >= COMPLIANCE_MAX_ACTIVE_UPLOAD_SESSIONS_PER_SCOPE) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many active compliance upload sessions for this business. Complete or let an existing session expire before starting another."
    );
  }
  if (createdSessionCount >= COMPLIANCE_MAX_UPLOAD_SESSIONS_PER_SCOPE_PER_UTC_DAY) {
    throw new HttpsError(
      "resource-exhausted",
      "Daily compliance upload session limit reached for this business. Try again after 00:00 UTC."
    );
  }
  if (declaredBytesCreated + declaredSizeBytes > COMPLIANCE_MAX_UPLOAD_BYTES_PER_SCOPE_PER_UTC_DAY) {
    throw new HttpsError(
      "resource-exhausted",
      "Daily compliance upload byte quota reached for this business. Try again after 00:00 UTC."
    );
  }

  return {
    apply(txRef) {
      const serverNow = admin.firestore.FieldValue.serverTimestamp();
      txRef.set(
        scopeRef,
        {
          businessId,
          uid,
          activeSessionCount: admin.firestore.FieldValue.increment(1),
          updatedAt: serverNow,
        },
        { merge: true }
      );
      txRef.set(
        dailyRef,
        {
          businessId,
          uid,
          utcDateKey,
          createdSessionCount: admin.firestore.FieldValue.increment(1),
          declaredBytesCreated: admin.firestore.FieldValue.increment(declaredSizeBytes),
          updatedAt: serverNow,
        },
        { merge: true }
      );
    },
  };
}

// Decrements the active-session counter exactly once, inside whatever
// transaction is performing the session's first-ever transition into a
// terminal status. Every call site (expiry sweep, validation-failure
// path, infected/scan-failed/consumed verdict paths) already guards this
// with a transactional "has this session already left its expected
// pre-terminal status" check before calling this — so double-release on
// duplicate event delivery or reconciliation re-entry is not possible by
// construction, not by a floor-at-zero clamp here.
function releaseActiveUploadQuota({ tx, db, businessId, uid }) {
  const scopeId = buildComplianceUploadQuotaScopeId({ businessId, uid });
  const scopeRef = db.collection(COMPLIANCE_UPLOAD_QUOTA_SCOPE_COLLECTION).doc(scopeId);
  tx.set(
    scopeRef,
    {
      businessId,
      uid,
      activeSessionCount: admin.firestore.FieldValue.increment(-1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

module.exports = {
  checkAndReserveUploadQuota,
  releaseActiveUploadQuota,
};
