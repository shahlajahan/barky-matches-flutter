"use strict";

// Deterministic validation for the signature-refresh fixture-integrity
// gate (Slice 2.2 adversarial correction, Mandatory correction 1).
// Exercises only the pure decision functions — no GCS access, no
// child_process, no network, no real /v1/scan call. The CLI wrapper's
// actual GCS reads and scan calls require later staging execution.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  REQUIRED_FIXTURE_IDS,
  PENDING_SENTINEL,
  validateManifestShape,
  decideFixtureIntegrity,
  decideVerdictCheck,
  decideOverallGate,
} = require("./fixtureManifest");

function validEntry(overrides = {}) {
  return {
    id: "benign-text",
    objectPath: "compliance_quarantine/ci-fixtures/benign.txt",
    generation: "123456789",
    sha256: "0903c6568fa5f60c0c42c3b6cde3707a98495f7b490220e57999a55341f2a828",
    sizeBytes: 134,
    expectedVerdict: "clean",
    ...overrides,
  };
}

function manifestWith(fixtures) {
  return { schemaVersion: 1, fixtures };
}

// ---------------------------------------------------------------------
// validateManifestShape — item 6: all required fixtures represented
// ---------------------------------------------------------------------

test("manifest shape: the REAL committed fixtureManifest.json is well-formed except for its expected PENDING_PROVISIONING sentinel", () => {
  const manifestPath = path.join(__dirname, "fixtureManifest.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  assert.equal(manifest.schemaVersion, 1);
  const ids = manifest.fixtures.map((f) => f.id);
  for (const required of REQUIRED_FIXTURE_IDS) {
    assert.ok(ids.includes(required), `manifest must list required fixture "${required}"`);
  }
  // Every checked-in fixture's pinned hash must match its own real file
  // on disk — the manifest and the actual bytes must never drift. For
  // an ENCODED fixture (Mandatory correction 3 — e.g. eicar-standard,
  // stored as base64 so the raw content is never committed in the
  // clear), the pinned sha256/sizeBytes describe the DECODED bytes,
  // not the encoded file — decode first, exactly as
  // ci/materializeEicarFixture.js's real consumers must.
  const crypto = require("node:crypto");
  for (const fixture of manifest.fixtures) {
    const fixturePath = path.join(__dirname, "..", fixture.localPath);
    const raw = fs.readFileSync(fixturePath);
    const bytes = fixture.encoding === "base64" ? Buffer.from(raw.toString("utf8").trim(), "base64") : raw;
    const realSha256 = crypto.createHash("sha256").update(bytes).digest("hex");
    assert.equal(realSha256, fixture.sha256, `${fixture.id}: manifest sha256 must match the real checked-in file (decoded, if encoded)`);
    assert.equal(bytes.length, fixture.sizeBytes, `${fixture.id}: manifest sizeBytes must match the real checked-in file (decoded, if encoded)`);
  }
  // The real manifest is expected to be UNPROVISIONED in this repo
  // state (no upload has happened) — validateManifestShape must
  // therefore currently reject it, proving the sentinel check is live,
  // not dead code.
  const validation = validateManifestShape(manifest);
  assert.equal(validation.valid, false);
  assert.equal(validation.reason, "fixture_not_provisioned");
});

test("manifest shape: a fully-provisioned manifest (sentinel replaced) validates successfully", () => {
  const manifest = manifestWith([
    validEntry({ id: "benign-text" }),
    validEntry({ id: "eicar-standard", expectedVerdict: "infected" }),
    validEntry({ id: "encrypted-pdf", expectedVerdict: "error", expectedErrorCode: "encrypted_document_unsupported" }),
  ]);
  const validation = validateManifestShape(manifest);
  assert.equal(validation.valid, true);
  assert.equal(Object.keys(validation.fixturesById).length, 3);
});

test("manifest shape: missing a required fixture id fails validation (item 6)", () => {
  const manifest = manifestWith([validEntry({ id: "benign-text" }), validEntry({ id: "eicar-standard" })]); // encrypted-pdf missing entirely
  const validation = validateManifestShape(manifest);
  assert.equal(validation.valid, false);
  assert.equal(validation.reason, "required_fixture_missing_from_manifest");
  assert.equal(validation.detail.id, "encrypted-pdf");
});

test("manifest shape: the PENDING_PROVISIONING sentinel on any required fixture fails validation", () => {
  const manifest = manifestWith([
    validEntry({ id: "benign-text", generation: PENDING_SENTINEL }),
    validEntry({ id: "eicar-standard" }),
    validEntry({ id: "encrypted-pdf" }),
  ]);
  const validation = validateManifestShape(manifest);
  assert.equal(validation.valid, false);
  assert.equal(validation.reason, "fixture_not_provisioned");
});

test("manifest shape: a malformed sha256 fails validation", () => {
  const manifest = manifestWith([
    validEntry({ id: "benign-text", sha256: "not-hex" }),
    validEntry({ id: "eicar-standard" }),
    validEntry({ id: "encrypted-pdf" }),
  ]);
  assert.equal(validateManifestShape(manifest).valid, false);
});

test("manifest shape: duplicate fixture ids fail validation", () => {
  const manifest = manifestWith([validEntry({ id: "benign-text" }), validEntry({ id: "benign-text" })]);
  const validation = validateManifestShape(manifest);
  assert.equal(validation.valid, false);
  assert.equal(validation.reason, "duplicate_fixture_id");
});

// ---------------------------------------------------------------------
// decideFixtureIntegrity — items 1, 2, 3
// ---------------------------------------------------------------------

test("integrity: a missing object fails (item 1)", () => {
  const result = decideFixtureIntegrity({ manifestEntry: validEntry(), actual: { exists: false } });
  assert.equal(result.ok, false);
  assert.equal(result.reason, "missing");
});

test("integrity: a generation mismatch fails, even with correct hash/size (item 2)", () => {
  const result = decideFixtureIntegrity({
    manifestEntry: validEntry(),
    actual: { exists: true, generation: "999999999", sha256: validEntry().sha256, sizeBytes: 134 },
  });
  assert.equal(result.ok, false);
  assert.equal(result.reason, "generation_mismatch");
});

test("integrity: a sha256 mismatch fails, even with correct generation/size (item 3 — the object was silently replaced)", () => {
  const result = decideFixtureIntegrity({
    manifestEntry: validEntry(),
    actual: { exists: true, generation: "123456789", sha256: "0".repeat(64), sizeBytes: 134 },
  });
  assert.equal(result.ok, false);
  assert.equal(result.reason, "sha256_mismatch");
});

test("integrity: a size mismatch fails", () => {
  const result = decideFixtureIntegrity({
    manifestEntry: validEntry(),
    actual: { exists: true, generation: "123456789", sha256: validEntry().sha256, sizeBytes: 1 },
  });
  assert.equal(result.ok, false);
  assert.equal(result.reason, "size_mismatch");
});

test("integrity: exact match on generation, sha256, and size passes", () => {
  const entry = validEntry();
  const result = decideFixtureIntegrity({
    manifestEntry: entry,
    actual: { exists: true, generation: entry.generation, sha256: entry.sha256, sizeBytes: entry.sizeBytes },
  });
  assert.equal(result.ok, true);
});

// ---------------------------------------------------------------------
// decideVerdictCheck — item 4
// ---------------------------------------------------------------------

test("verdict: a wrong verdict fails, even for a byte-perfect fixture (item 4 — e.g. a signature regression)", () => {
  const entry = validEntry({ id: "eicar-standard", expectedVerdict: "infected" });
  const result = decideVerdictCheck({ manifestEntry: entry, actual: { verdict: "clean" } });
  assert.equal(result.ok, false);
  assert.equal(result.reason, "verdict_mismatch");
});

test("verdict: correct verdict but wrong errorCode fails (encrypted fixture classified as the wrong kind of error)", () => {
  const entry = validEntry({
    id: "encrypted-pdf",
    expectedVerdict: "error",
    expectedErrorCode: "encrypted_document_unsupported",
  });
  const result = decideVerdictCheck({ manifestEntry: entry, actual: { verdict: "error", errorCode: "gcs_download_failed" } });
  assert.equal(result.ok, false);
  assert.equal(result.reason, "error_code_mismatch");
});

test("verdict: matching verdict and errorCode passes", () => {
  const entry = validEntry({
    id: "encrypted-pdf",
    expectedVerdict: "error",
    expectedErrorCode: "encrypted_document_unsupported",
  });
  const result = decideVerdictCheck({ manifestEntry: entry, actual: { verdict: "error", errorCode: "encrypted_document_unsupported" } });
  assert.equal(result.ok, true);
});

test("verdict: matching plain verdict with no expectedErrorCode requirement passes", () => {
  const entry = validEntry({ id: "benign-text", expectedVerdict: "clean" });
  const result = decideVerdictCheck({ manifestEntry: entry, actual: { verdict: "clean" } });
  assert.equal(result.ok, true);
});

// ---------------------------------------------------------------------
// decideOverallGate — item 5: skipped fixture cannot reach promotion
// ---------------------------------------------------------------------

test("gate: an invalid manifest blocks promotion outright, before any fixture is even considered", () => {
  const gate = decideOverallGate({ manifestValidation: { valid: false, reason: "fixture_not_provisioned" }, results: {} });
  assert.equal(gate.canPromote, false);
  assert.deepEqual(gate.reasons, ["manifest_invalid:fixture_not_provisioned"]);
});

test("gate: all three required fixtures ok -> canPromote true", () => {
  const manifestValidation = { valid: true, fixturesById: {} };
  const results = {
    "benign-text": { ok: true },
    "eicar-standard": { ok: true },
    "encrypted-pdf": { ok: true },
  };
  const gate = decideOverallGate({ manifestValidation, results });
  assert.equal(gate.canPromote, true);
  assert.deepEqual(gate.reasons, []);
});

test("gate: a fixture NEVER CHECKED AT ALL (absent from results) blocks promotion exactly like an explicit failure — this is the regression test for the original 'warn and skip' bug (item 5)", () => {
  const manifestValidation = { valid: true, fixturesById: {} };
  const results = {
    "benign-text": { ok: true },
    "eicar-standard": { ok: true },
    // encrypted-pdf: intentionally absent — simulates the old
    // "fixture not found, log a warning, move on" behavior.
  };
  const gate = decideOverallGate({ manifestValidation, results });
  assert.equal(gate.canPromote, false);
  assert.ok(gate.reasons.includes("encrypted-pdf:not_checked"));
});

test("gate: one failing fixture among otherwise-passing ones still blocks promotion", () => {
  const manifestValidation = { valid: true, fixturesById: {} };
  const results = {
    "benign-text": { ok: true },
    "eicar-standard": { ok: false, reason: "sha256_mismatch" },
    "encrypted-pdf": { ok: true },
  };
  const gate = decideOverallGate({ manifestValidation, results });
  assert.equal(gate.canPromote, false);
  assert.deepEqual(gate.reasons, ["eicar-standard:sha256_mismatch"]);
});

test("gate: multiple failures are all reported, not just the first", () => {
  const manifestValidation = { valid: true, fixturesById: {} };
  const results = {
    "benign-text": { ok: false, reason: "missing" },
    "eicar-standard": { ok: false, reason: "generation_mismatch" },
    "encrypted-pdf": { ok: true },
  };
  const gate = decideOverallGate({ manifestValidation, results });
  assert.equal(gate.canPromote, false);
  assert.equal(gate.reasons.length, 2);
});
