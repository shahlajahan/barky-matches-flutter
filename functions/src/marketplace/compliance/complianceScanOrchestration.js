"use strict";

// Petsupo Marketplace P1-A compliance foundation — malware-scan
// orchestration boundary (docs/plans/marketplace_p1a_compliance_review_
// implementation_plan_2026-08-21.md, Slice 2 security decision). Calls
// the injected MalwareScanner (never resolves one itself — the caller,
// functions/index.js, decides which scanner to use, so production code
// always gets resolveComplianceScanner()'s real, possibly-unconfigured
// adapter and tests always get an explicit fake), applies the verdict
// with bounded retries, and is the ONLY place a session is ever marked
// infected, scan_failed, or moved into the promotion saga.
//
// Fail-closed by construction: every code path that is not an explicit
// verdict === 'clean' from the scanner leaves the session at
// scan_pending (retry) or moves it to scan_failed (retries exhausted) —
// there is no path in this file that can produce a promoted document
// without the scanner itself having said so.
//
// Slice 2 correction (adversarial review 2026-08-21, finding A/F —
// "critical, no crash recovery"): a clean verdict no longer promotes the
// Storage object before persisting anything. It is now a two-step,
// resumable saga:
//   1. persistCleanScanResult(): scan_pending -> promotion_pending,
//      binding bucket/objectPath/generation/hash/size/mime/engine
//      version/signature version/scannedAt to the session. Still fully
//      unusable for evidence/approval — no complianceDocuments record
//      exists yet.
//   2. performPromotion(): promotion_pending -> consumed. Idempotent and
//      safe to call more than once (fresh session read, generation-
//      pinned copy with a create-only destination precondition,
//      identity-verified recovery if the destination already exists,
//      then a single Firestore transaction that creates the
//      complianceDocuments record and consumes the session together,
//      and only then a generation-pinned quarantine delete).
// The reconciler (complianceUploadReconciliation.js) calls
// performPromotion() directly to resume any session found stuck at
// promotion_pending after a crash — it is exported for exactly that
// reuse, not only called from the fast path below.

const admin = require("firebase-admin");
const {
  COMPLIANCE_UPLOAD_SESSION_STATUS,
  COMPLIANCE_DOCUMENT_STATUS,
  MALWARE_SCAN_VERDICT,
  MALWARE_SCAN_MAX_ATTEMPTS,
  MALWARE_SCAN_RETRY_BACKOFF_MS,
} = require("./complianceConstants");
const { releaseActiveUploadQuota } = require("./complianceUploadQuota");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Runs the scanner up to MALWARE_SCAN_MAX_ATTEMPTS times (bounded),
// short backoff between attempts (bounded), stopping early on the first
// clean or infected verdict — only a run of 'error' results exhausts the
// full attempt budget.
async function runScanWithBoundedRetries({ scanner, request, startingAttempts, logger }) {
  let attempts = startingAttempts;
  let lastResult = { verdict: MALWARE_SCAN_VERDICT.ERROR, reason: "not_attempted" };

  while (attempts < MALWARE_SCAN_MAX_ATTEMPTS) {
    attempts += 1;
    try {
      lastResult = await scanner.scan(request);
    } catch (err) {
      logger.error("compliance_scan_threw", { message: err && err.message, attempts });
      lastResult = { verdict: MALWARE_SCAN_VERDICT.ERROR, reason: "scanner_threw" };
    }

    if (!Object.values(MALWARE_SCAN_VERDICT).includes(lastResult.verdict)) {
      // Defense in depth even against a scanner implementation bug: an
      // unrecognized verdict string is treated exactly like 'error'.
      lastResult = { verdict: MALWARE_SCAN_VERDICT.ERROR, reason: "unknown_verdict" };
    }

    if (lastResult.verdict !== MALWARE_SCAN_VERDICT.ERROR) {
      return { attempts, result: lastResult };
    }
    if (attempts < MALWARE_SCAN_MAX_ATTEMPTS) {
      await sleep(MALWARE_SCAN_RETRY_BACKOFF_MS);
    }
  }
  return { attempts, result: lastResult };
}

// Shared terminal-transition helper: transactionally moves a session
// from one of `expectedStatuses` to `nextStatus`, releasing its active
// upload quota exactly once in the same transaction. A no-op (returns
// false, releases nothing) if the session has already left every status
// in `expectedStatuses` — the idempotency guard every call site below
// relies on to make duplicate delivery / concurrent reconciliation safe.
async function transitionToTerminalWithQuotaRelease({
  db,
  sessionRef,
  businessId,
  uid,
  expectedStatuses,
  nextStatus,
  extraFields = {},
}) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(sessionRef);
    const current = snap.data();
    if (!current || !expectedStatuses.includes(current.status)) {
      return false;
    }
    tx.update(sessionRef, {
      status: nextStatus,
      ...extraFields,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    releaseActiveUploadQuota({ tx, db, businessId, uid });
    return true;
  });
}

// Generation-pinned, best-effort quarantine delete — never throws. Used
// both by the main promotion path (after the finalize transaction
// commits) and by the reconciler's "consumed session with a leftover
// quarantine duplicate" resume case.
async function deleteQuarantineIfPresent({ bucket, session, logger }) {
  if (!session.objectPath || !session.uploadedGeneration) return false;
  try {
    await bucket
      .file(session.objectPath, { generation: Number(session.uploadedGeneration) })
      .delete({ ignoreNotFound: true });
    return true;
  } catch (err) {
    logger.error("compliance_promotion_quarantine_cleanup_failed", {
      sessionId: session.sessionId,
      message: err && err.message,
    });
    return false;
  }
}

// Step 1 of the clean-verdict saga: persists the verified scan result
// and moves scan_pending -> promotion_pending. Idempotent — a no-op
// (returns false) if the session is not currently scan_pending (already
// progressed by another delivery or a racing reconciliation attempt).
// Never touches Storage and never releases/consumes quota — the session
// still occupies its active-session slot all the way through
// promotion_pending, released only at final consumption or terminal
// failure.
async function persistCleanScanResult({ db, session, verdict, logger = console }) {
  const sessionRef = db.collection("complianceUploadSessions").doc(session.sessionId);
  const scannedAt = admin.firestore.FieldValue.serverTimestamp();

  const committed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(sessionRef);
    const current = snap.data();
    if (!current || current.status !== COMPLIANCE_UPLOAD_SESSION_STATUS.SCAN_PENDING) {
      return false;
    }
    tx.update(sessionRef, {
      status: COMPLIANCE_UPLOAD_SESSION_STATUS.PROMOTION_PENDING,
      scanVerdict: verdict.verdict,
      scanEngineVersion: verdict.engineVersion || null,
      scanSignatureVersion: verdict.signatureVersion || null,
      scannedAt,
      leaseOwner: null,
      leaseExpiresAt: null,
      reconciliationAttempts: 0,
      updatedAt: scannedAt,
    });
    return true;
  });

  if (!committed) {
    logger.info("compliance_persist_clean_scan_result_skipped", { sessionId: session.sessionId });
  }
  return committed;
}

// Step 2 of the clean-verdict saga, and the reconciler's sole resume
// action for a stale promotion_pending session. Always re-reads the
// session fresh (never trusts a possibly-stale caller-supplied snapshot,
// since a reconciliation resume calls this with only a snapshot taken by
// its own earlier query). Safe to call more than once for the same
// session, including concurrently:
//   - if already CONSUMED: idempotent no-op (still attempts the
//     quarantine cleanup, in case an earlier attempt's post-transaction
//     delete failed).
//   - if not PROMOTION_PENDING (and not CONSUMED): skipped — the
//     session is not in a state this function can act on.
//   - if PROMOTION_PENDING: generation-pinned copy with a create-only
//     destination precondition. If the destination already exists,
//     verifies it is provably this exact session's own prior attempt
//     (via the closed metadata this function always writes) before
//     treating it as a safe recovery point; otherwise fails closed.
async function performPromotion({ db, bucket, session: sessionArg, logger = console }) {
  const sessionRef = db.collection("complianceUploadSessions").doc(sessionArg.sessionId);
  const freshSnap = await sessionRef.get();
  if (!freshSnap.exists) {
    return { outcome: "skipped", reason: "session_not_found" };
  }
  const session = { ...freshSnap.data(), sessionId: sessionArg.sessionId };

  if (session.status === COMPLIANCE_UPLOAD_SESSION_STATUS.CONSUMED) {
    await deleteQuarantineIfPresent({ bucket, session, logger });
    return {
      outcome: "consumed",
      documentId: session.documentId,
      storagePath: session.destinationPath,
      alreadyConsumed: true,
    };
  }
  if (session.status !== COMPLIANCE_UPLOAD_SESSION_STATUS.PROMOTION_PENDING) {
    return { outcome: "skipped", reason: "session_not_promotion_pending" };
  }

  const destFile = bucket.file(session.destinationPath);
  const closedMetadata = {
    businessId: session.businessId,
    documentId: session.documentId,
    sessionId: session.sessionId,
  };

  const failClosed = (reason) =>
    transitionToTerminalWithQuotaRelease({
      db,
      sessionRef,
      businessId: session.businessId,
      uid: session.issuedBy,
      expectedStatuses: [COMPLIANCE_UPLOAD_SESSION_STATUS.PROMOTION_PENDING],
      nextStatus: COMPLIANCE_UPLOAD_SESSION_STATUS.SCAN_FAILED,
      extraFields: { scanFailureReason: reason },
    });

  // Explicit, non-inheriting write rather than File#copy() (Slice 2
  // correction verification finding — three separate emulator/API
  // behaviors were empirically checked against the real Storage
  // emulator, not assumed from documentation alone, and two of them
  // changed this design):
  //   1. Neither a source File's {generation} binding NOR
  //      preconditionOpts.ifGenerationMatch is enforced by the local
  //      emulator's copy()/rewriteTo OR save() implementations — both
  //      silently no-op (confirmed via a throwaway debug harness, since
  //      removed). Real GCS documents and enforces both, but this code
  //      does not rely on either alone: the explicit exists()/generation
  //      checks below are the actual correctness mechanism, not a
  //      precondition query parameter.
  //   2. File#copy()'s `metadata` option is NOT applied as a destination
  //      resource-field override by the emulator — it was observed
  //      landing, mangled, inside the destination's own custom-metadata
  //      map instead of setting real top-level fields.
  //   3. Even a same-call setMetadata({metadata: {key: null}}) — the
  //      documented way to delete a custom-metadata key — did NOT
  //      remove a firebaseStorageDownloadTokens key already present in
  //      inherited metadata (confirmed via a throwaway debug harness).
  //      "copy, then strip" is therefore not a safe way to guarantee a
  //      closed destination metadata map for this specific key.
  // The design that survives all three findings: download the source
  // bytes and .save() the destination fresh, with the closed metadata
  // map passed directly as the write's own metadata — there is no
  // "source" for a plain save() to inherit anything from, so no
  // stripping step is needed or relied upon.
  const [destExists] = await destFile.exists();
  if (destExists) {
    const [existingMeta] = await destFile.getMetadata().catch(() => [null]);
    const boundToThisSession =
      existingMeta &&
      existingMeta.metadata &&
      existingMeta.metadata.sessionId === session.sessionId &&
      existingMeta.metadata.documentId === session.documentId &&
      existingMeta.metadata.businessId === session.businessId;
    if (!boundToThisSession) {
      logger.error("compliance_promotion_destination_conflict", { sessionId: session.sessionId });
      await failClosed("promotion_destination_conflict");
      return { outcome: "scan_failed", reason: "promotion_destination_conflict" };
    }
    // Provably our own prior attempt's object — skip the write entirely
    // and fall through to finalize (idempotent recovery).
  } else {
    const pinnedSource = bucket.file(session.objectPath, { generation: Number(session.uploadedGeneration) });
    const [liveSourceMeta] = await bucket.file(session.objectPath).getMetadata().catch(() => [null]);
    if (!liveSourceMeta || String(liveSourceMeta.generation) !== String(session.uploadedGeneration)) {
      logger.error("compliance_promotion_source_generation_changed", {
        sessionId: session.sessionId,
        expected: session.uploadedGeneration,
        actual: liveSourceMeta && liveSourceMeta.generation,
      });
      await failClosed("promotion_source_generation_changed");
      return { outcome: "scan_failed", reason: "promotion_source_generation_changed" };
    }

    try {
      const [bytes] = await pinnedSource.download();
      await destFile.save(bytes, {
        resumable: false,
        contentType: session.actualContentType || session.declaredMimeType,
        metadata: { metadata: closedMetadata },
        preconditionOpts: { ifGenerationMatch: 0 },
      });
    } catch (err) {
      logger.error("compliance_promotion_write_failed", {
        sessionId: session.sessionId,
        message: err && err.message,
      });
      await failClosed("promotion_copy_failed");
      return { outcome: "scan_failed", reason: "promotion_copy_failed" };
    }
  }

  const [destMetadata] = await destFile.getMetadata();
  const documentRef = db.collection("complianceDocuments").doc(session.documentId);

  const finalizeResult = await db.runTransaction(async (tx) => {
    const [sessSnap, docSnap] = await Promise.all([tx.get(sessionRef), tx.get(documentRef)]);
    const current = sessSnap.data();
    if (!current) return { outcome: "skipped" };
    if (current.status === COMPLIANCE_UPLOAD_SESSION_STATUS.CONSUMED) {
      return { outcome: "already_consumed" };
    }
    if (current.status !== COMPLIANCE_UPLOAD_SESSION_STATUS.PROMOTION_PENDING) {
      return { outcome: "skipped" };
    }

    const consumedAt = admin.firestore.FieldValue.serverTimestamp();
    if (!docSnap.exists) {
      tx.create(documentRef, {
        businessId: session.businessId,
        sessionId: session.sessionId,
        documentType: session.documentType,
        sellerRelationship: session.sellerRelationship || null,
        storagePath: session.destinationPath,
        originalFilename: session.originalFilename,
        contentHash: session.contentHash,
        sizeBytes: session.actualSizeBytes,
        version: 1,
        supersedesDocumentId: null,
        supersededByDocumentId: null,
        issuedAt: null,
        validFrom: null,
        validUntil: null,
        status: COMPLIANCE_DOCUMENT_STATUS.CLEAN,
        uploadedBy: session.issuedBy,
        uploadedAt: session.uploadedAt || consumedAt,
        reviewedBy: null,
        reviewedAt: null,
        rejectionReason: null,
        infoRequestNote: null,
        revokedBy: null,
        revokedAt: null,
        revocationReason: null,
      });
    }
    tx.update(sessionRef, {
      status: COMPLIANCE_UPLOAD_SESSION_STATUS.CONSUMED,
      promotedGeneration: String(destMetadata.generation),
      promotedAt: consumedAt,
      consumedAt,
      consumedByDocumentId: session.documentId,
      leaseOwner: null,
      leaseExpiresAt: null,
      updatedAt: consumedAt,
    });
    releaseActiveUploadQuota({ tx, db, businessId: session.businessId, uid: session.issuedBy });
    return { outcome: "committed" };
  });

  if (finalizeResult.outcome === "skipped") {
    return { outcome: "skipped", reason: "session_not_promotion_pending" };
  }

  // Only after the Firestore transaction has durably committed (or a
  // concurrent invocation already committed it for us) do we delete the
  // quarantine source — generation-pinned, so this can never delete a
  // different, newer object that happens to land at the same path.
  await deleteQuarantineIfPresent({ bucket, session, logger });

  return { outcome: "consumed", documentId: session.documentId, storagePath: session.destinationPath };
}

async function applyInfectedVerdict({ db, bucket, session, verdict, logger }) {
  const sessionRef = db.collection("complianceUploadSessions").doc(session.sessionId);

  const applied = await transitionToTerminalWithQuotaRelease({
    db,
    sessionRef,
    businessId: session.businessId,
    uid: session.issuedBy,
    expectedStatuses: [COMPLIANCE_UPLOAD_SESSION_STATUS.SCAN_PENDING],
    nextStatus: COMPLIANCE_UPLOAD_SESSION_STATUS.INFECTED,
    extraFields: {
      scanVerdict: verdict.verdict,
      scanEngineVersion: verdict.engineVersion || null,
      scanSignatureVersion: verdict.signatureVersion || null,
      scannedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  });
  if (!applied) {
    return { outcome: "skipped", reason: "already_progressed" };
  }

  // Immediate, idempotent quarantine deletion — an infected file is
  // never retained "just in case". ignoreNotFound makes a duplicate
  // delivery's second delete attempt a safe no-op.
  await bucket
    .file(session.objectPath)
    .delete({ ignoreNotFound: true })
    .catch((err) =>
      logger.error("compliance_scan_infected_delete_failed", { message: err && err.message })
    );

  // Security-safe audit log: no file contents, no document URL, no
  // signed URL — only the coordinates already safe to log (session/
  // business identity, verdict metadata). Malware signature details are
  // intentionally not surfaced here beyond the scanner's own engine/
  // signature version, and this is never returned to the seller.
  logger.warn("compliance_scan_infected", {
    sessionId: session.sessionId,
    businessId: session.businessId,
    engineVersion: verdict.engineVersion || null,
  });

  return { outcome: "infected" };
}

async function applyScanFailure({ db, session, attempts, reason, logger }) {
  const sessionRef = db.collection("complianceUploadSessions").doc(session.sessionId);

  const applied = await transitionToTerminalWithQuotaRelease({
    db,
    sessionRef,
    businessId: session.businessId,
    uid: session.issuedBy,
    expectedStatuses: [COMPLIANCE_UPLOAD_SESSION_STATUS.SCAN_PENDING],
    nextStatus: COMPLIANCE_UPLOAD_SESSION_STATUS.SCAN_FAILED,
    extraFields: { scanAttempts: attempts, scanFailureReason: reason || "retries_exhausted" },
  });
  logger.error("compliance_scan_failed", { sessionId: session.sessionId, attempts, reason, applied });
  return { outcome: "scan_failed", reason: reason || "retries_exhausted" };
}

// Runs the generation-match check, then the two-step clean-verdict saga
// (persistCleanScanResult -> performPromotion) back to back. This is the
// fast/common path — a crash between the two steps is exactly what
// leaves a session at promotion_pending for the reconciler to resume via
// performPromotion() directly (see complianceUploadReconciliation.js).
async function handleCleanVerdict({ db, bucket, session, verdict, logger }) {
  const sessionRef = db.collection("complianceUploadSessions").doc(session.sessionId);

  // "A clean verdict may transition only the exact immutable object
  // generation that was scanned. If the object changes, the previous
  // scan result is invalid." — re-read the live object's generation and
  // require it still match what was claimed at upload time before
  // trusting this verdict at all.
  const [liveMetadata] = await bucket.file(session.objectPath).getMetadata();
  if (String(liveMetadata.generation) !== String(session.uploadedGeneration)) {
    logger.error("compliance_scan_generation_mismatch", {
      sessionId: session.sessionId,
      expected: session.uploadedGeneration,
      actual: liveMetadata.generation,
    });
    await transitionToTerminalWithQuotaRelease({
      db,
      sessionRef,
      businessId: session.businessId,
      uid: session.issuedBy,
      expectedStatuses: [COMPLIANCE_UPLOAD_SESSION_STATUS.SCAN_PENDING],
      nextStatus: COMPLIANCE_UPLOAD_SESSION_STATUS.SCAN_FAILED,
      extraFields: { scanFailureReason: "generation_mismatch" },
    });
    return { outcome: "scan_failed", reason: "generation_mismatch" };
  }

  const persisted = await persistCleanScanResult({ db, session, verdict, logger });
  if (!persisted) {
    return { outcome: "skipped", reason: "already_progressed" };
  }

  return performPromotion({ db, bucket, session, logger });
}

// Entry point. `session` must already be in scan_pending (the finalize
// pipeline's job, or a reconciliation resume). Bounded retries happen
// inside runScanWithBoundedRetries; this function applies exactly one of
// three outcomes: clean (persist + promote, resumable), infected
// (delete + mark), or scan_failed (retries exhausted / persistent
// misconfiguration).
async function orchestrateComplianceScan({ db, bucket, session, scanner, object, logger = console }) {
  if (session.status !== COMPLIANCE_UPLOAD_SESSION_STATUS.SCAN_PENDING) {
    return { outcome: "skipped", reason: "session_not_scan_pending" };
  }

  const request = {
    bucket: bucket.name,
    objectPath: session.objectPath,
    generation: session.uploadedGeneration,
    sha256: session.contentHash,
    sizeBytes: session.actualSizeBytes,
  };

  const { attempts, result } = await runScanWithBoundedRetries({
    scanner,
    request,
    startingAttempts: session.scanAttempts || 0,
    logger,
  });

  // Persist the attempt count regardless of outcome, so a later
  // invocation (if this one is retried by the platform) knows how many
  // attempts have already been spent against the bounded budget.
  await db
    .collection("complianceUploadSessions")
    .doc(session.sessionId)
    .update({ scanAttempts: attempts, updatedAt: admin.firestore.FieldValue.serverTimestamp() });

  if (result.verdict === MALWARE_SCAN_VERDICT.CLEAN) {
    return handleCleanVerdict({ db, bucket, session, verdict: result, logger });
  }
  if (result.verdict === MALWARE_SCAN_VERDICT.INFECTED) {
    return applyInfectedVerdict({ db, bucket, session, verdict: result, logger });
  }
  // Every remaining case is 'error' (misconfiguration, timeout, malformed
  // response, auth failure, unknown verdict) with attempts exhausted —
  // never a silent pass to clean.
  return applyScanFailure({ db, session, attempts, reason: result.reason, logger });
}

module.exports = {
  orchestrateComplianceScan,
  runScanWithBoundedRetries,
  persistCleanScanResult,
  performPromotion,
  handleCleanVerdict,
  applyInfectedVerdict,
  applyScanFailure,
  deleteQuarantineIfPresent,
  transitionToTerminalWithQuotaRelease,
};
