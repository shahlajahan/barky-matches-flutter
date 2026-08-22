"use strict";

// Petsupo Marketplace P1-A compliance foundation — compliance-scanner
// signature-refresh pipeline, versioned security-fixture verification
// (Slice 2.2 adversarial correction, Mandatory correction 1).
//
// Same split as ci/signatureRefreshLock.js:
//   1. Pure decision functions — no I/O, fully deterministic, fully
//      unit-tested by fixtureManifest.test.js.
//   2. A thin CLI wrapper (require.main === module) doing the real GCS
//      reads and real /v1/scan calls — requires later staging
//      execution, not exercised by any local test.
//
// Design intent (read before changing): the pipeline must NEVER
// silently regenerate a "trusted" fixture mid-run and then validate its
// own freshly-uploaded copy — that would validate nothing. Every
// mandatory fixture (see REQUIRED_FIXTURE_IDS) must already exist, at a
// manifest-pinned object path and generation, BEFORE the pipeline ever
// runs, uploaded once by a separate, documented provisioning process
// (see the readiness doc). This module's only job is to prove, on
// every run, that what is actually sitting at that path right now still
// matches the manifest exactly — content hash, size, generation, and
// (via a real scan) the expected verdict — and to fail the ENTIRE
// build closed if any single mandatory fixture fails that proof. A
// skipped check is never a passed check anywhere in this module: every
// function here returns an explicit ok:false with a reason, never
// silently omits a fixture from its result set.

const REQUIRED_FIXTURE_IDS = Object.freeze(["benign-text", "eicar-standard", "encrypted-pdf"]);
const PENDING_SENTINEL = "PENDING_PROVISIONING";
const SHA256_HEX_PATTERN = /^[a-f0-9]{64}$/;

/**
 * Validates the MANIFEST ITSELF — schema shape, required fixtures
 * present, no field left as the unprovisioned sentinel, hashes
 * well-formed. This is what test requirement 6 ("all required fixtures
 * are represented in the manifest") exercises. Does not touch GCS.
 *
 * @param {object} manifest Parsed fixtureManifest.json content.
 * @returns {
 *   | { valid: true, fixturesById: Record<string, object> }
 *   | { valid: false, reason: string, detail?: object }
 * }
 */
function validateManifestShape(manifest) {
  if (!manifest || typeof manifest !== "object" || !Array.isArray(manifest.fixtures)) {
    return { valid: false, reason: "malformed_manifest" };
  }
  if (manifest.schemaVersion !== 1) {
    return { valid: false, reason: "unsupported_schema_version" };
  }

  const fixturesById = {};
  for (const fixture of manifest.fixtures) {
    if (!fixture || typeof fixture.id !== "string" || fixture.id.length === 0) {
      return { valid: false, reason: "fixture_missing_id" };
    }
    if (fixturesById[fixture.id]) {
      return { valid: false, reason: "duplicate_fixture_id", detail: { id: fixture.id } };
    }
    fixturesById[fixture.id] = fixture;
  }

  for (const requiredId of REQUIRED_FIXTURE_IDS) {
    const fixture = fixturesById[requiredId];
    if (!fixture) {
      return { valid: false, reason: "required_fixture_missing_from_manifest", detail: { id: requiredId } };
    }
    if (typeof fixture.objectPath !== "string" || fixture.objectPath.length === 0) {
      return { valid: false, reason: "invalid_object_path", detail: { id: requiredId } };
    }
    if (typeof fixture.generation !== "string" || fixture.generation.length === 0) {
      return { valid: false, reason: "invalid_generation_field", detail: { id: requiredId } };
    }
    if (fixture.generation === PENDING_SENTINEL) {
      // The exact failure mode Mandatory correction 1 exists to close:
      // an unprovisioned fixture must fail the manifest itself, before
      // any GCS read is even attempted.
      return { valid: false, reason: "fixture_not_provisioned", detail: { id: requiredId } };
    }
    if (!/^\d+$/.test(fixture.generation)) {
      return { valid: false, reason: "generation_not_numeric", detail: { id: requiredId } };
    }
    if (typeof fixture.sha256 !== "string" || !SHA256_HEX_PATTERN.test(fixture.sha256)) {
      return { valid: false, reason: "invalid_sha256", detail: { id: requiredId } };
    }
    if (!Number.isInteger(fixture.sizeBytes) || fixture.sizeBytes <= 0) {
      return { valid: false, reason: "invalid_size_bytes", detail: { id: requiredId } };
    }
    if (typeof fixture.expectedVerdict !== "string" || fixture.expectedVerdict.length === 0) {
      return { valid: false, reason: "invalid_expected_verdict", detail: { id: requiredId } };
    }
  }

  return { valid: true, fixturesById };
}

/**
 * Compares a manifest entry against the REAL object state read from
 * GCS. Pure — the caller does the actual GCS read; this function only
 * decides pass/fail from already-collected facts.
 *
 * @param {object} args
 * @param {{ objectPath: string, generation: string, sha256: string, sizeBytes: number }} args.manifestEntry
 * @param {{ exists: boolean, generation?: string, sha256?: string, sizeBytes?: number }} args.actual
 *   `actual.sha256` must be computed from the REAL DOWNLOADED BYTES by
 *   the caller — never trusted from self-reported object metadata (see
 *   this file's top-of-file comment and the CLI half below).
 * @returns {
 *   | { ok: true }
 *   | { ok: false, reason: "missing" | "generation_mismatch" | "sha256_mismatch" | "size_mismatch" }
 * }
 */
function decideFixtureIntegrity({ manifestEntry, actual }) {
  if (!actual || actual.exists !== true) {
    return { ok: false, reason: "missing" };
  }
  if (String(actual.generation) !== String(manifestEntry.generation)) {
    return { ok: false, reason: "generation_mismatch" };
  }
  if (actual.sha256 !== manifestEntry.sha256) {
    return { ok: false, reason: "sha256_mismatch" };
  }
  if (actual.sizeBytes !== manifestEntry.sizeBytes) {
    return { ok: false, reason: "size_mismatch" };
  }
  return { ok: true };
}

/**
 * Compares a real scan result (from an actual /v1/scan call against
 * the fixture) to the manifest's expected verdict/errorCode. A fixture
 * that is byte-for-byte correct but scans with the WRONG verdict (e.g.
 * a signature-database regression turning EICAR into "clean", or the
 * encrypted-PDF fixture somehow classifying as plain "infected" instead
 * of the specific encrypted_document_unsupported error) must fail the
 * build exactly as loudly as a missing fixture would.
 *
 * @param {object} args
 * @param {{ expectedVerdict: string, expectedErrorCode?: string }} args.manifestEntry
 * @param {{ verdict: string, errorCode?: string }} args.actual
 * @returns {
 *   | { ok: true }
 *   | { ok: false, reason: "verdict_mismatch" | "error_code_mismatch" }
 * }
 */
function decideVerdictCheck({ manifestEntry, actual }) {
  if (!actual || actual.verdict !== manifestEntry.expectedVerdict) {
    return { ok: false, reason: "verdict_mismatch" };
  }
  if (manifestEntry.expectedErrorCode && actual.errorCode !== manifestEntry.expectedErrorCode) {
    return { ok: false, reason: "error_code_mismatch" };
  }
  return { ok: true };
}

/**
 * Aggregates the manifest-shape check plus one integrity+verdict result
 * per required fixture into a single build/no-build decision. This is
 * the function whose result the CLI half's exit code follows directly
 * — used to prove test requirement 5 ("skipped fixture cannot reach
 * promotion") deterministically: any fixture absent from `results`
 * (i.e. never checked at all — the old "warn and skip" bug) is treated
 * exactly the same as a fixture present with ok:false, never as a pass.
 *
 * @param {object} args
 * @param {{ valid: boolean, fixturesById?: Record<string, object> }} args.manifestValidation Result of validateManifestShape.
 * @param {Record<string, { ok: boolean, reason?: string }>} args.results
 *   One entry per fixture id this run actually attempted to check.
 * @returns {{ canPromote: boolean, reasons: string[] }}
 */
function decideOverallGate({ manifestValidation, results }) {
  if (!manifestValidation.valid) {
    return { canPromote: false, reasons: [`manifest_invalid:${manifestValidation.reason}`] };
  }

  const reasons = [];
  for (const requiredId of REQUIRED_FIXTURE_IDS) {
    const result = results[requiredId];
    if (!result) {
      // Never checked at all — the exact bug this correction closes.
      // Absence is failure, not an implicit pass.
      reasons.push(`${requiredId}:not_checked`);
      continue;
    }
    if (!result.ok) {
      reasons.push(`${requiredId}:${result.reason}`);
    }
  }

  return { canPromote: reasons.length === 0, reasons };
}

module.exports = {
  REQUIRED_FIXTURE_IDS,
  PENDING_SENTINEL,
  validateManifestShape,
  decideFixtureIntegrity,
  decideVerdictCheck,
  decideOverallGate,
};

// ---------------------------------------------------------------------
// CLI wrapper — real GCS access via @google-cloud/storage (NOT the
// `gcloud` CLI binary — see the same builder-image reasoning in
// ci/signatureRefreshLock.js's CLI section: this keeps this step's
// runtime requirement to "Node.js + this package's node_modules" only).
// Not exercised by any local test. STATICALLY reviewed and
// syntax-checked only.
//
// On success, ALSO writes two shell-consumable artifacts to
// /workspace, specifically so LATER pipeline steps (verify-candidate-
// container.sh, verify-deployed-candidate.sh) never need a `node`
// runtime themselves — they only need to `. /workspace/.fixtures.env`
// (plain shell variable assignments) and, for the EICAR fixture
// specifically, read the already-decoded, already-hash-verified bytes
// directly from /workspace/.eicar-materialized.bin:
//   - /workspace/.fixtures.env: one `FIXTURE_<ID>_<FIELD>=value` line
//     per required fixture's objectPath/generation/sha256/sizeBytes.
//   - /workspace/.eicar-materialized.bin: the REAL decoded EICAR bytes
//     (Mandatory correction 3) — materialized and hash-verified exactly
//     once, here, in this Node-having step; consumed read-only by every
//     later step that needs them. Written with 0600 permissions, never
//     logged, scoped to this single build's own /workspace (Cloud
//     Build's standard ephemeral shared volume for one build — not
//     persisted beyond it, not uploaded anywhere by this step itself).
// ---------------------------------------------------------------------
if (require.main === module) {
  /* eslint-disable no-console */
  const { Storage } = require("@google-cloud/storage");
  const crypto = require("node:crypto");
  const fs = require("node:fs");
  const { decodeAndVerify } = require("./materializeEicarFixture");

  function parseArgs(argv) {
    const out = {};
    for (const raw of argv) {
      const m = raw.match(/^--([a-zA-Z-]+)=(.*)$/);
      if (!m) continue;
      out[m[1].replace(/-([a-z])/g, (_, c) => c.toUpperCase())] = m[2];
    }
    return out;
  }

  async function readRealObject(storage, bucket, objectPath) {
    try {
      const file = storage.bucket(bucket).file(objectPath);
      const [buf] = await file.download();
      const [metadata] = await file.getMetadata();
      const sha256 = crypto.createHash("sha256").update(buf).digest("hex");
      return { exists: true, generation: metadata.generation, sha256, sizeBytes: buf.length };
    } catch (err) {
      return { exists: false };
    }
  }

  function envSafeId(id) {
    return id.toUpperCase().replace(/-/g, "_");
  }

  function writeFixturesEnv(fixturesById) {
    const lines = [];
    for (const id of REQUIRED_FIXTURE_IDS) {
      const f = fixturesById[id];
      const prefix = `FIXTURE_${envSafeId(id)}`;
      lines.push(`${prefix}_OBJECT_PATH=${f.objectPath}`);
      lines.push(`${prefix}_GENERATION=${f.generation}`);
      lines.push(`${prefix}_SHA256=${f.sha256}`);
      lines.push(`${prefix}_SIZE_BYTES=${f.sizeBytes}`);
      lines.push(`${prefix}_EXPECTED_VERDICT=${f.expectedVerdict}`);
      if (f.expectedErrorCode) lines.push(`${prefix}_EXPECTED_ERROR_CODE=${f.expectedErrorCode}`);
    }
    fs.writeFileSync("/workspace/.fixtures.env", lines.join("\n") + "\n", { mode: 0o600 });
  }

  function materializeEicar(fixturesById) {
    const entry = fixturesById["eicar-standard"];
    const encodedPath = require("node:path").join(__dirname, entry.localPath.replace(/^ci\//, ""));
    let encodedContent = null;
    try {
      encodedContent = fs.readFileSync(encodedPath, "utf8");
    } catch (err) {
      encodedContent = null;
    }
    const result = decodeAndVerify({
      encodedContent,
      expectedSha256: entry.sha256,
      sha256Of: (buf) => crypto.createHash("sha256").update(buf).digest("hex"),
    });
    if (!result.ok) {
      console.error(`fixture-manifest: EICAR MATERIALIZATION FAILED — ${JSON.stringify(result)}`);
      return false;
    }
    fs.writeFileSync("/workspace/.eicar-materialized.bin", result.bytes, { mode: 0o600 });
    return true;
  }

  async function main() {
    const args = parseArgs(process.argv.slice(2));
    if (!args.bucket || !args.manifest) {
      console.error("usage: node fixtureManifest.js --bucket=B --manifest=path/to/fixtureManifest.json");
      process.exit(2);
    }

    const manifest = JSON.parse(fs.readFileSync(args.manifest, "utf8"));
    const manifestValidation = validateManifestShape(manifest);

    if (!manifestValidation.valid) {
      console.error(`fixture-manifest: MANIFEST INVALID — ${JSON.stringify(manifestValidation)}`);
      console.error("fixture-manifest: refusing to check any fixture against an invalid manifest — build FAILS closed.");
      process.exit(1);
    }

    const storage = new Storage();
    const results = {};
    for (const id of REQUIRED_FIXTURE_IDS) {
      const entry = manifestValidation.fixturesById[id];
      const actual = await readRealObject(storage, args.bucket, entry.objectPath);
      const integrity = decideFixtureIntegrity({ manifestEntry: entry, actual });
      results[id] = integrity;
      if (!integrity.ok) {
        console.error(`fixture-manifest: FIXTURE FAILED — ${id}: ${integrity.reason}`);
      }
      // Verdict check requires a real scan — left to the calling shell
      // script, which has the scanner URL/token context.
    }

    const gate = decideOverallGate({ manifestValidation, results });
    if (!gate.canPromote) {
      console.log(JSON.stringify({ canPromote: false, reasons: gate.reasons, results }));
      process.exit(1);
    }

    const eicarOk = materializeEicar(manifestValidation.fixturesById);
    if (!eicarOk) {
      console.log(JSON.stringify({ canPromote: false, reasons: ["eicar-standard:materialization_failed"], results }));
      process.exit(1);
    }
    writeFixturesEnv(manifestValidation.fixturesById);

    console.log(JSON.stringify({ canPromote: true, reasons: [], results }));
    process.exit(0);
  }

  main().catch((err) => {
    console.error(`fixture-manifest: unexpected error — ${err && err.message}`);
    process.exit(1);
  });
}
