"use strict";

// Petsupo Marketplace P1-A compliance foundation — malware-scanning
// abstraction (docs/plans/marketplace_p1a_compliance_review_
// implementation_plan_2026-08-21.md, Slice 2 security decision). This
// module defines the MalwareScanner contract and two implementations:
//
//   - createClamAvCloudRunScanner(): the production-target adapter for a
//     privately operated ClamAV service on Cloud Run, authenticated via
//     Google-signed ID tokens. THIS TASK DOES NOT CREATE OR DEPLOY THAT
//     CLOUD RUN SERVICE — this is the client-side integration boundary
//     only, and it fails closed (never "clean") whenever the service is
//     unconfigured, unreachable, slow, or returns anything unexpected.
//   - createFakeCleanScanner()/createFakeInfectedScanner()/
//     createFakeErrorScanner(): deterministic scanners for tests and the
//     emulator ONLY. None of these is ever selected by
//     resolveComplianceScanner() at runtime — that function always
//     returns the real (possibly unconfigured, and therefore
//     fail-closed) production adapter. A fake scanner must be passed in
//     explicitly by a test; there is no environment variable or code
//     path that substitutes one automatically.
//
// A MalwareScanner is any object exposing:
//   async scan({ bucket, objectPath, generation, sha256, sizeBytes })
//     -> { verdict: 'clean'|'infected'|'error',
//          engineVersion?: string, signatureVersion?: string,
//          reason?: string }
//
// The scanner NEVER receives raw file bytes, a signed URL, or a document
// URL in its request — only bucket/path/generation/hash/size, so the
// production Cloud Run service is expected to fetch the object itself
// via its own IAM-granted Storage read access ("object access through
// trusted server identity", per the security decision), and so that
// nothing resembling a document location or content ever appears in a
// scanner request log on the Cloud Functions side.

const crypto = require("node:crypto");
const { GoogleAuth } = require("google-auth-library");
const {
  MALWARE_SCAN_VERDICT,
  MALWARE_SCAN_TIMEOUT_MS,
  COMPLIANCE_SCANNER_CONTRACT_VERSION,
  COMPLIANCE_SIGNATURE_MAX_AGE_MS,
} = require("./complianceConstants");

// Slice 2.1 correction (deployment-readiness audit 2026-08-21, part B —
// "a clean response must be cryptographically/transport-authenticated
// AND bound to the exact bucket, path, generation, SHA-256, and size
// that were requested and independently scanned"). The prior contract
// validated only contractVersion + verdict shape; transport auth (the
// ID-token audience check) proves the RESPONSE came from the legitimate
// service, but proves nothing about what that service actually scanned.
// This is the fix: every response is now checked for EXACT equality,
// field by field, against what THIS SPECIFIC request asked for — not
// merely "well-formed", but "provably an answer to this exact question".
//
// Closed-schema response: any key beyond this exact set is itself a
// rejection reason (COMPLIANCE_SCAN_RESPONSE_ALLOWED_KEYS below) — an
// unexpected extra field is treated as untrusted, not merely ignored.
const COMPLIANCE_SCAN_RESPONSE_ALLOWED_KEYS = new Set([
  "contractVersion",
  "requestId",
  "verdict",
  "bucket",
  "objectPath",
  "generation",
  "sha256",
  "sizeBytes",
  "engineVersion",
  "signatureVersion",
  "signatureBuiltAt",
  "scannedAt",
  "errorCode",
]);

function isValidIsoTimestamp(value) {
  if (typeof value !== "string" || value.length === 0) return false;
  const ms = Date.parse(value);
  return Number.isFinite(ms);
}

// Verifies the response is provably bound to the exact request that was
// sent, not merely well-formed. Returns { valid: true } or
// { valid: false, reason } — the reason is always the same stable, safe
// code (scanner_response_binding_mismatch) at the call site, per the
// requirement that a mismatch never leaks which specific field differed
// (that detail is only ever logged, never returned to the caller).
function verifyScanResponseBinding(body, request, { now = Date.now() } = {}) {
  if (body == null || typeof body !== "object" || Array.isArray(body)) {
    return { valid: false, reason: "not_an_object" };
  }
  for (const key of Object.keys(body)) {
    if (!COMPLIANCE_SCAN_RESPONSE_ALLOWED_KEYS.has(key)) {
      return { valid: false, reason: "unexpected_field" };
    }
  }
  if (body.contractVersion !== COMPLIANCE_SCANNER_CONTRACT_VERSION) {
    return { valid: false, reason: "contract_version_mismatch" };
  }
  if (typeof body.requestId !== "string" || body.requestId !== request.requestId) {
    return { valid: false, reason: "request_id_mismatch" };
  }
  if (body.bucket !== request.bucket) {
    return { valid: false, reason: "bucket_mismatch" };
  }
  if (body.objectPath !== request.objectPath) {
    return { valid: false, reason: "object_path_mismatch" };
  }
  if (String(body.generation) !== String(request.generation)) {
    return { valid: false, reason: "generation_mismatch" };
  }
  if (body.sha256 !== request.sha256) {
    return { valid: false, reason: "sha256_mismatch" };
  }
  if (Number(body.sizeBytes) !== Number(request.sizeBytes)) {
    return { valid: false, reason: "size_mismatch" };
  }
  if (!Object.values(MALWARE_SCAN_VERDICT).includes(body.verdict)) {
    return { valid: false, reason: "invalid_verdict" };
  }
  if (!isValidIsoTimestamp(body.scannedAt)) {
    return { valid: false, reason: "invalid_scanned_at" };
  }
  const scannedAtMs = Date.parse(body.scannedAt);
  // A small forward-clock-skew allowance (5s) — beyond that, a scannedAt
  // "in the future" relative to when the response was received is
  // itself a sign the response cannot be trusted at face value.
  if (scannedAtMs > now + 5000) {
    return { valid: false, reason: "scanned_at_in_future" };
  }
  if (!isValidIsoTimestamp(body.signatureBuiltAt)) {
    return { valid: false, reason: "invalid_signature_built_at" };
  }
  const signatureAgeMs = now - Date.parse(body.signatureBuiltAt);
  if (signatureAgeMs > COMPLIANCE_SIGNATURE_MAX_AGE_MS) {
    return { valid: false, reason: "stale_signatures" };
  }
  if (signatureAgeMs < 0) {
    return { valid: false, reason: "signature_built_at_in_future" };
  }
  if (
    (body.verdict === MALWARE_SCAN_VERDICT.CLEAN || body.verdict === MALWARE_SCAN_VERDICT.INFECTED) &&
    (typeof body.engineVersion !== "string" ||
      body.engineVersion.length === 0 ||
      typeof body.signatureVersion !== "string" ||
      body.signatureVersion.length === 0)
  ) {
    return { valid: false, reason: "missing_engine_or_signature_version" };
  }
  if (
    body.verdict === MALWARE_SCAN_VERDICT.ERROR &&
    body.errorCode !== undefined &&
    (typeof body.errorCode !== "string" || body.errorCode.length === 0)
  ) {
    return { valid: false, reason: "invalid_error_code" };
  }
  return { valid: true };
}

// ---------------------------------------------------------------------
// Production adapter: privately operated ClamAV on Cloud Run.
// ---------------------------------------------------------------------

// `authClientFactory` is injected (defaults to a real google-auth-library
// ID-token client) so tests can substitute a fake without any network
// call — never so production code can skip authentication.
function createClamAvCloudRunScanner({
  serviceUrl,
  audience,
  timeoutMs = MALWARE_SCAN_TIMEOUT_MS,
  logger = console,
  authClientFactory,
} = {}) {
  if (!serviceUrl) {
    // No environment variable, no service URL, no audience configured —
    // this adapter must never be mistaken for a working scanner. Every
    // call fails closed with a stable, inspectable reason.
    return {
      configured: false,
      async scan() {
        logger.warn("compliance_scan_not_configured", {
          reason: "missing_service_url",
        });
        return { verdict: MALWARE_SCAN_VERDICT.ERROR, reason: "not_configured" };
      },
    };
  }

  return {
    configured: true,
    async scan({ bucket, objectPath, generation, sha256, sizeBytes }) {
      // No raw file contents, no document URL, no download token in this
      // request payload — only the coordinates the trusted Cloud Run
      // service needs to fetch the object itself. contractVersion pins
      // the exact request/response schema the service must honor;
      // requestId (Slice 2.1, part B) is a fresh, unpredictable
      // correlation value this exact call expects to see echoed back —
      // it is what makes response-binding verification meaningful rather
      // than just checking the response "looks right".
      const requestBody = {
        contractVersion: COMPLIANCE_SCANNER_CONTRACT_VERSION,
        requestId: crypto.randomUUID(),
        bucket,
        objectPath,
        generation,
        sha256,
        sizeBytes,
      };

      let client;
      try {
        if (authClientFactory) {
          client = await authClientFactory(audience || serviceUrl);
        } else {
          const auth = new GoogleAuth();
          client = await auth.getIdTokenClient(audience || serviceUrl);
        }
      } catch (err) {
        logger.error("compliance_scan_auth_failure", {
          message: err && err.message,
        });
        return { verdict: MALWARE_SCAN_VERDICT.ERROR, reason: "auth_failure" };
      }

      let response;
      try {
        response = await client.request({
          url: serviceUrl,
          method: "POST",
          data: requestBody,
          timeout: timeoutMs,
        });
      } catch (err) {
        const isTimeout =
          err && (err.code === "ECONNABORTED" || /timeout/i.test(String(err.message)));
        logger.error("compliance_scan_request_failure", {
          message: err && err.message,
          timeout: Boolean(isTimeout),
        });
        return {
          verdict: MALWARE_SCAN_VERDICT.ERROR,
          reason: isTimeout ? "timeout" : "request_failed",
        };
      }

      const body = response && response.data;
      const binding = verifyScanResponseBinding(body, requestBody);
      if (!binding.valid) {
        // Do not trust transport authentication alone as document-result
        // binding (Slice 2.1, part B) — this is reached even for a
        // response that passed ID-token auth, if it isn't ALSO provably
        // an answer to this exact request. The specific mismatched field
        // is logged (never the raw body, which could — in a compromised
        // or misbehaving service — echo back something derived from the
        // file) but the returned reason is always the same stable, safe
        // code, never leaking which check failed to the caller.
        logger.error("compliance_scan_response_binding_mismatch", {
          hasBody: body != null,
          bindingFailureReason: binding.reason,
        });
        return { verdict: MALWARE_SCAN_VERDICT.ERROR, reason: "scanner_response_binding_mismatch" };
      }

      return {
        verdict: body.verdict,
        engineVersion: typeof body.engineVersion === "string" ? body.engineVersion : null,
        signatureVersion:
          typeof body.signatureVersion === "string" ? body.signatureVersion : null,
      };
    },
  };
}

// Resolves the production scanner from environment configuration. Always
// returns a scanner object — an unconfigured environment returns the
// fail-closed variant above, never throws, never silently substitutes a
// fake. This is the ONLY function production code (complianceScan
// Orchestration.js) is expected to call.
function resolveComplianceScanner({ env = process.env, logger = console } = {}) {
  const serviceUrl = env.CLAMAV_CLOUD_RUN_URL || null;
  const audience = env.CLAMAV_CLOUD_RUN_AUDIENCE || serviceUrl;
  return createClamAvCloudRunScanner({ serviceUrl, audience, logger });
}

// ---------------------------------------------------------------------
// Test/emulator-only fakes. Never referenced by resolveComplianceScanner
// or any exports.* Cloud Function — a caller must import and pass one of
// these explicitly, which only test code does.
// ---------------------------------------------------------------------

function createFakeCleanScanner({ engineVersion = "fake-test-engine-1", signatureVersion = "fake-sig-1" } = {}) {
  return {
    configured: true,
    isFake: true,
    async scan() {
      return { verdict: MALWARE_SCAN_VERDICT.CLEAN, engineVersion, signatureVersion };
    },
  };
}

function createFakeInfectedScanner({ engineVersion = "fake-test-engine-1", signatureVersion = "fake-sig-1" } = {}) {
  return {
    configured: true,
    isFake: true,
    async scan() {
      return { verdict: MALWARE_SCAN_VERDICT.INFECTED, engineVersion, signatureVersion };
    },
  };
}

function createFakeErrorScanner({ reason = "fake_forced_error" } = {}) {
  return {
    configured: true,
    isFake: true,
    async scan() {
      return { verdict: MALWARE_SCAN_VERDICT.ERROR, reason };
    },
  };
}

// A scanner that returns a malformed/unrecognized verdict string, for
// proving the "unknown verdict never produces clean" requirement — the
// production adapter's own isValidScanResponse() check would already
// catch this from a real HTTP response; this fake exercises the same
// downstream orchestration path without a network call.
function createFakeUnknownVerdictScanner() {
  return {
    configured: true,
    isFake: true,
    async scan() {
      return { verdict: "quarantine_maybe" };
    },
  };
}

module.exports = {
  createClamAvCloudRunScanner,
  resolveComplianceScanner,
  createFakeCleanScanner,
  createFakeInfectedScanner,
  createFakeErrorScanner,
  createFakeUnknownVerdictScanner,
  verifyScanResponseBinding,
  COMPLIANCE_SCAN_RESPONSE_ALLOWED_KEYS,
};
