"use strict";

// Petsupo Marketplace P1-A compliance foundation — compliance-scanner
// service, structured safe logging (Slice 2.1, part D). A single,
// narrow allowlist of fields may ever be logged; everything else is
// dropped, not merely "usually avoided" — the allowlist is enforced
// here so a future call site cannot accidentally introduce a leak by
// passing an extra field and having it silently included.
//
// Never logged, by construction (not present in the allowlist below):
// raw document bytes, original filename, full objectPath (only a
// truncated/non-reversible correlation form — see truncateForLog),
// supplier/invoice/tax data, Firebase tokens, signed URLs, Authorization
// headers, raw scanner/request bodies, environment values.

const ALLOWED_FIELDS = new Set([
  "requestId",
  "event",
  "verdict",
  "errorCode",
  "reason",
  "latencyMs",
  "engineVersion",
  "signatureVersion",
  "signatureAgeMs",
  "sizeBucket",
  "objectPathHash",
  "statusCode",
]);

// A one-way, non-reversible correlation value for the object path — lets
// operators correlate log lines for the same object across a single
// request's log entries without the path itself (or anything derived
// from the seller's original filename or business identity in readable
// form) ever appearing in logs.
function nonReversibleCorrelationId(value) {
  if (typeof value !== "string" || value.length === 0) return null;
  const crypto = require("node:crypto");
  return crypto.createHash("sha256").update(value).digest("hex").slice(0, 16);
}

// Buckets a byte size into a coarse label rather than logging the exact
// size (which, combined with other signals, is unnecessary precision
// for an operational log) — "small"/"medium"/"large" relative to the
// 15MB bound.
function sizeBucket(sizeBytes) {
  if (typeof sizeBytes !== "number" || !Number.isFinite(sizeBytes)) return "unknown";
  if (sizeBytes <= 1 * 1024 * 1024) return "small";
  if (sizeBytes <= 8 * 1024 * 1024) return "medium";
  return "large";
}

function createLogger({ sink = console } = {}) {
  function write(level, fields) {
    const safe = {};
    for (const key of Object.keys(fields || {})) {
      if (ALLOWED_FIELDS.has(key) && fields[key] !== undefined) {
        safe[key] = fields[key];
      }
    }
    const line = JSON.stringify({ level, ...safe, ts: new Date().toISOString() });
    if (typeof sink[level] === "function") {
      sink[level](line);
    } else {
      sink.log(line);
    }
  }

  return {
    info: (fields) => write("info", fields),
    warn: (fields) => write("warn", fields),
    error: (fields) => write("error", fields),
  };
}

module.exports = { createLogger, nonReversibleCorrelationId, sizeBucket, ALLOWED_FIELDS };
