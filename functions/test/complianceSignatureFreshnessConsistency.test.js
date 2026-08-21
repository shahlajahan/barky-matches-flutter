"use strict";

// Petsupo Marketplace P1-A compliance foundation — cross-component
// signature-freshness consistency check (Slice 2.1 review correction 1).
//
// The 48-hour maximum signature age is independently enforced in THREE
// separate deployable units, deliberately with no shared import between
// any of them at build or runtime — see each source's own doc comment
// for why (functions/ and services/compliance-scanner/ are separate
// deploy units; there is no package boundary a runtime `require` could
// safely cross, and this repository's own convention is that Functions
// never imports scanner-service code or vice versa):
//   1. functions/src/marketplace/compliance/complianceConstants.js
//      (COMPLIANCE_SIGNATURE_MAX_AGE_MS) — enforced when the Functions
//      side verifies a scanner response's signatureBuiltAt.
//   2. services/compliance-scanner/src/contract.js
//      (SIGNATURE_MAX_AGE_MS) — enforced by the scanner's own
//      /healthz freshness check and response construction.
//   3. services/compliance-scanner/docker/build-signatures.sh
//      (MAX_AGE_HOURS) — enforced at image-build time: the build fails
//      outright if freshly-fetched signatures are already older than
//      this.
//
// This is a TEST-ONLY cross-check — it is the one place in the
// repository allowed to read across both deployable units, specifically
// because a test asserting they agree is not a runtime or build-time
// coupling between them. It reads each source's ACTUAL value (via a
// real `require()` for the two JS constants — never re-typing "48"
// elsewhere — and a targeted, name-anchored parse of the shell script's
// single canonical `MAX_AGE_HOURS=` assignment), converts units
// explicitly, and fails if any one of the three ever drifts from the
// other two.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const { COMPLIANCE_SIGNATURE_MAX_AGE_MS } = require("../src/marketplace/compliance/complianceConstants");
const { SIGNATURE_MAX_AGE_MS } = require("../../services/compliance-scanner/src/contract");

const BUILD_SIGNATURES_SH_PATH = path.resolve(
  __dirname,
  "../../services/compliance-scanner/docker/build-signatures.sh"
);

// Deliberately anchored to the exact variable name, not a bare search
// for the text "48" — a different-looking value (e.g. a typo'd "480" or
// an unrelated "48" appearing anywhere else in the file, such as a port
// number or byte count) would not match this pattern and would
// correctly leave the extraction failing loudly instead of silently
// matching the wrong number.
const MAX_AGE_HOURS_PATTERN = /^MAX_AGE_HOURS=(\d+)\s*$/m;

function readShellScriptMaxAgeHours() {
  const raw = fs.readFileSync(BUILD_SIGNATURES_SH_PATH, "utf8");
  const match = raw.match(MAX_AGE_HOURS_PATTERN);
  assert.ok(
    match,
    `build-signatures.sh must define a single "MAX_AGE_HOURS=<integer>" line — none found. ` +
      `If the script's structure changed, update MAX_AGE_HOURS_PATTERN here deliberately, ` +
      `not by loosening it to match arbitrary text.`
  );
  return Number(match[1]);
}

test("COMPLIANCE_SIGNATURE_MAX_AGE_MS (Functions) is exactly 48 hours in milliseconds", () => {
  assert.equal(COMPLIANCE_SIGNATURE_MAX_AGE_MS, 48 * 60 * 60 * 1000);
});

test("SIGNATURE_MAX_AGE_MS (scanner contract.js) is exactly 48 hours in milliseconds", () => {
  assert.equal(SIGNATURE_MAX_AGE_MS, 48 * 60 * 60 * 1000);
});

test("build-signatures.sh's MAX_AGE_HOURS is exactly 48", () => {
  assert.equal(readShellScriptMaxAgeHours(), 48);
});

test("all three independently-enforced signature-freshness budgets agree exactly, unit-converted", () => {
  const scannerBuildMaxAgeMs = readShellScriptMaxAgeHours() * 60 * 60 * 1000;

  assert.equal(
    COMPLIANCE_SIGNATURE_MAX_AGE_MS,
    SIGNATURE_MAX_AGE_MS,
    "Functions-side COMPLIANCE_SIGNATURE_MAX_AGE_MS must equal the scanner's own SIGNATURE_MAX_AGE_MS"
  );
  assert.equal(
    COMPLIANCE_SIGNATURE_MAX_AGE_MS,
    scannerBuildMaxAgeMs,
    "Functions-side COMPLIANCE_SIGNATURE_MAX_AGE_MS must equal build-signatures.sh's MAX_AGE_HOURS, converted to milliseconds"
  );
  assert.equal(
    SIGNATURE_MAX_AGE_MS,
    scannerBuildMaxAgeMs,
    "scanner contract.js's SIGNATURE_MAX_AGE_MS must equal build-signatures.sh's MAX_AGE_HOURS, converted to milliseconds"
  );
});

// A deliberately independent-of-the-above sanity bound — proves this
// test suite would actually FAIL on drift, not merely pass by
// coincidence (e.g. if all three sources were broken in the exact same
// way). Pinned to the specific, currently-agreed value rather than only
// to each other, so a simultaneous, identical change to all three still
// requires a conscious edit of this test too.
test("the agreed signature-freshness budget is exactly 48 hours, not some other coincidentally-equal value", () => {
  const FORTY_EIGHT_HOURS_MS = 172800000;
  assert.equal(COMPLIANCE_SIGNATURE_MAX_AGE_MS, FORTY_EIGHT_HOURS_MS);
  assert.equal(SIGNATURE_MAX_AGE_MS, FORTY_EIGHT_HOURS_MS);
  assert.equal(readShellScriptMaxAgeHours() * 60 * 60 * 1000, FORTY_EIGHT_HOURS_MS);
});
