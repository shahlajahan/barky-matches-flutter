"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { handleScanRequest } = require("../src/scanHandler");
const { createFakeGcsReader, createFakeClamdScanner } = require("../src/fakeAdapters");
const { CONTRACT_VERSION } = require("../src/contract");

const ALLOWED_BUCKET = "barkymatches-new.firebasestorage.app";
const quietLogger = { info() {}, warn() {}, error() {} };

function baseConfig(overrides = {}) {
  return {
    allowedBucket: ALLOWED_BUCKET,
    engineVersion: "clamav-1.2.3",
    signatureVersion: "sig-9",
    signatureBuiltAt: new Date(Date.now() - 60 * 60 * 1000).toISOString(),
    tmpDir: os.tmpdir(),
    ...overrides,
  };
}

function requestFor(content) {
  const sha256 = crypto.createHash("sha256").update(content).digest("hex");
  return {
    contractVersion: CONTRACT_VERSION,
    requestId: "req-1",
    bucket: ALLOWED_BUCKET,
    objectPath: "compliance_quarantine/biz-1/sess-1/tok.pdf",
    generation: "111",
    sha256,
    sizeBytes: content.length,
  };
}

test("an invalid request is rejected with 400 before any GCS/clamd call", async () => {
  const gcsReader = createFakeGcsReader({ content: Buffer.from("x") });
  const clamdScanner = createFakeClamdScanner({ outcome: "clean" });
  const result = await handleScanRequest({
    body: { contractVersion: CONTRACT_VERSION }, // missing required fields
    config: baseConfig(),
    gcsReader,
    clamdScanner,
    logger: quietLogger,
  });
  assert.equal(result.status, 400);
  assert.equal(gcsReader.calls.length, 0);
  assert.equal(clamdScanner.calls.length, 0);
});

test("a genuine clean scan returns a fully-bound clean response", async () => {
  const content = Buffer.from("a synthetic, entirely safe test document");
  const request = requestFor(content);
  const gcsReader = createFakeGcsReader({ content });
  const clamdScanner = createFakeClamdScanner({ outcome: "clean" });

  const result = await handleScanRequest({ body: request, config: baseConfig(), gcsReader, clamdScanner, logger: quietLogger });

  assert.equal(result.status, 200);
  assert.equal(result.body.verdict, "clean");
  assert.equal(result.body.requestId, request.requestId);
  assert.equal(result.body.bucket, request.bucket);
  assert.equal(result.body.objectPath, request.objectPath);
  assert.equal(result.body.generation, request.generation);
  assert.equal(result.body.sha256, request.sha256);
  assert.equal(result.body.sizeBytes, request.sizeBytes);
  assert.equal(result.body.engineVersion, "clamav-1.2.3");
  // Exactly one, generation-pinned GCS download call — the only GCS
  // interaction this handler ever performs.
  assert.equal(gcsReader.calls.length, 1);
  assert.equal(gcsReader.calls[0].bucket, request.bucket);
  assert.equal(gcsReader.calls[0].objectPath, request.objectPath);
  assert.equal(gcsReader.calls[0].generation, request.generation);
});

test("an infected verdict is surfaced exactly, never coerced", async () => {
  const content = Buffer.from("synthetic eicar-like payload");
  const request = requestFor(content);
  const gcsReader = createFakeGcsReader({ content });
  const clamdScanner = createFakeClamdScanner({ outcome: "infected", signatureName: "Eicar-Test-Signature" });

  const result = await handleScanRequest({ body: request, config: baseConfig(), gcsReader, clamdScanner, logger: quietLogger });
  assert.equal(result.body.verdict, "infected");
});

// Slice 2.1 correction, part C.
test("an encrypted/unsupported heuristic outcome fails closed as error with a stable errorCode, never infected, never clean", async () => {
  const content = Buffer.from("synthetic encrypted-pdf-like payload");
  const request = requestFor(content);
  const gcsReader = createFakeGcsReader({ content });
  const clamdScanner = createFakeClamdScanner({
    outcome: "unsupported",
    signatureName: "Heuristics.Encrypted.PDF",
    message: "encrypted_document_unsupported",
  });

  const result = await handleScanRequest({ body: request, config: baseConfig(), gcsReader, clamdScanner, logger: quietLogger });
  assert.equal(result.body.verdict, "error");
  assert.equal(result.body.errorCode, "encrypted_document_unsupported");
  assert.notEqual(result.body.verdict, "infected");
  assert.notEqual(result.body.verdict, "clean");
});

test("a SHA-256 mismatch between declared and downloaded content fails closed, never clean", async () => {
  const actualContent = Buffer.from("what is actually stored at this generation");
  const request = requestFor(Buffer.from("a completely different declared payload"));
  request.sizeBytes = actualContent.length; // size matches, hash does not
  const gcsReader = createFakeGcsReader({ content: actualContent });
  const clamdScanner = createFakeClamdScanner({ outcome: "clean" }); // scanner would say clean if reached

  const result = await handleScanRequest({ body: request, config: baseConfig(), gcsReader, clamdScanner, logger: quietLogger });
  assert.equal(result.body.verdict, "error");
  assert.equal(result.body.errorCode, "content_mismatch");
  // The scanner must never even be invoked once content is provably
  // inconsistent with what was declared.
  assert.equal(clamdScanner.calls.length, 0);
});

test("a sizeBytes mismatch between declared and downloaded content fails closed, never clean", async () => {
  const actualContent = Buffer.from("some real content of one length");
  const request = requestFor(actualContent);
  request.sizeBytes = actualContent.length + 1; // now inconsistent
  const gcsReader = createFakeGcsReader({ content: actualContent });
  const clamdScanner = createFakeClamdScanner({ outcome: "clean" });

  const result = await handleScanRequest({ body: request, config: baseConfig(), gcsReader, clamdScanner, logger: quietLogger });
  assert.equal(result.body.verdict, "error");
  assert.equal(result.body.errorCode, "content_mismatch");
  assert.equal(clamdScanner.calls.length, 0);
});

test("a GCS download failure fails closed with a safe error code, never throws out of the handler", async () => {
  const request = requestFor(Buffer.from("irrelevant"));
  const gcsReader = createFakeGcsReader({ error: new Error("simulated 404 from GCS") });
  const clamdScanner = createFakeClamdScanner({ outcome: "clean" });

  const result = await handleScanRequest({ body: request, config: baseConfig(), gcsReader, clamdScanner, logger: quietLogger });
  assert.equal(result.body.verdict, "error");
  assert.equal(result.body.errorCode, "gcs_download_failed");
});

// ---------------------------------------------------------------------
// Error mapping (F.11) — every clamd outcome other than an explicit
// "clean" must map to verdict: error with a stable, safe errorCode.
// ---------------------------------------------------------------------

test("a clamd timeout maps to errorCode clamd_timeout, never clean", async () => {
  const content = Buffer.from("x");
  const request = requestFor(content);
  const gcsReader = createFakeGcsReader({ content });
  const clamdScanner = createFakeClamdScanner({ outcome: "error", message: "clamd_scan_timeout" });
  const result = await handleScanRequest({ body: request, config: baseConfig(), gcsReader, clamdScanner, logger: quietLogger });
  assert.equal(result.body.verdict, "error");
  assert.equal(result.body.errorCode, "clamd_timeout");
});

test("an unparseable clamd reply maps to a stable errorCode, never clean", async () => {
  const content = Buffer.from("x");
  const request = requestFor(content);
  const gcsReader = createFakeGcsReader({ content });
  const clamdScanner = createFakeClamdScanner({ outcome: "error", message: "unparseable_clamd_response" });
  const result = await handleScanRequest({ body: request, config: baseConfig(), gcsReader, clamdScanner, logger: quietLogger });
  assert.equal(result.body.verdict, "error");
  assert.equal(result.body.errorCode, "clamd_unparseable_response");
});

test("a scanner that throws is treated as error, never an unhandled crash, never clean", async () => {
  const content = Buffer.from("x");
  const request = requestFor(content);
  const gcsReader = createFakeGcsReader({ content });
  const clamdScanner = { async scanBuffer() { throw new Error("unexpected socket failure"); } };
  await assert.rejects(
    handleScanRequest({ body: request, config: baseConfig(), gcsReader, clamdScanner, logger: quietLogger })
  );
  // handleScanRequest itself does not catch a thrown scanBuffer — this
  // is intentional: the HTTP layer (server.js) catches it and returns
  // 500, and the Functions-side client already treats any non-2xx/
  // malformed response as verdict: error, never clean. Documented here
  // so the boundary is explicit, not accidental.
});

test("an unrecognized outcome value from the scanner is still never treated as clean", async () => {
  const content = Buffer.from("x");
  const request = requestFor(content);
  const gcsReader = createFakeGcsReader({ content });
  const clamdScanner = createFakeClamdScanner({ outcome: "something_unexpected" });
  const result = await handleScanRequest({ body: request, config: baseConfig(), gcsReader, clamdScanner, logger: quietLogger });
  assert.equal(result.body.verdict, "error");
});

// ---------------------------------------------------------------------
// Temp-file lifecycle (F.14)
// ---------------------------------------------------------------------

test("the private temporary file is removed after a successful scan", async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "scanner-test-"));
  const content = Buffer.from("temp file lifecycle test content");
  const request = requestFor(content);
  const gcsReader = createFakeGcsReader({ content });
  const clamdScanner = createFakeClamdScanner({ outcome: "clean" });

  await handleScanRequest({ body: request, config: baseConfig({ tmpDir }), gcsReader, clamdScanner, logger: quietLogger });

  const remaining = await fs.readdir(tmpDir);
  assert.equal(remaining.length, 0, "no temp file should remain after a successful scan");
  await fs.rmdir(tmpDir);
});

test("the private temporary file is removed even when the scan itself errors", async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "scanner-test-"));
  const content = Buffer.from("temp file lifecycle test content on error path");
  const request = requestFor(content);
  const gcsReader = createFakeGcsReader({ content });
  const clamdScanner = createFakeClamdScanner({ outcome: "error", message: "clamd_scan_timeout" });

  await handleScanRequest({ body: request, config: baseConfig({ tmpDir }), gcsReader, clamdScanner, logger: quietLogger });

  const remaining = await fs.readdir(tmpDir);
  assert.equal(remaining.length, 0, "no temp file should remain even after an error outcome");
  await fs.rmdir(tmpDir);
});
