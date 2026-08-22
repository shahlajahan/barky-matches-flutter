"use strict";

// Petsupo Marketplace P1-A compliance foundation — signature-refresh
// pipeline, EICAR fixture materialization (Slice 2.2 final correction,
// Mandatory correction 3).
//
// The canonical, "active" EICAR test string is deliberately NOT stored
// raw anywhere in this repository — a raw copy is exactly what many
// developer machines' endpoint protection, Git clients, GitHub's own
// scanning, and backup tools are DESIGNED to flag and quarantine (that
// is the entire point of the EICAR standard: any AV engine that does
// NOT flag it is considered broken). Instead, ci/fixtures/eicar.b64
// holds a base64 encoding of those bytes — harmless to store, matches
// no AV signature — and this module decodes it ONLY at the moment a
// test or pipeline step actually needs the real bytes, verifying the
// decoded content's hash before ever using or uploading it.
//
// Same split as every other ci/*.js module in this service:
//   1. Pure decode+verify function — no I/O, fully deterministic,
//      fully unit-tested by materializeEicarFixture.test.js.
//   2. A thin CLI wrapper (require.main === module) that reads the
//      real encoded file and writes the verified decoded bytes to a
//      caller-specified output path (intended to be an ephemeral
//      /tmp path inside a test/container workspace — never a
//      permanent repository path).
//
// Fail-closed by design: a missing encoded input, an encoded input
// that fails to base64-decode, or decoded bytes whose SHA-256 does not
// match the pinned expectation all resolve to an explicit failure —
// never a silent fallback, never an empty/placeholder scan.

/**
 * @param {object} args
 * @param {string | null} args.encodedContent Raw text content of the
 *   .b64 file, or null if the file could not be read at all.
 * @param {string} args.expectedSha256 The pinned SHA-256 (lowercase
 *   hex) of the DECODED bytes — from the fixture manifest.
 * @param {(buf: Buffer) => string} args.sha256Of Injected hashing
 *   function so this stays pure/testable without requiring
 *   node:crypto inside the function body itself.
 * @returns {
 *   | { ok: true, bytes: Buffer }
 *   | { ok: false, reason: "missing_encoded_input" | "decode_failed" | "hash_mismatch", detail?: object }
 * }
 */
function decodeAndVerify({ encodedContent, expectedSha256, sha256Of }) {
  if (encodedContent === null || encodedContent === undefined || encodedContent.trim().length === 0) {
    return { ok: false, reason: "missing_encoded_input" };
  }

  let bytes;
  try {
    bytes = Buffer.from(encodedContent.trim(), "base64");
  } catch (err) {
    return { ok: false, reason: "decode_failed" };
  }

  if (bytes.length === 0) {
    // Buffer.from never throws on garbage input for base64 — it
    // silently produces an empty or truncated buffer instead. A
    // decode that produces zero bytes from non-empty input is exactly
    // the "altered/corrupted encoded input" failure mode this function
    // exists to catch, not a legitimate empty fixture.
    return { ok: false, reason: "decode_failed" };
  }

  const actualSha256 = sha256Of(bytes);
  if (actualSha256 !== expectedSha256) {
    return { ok: false, reason: "hash_mismatch", detail: { actualSha256, expectedSha256 } };
  }

  return { ok: true, bytes };
}

module.exports = { decodeAndVerify };

// ---------------------------------------------------------------------
// CLI wrapper — real file I/O, not exercised by any local test.
// ---------------------------------------------------------------------
if (require.main === module) {
  /* eslint-disable no-console */
  const fs = require("node:fs");
  const crypto = require("node:crypto");

  function parseArgs(argv) {
    const out = {};
    for (const raw of argv) {
      const m = raw.match(/^--([a-zA-Z-]+)=(.*)$/);
      if (!m) continue;
      out[m[1].replace(/-([a-z])/g, (_, c) => c.toUpperCase())] = m[2];
    }
    return out;
  }

  const args = parseArgs(process.argv.slice(2));
  if (!args.encoded || !args.expectedSha256 || !args.out) {
    console.error("usage: node materializeEicarFixture.js --encoded=path/to/eicar.b64 --expected-sha256=HEX --out=/tmp/eicar.bin");
    process.exit(2);
  }

  let encodedContent = null;
  try {
    encodedContent = fs.readFileSync(args.encoded, "utf8");
  } catch (err) {
    encodedContent = null;
  }

  const result = decodeAndVerify({
    encodedContent,
    expectedSha256: args.expectedSha256,
    sha256Of: (buf) => crypto.createHash("sha256").update(buf).digest("hex"),
  });

  if (!result.ok) {
    console.error(`materialize-eicar-fixture: FAILED CLOSED — ${JSON.stringify({ reason: result.reason, detail: result.detail })}`);
    process.exit(1);
  }

  // Written with restrictive permissions and only ever to a caller-
  // specified (intended: ephemeral /tmp) path — never back into the
  // repository, never logged.
  fs.writeFileSync(args.out, result.bytes, { mode: 0o600 });
  console.log(JSON.stringify({ materialized: true, sizeBytes: result.bytes.length }));
  process.exit(0);
}
