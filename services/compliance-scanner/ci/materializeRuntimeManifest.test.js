"use strict";

// Deterministic validation for the environment-specific runtime
// fixture-manifest materialization (Slice 2.2 runtime-manifest
// correction). Exercises the pure URI/generation validators, plus
// static proof that: the committed, environment-neutral
// ci/fixtureManifest.json is never touched by this correction; a real
// pipeline run cannot fall back to it; the download is generation-
// pinned; the materialized output path is fixed, never a Cloud Build
// substitution; the dependency graph gates promotion through both the
// runtime-manifest step and the existing fixture-verification step;
// and no manifest contents are ever logged.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const {
  APPROVED_PREFIX,
  validateRuntimeManifestUri,
  validateRuntimeManifestGeneration,
  writeManifestAtomic,
} = require("./materializeRuntimeManifest");
const { validateManifestShape } = require("./fixtureManifest");

const REPO_ROOT = path.join(__dirname, "..");
const BUCKET = "petsupo-platform-staging-compliance-synthetic";
const VALID_URI = `gs://${BUCKET}/${APPROVED_PREFIX}2026-08-22-abc123.json`;

function scriptText(relPath) {
  return fs.readFileSync(path.join(REPO_ROOT, relPath), "utf8");
}

// ---------------------------------------------------------------------
// validateRuntimeManifestUri
// ---------------------------------------------------------------------

test("validateRuntimeManifestUri: a valid canonical gs:// URI under the approved prefix succeeds", () => {
  const result = validateRuntimeManifestUri({ uri: VALID_URI, expectedBucket: BUCKET });
  assert.equal(result.valid, true);
  assert.equal(result.bucket, BUCKET);
  assert.equal(result.objectPath, `${APPROVED_PREFIX}2026-08-22-abc123.json`);
});

test("validateRuntimeManifestUri: missing URI fails", () => {
  assert.equal(validateRuntimeManifestUri({ uri: "", expectedBucket: BUCKET }).valid, false);
  assert.equal(validateRuntimeManifestUri({ uri: undefined, expectedBucket: BUCKET }).valid, false);
  assert.equal(validateRuntimeManifestUri({ uri: "", expectedBucket: BUCKET }).reason, "missing_uri");
});

test("validateRuntimeManifestUri: bucket with no object path at all (gs://bucket) fails with missing_object_path", () => {
  const result = validateRuntimeManifestUri({ uri: `gs://${BUCKET}`, expectedBucket: BUCKET });
  assert.equal(result.valid, false);
  assert.equal(result.reason, "missing_object_path");
});

test("validateRuntimeManifestUri: bucket with a trailing slash and nothing after it (gs://bucket/) fails with empty_object_path", () => {
  const result = validateRuntimeManifestUri({ uri: `gs://${BUCKET}/`, expectedBucket: BUCKET });
  assert.equal(result.valid, false);
  assert.equal(result.reason, "empty_object_path");
});

test("validateRuntimeManifestUri: non-gs:// scheme fails", () => {
  const cases = [
    `https://${BUCKET}/${APPROVED_PREFIX}x.json`,
    `http://${BUCKET}/${APPROVED_PREFIX}x.json`,
    `file:///etc/passwd`,
    `s3://${BUCKET}/${APPROVED_PREFIX}x.json`,
    `${BUCKET}/${APPROVED_PREFIX}x.json`,
  ];
  for (const uri of cases) {
    const result = validateRuntimeManifestUri({ uri, expectedBucket: BUCKET });
    assert.equal(result.valid, false, `expected rejection for: ${uri}`);
    assert.equal(result.reason, "not_gs_scheme", `wrong reason for: ${uri}`);
  }
});

test("validateRuntimeManifestUri: wrong bucket fails", () => {
  const result = validateRuntimeManifestUri({
    uri: `gs://some-other-bucket/${APPROVED_PREFIX}x.json`,
    expectedBucket: BUCKET,
  });
  assert.equal(result.valid, false);
  assert.equal(result.reason, "wrong_bucket");
});

test("validateRuntimeManifestUri: wrong prefix fails", () => {
  const result = validateRuntimeManifestUri({
    uri: `gs://${BUCKET}/some-other-prefix/x.json`,
    expectedBucket: BUCKET,
  });
  assert.equal(result.valid, false);
  assert.equal(result.reason, "wrong_prefix");
});

test("validateRuntimeManifestUri: path traversal segments fail", () => {
  const cases = [
    `gs://${BUCKET}/${APPROVED_PREFIX}../secrets.json`,
    `gs://${BUCKET}/${APPROVED_PREFIX}foo/../../etc/passwd.json`,
    `gs://${BUCKET}/${APPROVED_PREFIX}./x.json`,
  ];
  for (const uri of cases) {
    const result = validateRuntimeManifestUri({ uri, expectedBucket: BUCKET });
    assert.equal(result.valid, false, `expected rejection for: ${uri}`);
  }
});

test("validateRuntimeManifestUri: control characters fail", () => {
  const result = validateRuntimeManifestUri({
    uri: `gs://${BUCKET}/${APPROVED_PREFIX}x\x00y.json`,
    expectedBucket: BUCKET,
  });
  assert.equal(result.valid, false);
  assert.equal(result.reason, "control_character_present");
});

test("validateRuntimeManifestUri: wildcards fail", () => {
  const result = validateRuntimeManifestUri({
    uri: `gs://${BUCKET}/${APPROVED_PREFIX}*.json`,
    expectedBucket: BUCKET,
  });
  assert.equal(result.valid, false);
});

test("validateRuntimeManifestUri: query strings fail", () => {
  const result = validateRuntimeManifestUri({
    uri: `gs://${BUCKET}/${APPROVED_PREFIX}x.json?generation=123`,
    expectedBucket: BUCKET,
  });
  assert.equal(result.valid, false);
  assert.equal(result.reason, "query_string_present");
});

test("validateRuntimeManifestUri: fragments fail", () => {
  const result = validateRuntimeManifestUri({
    uri: `gs://${BUCKET}/${APPROVED_PREFIX}x.json#frag`,
    expectedBucket: BUCKET,
  });
  assert.equal(result.valid, false);
  assert.equal(result.reason, "fragment_present");
});

test("validateRuntimeManifestUri: ambiguous-normalization forms fail (percent-encoding, backslashes, non-allowlisted characters)", () => {
  const cases = [
    `gs://${BUCKET}/${APPROVED_PREFIX}%2e%2e%2fx.json`,
    `gs://${BUCKET}/${APPROVED_PREFIX}x\\y.json`,
    `gs://${BUCKET}/${APPROVED_PREFIX}x y.json`,
    `gs://${BUCKET}/${APPROVED_PREFIX}xÿ.json`,
  ];
  for (const uri of cases) {
    const result = validateRuntimeManifestUri({ uri, expectedBucket: BUCKET });
    assert.equal(result.valid, false, `expected rejection for: ${uri}`);
  }
});

test("validateRuntimeManifestUri: non-.json object names fail", () => {
  const result = validateRuntimeManifestUri({
    uri: `gs://${BUCKET}/${APPROVED_PREFIX}x.txt`,
    expectedBucket: BUCKET,
  });
  assert.equal(result.valid, false);
  assert.equal(result.reason, "not_json_object");
});

// ---------------------------------------------------------------------
// validateRuntimeManifestGeneration
// ---------------------------------------------------------------------

test("validateRuntimeManifestGeneration: a canonical positive integer succeeds", () => {
  const result = validateRuntimeManifestGeneration("1755882345123456");
  assert.equal(result.valid, true);
  assert.equal(result.generation, "1755882345123456");
});

test("validateRuntimeManifestGeneration: missing generation fails", () => {
  assert.equal(validateRuntimeManifestGeneration("").valid, false);
  assert.equal(validateRuntimeManifestGeneration(undefined).valid, false);
  assert.equal(validateRuntimeManifestGeneration("").reason, "missing_generation");
});

test("validateRuntimeManifestGeneration: zero fails", () => {
  const result = validateRuntimeManifestGeneration("0");
  assert.equal(result.valid, false);
  assert.equal(result.reason, "generation_zero");
});

test("validateRuntimeManifestGeneration: negative fails", () => {
  const result = validateRuntimeManifestGeneration("-5");
  assert.equal(result.valid, false);
  assert.equal(result.reason, "generation_negative");
});

test("validateRuntimeManifestGeneration: decimal fails", () => {
  const result = validateRuntimeManifestGeneration("123.5");
  assert.equal(result.valid, false);
  assert.equal(result.reason, "generation_decimal");
});

test("validateRuntimeManifestGeneration: non-numeric fails", () => {
  const result = validateRuntimeManifestGeneration("abc123");
  assert.equal(result.valid, false);
  assert.equal(result.reason, "generation_not_numeric");
});

test("validateRuntimeManifestGeneration: non-canonical (leading zero) fails", () => {
  const result = validateRuntimeManifestGeneration("0123");
  assert.equal(result.valid, false);
  assert.equal(result.reason, "generation_non_canonical");
});

// ---------------------------------------------------------------------
// writeManifestAtomic — real local filesystem I/O, deterministic
// (permission/existing-file-based failures, never timing-based), no
// GCS/network dependency, exercised directly against the real exported
// function.
// ---------------------------------------------------------------------

function mkTmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "write-manifest-atomic-"));
}

function tmpEntries(dir) {
  return fs.readdirSync(dir).filter((f) => f.includes(".tmp-"));
}

test("writeManifestAtomic: successful materialization produces the exact expected destination bytes", () => {
  const dir = mkTmpDir();
  const dest = path.join(dir, "manifest.json");
  const content = Buffer.from(JSON.stringify({ hello: "world" }));

  writeManifestAtomic(dest, content);

  assert.ok(fs.existsSync(dest));
  assert.deepEqual(fs.readFileSync(dest), content);
  const stat = fs.statSync(dest);
  assert.equal(stat.mode & 0o777, 0o600);
});

test("writeManifestAtomic: rename replaces an existing regular destination atomically", () => {
  const dir = mkTmpDir();
  const dest = path.join(dir, "manifest.json");
  fs.writeFileSync(dest, "OLD CONTENT", { mode: 0o600 });

  const newContent = Buffer.from("NEW CONTENT");
  writeManifestAtomic(dest, newContent);

  assert.deepEqual(fs.readFileSync(dest), newContent);
});

test("writeManifestAtomic: a write failure (deterministic — fs.writeSync mocked to throw) does not touch an existing destination file", (t) => {
  const dir = mkTmpDir();
  const dest = path.join(dir, "manifest.json");
  fs.writeFileSync(dest, "OLD CONTENT", { mode: 0o600 });

  // Deterministic, UID-independent failure: mocks the exact fs
  // primitive writeManifestAtomic uses to perform the real data write
  // (fs.writeSync(fd, buf) — see ci/materializeRuntimeManifest.js) to
  // throw a realistic write-failure error, regardless of the calling
  // process's UID/permissions. Directory-permission-bit tricks
  // (chmod 0o500) are not usable here: root (e.g. Cloud Build's
  // node:20.18.1-bookworm-slim step, which runs as root by default)
  // ignores permission bits entirely, so that approach silently
  // stopped failing under staging execution. t.mock.method's mock is
  // scoped to this TestContext and is automatically reset once this
  // test finishes (Node's test runner resets each test's own
  // MockTracker after that test completes), so no manual restore is
  // needed and no other test ever observes the mocked fs.writeSync.
  const writeError = Object.assign(new Error("EIO: i/o error, write"), { code: "EIO" });
  t.mock.method(fs, "writeSync", () => {
    throw writeError;
  });

  assert.throws(
    () => writeManifestAtomic(dest, Buffer.from("ATTACKER CONTENT")),
    /failed to write temporary file/,
    "a mocked fs.writeSync failure must propagate as writeManifestAtomic's own write-failure error, never be swallowed"
  );

  assert.equal(fs.readFileSync(dest, "utf8"), "OLD CONTENT", "the pre-existing destination must remain byte-for-byte unchanged");
  assert.equal(tmpEntries(dir).length, 0, "the temporary file must be removed after a failed write, never left behind");
  assert.deepEqual(fs.readdirSync(dir), ["manifest.json"], "no unrelated file may exist in the directory after a failed write");
});

test("writeManifestAtomic: rename failure (deterministic — destination path is an existing directory) cleans up the temporary file and leaves no partial destination", () => {
  const dir = mkTmpDir();
  const dest = path.join(dir, "manifest.json");
  // A regular file cannot be renamed onto an existing directory —
  // deterministic EISDIR/ENOTDIR-class failure, not a race.
  fs.mkdirSync(dest);

  assert.throws(() => writeManifestAtomic(dest, Buffer.from("content")));

  assert.equal(tmpEntries(dir).length, 0, "no temp file should remain after a rename failure");
  assert.ok(fs.statSync(dest).isDirectory(), "the pre-existing directory at dest must be untouched");
});

test("writeManifestAtomic: no temporary file remains in the directory after a successful materialization", () => {
  const dir = mkTmpDir();
  const dest = path.join(dir, "manifest.json");

  writeManifestAtomic(dest, Buffer.from("content"));

  assert.equal(tmpEntries(dir).length, 0);
  assert.deepEqual(fs.readdirSync(dir), ["manifest.json"]);
});

test("writeManifestAtomic: a pre-existing symlink at the exact candidate temporary path is never followed — the call fails closed instead of writing through it", () => {
  const dir = mkTmpDir();
  const dest = path.join(dir, "manifest.json");
  const outsideTarget = path.join(dir, "outside-target.json");
  fs.writeFileSync(outsideTarget, "PRE-EXISTING OUTSIDE CONTENT");

  const suffix = "deterministic-test-suffix";
  const predictedTmpPath = path.join(dir, `.manifest.json.tmp-${suffix}`);
  fs.symlinkSync(outsideTarget, predictedTmpPath);

  assert.throws(
    () => writeManifestAtomic(dest, Buffer.from("attacker-controlled content"), { randomSuffix: suffix }),
    /failed to create temporary file/
  );

  // The symlink's target must be completely untouched — O_EXCL means
  // the open() call itself fails without ever writing through the
  // symlink.
  assert.equal(fs.readFileSync(outsideTarget, "utf8"), "PRE-EXISTING OUTSIDE CONTENT");
  assert.ok(!fs.existsSync(dest), "dest must not have been created via the symlinked temp path");
});

test("writeManifestAtomic: a same-name temp-path collision (two calls forced to use the identical suffix) is safely rejected, never silently overwritten", () => {
  const dir = mkTmpDir();
  const dest1 = path.join(dir, "manifest1.json");
  const dest2 = path.join(dir, "manifest2.json");
  const suffix = "same-suffix-forced-collision";

  // First call succeeds and cleans up its own temp file normally.
  writeManifestAtomic(dest1, Buffer.from("first"), { randomSuffix: suffix });
  assert.equal(fs.readFileSync(dest1, "utf8"), "first");

  // Manually re-create a leftover at the exact same temp path a second
  // call with the same forced suffix would target, simulating a
  // collision window between two concurrent invocations.
  const collidingTmpPath = path.join(dir, `.manifest2.json.tmp-${suffix}`);
  fs.writeFileSync(collidingTmpPath, "IN-PROGRESS FROM ANOTHER CALL", { mode: 0o600 });

  assert.throws(
    () => writeManifestAtomic(dest2, Buffer.from("second"), { randomSuffix: suffix }),
    /failed to create temporary file/
  );

  // The colliding in-progress file must be untouched — never
  // silently clobbered — and dest2 must never have been created.
  assert.equal(fs.readFileSync(collidingTmpPath, "utf8"), "IN-PROGRESS FROM ANOTHER CALL");
  assert.ok(!fs.existsSync(dest2));
});

test("writeManifestAtomic: default random suffix produces a different temp-path each call (real usage avoids collisions rather than relying on rejection alone)", () => {
  const dir = mkTmpDir();
  const dest1 = path.join(dir, "manifest1.json");
  const dest2 = path.join(dir, "manifest2.json");

  // No randomSuffix override — exercises the real crypto.randomBytes
  // default path.
  writeManifestAtomic(dest1, Buffer.from("first"));
  writeManifestAtomic(dest2, Buffer.from("second"));

  assert.equal(fs.readFileSync(dest1, "utf8"), "first");
  assert.equal(fs.readFileSync(dest2, "utf8"), "second");
  assert.equal(tmpEntries(dir).length, 0);
});

// ---------------------------------------------------------------------
// Static / structural proof — the CLI wrapper's real source, not a
// hand-copied duplicate.
// ---------------------------------------------------------------------

test("CLI wrapper: download addresses the GCS File handle with the validated generation (generation-pinned, not \"latest\")", () => {
  const text = scriptText("ci/materializeRuntimeManifest.js");
  assert.ok(
    /\.file\(uriResult\.objectPath,\s*\{\s*generation:\s*generationResult\.generation\s*\}\)/.test(text),
    "the download must address the file with an explicit generation option"
  );
});

test("CLI wrapper: reuses fixtureManifest.js's validateManifestShape — no separate, weaker schema check exists", () => {
  const text = scriptText("ci/materializeRuntimeManifest.js");
  assert.ok(/require\("\.\/fixtureManifest"\)/.test(text));
  assert.ok(/validateManifestShape\(parsed\)/.test(text));
});

test("CLI wrapper: never logs the downloaded manifest's own parsed contents, only pass/fail summaries and its own provisioning coordinates", () => {
  const text = scriptText("ci/materializeRuntimeManifest.js");
  const consoleLogCalls = text.match(/console\.log\([^;]*\)/g) || [];
  for (const call of consoleLogCalls) {
    assert.ok(!/parsed/.test(call), `console.log must never reference the parsed manifest object: ${call}`);
    assert.ok(!/\.fixtures\b/.test(call), `console.log must never reference manifest fixture entries: ${call}`);
  }
});

test("CLI wrapper: no production project/bucket literal is introduced anywhere in the new module", () => {
  const text = scriptText("ci/materializeRuntimeManifest.js");
  assert.ok(!/barkymatches-new/.test(text));
  assert.ok(!/petsupo-platform-staging/.test(text));
});

test("CLI wrapper: the destination write goes through writeManifestAtomic, never a direct fs.writeFileSync to args.out", () => {
  const text = scriptText("ci/materializeRuntimeManifest.js");
  assert.ok(/writeManifestAtomic\(args\.out, buf\)/.test(text), "the CLI wrapper must call writeManifestAtomic for the destination write");
  assert.ok(
    !/fs\.writeFileSync\(args\.out/.test(text),
    "the CLI wrapper must not write directly to args.out — only writeManifestAtomic's internal temp-then-rename path may touch it"
  );
});

// ---------------------------------------------------------------------
// verify-fixtures.sh — no fallback to the committed sentinel manifest.
// ---------------------------------------------------------------------

test("verify-fixtures.sh: real pipeline run reads RUNTIME_FIXTURE_MANIFEST_PATH, never the committed ci/fixtureManifest.json, as --manifest=", () => {
  const text = scriptText("ci/verify-fixtures.sh");
  assert.ok(
    /--manifest="\$RUNTIME_FIXTURE_MANIFEST_PATH"/.test(text),
    "verify-fixtures.sh must pass the materialized runtime-manifest path to fixtureManifest.js"
  );
  assert.ok(
    !/--manifest=ci\/fixtureManifest\.json/.test(text),
    "verify-fixtures.sh must not hardcode the committed environment-neutral manifest as its --manifest= argument"
  );
});

test("verify-fixtures.sh: RUNTIME_FIXTURE_MANIFEST_PATH is a required, fail-closed input", () => {
  const text = scriptText("ci/verify-fixtures.sh");
  assert.ok(/: "\$\{RUNTIME_FIXTURE_MANIFEST_PATH:\?RUNTIME_FIXTURE_MANIFEST_PATH is required\}"/.test(text));
});

// ---------------------------------------------------------------------
// Committed fixtureManifest.json remains untouched / environment-
// neutral — still fails closed on its own sentinels.
// ---------------------------------------------------------------------

test("committed ci/fixtureManifest.json remains environment-neutral: still fails validateManifestShape via its own PENDING_PROVISIONING sentinels", () => {
  const manifest = JSON.parse(scriptText("ci/fixtureManifest.json"));
  const result = validateManifestShape(manifest);
  assert.equal(result.valid, false);
  assert.equal(result.reason, "fixture_not_provisioned");
});

test("committed ci/fixtureManifest.json still declares exactly the three required fixtures, unmodified by this correction", () => {
  const manifest = JSON.parse(scriptText("ci/fixtureManifest.json"));
  const ids = manifest.fixtures.map((f) => f.id).sort();
  assert.deepEqual(ids, ["benign-text", "eicar-standard", "encrypted-pdf"]);
});

// Dependency-graph, substitution, and fixed-output-path proof for
// cloudbuild.signature-refresh.yaml lives in ci/pipelineStatic.test.js
// (the established, dedicated home for cross-cutting pipeline-YAML
// structure tests — see that file's own top-of-file comment on why it
// deliberately avoids adding a YAML-parser library dependency).
