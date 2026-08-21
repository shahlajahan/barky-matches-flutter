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

const { GoogleAuth } = require("google-auth-library");
const {
  MALWARE_SCAN_VERDICT,
  MALWARE_SCAN_TIMEOUT_MS,
  COMPLIANCE_SCANNER_CONTRACT_VERSION,
} = require("./complianceConstants");

// Slice 2 correction (adversarial review 2026-08-21, finding H): the
// scanner response must declare the exact contract version it was built
// against. A missing or mismatched contractVersion is treated exactly
// like a malformed response — fail closed, never "clean" — so a future,
// not-yet-built Cloud Run service that speaks a different (even
// superficially compatible-looking) response shape can never be
// silently trusted.
function isValidScanResponse(body) {
  return (
    body != null &&
    typeof body === "object" &&
    body.contractVersion === COMPLIANCE_SCANNER_CONTRACT_VERSION &&
    Object.values(MALWARE_SCAN_VERDICT).includes(body.verdict)
  );
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
      // the exact request/response schema the service must honor.
      const requestBody = {
        contractVersion: COMPLIANCE_SCANNER_CONTRACT_VERSION,
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
      if (!isValidScanResponse(body)) {
        logger.error("compliance_scan_malformed_response", {
          // Log only that the shape was wrong, never the raw body (which
          // could — in a compromised/misbehaving service — echo back
          // something derived from the file).
          hasBody: body != null,
        });
        return { verdict: MALWARE_SCAN_VERDICT.ERROR, reason: "malformed_response" };
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
};
