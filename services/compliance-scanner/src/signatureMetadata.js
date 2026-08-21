"use strict";

// Petsupo Marketplace P1-A compliance foundation — compliance-scanner
// service, build-time signature metadata reader (Slice 2.1 correction,
// part B). Extracted from index.js into its own module specifically so
// it is unit-testable against synthetic manifest files, without needing
// a real Docker build.
//
// The manifest at `metadataPath` is written ONCE, at image-build time,
// by docker/build-signatures.sh — which itself derives signatureBuiltAt
// from the downloaded ClamAV database's OWN embedded build metadata via
// `sigtool --info`, never from the build host's wall clock (see that
// script's own doc comment for the full reasoning). This reader's job is
// narrow and strict: read exactly what was recorded, validate it is
// well-formed, and NEVER substitute Date.now() or any other "now" value
// when the manifest is missing, unreadable, or malformed — a missing/
// malformed manifest must read as "signatures unknown", which
// healthHandler.js's freshness check already treats as unhealthy, and
// scanHandler.js's response building already treats as fail-closed
// (an invalid signatureBuiltAt fails contract.js's isSignatureFresh()
// on the Functions side too, independently).

const fs = require("node:fs");

function isValidIsoTimestamp(value) {
  return typeof value === "string" && value.length > 0 && Number.isFinite(Date.parse(value));
}

function readSignatureMetadata({ metadataPath, readFileSync = fs.readFileSync } = {}) {
  const NULL_RESULT = { signatureBuiltAt: null, engineVersion: null, signatureVersion: null };

  let raw;
  try {
    raw = readFileSync(metadataPath, "utf8");
  } catch (err) {
    // Missing/unreadable file — e.g. local dev without the build-time
    // signature-refresh step having run. Never a reason to fabricate a
    // timestamp.
    return NULL_RESULT;
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (err) {
    return NULL_RESULT;
  }

  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    return NULL_RESULT;
  }

  const { signatureBuiltAt, engineVersion, signatureVersion } = parsed;

  // Strict field validation — a manifest with the right JSON shape but
  // garbage values (e.g. signatureBuiltAt: "not-a-date", or an empty
  // engineVersion) must not be treated as partially trustworthy. Any
  // one invalid field invalidates the whole manifest read, since a
  // manifest that got this far wrong was not produced by build-
  // signatures.sh as designed.
  if (
    !isValidIsoTimestamp(signatureBuiltAt) ||
    typeof engineVersion !== "string" ||
    engineVersion.length === 0 ||
    typeof signatureVersion !== "string" ||
    signatureVersion.length === 0
  ) {
    return NULL_RESULT;
  }

  return { signatureBuiltAt, engineVersion, signatureVersion };
}

module.exports = { readSignatureMetadata, isValidIsoTimestamp };
