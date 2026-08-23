"use strict";

// Petsupo Marketplace P1-A compliance foundation — signature-refresh
// pipeline, generation-pinning re-verification helper for
// ci/verify-deployed-candidate.sh (single-authoritative-execution-
// identity correction, closing a real staging failure — build
// 9cb468c3-2401-403a-8ed6-e4afabfa9f9a, step verify-deployed-candidate:
// "does not have storage.objects.list access to the Google Cloud
// Storage bucket").
//
// Root cause: the previous implementation used `gcloud storage cp` /
// `gcloud storage objects describe` / `gcloud storage rm -a` against
// the synthetic bucket. `gcloud storage cp`'s own client-side
// implementation performs a bucket-level LIST call as part of its
// destination-resolution logic even for a single, fully-qualified
// `gs://bucket/exact/object/path` destination — this is CLI behavior,
// not a real requirement of the underlying write. The dedicated CI
// service account intentionally has only IAM-Condition PATH-SCOPED
// object permissions on this bucket (storage.objectAdmin, conditioned
// to `compliance_quarantine/ci-*` — see the readiness doc's §13 and
// the bucket IAM policy itself), deliberately NOT bucket-wide
// storage.objects.list — so the gcloud CLI's internal list call fails
// closed, exactly as the existing least-privilege model intends.
//
// This module replaces every `gcloud storage` invocation in that one
// code path with direct @google-cloud/storage object-API calls
// (file.save/file.download/file.delete), each addressed by its own
// EXACT, already-known object name — never a list, never a wildcard,
// never a prefix enumeration. This is not a workaround: it performs
// the SAME create/overwrite/generation-pinned-read/cleanup sequence
// the original bash implementation did, using an API surface that
// genuinely needs only the object-level permissions already granted,
// because it never needs to discover what exists — it always already
// knows the one exact path it is operating on.
//
// Split, matching this pipeline's other ci/*.js modules (see
// materializeRuntimeManifest.js and signatureRefreshLock.js for the
// same shape):
//   1. Pure validation functions — no I/O, fully deterministic, fully
//      unit-tested by verifyGenerationPinning.test.js.
//   2. runGenerationPinningVerification — the real async lifecycle
//      (create/verify/overwrite/verify/cleanup), dependency-injected
//      via a `fileFactory(generation)` callback so tests can supply an
//      in-memory fake Storage implementation and never touch a real
//      bucket. The CLI wrapper below supplies the REAL factory
//      (`(generation) => storage.bucket(bucket).file(path, generation
//      ? { generation } : {})`) — the exact same
//      storage.bucket(...).file(path, { generation }) generation-
//      pinning idiom materializeRuntimeManifest.js and src/gcsReader.js
//      already use.
//   3. A thin CLI wrapper (require.main === module) — real GCS access,
//      not exercised by any local test, statically reviewed and
//      syntax-checked only (same "requires later staging execution"
//      honesty-language convention as every other ci/*.js CLI half in
//      this repository).
//
// Generation values are treated as OPAQUE STRINGS throughout this
// entire file — never passed through Number()/parseInt()/parseFloat()/
// unary-plus. Real GCS generations are large decimal integers that can
// legitimately approach or exceed Number.MAX_SAFE_INTEGER; the GCS
// JSON API itself represents them as strings for exactly this reason.
// (ci/signatureRefreshLock.js's own older CLI half does coerce its
// generation to Number for lock-fencing bookkeeping — a narrower,
// already-reviewed tradeoff for that file's own purpose, not a pattern
// this file repeats; string-generation handling here matches
// materializeRuntimeManifest.js's already-established convention
// instead.)

const APPROVED_OBJECT_PREFIX = "compliance_quarantine/ci-";
const APPROVED_OBJECT_SUFFIX = "/deployed-verify/generation-test.bin";

// Cloud Build's own well-formed UUID shape for BUILD_ID — the exact
// same case-pattern deploy-candidate.sh already validates BUILD_ID
// against before using it to construct anything. Reusing this exact
// shape here means the object path this module ever constructs is
// built ENTIRELY from characters this pattern allows (lowercase hex
// digits and hyphens) — traversal segments, backslashes, control
// characters, query/fragment syntax, wildcards, and empty segments are
// therefore structurally impossible in the result, not merely
// rejected after the fact by a secondary check (though the allowlist
// check on the final constructed path below still exists too, as
// defense in depth, exactly like materializeRuntimeManifest.js's own
// belt-and-suspenders OBJECT_PATH_ALLOWLIST).
const BUILD_ID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

// Allowlist, not a blacklist — every character NOT in this set is
// rejected. Mirrors materializeRuntimeManifest.js's own
// OBJECT_PATH_ALLOWLIST exactly.
const OBJECT_PATH_ALLOWLIST = /^[A-Za-z0-9._/-]+$/;

// GCS bucket-naming rules (lowercase letters, digits, hyphens,
// underscores, dots; 3-63 characters) — narrower than what GCS
// technically permits in every edge case, but every real bucket this
// pipeline is ever configured against fits this shape, and rejecting
// anything looser is strictly safer.
const BUCKET_NAME_PATTERN = /^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$/;

/**
 * Validates BUILD_ID against Cloud Build's own UUID shape. Pure.
 *
 * @param {string} buildId
 * @returns { { valid: true, buildId: string } | { valid: false, reason: string } }
 */
function validateBuildId(buildId) {
  if (typeof buildId !== "string" || buildId.length === 0) {
    return { valid: false, reason: "missing_build_id" };
  }
  if (!BUILD_ID_PATTERN.test(buildId)) {
    return { valid: false, reason: "build_id_not_well_formed_uuid" };
  }
  return { valid: true, buildId };
}

/**
 * Validates the configured synthetic-test bucket name. Pure. There is
 * deliberately no second "target bucket" parameter to compare against
 * — this module only ever constructs object references against the
 * ONE bucket value the caller supplies, so "the bucket must equal the
 * configured synthetic bucket" is enforced structurally (there is no
 * code path that could address a different bucket), not by comparing
 * two independently-suppliable strings.
 *
 * @param {string} bucket
 * @returns { { valid: true, bucket: string } | { valid: false, reason: string } }
 */
function validateSyntheticBucket(bucket) {
  if (typeof bucket !== "string" || bucket.length === 0) {
    return { valid: false, reason: "missing_bucket" };
  }
  if (bucket.includes("..")) {
    return { valid: false, reason: "bucket_traversal_shape" };
  }
  if (!BUCKET_NAME_PATTERN.test(bucket)) {
    return { valid: false, reason: "bucket_malformed" };
  }
  return { valid: true, bucket };
}

/**
 * Constructs and validates the ONE approved, build-scoped generation-
 * pinning test object path:
 *   compliance_quarantine/ci-<build-id>/deployed-verify/generation-test.bin
 * Pure — no I/O. The caller never supplies a raw path; only a BUILD_ID,
 * which this function itself validates before ever using it to build a
 * string. Defense in depth: the final constructed path is ALSO run
 * through the same traversal/backslash/control-character/query-
 * fragment/wildcard/empty-segment/allowlist checks
 * materializeRuntimeManifest.js's validateRuntimeManifestUri already
 * uses, even though the BUILD_ID_PATTERN restriction above already
 * makes every one of those conditions structurally unreachable.
 *
 * @param {string} buildId
 * @returns { { valid: true, objectPath: string } | { valid: false, reason: string } }
 */
function buildGenerationTestObjectPath(buildId) {
  const buildIdResult = validateBuildId(buildId);
  if (!buildIdResult.valid) {
    return { valid: false, reason: buildIdResult.reason };
  }

  const objectPath = `${APPROVED_OBJECT_PREFIX}${buildId}${APPROVED_OBJECT_SUFFIX}`;

  if (objectPath.includes("..")) {
    return { valid: false, reason: "path_traversal" };
  }
  if (objectPath.includes("\\")) {
    return { valid: false, reason: "backslash_present" };
  }
  // eslint-disable-next-line no-control-regex
  if (/[\x00-\x1f\x7f]/.test(objectPath)) {
    return { valid: false, reason: "control_character_present" };
  }
  if (objectPath.includes("?") || objectPath.includes("#")) {
    return { valid: false, reason: "query_or_fragment_present" };
  }
  if (objectPath.includes("*") || objectPath.includes("[") || objectPath.includes("]")) {
    return { valid: false, reason: "wildcard_present" };
  }
  if (objectPath.includes("//") || objectPath.split("/").some((segment) => segment.length === 0)) {
    return { valid: false, reason: "empty_segment" };
  }
  if (!objectPath.startsWith(APPROVED_OBJECT_PREFIX) || !objectPath.endsWith(APPROVED_OBJECT_SUFFIX)) {
    return { valid: false, reason: "unexpected_prefix_or_suffix" };
  }
  if (!OBJECT_PATH_ALLOWLIST.test(objectPath)) {
    return { valid: false, reason: "disallowed_characters" };
  }

  return { valid: true, objectPath };
}

// A real GCS generation is always a canonical positive decimal integer
// string — no leading zero, no sign, no fractional part. Matches
// materializeRuntimeManifest.js's validateRuntimeManifestGeneration
// shape exactly (generation "0" is GCS's own reserved
// ifGenerationMatch sentinel meaning "must not currently exist", never
// a real object's own generation, so it is rejected here too).
function isCanonicalGenerationString(value) {
  return typeof value === "string" && /^[1-9][0-9]*$/.test(value);
}

/**
 * The real async lifecycle: create the first generation (fail closed
 * if one already exists at this exact path), verify it is readable at
 * its own pinned generation with the expected content, overwrite it
 * (fenced by an explicit ifGenerationMatch precondition on the
 * generation just created — never an unconditioned overwrite), verify
 * the new current generation reads back with the expected content,
 * re-verify the FIRST generation is still independently readable and
 * still returns the ORIGINAL content even though it is no longer
 * current (the actual property this whole test proves: a pinned read
 * of an old generation is never silently satisfied by the bucket's
 * current object), then clean up — deleting ONLY the exact generations
 * this invocation itself created, each by its own precise generation
 * precondition, never a bare/unconditioned delete and never anything
 * list- or prefix-based. Cleanup runs in a `finally` block so it is
 * attempted even when an earlier step throws, and a cleanup failure is
 * reported as a distinct, non-fatal diagnostic that never overwrites
 * or masks the primary result.
 *
 * @param {object} args
 * @param {(generation?: string) => { save: Function, download: Function, delete: Function, getMetadata: Function }} args.fileFactory
 *   Returns a file-handle-like object bound to a specific generation
 *   (when `generation` is supplied) or the current/mutable object
 *   (when omitted) — the real CLI wrapper below supplies
 *   `storage.bucket(bucket).file(objectPath, generation ? { generation } : {})`;
 *   tests supply an in-memory fake with the identical method shape and
 *   deliberately NO list-capable method at all.
 * @param {Buffer} args.v1Buffer First generation's content.
 * @param {Buffer} args.v2Buffer Second (overwrite) generation's content.
 * @param {(op: string, detail: object) => void} [args.log] Bounded,
 *   non-sensitive diagnostic emitter — operation name, generation
 *   identifiers, and pass/fail classification only. Never called with
 *   object contents, credentials, tokens, or signed URLs.
 * @returns {Promise<
 *   | { ok: true, gen1: string, gen2: string }
 *   | { ok: false, error: string }
 * >}
 */
async function runGenerationPinningVerification({ fileFactory, v1Buffer, v2Buffer, log = () => {} }) {
  const createdGenerations = [];

  try {
    const writable = fileFactory();

    await writable.save(v1Buffer, {
      resumable: false,
      preconditionOpts: { ifGenerationMatch: 0 },
      metadata: { contentType: "application/octet-stream" },
    });
    const [meta1] = await writable.getMetadata();
    const gen1 = String(meta1 && meta1.generation);
    if (!isCanonicalGenerationString(gen1)) {
      throw new Error(`ambiguous generation reported after create: ${JSON.stringify(meta1 && meta1.generation)}`);
    }
    createdGenerations.push(gen1);
    log("create", { generation: gen1, result: "pass" });

    const pinnedV1 = fileFactory(gen1);
    const [downloaded1] = await pinnedV1.download();
    if (!Buffer.isBuffer(downloaded1) || !downloaded1.equals(v1Buffer)) {
      throw new Error("pinned read of the first generation did not return the expected content");
    }
    log("verify-pinned-read", { generation: gen1, result: "pass" });

    await writable.save(v2Buffer, {
      resumable: false,
      preconditionOpts: { ifGenerationMatch: gen1 },
      metadata: { contentType: "application/octet-stream" },
    });
    const [meta2] = await writable.getMetadata();
    const gen2 = String(meta2 && meta2.generation);
    if (!isCanonicalGenerationString(gen2)) {
      throw new Error(`ambiguous generation reported after overwrite: ${JSON.stringify(meta2 && meta2.generation)}`);
    }
    if (gen2 === gen1) {
      throw new Error("overwrite did not produce a new generation distinct from the first");
    }
    createdGenerations.push(gen2);
    log("overwrite", { generation: gen2, precondition: gen1, result: "pass" });

    const pinnedV2 = fileFactory(gen2);
    const [downloaded2] = await pinnedV2.download();
    if (!Buffer.isBuffer(downloaded2) || !downloaded2.equals(v2Buffer)) {
      throw new Error("pinned read of the second (current) generation did not return the expected content");
    }
    log("verify-pinned-read", { generation: gen2, result: "pass" });

    const rereadPinnedV1 = fileFactory(gen1);
    const [redownloaded1] = await rereadPinnedV1.download();
    if (!Buffer.isBuffer(redownloaded1) || !redownloaded1.equals(v1Buffer)) {
      throw new Error("pinned re-read of the first generation, after it was superseded, no longer returned the original content");
    }
    log("verify-pinned-read-after-overwrite", { generation: gen1, result: "pass" });

    return { ok: true, gen1, gen2 };
  } catch (err) {
    return { ok: false, error: (err && err.message) || String(err) };
  } finally {
    for (const generation of createdGenerations) {
      try {
        const handle = fileFactory(generation);
        await handle.delete({ preconditionOpts: { ifGenerationMatch: generation } });
        log("cleanup", { generation, result: "pass" });
      } catch (cleanupErr) {
        // Best-effort only — a cleanup failure must never mask or
        // replace the primary result computed above.
        log("cleanup", { generation, result: "fail" });
      }
    }
  }
}

module.exports = {
  APPROVED_OBJECT_PREFIX,
  APPROVED_OBJECT_SUFFIX,
  validateBuildId,
  validateSyntheticBucket,
  buildGenerationTestObjectPath,
  isCanonicalGenerationString,
  runGenerationPinningVerification,
};

// ---------------------------------------------------------------------
// CLI wrapper — real GCS access via @google-cloud/storage (not the
// `gcloud` CLI binary — this is the entire point of this correction:
// the CLI's own client-side list-based path resolution is exactly what
// this module exists to avoid). Not exercised by any local test.
// STATICALLY reviewed and syntax-checked (`node --check`) only, same
// "requires later staging execution" convention as every other ci/*.js
// CLI half in this repository.
//
// Deliberately never logs object contents, credentials, tokens, or
// signed URLs — only operation names, generation identifiers, and
// pass/fail classification, via the same bounded `log` callback the
// core function above already restricts itself to.
// ---------------------------------------------------------------------
if (require.main === module) {
  /* eslint-disable no-console */
  const fs = require("node:fs");
  const { Storage } = require("@google-cloud/storage");

  function requireEnv(name) {
    const value = process.env[name];
    if (!value) {
      console.error(`verify-generation-pinning: ${name} is required`);
      process.exit(2);
    }
    return value;
  }

  async function main() {
    const projectId = requireEnv("PROJECT_ID");
    const rawBucket = requireEnv("SYNTHETIC_TEST_BUCKET");
    const buildId = requireEnv("BUILD_ID");
    const v1Path = requireEnv("V1_PAYLOAD_PATH");
    const v2Path = requireEnv("V2_PAYLOAD_PATH");

    const bucketResult = validateSyntheticBucket(rawBucket);
    if (!bucketResult.valid) {
      console.error(`verify-generation-pinning: BUCKET REJECTED — ${bucketResult.reason}`);
      process.exit(1);
    }

    const pathResult = buildGenerationTestObjectPath(buildId);
    if (!pathResult.valid) {
      console.error(`verify-generation-pinning: BUILD_ID/PATH REJECTED — ${pathResult.reason}`);
      process.exit(1);
    }

    let v1Buffer;
    let v2Buffer;
    try {
      v1Buffer = fs.readFileSync(v1Path);
      v2Buffer = fs.readFileSync(v2Path);
    } catch (err) {
      console.error(`verify-generation-pinning: failed to read local payload file — ${err && err.message}`);
      process.exit(1);
    }
    if (v1Buffer.length === 0 || v2Buffer.length === 0) {
      console.error("verify-generation-pinning: a local payload file is empty");
      process.exit(1);
    }

    const storage = new Storage({ projectId });
    const bucket = storage.bucket(bucketResult.bucket);
    const fileFactory = (generation) => bucket.file(pathResult.objectPath, generation ? { generation } : {});

    const result = await runGenerationPinningVerification({
      fileFactory,
      v1Buffer,
      v2Buffer,
      log: (op, detail) => console.error(`verify-generation-pinning: ${op} ${JSON.stringify(detail)}`),
    });

    if (!result.ok) {
      console.error(`verify-generation-pinning: FAILED — ${result.error}`);
      process.exit(1);
    }

    console.log(pathResult.objectPath);
    console.log(result.gen1);
    console.log(result.gen2);
    process.exit(0);
  }

  main().catch((err) => {
    console.error(`verify-generation-pinning: unexpected error — ${err && err.message}`);
    process.exit(1);
  });
}
