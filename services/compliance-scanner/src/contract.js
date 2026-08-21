"use strict";

// Petsupo Marketplace P1-A compliance foundation — compliance-scanner
// service, request/response contract (Slice 2.1, part B/C). Pure
// functions only — no network, no filesystem, no GCS/clamd access — so
// this file is fully unit-testable without any live dependency.
//
// This contract MUST stay in exact sync with the Functions-side
// constants in functions/src/marketplace/compliance/complianceConstants
// .js (COMPLIANCE_SCANNER_CONTRACT_VERSION, COMPLIANCE_SIGNATURE_MAX_
// AGE_MS) and the verification logic in functions/src/marketplace/
// compliance/complianceScanner.js. There is no shared npm package
// between the Functions deploy unit and this service's deploy unit —
// deliberately, since they are separate deployables — so this sync is
// manual and must be checked whenever either side changes the contract
// version or the allowed field set.

const CONTRACT_VERSION = 1;
const SIGNATURE_MAX_AGE_MS = 48 * 60 * 60 * 1000; // 48 hours
const MAX_SIZE_BYTES = 15 * 1024 * 1024; // 15MB
const QUARANTINE_PREFIX = "compliance_quarantine/";

const REQUEST_ALLOWED_KEYS = Object.freeze([
  "contractVersion",
  "requestId",
  "bucket",
  "objectPath",
  "generation",
  "sha256",
  "sizeBytes",
]);

const RESPONSE_ALLOWED_KEYS = Object.freeze([
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

const VERDICT = Object.freeze({ CLEAN: "clean", INFECTED: "infected", ERROR: "error" });

function hasOnlyAllowedKeys(obj, allowedKeys) {
  if (obj === null || typeof obj !== "object" || Array.isArray(obj)) return false;
  const allowed = new Set(allowedKeys);
  return Object.keys(obj).every((k) => allowed.has(k));
}

const SHA256_HEX_PATTERN = /^[a-f0-9]{64}$/i;

// Rejects traversal (.. as a path segment), encoded traversal/null/
// backslash sequences, control characters, and anything not shaped
// exactly like "compliance_quarantine/{businessId}/{sessionId}/
// {objectId}" — mirrors buildComplianceQuarantineObjectPath's shape on
// the Functions side without importing it (separate deploy units).
function isSafeQuarantineObjectPath(objectPath) {
  if (typeof objectPath !== "string" || objectPath.length === 0 || objectPath.length > 1024) {
    return false;
  }
  if (!objectPath.startsWith(QUARANTINE_PREFIX)) return false;
  if (objectPath.includes("..")) return false;
  if (objectPath.includes("\\")) return false;
  if (objectPath.includes("//")) return false;
  // Encoded traversal/null/backslash/slash sequences — case-insensitive,
  // covers both single- and double-encoded forms.
  if (/%2e|%2f|%00|%5c|%252e|%252f/i.test(objectPath)) return false;
  for (let i = 0; i < objectPath.length; i += 1) {
    const code = objectPath.charCodeAt(i);
    if (code <= 0x1f || code === 0x7f) return false; // control characters
  }
  const rest = objectPath.slice(QUARANTINE_PREFIX.length);
  const parts = rest.split("/");
  if (parts.length !== 3) return false;
  return parts.every((part) => part.length > 0);
}

function isValidGeneration(generation) {
  if (typeof generation === "number") {
    return Number.isInteger(generation) && generation > 0;
  }
  if (typeof generation === "string" && generation.length > 0 && generation.length <= 32) {
    return /^[0-9]+$/.test(generation) && Number(generation) > 0;
  }
  return false;
}

// Validates a decoded JSON request body. `allowedBucket` is the single
// configured bucket this deployment is permitted to read from — never a
// caller-supplied value taken at face value.
function validateScanRequest(body, { allowedBucket }) {
  if (!hasOnlyAllowedKeys(body, REQUEST_ALLOWED_KEYS)) {
    return { valid: false, reason: "unexpected_field" };
  }
  if (body.contractVersion !== CONTRACT_VERSION) {
    return { valid: false, reason: "unsupported_contract_version" };
  }
  if (typeof body.requestId !== "string" || body.requestId.length === 0 || body.requestId.length > 128) {
    return { valid: false, reason: "invalid_request_id" };
  }
  if (typeof body.bucket !== "string" || body.bucket !== allowedBucket) {
    return { valid: false, reason: "bucket_not_allowed" };
  }
  if (!isSafeQuarantineObjectPath(body.objectPath)) {
    return { valid: false, reason: "invalid_object_path" };
  }
  if (!isValidGeneration(body.generation)) {
    return { valid: false, reason: "invalid_generation" };
  }
  if (typeof body.sha256 !== "string" || !SHA256_HEX_PATTERN.test(body.sha256)) {
    return { valid: false, reason: "invalid_sha256" };
  }
  if (
    typeof body.sizeBytes !== "number" ||
    !Number.isInteger(body.sizeBytes) ||
    body.sizeBytes <= 0 ||
    body.sizeBytes > MAX_SIZE_BYTES
  ) {
    return { valid: false, reason: "invalid_size_bytes" };
  }
  return {
    valid: true,
    value: {
      contractVersion: body.contractVersion,
      requestId: body.requestId,
      bucket: body.bucket,
      objectPath: body.objectPath,
      generation: String(body.generation),
      sha256: body.sha256.toLowerCase(),
      sizeBytes: body.sizeBytes,
    },
  };
}

// Builds the exact closed-schema response body. `errorCode` is included
// only when explicitly provided (never a bare empty string).
function buildScanResponse({
  request,
  verdict,
  engineVersion = null,
  signatureVersion = null,
  signatureBuiltAt,
  scannedAt = new Date().toISOString(),
  errorCode,
}) {
  const response = {
    contractVersion: CONTRACT_VERSION,
    requestId: request.requestId,
    verdict,
    bucket: request.bucket,
    objectPath: request.objectPath,
    generation: request.generation,
    sha256: request.sha256,
    sizeBytes: request.sizeBytes,
    signatureBuiltAt,
    scannedAt,
  };
  if (verdict === VERDICT.CLEAN || verdict === VERDICT.INFECTED) {
    response.engineVersion = engineVersion;
    response.signatureVersion = signatureVersion;
  }
  if (errorCode) {
    response.errorCode = errorCode;
  }
  return response;
}

function isSignatureFresh(signatureBuiltAtIso, { now = Date.now(), maxAgeMs = SIGNATURE_MAX_AGE_MS } = {}) {
  const builtAtMs = Date.parse(signatureBuiltAtIso);
  if (!Number.isFinite(builtAtMs)) return false;
  const ageMs = now - builtAtMs;
  return ageMs >= 0 && ageMs <= maxAgeMs;
}

module.exports = {
  CONTRACT_VERSION,
  SIGNATURE_MAX_AGE_MS,
  MAX_SIZE_BYTES,
  QUARANTINE_PREFIX,
  REQUEST_ALLOWED_KEYS,
  RESPONSE_ALLOWED_KEYS,
  VERDICT,
  hasOnlyAllowedKeys,
  isSafeQuarantineObjectPath,
  isValidGeneration,
  validateScanRequest,
  buildScanResponse,
  isSignatureFresh,
};
