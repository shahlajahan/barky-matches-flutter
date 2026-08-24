"use strict";

// Petsupo Marketplace P1-A compliance foundation — signature-refresh
// pipeline, generation-pinning re-verification helper for
// ci/verify-deployed-candidate.sh (generation-pinning sequencing
// correction, closing a real staging failure — build
// 8b35480c-b19f-4aad-a0dd-9779a42d8b49, step verify-deployed-candidate:
// "generation-pinned read of old (EICAR) generation failed ...
// gcs_download_failed").
//
// Root cause of THIS correction (the prior single-shot design's own
// defect, not the storage.objects.list defect that design already
// fixed): the previous version of this module created both
// generations, verified them LOCALLY, then deleted both — all inside
// one invocation, before ci/verify-deployed-candidate.sh's own
// downstream /v1/scan HTTP calls ever asked the DEPLOYED CANDIDATE
// (a separate service, reading with its own separate runtime service
// account) to fetch and scan those same generations. By the time that
// cross-service verification happened, both generations were already
// deleted — a real regression this build proved empirically, not a
// permission error at all (build 8b35480c's own log shows every
// prepare-phase GCS operation, including cleanup, reporting "pass";
// the FAILURE was a 404-shaped gcs_download_failed on the deployed
// candidate's own later read).
//
// Fixed by splitting this module into two explicit, separately
// invoked operations with an ownership-transfer boundary between them:
//   - `prepare`: create GEN1, verify it locally, overwrite to GEN2,
//     verify GEN2 locally, re-verify GEN1 is still independently
//     readable after being superseded — then, ONLY on success, persist
//     an atomically-written, exclusively-created local RECEIPT file
//     recording exactly what was created (never credentials, tokens,
//     or object content) and returns without deleting anything. This
//     is the ownership-transfer point: from here on, the SHELL
//     orchestration (ci/verify-deployed-candidate.sh) owns responsibility
//     for eventually calling `cleanup`, not this process.
//   - `cleanup`: reads and STRICTLY revalidates the receipt (every
//     field independently re-checked against the same validators
//     `prepare` itself uses — a malformed, foreign, or tampered
//     receipt is rejected before any Storage call is even attempted),
//     deletes GEN1 and GEN2 by their own exact generation
//     preconditions (tolerating "already deleted" as a successful,
//     idempotent outcome — never a list, never a bucket-wide or
//     prefix-based delete), and removes the receipt itself only after
//     both deletions are confirmed complete.
//
// The shell script now runs `prepare`, then its EXISTING (unchanged)
// HTTP verification against the real deployed candidate for BOTH
// generations, and only THEN runs `cleanup` — with an EXIT/INT/TERM
// trap armed for the whole window in between, so an unexpected failure
// or signal after `prepare` still triggers `cleanup` (idempotent and
// safe to call even when there is nothing to clean up), without ever
// masking whatever the PRIMARY failure/exit code was.
//
// Split, matching this pipeline's other ci/*.js modules (see
// materializeRuntimeManifest.js and signatureRefreshLock.js for the
// same shape):
//   1. Pure validation functions — no I/O, fully deterministic, fully
//      unit-tested by verifyGenerationPinning.test.js.
//   2. prepareGenerationPinning / cleanupGenerationPinning — the real
//      async lifecycles, dependency-injected via a `fileFactory
//      (generation)` callback (tests supply an in-memory fake, never a
//      real bucket) and a `receiptStore` callback pair (tests supply
//      an in-memory fake filesystem, never real disk I/O).
//   3. A thin CLI wrapper (require.main === module) — real GCS +
//      filesystem access, not exercised by any local test, statically
//      reviewed and syntax-checked only (same "requires later staging
//      execution" honesty-language convention as every other ci/*.js
//      CLI half in this repository).
//
// Generation values remain OPAQUE STRINGS throughout this entire file
// — never passed through Number()/parseInt()/parseFloat()/unary-plus
// — unchanged from the prior version of this correction; see that
// version's own note on why (GCS generations can exceed
// Number.MAX_SAFE_INTEGER; the GCS JSON API itself represents them as
// strings for exactly this reason).
//
// Do not create a second, competing GCS implementation: this file
// remains the ONLY module in this pipeline that reads/writes the
// generation-pinning test object, exactly as before — `prepare` and
// `cleanup` are two operations on ONE implementation, not two parallel
// ones.

const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");

const APPROVED_OBJECT_PREFIX = "compliance_quarantine/ci-";
const APPROVED_OBJECT_SUFFIX = "/deployed-verify/generation-test.bin";

// Fixed, pipeline-owned receipt directory — never a Cloud Build
// substitution, never caller-supplied — matching
// materializeRuntimeManifest.js's own "always the single fixed
// /workspace location" convention for exactly the same reason: a
// caller-controlled destination would reopen the class of risk this
// whole correction is designed to close.
const RECEIPT_DIR = "/workspace/.generation-pinning-receipts";
const RECEIPT_SCHEMA_VERSION = 1;

// Cloud Build's own well-formed UUID shape for BUILD_ID — the exact
// same case-pattern deploy-candidate.sh already validates BUILD_ID
// against, and the same pattern the prior version of this file already
// used for the object path. Reused here for the receipt filename too,
// so a receipt path can never contain anything outside
// [0-9a-f-] plus the fixed ".json" suffix this module itself appends.
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
 * ONE bucket value the caller supplies.
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

function checkPathSafety(candidatePath, { approvedPrefix, approvedSuffix }) {
  if (candidatePath.includes("..")) return "path_traversal";
  if (candidatePath.includes("\\")) return "backslash_present";
  // eslint-disable-next-line no-control-regex
  if (/[\x00-\x1f\x7f]/.test(candidatePath)) return "control_character_present";
  if (candidatePath.includes("?") || candidatePath.includes("#")) return "query_or_fragment_present";
  if (candidatePath.includes("*") || candidatePath.includes("[") || candidatePath.includes("]")) return "wildcard_present";
  if (candidatePath.includes("//") || candidatePath.split("/").some((segment) => segment.length === 0)) return "empty_segment";
  if (approvedPrefix && !candidatePath.startsWith(approvedPrefix)) return "unexpected_prefix";
  if (approvedSuffix && !candidatePath.endsWith(approvedSuffix)) return "unexpected_suffix";
  if (!OBJECT_PATH_ALLOWLIST.test(candidatePath)) return "disallowed_characters";
  return null;
}

/**
 * Constructs and validates the ONE approved, build-scoped generation-
 * pinning test OBJECT path:
 *   compliance_quarantine/ci-<build-id>/deployed-verify/generation-test.bin
 * Pure — no I/O. The caller never supplies a raw path; only a BUILD_ID,
 * which this function itself validates before ever using it to build a
 * string. Defense in depth: the final constructed path is ALSO run
 * through the same traversal/backslash/control-character/query-
 * fragment/wildcard/empty-segment/allowlist checks
 * materializeRuntimeManifest.js's validateRuntimeManifestUri already
 * uses, even though BUILD_ID_PATTERN already makes every one of those
 * conditions structurally unreachable for any input that passes it.
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
  const reason = checkPathSafety(objectPath, { approvedPrefix: APPROVED_OBJECT_PREFIX, approvedSuffix: APPROVED_OBJECT_SUFFIX });
  if (reason) return { valid: false, reason };
  return { valid: true, objectPath };
}

/**
 * Constructs and validates the ONE approved, build-scoped RECEIPT file
 * path under the fixed RECEIPT_DIR. Pure — no I/O. Same
 * validate-then-construct discipline as buildGenerationTestObjectPath:
 * the caller supplies only a BUILD_ID, this function derives the exact
 * path, and the result is additionally run through the same
 * defense-in-depth character checks.
 *
 * @param {string} buildId
 * @returns { { valid: true, receiptPath: string } | { valid: false, reason: string } }
 */
function buildReceiptPath(buildId) {
  const buildIdResult = validateBuildId(buildId);
  if (!buildIdResult.valid) {
    return { valid: false, reason: buildIdResult.reason };
  }
  const receiptPath = path.join(RECEIPT_DIR, `${buildId}.json`);
  if (!receiptPath.startsWith(`${RECEIPT_DIR}/`)) {
    // Defensive: path.join could in principle normalize its way out of
    // RECEIPT_DIR given a hostile buildId, though BUILD_ID_PATTERN
    // already forbids every character that could cause that.
    return { valid: false, reason: "receipt_path_outside_approved_directory" };
  }
  return { valid: true, receiptPath };
}

// A real GCS generation is always a canonical positive decimal integer
// string — no leading zero, no sign, no fractional part. Generation
// "0" is GCS's own reserved ifGenerationMatch sentinel meaning "must
// not currently exist", never a real object's own generation, so it is
// rejected here too.
function isCanonicalGenerationString(value) {
  return typeof value === "string" && /^[1-9][0-9]*$/.test(value);
}

/**
 * Strictly validates a parsed receipt object against the EXPECTED
 * invocation context (the same project/bucket/buildId the caller was
 * itself given), independently re-deriving the expected object path
 * from the expected buildId rather than ever trusting the receipt's
 * own claimed objectPath at face value. Pure — no I/O. This is what
 * makes a malformed, foreign, or tampered receipt fail BEFORE any
 * Storage call is ever attempted: every field is re-checked against
 * the same validators `prepare` itself used to produce it.
 *
 * @param {unknown} receipt Parsed JSON content of the receipt file.
 * @param {object} expected
 * @param {string} expected.project
 * @param {string} expected.bucket
 * @param {string} expected.buildId
 * @returns { { valid: true, receipt: object } | { valid: false, reason: string } }
 */
function validateReceipt(receipt, expected) {
  if (receipt === null || typeof receipt !== "object" || Array.isArray(receipt)) {
    return { valid: false, reason: "receipt_not_an_object" };
  }
  if (receipt.schemaVersion !== RECEIPT_SCHEMA_VERSION) {
    return { valid: false, reason: "receipt_schema_version_mismatch" };
  }

  const expectedBucketResult = validateSyntheticBucket(expected.bucket);
  if (!expectedBucketResult.valid) {
    return { valid: false, reason: "expected_bucket_invalid" };
  }
  const expectedPathResult = buildGenerationTestObjectPath(expected.buildId);
  if (!expectedPathResult.valid) {
    return { valid: false, reason: "expected_build_id_invalid" };
  }

  if (typeof receipt.project !== "string" || receipt.project.length === 0 || receipt.project !== expected.project) {
    return { valid: false, reason: "receipt_project_mismatch" };
  }
  if (typeof receipt.bucket !== "string" || receipt.bucket !== expectedBucketResult.bucket) {
    return { valid: false, reason: "receipt_bucket_mismatch" };
  }
  if (typeof receipt.buildId !== "string" || receipt.buildId !== expected.buildId) {
    return { valid: false, reason: "receipt_build_id_mismatch" };
  }
  // Never trust the receipt's own objectPath — always compare against
  // the independently re-derived expected path.
  if (typeof receipt.objectPath !== "string" || receipt.objectPath !== expectedPathResult.objectPath) {
    return { valid: false, reason: "receipt_object_path_mismatch" };
  }
  if (!isCanonicalGenerationString(receipt.gen1)) {
    return { valid: false, reason: "receipt_gen1_not_canonical" };
  }
  if (!isCanonicalGenerationString(receipt.gen2)) {
    return { valid: false, reason: "receipt_gen2_not_canonical" };
  }
  if (receipt.gen1 === receipt.gen2) {
    return { valid: false, reason: "receipt_gen1_equals_gen2" };
  }

  return {
    valid: true,
    receipt: {
      schemaVersion: receipt.schemaVersion,
      project: receipt.project,
      bucket: receipt.bucket,
      buildId: receipt.buildId,
      objectPath: receipt.objectPath,
      gen1: receipt.gen1,
      gen2: receipt.gen2,
    },
  };
}

/**
 * Publishes the receipt via a TRUE atomic no-clobber primitive — not
 * a check-then-write (lstat/access followed by a separate write or
 * rename) TOCTOU pattern, which a concurrent or adversarial creator
 * could win in the window between the check and the write. Instead:
 *
 *   1. Write the full, already-serialized content to a same-directory
 *      temp file opened with O_CREAT|O_EXCL|O_WRONLY (mode 0600) —
 *      this alone is already symlink- and collision-safe for the TEMP
 *      name (a fresh random suffix per call), exactly like
 *      materializeRuntimeManifest.js's writeManifestAtomic uses for
 *      ITS temp file.
 *   2. fsync() the temp file's own data before it is ever linked to
 *      the real name, so the content is durable before publication.
 *   3. Publish via link(2) (fs.linkSync), NOT rename(2). This is the
 *      actual fix: POSIX guarantees link() FAILS with EEXIST if
 *      `receiptPath` already names ANYTHING — a regular file, a
 *      symlink (the symlink's own directory-entry name blocks the
 *      link outright; it is never followed, dereferenced, or
 *      replaced), or a directory. rename(2), by contrast, is
 *      documented to ATOMICALLY REPLACE an existing destination —
 *      which is exactly the TOCTOU-adjacent risk this function
 *      previously carried (a pre-check could observe "nothing there"
 *      an instant before a rename silently clobbered whatever a
 *      concurrent writer had just created). There is no separate
 *      check-then-act window here: the existence check and the
 *      publish are the SAME single syscall.
 *   4. On success, unlink the temp name — receiptPath is now an
 *      independent second hard link to the identical, already-fsynced
 *      inode, so removing the temp name has no effect on it.
 *   5. Best-effort fsync of the ENCLOSING DIRECTORY's own file
 *      descriptor, so the new directory entry is more likely to
 *      survive a crash immediately after publish ("durably finalized
 *      where practical" — deliberately never fatal: some platforms/
 *      filesystems do not support fsyncing a directory fd at all, and
 *      by this point the publish itself already succeeded atomically
 *      and correctly regardless of this step's outcome).
 *
 * The temp file is cleaned up on every failure path: open failure
 * (nothing to clean), write/fsync failure, and link failure
 * (including the EEXIST/lost-the-race case) all remove the temp name
 * before returning/throwing. receiptPath itself is NEVER touched
 * unless link() itself actually created it.
 *
 * Confirmed portable for both real runtime targets this function
 * needs: Cloud Build's Linux container filesystem (/workspace, an
 * ext4/overlay-backed volume) and local macOS test filesystems
 * (APFS) — both are POSIX-compliant and support hard links with
 * standard EEXIST-on-existing-destination semantics; this function
 * never crosses a filesystem boundary (the temp file and the final
 * name are always siblings in the same directory), so link(2)'s
 * cross-device EXDEV failure mode can never occur here.
 *
 * @param {string} receiptPath
 * @param {object} receiptData
 */
function writeReceiptExclusive(receiptPath, receiptData) {
  // Derived from receiptPath itself, not the RECEIPT_DIR constant
  // directly — real production callers always pass a receiptPath
  // already computed by buildReceiptPath (always under RECEIPT_DIR),
  // but deriving the directory this way also makes this function
  // correctly testable against an isolated temp path, and avoids ever
  // trying to create RECEIPT_DIR's fixed /workspace location in an
  // environment where receiptPath legitimately points somewhere else.
  const dir = path.dirname(receiptPath);
  fs.mkdirSync(dir, { recursive: true, mode: 0o700 });

  const tmpPath = path.join(dir, `.receipt.tmp-${crypto.randomBytes(16).toString("hex")}`);
  const buf = Buffer.from(JSON.stringify(receiptData));

  let fd;
  try {
    fd = fs.openSync(tmpPath, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL, 0o600);
  } catch (err) {
    throw new Error(`failed to create temporary receipt file (refusing to follow any pre-existing path/symlink): ${err && err.message}`);
  }

  try {
    fs.writeSync(fd, buf);
    fs.fsyncSync(fd);
  } catch (err) {
    try {
      fs.closeSync(fd);
    } catch (closeErr) {
      // ignore — the temp file is being removed regardless
    }
    try {
      fs.unlinkSync(tmpPath);
    } catch (unlinkErr) {
      // ignore — best-effort cleanup; the original write/fsync error is what matters
    }
    throw new Error(`failed to write temporary receipt file: ${err && err.message}`);
  }
  fs.closeSync(fd);

  // The actual no-clobber publish. Never wrapped in, or preceded by, a
  // separate existence check — this single call IS the check.
  try {
    fs.linkSync(tmpPath, receiptPath);
  } catch (err) {
    try {
      fs.unlinkSync(tmpPath);
    } catch (unlinkErr) {
      // ignore — best-effort cleanup; the original link error is what matters
    }
    if (err && err.code === "EEXIST") {
      throw new Error("refusing to publish receipt: a file, symlink, or directory already exists at this path (pre-existing/untrusted, or lost a concurrent publish race) — left completely untouched");
    }
    throw new Error(`failed to publish receipt via exclusive link: ${err && err.message}`);
  }

  // Best-effort durability only (never correctness/atomicity — link()
  // above already guarantees that unconditionally, and by this point
  // the receipt is ALREADY correctly, atomically published). Silently
  // tolerates any failure here on purpose: some filesystems/platforms
  // do not support fsyncing a directory file descriptor at all, and
  // failing (or worse, unwinding an already-successful publish) over
  // a pure durability nicety would be strictly worse than accepting
  // best-effort durability.
  try {
    const dirFd = fs.openSync(dir, fs.constants.O_RDONLY);
    try {
      fs.fsyncSync(dirFd);
    } finally {
      fs.closeSync(dirFd);
    }
  } catch (dirSyncErr) {
    // best-effort only — see comment above
  }

  fs.unlinkSync(tmpPath);
}

/**
 * `prepare`: create GEN1 (ifGenerationMatch: 0), verify it locally,
 * overwrite to GEN2 (fenced by ifGenerationMatch: GEN1), verify GEN2
 * locally, re-verify GEN1 is still independently readable with its
 * original content after being superseded — then persist the receipt.
 * Ownership of eventual cleanup transfers to the CALLER only once this
 * function returns `{ ok: true }` (i.e. only once the receipt has been
 * durably written) — this function deletes nothing on success.
 *
 * On any failure BEFORE the receipt is successfully written, this
 * function cleans up whatever generations it itself already created
 * (best-effort — a cleanup failure here is reported as a distinct,
 * non-fatal diagnostic that never replaces the primary error), exactly
 * matching the "helper itself must clean only generations it created"
 * requirement for the pre-ownership-transfer window.
 *
 * @param {object} args
 * @param {(generation?: string) => object} args.fileFactory Same shape
 *   as the prior version of this module: returns a file-handle-like
 *   object (`save`/`download`/`delete`/`getMetadata`) bound to a
 *   specific generation, or the current/mutable object when omitted.
 * @param {Buffer} args.v1Buffer
 * @param {Buffer} args.v2Buffer
 * @param {string} args.receiptPath Already-validated, via buildReceiptPath.
 * @param {{ project: string, bucket: string, buildId: string, objectPath: string }} args.receiptContext
 * @param {(op: string, detail: object) => void} [args.log]
 * @param {(receiptPath: string, receiptData: object) => void} [args.writeReceipt]
 *   Injectable for tests — defaults to writeReceiptExclusive.
 * @returns {Promise<{ ok: true, gen1: string, gen2: string } | { ok: false, error: string }>}
 */
async function prepareGenerationPinning({
  fileFactory,
  v1Buffer,
  v2Buffer,
  receiptPath,
  receiptContext,
  log = () => {},
  writeReceipt = writeReceiptExclusive,
}) {
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

    // Ownership-transfer point: only reached once both generations are
    // proven to exist and read back correctly. Nothing above this line
    // deletes anything; nothing below this line creates anything.
    writeReceipt(receiptPath, {
      schemaVersion: RECEIPT_SCHEMA_VERSION,
      project: receiptContext.project,
      bucket: receiptContext.bucket,
      buildId: receiptContext.buildId,
      objectPath: receiptContext.objectPath,
      gen1,
      gen2,
    });
    log("receipt-written", { result: "pass" });

    return { ok: true, gen1, gen2 };
  } catch (err) {
    // Pre-ownership-transfer failure: this process still owns whatever
    // it created, so it cleans up here — never leaving orphaned
    // generations behind just because the receipt was never written.
    for (const generation of createdGenerations) {
      try {
        const handle = fileFactory(generation);
        await handle.delete({ preconditionOpts: { ifGenerationMatch: generation } });
        log("prepare-failure-cleanup", { generation, result: "pass" });
      } catch (cleanupErr) {
        log("prepare-failure-cleanup", { generation, result: "fail" });
      }
    }
    return { ok: false, error: (err && err.message) || String(err) };
  }
}

// A 404-shaped error from the fake/real Storage adapter — "this exact
// generation is already gone" — is the ONE class of delete failure
// this module treats as an already-achieved goal state (idempotent
// retry-safe), never as a real cleanup failure. Any other error
// (permission denied, precondition mismatch for a reason other than
// "gone", network failure) remains a genuine failure.
function isNotFoundError(err) {
  return Boolean(err && (err.code === 404 || err.code === "404" || /not found|no such object/i.test(String(err && err.message))));
}

/**
 * `cleanup`: reads and strictly revalidates the receipt against the
 * caller's own expected project/bucket/buildId (never trusting the
 * receipt file's own claims at face value), deletes GEN1 and GEN2 by
 * their own exact generation preconditions — tolerating "already
 * deleted" as success for safe idempotent retries — and removes the
 * receipt only once both deletions are confirmed complete. Never
 * lists, never deletes a prefix, never deletes anything without an
 * exact generation precondition.
 *
 * @param {object} args
 * @param {(generation?: string) => object} args.fileFactory
 * @param {string} args.receiptPath
 * @param {{ project: string, bucket: string, buildId: string }} args.expected
 * @param {(op: string, detail: object) => void} [args.log]
 * @param {(receiptPath: string) => object | null} [args.readReceipt]
 *   Injectable for tests. Returns the parsed receipt, or null if no
 *   receipt file exists at this path (a safe, idempotent no-op case —
 *   NOT an error; cleanup may legitimately be called when there is
 *   nothing to clean up, e.g. a retry after a previous successful run,
 *   or a trap firing before `prepare` ever completed).
 * @param {(receiptPath: string) => void} [args.removeReceipt]
 * @returns {Promise<{ ok: true, cleaned: boolean } | { ok: false, error: string }>}
 */
async function cleanupGenerationPinning({
  fileFactory,
  receiptPath,
  expected,
  log = () => {},
  readReceipt = defaultReadReceipt,
  removeReceipt = defaultRemoveReceipt,
}) {
  let parsed;
  try {
    parsed = readReceipt(receiptPath);
  } catch (err) {
    return { ok: false, error: `failed to read receipt: ${(err && err.message) || String(err)}` };
  }

  if (parsed === null) {
    log("cleanup", { result: "noop", reason: "no_receipt" });
    return { ok: true, cleaned: false };
  }

  const validation = validateReceipt(parsed, expected);
  if (!validation.valid) {
    return { ok: false, error: `receipt rejected — ${validation.reason}` };
  }
  const { objectPath, gen1, gen2 } = validation.receipt;

  const failures = [];
  for (const generation of [gen1, gen2]) {
    try {
      const handle = fileFactory(generation);
      await handle.delete({ preconditionOpts: { ifGenerationMatch: generation } });
      log("delete", { objectPath, generation, result: "pass" });
    } catch (err) {
      if (isNotFoundError(err)) {
        log("delete", { objectPath, generation, result: "pass", note: "already_absent" });
      } else {
        log("delete", { objectPath, generation, result: "fail" });
        failures.push(generation);
      }
    }
  }

  if (failures.length > 0) {
    return { ok: false, error: `cleanup incomplete — failed to delete generation(s): ${failures.join(", ")}` };
  }

  try {
    removeReceipt(receiptPath);
    log("receipt-removed", { result: "pass" });
  } catch (err) {
    return { ok: false, error: `both generations deleted, but failed to remove the receipt file: ${(err && err.message) || String(err)}` };
  }

  return { ok: true, cleaned: true };
}

function defaultReadReceipt(receiptPath) {
  let raw;
  try {
    raw = fs.readFileSync(receiptPath, "utf8");
  } catch (err) {
    if (err && err.code === "ENOENT") return null;
    throw err;
  }
  return JSON.parse(raw);
}

function defaultRemoveReceipt(receiptPath) {
  fs.unlinkSync(receiptPath);
}

module.exports = {
  APPROVED_OBJECT_PREFIX,
  APPROVED_OBJECT_SUFFIX,
  RECEIPT_DIR,
  RECEIPT_SCHEMA_VERSION,
  validateBuildId,
  validateSyntheticBucket,
  buildGenerationTestObjectPath,
  buildReceiptPath,
  isCanonicalGenerationString,
  validateReceipt,
  writeReceiptExclusive,
  prepareGenerationPinning,
  cleanupGenerationPinning,
};

// ---------------------------------------------------------------------
// CLI wrapper — real GCS + filesystem access via @google-cloud/storage
// and node:fs (never the `gcloud` CLI binary). Not exercised by any
// local test. STATICALLY reviewed and syntax-checked (`node --check`)
// only, same "requires later staging execution" convention as every
// other ci/*.js CLI half in this repository.
//
// Two subcommands: `prepare` and `cleanup`. Deliberately never logs
// object contents, credentials, tokens, or signed URLs — only
// operation names, generation identifiers, and pass/fail
// classification, via the same bounded `log` callback the core
// functions above already restrict themselves to.
// ---------------------------------------------------------------------
if (require.main === module) {
  /* eslint-disable no-console */
  const fsSync = require("node:fs");
  const { Storage } = require("@google-cloud/storage");

  function requireEnv(name) {
    const value = process.env[name];
    if (!value) {
      console.error(`verify-generation-pinning: ${name} is required`);
      process.exit(2);
    }
    return value;
  }

  async function runPrepare() {
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
    const receiptPathResult = buildReceiptPath(buildId);
    if (!receiptPathResult.valid) {
      console.error(`verify-generation-pinning: RECEIPT PATH REJECTED — ${receiptPathResult.reason}`);
      process.exit(1);
    }

    let v1Buffer;
    let v2Buffer;
    try {
      v1Buffer = fsSync.readFileSync(v1Path);
      v2Buffer = fsSync.readFileSync(v2Path);
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

    const result = await prepareGenerationPinning({
      fileFactory,
      v1Buffer,
      v2Buffer,
      receiptPath: receiptPathResult.receiptPath,
      receiptContext: { project: projectId, bucket: bucketResult.bucket, buildId, objectPath: pathResult.objectPath },
      log: (op, detail) => console.error(`verify-generation-pinning: ${op} ${JSON.stringify(detail)}`),
    });

    if (!result.ok) {
      console.error(`verify-generation-pinning: PREPARE FAILED — ${result.error}`);
      process.exit(1);
    }

    console.log(pathResult.objectPath);
    console.log(result.gen1);
    console.log(result.gen2);
    process.exit(0);
  }

  async function runCleanup() {
    const projectId = requireEnv("PROJECT_ID");
    const rawBucket = requireEnv("SYNTHETIC_TEST_BUCKET");
    const buildId = requireEnv("BUILD_ID");

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
    const receiptPathResult = buildReceiptPath(buildId);
    if (!receiptPathResult.valid) {
      console.error(`verify-generation-pinning: RECEIPT PATH REJECTED — ${receiptPathResult.reason}`);
      process.exit(1);
    }

    // objectPath is deterministically re-derived from buildId here —
    // exactly like `prepare` — never read from the receipt as the
    // source of truth for what to operate on. The receipt's own
    // objectPath field is used ONLY inside cleanupGenerationPinning's
    // validateReceipt call, to confirm it AGREES with this
    // independently-derived value, not to supply it.
    const storage = new Storage({ projectId });
    const bucket = storage.bucket(bucketResult.bucket);
    const fileFactory = (generation) => bucket.file(pathResult.objectPath, generation ? { generation } : {});

    const result = await cleanupGenerationPinning({
      fileFactory,
      receiptPath: receiptPathResult.receiptPath,
      expected: { project: projectId, bucket: bucketResult.bucket, buildId },
      log: (op, detail) => console.error(`verify-generation-pinning: ${op} ${JSON.stringify(detail)}`),
    });

    if (!result.ok) {
      console.error(`verify-generation-pinning: CLEANUP FAILED — ${result.error}`);
      process.exit(1);
    }

    console.log(JSON.stringify({ cleaned: result.cleaned }));
    process.exit(0);
  }

  async function main() {
    const subcommand = process.argv[2];
    if (subcommand === "prepare") {
      await runPrepare();
      return;
    }
    if (subcommand === "cleanup") {
      await runCleanup();
      return;
    }
    console.error(`verify-generation-pinning: unknown subcommand ${JSON.stringify(subcommand)} — expected "prepare" or "cleanup"`);
    process.exit(2);
  }

  main().catch((err) => {
    console.error(`verify-generation-pinning: unexpected error — ${err && err.message}`);
    process.exit(1);
  });
}
