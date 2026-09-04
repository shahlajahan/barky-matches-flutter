"use strict";

// P1-A Slice 2 — pure unit tests (no Firestore/Storage emulator): the
// state-transition table, request-shape validation, file-signature
// checks, and bounded-retry scanner orchestration loop.

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  isAllowedComplianceUploadSessionTransition,
  isTerminalComplianceUploadSessionStatus,
  buildComplianceUploadObjectId,
  hasOnlyAllowedComplianceUploadSessionRequestFields,
  parseComplianceUploadCanaryAllowlist,
  isComplianceUploadCanaryEnabledForBusiness,
} = require("../src/marketplace/compliance/complianceValidators");
const {
  COMPLIANCE_UPLOAD_SESSION_STATUS,
  COMPLIANCE_UPLOAD_SESSION_TERMINAL_STATUSES,
  MALWARE_SCAN_MAX_ATTEMPTS,
} = require("../src/marketplace/compliance/complianceConstants");
const {
  verifyFileSignature,
  computeSha256,
} = require("../src/marketplace/compliance/complianceUploadFinalization");
const {
  performSingleScanAttempt,
} = require("../src/marketplace/compliance/complianceScanOrchestration");
const {
  createFakeCleanScanner,
  createFakeInfectedScanner,
  createFakeErrorScanner,
  createFakeUnknownVerdictScanner,
  resolveComplianceScanner,
} = require("../src/marketplace/compliance/complianceScanner");
const {
  assertValidRequestShape,
  deriveSessionId,
} = require("../src/marketplace/compliance/complianceUploadSessions");

// ---------------------------------------------------------------------
// State machine
// ---------------------------------------------------------------------

test("a consumed session has no outgoing transitions", () => {
  assert.equal(isTerminalComplianceUploadSessionStatus("consumed"), true);
  assert.equal(isAllowedComplianceUploadSessionTransition("consumed", "uploaded"), false);
  assert.equal(isAllowedComplianceUploadSessionTransition("consumed", "upload_authorized"), false);
});

test("an expired session has no outgoing transitions", () => {
  assert.equal(isTerminalComplianceUploadSessionStatus("expired"), true);
  assert.equal(isAllowedComplianceUploadSessionTransition("expired", "uploaded"), false);
});

test("every documented terminal status has zero outgoing transitions", () => {
  for (const status of COMPLIANCE_UPLOAD_SESSION_TERMINAL_STATUSES) {
    for (const candidate of Object.values(COMPLIANCE_UPLOAD_SESSION_STATUS)) {
      assert.equal(
        isAllowedComplianceUploadSessionTransition(status, candidate),
        false,
        `${status} -> ${candidate} must not be allowed`
      );
    }
  }
});

test("the documented happy path is exactly upload_authorized -> uploaded -> validating -> scan_pending -> promotion_pending -> consumed", () => {
  const path = [
    "upload_authorized",
    "uploaded",
    "validating",
    "scan_pending",
    "promotion_pending",
    "consumed",
  ];
  for (let i = 0; i < path.length - 1; i += 1) {
    assert.equal(
      isAllowedComplianceUploadSessionTransition(path[i], path[i + 1]),
      true,
      `${path[i]} -> ${path[i + 1]} should be allowed`
    );
  }
});

test("scan_pending may resolve to promotion_pending, infected, or scan_failed only", () => {
  assert.equal(isAllowedComplianceUploadSessionTransition("scan_pending", "promotion_pending"), true);
  assert.equal(isAllowedComplianceUploadSessionTransition("scan_pending", "infected"), true);
  assert.equal(isAllowedComplianceUploadSessionTransition("scan_pending", "scan_failed"), true);
  assert.equal(isAllowedComplianceUploadSessionTransition("scan_pending", "consumed"), false);
  assert.equal(isAllowedComplianceUploadSessionTransition("scan_pending", "uploaded"), false);
});

test("promotion_pending may resolve to consumed or scan_failed only", () => {
  assert.equal(isAllowedComplianceUploadSessionTransition("promotion_pending", "consumed"), true);
  assert.equal(isAllowedComplianceUploadSessionTransition("promotion_pending", "scan_failed"), true);
  assert.equal(isAllowedComplianceUploadSessionTransition("promotion_pending", "infected"), false);
  assert.equal(isAllowedComplianceUploadSessionTransition("promotion_pending", "scan_pending"), false);
});

// ---------------------------------------------------------------------
// objectId generation — no client-influenced extension
// ---------------------------------------------------------------------

test("objectId extension is derived only from the validated MIME type", () => {
  assert.equal(buildComplianceUploadObjectId("tok", "application/pdf"), "tok.pdf");
  assert.equal(buildComplianceUploadObjectId("tok", "image/jpeg"), "tok.jpg");
  assert.equal(buildComplianceUploadObjectId("tok", "image/png"), "tok.png");
  assert.throws(() => buildComplianceUploadObjectId("tok", "image/svg+xml"));
});

// ---------------------------------------------------------------------
// createComplianceUploadSession request-shape validation (pure part)
// ---------------------------------------------------------------------

const validRequest = () => ({
  businessId: "biz-1",
  originalFilename: "invoice.pdf",
  declaredMimeType: "application/pdf",
  declaredSizeBytes: 1024,
  documentType: "purchase_invoice",
  // Revision 30 §D (Slice 2) — required, and the pair must appear in the
  // frozen intake matrix: reseller's row lists purchase_invoice.
  sellerRelationship: "reseller",
});

test("a well-formed request passes shape validation", () => {
  const result = assertValidRequestShape(validRequest());
  assert.equal(result.businessId, "biz-1");
  assert.equal(result.declaredMimeType, "application/pdf");
});

test("an unknown request field is rejected", () => {
  assert.throws(() =>
    assertValidRequestShape({ ...validRequest(), storagePath: "compliance_docs/x/y/z" })
  );
  assert.throws(() =>
    assertValidRequestShape({ ...validRequest(), status: "approved" })
  );
  assert.throws(() =>
    assertValidRequestShape({ ...validRequest(), reviewedBy: "attacker-uid" })
  );
});

test("an unsupported declared MIME type is rejected", () => {
  assert.throws(() => assertValidRequestShape({ ...validRequest(), declaredMimeType: "image/svg+xml" }));
});

test("zero, negative, decimal, and oversized declared size are all rejected", () => {
  assert.throws(() => assertValidRequestShape({ ...validRequest(), declaredSizeBytes: 0 }));
  assert.throws(() => assertValidRequestShape({ ...validRequest(), declaredSizeBytes: -5 }));
  assert.throws(() => assertValidRequestShape({ ...validRequest(), declaredSizeBytes: 3.5 }));
  assert.throws(() => assertValidRequestShape({ ...validRequest(), declaredSizeBytes: 999999999 }));
});

test("an invalid documentType is rejected", () => {
  assert.throws(() => assertValidRequestShape({ ...validRequest(), documentType: "medical_prescription" }));
});

test("originalFilename with a path separator is sanitized, not rejected outright", () => {
  const result = assertValidRequestShape({
    ...validRequest(),
    originalFilename: "../../etc/passwd.pdf",
  });
  assert.equal(result.originalFilename.includes("/"), false);
  assert.equal(result.originalFilename.includes("\\"), false);
});

test("hasOnlyAllowedComplianceUploadSessionRequestFields matches assertValidRequestShape's allowlist", () => {
  assert.equal(hasOnlyAllowedComplianceUploadSessionRequestFields(validRequest()), true);
  assert.equal(
    hasOnlyAllowedComplianceUploadSessionRequestFields({ ...validRequest(), objectPath: "x" }),
    false
  );
});

test("deriveSessionId is deterministic for the same idempotency key and random otherwise", () => {
  const a = deriveSessionId({ businessId: "biz-1", uid: "u1", clientIdempotencyKey: "k1" });
  const b = deriveSessionId({ businessId: "biz-1", uid: "u1", clientIdempotencyKey: "k1" });
  assert.equal(a, b);
  const c = deriveSessionId({ businessId: "biz-1", uid: "u2", clientIdempotencyKey: "k1" });
  assert.notEqual(a, c);
  const d1 = deriveSessionId({ businessId: "biz-1", uid: "u1", clientIdempotencyKey: null });
  const d2 = deriveSessionId({ businessId: "biz-1", uid: "u1", clientIdempotencyKey: null });
  assert.notEqual(d1, d2);
});

// ---------------------------------------------------------------------
// File signature verification
// ---------------------------------------------------------------------

test("a genuine PDF header with an EOF marker passes", () => {
  const buf = Buffer.concat([
    Buffer.from("%PDF-1.4\n"),
    Buffer.alloc(100, 0x20),
    Buffer.from("\n%%EOF"),
  ]);
  assert.equal(verifyFileSignature("application/pdf", buf).valid, true);
});

test("a file merely named .pdf without the PDF header fails", () => {
  const buf = Buffer.from("this is just some text, not a pdf at all");
  const result = verifyFileSignature("application/pdf", buf);
  assert.equal(result.valid, false);
  assert.equal(result.reason, "magic_byte_mismatch");
});

test("a PDF header without an EOF marker fails structurally", () => {
  const buf = Buffer.concat([Buffer.from("%PDF-1.4\n"), Buffer.alloc(50, 0x20)]);
  const result = verifyFileSignature("application/pdf", buf);
  assert.equal(result.valid, false);
  assert.equal(result.reason, "pdf_missing_eof_marker");
});

test("a genuine JPEG signature passes, a mismatched one fails", () => {
  const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
  assert.equal(verifyFileSignature("image/jpeg", jpeg).valid, true);
  const notJpeg = Buffer.from([0x00, 0x01, 0x02]);
  assert.equal(verifyFileSignature("image/jpeg", notJpeg).valid, false);
});

test("a genuine PNG signature passes, a mismatched one fails", () => {
  const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2]);
  assert.equal(verifyFileSignature("image/png", png).valid, true);
  const notPng = Buffer.from([0x89, 0x50, 0x00, 0x00]);
  assert.equal(verifyFileSignature("image/png", notPng).valid, false);
});

test("computeSha256 is deterministic", () => {
  const buf = Buffer.from("hello compliance");
  assert.equal(computeSha256(buf), computeSha256(Buffer.from("hello compliance")));
  assert.notEqual(computeSha256(buf), computeSha256(Buffer.from("hello compliance!")));
});

// ---------------------------------------------------------------------
// Scanner: fail-closed configuration
// ---------------------------------------------------------------------

test("resolveComplianceScanner with no CLAMAV_CLOUD_RUN_URL is fail-closed", async () => {
  const scanner = resolveComplianceScanner({ env: {} });
  assert.equal(scanner.configured, false);
  const result = await scanner.scan({ bucket: "b", objectPath: "p", generation: "1", sha256: "x", sizeBytes: 1 });
  assert.equal(result.verdict, "error");
  assert.equal(result.reason, "not_configured");
});

test("a configured scanner whose request times out reports error, not clean (item 34)", async () => {
  const { createClamAvCloudRunScanner } = require("../src/marketplace/compliance/complianceScanner");
  const timeoutError = new Error("timeout of 15000ms exceeded");
  timeoutError.code = "ECONNABORTED";
  const scanner = createClamAvCloudRunScanner({
    serviceUrl: "https://example-clamav.invalid/scan",
    audience: "https://example-clamav.invalid/scan",
    logger: { error() {}, warn() {} },
    authClientFactory: async () => ({
      async request() {
        throw timeoutError;
      },
    }),
  });
  assert.equal(scanner.configured, true);
  const result = await scanner.scan({ bucket: "b", objectPath: "p", generation: "1", sha256: "x", sizeBytes: 1 });
  assert.equal(result.verdict, "error");
  assert.equal(result.reason, "timeout");
  assert.notEqual(result.verdict, "clean");
});

test("a configured scanner that fails authentication reports error, not clean", async () => {
  const { createClamAvCloudRunScanner } = require("../src/marketplace/compliance/complianceScanner");
  const scanner = createClamAvCloudRunScanner({
    serviceUrl: "https://example-clamav.invalid/scan",
    logger: { error() {}, warn() {} },
    authClientFactory: async () => {
      throw new Error("no credentials available");
    },
  });
  const result = await scanner.scan({ bucket: "b", objectPath: "p", generation: "1", sha256: "x", sizeBytes: 1 });
  assert.equal(result.verdict, "error");
  assert.equal(result.reason, "auth_failure");
});

test("a configured scanner returning a malformed response body reports error, not clean", async () => {
  const { createClamAvCloudRunScanner } = require("../src/marketplace/compliance/complianceScanner");
  const scanner = createClamAvCloudRunScanner({
    serviceUrl: "https://example-clamav.invalid/scan",
    logger: { error() {}, warn() {} },
    authClientFactory: async () => ({
      async request() {
        return { data: { unexpected: "shape", noVerdictField: true } };
      },
    }),
  });
  const result = await scanner.scan({ bucket: "b", objectPath: "p", generation: "1", sha256: "x", sizeBytes: 1 });
  assert.equal(result.verdict, "error");
  assert.equal(result.reason, "scanner_response_binding_mismatch");
});

// ---------------------------------------------------------------------
// Response-binding verification (Slice 2.1 correction, part B) — a
// clean/infected verdict must be provably bound to the exact request
// that produced it, not merely well-formed. echoValidResponse() builds a
// fully-correct response for whatever request body the fake transport
// actually received, so every mutate-one-field test below starts from a
// genuinely valid baseline and breaks exactly one binding at a time.
// ---------------------------------------------------------------------

const { COMPLIANCE_SCANNER_CONTRACT_VERSION, COMPLIANCE_SIGNATURE_MAX_AGE_MS } = require("../src/marketplace/compliance/complianceConstants");

function echoValidResponse(sentBody, overrides = {}) {
  return {
    contractVersion: sentBody.contractVersion,
    requestId: sentBody.requestId,
    verdict: "clean",
    bucket: sentBody.bucket,
    objectPath: sentBody.objectPath,
    generation: sentBody.generation,
    sha256: sentBody.sha256,
    sizeBytes: sentBody.sizeBytes,
    engineVersion: "clamav-1.2.3",
    signatureVersion: "sig-9",
    signatureBuiltAt: new Date(Date.now() - 60 * 60 * 1000).toISOString(), // 1h old, well within budget
    scannedAt: new Date().toISOString(),
    ...overrides,
  };
}

const SAMPLE_SCAN_REQUEST = { bucket: "b", objectPath: "compliance_quarantine/biz/sess/tok.pdf", generation: "12345", sha256: "a".repeat(64), sizeBytes: 2048 };

async function scanWithEcho(overrides) {
  const { createClamAvCloudRunScanner } = require("../src/marketplace/compliance/complianceScanner");
  let sentBody = null;
  const scanner = createClamAvCloudRunScanner({
    serviceUrl: "https://example-clamav.invalid/scan",
    logger: { error() {}, warn() {} },
    authClientFactory: async () => ({
      async request(opts) {
        sentBody = opts.data;
        return { data: echoValidResponse(sentBody, overrides) };
      },
    }),
  });
  const result = await scanner.scan(SAMPLE_SCAN_REQUEST);
  return { result, sentBody };
}

test("a genuinely valid, fully-bound clean response is honored", async () => {
  const { result } = await scanWithEcho({});
  assert.equal(result.verdict, "clean");
  assert.equal(result.engineVersion, "clamav-1.2.3");
});

test("the scanner request always declares contractVersion and a fresh requestId", async () => {
  const { sentBody } = await scanWithEcho({});
  assert.equal(sentBody.contractVersion, COMPLIANCE_SCANNER_CONTRACT_VERSION);
  assert.equal(typeof sentBody.requestId, "string");
  assert.ok(sentBody.requestId.length > 0);
});

test("two separate scan calls use two different requestId values", async () => {
  const first = await scanWithEcho({});
  const second = await scanWithEcho({});
  assert.notEqual(first.sentBody.requestId, second.sentBody.requestId);
});

// 28. scanner contract version mismatch fails closed (Slice 2 correction)
test("a mismatched contractVersion fails closed, not clean", async () => {
  const { result } = await scanWithEcho({ contractVersion: 999 });
  assert.equal(result.verdict, "error");
  assert.equal(result.reason, "scanner_response_binding_mismatch");
});

test("a mismatched requestId fails closed — proves the response is bound to THIS request, not just well-formed", async () => {
  const { result } = await scanWithEcho({ requestId: "some-other-requests-id" });
  assert.equal(result.verdict, "error");
  assert.equal(result.reason, "scanner_response_binding_mismatch");
});

test("a mismatched bucket in the response fails closed", async () => {
  const { result } = await scanWithEcho({ bucket: "a-different-bucket" });
  assert.equal(result.verdict, "error");
});

test("a mismatched objectPath in the response fails closed", async () => {
  const { result } = await scanWithEcho({ objectPath: "compliance_quarantine/biz/sess/different.pdf" });
  assert.equal(result.verdict, "error");
});

test("a mismatched generation in the response fails closed", async () => {
  const { result } = await scanWithEcho({ generation: "99999999" });
  assert.equal(result.verdict, "error");
});

test("a mismatched sha256 in the response fails closed", async () => {
  const { result } = await scanWithEcho({ sha256: "b".repeat(64) });
  assert.equal(result.verdict, "error");
});

test("a mismatched sizeBytes in the response fails closed", async () => {
  const { result } = await scanWithEcho({ sizeBytes: 99 });
  assert.equal(result.verdict, "error");
});

test("an unexpected extra field in the response fails closed (closed-schema)", async () => {
  const { result } = await scanWithEcho({ maliciousExtraField: "anything" });
  assert.equal(result.verdict, "error");
});

test("a missing or invalid scannedAt fails closed", async () => {
  const missing = await scanWithEcho({ scannedAt: undefined });
  assert.equal(missing.result.verdict, "error");
  const invalid = await scanWithEcho({ scannedAt: "not-a-date" });
  assert.equal(invalid.result.verdict, "error");
});

test("a scannedAt impossibly in the future fails closed", async () => {
  const { result } = await scanWithEcho({ scannedAt: new Date(Date.now() + 60 * 60 * 1000).toISOString() });
  assert.equal(result.verdict, "error");
});

test("a missing or invalid signatureBuiltAt fails closed", async () => {
  const missing = await scanWithEcho({ signatureBuiltAt: undefined });
  assert.equal(missing.result.verdict, "error");
  const invalid = await scanWithEcho({ signatureBuiltAt: "garbage" });
  assert.equal(invalid.result.verdict, "error");
});

// Signature freshness — the core of part B's "must never return clean"
// requirement for stale signatures.
test("signatures exactly at the 48-hour boundary are accepted; one millisecond past it fails closed", async () => {
  const boundary = await scanWithEcho({
    signatureBuiltAt: new Date(Date.now() - COMPLIANCE_SIGNATURE_MAX_AGE_MS).toISOString(),
  });
  assert.equal(boundary.result.verdict, "clean");

  const pastBoundary = await scanWithEcho({
    signatureBuiltAt: new Date(Date.now() - COMPLIANCE_SIGNATURE_MAX_AGE_MS - 1000).toISOString(),
  });
  assert.equal(pastBoundary.result.verdict, "error");
});

test("a signatureBuiltAt in the future fails closed", async () => {
  const { result } = await scanWithEcho({ signatureBuiltAt: new Date(Date.now() + 60 * 60 * 1000).toISOString() });
  assert.equal(result.verdict, "error");
});

test("a clean verdict missing engineVersion or signatureVersion fails closed", async () => {
  const missingEngine = await scanWithEcho({ engineVersion: undefined });
  assert.equal(missingEngine.result.verdict, "error");
  const emptyEngine = await scanWithEcho({ engineVersion: "" });
  assert.equal(emptyEngine.result.verdict, "error");
  const missingSig = await scanWithEcho({ signatureVersion: undefined });
  assert.equal(missingSig.result.verdict, "error");
});

test("an infected verdict also requires engineVersion and signatureVersion", async () => {
  const { result } = await scanWithEcho({ verdict: "infected", engineVersion: undefined });
  assert.equal(result.verdict, "error");
});

test("an error verdict does not require engineVersion/signatureVersion but requires a well-formed errorCode if present", async () => {
  const clean = await scanWithEcho({
    verdict: "error",
    engineVersion: undefined,
    signatureVersion: undefined,
    errorCode: "clamd_unavailable",
  });
  assert.equal(clean.result.verdict, "error");
  // Both a genuinely-accepted 'error' verdict AND a rejected/binding-
  // mismatched response surface as verdict: "error" — the only way to
  // tell them apart is that a REJECTED response always carries this
  // specific stable reason (see scan()'s binding-mismatch branch), while
  // an accepted verdict never sets `reason` at all. Asserting its
  // absence here is what actually proves this well-formed error
  // response was honored as-is, not silently rejected-then-coerced.
  assert.notEqual(clean.result.reason, "scanner_response_binding_mismatch");

  const badCode = await scanWithEcho({ verdict: "error", engineVersion: undefined, signatureVersion: undefined, errorCode: "" });
  assert.equal(badCode.result.verdict, "error");
  assert.equal(badCode.result.reason, "scanner_response_binding_mismatch");
});

// ---------------------------------------------------------------------
// Single-attempt scan orchestration (Slice 2.1 correction, part A) — no
// in-process retry loop; performSingleScanAttempt makes exactly one
// scanner call per invocation, and the attempt budget is enforced by the
// caller comparing the returned `attempts` against MALWARE_SCAN_MAX_
// ATTEMPTS across SEPARATE invocations, never inside this function.
// ---------------------------------------------------------------------

test("a clean verdict on the first attempt is honored, exactly one scanner call", async () => {
  let callCount = 0;
  const scanner = { async scan() { callCount += 1; return createFakeCleanScanner().scan(); } };
  const { attempts, result } = await performSingleScanAttempt({
    scanner,
    request: {},
    startingAttempts: 0,
    logger: { error() {}, warn() {} },
  });
  assert.equal(callCount, 1);
  assert.equal(attempts, 1);
  assert.equal(result.verdict, "clean");
});

test("an infected verdict is honored on the first attempt, exactly one scanner call", async () => {
  let callCount = 0;
  const scanner = { async scan() { callCount += 1; return createFakeInfectedScanner().scan(); } };
  const { attempts, result } = await performSingleScanAttempt({
    scanner,
    request: {},
    startingAttempts: 0,
    logger: { error() {}, warn() {} },
  });
  assert.equal(callCount, 1);
  assert.equal(attempts, 1);
  assert.equal(result.verdict, "infected");
});

test("a single error attempt increments attempts by exactly one and never produces clean", async () => {
  const scanner = createFakeErrorScanner({ reason: "always_down" });
  const { attempts, result } = await performSingleScanAttempt({
    scanner,
    request: {},
    startingAttempts: 0,
    logger: { error() {}, warn() {} },
  });
  assert.equal(attempts, 1);
  assert.equal(result.verdict, "error");
  assert.notEqual(result.verdict, "clean");
});

test("repeated single attempts across separate calls advance startingAttempts and reach the bound without ever sleeping in-process", async () => {
  const scanner = createFakeErrorScanner({ reason: "always_down" });
  let attempts = 0;
  const startedAt = Date.now();
  for (let i = 0; i < MALWARE_SCAN_MAX_ATTEMPTS; i += 1) {
    ({ attempts } = await performSingleScanAttempt({
      scanner,
      request: {},
      startingAttempts: attempts,
      logger: { error() {}, warn() {} },
    }));
  }
  const elapsedMs = Date.now() - startedAt;
  assert.equal(attempts, MALWARE_SCAN_MAX_ATTEMPTS);
  // No internal backoff/sleep exists anymore — MALWARE_SCAN_MAX_ATTEMPTS
  // calls to a fake scanner that resolves instantly must complete near-
  // instantly, proving no sleep-based retry loop remains.
  assert.equal(elapsedMs < 1000, true, `expected no internal backoff sleep, took ${elapsedMs}ms`);
});

test("an unknown/malformed verdict string is treated exactly like an error, never clean", async () => {
  const scanner = createFakeUnknownVerdictScanner();
  const { attempts, result } = await performSingleScanAttempt({
    scanner,
    request: {},
    startingAttempts: 0,
    logger: { error() {}, warn() {} },
  });
  assert.equal(attempts, 1);
  assert.equal(result.verdict, "error");
});

test("a scanner that throws is treated as an error, not an unhandled crash", async () => {
  const throwingScanner = {
    async scan() {
      throw new Error("network exploded");
    },
  };
  const { result } = await performSingleScanAttempt({
    scanner: throwingScanner,
    request: {},
    startingAttempts: 0,
    logger: { error() {}, warn() {} },
  });
  assert.equal(result.verdict, "error");
});

test("startingAttempts already at the bound short-circuits with zero additional scanner calls", async () => {
  let callCount = 0;
  const countingScanner = {
    async scan() {
      callCount += 1;
      return { verdict: "clean" };
    },
  };
  const { attempts, result } = await performSingleScanAttempt({
    scanner: countingScanner,
    request: {},
    startingAttempts: MALWARE_SCAN_MAX_ATTEMPTS,
    logger: { error() {}, warn() {} },
  });
  assert.equal(callCount, 0);
  assert.equal(attempts, MALWARE_SCAN_MAX_ATTEMPTS);
  assert.equal(result.verdict, "error");
  assert.equal(result.reason, "attempts_already_exhausted");
});

// ---------------------------------------------------------------------
// Canary allowlist (Slice 2.1 correction, part G)
// ---------------------------------------------------------------------

test("parseComplianceUploadCanaryAllowlist parses, trims, and drops empty entries", () => {
  assert.deepEqual(parseComplianceUploadCanaryAllowlist("biz-1,biz-2"), ["biz-1", "biz-2"]);
  assert.deepEqual(parseComplianceUploadCanaryAllowlist("  biz-1 , biz-2  "), ["biz-1", "biz-2"]);
  assert.deepEqual(parseComplianceUploadCanaryAllowlist(""), []);
  assert.deepEqual(parseComplianceUploadCanaryAllowlist(" , ,, "), []);
  assert.deepEqual(parseComplianceUploadCanaryAllowlist(undefined), []);
  assert.deepEqual(parseComplianceUploadCanaryAllowlist(null), []);
});

test("isComplianceUploadCanaryEnabledForBusiness denies by default (missing/empty/malformed allowlist)", () => {
  assert.equal(isComplianceUploadCanaryEnabledForBusiness("biz-1", undefined), false);
  assert.equal(isComplianceUploadCanaryEnabledForBusiness("biz-1", ""), false);
  assert.equal(isComplianceUploadCanaryEnabledForBusiness("biz-1", " , , "), false);
  assert.equal(isComplianceUploadCanaryEnabledForBusiness("biz-1", "biz-2,biz-3"), false);
});

test("isComplianceUploadCanaryEnabledForBusiness allows only an exact, explicitly-listed businessId", () => {
  assert.equal(isComplianceUploadCanaryEnabledForBusiness("biz-1", "biz-1"), true);
  assert.equal(isComplianceUploadCanaryEnabledForBusiness("biz-1", "biz-0,biz-1,biz-2"), true);
  assert.equal(isComplianceUploadCanaryEnabledForBusiness("biz-1", "biz-1x"), false, "must be an exact match, not a prefix");
  assert.equal(isComplianceUploadCanaryEnabledForBusiness("", "biz-1"), false);
});
