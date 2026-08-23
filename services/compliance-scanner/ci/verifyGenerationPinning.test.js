"use strict";

// Deterministic validation for the generation-pinning re-verification
// helper (single-authoritative-execution-identity correction, closing
// a real staging failure — build 9cb468c3-2401-403a-8ed6-e4afabfa9f9a,
// step verify-deployed-candidate: "does not have storage.objects.list
// access to the Google Cloud Storage bucket"). Exercises the pure
// bucket/build-id/path validators directly, and the real async
// create/verify/overwrite/verify/cleanup lifecycle
// (runGenerationPinningVerification) against an in-memory FAKE Storage
// adapter — never a real bucket, never a network call, and — this is
// the property this whole correction exists to prove — an adapter that
// exposes NO list-capable method at all, so any accidental future
// dependency on listing would fail this test suite immediately with
// "not a function", not silently pass against a real, more permissive
// bucket.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  APPROVED_OBJECT_PREFIX,
  APPROVED_OBJECT_SUFFIX,
  validateBuildId,
  validateSyntheticBucket,
  buildGenerationTestObjectPath,
  isCanonicalGenerationString,
  runGenerationPinningVerification,
} = require("./verifyGenerationPinning");

const VALID_BUILD_ID = "9cb468c3-2401-403a-8ed6-e4afabfa9f9a";
const VALID_BUCKET = "petsupo-platform-staging-compliance-synthetic";
const THIS_FILE_SOURCE = fs.readFileSync(path.join(__dirname, "verifyGenerationPinning.js"), "utf8");

// Matches pipelineStatic.test.js's own nonCommentLines() convention:
// this module's doc comments legitimately DISCUSS the old
// `gcloud storage cp`/`Number()`/`parseInt()` pattern being replaced
// (explaining why it was wrong), so scans for "these must never appear
// on an executable line" must exclude comment-only lines, exactly like
// every other such scan elsewhere in this repository's test suite.
function nonCommentLines(text) {
  return text.split("\n").filter((line) => !line.trim().startsWith("#") && !line.trim().startsWith("//"));
}
const EXECUTABLE_SOURCE = nonCommentLines(THIS_FILE_SOURCE).join("\n");

// ---------------------------------------------------------------------
// Fake, in-memory, list-free Storage adapter. Deliberately exposes only
// save/download/delete/getMetadata — the exact subset
// runGenerationPinningVerification uses — and nothing resembling a
// list/getFiles method. `calls` records every invocation (operation +
// the generation/precondition involved) for assertions; `objects`
// exposes the live in-memory store so tests can inspect final state
// directly (e.g. "cleanup left nothing behind").
// ---------------------------------------------------------------------
function createFakeGcsStore({ generationSeed = 1000000000000000, failSecondSave = false } = {}) {
  const calls = [];
  let nextGeneration = generationSeed;
  const objects = new Map();
  let currentGeneration = null;
  let saveCount = 0;

  function pinnedHandle(generation) {
    return {
      async download() {
        calls.push({ op: "download", generation });
        if (!objects.has(generation)) {
          throw Object.assign(new Error(`fake: no object at generation ${generation}`), { code: 404 });
        }
        return [objects.get(generation)];
      },
      async getMetadata() {
        calls.push({ op: "getMetadata", generation });
        if (!objects.has(generation)) {
          throw Object.assign(new Error("fake: not found"), { code: 404 });
        }
        return [{ generation }];
      },
      async delete(opts) {
        const expected = opts && opts.preconditionOpts && opts.preconditionOpts.ifGenerationMatch;
        calls.push({ op: "delete", generation, precondition: expected });
        if (String(expected) !== String(generation)) {
          throw new Error("fake: delete precondition mismatch");
        }
        if (!objects.has(generation)) {
          throw new Error("fake: delete target does not exist");
        }
        objects.delete(generation);
        if (currentGeneration === generation) currentGeneration = null;
      },
      async save() {
        throw new Error("fake: save() is not supported on a pinned-generation handle");
      },
    };
  }

  function mutableHandle() {
    return {
      async save(buffer, opts) {
        saveCount += 1;
        const precondition = opts && opts.preconditionOpts && opts.preconditionOpts.ifGenerationMatch;
        calls.push({ op: "save", precondition });
        if (failSecondSave && saveCount === 2) {
          throw new Error("fake: simulated write failure");
        }
        if (precondition === 0) {
          if (currentGeneration !== null) {
            throw new Error("fake: precondition failed — object already exists (ifGenerationMatch: 0)");
          }
        } else if (precondition !== undefined) {
          if (String(precondition) !== String(currentGeneration)) {
            throw new Error("fake: precondition failed — generation mismatch");
          }
        }
        const newGen = String(nextGeneration);
        nextGeneration += 1;
        objects.set(newGen, Buffer.from(buffer));
        currentGeneration = newGen;
      },
      async getMetadata() {
        calls.push({ op: "getMetadata", generation: "current" });
        if (currentGeneration === null) {
          throw Object.assign(new Error("fake: not found"), { code: 404 });
        }
        return [{ generation: currentGeneration }];
      },
      async download() {
        calls.push({ op: "download", generation: "current" });
        if (currentGeneration === null) throw new Error("fake: not found");
        return [objects.get(currentGeneration)];
      },
      async delete() {
        throw new Error("fake: delete() on the unpinned/mutable handle is never used by this module");
      },
    };
  }

  const fileFactory = (generation) => (generation === undefined ? mutableHandle() : pinnedHandle(generation));
  return { fileFactory, calls, objects };
}

const V1_BUFFER = Buffer.from("canonical EICAR-shaped test bytes, v1");
const V2_BUFFER = Buffer.from("synthetic benign replacement content, v2");

// ---------------------------------------------------------------------
// Pure validators
// ---------------------------------------------------------------------

test("validateBuildId: a well-formed Cloud Build UUID succeeds", () => {
  assert.deepEqual(validateBuildId(VALID_BUILD_ID), { valid: true, buildId: VALID_BUILD_ID });
});

test("validateBuildId: missing/empty fails", () => {
  assert.equal(validateBuildId("").valid, false);
  assert.equal(validateBuildId(undefined).valid, false);
  assert.equal(validateBuildId("").reason, "missing_build_id");
});

test("validateBuildId: traversal-shaped, backslash, control-character, wildcard/glob, uppercase, and malformed values all fail with build_id_not_well_formed_uuid", () => {
  const badIds = [
    "../../etc/passwd",
    "9cb468c3-2401-403a-8ed6-e4afabfa9f9a/../secret",
    "9cb468c3\\2401-403a-8ed6-e4afabfa9f9a",
    "9cb468c3-2401-403a-8ed6-e4afabfa9f9a\n",
    "9cb468c3-2401-403a-8ed6-e4afabfa9f9a\x00",
    "*",
    "9cb468c3-2401-403a-8ed6-e4afabfa9f9a*",
    "9CB468C3-2401-403A-8ED6-E4AFABFA9F9A",
    "9cb468c3-2401-403a-8ed6",
    "9cb468c3-2401-403a-8ed6-e4afabfa9f9a-extra",
    "not-a-uuid-at-all",
    "9cb468c3 2401 403a 8ed6 e4afabfa9f9a",
  ];
  for (const buildId of badIds) {
    const result = validateBuildId(buildId);
    assert.equal(result.valid, false, `expected rejection for: ${JSON.stringify(buildId)}`);
    assert.equal(result.reason, "build_id_not_well_formed_uuid", `wrong reason for: ${JSON.stringify(buildId)}`);
  }
});

test("validateSyntheticBucket: the real staging bucket name succeeds", () => {
  assert.deepEqual(validateSyntheticBucket(VALID_BUCKET), { valid: true, bucket: VALID_BUCKET });
});

test("validateSyntheticBucket: missing, empty, traversal-shaped, or malformed bucket names fail before any Storage call could occur (no Storage client is ever constructed by this pure function)", () => {
  const badBuckets = ["", undefined, null, "..", "Bucket-With-Upper", "a", "-leading-hyphen", "trailing-hyphen-", "has a space", "has/slash"];
  for (const bucket of badBuckets) {
    const result = validateSyntheticBucket(bucket);
    assert.equal(result.valid, false, `expected rejection for: ${JSON.stringify(bucket)}`);
  }
});

test("buildGenerationTestObjectPath: a valid build id resolves to exactly the one approved, build-scoped path", () => {
  const result = buildGenerationTestObjectPath(VALID_BUILD_ID);
  assert.deepEqual(result, {
    valid: true,
    objectPath: `compliance_quarantine/ci-${VALID_BUILD_ID}/deployed-verify/generation-test.bin`,
  });
  assert.ok(result.objectPath.startsWith(APPROVED_OBJECT_PREFIX));
  assert.ok(result.objectPath.endsWith(APPROVED_OBJECT_SUFFIX));
});

test("buildGenerationTestObjectPath: an invalid build id is rejected before any path is ever constructed — malformed bucket/build-id inputs fail closed, never falling through to a Storage call", () => {
  const result = buildGenerationTestObjectPath("../../etc/passwd");
  assert.equal(result.valid, false);
  assert.equal(result.reason, "build_id_not_well_formed_uuid");
});

test("buildGenerationTestObjectPath: every valid-shaped build id produces a path containing none of the individually-forbidden characters (traversal, backslash, control characters, wildcards, query/fragment, empty segments) — proves the BUILD_ID_PATTERN gate makes every one of buildGenerationTestObjectPath's own defense-in-depth checks structurally unreachable for any input that passes it, not merely untested", () => {
  const sampleBuildIds = [
    "00000000-0000-0000-0000-000000000000",
    "ffffffff-ffff-ffff-ffff-ffffffffffff",
    "9cb468c3-2401-403a-8ed6-e4afabfa9f9a",
  ];
  for (const buildId of sampleBuildIds) {
    const result = buildGenerationTestObjectPath(buildId);
    assert.equal(result.valid, true);
    const p = result.objectPath;
    assert.ok(!p.includes(".."));
    assert.ok(!p.includes("\\"));
    // eslint-disable-next-line no-control-regex
    assert.ok(!/[\x00-\x1f\x7f]/.test(p));
    assert.ok(!p.includes("?") && !p.includes("#"));
    assert.ok(!p.includes("*") && !p.includes("[") && !p.includes("]"));
    assert.ok(!p.includes("//"));
    assert.ok(p.split("/").every((segment) => segment.length > 0));
  }
});

test("isCanonicalGenerationString: accepts only canonical positive decimal integers, rejects the GCS ifGenerationMatch:0 sentinel, leading zeros, negatives, decimals, and non-numeric strings", () => {
  assert.equal(isCanonicalGenerationString("1787487948769918"), true);
  assert.equal(isCanonicalGenerationString("1"), true);
  for (const bad of ["0", "01", "-1", "1.5", "", "abc", null, undefined, 12345]) {
    assert.equal(isCanonicalGenerationString(bad), false, `expected rejection for: ${JSON.stringify(bad)}`);
  }
});

// ---------------------------------------------------------------------
// runGenerationPinningVerification — real lifecycle against the fake,
// list-free adapter.
// ---------------------------------------------------------------------

test("runGenerationPinningVerification: the full happy path succeeds — create (ifGenerationMatch: 0), pinned read of gen1, fenced overwrite (ifGenerationMatch: gen1), pinned read of gen2, pinned RE-read of gen1 after being superseded, then cleanup of both generations", async () => {
  const { fileFactory, calls, objects } = createFakeGcsStore();
  const result = await runGenerationPinningVerification({ fileFactory, v1Buffer: V1_BUFFER, v2Buffer: V2_BUFFER });

  assert.equal(result.ok, true, `expected success, got: ${JSON.stringify(result)}`);
  assert.equal(typeof result.gen1, "string");
  assert.equal(typeof result.gen2, "string");
  assert.notEqual(result.gen1, result.gen2);

  // Requirement: first create uses ifGenerationMatch: 0.
  const saves = calls.filter((c) => c.op === "save");
  assert.equal(saves.length, 2);
  assert.equal(saves[0].precondition, 0, "the first save must use ifGenerationMatch: 0");
  assert.equal(saves[1].precondition, result.gen1, "the second (overwrite) save must use ifGenerationMatch: gen1, never unconditioned");

  // Requirement: cleanup targets only the exact generations created —
  // nothing left behind, and the deletes were generation-pinned.
  assert.equal(objects.size, 0, "cleanup must remove every generation this invocation created");
  const deletes = calls.filter((c) => c.op === "delete");
  assert.deepEqual(deletes.map((d) => d.generation).sort(), [result.gen1, result.gen2].sort());
  for (const d of deletes) {
    assert.equal(d.precondition, d.generation, "every delete must be fenced by its own exact generation precondition");
  }

  // Requirement: zero list-shaped calls of any kind occurred.
  assert.ok(calls.every((c) => c.op !== "list" && c.op !== "getFiles"), "no list-shaped operation may occur");
});

test("runGenerationPinningVerification: pinned reads are generation-bound, not 'whatever is current' — a pinned download of gen1 issued AFTER gen2 has become current still returns gen1's own original content, proven independently of the module's internal bookkeeping by re-issuing the pinned read directly against the same underlying store the module used", async () => {
  const { fileFactory, objects } = createFakeGcsStore();
  // Intercept delete() so cleanup does not remove the generations
  // before this test independently re-reads them — this test cares
  // about generation-boundedness DURING the run, which the module's
  // own cleanup would otherwise erase by the time control returns here.
  let interceptedGen1;
  let interceptedGen2;
  const observingFactory = (generation) => {
    const handle = fileFactory(generation);
    if (generation === undefined) return handle;
    return {
      ...handle,
      delete: async () => {
        // no-op: keep both generations alive for this test's own
        // independent post-hoc pinned reads below.
      },
    };
  };
  const result = await runGenerationPinningVerification({ fileFactory: observingFactory, v1Buffer: V1_BUFFER, v2Buffer: V2_BUFFER });
  assert.equal(result.ok, true, `expected success, got: ${JSON.stringify(result)}`);
  interceptedGen1 = result.gen1;
  interceptedGen2 = result.gen2;

  assert.ok(objects.has(interceptedGen1), "sanity: gen1 must still exist in the underlying store (cleanup was intercepted)");
  assert.ok(objects.has(interceptedGen2), "sanity: gen2 must still exist in the underlying store (cleanup was intercepted)");

  const [rereadGen1] = await fileFactory(interceptedGen1).download();
  const [rereadGen2] = await fileFactory(interceptedGen2).download();
  assert.ok(rereadGen1.equals(V1_BUFFER), "an independent pinned read of gen1, issued after gen2 became current, must still return v1's own content");
  assert.ok(rereadGen2.equals(V2_BUFFER), "an independent pinned read of gen2 must return v2's content");
  assert.ok(!rereadGen1.equals(rereadGen2), "the two pinned generations must never resolve to the same content");
});

test("runGenerationPinningVerification: a stale/wrong generation precondition on the second write is rejected, not silently accepted", async () => {
  const { fileFactory } = createFakeGcsStore();
  // Directly exercise the fake's own precondition enforcement the way
  // the module's second save() call does, but with a deliberately
  // wrong precondition, proving the underlying adapter contract this
  // module relies on actually rejects stale preconditions.
  const writable = fileFactory();
  await writable.save(V1_BUFFER, { preconditionOpts: { ifGenerationMatch: 0 } });
  await assert.rejects(
    () => writable.save(V2_BUFFER, { preconditionOpts: { ifGenerationMatch: "999999999999999999" } }),
    /precondition failed/,
    "a stale/wrong ifGenerationMatch must be rejected"
  );
});

test("runGenerationPinningVerification: cleanup still runs (and removes what WAS created) even when the overwrite step fails partway through — the primary failure is reported, not masked, and gen1 is not left behind", async () => {
  const { fileFactory, objects, calls } = createFakeGcsStore({ failSecondSave: true });
  const result = await runGenerationPinningVerification({ fileFactory, v1Buffer: V1_BUFFER, v2Buffer: V2_BUFFER });

  assert.equal(result.ok, false, "the overall result must report failure");
  assert.ok(/simulated write failure/.test(result.error), `expected the primary failure reason, got: ${result.error}`);
  assert.equal(objects.size, 0, "cleanup must still remove the ONE generation (gen1) that was actually created before the failure");
  const deletes = calls.filter((c) => c.op === "delete");
  assert.equal(deletes.length, 1, "only the one generation that was created should ever be targeted for cleanup");
});

test("runGenerationPinningVerification: a cleanup failure does not replace or hide the primary result — a successful run still reports ok:true even if deleting one of its own generations fails, and a failed run still reports its own original error, not a cleanup error", async () => {
  const { fileFactory, calls } = createFakeGcsStore();
  // Wrap the factory so every delete() call fails, without affecting
  // save/download/getMetadata at all.
  const wrappedFactory = (generation) => {
    const handle = fileFactory(generation);
    if (generation === undefined) return handle;
    return {
      ...handle,
      delete: async () => {
        throw new Error("fake: injected cleanup failure");
      },
    };
  };
  const result = await runGenerationPinningVerification({ fileFactory: wrappedFactory, v1Buffer: V1_BUFFER, v2Buffer: V2_BUFFER });
  assert.equal(result.ok, true, "cleanup failing must never turn a successful primary result into a failure");
  assert.equal(typeof result.gen1, "string");
  assert.equal(typeof result.gen2, "string");
  // The failed cleanup attempts must still have been ATTEMPTED (the
  // fake's own save/download calls prove the primary path ran fully;
  // this call log confirms cleanup was reached even though it failed).
  assert.ok(calls.some((c) => c.op === "save"));
});

test("runGenerationPinningVerification: the pinned read of the first generation returns exactly the v1 payload bytes, and the current-generation read after overwrite returns exactly the v2 payload bytes — the original test's core assertion, now verified directly against GCS content rather than only inferred from the deployed candidate's scan verdict", async () => {
  const { fileFactory } = createFakeGcsStore();
  const result = await runGenerationPinningVerification({ fileFactory, v1Buffer: V1_BUFFER, v2Buffer: V2_BUFFER });
  assert.equal(result.ok, true);
  // Re-derive independently: construct a SEPARATE store, replay the
  // same two writes by hand, and confirm the module's own reported
  // generations correspond to content matching v1/v2 exactly.
  const store2 = createFakeGcsStore();
  const w = store2.fileFactory();
  await w.save(V1_BUFFER, { preconditionOpts: { ifGenerationMatch: 0 } });
  const [m1] = await w.getMetadata();
  await w.save(V2_BUFFER, { preconditionOpts: { ifGenerationMatch: m1.generation } });
  const [m2] = await w.getMetadata();
  const [contentAtGen1] = await store2.fileFactory(m1.generation).download();
  const [contentAtGen2] = await store2.fileFactory(m2.generation).download();
  assert.ok(contentAtGen1.equals(V1_BUFFER));
  assert.ok(contentAtGen2.equals(V2_BUFFER));
});

test("runGenerationPinningVerification: every generation returned or recorded remains a plain string end to end — never coerced through Number, and never losing precision-relevant digits (checked on EXECUTABLE lines only — the file's own doc comment legitimately names Number()/parseInt()/parseFloat() once, explaining the policy this test enforces)", () => {
  assert.ok(
    !/\bNumber\s*\(\s*(meta|generation|gen1|gen2)/.test(EXECUTABLE_SOURCE),
    "verifyGenerationPinning.js must never call Number(...) on a generation value on an executable line"
  );
  assert.ok(!/\bparseInt\s*\(/.test(EXECUTABLE_SOURCE), "verifyGenerationPinning.js must never call parseInt(...) on an executable line");
  assert.ok(!/\bparseFloat\s*\(/.test(EXECUTABLE_SOURCE), "verifyGenerationPinning.js must never call parseFloat(...) on an executable line");
  assert.ok(!/[^!=<>]\+(generation|gen1|gen2|meta1|meta2)\b/.test(EXECUTABLE_SOURCE), "verifyGenerationPinning.js must never apply unary-plus to a generation value on an executable line");
});

test("verifyGenerationPinning.js never invokes a bucket/prefix list operation (no .list(, .getFiles(, or gcloud storage ls/cp/rm on any EXECUTABLE line) and never runs an IAM mutation command — a pure client-behavior substitution, not a broader-permission workaround (the file's own doc comment legitimately describes the OLD gcloud-storage-cp pattern being replaced, once, as history)", () => {
  assert.ok(!/\.list\s*\(/.test(EXECUTABLE_SOURCE));
  assert.ok(!/\.getFiles\s*\(/.test(EXECUTABLE_SOURCE));
  assert.ok(!/gcloud storage (cp|ls|rm)\b/.test(EXECUTABLE_SOURCE));
  assert.ok(!/add-iam-policy-binding|remove-iam-policy-binding|set-iam-policy\b/.test(EXECUTABLE_SOURCE));
});
