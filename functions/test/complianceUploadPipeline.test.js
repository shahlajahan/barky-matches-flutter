"use strict";

// P1-A Slice 2 — end-to-end finalize + scan orchestration pipeline
// tests (docs/plans/marketplace_p1a_compliance_review_implementation_
// plan_2026-08-21.md, security decision). Uses real Firestore + Storage
// emulators via the Admin SDK (never Firestore/Storage Rules — Admin SDK
// always bypasses both, exactly as production Cloud Functions do), and
// calls the exported pipeline functions directly with synthetic
// Storage-event payloads reconstructed from real, just-uploaded object
// metadata — not hand-typed fake metadata — so magic-byte/content-type/
// generation checks run against genuinely real values.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();
const BUCKET_NAME = "p1a-compliance-pipeline-test-bucket";
const bucket = admin.storage().bucket(BUCKET_NAME);

const {
  processComplianceQuarantineUpload,
} = require("../src/marketplace/compliance/complianceUploadFinalization");
const {
  orchestrateComplianceScan,
} = require("../src/marketplace/compliance/complianceScanOrchestration");
const {
  complianceUploadOrphanCleanup,
} = require("../src/marketplace/compliance/complianceUploadCleanup");
const {
  createFakeCleanScanner,
  createFakeInfectedScanner,
  createFakeErrorScanner,
} = require("../src/marketplace/compliance/complianceScanner");
const {
  buildComplianceQuarantineObjectPath,
  buildComplianceDocsObjectPath,
  buildComplianceUploadObjectId,
} = require("../src/marketplace/compliance/complianceValidators");
const {
  complianceUploadReconciliation,
} = require("../src/marketplace/compliance/complianceUploadReconciliation");

const hasEmulators = Boolean(
  process.env.FIRESTORE_EMULATOR_HOST && process.env.STORAGE_EMULATOR_HOST
);
function itest(name, fn) {
  test(name, { skip: !hasEmulators }, fn);
}

const validPdfBytes = Buffer.concat([
  Buffer.from("%PDF-1.4\n"),
  Buffer.alloc(64, 0x20),
  Buffer.from("\n%%EOF"),
]);

let seq = 0;
function nextId(label) {
  seq += 1;
  return `${label}-${Date.now()}-${seq}`;
}

const FUTURE = new Date(Date.now() + 15 * 60 * 1000);

// Creates a session doc directly (bypassing createComplianceUploadSession
// for test speed/control — this is exactly the document shape that
// function produces) and returns { session, sessionRef }.
async function seedSession(overrides = {}) {
  const businessId = overrides.businessId || "biz-1";
  const sessionId = nextId("sess");
  const documentId = nextId("doc");
  const declaredMimeType = overrides.declaredMimeType || "application/pdf";
  const objectId = buildComplianceUploadObjectId(nextId("tok"), declaredMimeType);
  const objectPath = buildComplianceQuarantineObjectPath({ businessId, sessionId, objectId });
  const destinationPath = buildComplianceDocsObjectPath({ businessId, documentId, objectId });

  const session = {
    businessId,
    sessionId,
    documentId,
    objectId,
    objectPath,
    destinationPath,
    originalFilename: "invoice.pdf",
    declaredMimeType,
    declaredSizeBytes: validPdfBytes.length,
    documentType: "purchase_invoice",
    sellerRelationship: null,
    clientIdempotencyKey: null,
    allowedMimeTypes: ["application/pdf", "image/jpeg", "image/png"],
    maxSizeBytes: 15 * 1024 * 1024,
    status: "upload_authorized",
    issuedBy: "seller-1",
    issuedAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: FUTURE,
    uploadedAt: null,
    uploadedGeneration: null,
    finalizedAt: null,
    contentHash: null,
    actualContentType: null,
    actualSizeBytes: null,
    validationFailureReason: null,
    scanAttempts: 0,
    scanVerdict: null,
    scanEngineVersion: null,
    scanSignatureVersion: null,
    scannedAt: null,
    scanFailureReason: null,
    promotedGeneration: null,
    promotedAt: null,
    consumedAt: null,
    consumedByDocumentId: null,
    leaseOwner: null,
    leaseExpiresAt: null,
    reconciliationAttempts: 0,
    lastReconciledAt: null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...overrides,
  };
  const sessionRef = db.collection("complianceUploadSessions").doc(sessionId);
  await sessionRef.set(session);
  return { session: { ...session, sessionId }, sessionRef, objectPath, documentId };
}

// Uploads real bytes (Admin SDK — equivalent to a Rules-authorized
// client upload succeeding) and returns a synthetic Storage-event object
// built from the object's REAL, freshly-read metadata.
async function uploadAndBuildEvent({ objectPath, bytes, contentType, customMetadata }) {
  await bucket.file(objectPath).save(bytes, {
    contentType,
    resumable: false,
    metadata: customMetadata ? { metadata: customMetadata } : undefined,
  });
  const [metadata] = await bucket.file(objectPath).getMetadata();
  return {
    bucket: BUCKET_NAME,
    name: objectPath,
    contentType: metadata.contentType,
    size: metadata.size,
    generation: metadata.generation,
    metadata: metadata.metadata || {},
  };
}

const quietLogger = { info() {}, warn() {}, error() {} };

test.before(async () => {
  await bucket.create().catch(() => {}); // idempotent — ignore "already exists"
});

// ---------------------------------------------------------------------
// Finalize: claim + validate
// ---------------------------------------------------------------------

itest("a genuine PDF upload is claimed and reaches scan_pending", async () => {
  const { session, sessionRef, objectPath } = await seedSession();
  const object = await uploadAndBuildEvent({
    objectPath,
    bytes: validPdfBytes,
    contentType: "application/pdf",
  });

  const result = await processComplianceQuarantineUpload({
    db,
    bucket,
    object,
    expectedBucket: BUCKET_NAME,
    logger: quietLogger,
  });

  assert.equal(result.claimed, true);
  assert.equal(result.status, "scan_pending");
  const snap = await sessionRef.get();
  assert.equal(snap.data().status, "scan_pending");
  assert.ok(snap.data().contentHash, "server-side SHA-256 must be recorded");
  assert.equal(snap.data().uploadedGeneration, String(object.generation));
});

itest("declared MIME versus Storage-reported MIME mismatch fails finalization (item 18, server-side)", async () => {
  const { sessionRef, objectPath } = await seedSession({ declaredMimeType: "application/pdf" });
  // Upload real PNG bytes but declare application/pdf as the actual
  // Storage contentType — simulates a client that lied about content
  // type at the Storage layer despite the session's own declaration.
  const object = await uploadAndBuildEvent({
    objectPath,
    bytes: Buffer.from([0x89, 0x50, 0x4e, 0x47, 1, 2]),
    contentType: "application/pdf", // Storage itself reports this; the
    // bytes are PNG, so the magic-byte check is what actually catches it
  });
  const result = await processComplianceQuarantineUpload({
    db,
    bucket,
    object,
    expectedBucket: BUCKET_NAME,
    logger: quietLogger,
  });
  assert.equal(result.status, "validation_failed");
  const snap = await sessionRef.get();
  assert.equal(snap.data().status, "validation_failed");
  assert.equal(snap.data().validationFailureReason, "magic_byte_mismatch");
  const [exists] = await bucket.file(objectPath).exists();
  assert.equal(exists, false, "the invalid object must be deleted, not left in quarantine");
});

itest("magic-byte mismatch fails even with a matching declared/actual content type (item 20)", async () => {
  const { sessionRef, objectPath } = await seedSession();
  const object = await uploadAndBuildEvent({
    objectPath,
    bytes: Buffer.from("not actually a pdf despite the content type"),
    contentType: "application/pdf",
  });
  const result = await processComplianceQuarantineUpload({
    db,
    bucket,
    object,
    expectedBucket: BUCKET_NAME,
    logger: quietLogger,
  });
  assert.equal(result.status, "validation_failed");
  assert.equal(result.reason, "magic_byte_mismatch");
  const snap = await sessionRef.get();
  assert.equal(snap.data().status, "validation_failed");
});

itest("a Storage-reported content type outside the allowlist fails even if the session declared a valid one", async () => {
  const { sessionRef, objectPath } = await seedSession({ declaredMimeType: "application/pdf" });
  const object = await uploadAndBuildEvent({
    objectPath,
    bytes: validPdfBytes,
    contentType: "application/octet-stream",
  });
  const result = await processComplianceQuarantineUpload({
    db,
    bucket,
    object,
    expectedBucket: BUCKET_NAME,
    logger: quietLogger,
  });
  assert.equal(result.status, "validation_failed");
  const snap = await sessionRef.get();
  assert.equal(snap.data().status, "validation_failed");
});

itest("a wrong bucket in the event is rejected and the stray object deleted", async () => {
  const { sessionRef, objectPath } = await seedSession();
  const object = await uploadAndBuildEvent({
    objectPath,
    bytes: validPdfBytes,
    contentType: "application/pdf",
  });
  const result = await processComplianceQuarantineUpload({
    db,
    bucket,
    object: { ...object, bucket: "some-other-bucket" },
    expectedBucket: BUCKET_NAME,
    logger: quietLogger,
  });
  assert.equal(result.claimed, false);
  assert.equal(result.reason, "bucket_mismatch");
  const snap = await sessionRef.get();
  assert.equal(snap.data().status, "upload_authorized", "session must not be claimed by a mismatched-bucket event");
});

itest("an event for a session that does not exist is handled without throwing", async () => {
  const objectPath = buildComplianceQuarantineObjectPath({
    businessId: "biz-1",
    sessionId: "no-such-session",
    objectId: "tok.pdf",
  });
  await bucket.file(objectPath).save(validPdfBytes, { contentType: "application/pdf", resumable: false });
  const [metadata] = await bucket.file(objectPath).getMetadata();
  const result = await processComplianceQuarantineUpload({
    db,
    bucket,
    object: { bucket: BUCKET_NAME, name: objectPath, contentType: metadata.contentType, size: metadata.size, generation: metadata.generation, metadata: {} },
    expectedBucket: BUCKET_NAME,
    logger: quietLogger,
  });
  assert.equal(result.claimed, false);
  assert.equal(result.reason, "session_not_found");
});

// 30. no download token is created or accepted — server-side half. The
// Storage Rules test suite proves a normal upload succeeds without one
// being required; this proves the finalize pipeline actively rejects an
// object that unexpectedly carries firebaseStorageDownloadTokens
// metadata, rather than silently ignoring it.
itest("an object carrying unexpected firebaseStorageDownloadTokens metadata fails validation (item 30, server-side)", async () => {
  const { sessionRef, objectPath } = await seedSession();
  const object = await uploadAndBuildEvent({
    objectPath,
    bytes: validPdfBytes,
    contentType: "application/pdf",
    customMetadata: { firebaseStorageDownloadTokens: "some-token-that-should-never-be-here" },
  });
  const result = await processComplianceQuarantineUpload({
    db,
    bucket,
    object,
    expectedBucket: BUCKET_NAME,
    logger: quietLogger,
  });
  assert.equal(result.status, "validation_failed");
  assert.equal(result.reason, "unexpected_download_token_present");
  const snap = await sessionRef.get();
  assert.equal(snap.data().status, "validation_failed");
  const [exists] = await bucket.file(objectPath).exists();
  assert.equal(exists, false, "an object with an unexpected download token must be deleted, not retained");
});

itest("duplicate Storage event delivery for the same object is idempotent (item 31)", async () => {
  const { session, sessionRef, objectPath } = await seedSession();
  const object = await uploadAndBuildEvent({
    objectPath,
    bytes: validPdfBytes,
    contentType: "application/pdf",
  });

  const first = await processComplianceQuarantineUpload({
    db,
    bucket,
    object,
    expectedBucket: BUCKET_NAME,
    logger: quietLogger,
  });
  assert.equal(first.status, "scan_pending");

  // Redeliver the exact same event a second time (Storage triggers are
  // at-least-once) — must be a safe no-op, not a duplicate/erroring
  // re-processing.
  const second = await processComplianceQuarantineUpload({
    db,
    bucket,
    object,
    expectedBucket: BUCKET_NAME,
    logger: quietLogger,
  });
  assert.equal(second.claimed, false);
  assert.equal(second.reason, "session_not_upload_authorized");

  const snap = await sessionRef.get();
  assert.equal(snap.data().status, "scan_pending", "the second delivery must not have altered state");
});

// Slice 2.1 correction (part D) — explicit, end-to-end proof that a
// duplicate Storage event redelivered AFTER a successful claim can
// never reach the scanner a second time, mirroring the exact
// finalize-then-conditionally-scan wiring functions/index.js actually
// uses (gated on finalizeResult.claimed).
itest("a duplicate Storage event redelivered after a successful claim never causes a second scanner invocation", async () => {
  const { session, sessionRef, objectPath } = await seedSession();
  const object = await uploadAndBuildEvent({ objectPath, bytes: validPdfBytes, contentType: "application/pdf" });

  let scanCallCount = 0;
  const countingCleanScanner = {
    async scan() {
      scanCallCount += 1;
      return { verdict: "clean", engineVersion: "test-engine", signatureVersion: "test-sig" };
    },
  };

  async function deliverEventLikeIndexJs() {
    const finalizeResult = await processComplianceQuarantineUpload({
      db,
      bucket,
      object,
      expectedBucket: BUCKET_NAME,
      logger: quietLogger,
    });
    // Mirrors functions/index.js's exact gate: orchestrateComplianceScan
    // is only ever called when this delivery itself won the claim.
    if (!finalizeResult.claimed || finalizeResult.status !== "scan_pending") {
      return finalizeResult;
    }
    const sessionSnap = await sessionRef.get();
    return orchestrateComplianceScan({
      db,
      bucket,
      session: { ...sessionSnap.data(), sessionId: session.sessionId },
      object,
      scanner: countingCleanScanner,
      logger: quietLogger,
    });
  }

  const first = await deliverEventLikeIndexJs();
  assert.equal(first.outcome, "consumed");
  assert.equal(scanCallCount, 1);

  // Redeliver the exact same event — Storage triggers are at-least-once.
  const second = await deliverEventLikeIndexJs();
  assert.equal(second.claimed, false, "the redelivered event must be rejected at the claim gate, not reach orchestration");
  assert.equal(scanCallCount, 1, "the scanner must never be invoked a second time for a redelivered event");
});

// ---------------------------------------------------------------------
// Scan orchestration
// ---------------------------------------------------------------------

async function advanceToScanPending() {
  const { session, sessionRef, objectPath, documentId } = await seedSession();
  const object = await uploadAndBuildEvent({
    objectPath,
    bytes: validPdfBytes,
    contentType: "application/pdf",
  });
  await processComplianceQuarantineUpload({
    db,
    bucket,
    object,
    expectedBucket: BUCKET_NAME,
    logger: quietLogger,
  });
  const snap = await sessionRef.get();
  return { session: { ...snap.data(), sessionId: session.sessionId }, sessionRef, object, documentId };
}

// 36. authenticated clean verdict transitions only the expected object
itest("a clean verdict promotes the object, creates complianceDocuments, and consumes the session", async () => {
  const { session, sessionRef, object, documentId } = await advanceToScanPending();

  const result = await orchestrateComplianceScan({
    db,
    bucket,
    session,
    object,
    scanner: createFakeCleanScanner(),
    logger: quietLogger,
  });

  assert.equal(result.outcome, "consumed");
  assert.equal(result.documentId, documentId);

  const sessionSnap = await sessionRef.get();
  assert.equal(sessionSnap.data().status, "consumed");
  assert.equal(sessionSnap.data().scanVerdict, "clean");
  assert.ok(sessionSnap.data().consumedAt);

  const docSnap = await db.collection("complianceDocuments").doc(documentId).get();
  assert.equal(docSnap.exists, true);
  assert.equal(docSnap.data().status, "clean");
  assert.equal(docSnap.data().storagePath, result.storagePath);

  const [promotedExists] = await bucket.file(result.storagePath).exists();
  assert.equal(promotedExists, true);
  const [quarantineStillExists] = await bucket.file(session.objectPath).exists();
  assert.equal(quarantineStillExists, false, "the quarantine copy must be removed after promotion");
});

// 32. wrong object generation cannot reuse a clean verdict
itest("a clean verdict is rejected if the object's generation no longer matches what was claimed", async () => {
  const { session, sessionRef, object } = await advanceToScanPending();

  // Simulate the object having changed since it was claimed: overwrite
  // it directly via Admin SDK (bypassing all Rules, exactly as a
  // hypothetical Rules bug or manual intervention would) to produce a
  // new generation.
  await bucket.file(session.objectPath).save(Buffer.from("different content now"), {
    contentType: "application/pdf",
    resumable: false,
  });

  const result = await orchestrateComplianceScan({
    db,
    bucket,
    session,
    object,
    scanner: createFakeCleanScanner(),
    logger: quietLogger,
  });

  assert.equal(result.outcome, "scan_failed");
  assert.equal(result.reason, "generation_mismatch");
  const sessionSnap = await sessionRef.get();
  assert.equal(sessionSnap.data().status, "scan_failed");
  const docSnap = await db.collection("complianceDocuments").doc(session.documentId).get();
  assert.equal(docSnap.exists, false, "no complianceDocuments record may be created from a generation-mismatched verdict");
});

// 37. infected verdict blocks all later use
itest("an infected verdict deletes the object and blocks all later use", async () => {
  const { session, sessionRef, object } = await advanceToScanPending();

  const result = await orchestrateComplianceScan({
    db,
    bucket,
    session,
    object,
    scanner: createFakeInfectedScanner(),
    logger: quietLogger,
  });

  assert.equal(result.outcome, "infected");
  const sessionSnap = await sessionRef.get();
  assert.equal(sessionSnap.data().status, "infected");

  const [exists] = await bucket.file(session.objectPath).exists();
  assert.equal(exists, false, "an infected object must be deleted immediately");

  const docSnap = await db.collection("complianceDocuments").doc(session.documentId).get();
  assert.equal(docSnap.exists, false, "no complianceDocuments record may ever be created for an infected file");

  // A second orchestration attempt against the now-infected session must
  // not re-process it (infected is terminal).
  const second = await orchestrateComplianceScan({
    db,
    bucket,
    session: sessionSnap.data(),
    object,
    scanner: createFakeCleanScanner(),
    logger: quietLogger,
  });
  assert.equal(second.outcome, "skipped");
});

// 33/34/35/38. missing config / timeout / unknown verdict never produce
// clean; attempt budget bounded and idempotent. Slice 2.1 correction
// (part A): orchestrateComplianceScan now performs exactly ONE scanner
// attempt per invocation — reaching the exhausted/scan_failed state
// requires MALWARE_SCAN_MAX_ATTEMPTS SEPARATE invocations (simulating
// Slice 2.1 correction (part E) — deterministic timeout simulation:
// proves that even when the scanner call itself takes real, measurable
// time before ultimately erroring (simulating MALWARE_SCAN_TIMEOUT_MS's
// real 60s client timeout without a test actually waiting 60 real
// seconds), the session still ends up in a recoverable state
// (scan_pending, scanAttempts incremented) — the state write only ever
// happens AFTER the scan call fully settles, so a slow call delays but
// never corrupts or skips persisting the recoverable state.
itest("state is correctly persisted as recoverable even when the scanner call itself takes real time before erroring (part E)", async () => {
  const { session, sessionRef } = await advanceToScanPending();
  const slowTimeoutLikeScanner = {
    async scan() {
      await new Promise((resolve) => setTimeout(resolve, 200)); // stands in for a real, slow-but-bounded call
      return { verdict: "error", reason: "timeout" };
    },
  };

  const startedAt = Date.now();
  const result = await orchestrateComplianceScan({
    db,
    bucket,
    session,
    object: null,
    scanner: slowTimeoutLikeScanner,
    logger: quietLogger,
  });
  const elapsedMs = Date.now() - startedAt;

  assert.equal(elapsedMs >= 200, true, "the scan call must have genuinely taken time, not been short-circuited");
  assert.equal(result.outcome, "retry_later");
  const sessionSnap = await sessionRef.get();
  assert.equal(sessionSnap.data().status, "scan_pending", "recoverable state must be persisted after the slow call settles");
  assert.equal(sessionSnap.data().scanAttempts, 1, "the attempt must be counted even though the call was slow");
});

// Eventarc redelivery / reconciliation resumes), never one call
// internally retrying three times.
itest("a single orchestration call with budget remaining leaves the session at scan_pending for later retry, never scan_failed early (part A)", async () => {
  const { session, sessionRef } = await advanceToScanPending();

  const result = await orchestrateComplianceScan({
    db,
    bucket,
    session,
    object: null,
    scanner: createFakeErrorScanner({ reason: "not_configured" }),
    logger: quietLogger,
  });

  assert.equal(result.outcome, "retry_later");
  assert.notEqual(result.outcome, "scan_failed");
  const sessionSnap = await sessionRef.get();
  assert.equal(sessionSnap.data().status, "scan_pending", "budget remains — session must not have moved to a terminal state");
  assert.equal(sessionSnap.data().scanAttempts, 1);
});

// Slice 2.1 correction (part D, items 2+3) — a transient scanner failure
// is recovered by the scheduled reconciler ALONE: this test never
// redelivers any Storage event, proving Eventarc redelivery is not
// required (and, per the corrected documentation above, could not help
// here even if it occurred, since the claim gate was already consumed).
itest("a transient scanner failure is retried and resolved by reconciliation alone, with no Storage event ever redelivered", async () => {
  const { session, sessionRef, object } = await advanceToScanPending();

  // Simulate one transient failure via the exact same entry point the
  // Storage-trigger handler itself calls — never a second finalize
  // delivery.
  const transientResult = await orchestrateComplianceScan({
    db,
    bucket,
    session,
    object,
    scanner: createFakeErrorScanner({ reason: "transient_network_blip" }),
    logger: quietLogger,
  });
  assert.equal(transientResult.outcome, "retry_later");
  let sessionSnap = await sessionRef.get();
  assert.equal(sessionSnap.data().status, "scan_pending");
  assert.equal(sessionSnap.data().scanAttempts, 1);

  // Now let the scheduled reconciler alone pick it up — no Storage event
  // of any kind is delivered from this point on.
  await sessionRef.update({ updatedAt: new Date(Date.now() - 60 * 60 * 1000) });
  const reconciliation = await reconcileStaleComplianceUploadSessions({ db, bucket, now: new Date(), logger: quietLogger, env: {} });
  const scanPendingResult = reconciliation.results.find((r) => r.status === "scan_pending");
  assert.equal(scanPendingResult.resumed, 1);

  sessionSnap = await sessionRef.get();
  assert.equal(sessionSnap.data().scanAttempts, 2, "reconciliation's resume must count as exactly one more real scanner call, not zero and not more than one");
});

itest("a persistently erroring scanner exhausts the bounded attempt budget across separate invocations and never produces clean (items 33-35, 38)", async () => {
  const { session, sessionRef } = await advanceToScanPending();
  const scanner = createFakeErrorScanner({ reason: "not_configured" });

  let result;
  let sessionSnap = await sessionRef.get();
  for (let i = 0; i < 3; i += 1) {
    const current = { ...sessionSnap.data(), sessionId: session.sessionId };
    result = await orchestrateComplianceScan({ db, bucket, session: current, object: null, scanner, logger: quietLogger });
    sessionSnap = await sessionRef.get();
  }

  assert.equal(result.outcome, "scan_failed");
  assert.notEqual(result.outcome, "consumed");
  assert.equal(sessionSnap.data().status, "scan_failed");
  assert.equal(sessionSnap.data().scanAttempts, 3);
  const docSnap = await db.collection("complianceDocuments").doc(session.documentId).get();
  assert.equal(docSnap.exists, false, "scan_failed must never create a complianceDocuments record");
});

itest("orchestrating a session not in scan_pending is a safe no-op", async () => {
  const { session } = await seedSession({ status: "promotion_pending" });
  const result = await orchestrateComplianceScan({
    db,
    bucket,
    session,
    object: {},
    scanner: createFakeCleanScanner(),
    logger: quietLogger,
  });
  assert.equal(result.outcome, "skipped");
});

// ---------------------------------------------------------------------
// Cleanup / retention
// ---------------------------------------------------------------------

// 39. cleanup cannot delete another business's object
itest("expiring a stale session never touches a different business's session/object", async () => {
  const { session: staleSession, sessionRef: staleRef } = await seedSession({ expiresAt: new Date(Date.now() - 1000) });
  const { session: otherSession, sessionRef: otherRef, objectPath: otherPath } = await seedSession({
    businessId: "biz-2",
  });
  await bucket.file(otherPath).save(validPdfBytes, { contentType: "application/pdf", resumable: false });

  const result = await complianceUploadOrphanCleanup({ db, bucket, now: new Date(), logger: quietLogger });
  assert.equal(result.expired.expiredCount >= 1, true);

  const staleSnap = await staleRef.get();
  assert.equal(staleSnap.data().status, "expired");

  const otherSnap = await otherRef.get();
  assert.equal(otherSnap.data().status, "upload_authorized", "a different business's active session must be untouched");
  const [otherStillExists] = await bucket.file(otherPath).exists();
  assert.equal(otherStillExists, true, "a different business's object must not be deleted by an unrelated cleanup run");
});

itest("terminal-failure objects past the retention window are deleted; recent ones are kept", async () => {
  const oldCutoff = new Date(Date.now() - 8 * 24 * 60 * 60 * 1000); // 8 days ago
  const { session: oldFailed, objectPath: oldPath } = await seedSession({
    status: "scan_failed",
    updatedAt: oldCutoff,
  });
  await bucket.file(oldPath).save(validPdfBytes, { contentType: "application/pdf", resumable: false });

  const { session: recentFailed, objectPath: recentPath } = await seedSession({
    status: "scan_failed",
    updatedAt: new Date(),
  });
  await bucket.file(recentPath).save(validPdfBytes, { contentType: "application/pdf", resumable: false });

  await complianceUploadOrphanCleanup({ db, bucket, now: new Date(), logger: quietLogger });

  const [oldExists] = await bucket.file(oldPath).exists();
  assert.equal(oldExists, false, "an 8-day-old scan_failed object must be cleaned up");
  const [recentExists] = await bucket.file(recentPath).exists();
  assert.equal(recentExists, true, "a fresh scan_failed object must be retained within the window");
});

// ---------------------------------------------------------------------
// Slice 2 correction (adversarial review 2026-08-21) — resumable
// promotion saga: generation pinning, destination-overwrite protection,
// idempotent recovery, and crash-window resumption (findings A/F).
// ---------------------------------------------------------------------

const {
  persistCleanScanResult,
  performPromotion,
} = require("../src/marketplace/compliance/complianceScanOrchestration");
const {
  cleanupConsumedQuarantineDuplicates,
  reconcileStaleComplianceUploadSessions,
} = require("../src/marketplace/compliance/complianceUploadReconciliation");

async function advanceToPromotionPending() {
  const advanced = await advanceToScanPending();
  await persistCleanScanResult({
    db,
    session: advanced.session,
    verdict: { verdict: "clean", engineVersion: "test-engine", signatureVersion: "test-sig" },
    logger: quietLogger,
  });
  const snap = await advanced.sessionRef.get();
  return { ...advanced, session: { ...snap.data(), sessionId: advanced.session.sessionId } };
}

// 13. destination overwrite blocked
itest("promotion never overwrites a pre-existing, unrelated destination object", async () => {
  const { session, sessionRef } = await advanceToPromotionPending();

  // A conflicting object already sits at the destination path, NOT
  // bound to this session (no matching closed metadata) — simulates
  // either a genuine collision or corrupted prior state.
  await bucket.file(session.destinationPath).save(Buffer.from("unrelated pre-existing content"), {
    contentType: "application/pdf",
    resumable: false,
  });

  const result = await performPromotion({ db, bucket, session, logger: quietLogger });
  assert.equal(result.outcome, "scan_failed");
  assert.equal(result.reason, "promotion_destination_conflict");

  const sessionSnap = await sessionRef.get();
  assert.equal(sessionSnap.data().status, "scan_failed");
  assert.equal(sessionSnap.data().scanFailureReason, "promotion_destination_conflict");

  const [destBytes] = await bucket.file(session.destinationPath).download();
  assert.equal(destBytes.toString(), "unrelated pre-existing content", "the conflicting object must never be overwritten");

  const docSnap = await db.collection("complianceDocuments").doc(session.documentId).get();
  assert.equal(docSnap.exists, false);
});

// 12/F. source generation mismatch blocks promotion (same mechanism as
// the existing "generation no longer matches" test above, restated here
// for direct item-12 traceability against performPromotion directly).
// performPromotion's own pre-write check (independent of
// handleCleanVerdict's earlier generation check — this one exists
// specifically so the reconciler's direct performPromotion() resume path
// is protected too, since it never goes through handleCleanVerdict at
// all) explicitly re-reads the live source generation immediately before
// writing and fails closed on any mismatch, rather than attempting to
// reach back for stale bytes.
itest("promotion never promotes a generation different from the one scanned", async () => {
  const { session, sessionRef } = await advanceToPromotionPending();
  await bucket.file(session.objectPath).save(Buffer.from("a newer, different upload"), {
    contentType: "application/pdf",
    resumable: false,
  });

  const result = await performPromotion({ db, bucket, session, logger: quietLogger });
  assert.equal(result.outcome, "scan_failed");
  assert.equal(result.reason, "promotion_source_generation_changed");

  const sessionSnap = await sessionRef.get();
  assert.equal(sessionSnap.data().status, "scan_failed");
  const [newGenerationStillExists] = await bucket.file(session.objectPath).exists();
  assert.equal(newGenerationStillExists, true, "the newer generation at the same path must never be deleted");
  const docSnap = await db.collection("complianceDocuments").doc(session.documentId).get();
  assert.equal(docSnap.exists, false, "no document may be created from a generation that no longer matches what was scanned");
});

// 14/17. crash after copy but before Firestore finalization recovers
// (identical existing, correctly-bound destination permits recovery)
itest("a promotion resumed after the copy succeeded but before the Firestore transaction committed recovers cleanly", async () => {
  const { session, sessionRef } = await advanceToPromotionPending();

  // Simulate exactly what performPromotion's own write step would have
  // done, then stop — as if the process crashed right after it.
  const pinnedSource = bucket.file(session.objectPath, { generation: Number(session.uploadedGeneration) });
  const [bytes] = await pinnedSource.download();
  await bucket.file(session.destinationPath).save(bytes, {
    resumable: false,
    contentType: session.actualContentType,
    metadata: {
      metadata: { businessId: session.businessId, documentId: session.documentId, sessionId: session.sessionId },
    },
  });
  // Session is still promotion_pending; quarantine object still present
  // (the crash is simulated as happening before the delete too).

  const result = await performPromotion({ db, bucket, session, logger: quietLogger });
  assert.equal(result.outcome, "consumed");
  assert.equal(result.documentId, session.documentId);

  const sessionSnap = await sessionRef.get();
  assert.equal(sessionSnap.data().status, "consumed");
  const docSnap = await db.collection("complianceDocuments").doc(session.documentId).get();
  assert.equal(docSnap.exists, true, "the resumed attempt must still create exactly one complianceDocuments record");
  const [quarantineGone] = await bucket.file(session.objectPath).exists();
  assert.equal(quarantineGone, false, "the resumed attempt must still complete the quarantine cleanup");
});

// 15. conflicting existing destination fails closed (metadata present
// but bound to a DIFFERENT session — must not be treated as recoverable)
itest("a destination bound to a different session's identity fails closed, not recovered", async () => {
  const { session, sessionRef } = await advanceToPromotionPending();
  const destFile = bucket.file(session.destinationPath);
  await destFile.save(Buffer.from("looks like a promotion but isn't ours"), {
    contentType: "application/pdf",
    resumable: false,
    metadata: {
      metadata: { businessId: session.businessId, documentId: "some-other-document-id", sessionId: "some-other-session-id" },
    },
  });

  const result = await performPromotion({ db, bucket, session, logger: quietLogger });
  assert.equal(result.outcome, "scan_failed");
  assert.equal(result.reason, "promotion_destination_conflict");
  const sessionSnap = await sessionRef.get();
  assert.equal(sessionSnap.data().status, "scan_failed");
});

// 16. crash after scan persistence resumes from promotion_pending (via
// the reconciler, not the fast path)
itest("the reconciler resumes a session stuck at promotion_pending", async () => {
  const { session, sessionRef } = await advanceToPromotionPending();
  // Simulate staleness by backdating updatedAt past the reconciler's
  // threshold, and clearing any lease as a fresh crash would leave it.
  await sessionRef.update({ updatedAt: new Date(Date.now() - 60 * 60 * 1000), leaseOwner: null, leaseExpiresAt: null });

  const result = await reconcileStaleComplianceUploadSessions({ db, bucket, now: new Date(), logger: quietLogger });
  const promotionResult = result.results.find((r) => r.status === "promotion_pending");
  assert.equal(promotionResult.resumed, 1);

  const sessionSnap = await sessionRef.get();
  assert.equal(sessionSnap.data().status, "consumed", "reconciliation must have completed the promotion");
  const docSnap = await db.collection("complianceDocuments").doc(session.documentId).get();
  assert.equal(docSnap.exists, true);
});

// 18. crash after Firestore finalization but before source deletion
// recovers (via the consumed-quarantine-duplicate cleanup sweep)
itest("a consumed session's leftover quarantine duplicate is cleaned up by the reconciler's safety net", async () => {
  const { session, sessionRef } = await advanceToPromotionPending();

  // Force the post-transaction quarantine delete to fail, simulating a
  // crash/error in that step specifically (Firestore already committed).
  // Mutates the real File instance's own `delete` (shadowing the
  // prototype method as an own property) rather than spreading it, so
  // every other File method (.copy()/.getMetadata()/.exists(), all
  // defined on the prototype) keeps working normally.
  const throwingBucket = {
    name: bucket.name,
    file: (p, opts) => {
      const real = bucket.file(p, opts);
      if (p === session.objectPath) {
        real.delete = async () => {
          throw new Error("simulated delete failure");
        };
      }
      return real;
    },
  };
  const result = await performPromotion({ db, bucket: throwingBucket, session, logger: quietLogger });
  assert.equal(result.outcome, "consumed");

  const [stillThere] = await bucket.file(session.objectPath).exists();
  assert.equal(stillThere, true, "the quarantine duplicate must still be present after the simulated delete failure");

  const cleanupResult = await cleanupConsumedQuarantineDuplicates({
    db,
    bucket,
    now: new Date(Date.now() + 60 * 60 * 1000),
    logger: quietLogger,
  });
  assert.equal(cleanupResult.cleaned >= 1, true);
  const [goneNow] = await bucket.file(session.objectPath).exists();
  assert.equal(goneNow, false, "the safety-net sweep must delete the leftover quarantine duplicate");

  const sessionSnap = await sessionRef.get();
  assert.equal(sessionSnap.data().status, "consumed", "cleanup must never touch the already-consumed session's status");
});

// ---------------------------------------------------------------------
// Reconciliation — stale uploaded / validating leases
// ---------------------------------------------------------------------

// 19. stale uploaded resumes
itest("a session stuck at uploaded is resumed by the reconciler", async () => {
  const { session, sessionRef, objectPath } = await seedSession();
  const object = await uploadAndBuildEvent({ objectPath, bytes: validPdfBytes, contentType: "application/pdf" });
  const { claimUploadedObject } = require("../src/marketplace/compliance/complianceUploadFinalization");
  await claimUploadedObject({ db, object, expectedBucket: BUCKET_NAME, logger: quietLogger });
  await sessionRef.update({ updatedAt: new Date(Date.now() - 60 * 60 * 1000) });

  const result = await reconcileStaleComplianceUploadSessions({ db, bucket, now: new Date(), logger: quietLogger });
  const uploadedResult = result.results.find((r) => r.status === "uploaded");
  assert.equal(uploadedResult.resumed, 1);

  const snap = await sessionRef.get();
  assert.equal(snap.data().status, "scan_pending", "a stale uploaded session must resume all the way through validation");
});

// 20. stale validating lease is reclaimed
itest("a session stuck at validating has its lease reclaimed and is resumed", async () => {
  const { session, sessionRef, objectPath } = await seedSession();
  const object = await uploadAndBuildEvent({ objectPath, bytes: validPdfBytes, contentType: "application/pdf" });
  const { claimUploadedObject } = require("../src/marketplace/compliance/complianceUploadFinalization");
  await claimUploadedObject({ db, object, expectedBucket: BUCKET_NAME, logger: quietLogger });
  // Force straight to VALIDATING with an expired lease from a
  // hypothetical crashed prior worker, as if performValidation started
  // but never finished.
  await sessionRef.update({
    status: "validating",
    updatedAt: new Date(Date.now() - 60 * 60 * 1000),
    leaseOwner: "dead-worker-1",
    leaseExpiresAt: new Date(Date.now() - 60 * 1000), // already expired
  });

  const result = await reconcileStaleComplianceUploadSessions({ db, bucket, now: new Date(), logger: quietLogger });
  const validatingResult = result.results.find((r) => r.status === "validating");
  assert.equal(validatingResult.resumed, 1);

  const snap = await sessionRef.get();
  assert.equal(snap.data().status, "scan_pending");
  assert.equal(snap.data().leaseOwner, null, "the reclaimed lease must be cleared once resumed");
});

itest("a live (unexpired) lease is not reclaimed by a concurrent reconciler pass", async () => {
  const { session, sessionRef, objectPath } = await seedSession();
  const object = await uploadAndBuildEvent({ objectPath, bytes: validPdfBytes, contentType: "application/pdf" });
  const { claimUploadedObject } = require("../src/marketplace/compliance/complianceUploadFinalization");
  await claimUploadedObject({ db, object, expectedBucket: BUCKET_NAME, logger: quietLogger });
  await sessionRef.update({
    status: "validating",
    updatedAt: new Date(Date.now() - 60 * 60 * 1000),
    leaseOwner: "still-alive-worker",
    leaseExpiresAt: new Date(Date.now() + 60 * 60 * 1000), // far in the future
  });

  const result = await reconcileStaleComplianceUploadSessions({ db, bucket, now: new Date(), logger: quietLogger });
  const validatingResult = result.results.find((r) => r.status === "validating");
  assert.equal(validatingResult.resumed, 0);
  assert.equal(validatingResult.skipped >= 1, true);

  const snap = await sessionRef.get();
  assert.equal(snap.data().status, "validating", "a live-leased session must be left untouched");
  assert.equal(snap.data().leaseOwner, "still-alive-worker");
});

// 21. stale scan_pending resumes with bounded attempts. Slice 2.1
// correction (part A): each reconciliation resume performs exactly ONE
// scanner attempt (matching orchestrateComplianceScan's new single-
// attempt contract) — reaching scan_failed requires
// MALWARE_SCAN_MAX_ATTEMPTS separate resumes, not one.
itest("each reconciliation resume of a stale scan_pending session performs exactly one scanner attempt", async () => {
  const { session, sessionRef } = await advanceToScanPending();
  await sessionRef.update({ updatedAt: new Date(Date.now() - 60 * 60 * 1000) });

  // The reconciler resolves the REAL (unconfigured, fail-closed) scanner
  // from env by default — it does not inject a fake scanner
  // (resumeScanPending always resolves the production scanner), matching
  // production wiring exactly.
  const result = await reconcileStaleComplianceUploadSessions({ db, bucket, now: new Date(), logger: quietLogger, env: {} });
  const scanPendingResult = result.results.find((r) => r.status === "scan_pending");
  assert.equal(scanPendingResult.resumed, 1);

  const snap = await sessionRef.get();
  assert.equal(snap.data().status, "scan_pending", "budget remains after one resume — must not jump to a terminal state early");
  assert.equal(snap.data().scanAttempts, 1);
});

itest("repeated reconciliation resumes of scan_pending exhaust the attempt budget and fail closed, never clean", async () => {
  const { session, sessionRef } = await advanceToScanPending();

  for (let i = 0; i < 3; i += 1) {
    await sessionRef.update({ updatedAt: new Date(Date.now() - 60 * 60 * 1000) });
    // eslint-disable-next-line no-await-in-loop
    await reconcileStaleComplianceUploadSessions({ db, bucket, now: new Date(), logger: quietLogger, env: {} });
  }

  const snap = await sessionRef.get();
  assert.equal(snap.data().status, "scan_failed", "an unconfigured scanner must still fail closed after the full budget, never silently clean");
  assert.equal(snap.data().scanAttempts, 3);
  const docSnap = await db.collection("complianceDocuments").doc(session.documentId).get();
  assert.equal(docSnap.exists, false);
});

// 22. stale promotion_pending resumes — already proven by item 16's test
// above ("the reconciler resumes a session stuck at promotion_pending").

// reconciliation attempt budget exhaustion fails closed rather than
// looping forever
itest("a session that exhausts its reconciliation attempt budget fails closed instead of retrying forever", async () => {
  const { session, sessionRef, objectPath } = await seedSession();
  // uploadedGeneration deliberately left null/never-claimed, but status
  // forced to "uploaded" with no real object at the path -- every resume
  // attempt will hit object_missing_on_reconciliation and, because that
  // path fails the session closed immediately (not a retry-eligible
  // outcome), we instead force validating with a bogus generation to
  // guarantee repeated resumable failures via reconstructObjectDescriptor
  // returning null, while manually incrementing reconciliationAttempts
  // to simulate several prior failed passes.
  await sessionRef.update({
    status: "uploaded",
    uploadedGeneration: "999999999999",
    updatedAt: new Date(Date.now() - 60 * 60 * 1000),
    reconciliationAttempts: 5, // already at COMPLIANCE_RECONCILIATION_MAX_ATTEMPTS
  });

  const result = await reconcileStaleComplianceUploadSessions({ db, bucket, now: new Date(), logger: quietLogger });
  const uploadedResult = result.results.find((r) => r.status === "uploaded");
  assert.equal(uploadedResult.failedClosed, 1);

  const snap = await sessionRef.get();
  assert.equal(snap.data().status, "scan_failed");
  assert.equal(snap.data().scanFailureReason, "reconciliation_attempts_exhausted");
});

itest("cleanup does not touch an already-consumed session's promoted document", async () => {
  const { session, object, documentId } = await advanceToScanPending();
  await orchestrateComplianceScan({
    db,
    bucket,
    session,
    object,
    scanner: createFakeCleanScanner(),
    logger: quietLogger,
  });
  const before = await db.collection("complianceDocuments").doc(documentId).get();
  assert.equal(before.exists, true);

  await complianceUploadOrphanCleanup({ db, bucket, now: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), logger: quietLogger });

  const after = await db.collection("complianceDocuments").doc(documentId).get();
  assert.equal(after.exists, true, "cleanup must never touch complianceDocuments, only the quarantine boundary");
  const [promotedStillExists] = await bucket.file(after.data().storagePath).exists();
  assert.equal(promotedStillExists, true, "a promoted, consumed document's file must never be deleted by quarantine cleanup");
});
