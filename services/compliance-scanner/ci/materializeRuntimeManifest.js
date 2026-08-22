"use strict";

// Petsupo Marketplace P1-A compliance foundation — signature-refresh
// pipeline, environment-specific runtime fixture-manifest materialization
// (Slice 2.2 runtime-manifest correction).
//
// Problem this closes: services/compliance-scanner/ci/fixtureManifest.json
// is deliberately environment-neutral and ships with fail-closed
// PENDING_PROVISIONING generation sentinels (see that file's own
// comments) — it must never carry a real staging or production GCS
// generation. But ci/fixtureManifest.js's own validateManifestShape()
// REQUIRES real, non-sentinel numeric generations before any build can
// proceed. Something environment-specific has to supply those real
// values at run time, without ever being written into the shared,
// committed manifest.
//
// This module resolves that: given a `gs://` URI and an exact GCS
// object generation (both supplied only via this pipeline's own
// substitutions, never a free-text/local-filesystem path), it downloads
// the REAL, environment-specific runtime manifest — same schema as
// fixtureManifest.json, but with real generations — at EXACTLY that
// pinned generation (never "latest"), validates it with the SAME
// validateManifestShape() the committed manifest is validated with (no
// separate, weaker schema check exists), and writes it to a single
// fixed, pipeline-owned /workspace path that ci/verify-fixtures.sh then
// reads via an internal env var — never a Cloud Build substitution a
// caller could redirect.
//
// Split into three parts:
//   1. Pure decision functions — no I/O, fully deterministic, fully
//      unit-tested by materializeRuntimeManifest.test.js.
//   2. writeManifestAtomic — local-filesystem-only (no network, no GCS
//      dependency), fully deterministic, fully unit-tested. Kept
//      separate from the CLI section specifically so it CAN be tested
//      locally despite living next to GCS-dependent code.
//   3. A thin CLI wrapper (require.main === module) doing the real GCS
//      download — requires later staging execution, not exercised by
//      any local test.

const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { validateManifestShape } = require("./fixtureManifest");

const APPROVED_PREFIX = "ci-runtime-manifests/";
// Allowlist, not a blacklist: every character NOT in this set is
// rejected, which is what actually closes the "ambiguous normalization"
// requirement — percent-encoded traversal, unicode look-alikes,
// backslashes, spaces, and every other byte that could be interpreted
// two different ways by two different layers of this pipeline simply
// cannot appear in a valid object path at all.
const OBJECT_PATH_ALLOWLIST = /^[A-Za-z0-9._/-]+$/;

/**
 * Validates a runtime-manifest `gs://` URI against the configured
 * synthetic-test bucket and the one approved object-name prefix. Pure —
 * performs no network or filesystem access.
 *
 * @param {object} args
 * @param {string} args.uri e.g. "gs://bucket/ci-runtime-manifests/2026-08-22-abcdef.json"
 * @param {string} args.expectedBucket The configured synthetic-test bucket
 *   (must match exactly — this function never trusts a caller-supplied
 *   bucket name).
 * @returns {
 *   | { valid: true, bucket: string, objectPath: string }
 *   | { valid: false, reason: string }
 * }
 */
function validateRuntimeManifestUri({ uri, expectedBucket }) {
  if (typeof uri !== "string" || uri.length === 0) {
    return { valid: false, reason: "missing_uri" };
  }
  if (uri.includes("?")) {
    return { valid: false, reason: "query_string_present" };
  }
  if (uri.includes("#")) {
    return { valid: false, reason: "fragment_present" };
  }
  // eslint-disable-next-line no-control-regex
  if (/[\x00-\x1f\x7f]/.test(uri)) {
    return { valid: false, reason: "control_character_present" };
  }
  if (uri.includes("\\")) {
    return { valid: false, reason: "backslash_present" };
  }
  if (!uri.startsWith("gs://")) {
    return { valid: false, reason: "not_gs_scheme" };
  }

  const rest = uri.slice("gs://".length);
  if (rest.length === 0 || rest.startsWith("/")) {
    return { valid: false, reason: "malformed_uri" };
  }

  const slashIndex = rest.indexOf("/");
  if (slashIndex === -1) {
    return { valid: false, reason: "missing_object_path" };
  }

  const bucket = rest.slice(0, slashIndex);
  const objectPath = rest.slice(slashIndex + 1);

  if (bucket.length === 0) {
    return { valid: false, reason: "malformed_uri" };
  }
  if (typeof expectedBucket !== "string" || expectedBucket.length === 0 || bucket !== expectedBucket) {
    return { valid: false, reason: "wrong_bucket" };
  }

  if (objectPath.length === 0) {
    return { valid: false, reason: "empty_object_path" };
  }
  if (objectPath.endsWith("/")) {
    return { valid: false, reason: "trailing_slash" };
  }
  if (objectPath.includes("//")) {
    return { valid: false, reason: "double_slash" };
  }

  const segments = objectPath.split("/");
  if (segments.some((s) => s === "." || s === "..")) {
    return { valid: false, reason: "path_traversal" };
  }

  if (!objectPath.startsWith(APPROVED_PREFIX)) {
    return { valid: false, reason: "wrong_prefix" };
  }
  if (objectPath.includes("*")) {
    return { valid: false, reason: "wildcard_present" };
  }
  if (!OBJECT_PATH_ALLOWLIST.test(objectPath)) {
    return { valid: false, reason: "disallowed_characters" };
  }
  if (!objectPath.endsWith(".json")) {
    return { valid: false, reason: "not_json_object" };
  }

  return { valid: true, bucket, objectPath };
}

/**
 * Validates a GCS object generation string. Pure. Only a canonical
 * positive integer with no leading zero is accepted — real GCS
 * generations are always large positive integers with no canonical
 * leading-zero form, and "0" is GCS's own reserved sentinel for
 * "object must not currently exist" in generation-precondition
 * semantics, so it is rejected here rather than ever being treated as
 * a real, pinnable generation.
 *
 * @param {string} generation
 * @returns {
 *   | { valid: true, generation: string }
 *   | { valid: false, reason: string }
 * }
 */
function validateRuntimeManifestGeneration(generation) {
  if (typeof generation !== "string" || generation.length === 0) {
    return { valid: false, reason: "missing_generation" };
  }
  if (generation.includes(".")) {
    return { valid: false, reason: "generation_decimal" };
  }
  if (generation.startsWith("-")) {
    return { valid: false, reason: "generation_negative" };
  }
  if (!/^[0-9]+$/.test(generation)) {
    return { valid: false, reason: "generation_not_numeric" };
  }
  if (generation === "0") {
    return { valid: false, reason: "generation_zero" };
  }
  if (generation.length > 1 && generation[0] === "0") {
    return { valid: false, reason: "generation_non_canonical" };
  }
  return { valid: true, generation };
}

/**
 * Writes `buf` to `destPath` atomically: create a uniquely-named
 * temporary file in the SAME DIRECTORY as `destPath` (same directory —
 * and therefore same filesystem — is what makes the final rename an
 * atomic, no-partial-state operation on POSIX), write the complete
 * bytes to it, then rename it onto `destPath`.
 *
 * Safety properties this deliberately provides:
 *   - The temp file is created with O_CREAT | O_EXCL, which — per
 *     POSIX open(2) — fails immediately (EEXIST) if ANYTHING already
 *     exists at that path, INCLUDING a symlink, without ever following
 *     it. This closes the classic "attacker pre-plants a symlink at a
 *     predictable temp path" race: there is no separate stat-then-open
 *     window to race, and a real symlink already sitting at the chosen
 *     temp path causes this function to fail closed, never write
 *     through it.
 *   - The temp filename includes a fresh `crypto.randomBytes` suffix
 *     (16 hex chars / 64 bits of entropy) by default, making a name
 *     collision between concurrent invocations astronomically
 *     unlikely; O_EXCL above additionally makes a same-name collision,
 *     if it ever happened anyway, fail safely rather than one
 *     invocation silently clobbering another's in-progress write.
 *   - `destPath` itself is NEVER opened for writing directly — only
 *     the temp path is. A failure at any point before the final
 *     rename therefore cannot truncate, corrupt, or otherwise touch an
 *     existing file already at `destPath`.
 *   - The temp file is removed on every failure path after creation
 *     (write failure, rename failure) — never left behind.
 *   - The final `fs.renameSync` is a single atomic POSIX rename:
 *     `destPath` is either the complete old content or the complete
 *     new content, never a partial mix, and never briefly absent.
 *
 * @param {string} destPath
 * @param {Buffer} buf
 * @param {object} [options]
 * @param {string} [options.randomSuffix] Injected temp-filename suffix
 *   — overridable ONLY for deterministic testing (e.g. to pre-place a
 *   symlink at the exact temp path a test expects this function to
 *   use). Defaults to a fresh `crypto.randomBytes` value in real use.
 */
function writeManifestAtomic(destPath, buf, options = {}) {
  const suffix = options.randomSuffix || crypto.randomBytes(8).toString("hex");
  const dir = path.dirname(destPath);
  const base = path.basename(destPath);
  const tmpPath = path.join(dir, `.${base}.tmp-${suffix}`);

  let fd;
  try {
    fd = fs.openSync(tmpPath, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL, 0o600);
  } catch (err) {
    throw new Error(`failed to create temporary file (refusing to follow any pre-existing path/symlink): ${err && err.message}`);
  }

  try {
    fs.writeSync(fd, buf);
  } catch (err) {
    try {
      fs.closeSync(fd);
    } catch (closeErr) {
      // ignore — the file is being removed regardless
    }
    try {
      fs.unlinkSync(tmpPath);
    } catch (unlinkErr) {
      // ignore — best-effort cleanup; the original write error is what matters
    }
    throw new Error(`failed to write temporary file: ${err && err.message}`);
  }
  fs.closeSync(fd);

  try {
    fs.renameSync(tmpPath, destPath);
  } catch (err) {
    try {
      fs.unlinkSync(tmpPath);
    } catch (unlinkErr) {
      // ignore — best-effort cleanup; the original rename error is what matters
    }
    throw new Error(`failed to rename temporary file into place: ${err && err.message}`);
  }
}

module.exports = {
  APPROVED_PREFIX,
  validateRuntimeManifestUri,
  validateRuntimeManifestGeneration,
  writeManifestAtomic,
};

// ---------------------------------------------------------------------
// CLI wrapper — real GCS access via @google-cloud/storage (not the
// `gcloud` CLI binary — same builder-image reasoning as every other
// ci/*.js module in this service). Not exercised by any local test.
// STATICALLY reviewed and syntax-checked only.
//
// Deliberately never logs the downloaded manifest's own contents (the
// three fixtures' object paths / sha256 / generation values) — only the
// runtime-manifest's OWN provisioning coordinates (the gs:// bucket,
// object path, and generation the operator already supplied as
// substitutions) and a pass/fail summary.
// ---------------------------------------------------------------------
if (require.main === module) {
  /* eslint-disable no-console */
  const { Storage } = require("@google-cloud/storage");

  function parseArgs(argv) {
    const out = {};
    for (const raw of argv) {
      const m = raw.match(/^--([a-zA-Z-]+)=(.*)$/);
      if (!m) continue;
      out[m[1].replace(/-([a-z])/g, (_, c) => c.toUpperCase())] = m[2];
    }
    return out;
  }

  async function main() {
    const args = parseArgs(process.argv.slice(2));
    if (!args.uri || !args.generation || !args.syntheticBucket || !args.out) {
      console.error(
        "usage: node materializeRuntimeManifest.js --uri=gs://BUCKET/ci-runtime-manifests/NAME.json --generation=N --synthetic-bucket=BUCKET --out=/workspace/.runtime-fixture-manifest.json"
      );
      process.exit(2);
    }

    const uriResult = validateRuntimeManifestUri({ uri: args.uri, expectedBucket: args.syntheticBucket });
    if (!uriResult.valid) {
      console.error(`materialize-runtime-manifest: URI REJECTED — ${uriResult.reason}`);
      process.exit(1);
    }

    const generationResult = validateRuntimeManifestGeneration(args.generation);
    if (!generationResult.valid) {
      console.error(`materialize-runtime-manifest: GENERATION REJECTED — ${generationResult.reason}`);
      process.exit(1);
    }

    const storage = new Storage();
    let buf;
    try {
      // Addressing the File with an explicit `generation` makes every
      // subsequent operation on this handle (download included) apply
      // to EXACTLY that generation, never whatever the bucket's current
      // "latest" happens to be at the moment the request lands — this
      // is the generation-pinning the download itself performs, not
      // just a value this script checks and discards.
      const file = storage.bucket(uriResult.bucket).file(uriResult.objectPath, { generation: generationResult.generation });
      [buf] = await file.download();
    } catch (err) {
      console.error(`materialize-runtime-manifest: DOWNLOAD FAILED — ${err && err.message}`);
      process.exit(1);
    }

    if (!buf || buf.length === 0) {
      console.error("materialize-runtime-manifest: downloaded object is empty");
      process.exit(1);
    }

    let parsed;
    try {
      parsed = JSON.parse(buf.toString("utf8"));
    } catch (err) {
      console.error("materialize-runtime-manifest: downloaded object is not valid JSON");
      process.exit(1);
    }

    // Reuses the SAME schema validator the committed manifest is held
    // to — no separate, weaker check exists for the runtime manifest.
    // This also means a runtime manifest that still carries a
    // PENDING_PROVISIONING sentinel (e.g. a botched provisioning run)
    // fails here exactly as loudly as the committed one would.
    const shapeResult = validateManifestShape(parsed);
    if (!shapeResult.valid) {
      console.error(`materialize-runtime-manifest: SCHEMA REJECTED — ${shapeResult.reason}`);
      process.exit(1);
    }

    // Written atomically (temp file in the same directory, then
    // renamed into place — see writeManifestAtomic's own doc comment)
    // to a caller-specified path that, per this pipeline's own design
    // (see services/compliance-scanner/cloudbuild.signature-refresh.yaml
    // and ci/materialize-runtime-manifest.sh), is always the single
    // fixed /workspace location — never a Cloud Build substitution. A
    // failure here cannot leave a partial or stale destination file.
    try {
      writeManifestAtomic(args.out, buf);
    } catch (err) {
      console.error(`materialize-runtime-manifest: WRITE FAILED — ${err && err.message}`);
      process.exit(1);
    }

    console.log(
      JSON.stringify({
        materialized: true,
        bucket: uriResult.bucket,
        objectPath: uriResult.objectPath,
        generation: generationResult.generation,
      })
    );
    process.exit(0);
  }

  main().catch((err) => {
    console.error(`materialize-runtime-manifest: unexpected error — ${err && err.message}`);
    process.exit(1);
  });
}
