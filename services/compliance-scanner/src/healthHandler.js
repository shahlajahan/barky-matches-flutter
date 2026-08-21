"use strict";

// Petsupo Marketplace P1-A compliance foundation — compliance-scanner
// service, GET /healthz handler (Slice 2.1, part C). Healthy only when
// clamd itself is reachable AND signatures are loaded AND their build
// timestamp is available AND not older than the shared 48-hour maximum
// (contract.js's SIGNATURE_MAX_AGE_MS — the same number the Functions
// side independently enforces on the response). Never includes bucket
// names, paths, or any request/document information — only the three
// boolean checks and their aggregate.

const { isSignatureFresh } = require("./contract");

async function handleHealthCheck({ config, clamdScanner }) {
  let clamdReachable = false;
  try {
    clamdReachable = await clamdScanner.ping();
  } catch (err) {
    clamdReachable = false;
  }

  const signaturesLoaded = Boolean(
    config.signatureBuiltAt && config.engineVersion && config.signatureVersion
  );
  const signaturesFresh = signaturesLoaded && isSignatureFresh(config.signatureBuiltAt);

  const healthy = clamdReachable && signaturesLoaded && signaturesFresh;

  return {
    status: healthy ? 200 : 503,
    body: {
      status: healthy ? "healthy" : "unhealthy",
      checks: { clamdReachable, signaturesLoaded, signaturesFresh },
    },
  };
}

module.exports = { handleHealthCheck };
