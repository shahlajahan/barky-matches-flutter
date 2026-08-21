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
  runScanWithBoundedRetries,
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
  assert.equal(result.reason, "malformed_response");
});

test("a configured scanner returning a genuinely valid clean response is honored", async () => {
  const { createClamAvCloudRunScanner } = require("../src/marketplace/compliance/complianceScanner");
  const scanner = createClamAvCloudRunScanner({
    serviceUrl: "https://example-clamav.invalid/scan",
    logger: { error() {}, warn() {} },
    authClientFactory: async () => ({
      async request() {
        return {
          data: {
            contractVersion: 1,
            verdict: "clean",
            engineVersion: "clamav-1.2.3",
            signatureVersion: "sig-9",
          },
        };
      },
    }),
  });
  const result = await scanner.scan({ bucket: "b", objectPath: "p", generation: "1", sha256: "x", sizeBytes: 1 });
  assert.equal(result.verdict, "clean");
  assert.equal(result.engineVersion, "clamav-1.2.3");
});

// 28. scanner contract version mismatch fails closed (Slice 2 correction)
test("a scanner response with a missing or mismatched contractVersion fails closed, not clean", async () => {
  const { createClamAvCloudRunScanner } = require("../src/marketplace/compliance/complianceScanner");
  const missingVersion = createClamAvCloudRunScanner({
    serviceUrl: "https://example-clamav.invalid/scan",
    logger: { error() {}, warn() {} },
    authClientFactory: async () => ({
      async request() {
        return { data: { verdict: "clean", engineVersion: "clamav-1.2.3" } }; // no contractVersion
      },
    }),
  });
  const resultMissing = await missingVersion.scan({ bucket: "b", objectPath: "p", generation: "1", sha256: "x", sizeBytes: 1 });
  assert.equal(resultMissing.verdict, "error");
  assert.equal(resultMissing.reason, "malformed_response");

  const wrongVersion = createClamAvCloudRunScanner({
    serviceUrl: "https://example-clamav.invalid/scan",
    logger: { error() {}, warn() {} },
    authClientFactory: async () => ({
      async request() {
        return { data: { contractVersion: 999, verdict: "clean" } };
      },
    }),
  });
  const resultWrong = await wrongVersion.scan({ bucket: "b", objectPath: "p", generation: "1", sha256: "x", sizeBytes: 1 });
  assert.equal(resultWrong.verdict, "error");
  assert.equal(resultWrong.reason, "malformed_response");
});

test("the scanner request body always declares the current contractVersion", async () => {
  const { createClamAvCloudRunScanner } = require("../src/marketplace/compliance/complianceScanner");
  const { COMPLIANCE_SCANNER_CONTRACT_VERSION } = require("../src/marketplace/compliance/complianceConstants");
  let capturedBody = null;
  const scanner = createClamAvCloudRunScanner({
    serviceUrl: "https://example-clamav.invalid/scan",
    logger: { error() {}, warn() {} },
    authClientFactory: async () => ({
      async request(opts) {
        capturedBody = opts.data;
        return { data: { contractVersion: COMPLIANCE_SCANNER_CONTRACT_VERSION, verdict: "clean" } };
      },
    }),
  });
  await scanner.scan({ bucket: "b", objectPath: "p", generation: "1", sha256: "x", sizeBytes: 1 });
  assert.equal(capturedBody.contractVersion, COMPLIANCE_SCANNER_CONTRACT_VERSION);
});

// ---------------------------------------------------------------------
// Bounded retry orchestration loop
// ---------------------------------------------------------------------

test("a clean verdict on the first attempt stops immediately, no retries", async () => {
  const scanner = createFakeCleanScanner();
  const { attempts, result } = await runScanWithBoundedRetries({
    scanner,
    request: {},
    startingAttempts: 0,
    logger: { error() {}, warn() {} },
  });
  assert.equal(attempts, 1);
  assert.equal(result.verdict, "clean");
});

test("an infected verdict also stops immediately", async () => {
  const scanner = createFakeInfectedScanner();
  const { attempts, result } = await runScanWithBoundedRetries({
    scanner,
    request: {},
    startingAttempts: 0,
    logger: { error() {}, warn() {} },
  });
  assert.equal(attempts, 1);
  assert.equal(result.verdict, "infected");
});

test("persistent errors exhaust the bounded retry budget and never produce clean", async () => {
  const scanner = createFakeErrorScanner({ reason: "always_down" });
  const { attempts, result } = await runScanWithBoundedRetries({
    scanner,
    request: {},
    startingAttempts: 0,
    logger: { error() {}, warn() {} },
  });
  assert.equal(attempts, MALWARE_SCAN_MAX_ATTEMPTS);
  assert.equal(result.verdict, "error");
  assert.notEqual(result.verdict, "clean");
});

test("an unknown/malformed verdict string is treated exactly like an error, never clean", async () => {
  const scanner = createFakeUnknownVerdictScanner();
  const { attempts, result } = await runScanWithBoundedRetries({
    scanner,
    request: {},
    startingAttempts: 0,
    logger: { error() {}, warn() {} },
  });
  assert.equal(attempts, MALWARE_SCAN_MAX_ATTEMPTS);
  assert.equal(result.verdict, "error");
});

test("a scanner that throws is treated as an error, not an unhandled crash", async () => {
  const throwingScanner = {
    async scan() {
      throw new Error("network exploded");
    },
  };
  const { result } = await runScanWithBoundedRetries({
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
  const { attempts, result } = await runScanWithBoundedRetries({
    scanner: countingScanner,
    request: {},
    startingAttempts: MALWARE_SCAN_MAX_ATTEMPTS,
    logger: { error() {}, warn() {} },
  });
  assert.equal(callCount, 0);
  assert.equal(attempts, MALWARE_SCAN_MAX_ATTEMPTS);
  assert.equal(result.verdict, "error");
  assert.equal(result.reason, "not_attempted");
});
