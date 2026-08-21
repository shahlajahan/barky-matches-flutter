"use strict";

// Petsupo Marketplace P1-A compliance foundation — compliance-scanner
// service, POST /v1/scan handler (Slice 2.1, part C). Composes pure
// request validation (contract.js) with two injected adapters
// (gcsReader, clamdScanner) — production wiring (server.js/index.js)
// injects the real ones; every test injects fakes, so this file itself
// never touches a real network, socket, or filesystem dependency beyond
// its own private temp file.

const crypto = require("node:crypto");
const fs = require("node:fs/promises");
const path = require("node:path");
const os = require("node:os");
const { validateScanRequest, buildScanResponse, VERDICT } = require("./contract");
const { sizeBucket, nonReversibleCorrelationId } = require("./logger");

function mapClamdErrorCode(rawMessage) {
  const msg = String(rawMessage || "").toLowerCase();
  if (msg.includes("timeout")) return "clamd_timeout";
  if (msg.includes("connection")) return "clamd_connection_error";
  if (msg.includes("write")) return "clamd_write_failed";
  if (msg === "empty_response") return "clamd_empty_response";
  if (msg === "unparseable_clamd_response") return "clamd_unparseable_response";
  return "clamd_scan_failed";
}

// `config`: { allowedBucket, clamdTimeoutMs, signatureBuiltAt,
// engineVersion, signatureVersion, tmpDir } — all server-owned, never
// derived from the request.
async function handleScanRequest({ body, config, gcsReader, clamdScanner, logger }) {
  const startedAt = Date.now();

  const validation = validateScanRequest(body, { allowedBucket: config.allowedBucket });
  if (!validation.valid) {
    logger.warn({ event: "scan_request_rejected", reason: validation.reason });
    return { status: 400, body: { error: "invalid_request", reason: validation.reason } };
  }
  const request = validation.value;
  const objectPathHash = nonReversibleCorrelationId(request.objectPath);

  // Generation-pinned, read-only fetch — this call is the ONLY GCS
  // interaction this handler ever performs. It never uploads, copies,
  // modifies, deletes, lists, or reads anything under compliance_docs/;
  // the request's own objectPath was already required (validateScanRequest)
  // to fall under compliance_quarantine/, and no other path is ever
  // constructed or accepted.
  let downloadedBuffer;
  try {
    downloadedBuffer = await gcsReader.downloadGenerationPinned({
      bucket: request.bucket,
      objectPath: request.objectPath,
      generation: request.generation,
    });
  } catch (err) {
    logger.error({ event: "gcs_download_failed", requestId: request.requestId, objectPathHash });
    return {
      status: 200,
      body: buildScanResponse({
        request,
        verdict: VERDICT.ERROR,
        signatureBuiltAt: config.signatureBuiltAt,
        errorCode: "gcs_download_failed",
      }),
    };
  }

  // Independently recompute size and SHA-256 — the caller-declared
  // values in the request are never trusted for the scan decision, only
  // used to route the download and as the value to compare against.
  const actualSize = downloadedBuffer.length;
  const actualSha256 = crypto.createHash("sha256").update(downloadedBuffer).digest("hex");
  if (actualSize !== request.sizeBytes || actualSha256 !== request.sha256) {
    logger.warn({ event: "scan_content_mismatch", requestId: request.requestId, objectPathHash });
    return {
      status: 200,
      body: buildScanResponse({
        request,
        verdict: VERDICT.ERROR,
        signatureBuiltAt: config.signatureBuiltAt,
        errorCode: "content_mismatch",
      }),
    };
  }

  let tempFilePath = null;
  try {
    // Private temporary file, 0600, unique per request — an operational/
    // audit artifact of exactly what was scanned; the actual clamd
    // interaction below streams the buffer directly (INSTREAM), it does
    // not read this file back.
    tempFilePath = path.join(config.tmpDir || os.tmpdir(), `scan-${crypto.randomUUID()}.bin`);
    await fs.writeFile(tempFilePath, downloadedBuffer, { mode: 0o600 });

    const scanResult = await clamdScanner.scanBuffer(downloadedBuffer);
    const latencyMs = Date.now() - startedAt;

    if (scanResult.outcome === VERDICT.CLEAN) {
      logger.info({
        event: "scan_completed",
        requestId: request.requestId,
        verdict: "clean",
        latencyMs,
        engineVersion: config.engineVersion,
        signatureVersion: config.signatureVersion,
        sizeBucket: sizeBucket(actualSize),
      });
      return {
        status: 200,
        body: buildScanResponse({
          request,
          verdict: VERDICT.CLEAN,
          engineVersion: config.engineVersion,
          signatureVersion: config.signatureVersion,
          signatureBuiltAt: config.signatureBuiltAt,
        }),
      };
    }

    if (scanResult.outcome === "infected") {
      logger.warn({
        event: "scan_completed",
        requestId: request.requestId,
        verdict: "infected",
        latencyMs,
        engineVersion: config.engineVersion,
        signatureVersion: config.signatureVersion,
        sizeBucket: sizeBucket(actualSize),
      });
      return {
        status: 200,
        body: buildScanResponse({
          request,
          verdict: VERDICT.INFECTED,
          engineVersion: config.engineVersion,
          signatureVersion: config.signatureVersion,
          signatureBuiltAt: config.signatureBuiltAt,
        }),
      };
    }

    // Slice 2.1 correction, part C: an encrypted/password-protected
    // document that clamd's heuristic engine flagged (see
    // clamdProtocol.js's narrow, explicit Heuristics.Encrypted.*
    // allowlist) is fail-closed exactly like any other error — it must
    // never become clean — but it is NOT reported as confirmed malware
    // either, since that would be factually false. A stable, distinct
    // errorCode (never the generic clamd_scan_failed) lets the caller
    // and any audit/UI-facing surface tell "we could not verify this is
    // safe because we cannot inspect encrypted content" apart from "this
    // is a detected threat".
    if (scanResult.outcome === "unsupported") {
      logger.warn({
        event: "scan_completed",
        requestId: request.requestId,
        errorCode: "encrypted_document_unsupported",
        latencyMs,
        sizeBucket: sizeBucket(actualSize),
      });
      return {
        status: 200,
        body: buildScanResponse({
          request,
          verdict: VERDICT.ERROR,
          signatureBuiltAt: config.signatureBuiltAt,
          errorCode: "encrypted_document_unsupported",
        }),
      };
    }

    // Every remaining outcome (explicit "error", a thrown/rejected
    // scanBuffer, a timeout, an unparseable clamd reply, or any future
    // unrecognized outcome value) maps to VERDICT.ERROR — there is no
    // code path in this handler that can reach VERDICT.CLEAN except the
    // single branch above, reached only via an explicit "clean" outcome
    // from the injected scanner.
    const reason = scanResult && scanResult.message;
    logger.error({ event: "scan_error", requestId: request.requestId, reason, latencyMs });
    return {
      status: 200,
      body: buildScanResponse({
        request,
        verdict: VERDICT.ERROR,
        signatureBuiltAt: config.signatureBuiltAt,
        errorCode: mapClamdErrorCode(reason),
      }),
    };
  } finally {
    if (tempFilePath) {
      await fs.unlink(tempFilePath).catch(() => {});
    }
  }
}

module.exports = { handleScanRequest, mapClamdErrorCode };
