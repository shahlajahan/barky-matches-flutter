"use strict";

// Deterministic validation for EICAR fixture materialization (Slice
// 2.2 final correction, Mandatory correction 3). Exercises the pure
// decode+verify function AND scans the actual repository source for
// the exact failure mode this correction exists to prevent: a raw,
// AV-triggering copy of the canonical EICAR string committed in the
// clear.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { decodeAndVerify } = require("./materializeEicarFixture");

const REPO_ROOT = path.join(__dirname, "..");
const EXPECTED_SHA256 = "275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f";

function sha256Of(buf) {
  return crypto.createHash("sha256").update(buf).digest("hex");
}

// The canonical, literal EICAR signature substring — deliberately
// spelled out ONLY here, inside a test assertion that PROVES its
// absence elsewhere, never as fixture content itself.
const CANONICAL_EICAR_MARKER = "EICAR-STANDARD-ANTIVIRUS-TEST-FILE";

// ---------------------------------------------------------------------
// decodeAndVerify — pure logic
// ---------------------------------------------------------------------

test("decodeAndVerify: correct encoded input with matching hash succeeds and returns the real decoded bytes", () => {
  const encoded = fs.readFileSync(path.join(REPO_ROOT, "ci/fixtures/eicar.b64"), "utf8");
  const result = decodeAndVerify({ encodedContent: encoded, expectedSha256: EXPECTED_SHA256, sha256Of });
  assert.equal(result.ok, true);
  assert.equal(result.bytes.length, 68);
  assert.equal(result.bytes.toString("utf8").includes(CANONICAL_EICAR_MARKER), true);
});

test("decodeAndVerify: deterministic decoding produces the expected, pinned SHA-256 exactly", () => {
  const encoded = fs.readFileSync(path.join(REPO_ROOT, "ci/fixtures/eicar.b64"), "utf8");
  const result = decodeAndVerify({ encodedContent: encoded, expectedSha256: EXPECTED_SHA256, sha256Of });
  assert.equal(result.ok, true);
  assert.equal(sha256Of(result.bytes), EXPECTED_SHA256);
});

test("decodeAndVerify: missing encoded input fails closed (item: missing encoded input fails)", () => {
  for (const missing of [null, undefined, "", "   \n"]) {
    const result = decodeAndVerify({ encodedContent: missing, expectedSha256: EXPECTED_SHA256, sha256Of });
    assert.equal(result.ok, false);
    assert.equal(result.reason, "missing_encoded_input");
  }
});

test("decodeAndVerify: altered/corrupted encoded input fails closed (item: altered encoded input fails)", () => {
  const realEncoded = fs.readFileSync(path.join(REPO_ROOT, "ci/fixtures/eicar.b64"), "utf8");
  const tampered = realEncoded.trim().slice(0, -4) + "XXXX"; // corrupt the tail
  const result = decodeAndVerify({ encodedContent: tampered, expectedSha256: EXPECTED_SHA256, sha256Of });
  assert.equal(result.ok, false);
  assert.equal(result.reason, "hash_mismatch");
});

test("decodeAndVerify: valid base64 decoding to WRONG content (different but well-formed payload) fails on hash mismatch, not silently accepted", () => {
  const wrongPayload = Buffer.from("this is not eicar at all").toString("base64");
  const result = decodeAndVerify({ encodedContent: wrongPayload, expectedSha256: EXPECTED_SHA256, sha256Of });
  assert.equal(result.ok, false);
  assert.equal(result.reason, "hash_mismatch");
});

test("decodeAndVerify: gibberish that is not valid base64 content fails closed rather than producing garbage bytes silently accepted", () => {
  const result = decodeAndVerify({ encodedContent: "!!!not-base64-at-all!!!", expectedSha256: EXPECTED_SHA256, sha256Of });
  assert.equal(result.ok, false);
  // Buffer.from's base64 decoder is lenient (skips invalid chars rather
  // than throwing), so this specific gibberish may decode to a short,
  // wrong-hash buffer rather than throwing — either classification
  // (decode_failed or hash_mismatch) is an acceptable fail-closed
  // outcome; ok:false is the only hard requirement.
  assert.ok(["decode_failed", "hash_mismatch"].includes(result.reason));
});

// ---------------------------------------------------------------------
// Repository source scan — item: "repository source does not contain
// the canonical raw EICAR string"
// ---------------------------------------------------------------------

test("repository scan: no file under services/compliance-scanner (excluding node_modules) contains the raw, literal EICAR string", () => {
  const offenders = [];
  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.name === "node_modules" || entry.name === ".git") continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
        continue;
      }
      // The .b64 fixture is deliberately excluded from this raw-string
      // scan — its whole point is to hold an ENCODED representation
      // that does NOT contain the raw marker string in the first
      // place; asserting that is covered by the next test instead.
      // This test file itself is also excluded — it deliberately
      // spells out CANONICAL_EICAR_MARKER once, as the string this
      // very scan searches FOR, which is the one legitimate,
      // self-referential place it belongs.
      if (full === __filename) continue;
      const text = fs.readFileSync(full, "latin1");
      if (text.includes(CANONICAL_EICAR_MARKER) && !full.endsWith(".b64")) {
        offenders.push(path.relative(REPO_ROOT, full));
      }
    }
  }
  walk(REPO_ROOT);
  assert.deepEqual(offenders, [], `raw EICAR string found in: ${offenders.join(", ")}`);
});

test("repository scan: ci/fixtures/eicar.b64 itself does not contain the raw marker string (confirms it is genuinely encoded, not just renamed)", () => {
  const text = fs.readFileSync(path.join(REPO_ROOT, "ci/fixtures/eicar.b64"), "utf8");
  assert.equal(text.includes(CANONICAL_EICAR_MARKER), false);
});

test("repository scan: ci/fixtures/eicar.txt (the old raw fixture path) no longer exists", () => {
  assert.equal(fs.existsSync(path.join(REPO_ROOT, "ci/fixtures/eicar.txt")), false);
});
