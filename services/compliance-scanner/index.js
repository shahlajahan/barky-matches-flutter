"use strict";

// Petsupo Marketplace P1-A compliance foundation — compliance-scanner
// service, real entrypoint (Slice 2.1, part C/E). This is the ONLY file
// that wires the REAL adapters (gcsReader.js, clamdProtocol.js's
// createRealClamdScanner) into server.js — it is what the container's
// ENTRYPOINT actually runs, and is not exercised by any unit/HTTP test
// (those construct createServer() directly with fakeAdapters.js).
//
// All configuration comes from environment variables, set at deploy
// time (see the deployment-readiness doc) — nothing here reads a
// credential file or embeds a secret; GCS access uses the container's
// own Cloud Run runtime service-account identity (Application Default
// Credentials), never a key file.

const { createServer } = require("./src/server");
const { createRealGcsReader } = require("./src/gcsReader");
const { createRealClamdScanner } = require("./src/clamdProtocol");
const { createLogger } = require("./src/logger");
const { readSignatureMetadata } = require("./src/signatureMetadata");

function main() {
  const logger = createLogger();
  const metadataPath = process.env.SIGNATURE_METADATA_PATH || "/opt/clamav-signatures/metadata.json";
  const signatureMetadata = readSignatureMetadata({ metadataPath });
  if (!signatureMetadata.signatureBuiltAt) {
    // Not fatal at startup (unlike a missing bucket config below) —
    // /healthz already reports unhealthy for this, which is the correct
    // signal for Cloud Run's own health-based traffic routing to act on,
    // and local dev without a real build is a legitimate reason to reach
    // this. Logged loudly so it is never silently unnoticed either way.
    logger.error({ event: "startup_signature_metadata_missing_or_invalid" });
  }

  const config = {
    allowedBucket: process.env.COMPLIANCE_BUCKET_NAME || "",
    clamdTimeoutMs: Number(process.env.CLAMD_SCAN_TIMEOUT_MS || 45000),
    tmpDir: process.env.SCAN_TMP_DIR || undefined,
    ...signatureMetadata,
  };

  if (!config.allowedBucket) {
    // Fail closed at startup, not silently: an unconfigured bucket would
    // otherwise mean validateScanRequest() rejects every single request
    // as bucket_not_allowed forever — surface this loudly instead.
    logger.error({ event: "startup_config_missing", reason: "COMPLIANCE_BUCKET_NAME not set" });
    process.exitCode = 1;
    return;
  }

  const gcsReader = createRealGcsReader();
  const clamdScanner = createRealClamdScanner({
    socketPath: process.env.CLAMD_SOCKET_PATH || "/var/run/clamav/clamd.sock",
    host: process.env.CLAMD_HOST,
    port: process.env.CLAMD_PORT ? Number(process.env.CLAMD_PORT) : undefined,
    timeoutMs: config.clamdTimeoutMs,
  });

  const server = createServer({ config, gcsReader, clamdScanner, logger });
  const port = Number(process.env.PORT || 8080);

  server.listen(port, () => {
    logger.info({ event: "server_started" });
  });

  // Graceful termination — Cloud Run sends SIGTERM before stopping an
  // instance; stop accepting new connections and let in-flight requests
  // (bounded by CLAMD_SCAN_TIMEOUT_MS regardless) finish.
  const shutdown = () => {
    logger.info({ event: "server_shutting_down" });
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 10000).unref();
  };
  process.on("SIGTERM", shutdown);
  process.on("SIGINT", shutdown);
}

if (require.main === module) {
  main();
}

module.exports = { main };
