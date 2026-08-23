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

test("healthy right at the 48-hour signature-age boundary", async (t) => {
  // Deterministic, timing-independent boundary proof: contract.js's
  // isSignatureFresh(signatureBuiltAtIso, { now = Date.now(), ... })
  // resolves `now` from its OWN, LATER Date.now() call inside
  // handleHealthCheck — a genuinely separate call from the Date.now()
  // used below to construct signatureBuiltAt. Any real wall-clock time
  // elapsing between the two (more likely, and larger, under a shared
  // CI container than on a quiet local machine) pushes the actual age
  // past SIGNATURE_MAX_AGE_MS, flipping this exact-boundary case from
  // healthy to unhealthy — precisely the flake real staging execution
  // exposed. handleHealthCheck/isSignatureFresh are production code
  // (out of this correction's scope) and are not modified to accept an
  // injected clock; instead, the global Date.now is mocked for the
  // duration of this test so BOTH call sites — this test's own
  // signatureBuiltAt construction below and isSignatureFresh's default
  // `now` parameter inside handleHealthCheck — observe the exact same
  // frozen epoch. No real time elapses, and no arbitrary tolerance is
  // introduced: the boundary remains bit-for-bit exact. t.mock.method's
  // mock is scoped to this TestContext and is automatically reset once
  // this test finishes, so no other test ever observes a frozen clock.
  const FROZEN_NOW = Date.now();
  t.mock.method(Date, "now", () => FROZEN_NOW);

  const boundaryConfig = freshConfig({
    signatureBuiltAt: new Date(FROZEN_NOW - SIGNATURE_MAX_AGE_MS).toISOString(),
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
