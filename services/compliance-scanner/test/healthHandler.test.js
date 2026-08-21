"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { handleHealthCheck } = require("../src/healthHandler");
const { createFakeClamdScanner } = require("../src/fakeAdapters");
const { SIGNATURE_MAX_AGE_MS } = require("../src/contract");

function freshConfig(overrides = {}) {
  return {
    engineVersion: "clamav-1.2.3",
    signatureVersion: "sig-9",
    signatureBuiltAt: new Date(Date.now() - 60 * 60 * 1000).toISOString(), // 1h old
    ...overrides,
  };
}

test("healthy only when clamd is reachable AND signatures are loaded AND fresh", async () => {
  const result = await handleHealthCheck({ config: freshConfig(), clamdScanner: createFakeClamdScanner({ reachable: true }) });
  assert.equal(result.status, 200);
  assert.equal(result.body.status, "healthy");
  assert.equal(result.body.checks.clamdReachable, true);
  assert.equal(result.body.checks.signaturesLoaded, true);
  assert.equal(result.body.checks.signaturesFresh, true);
});

test("unhealthy (503) when clamd is unreachable, even with fresh signatures", async () => {
  const result = await handleHealthCheck({ config: freshConfig(), clamdScanner: createFakeClamdScanner({ reachable: false }) });
  assert.equal(result.status, 503);
  assert.equal(result.body.status, "unhealthy");
  assert.equal(result.body.checks.clamdReachable, false);
});

test("unhealthy when signature metadata is entirely missing", async () => {
  const config = freshConfig({ signatureBuiltAt: null, engineVersion: null, signatureVersion: null });
  const result = await handleHealthCheck({ config, clamdScanner: createFakeClamdScanner({ reachable: true }) });
  assert.equal(result.status, 503);
  assert.equal(result.body.checks.signaturesLoaded, false);
  assert.equal(result.body.checks.signaturesFresh, false);
});

test("unhealthy when signatures are older than the 48-hour maximum, even with clamd reachable", async () => {
  const staleConfig = freshConfig({
    signatureBuiltAt: new Date(Date.now() - SIGNATURE_MAX_AGE_MS - 1000).toISOString(),
  });
  const result = await handleHealthCheck({ config: staleConfig, clamdScanner: createFakeClamdScanner({ reachable: true }) });
  assert.equal(result.status, 503);
  assert.equal(result.body.checks.clamdReachable, true);
  assert.equal(result.body.checks.signaturesLoaded, true);
  assert.equal(result.body.checks.signaturesFresh, false);
});

test("healthy right at the 48-hour signature-age boundary", async () => {
  const boundaryConfig = freshConfig({
    signatureBuiltAt: new Date(Date.now() - SIGNATURE_MAX_AGE_MS).toISOString(),
  });
  const result = await handleHealthCheck({ config: boundaryConfig, clamdScanner: createFakeClamdScanner({ reachable: true }) });
  assert.equal(result.status, 200);
});

test("a clamd.ping() rejection is treated as unreachable, not a crash", async () => {
  const throwingScanner = { async ping() { throw new Error("socket error"); } };
  const result = await handleHealthCheck({ config: freshConfig(), clamdScanner: throwingScanner });
  assert.equal(result.status, 503);
  assert.equal(result.body.checks.clamdReachable, false);
});

test("health output never includes bucket names, paths, or any document/request information", async () => {
  const result = await handleHealthCheck({ config: freshConfig(), clamdScanner: createFakeClamdScanner({ reachable: true }) });
  const serialized = JSON.stringify(result.body);
  for (const forbidden of ["bucket", "objectPath", "compliance_quarantine", "sha256", "generation"]) {
    assert.equal(serialized.toLowerCase().includes(forbidden.toLowerCase()), false, `health output must not mention "${forbidden}"`);
  }
});
