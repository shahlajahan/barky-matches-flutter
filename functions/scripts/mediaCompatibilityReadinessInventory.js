"use strict";

// Step 21a media-compatibility readiness inventory
// (docs/plans/marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §10.1 "Media-compatibility readiness inventory" / "Operational store,
// checkpoint, and output-format completion contract", Revision 24 §0.22,
// Revision 25 §0.23). Read-only, collectionGroup("products") traversal
// classifying only the stored `media` field. This module is never executed
// against Firebase by importing it — the CLI only runs when this file is
// the process entry point (`require.main === module`, at the bottom).

const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const crypto = require("node:crypto");

// ---------------------------------------------------------------------------
// Constants (frozen by the plan; never operator-configurable)
// ---------------------------------------------------------------------------

const SCHEMA_VERSION = 1;
const PAGE_SIZE = 500;
const MAX_READ_ATTEMPTS = 3;
const RUN_ID_PATTERN = /^[a-z0-9][a-z0-9-]{0,63}$/;
const RESERVED_BASENAMES = new Set([
  "con",
  "prn",
  "aux",
  "nul",
  "com1",
  "com2",
  "com3",
  "com4",
  "com5",
  "com6",
  "com7",
  "com8",
  "com9",
  "lpt1",
  "lpt2",
  "lpt3",
  "lpt4",
  "lpt5",
  "lpt6",
  "lpt7",
  "lpt8",
  "lpt9",
]);

const CATEGORY_MISSING = "media_missing";
const CATEGORY_NULL = "media_null";
const CATEGORY_WRONG_TYPE = "media_wrong_type";
const CATEGORY_CONFORMING = "media_conforming";
const CATEGORY_OVERSIZED = "media_oversized";

const CATEGORY_KEYS = [
  CATEGORY_MISSING,
  CATEGORY_NULL,
  CATEGORY_WRONG_TYPE,
  CATEGORY_CONFORMING,
  CATEGORY_OVERSIZED,
];

const VIOLATION_CATEGORIES = [
  CATEGORY_MISSING,
  CATEGORY_NULL,
  CATEGORY_WRONG_TYPE,
  CATEGORY_OVERSIZED,
];

const CHECKPOINT_FIELDS = [
  "schemaVersion",
  "runId",
  "toolVersion",
  "projectBinding",
  "projectClassification",
  "status",
  "lastCommittedPageIndex",
  "lastCommittedPath",
  "startedAt",
  "lastActivityAt",
  "completedAt",
  "readFailureCount",
];

const PAGE_JOURNAL_FIELDS = [
  "schemaVersion",
  "runId",
  "pageIndex",
  "pageStartExclusivePath",
  "pageEndInclusivePath",
  "examinedCount",
  "categoryCounts",
  "violations",
];

const VIOLATION_ENTRY_FIELDS = ["path", "category", "observedLength"];

const LOCK_FIELDS = [
  "schemaVersion",
  "runId",
  "ownershipToken",
  "pid",
  "hostname",
  "acquiredAt",
];

const RUN_STATUS = { IN_PROGRESS: "in_progress", COMPLETED: "completed", FAILED: "failed" };
const PROJECT_CLASSIFICATIONS = ["emulator", "demo", "staging", "production", "unknown"];

const NO_MUTATION_SENTENCE =
  "This report is read-only evidence; no product, Firestore, or Storage data was created, modified, or deleted by this scan.";

// ---------------------------------------------------------------------------
// Classification (§10.1, Revision 12/24 — five mutually exclusive categories)
// ---------------------------------------------------------------------------

/**
 * Classifies a product document's stored `media` field value into exactly
 * one of the five frozen categories. Never validates per-entry structure,
 * never inspects the legacy `images` field, never truncates or mutates.
 */
function classifyMedia(mediaValue) {
  if (mediaValue === undefined) return CATEGORY_MISSING;
  if (mediaValue === null) return CATEGORY_NULL;
  if (!Array.isArray(mediaValue)) return CATEGORY_WRONG_TYPE;
  if (mediaValue.length > 20) return CATEGORY_OVERSIZED;
  return CATEGORY_CONFORMING;
}

function isViolationCategory(category) {
  return VIOLATION_CATEGORIES.includes(category);
}

/**
 * Classifies one candidate document into a `{path, category, observedLength}`
 * shaped violation entry, or `null` when the document is conforming.
 * `docPath` must already be the full, deterministic document path.
 */
function classifyDocument(docPath, mediaValue) {
  const category = classifyMedia(mediaValue);
  if (category === CATEGORY_CONFORMING) return { category, violation: null };
  const violation = { path: docPath, category };
  if (category === CATEGORY_OVERSIZED) {
    violation.observedLength = mediaValue.length;
  }
  return { category, violation };
}

// ---------------------------------------------------------------------------
// CLI argument parsing (guard 1; Revision 25 CLI contract)
// ---------------------------------------------------------------------------

const KNOWN_FLAGS = new Set([
  "project",
  "output-dir",
  "resume-run-id",
  "confirm-production",
  "max-pages",
  "confirm-unbounded-scan",
]);

/**
 * Parses argv-style tokens into a flat args object. Rejects unknown,
 * duplicate, or malformed flags before any other guard runs.
 */
function parseArgs(argv) {
  const args = {};
  for (const token of argv) {
    if (typeof token !== "string" || !token.startsWith("--")) {
      throw new InventoryError(`Unrecognized argument: ${String(token)}`);
    }
    const body = token.slice(2);
    const eq = body.indexOf("=");
    const key = eq === -1 ? body : body.slice(0, eq);
    const value = eq === -1 ? true : body.slice(eq + 1);
    if (!KNOWN_FLAGS.has(key)) {
      throw new InventoryError(`Unknown argument: --${key}`);
    }
    if (Object.prototype.hasOwnProperty.call(args, key)) {
      throw new InventoryError(`Duplicate argument: --${key}`);
    }
    args[key] = value;
  }
  if (args["confirm-unbounded-scan"] !== undefined && args["max-pages"] !== undefined) {
    throw new InventoryError(
      "Contradictory arguments: --max-pages and --confirm-unbounded-scan are mutually exclusive"
    );
  }
  return args;
}

class InventoryError extends Error {
  constructor(message, code) {
    super(message);
    this.name = "InventoryError";
    this.code = code || "INVENTORY_ERROR";
  }
}

// ---------------------------------------------------------------------------
// Project / environment guards (guards 1-4)
// ---------------------------------------------------------------------------

/** Mechanical, not name-based, emulator detection (guard 2's own basis). */
function isEmulatorEnvironment(env) {
  return Boolean(env && typeof env.FIRESTORE_EMULATOR_HOST === "string" && env.FIRESTORE_EMULATOR_HOST.length > 0);
}

/**
 * Classifies a project id into a broad, non-authoritative reporting label
 * only. Never used for any safety/authorization decision — see
 * `assertProjectGuard`, which relies solely on mechanical emulator
 * detection and `--confirm-production`, never on this classification.
 */
function classifyProject(projectId, env) {
  if (isEmulatorEnvironment(env)) return "emulator";
  if (typeof projectId !== "string" || projectId.length === 0) return "unknown";
  if (/(^|[-_])demo([-_]|$)/i.test(projectId)) return "demo";
  if (/(^|[-_])(staging|stg)([-_]|$)/i.test(projectId)) return "staging";
  if (/prod/i.test(projectId)) return "production";
  return "unknown";
}

/**
 * Enforces guards 1-2: `--project` is always mandatory; every non-emulator
 * invocation (regardless of naming convention) requires
 * `--confirm-production`. Throws `InventoryError` on any violation, before
 * any Firestore access or output-path validation.
 */
function assertProjectGuard({ args, env }) {
  if (typeof args.project !== "string" || args.project.length === 0) {
    throw new InventoryError("--project is required and must be a non-empty string", "MISSING_PROJECT");
  }
  const emulator = isEmulatorEnvironment(env);
  if (!emulator && args["confirm-production"] !== true) {
    throw new InventoryError(
      "--confirm-production is required for every non-emulator invocation",
      "MISSING_CONFIRM_PRODUCTION"
    );
  }
  return {
    project: args.project,
    isEmulator: emulator,
    classification: classifyProject(args.project, env),
  };
}

/** Guard 5: an explicit maximum-page bound, or an explicit unbounded-scan confirmation. */
function assertScanBoundGuard(args) {
  const hasMaxPages = args["max-pages"] !== undefined;
  const hasUnboundedConfirm = args["confirm-unbounded-scan"] === true;
  if (!hasMaxPages && !hasUnboundedConfirm) {
    throw new InventoryError(
      "Either --max-pages=<n> or --confirm-unbounded-scan is required",
      "MISSING_SCAN_BOUND"
    );
  }
  if (hasMaxPages) {
    const n = Number(args["max-pages"]);
    if (!Number.isInteger(n) || n <= 0) {
      throw new InventoryError("--max-pages must be a positive integer", "INVALID_MAX_PAGES");
    }
    return { maxPages: n };
  }
  return { maxPages: null };
}

/** Guard 4: a pre-run confirmation line, printed before any read begins. */
function formatPreRunConfirmation({ classification, runId }) {
  return `[media-compatibility-inventory] runId=${runId} projectClassification=${classification} operation=read-only-inventory`;
}

// ---------------------------------------------------------------------------
// runId grammar (Revision 25 "runId grammar, exact")
// ---------------------------------------------------------------------------

function validateRunId(runId) {
  if (typeof runId !== "string" || !RUN_ID_PATTERN.test(runId)) {
    throw new InventoryError(`runId fails the required grammar: ${JSON.stringify(runId)}`, "INVALID_RUN_ID");
  }
  if (RESERVED_BASENAMES.has(runId.toLowerCase())) {
    throw new InventoryError(`runId is a reserved basename: ${runId}`, "RESERVED_RUN_ID");
  }
  return runId;
}

function generateRunId(randomBytesImpl) {
  const bytes = (randomBytesImpl || crypto.randomBytes)(9);
  const runId = "run-" + bytes.toString("hex");
  return validateRunId(runId);
}

// ---------------------------------------------------------------------------
// Platform scope (Revision 25 "Supported platform scope, exact")
// ---------------------------------------------------------------------------

function assertSupportedPlatform(platform) {
  if (platform !== "darwin" && platform !== "linux") {
    throw new InventoryError(`Unsupported platform: ${platform}`, "UNSUPPORTED_PLATFORM");
  }
}

// ---------------------------------------------------------------------------
// Output-path safety (Revision 25 "Output-path safety, exact")
// ---------------------------------------------------------------------------

const PROTECTED_RELATIVE_PATHS = ["ai_exports/vet_context", "shipping_label"];
const SOURCE_LIKE_DIR_NAMES = ["lib", "functions"];

function isPathOrAncestor(candidate, ancestor) {
  const rel = path.relative(ancestor, candidate);
  return rel === "" || (!rel.startsWith("..") && !path.isAbsolute(rel));
}

/**
 * Resolves `--output-dir` to its canonical, symlink-resolved absolute form
 * and refuses it (or any ancestor-chain symlink) if it lands inside a
 * protected path, the repo root, a recognized source/config directory, the
 * filesystem root, or the resolved home directory. `fsImpl` must expose
 * `existsSync`, `lstatSync`, `realpathSync`, `mkdirSync`.
 */
function resolveAndValidateOutputDir({ outputDir, repoRoot, homeDir, fsImpl }) {
  if (typeof outputDir !== "string" || outputDir.length === 0) {
    throw new InventoryError("--output-dir is required", "MISSING_OUTPUT_DIR");
  }
  const absolute = path.resolve(outputDir);
  if (!fsImpl.existsSync(absolute)) {
    fsImpl.mkdirSync(absolute, { recursive: true });
  }
  const canonical = fsImpl.realpathSync(absolute);
  const canonicalRepoRoot = fsImpl.realpathSync(repoRoot);
  const canonicalHome = fsImpl.realpathSync(homeDir);

  if (isPathOrAncestor(canonical, canonicalRepoRoot)) {
    for (const relProtected of PROTECTED_RELATIVE_PATHS) {
      const protectedAbsolute = path.join(canonicalRepoRoot, relProtected);
      if (isPathOrAncestor(canonical, protectedAbsolute)) {
        throw new InventoryError(`--output-dir resolves inside a protected path: ${relProtected}`, "PROTECTED_OUTPUT_DIR");
      }
    }
    if (canonical === canonicalRepoRoot) {
      throw new InventoryError("--output-dir must not be the repository root", "UNSAFE_OUTPUT_DIR");
    }
    for (const sourceDir of SOURCE_LIKE_DIR_NAMES) {
      const sourceAbsolute = path.join(canonicalRepoRoot, sourceDir);
      if (isPathOrAncestor(canonical, sourceAbsolute)) {
        throw new InventoryError(`--output-dir resolves inside a recognized source/config directory: ${sourceDir}`, "UNSAFE_OUTPUT_DIR");
      }
    }
  }
  if (canonical === path.parse(canonical).root) {
    throw new InventoryError("--output-dir must not be the filesystem root", "UNSAFE_OUTPUT_DIR");
  }
  if (isPathOrAncestor(canonical, canonicalHome) && canonical === canonicalHome) {
    throw new InventoryError("--output-dir must not be the resolved home directory", "UNSAFE_OUTPUT_DIR");
  }
  // `canonical` is already the output of `realpathSync`, which by definition
  // contains no symlink component — walking its own ancestor chain here
  // would be tautological (and would incorrectly flag benign, immutable
  // OS-level symlinks like macOS's `/var` -> `/private/var` that sit above
  // any operator-chosen path). Revalidation (rule 3, below) instead checks
  // this same canonical chain, from this trusted root down to each artifact,
  // immediately before every later artifact operation — detecting anything
  // swapped to a symlink *after* this initial resolution.
  return canonical;
}

/**
 * Revalidated immediately before every artifact operation (rule 3,
 * per-artifact path safety): walks from `stopAt` (the already-canonicalized,
 * trusted `--output-dir`) down to `canonicalPath`, confirming no component
 * in between has since been replaced by a symlink. Never walks above
 * `stopAt` — components above the operator's own approved output directory
 * (including OS-level symlinks) are outside this contract's concern.
 */
function assertAncestorChainNotSymlinked({ canonicalPath, stopAt, fsImpl }) {
  let current = canonicalPath;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    if (fsImpl.existsSync(current)) {
      const stat = fsImpl.lstatSync(current);
      if (stat.isSymbolicLink()) {
        throw new InventoryError(`Ancestor path component is a symlink: ${current}`, "SYMLINK_ANCESTOR");
      }
    }
    if (current === stopAt || current === path.dirname(current)) break;
    current = path.dirname(current);
  }
}

/** Refuses a rename destination that is anything other than absent or a plain regular file. */
function assertSafeRenameDestination(destinationPath, fsImpl) {
  if (!fsImpl.existsSync(destinationPath)) return;
  const stat = fsImpl.lstatSync(destinationPath);
  if (!stat.isFile() || stat.isSymbolicLink()) {
    throw new InventoryError(`Rename destination is not a plain regular file: ${destinationPath}`, "UNSAFE_RENAME_DESTINATION");
  }
}

function assertPageJournalDirSafe(pagesDir, fsImpl) {
  if (fsImpl.existsSync(pagesDir)) {
    const stat = fsImpl.lstatSync(pagesDir);
    if (stat.isSymbolicLink()) {
      throw new InventoryError(`Page-journal directory is a symlink: ${pagesDir}`, "SYMLINK_PAGES_DIR");
    }
    if (!stat.isDirectory()) {
      throw new InventoryError(`Page-journal directory path is not a directory: ${pagesDir}`, "UNSAFE_PAGES_DIR");
    }
  } else {
    fsImpl.mkdirSync(pagesDir, { recursive: true });
    const stat = fsImpl.lstatSync(pagesDir);
    if (stat.isSymbolicLink() || !stat.isDirectory()) {
      throw new InventoryError(`Page-journal directory could not be safely created: ${pagesDir}`, "UNSAFE_PAGES_DIR");
    }
  }
}

// ---------------------------------------------------------------------------
// Atomic write protocol (Revision 25 "Atomic-write protocol, exact")
// ---------------------------------------------------------------------------

/**
 * Writes `content` to `finalPath` using the frozen 8-step exclusive-temp
 * -then-rename-then-fsync protocol. `fsImpl` must expose `writeFileSync`,
 * `closeSync`, `openSync`, `fsyncSync`, `renameSync`, `existsSync`,
 * `lstatSync`, `unlinkSync`. `randomBytesImpl` defaults to
 * `crypto.randomBytes`. Never opens the final path directly for writing.
 */
function atomicWriteFile({ finalPath, content, fsImpl, randomBytesImpl, directoryFsync = true, safeRoot }) {
  const dir = path.dirname(finalPath);
  const stopAt = safeRoot || dir;
  assertAncestorChainNotSymlinked({ canonicalPath: dir, stopAt, fsImpl });

  const nonce = (randomBytesImpl || crypto.randomBytes)(12).toString("hex");
  const tempPath = path.join(dir, `.${path.basename(finalPath)}.${nonce}.tmp`);

  const buffer = Buffer.from(content, "utf8");
  let fd;
  try {
    fd = fsImpl.openSync(tempPath, "wx");
  } catch (err) {
    throw new InventoryError(`Failed to exclusively create temporary file: ${tempPath} (${err.message})`, "TEMP_CREATE_FAILED");
  }
  try {
    const written = fsImpl.writeSync(fd, buffer, 0, buffer.length, 0);
    if (written !== buffer.length) {
      throw new InventoryError(`Short write for temporary file: ${tempPath}`, "SHORT_WRITE");
    }
    fsImpl.fsyncSync(fd);
  } finally {
    fsImpl.closeSync(fd);
  }

  assertAncestorChainNotSymlinked({ canonicalPath: dir, stopAt, fsImpl });
  assertSafeRenameDestination(finalPath, fsImpl);
  fsImpl.renameSync(tempPath, finalPath);

  if (directoryFsync) {
    let dirFd;
    try {
      dirFd = fsImpl.openSync(dir, "r");
      fsImpl.fsyncSync(dirFd);
    } catch (err) {
      throw new InventoryError(
        `Directory fsync failed or is unsupported on this platform: ${dir} (${err.message})`,
        "DIRECTORY_FSYNC_FAILED"
      );
    } finally {
      if (dirFd !== undefined) fsImpl.closeSync(dirFd);
    }
  }
}

// ---------------------------------------------------------------------------
// Single-writer lock (Revision 25 "Single-writer lock, exact")
// ---------------------------------------------------------------------------

function lockPathFor(outputDir, runId) {
  return path.join(outputDir, `${runId}.lock`);
}

/**
 * Acquires the run's exclusive lock via `wx` create, writing a fresh
 * per-acquisition ownership token. Returns `{ ownershipToken, lockPath }`.
 * Throws `InventoryError` if the lock already exists.
 */
function acquireLock({ outputDir, runId, fsImpl, randomBytesImpl, pid, hostname, now }) {
  assertAncestorChainNotSymlinked({ canonicalPath: outputDir, stopAt: outputDir, fsImpl });
  const lockPath = lockPathFor(outputDir, runId);
  const ownershipToken = (randomBytesImpl || crypto.randomBytes)(16).toString("hex");
  const lockContent = JSON.stringify(
    {
      schemaVersion: SCHEMA_VERSION,
      runId,
      ownershipToken,
      pid,
      hostname,
      acquiredAt: now,
    },
    null,
    2
  );
  let fd;
  try {
    fd = fsImpl.openSync(lockPath, "wx");
  } catch (err) {
    throw new InventoryError(`Lock already held for runId: ${runId} (${err.message})`, "LOCK_HELD");
  }
  try {
    const buffer = Buffer.from(lockContent, "utf8");
    fsImpl.writeSync(fd, buffer, 0, buffer.length, 0);
    fsImpl.fsyncSync(fd);
  } finally {
    fsImpl.closeSync(fd);
  }
  return { ownershipToken, lockPath };
}

function validateLockSchema(obj) {
  if (!obj || typeof obj !== "object") return false;
  const keys = Object.keys(obj);
  if (keys.length !== LOCK_FIELDS.length) return false;
  for (const field of LOCK_FIELDS) {
    if (!Object.prototype.hasOwnProperty.call(obj, field)) return false;
  }
  return obj.schemaVersion === SCHEMA_VERSION && typeof obj.runId === "string" && typeof obj.ownershipToken === "string";
}

/**
 * Releases the lock only after confirming, via `lstat` (never following a
 * symlink) plus an exact `ownershipToken` match, that this process still
 * owns it. Any mismatch, missing file, symlink, or malformed lock is left
 * completely untouched and reported as a cleanup-failure diagnostic.
 */
function releaseLock({ lockPath, ownershipToken, fsImpl }) {
  if (!fsImpl.existsSync(lockPath)) {
    return { released: false, reason: "LOCK_MISSING" };
  }
  const stat = fsImpl.lstatSync(lockPath);
  if (!stat.isFile() || stat.isSymbolicLink()) {
    return { released: false, reason: "LOCK_NOT_REGULAR_FILE" };
  }
  let parsed;
  try {
    parsed = JSON.parse(fsImpl.readFileSync(lockPath, "utf8"));
  } catch {
    return { released: false, reason: "LOCK_MALFORMED" };
  }
  if (!validateLockSchema(parsed)) {
    return { released: false, reason: "LOCK_SCHEMA_INVALID" };
  }
  if (parsed.ownershipToken !== ownershipToken) {
    return { released: false, reason: "LOCK_TOKEN_MISMATCH" };
  }
  try {
    fsImpl.unlinkSync(lockPath);
  } catch {
    return { released: false, reason: "LOCK_UNLINK_FAILED" };
  }
  return { released: true, reason: null };
}

// ---------------------------------------------------------------------------
// Checkpoint schema (Revision 25 "Checkpoint schema, exact")
// ---------------------------------------------------------------------------

function checkpointPathFor(outputDir, runId) {
  return path.join(outputDir, `${runId}.checkpoint.json`);
}

function buildFreshCheckpoint({ runId, toolVersion, projectBinding, projectClassification, now }) {
  return {
    schemaVersion: SCHEMA_VERSION,
    runId,
    toolVersion,
    projectBinding,
    projectClassification,
    status: RUN_STATUS.IN_PROGRESS,
    lastCommittedPageIndex: -1,
    lastCommittedPath: null,
    startedAt: now,
    lastActivityAt: now,
    completedAt: null,
    readFailureCount: 0,
  };
}

/**
 * Validates a parsed checkpoint object against the exact, exhaustive
 * 10-field schema. Never accepts `examinedCount`/`documentsExamined`/
 * `categoryCounts`/`violationCount`/`totalViolations` or any other
 * page-derived aggregate field.
 */
function validateCheckpointSchema(obj) {
  const errors = [];
  if (!obj || typeof obj !== "object" || Array.isArray(obj)) {
    return { valid: false, errors: ["Checkpoint is not a plain object"] };
  }
  const keys = Object.keys(obj);
  for (const key of keys) {
    if (!CHECKPOINT_FIELDS.includes(key)) errors.push(`Unrecognized checkpoint field: ${key}`);
  }
  for (const field of CHECKPOINT_FIELDS) {
    if (!Object.prototype.hasOwnProperty.call(obj, field)) errors.push(`Missing checkpoint field: ${field}`);
  }
  if (obj.schemaVersion !== SCHEMA_VERSION) errors.push(`Unrecognized schemaVersion: ${obj.schemaVersion}`);
  if (typeof obj.runId !== "string" || !RUN_ID_PATTERN.test(obj.runId)) errors.push("Invalid runId");
  if (typeof obj.toolVersion !== "string" || obj.toolVersion.length === 0) errors.push("Invalid toolVersion");
  if (typeof obj.projectBinding !== "string" || obj.projectBinding.length === 0) errors.push("Invalid projectBinding");
  if (!PROJECT_CLASSIFICATIONS.includes(obj.projectClassification)) errors.push("Invalid projectClassification");
  if (![RUN_STATUS.IN_PROGRESS, RUN_STATUS.COMPLETED, RUN_STATUS.FAILED].includes(obj.status)) {
    errors.push("Invalid status");
  }
  if (!Number.isInteger(obj.lastCommittedPageIndex) || obj.lastCommittedPageIndex < -1) {
    errors.push("Invalid lastCommittedPageIndex");
  }
  if (obj.lastCommittedPath !== null && typeof obj.lastCommittedPath !== "string") {
    errors.push("Invalid lastCommittedPath");
  }
  if (typeof obj.startedAt !== "string") errors.push("Invalid startedAt");
  if (typeof obj.lastActivityAt !== "string") errors.push("Invalid lastActivityAt");
  if (obj.completedAt !== null && typeof obj.completedAt !== "string") errors.push("Invalid completedAt");
  if (obj.status === RUN_STATUS.IN_PROGRESS && obj.completedAt !== null) errors.push("in_progress status must have null completedAt");
  if (obj.status !== RUN_STATUS.IN_PROGRESS && obj.completedAt === null) errors.push("terminal status must have a completedAt");
  if (!Number.isInteger(obj.readFailureCount) || obj.readFailureCount < 0) errors.push("Invalid readFailureCount");
  return { valid: errors.length === 0, errors };
}

function readCheckpoint({ outputDir, runId, fsImpl }) {
  const checkpointPath = checkpointPathFor(outputDir, runId);
  if (!fsImpl.existsSync(checkpointPath)) return { exists: false, checkpoint: null, errors: [] };
  const stat = fsImpl.lstatSync(checkpointPath);
  if (!stat.isFile() || stat.isSymbolicLink()) {
    return { exists: true, checkpoint: null, errors: ["Checkpoint path is not a regular file"] };
  }
  let parsed;
  try {
    parsed = JSON.parse(fsImpl.readFileSync(checkpointPath, "utf8"));
  } catch (err) {
    return { exists: true, checkpoint: null, errors: [`Checkpoint is not valid JSON: ${err.message}`] };
  }
  const { valid, errors } = validateCheckpointSchema(parsed);
  if (!valid) return { exists: true, checkpoint: null, errors };
  return { exists: true, checkpoint: parsed, errors: [] };
}

function writeCheckpointAtomic({ outputDir, checkpoint, fsImpl, randomBytesImpl }) {
  const { valid, errors } = validateCheckpointSchema(checkpoint);
  if (!valid) throw new InventoryError(`Refusing to write invalid checkpoint: ${errors.join("; ")}`, "INVALID_CHECKPOINT");
  const finalPath = checkpointPathFor(outputDir, checkpoint.runId);
  atomicWriteFile({
    finalPath,
    content: JSON.stringify(checkpoint, null, 2),
    fsImpl,
    randomBytesImpl,
    safeRoot: outputDir,
  });
}

// ---------------------------------------------------------------------------
// Resume project-binding, exact ordering
// ---------------------------------------------------------------------------

/**
 * Compares a resumed checkpoint's stored `projectBinding` against the
 * current invocation's own resolved project identity. Exact-match only —
 * never a classification-level comparison. A missing/malformed binding
 * fails exactly like a mismatch.
 */
function assertProjectBindingMatches({ checkpoint, currentProject }) {
  if (typeof checkpoint.projectBinding !== "string" || checkpoint.projectBinding.length === 0) {
    throw new InventoryError("Checkpoint has a missing or malformed project binding", "MISSING_PROJECT_BINDING");
  }
  if (checkpoint.projectBinding !== currentProject) {
    throw new InventoryError("Resumed checkpoint's project binding does not match --project", "PROJECT_BINDING_MISMATCH");
  }
}

// ---------------------------------------------------------------------------
// Page-journal schema (Revision 25 "Page-journal schema, exact")
// ---------------------------------------------------------------------------

function pagesDirFor(outputDir, runId) {
  return path.join(outputDir, `${runId}.pages`);
}

function pageJournalFilenameFor(pageIndex) {
  return `${String(pageIndex).padStart(8, "0")}.json`;
}

function pageJournalPathFor(outputDir, runId, pageIndex) {
  return path.join(pagesDirFor(outputDir, runId), pageJournalFilenameFor(pageIndex));
}

/**
 * Ascending document-path comparison, the frozen ordering everywhere in
 * this contract. Compares the UTF-8 *byte* encoding of each path, not
 * JavaScript's native UTF-16 code-unit `<` ordering — the two are
 * documented to diverge for supplementary-plane Unicode characters
 * (surrogate pairs sort differently under UTF-16 code-unit comparison than
 * their 4-byte UTF-8 encoding sorts under byte comparison). This
 * implements exactly the plan's own "ascending Firestore document
 * name/path order" requirement as a precise UTF-8 byte-ordering
 * comparator; it does not, and cannot, independently verify any
 * undocumented internal behavior of Firestore's own storage engine beyond
 * that documented byte-ordering contract. Fails closed on any non-string
 * input — a malformed path can never silently compare as "equal" or
 * "before" a well-formed one.
 */
function comparePaths(a, b) {
  if (typeof a !== "string" || typeof b !== "string") {
    throw new InventoryError("comparePaths requires two strings", "INVALID_PATH_COMPARISON");
  }
  if (a === b) return 0;
  return Buffer.compare(Buffer.from(a, "utf8"), Buffer.from(b, "utf8"));
}

function buildPageJournal({ runId, pageIndex, pageStartExclusivePath, pageEndInclusivePath, examinedCount, categoryCounts, violations }) {
  return {
    schemaVersion: SCHEMA_VERSION,
    runId,
    pageIndex,
    pageStartExclusivePath,
    pageEndInclusivePath,
    examinedCount,
    categoryCounts,
    violations,
  };
}

/**
 * Rules 1-16 (content/structural validation) plus rule 16's exact-field
 * check. Rule 1 (regular, non-symlink file) is enforced by the caller via
 * `lstat` before this function is ever invoked with parsed content. Rules
 * 17/18 (post-acceptance immutability, failure semantics) are behavioral
 * commitments enforced by `atomicWriteFile`'s write-once installation and
 * by `Output-corruption fail-closed behavior` (see `reconcileJournalChain`).
 */
function validatePageJournalContent(journal, { expectedRunId, expectedPageIndex, checkpointLastCommittedPath }) {
  const errors = [];
  if (!journal || typeof journal !== "object" || Array.isArray(journal)) {
    return { valid: false, errors: ["Journal is not a plain object"] };
  }

  const keys = Object.keys(journal);
  for (const key of keys) {
    if (!PAGE_JOURNAL_FIELDS.includes(key)) errors.push(`Unrecognized field: ${key}`); // rule 16
  }
  for (const field of PAGE_JOURNAL_FIELDS) {
    if (!Object.prototype.hasOwnProperty.call(journal, field)) errors.push(`Missing field: ${field}`);
  }
  if (errors.length > 0) return { valid: false, errors };

  if (journal.schemaVersion !== SCHEMA_VERSION) errors.push(`Unrecognized schemaVersion: ${journal.schemaVersion}`); // rule 2
  if (journal.runId !== expectedRunId) errors.push("runId does not match current run"); // rule 3
  if (journal.pageIndex !== expectedPageIndex) errors.push("pageIndex does not match expected position"); // rule 4

  if (journal.pageStartExclusivePath !== checkpointLastCommittedPath) {
    errors.push("pageStartExclusivePath does not equal checkpoint.lastCommittedPath"); // rule 5
  }
  if (typeof journal.pageEndInclusivePath !== "string" || journal.pageEndInclusivePath.length === 0) {
    errors.push("pageEndInclusivePath is not a valid document path"); // rule 6
  } else if (
    journal.pageStartExclusivePath !== null &&
    typeof journal.pageStartExclusivePath === "string" &&
    comparePaths(journal.pageEndInclusivePath, journal.pageStartExclusivePath) <= 0
  ) {
    errors.push("pageEndInclusivePath does not strictly follow pageStartExclusivePath"); // rule 7
  } else if (journal.pageStartExclusivePath !== null && typeof journal.pageStartExclusivePath !== "string") {
    errors.push("pageStartExclusivePath is neither null nor a string"); // rule 7 (malformed, fails closed)
  }

  if (!Number.isInteger(journal.examinedCount) || journal.examinedCount < 0) {
    errors.push("examinedCount is not a non-negative safe integer"); // rule 8
  }

  const cc = journal.categoryCounts;
  let categorySum = null;
  if (!cc || typeof cc !== "object" || Array.isArray(cc)) {
    errors.push("categoryCounts is not an object");
  } else {
    const ccKeys = Object.keys(cc);
    for (const key of ccKeys) {
      if (!CATEGORY_KEYS.includes(key)) errors.push(`categoryCounts has an unrecognized key: ${key}`);
    }
    for (const key of CATEGORY_KEYS) {
      if (!Number.isInteger(cc[key]) || cc[key] < 0) errors.push(`categoryCounts.${key} is not a non-negative safe integer`); // rule 9
    }
    categorySum = CATEGORY_KEYS.reduce((sum, key) => sum + (Number.isInteger(cc[key]) ? cc[key] : 0), 0);
  }
  if (categorySum !== null && Number.isInteger(journal.examinedCount) && categorySum !== journal.examinedCount) {
    errors.push("Sum of categoryCounts does not equal examinedCount"); // rule 10
  }

  const violations = journal.violations;
  if (!Array.isArray(violations)) {
    errors.push("violations is not an array");
  } else {
    let previousPath = null;
    const seenPaths = new Set();
    for (const entry of violations) {
      if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
        errors.push("A violations entry is not a plain object");
        continue;
      }
      const entryKeys = Object.keys(entry);
      for (const key of entryKeys) {
        if (!VIOLATION_ENTRY_FIELDS.includes(key)) errors.push(`violations entry has an unrecognized field: ${key}`); // rule 11
      }
      if (typeof entry.path !== "string" || entry.path.length === 0) {
        errors.push("A violations entry has an invalid path"); // rule 11
      }
      if (!isViolationCategory(entry.category)) {
        errors.push(`A violations entry has an invalid category: ${entry.category}`); // rule 11
      }
      const hasObservedLength = Object.prototype.hasOwnProperty.call(entry, "observedLength");
      if (entry.category === CATEGORY_OVERSIZED) {
        if (!hasObservedLength || !Number.isInteger(entry.observedLength) || entry.observedLength < 21) {
          errors.push("A media_oversized violations entry is missing a valid observedLength >= 21"); // rule 12
        }
      } else if (hasObservedLength) {
        errors.push("observedLength present on a non-media_oversized violations entry"); // rule 12
      }
      if (typeof entry.path === "string") {
        if (seenPaths.has(entry.path)) errors.push(`Duplicate violation path: ${entry.path}`); // rule 14
        seenPaths.add(entry.path);
        if (previousPath !== null && comparePaths(entry.path, previousPath) <= 0) {
          errors.push(`Violation paths are not strictly ascending at: ${entry.path}`); // rule 14
        }
        previousPath = entry.path;
        if (
          typeof journal.pageStartExclusivePath === "string" &&
          comparePaths(entry.path, journal.pageStartExclusivePath) <= 0
        ) {
          errors.push(`Violation path falls at/before pageStartExclusivePath: ${entry.path}`); // rule 15
        }
        if (
          typeof journal.pageEndInclusivePath === "string" &&
          comparePaths(entry.path, journal.pageEndInclusivePath) > 0
        ) {
          errors.push(`Violation path falls after pageEndInclusivePath: ${entry.path}`); // rule 15
        }
      }
    }
    if (categorySum !== null && cc) {
      const conforming = Number.isInteger(cc[CATEGORY_CONFORMING]) ? cc[CATEGORY_CONFORMING] : 0;
      const violatingTotal = (categorySum || 0) - conforming;
      if (violations.length !== violatingTotal) {
        errors.push("violations.length does not equal the sum of the four violating category counts"); // rule 13
      }
    }
  }

  return { valid: errors.length === 0, errors };
}

/** Rule 1: reads and validates a journal file end to end (fs safety + content). */
function readAndValidatePageJournal({ outputDir, runId, pageIndex, checkpointLastCommittedPath, fsImpl }) {
  const journalPath = pageJournalPathFor(outputDir, runId, pageIndex);
  if (!fsImpl.existsSync(journalPath)) return { exists: false, journal: null, errors: [] };
  const stat = fsImpl.lstatSync(journalPath);
  if (!stat.isFile() || stat.isSymbolicLink()) {
    return { exists: true, journal: null, errors: ["Journal path is not a regular, non-symlink file"] }; // rule 1
  }
  let parsed;
  try {
    parsed = JSON.parse(fsImpl.readFileSync(journalPath, "utf8"));
  } catch (err) {
    return { exists: true, journal: null, errors: [`Journal is not valid JSON: ${err.message}`] };
  }
  const { valid, errors } = validatePageJournalContent(parsed, {
    expectedRunId: runId,
    expectedPageIndex: pageIndex,
    checkpointLastCommittedPath,
  });
  if (!valid) return { exists: true, journal: null, errors };
  return { exists: true, journal: parsed, errors: [] };
}

function writePageJournalAtomic({ outputDir, journal, fsImpl, randomBytesImpl }) {
  const finalPath = pageJournalPathFor(outputDir, journal.runId, journal.pageIndex);
  assertSafeRenameDestination(finalPath, fsImpl); // rule 9 (pre-existing-journal never blindly overwritten)
  if (fsImpl.existsSync(finalPath)) {
    throw new InventoryError(`Page journal already exists and is immutable: ${finalPath}`, "JOURNAL_ALREADY_COMMITTED"); // rule 17
  }
  atomicWriteFile({
    finalPath,
    content: JSON.stringify(journal, null, 2),
    fsImpl,
    randomBytesImpl,
    safeRoot: outputDir,
  });
}

// ---------------------------------------------------------------------------
// Full pairwise journal-chain continuity (9 rules)
// ---------------------------------------------------------------------------

const FIRST_PAGE_SENTINEL = null;

/**
 * The single authoritative full-directory inspection step. Enumerates
 * *every* entry in `<runId>.pages/` — never just one or two canonical
 * filenames — and fails closed on any anomaly, before the caller may trust
 * anything about the directory's contents. Every entry is inspected with
 * `lstat` (never followed). Only a regular, non-symlink file whose name is
 * exactly the canonical `<8-digit-zero-padded-pageIndex>.json` form (and
 * round-trips exactly through `pageJournalFilenameFor`) is ever accepted.
 *
 * Given `lastCommittedPageIndex` (`N`) and `checkpointStatus`, the only two
 * valid outcomes are:
 *   - the directory contains exactly the committed prefix (`{0..N}`, or
 *     nothing if `N === -1`) and nothing else — returns
 *     `{ prefixIndexes, aheadIndex: null }`;
 *   - the directory contains exactly that prefix plus exactly one further
 *     entry at exactly `N + 1`, **and** `checkpointStatus` is
 *     `"in_progress"` (a `completed`/`failed` checkpoint has nothing
 *     legitimately ahead of it — an entry there is itself an anomaly) —
 *     returns `{ prefixIndexes, aheadIndex: N + 1 }`.
 * Any other observed state — a gap or missing entry inside the prefix, an
 * index farther ahead than `N + 1`, more than one entry beyond the prefix,
 * a noncanonical filename, a symlink, a directory, a socket/device/FIFO, a
 * duplicate semantic index, or an entry beyond the prefix while the
 * checkpoint is already terminal — throws `InventoryError` before
 * returning, and before the caller may attempt any Firestore read,
 * checkpoint advance, journal mutation, or output regeneration. Never
 * deletes or otherwise touches a suspicious entry.
 */
function enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex, checkpointStatus, fsImpl }) {
  const pagesDir = pagesDirFor(outputDir, runId);
  const canonicalIndexes = new Set();

  if (fsImpl.existsSync(pagesDir)) {
    const dirStat = fsImpl.lstatSync(pagesDir);
    if (dirStat.isSymbolicLink() || !dirStat.isDirectory()) {
      throw new InventoryError(`Page-journal directory is not a real, non-symlink directory: ${pagesDir}`, "UNSAFE_PAGES_DIR");
    }
    for (const entry of fsImpl.readdirSync(pagesDir)) {
      const entryPath = path.join(pagesDir, entry);
      const entryStat = fsImpl.lstatSync(entryPath);
      if (entryStat.isSymbolicLink()) {
        throw new InventoryError(`Unexpected symlink in page-journal directory: ${entry}`, "PAGES_DIR_ANOMALY");
      }
      if (!entryStat.isFile()) {
        throw new InventoryError(`Unexpected non-regular entry in page-journal directory: ${entry}`, "PAGES_DIR_ANOMALY");
      }
      const match = /^(\d{8})\.json$/.exec(entry);
      if (!match) {
        throw new InventoryError(`Noncanonical filename in page-journal directory: ${entry}`, "PAGES_DIR_ANOMALY");
      }
      const index = Number(match[1]);
      if (!Number.isSafeInteger(index) || index < 0 || pageJournalFilenameFor(index) !== entry) {
        throw new InventoryError(`Filename does not round-trip through the canonical formatter: ${entry}`, "PAGES_DIR_ANOMALY");
      }
      if (canonicalIndexes.has(index)) {
        throw new InventoryError(`Duplicate semantic pageIndex represented in page-journal directory: ${index}`, "PAGES_DIR_ANOMALY");
      }
      canonicalIndexes.add(index);
    }
  }

  const prefixIndexes = [];
  for (let i = 0; i <= lastCommittedPageIndex; i += 1) prefixIndexes.push(i);
  for (const i of prefixIndexes) {
    if (!canonicalIndexes.has(i)) {
      throw new InventoryError(`Missing committed journal at pageIndex ${i}`, "PAGES_DIR_ANOMALY");
    }
  }

  const beyondPrefix = [...canonicalIndexes].filter((i) => i > lastCommittedPageIndex).sort((a, b) => a - b);

  if (beyondPrefix.length === 0) {
    return { prefixIndexes, aheadIndex: null };
  }

  if (
    checkpointStatus === RUN_STATUS.IN_PROGRESS &&
    beyondPrefix.length === 1 &&
    beyondPrefix[0] === lastCommittedPageIndex + 1
  ) {
    return { prefixIndexes, aheadIndex: lastCommittedPageIndex + 1 };
  }

  throw new InventoryError(
    `Unexpected page-journal entries beyond the committed prefix: ${beyondPrefix.join(", ")} (checkpoint status: ${checkpointStatus})`,
    "PAGES_DIR_ANOMALY"
  );
}

/**
 * Loads and validates every committed page journal implied by
 * `checkpoint.lastCommittedPageIndex`, individually (18-rule contract) and
 * as a full ordered chain (9-rule contract), after first requiring the
 * complete page-journal directory to contain exactly that prefix (and, for
 * an `in_progress` checkpoint, at most one further entry at exactly
 * `lastCommittedPageIndex + 1`, ignored here and left for
 * `reconcileAheadOfCheckpointJournal` to handle). Returns `{ valid, errors,
 * journals }`. Never issues a Firestore read or mutates any artifact.
 */
function loadAndValidateJournalChain({ outputDir, runId, checkpoint, fsImpl }) {
  const lastIndex = checkpoint.lastCommittedPageIndex;

  let prefixIndexes;
  try {
    ({ prefixIndexes } = enumeratePageDirectory({
      outputDir,
      runId,
      lastCommittedPageIndex: lastIndex,
      checkpointStatus: checkpoint.status,
      fsImpl,
    }));
  } catch (err) {
    return { valid: false, errors: [err.message], journals: [] };
  }

  if (lastIndex === -1) {
    // rule 6: empty/fresh-run case
    return { valid: true, errors: [], journals: [] };
  }

  const errors = [];
  const journals = [];
  let previousEndPath = FIRST_PAGE_SENTINEL;
  for (const i of prefixIndexes) {
    const expectedStart = i === 0 ? FIRST_PAGE_SENTINEL : previousEndPath;
    const { journal, errors: journalErrors } = readAndValidatePageJournal({
      outputDir,
      runId,
      pageIndex: i,
      checkpointLastCommittedPath: expectedStart,
      fsImpl,
    });
    if (!journal) {
      errors.push(...journalErrors.map((e) => `pageIndex ${i}: ${e}`));
      continue;
    }
    if (i === 0 && journal.pageStartExclusivePath !== FIRST_PAGE_SENTINEL) {
      errors.push("First journal does not use the frozen first-page sentinel"); // rule 2
    }
    if (i > 0 && journal.pageStartExclusivePath !== previousEndPath) {
      errors.push(`pageIndex ${i}: pageStartExclusivePath does not equal previous journal's pageEndInclusivePath`); // rule 3
    }
    if (previousEndPath !== null && comparePaths(journal.pageEndInclusivePath, previousEndPath) <= 0) {
      errors.push(`pageIndex ${i}: cursor did not strictly progress across the chain`); // rule 4
    }
    journals.push(journal);
    previousEndPath = journal.pageEndInclusivePath;
  }

  if (errors.length > 0) return { valid: false, errors, journals: [] };

  const finalJournal = journals[journals.length - 1];
  if (finalJournal.pageIndex !== checkpoint.lastCommittedPageIndex) {
    errors.push("checkpoint.lastCommittedPageIndex does not equal the final validated journal's own pageIndex"); // rule 5
  }
  if (finalJournal.pageEndInclusivePath !== checkpoint.lastCommittedPath) {
    errors.push("checkpoint.lastCommittedPath does not equal the final validated journal's own pageEndInclusivePath"); // rule 5
  }

  return { valid: errors.length === 0, errors, journals };
}

/**
 * Implements the "Idempotent page-commit order, exact" fast path: before
 * ever fetching a new page, requires the complete page-journal directory
 * (via `enumeratePageDirectory`, never a probe of just one or two
 * filenames) to resolve to either "nothing ahead of the checkpoint" or
 * "exactly one journal at `lastCommittedPageIndex + 1`" — the
 * "process crashed between the journal's own atomic rename and the
 * checkpoint's advance" state. Never fetches, never reclassifies, never
 * rewrites the immutable journal. Returns:
 *   - `{ reconciled: false, checkpoint, journal: null }` if nothing is
 *     ahead of the checkpoint — the caller proceeds to fetch normally;
 *   - `{ reconciled: true, checkpoint: <advanced>, journal }` if the single
 *     ahead journal passed the complete 18-rule validation contract and
 *     the checkpoint has been advanced to match it, with nothing else
 *     mutated;
 *   - throws `InventoryError` (fail-closed, no Firestore/output mutation of
 *     any kind attempted) if `enumeratePageDirectory` itself throws (any
 *     directory anomaly), or if the single ahead journal it identifies
 *     fails the 18-rule content contract.
 * Idempotent across repeated restarts: once the checkpoint has actually
 * advanced, `lastCommittedPageIndex + 1` points at a new, not-yet-existing
 * index, so a second restart finds nothing to reconcile.
 */
function reconcileAheadOfCheckpointJournal({ outputDir, runId, checkpoint, fsImpl }) {
  const { aheadIndex } = enumeratePageDirectory({
    outputDir,
    runId,
    lastCommittedPageIndex: checkpoint.lastCommittedPageIndex,
    checkpointStatus: checkpoint.status,
    fsImpl,
  });

  if (aheadIndex === null) {
    return { reconciled: false, checkpoint, journal: null };
  }

  const { journal, errors } = readAndValidatePageJournal({
    outputDir,
    runId,
    pageIndex: aheadIndex,
    checkpointLastCommittedPath: checkpoint.lastCommittedPath,
    fsImpl,
  });
  if (!journal) {
    throw new InventoryError(
      `Ahead-of-checkpoint journal at pageIndex ${aheadIndex} failed validation: ${errors.join("; ")}`,
      "AHEAD_JOURNAL_CORRUPT"
    );
  }

  const advancedCheckpoint = {
    ...checkpoint,
    lastCommittedPageIndex: journal.pageIndex,
    lastCommittedPath: journal.pageEndInclusivePath,
  };
  return { reconciled: true, checkpoint: advancedCheckpoint, journal };
}

// ---------------------------------------------------------------------------
// Aggregate recomputation (never read from the checkpoint)
// ---------------------------------------------------------------------------

/**
 * Recomputes `documentsExamined`/`categoryCounts`/`totalViolations`/
 * `pagesCompleted` deterministically from a validated journal chain alone.
 * An empty chain recomputes to all-zero totals.
 */
function recomputeAggregates(journals) {
  const categoryCounts = Object.fromEntries(CATEGORY_KEYS.map((k) => [k, 0]));
  let documentsExamined = 0;
  let totalViolations = 0;
  for (const journal of journals) {
    documentsExamined += journal.examinedCount;
    for (const key of CATEGORY_KEYS) categoryCounts[key] += journal.categoryCounts[key];
    totalViolations += journal.violations.length;
  }
  return { documentsExamined, categoryCounts, totalViolations, pagesCompleted: journals.length };
}

// ---------------------------------------------------------------------------
// Summary / Markdown / NDJSON (derived, regenerable, never authoritative)
// ---------------------------------------------------------------------------

function summaryPathFor(outputDir, runId) {
  return path.join(outputDir, `${runId}.summary.json`);
}
function markdownPathFor(outputDir, runId) {
  return path.join(outputDir, `${runId}.summary.md`);
}
function ndjsonPathFor(outputDir, runId) {
  return path.join(outputDir, `${runId}.violations.ndjson`);
}

function buildSummary({ checkpoint, aggregates, toolVersion }) {
  return {
    schemaVersion: SCHEMA_VERSION,
    runId: checkpoint.runId,
    toolVersion,
    projectClassification: checkpoint.projectClassification,
    status: checkpoint.status,
    startedAt: checkpoint.startedAt,
    completedAt: checkpoint.completedAt,
    pagesCompleted: aggregates.pagesCompleted,
    documentsExamined: aggregates.documentsExamined,
    readFailureCount: checkpoint.readFailureCount,
    categoryCounts: aggregates.categoryCounts,
    totalViolations: aggregates.totalViolations,
  };
}

function writeSummaryAtomic({ outputDir, summary, fsImpl, randomBytesImpl }) {
  atomicWriteFile({
    finalPath: summaryPathFor(outputDir, summary.runId),
    content: JSON.stringify(summary, null, 2),
    fsImpl,
    randomBytesImpl,
    safeRoot: outputDir,
  });
}

/** Generation is only ever authorized for a terminal (`completed`/`failed`) run. */
function renderMarkdownSummary(summary) {
  if (summary.status === RUN_STATUS.IN_PROGRESS) {
    throw new InventoryError("Markdown generation is not authorized for an in_progress run", "MARKDOWN_NOT_TERMINAL");
  }
  const lines = [
    `# Media-compatibility readiness inventory — ${summary.runId}`,
    "",
    `- projectClassification: ${summary.projectClassification}`,
    `- status: ${summary.status}`,
    `- startedAt: ${summary.startedAt}`,
    `- completedAt: ${summary.completedAt}`,
    `- documentsExamined: ${summary.documentsExamined}`,
    `- pagesCompleted: ${summary.pagesCompleted}`,
    `- readFailureCount: ${summary.readFailureCount}`,
    `- toolVersion: ${summary.toolVersion}`,
    "",
    "## Category counts",
    "",
    ...CATEGORY_KEYS.map((key) => `- ${key}: ${summary.categoryCounts[key]}`),
    "",
    `- totalViolations: ${summary.totalViolations}`,
    "",
    NO_MUTATION_SENTENCE,
    "",
  ];
  return lines.join("\n");
}

function writeMarkdownAtomic({ outputDir, summary, fsImpl, randomBytesImpl }) {
  atomicWriteFile({
    finalPath: markdownPathFor(outputDir, summary.runId),
    content: renderMarkdownSummary(summary),
    fsImpl,
    randomBytesImpl,
    safeRoot: outputDir,
  });
}

/** One JSON object per line, in strict page order, `{path, category, observedLength?}` only. */
function renderViolationsNdjson(journals) {
  const lines = [];
  for (const journal of journals) {
    for (const violation of journal.violations) {
      const entry = { path: violation.path, category: violation.category };
      if (Object.prototype.hasOwnProperty.call(violation, "observedLength")) {
        entry.observedLength = violation.observedLength;
      }
      lines.push(JSON.stringify(entry));
    }
  }
  return lines.length > 0 ? lines.join("\n") + "\n" : "";
}

function writeNdjsonAtomic({ outputDir, runId, journals, fsImpl, randomBytesImpl }) {
  atomicWriteFile({
    finalPath: ndjsonPathFor(outputDir, runId),
    content: renderViolationsNdjson(journals),
    fsImpl,
    randomBytesImpl,
    safeRoot: outputDir,
  });
}

// ---------------------------------------------------------------------------
// Read-only Firestore adapter (read/query only; no write method exposed)
// ---------------------------------------------------------------------------

/**
 * Wraps a real `firebase-admin` Firestore instance in a strictly read-only
 * adapter exposing exactly one method, `fetchPage`. No `.set`/`.update`/
 * `.delete`/`.create`/batch/transaction-write/BulkWriter method is ever
 * referenced anywhere in this module.
 */
function createFirestoreAdapter(db) {
  return {
    async fetchPage({ afterPath, pageSize }) {
      let query = db.collectionGroup("products").orderBy("__name__").limit(pageSize);
      if (afterPath) {
        query = query.startAfter(db.doc(afterPath));
      }
      const snapshot = await query.get();
      return snapshot.docs.map((docSnapshot) => ({
        path: docSnapshot.ref.path,
        data: docSnapshot.data(),
      }));
    },
  };
}

/** Exactly 3 attempts, deterministic and testable via an injected `sleepImpl`. */
async function withRetry(fn, { maxAttempts = MAX_READ_ATTEMPTS, sleepImpl } = {}) {
  let lastError;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      return await fn(attempt);
    } catch (err) {
      lastError = err;
      if (attempt < maxAttempts && sleepImpl) await sleepImpl(attempt);
    }
  }
  throw lastError;
}

// ---------------------------------------------------------------------------
// Orchestration
// ---------------------------------------------------------------------------

/**
 * Runs the complete resume-then-scan orchestration. `deps` supplies every
 * injectable boundary (`fsImpl`, `adapterFactory`, `randomBytesImpl`,
 * `nowImpl`, `pid`, `hostname`, `platform`, `env`, `repoRoot`, `homeDir`,
 * `toolVersion`, `sleepImpl`).
 *
 * Guard order, exact: every check that does not require reading mutable
 * run state (CLI parsing, platform, project/`--confirm-production`,
 * scan-bound, output-directory canonicalization, `runId` grammar) runs
 * first. The exclusive run lock is then acquired *before* any checkpoint
 * content is read, parsed, or trusted — the single-writer lock is what
 * makes the subsequent checkpoint read authoritative, not merely a
 * best-effort snapshot a concurrent invocation could race. No pre-lock
 * checkpoint read of any kind is performed; the checkpoint is read exactly
 * once, immediately after the lock is held, and that post-lock object is
 * the only one ever trusted for the remainder of the run (resume
 * project-binding comparison, chain validation, reconciliation, fetching,
 * and output regeneration all use it — none reuses any earlier snapshot,
 * because none exists).
 *
 * `adapterFactory` is a zero-argument function returning a Firestore
 * adapter (`{ fetchPage }`) — never a pre-constructed adapter. It is
 * invoked at most once, lazily memoized, and only immediately before the
 * first genuinely necessary Firestore fetch: strictly after every guard
 * above, including the post-lock checkpoint read, exact resume
 * project-binding comparison, and full 18-rule/9-rule journal-chain
 * validation. A run that resolves entirely from local state (a completed
 * resume, or a run whose next page is recovered from an already-committed
 * ahead-of-checkpoint journal) never calls `adapterFactory` at all. This is
 * what keeps `main()` free of any Admin SDK initialization for a rejected
 * or mismatched invocation — see `main()`, below.
 */
async function runInventory({ args, deps }) {
  const {
    fsImpl,
    adapterFactory,
    randomBytesImpl,
    nowImpl,
    pid,
    hostname,
    platform,
    env,
    repoRoot,
    homeDir,
    toolVersion,
    sleepImpl,
    pageSize = PAGE_SIZE,
    diagnosticSink = () => {},
  } = deps;
  let firestoreAdapter = null;
  function getFirestoreAdapter() {
    if (!firestoreAdapter) firestoreAdapter = adapterFactory();
    return firestoreAdapter;
  }

  // --- Pre-lock guards: none of these reads mutable run state. ---
  assertSupportedPlatform(platform);
  const { project, isEmulator, classification } = assertProjectGuard({ args, env });
  const { maxPages } = assertScanBoundGuard(args);
  const outputDir = resolveAndValidateOutputDir({ outputDir: args["output-dir"], repoRoot, homeDir, fsImpl });

  const isResume = typeof args["resume-run-id"] === "string";
  const runId = isResume ? validateRunId(args["resume-run-id"]) : generateRunId(randomBytesImpl);

  console.log(formatPreRunConfirmation({ classification, runId })); // guard 4

  // --- Lock acquisition: the boundary before which no checkpoint content
  // is ever read. A lock-held invocation throws here, having parsed or
  // trusted zero checkpoint bytes. ---
  const { ownershipToken, lockPath } = acquireLock({
    outputDir,
    runId,
    fsImpl,
    randomBytesImpl,
    pid,
    hostname,
    now: nowImpl(),
  });

  let lockCleanupFailed = false;
  let result;
  try {
    // --- The single, authoritative, post-lock checkpoint read. Nothing
    // before this point has read this file's content. ---
    const { exists, checkpoint: freshCheckpoint, errors: checkpointErrors } = readCheckpoint({
      outputDir,
      runId,
      fsImpl,
    });

    let checkpoint;
    if (isResume) {
      if (!exists || !freshCheckpoint) {
        throw new InventoryError(`Cannot resume: no valid checkpoint for runId ${runId} (${checkpointErrors.join("; ")})`, "CORRUPT_CHECKPOINT");
      }
      assertProjectBindingMatches({ checkpoint: freshCheckpoint, currentProject: project });
      checkpoint = freshCheckpoint;
    } else if (exists) {
      throw new InventoryError(`Refusing to overwrite an existing run: ${runId}`, "RUN_ID_COLLISION");
    } else {
      checkpoint = buildFreshCheckpoint({
        runId,
        toolVersion,
        projectBinding: project,
        projectClassification: classification,
        now: nowImpl(),
      });
      writeCheckpointAtomic({ outputDir, checkpoint, fsImpl, randomBytesImpl });
    }

    const { valid: chainValid, errors: chainErrors, journals: validatedJournals } = loadAndValidateJournalChain({
      outputDir,
      runId,
      checkpoint,
      fsImpl,
    });
    if (!chainValid) {
      checkpoint = { ...checkpoint, status: RUN_STATUS.FAILED, completedAt: nowImpl(), lastActivityAt: nowImpl() };
      writeCheckpointAtomic({ outputDir, checkpoint, fsImpl, randomBytesImpl });
      throw new InventoryError(`Journal chain failed validation: ${chainErrors.join("; ")}`, "CHAIN_CORRUPT");
    }

    // Only reached once the existing committed prefix (if any) is fully
    // validated — never create the pages directory as a side effect of a
    // run that is about to fail closed.
    assertPageJournalDirSafe(pagesDirFor(outputDir, runId), fsImpl);

    let journals = validatedJournals;
    let pagesRead = journals.length;

    while (checkpoint.status === RUN_STATUS.IN_PROGRESS && (maxPages === null || pagesRead < maxPages)) {
      // Idempotent page-commit order, exact: before ever fetching, check
      // whether the next page's journal was already durably committed by a
      // prior attempt that crashed before the checkpoint's own advance.
      const { reconciled, checkpoint: reconciledCheckpoint, journal: recoveredJournal } = reconcileAheadOfCheckpointJournal({
        outputDir,
        runId,
        checkpoint,
        fsImpl,
      });
      if (reconciled) {
        journals = journals.concat([recoveredJournal]);
        pagesRead += 1;
        const exhausted = recoveredJournal.examinedCount < pageSize;
        checkpoint = {
          ...reconciledCheckpoint,
          lastActivityAt: nowImpl(),
          status: exhausted ? RUN_STATUS.COMPLETED : RUN_STATUS.IN_PROGRESS,
          completedAt: exhausted ? nowImpl() : null,
        };
        writeCheckpointAtomic({ outputDir, checkpoint, fsImpl, randomBytesImpl });
        continue;
      }

      let page;
      try {
        page = await withRetry(
          () => getFirestoreAdapter().fetchPage({ afterPath: checkpoint.lastCommittedPath, pageSize }),
          { maxAttempts: MAX_READ_ATTEMPTS, sleepImpl }
        );
      } catch {
        checkpoint = {
          ...checkpoint,
          status: RUN_STATUS.FAILED,
          readFailureCount: checkpoint.readFailureCount + 1,
          completedAt: nowImpl(),
          lastActivityAt: nowImpl(),
        };
        writeCheckpointAtomic({ outputDir, checkpoint, fsImpl, randomBytesImpl });
        break;
      }

      if (page.length === 0) {
        // A zero-document fetch unambiguously signals true exhaustion (the
        // ordered, page-bounded query returned nothing beyond the current
        // cursor). There is nothing to examine and therefore no page
        // boundary to record — no journal is written for this attempt; the
        // checkpoint simply transitions to `completed`, matching the
        // already-frozen "empty/fresh-run" and "short final page" cases.
        checkpoint = {
          ...checkpoint,
          status: RUN_STATUS.COMPLETED,
          lastActivityAt: nowImpl(),
          completedAt: nowImpl(),
        };
        writeCheckpointAtomic({ outputDir, checkpoint, fsImpl, randomBytesImpl });
        break;
      }

      const categoryCounts = Object.fromEntries(CATEGORY_KEYS.map((k) => [k, 0]));
      const violations = [];
      for (const doc of page) {
        const { category, violation } = classifyDocument(doc.path, doc.data ? doc.data.media : undefined);
        categoryCounts[category] += 1;
        if (violation) violations.push(violation);
      }

      const pageIndex = checkpoint.lastCommittedPageIndex + 1;
      const pageStartExclusivePath = checkpoint.lastCommittedPath;
      const pageEndInclusivePath = page[page.length - 1].path;

      const journal = buildPageJournal({
        runId,
        pageIndex,
        pageStartExclusivePath,
        pageEndInclusivePath,
        examinedCount: page.length,
        categoryCounts,
        violations,
      });
      const { valid: journalValid, errors: journalErrors } = validatePageJournalContent(journal, {
        expectedRunId: runId,
        expectedPageIndex: pageIndex,
        checkpointLastCommittedPath: pageStartExclusivePath,
      });
      if (!journalValid) {
        throw new InventoryError(`Refusing to commit an invalid page journal: ${journalErrors.join("; ")}`, "INVALID_JOURNAL_BUILT");
      }

      writePageJournalAtomic({ outputDir, journal, fsImpl, randomBytesImpl });
      journals = journals.concat([journal]);
      pagesRead += 1;

      const exhausted = page.length < pageSize;
      checkpoint = {
        ...checkpoint,
        lastCommittedPageIndex: pageIndex,
        lastCommittedPath: pageEndInclusivePath,
        lastActivityAt: nowImpl(),
        status: exhausted ? RUN_STATUS.COMPLETED : RUN_STATUS.IN_PROGRESS,
        completedAt: exhausted ? nowImpl() : null,
      };
      writeCheckpointAtomic({ outputDir, checkpoint, fsImpl, randomBytesImpl });
    }

    // Before trusting/regenerating any derived output — including for a
    // run that was already `completed` on entry, or that just completed
    // during this invocation — require one final, authoritative full
    // directory enumeration against the *final* checkpoint state. This
    // catches any anomalous entry beyond the final committed prefix that
    // the loop's own per-iteration reconciliation checks (each scoped to
    // the checkpoint state *at that iteration*) would not otherwise have
    // been asked to re-confirm after the last advance.
    const { valid: finalChainValid, errors: finalChainErrors } = loadAndValidateJournalChain({
      outputDir,
      runId,
      checkpoint,
      fsImpl,
    });
    if (!finalChainValid) {
      checkpoint = { ...checkpoint, status: RUN_STATUS.FAILED, completedAt: nowImpl(), lastActivityAt: nowImpl() };
      writeCheckpointAtomic({ outputDir, checkpoint, fsImpl, randomBytesImpl });
      throw new InventoryError(`Final journal-directory validation failed before output regeneration: ${finalChainErrors.join("; ")}`, "CHAIN_CORRUPT");
    }

    const aggregates = recomputeAggregates(journals);
    const summary = buildSummary({ checkpoint, aggregates, toolVersion });
    writeSummaryAtomic({ outputDir, summary, fsImpl, randomBytesImpl });
    if (summary.status !== RUN_STATUS.IN_PROGRESS) {
      writeMarkdownAtomic({ outputDir, summary, fsImpl, randomBytesImpl });
    }
    writeNdjsonAtomic({ outputDir, runId, journals, fsImpl, randomBytesImpl });

    result = { runId, checkpoint, summary };
  } finally {
    // The release outcome is inspected, never discarded: a failed release
    // (foreign/mismatched/malformed/missing lock) is reported as a
    // cleanup-failure diagnostic naming only a safe reason class — never
    // the ownership token, the raw project identity, a credential, or any
    // product/business/document path — and a failed release never deletes
    // whatever is currently at the lock path (per `releaseLock` itself).
    // Any error while reporting the diagnostic is swallowed here so it can
    // never replace or mask the primary try-block's own result/exception —
    // if the try block threw, `result` was never assigned, and the
    // original exception continues propagating past this `finally` exactly
    // as normal `finally` semantics require, regardless of what happens
    // here.
    try {
      const releaseOutcome = releaseLock({ lockPath, ownershipToken, fsImpl });
      lockCleanupFailed = !releaseOutcome.released;
      if (lockCleanupFailed) {
        diagnosticSink(`[media-compatibility-inventory] lock cleanup failed for runId=${runId}: ${releaseOutcome.reason}`);
      }
    } catch {
      // Reporting must never itself throw past this finally block, but an
      // unexpected failure here is conservatively treated as an unreported
      // cleanup failure for the return-level signal.
      lockCleanupFailed = true;
    }
  }
  // Reached only when the try block completed without throwing — `result`
  // is guaranteed assigned, and the lock's own release outcome (known only
  // once `finally` has run) is folded into the return value here, never
  // inside `finally` itself.
  return { ...result, lockCleanupFailed };
}

// ---------------------------------------------------------------------------
// CLI entry point — never executed by `require`
// ---------------------------------------------------------------------------

function main() {
  const args = parseArgs(process.argv.slice(2));
  // `main()` itself performs zero Admin SDK / Firestore access. It only
  // supplies `runInventory` a *factory* — `require("firebase-admin")`,
  // `admin.initializeApp()`, and `admin.firestore()` are deferred inside
  // this closure and run only if/when `runInventory` itself decides a
  // genuine Firestore fetch is unavoidable, strictly after every local
  // guard (project/confirm-production, platform, scan-bound, output-dir,
  // lock, checkpoint validation, exact resume project-binding comparison)
  // has already passed. A rejected or mismatched-project invocation never
  // reaches this closure at all.
  const adapterFactory = () => {
    const admin = require("firebase-admin");
    if (!admin.apps.length) admin.initializeApp({ projectId: args.project });
    return createFirestoreAdapter(admin.firestore());
  };

  const deps = {
    fsImpl: fs,
    adapterFactory,
    randomBytesImpl: crypto.randomBytes,
    nowImpl: () => new Date().toISOString(),
    pid: process.pid,
    hostname: os.hostname(),
    platform: process.platform,
    env: process.env,
    repoRoot: path.resolve(__dirname, "..", ".."),
    homeDir: os.homedir(),
    toolVersion: "mediaCompatibilityReadinessInventory@1",
    sleepImpl: (attempt) => new Promise((resolve) => setTimeout(resolve, attempt * 250)),
    diagnosticSink: (message) => console.error(message),
  };

  runInventory({ args, deps })
    .then((result) => {
      console.log(`[media-compatibility-inventory] finished runId=${result.runId} status=${result.checkpoint.status}`);
    })
    .catch((err) => {
      console.error(`[media-compatibility-inventory] failed: ${err.message}`);
      process.exitCode = 1;
    });
}

if (require.main === module) {
  main();
}

module.exports = {
  // constants
  SCHEMA_VERSION,
  PAGE_SIZE,
  MAX_READ_ATTEMPTS,
  RUN_ID_PATTERN,
  RESERVED_BASENAMES,
  CATEGORY_KEYS,
  VIOLATION_CATEGORIES,
  CHECKPOINT_FIELDS,
  PAGE_JOURNAL_FIELDS,
  LOCK_FIELDS,
  RUN_STATUS,
  NO_MUTATION_SENTENCE,
  // classification
  classifyMedia,
  classifyDocument,
  isViolationCategory,
  // CLI/guards
  InventoryError,
  parseArgs,
  isEmulatorEnvironment,
  classifyProject,
  assertProjectGuard,
  assertScanBoundGuard,
  formatPreRunConfirmation,
  validateRunId,
  generateRunId,
  assertSupportedPlatform,
  // output-path safety
  resolveAndValidateOutputDir,
  assertAncestorChainNotSymlinked,
  assertSafeRenameDestination,
  assertPageJournalDirSafe,
  // atomic writes
  atomicWriteFile,
  // lock
  lockPathFor,
  acquireLock,
  releaseLock,
  validateLockSchema,
  // checkpoint
  checkpointPathFor,
  buildFreshCheckpoint,
  validateCheckpointSchema,
  readCheckpoint,
  writeCheckpointAtomic,
  assertProjectBindingMatches,
  // page journals
  pagesDirFor,
  pageJournalFilenameFor,
  pageJournalPathFor,
  buildPageJournal,
  validatePageJournalContent,
  readAndValidatePageJournal,
  writePageJournalAtomic,
  comparePaths,
  // chain
  loadAndValidateJournalChain,
  reconcileAheadOfCheckpointJournal,
  enumeratePageDirectory,
  // aggregates/outputs
  recomputeAggregates,
  summaryPathFor,
  markdownPathFor,
  ndjsonPathFor,
  buildSummary,
  writeSummaryAtomic,
  renderMarkdownSummary,
  writeMarkdownAtomic,
  renderViolationsNdjson,
  writeNdjsonAtomic,
  // firestore adapter
  createFirestoreAdapter,
  withRetry,
  // orchestration
  runInventory,
};
