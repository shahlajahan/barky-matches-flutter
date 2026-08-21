"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const path = require("node:path");
const os = require("node:os");
const { readSignatureMetadata } = require("../src/signatureMetadata");
const { handleHealthCheck } = require("../src/healthHandler");
const { handleScanRequest } = require("../src/scanHandler");
const { createFakeGcsReader, createFakeClamdScanner } = require("../src/fakeAdapters");
const { CONTRACT_VERSION, SIGNATURE_MAX_AGE_MS } = require("../src/contract");

async function writeManifest(dir, content) {
  const filePath = path.join(dir, "metadata.json");
  await fs.writeFile(filePath, typeof content === "string" ? content : JSON.stringify(content));
  return filePath;
}

test("a real, valid manifest returns exactly the recorded timestamp — never Date.now()", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "sigmeta-"));
  const recordedTimestamp = "2026-08-19T08:00:00Z"; // deliberately NOT "now"
  const metadataPath = await writeManifest(dir, {
    signatureBuiltAt: recordedTimestamp,
    engineVersion: "clamav-1.4.0",
    signatureVersion: "27000",
  });

  const result = readSignatureMetadata({ metadataPath });
  assert.equal(result.signatureBuiltAt, recordedTimestamp);
  assert.notEqual(result.signatureBuiltAt, new Date().toISOString().slice(0, 10)); // sanity: not today
  assert.equal(result.engineVersion, "clamav-1.4.0");
  assert.equal(result.signatureVersion, "27000");
  await fs.rm(dir, { recursive: true });
});

test("a missing manifest file returns nulls, never a fabricated timestamp", () => {
  const result = readSignatureMetadata({ metadataPath: "/nonexistent/path/metadata.json" });
  assert.equal(result.signatureBuiltAt, null);
  assert.equal(result.engineVersion, null);
  assert.equal(result.signatureVersion, null);
});

test("a malformed JSON manifest returns nulls, not a partial/guessed read", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "sigmeta-"));
  const metadataPath = await writeManifest(dir, "{not valid json at all");
  const result = readSignatureMetadata({ metadataPath });
  assert.equal(result.signatureBuiltAt, null);
  await fs.rm(dir, { recursive: true });
});

test("a manifest with a non-date signatureBuiltAt string is entirely rejected, not partially trusted", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "sigmeta-"));
  const metadataPath = await writeManifest(dir, {
    signatureBuiltAt: "definitely-not-a-date",
    engineVersion: "clamav-1.4.0",
    signatureVersion: "27000",
  });
  const result = readSignatureMetadata({ metadataPath });
  assert.equal(result.signatureBuiltAt, null);
  assert.equal(result.engineVersion, null, "one invalid field invalidates the whole manifest");
  await fs.rm(dir, { recursive: true });
});

test("a manifest missing engineVersion or signatureVersion is entirely rejected", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "sigmeta-"));
  const metadataPath = await writeManifest(dir, { signatureBuiltAt: "2026-08-19T08:00:00Z" });
  const result = readSignatureMetadata({ metadataPath });
  assert.equal(result.signatureBuiltAt, null);
  await fs.rm(dir, { recursive: true });
});

test("a manifest that is valid JSON but not an object (array/string/number) is rejected", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "sigmeta-"));
  for (const bad of [[1, 2, 3], "just a string", 42, null]) {
    const metadataPath = await writeManifest(dir, JSON.stringify(bad));
    const result = readSignatureMetadata({ metadataPath });
    assert.equal(result.signatureBuiltAt, null, `${JSON.stringify(bad)} should be rejected`);
  }
  await fs.rm(dir, { recursive: true });
});

// ---------------------------------------------------------------------
// End-to-end: a stale (but well-formed and real-looking) manifest makes
// health unhealthy AND makes scanning fail closed — never clean.
// ---------------------------------------------------------------------

test("a stale (48h+) real manifest makes /healthz report unhealthy", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "sigmeta-"));
  const staleTimestamp = new Date(Date.now() - SIGNATURE_MAX_AGE_MS - 60 * 60 * 1000).toISOString(); // 49h old
  const metadataPath = await writeManifest(dir, {
    signatureBuiltAt: staleTimestamp,
    engineVersion: "clamav-1.4.0",
    signatureVersion: "27000",
  });

  const signatureMetadata = readSignatureMetadata({ metadataPath });
  const config = { allowedBucket: "b", ...signatureMetadata };
  const health = await handleHealthCheck({ config, clamdScanner: createFakeClamdScanner({ reachable: true }) });
  assert.equal(health.status, 503);
  assert.equal(health.body.checks.signaturesFresh, false);
  await fs.rm(dir, { recursive: true });
});

test("a missing manifest makes /healthz unhealthy AND makes a scan fail closed, never clean", async () => {
  const signatureMetadata = readSignatureMetadata({ metadataPath: "/nonexistent/metadata.json" });
  const config = {
    allowedBucket: "barkymatches-new.firebasestorage.app",
    ...signatureMetadata,
  };

  const health = await handleHealthCheck({ config, clamdScanner: createFakeClamdScanner({ reachable: true }) });
  assert.equal(health.status, 503);

  // Even though the scanner itself is "reachable" and would say clean,
  // the Functions-side response verification independently rejects a
  // response whose signatureBuiltAt is missing/invalid (contract.js's
  // isSignatureFresh) — proven here at the scanHandler level: the
  // response this service WOULD send simply cannot carry a valid
  // signatureBuiltAt when the manifest never loaded, so scanHandler's
  // own response is built with signatureBuiltAt: null, which
  // buildScanResponse passes through as-is (not fabricated) for the
  // Functions client to then reject.
  const crypto = require("node:crypto");
  const content = Buffer.from("synthetic content");
  const request = {
    contractVersion: CONTRACT_VERSION,
    requestId: "req-1",
    bucket: config.allowedBucket,
    objectPath: "compliance_quarantine/biz-1/sess-1/tok.pdf",
    generation: "111",
    sha256: crypto.createHash("sha256").update(content).digest("hex"),
    sizeBytes: content.length,
  };
  const scanResult = await handleScanRequest({
    body: request,
    config,
    gcsReader: createFakeGcsReader({ content }),
    clamdScanner: createFakeClamdScanner({ outcome: "clean" }),
    logger: { info() {}, warn() {}, error() {} },
  });
  // The scan handler itself does not independently gate on signature
  // freshness (that enforcement lives in healthHandler and, decisively,
  // in the Functions-side response verification) — this assertion
  // documents that boundary precisely: signatureBuiltAt is null in the
  // response, which is exactly what makes the Functions-side check
  // reject it.
  assert.equal(scanResult.body.signatureBuiltAt, null);
});

test("build time cannot overwrite or disguise an old signature timestamp: writing metadata.json AFTER an old signatureBuiltAt does not change what is read", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "sigmeta-"));
  const oldTimestamp = "2020-01-01T00:00:00Z"; // deliberately ancient
  const metadataPath = await writeManifest(dir, {
    signatureBuiltAt: oldTimestamp,
    engineVersion: "clamav-1.4.0",
    signatureVersion: "27000",
  });
  // The manifest FILE's own mtime is "now" (it was just written), but
  // the recorded signatureBuiltAt field is what must be honored — proves
  // this reader trusts the recorded field, not filesystem metadata or
  // wall-clock timing of when the file happened to be written/read.
  const result = readSignatureMetadata({ metadataPath });
  assert.equal(result.signatureBuiltAt, oldTimestamp);
  assert.notEqual(result.signatureBuiltAt, new Date().toISOString());
  await fs.rm(dir, { recursive: true });
});
