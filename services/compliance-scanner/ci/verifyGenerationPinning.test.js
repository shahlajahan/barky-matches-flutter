"use strict";

// Deterministic validation for the two-phase generation-pinning
// re-verification helper (sequencing correction, closing a real
// staging failure — build 8b35480c-b19f-4aad-a0dd-9779a42d8b49, step
// verify-deployed-candidate: "generation-pinned read of old (EICAR)
// generation failed ... gcs_download_failed"). Exercises the pure
// validators directly, and the real async prepare/cleanup lifecycles
// against an in-memory FAKE Storage adapter (never a real bucket,
// never a network call, and — the property this whole correction
// exists to prove — an adapter with NO list-capable method at all) and
// a FAKE receipt store (never real disk I/O, except in the two tests
// that specifically need to prove real atomic-write/pre-existing-
// receipt/file-mode behavior, which use an isolated os.tmpdir()
// directory, never the real /workspace).

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const {
  APPROVED_OBJECT_PREFIX,
  APPROVED_OBJECT_SUFFIX,
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
} = require("./verifyGenerationPinning");

const VALID_BUILD_ID = "8b35480c-b19f-4aad-a0dd-9779a42d8b49";
const VALID_PROJECT = "petsupo-platform-staging";
const VALID_BUCKET = "petsupo-platform-staging-compliance-synthetic";
const THIS_FILE_SOURCE = fs.readFileSync(path.join(__dirname, "verifyGenerationPinning.js"), "utf8");

function nonCommentLines(text) {
  return text.split("\n").filter((line) => !line.trim().startsWith("#") && !line.trim().startsWith("//"));
}
const EXECUTABLE_SOURCE = nonCommentLines(THIS_FILE_SOURCE).join("\n");

const V1_BUFFER = Buffer.from("canonical EICAR-shaped test bytes, v1");
const V2_BUFFER = Buffer.from("synthetic benign replacement content, v2");

function expectedContext(buildId = VALID_BUILD_ID) {
  const objectPath = buildGenerationTestObjectPath(buildId).objectPath;
  return { project: VALID_PROJECT, bucket: VALID_BUCKET, buildId, objectPath };
}

// ---------------------------------------------------------------------
// Fake, in-memory, list-free Storage adapter — identical shape to the
// prior version of this correction's own fake (save/download/delete/
// getMetadata only, nothing list-shaped).
// ---------------------------------------------------------------------
function createFakeGcsStore({ generationSeed = 1000000000000000, failSecondSave = false, failDeleteGenerations = new Set() } = {}) {
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
        if (failDeleteGenerations.has(generation)) {
          throw new Error(`fake: injected delete failure for generation ${generation}`);
        }
        if (!objects.has(generation)) {
          throw Object.assign(new Error(`fake: no such object (generation ${generation} already absent)`), { code: 404 });
        }
        if (String(expected) !== String(generation)) {
          throw new Error("fake: delete precondition mismatch");
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
        if (currentGeneration === null) throw Object.assign(new Error("fake: not found"), { code: 404 });
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

// ---------------------------------------------------------------------
// Fake, in-memory receipt store (no real disk I/O).
// ---------------------------------------------------------------------
function createFakeReceiptStore() {
  const store = new Map();
  return {
    writeReceipt(receiptPath, receiptData) {
      if (store.has(receiptPath)) {
        throw new Error("fake: refusing to write receipt: a file already exists at this path (pre-existing/untrusted)");
      }
      store.set(receiptPath, JSON.parse(JSON.stringify(receiptData)));
    },
    readReceipt(receiptPath) {
      return store.has(receiptPath) ? store.get(receiptPath) : null;
    },
    removeReceipt(receiptPath) {
      if (!store.has(receiptPath)) throw new Error("fake: cannot remove a receipt that does not exist");
      store.delete(receiptPath);
    },
    raw: store,
  };
}

// ---------------------------------------------------------------------
// Pure validators
// ---------------------------------------------------------------------

test("validateBuildId / validateSyntheticBucket / buildGenerationTestObjectPath: unchanged behavior from the prior version of this correction", () => {
  assert.deepEqual(validateBuildId(VALID_BUILD_ID), { valid: true, buildId: VALID_BUILD_ID });
  assert.equal(validateBuildId("../../etc/passwd").valid, false);
  assert.deepEqual(validateSyntheticBucket(VALID_BUCKET), { valid: true, bucket: VALID_BUCKET });
  assert.equal(validateSyntheticBucket("Bucket-With-Upper").valid, false);
  const pathResult = buildGenerationTestObjectPath(VALID_BUILD_ID);
  assert.deepEqual(pathResult, { valid: true, objectPath: `${APPROVED_OBJECT_PREFIX}${VALID_BUILD_ID}${APPROVED_OBJECT_SUFFIX}` });
});

test("buildReceiptPath: a valid build id resolves to exactly one receipt path under the fixed RECEIPT_DIR, named <build-id>.json", () => {
  const result = buildReceiptPath(VALID_BUILD_ID);
  assert.equal(result.valid, true);
  assert.equal(result.receiptPath, `/workspace/.generation-pinning-receipts/${VALID_BUILD_ID}.json`);
});

test("buildReceiptPath: an invalid build id is rejected before any path is constructed", () => {
  const result = buildReceiptPath("../../etc/passwd");
  assert.equal(result.valid, false);
  assert.equal(result.reason, "build_id_not_well_formed_uuid");
});

test("isCanonicalGenerationString: unchanged behavior", () => {
  assert.equal(isCanonicalGenerationString("1787487948769918"), true);
  for (const bad of ["0", "01", "-1", "1.5", "", "abc", null, undefined, 12345]) {
    assert.equal(isCanonicalGenerationString(bad), false);
  }
});

// ---------------------------------------------------------------------
// validateReceipt — malformed/forged receipt rejection, pure (no I/O,
// no Storage call of any kind — these are plain function calls against
// a fabricated in-memory object).
// ---------------------------------------------------------------------

function validReceiptData(overrides = {}) {
  const ctx = expectedContext();
  return {
    schemaVersion: RECEIPT_SCHEMA_VERSION,
    project: ctx.project,
    bucket: ctx.bucket,
    buildId: ctx.buildId,
    objectPath: ctx.objectPath,
    gen1: "1787489814789338",
    gen2: "1787489814946913",
    ...overrides,
  };
}

test("validateReceipt: a well-formed, matching receipt is accepted", () => {
  const result = validateReceipt(validReceiptData(), expectedContext());
  assert.equal(result.valid, true);
});

test("validateReceipt: malformed/forged/foreign receipts are all rejected — wrong schema version, wrong project/bucket/buildId, mismatched (never trusted) objectPath, non-canonical or equal generations, and non-object payloads", () => {
  const expected = expectedContext();
  const cases = [
    [null, "receipt_not_an_object"],
    ["a string", "receipt_not_an_object"],
    [[], "receipt_not_an_object"],
    [validReceiptData({ schemaVersion: 999 }), "receipt_schema_version_mismatch"],
    [validReceiptData({ project: "some-other-project" }), "receipt_project_mismatch"],
    [validReceiptData({ bucket: "some-other-bucket" }), "receipt_bucket_mismatch"],
    [validReceiptData({ buildId: "00000000-0000-0000-0000-000000000000" }), "receipt_build_id_mismatch"],
    [validReceiptData({ objectPath: "compliance_quarantine/ci-forged/deployed-verify/generation-test.bin" }), "receipt_object_path_mismatch"],
    [validReceiptData({ gen1: "0" }), "receipt_gen1_not_canonical"],
    [validReceiptData({ gen1: "not-a-number" }), "receipt_gen1_not_canonical"],
    [validReceiptData({ gen2: "01" }), "receipt_gen2_not_canonical"],
    [validReceiptData({ gen1: "111", gen2: "111" }), "receipt_gen1_equals_gen2"],
  ];
  for (const [receipt, expectedReason] of cases) {
    const result = validateReceipt(receipt, expected);
    assert.equal(result.valid, false, `expected rejection for: ${JSON.stringify(receipt)}`);
    assert.equal(result.reason, expectedReason, `wrong reason for: ${JSON.stringify(receipt)}`);
  }
});

// ---------------------------------------------------------------------
// prepareGenerationPinning
// ---------------------------------------------------------------------

test("prepareGenerationPinning: happy path succeeds, writes the receipt, and leaves BOTH generations present in the store — no cleanup on success (ownership transfers to the caller)", async () => {
  const { fileFactory, calls, objects } = createFakeGcsStore();
  const receipts = createFakeReceiptStore();
  const ctx = expectedContext();
  const receiptPath = buildReceiptPath(VALID_BUILD_ID).receiptPath;

  const result = await prepareGenerationPinning({
    fileFactory,
    v1Buffer: V1_BUFFER,
    v2Buffer: V2_BUFFER,
    receiptPath,
    receiptContext: ctx,
    writeReceipt: receipts.writeReceipt,
  });

  assert.equal(result.ok, true, `expected success, got: ${JSON.stringify(result)}`);
  assert.equal(typeof result.gen1, "string");
  assert.equal(typeof result.gen2, "string");
  assert.notEqual(result.gen1, result.gen2);

  // Requirement: first create uses ifGenerationMatch: 0; overwrite is
  // fenced by ifGenerationMatch: gen1.
  const saves = calls.filter((c) => c.op === "save");
  assert.equal(saves.length, 2);
  assert.equal(saves[0].precondition, 0);
  assert.equal(saves[1].precondition, result.gen1);

  // Requirement: prepare does NOT clean up on success — both
  // generations remain available for an external consumer.
  assert.equal(objects.size, 2, "prepare must leave BOTH generations available on success");
  assert.ok(objects.has(result.gen1));
  assert.ok(objects.has(result.gen2));
  assert.ok(!calls.some((c) => c.op === "delete"), "prepare must never delete anything on the success path");

  // The receipt was written, matching the invocation.
  const stored = receipts.readReceipt(receiptPath);
  assert.ok(stored);
  assert.equal(stored.gen1, result.gen1);
  assert.equal(stored.gen2, result.gen2);
});

test("prepareGenerationPinning + simulated external consumer: after prepare returns, a caller OTHER than this module (standing in for the deployed candidate's own separate read) can independently read BOTH generations by the same fileFactory, and cleanup has not run before that read — GEN1 still contains the original (EICAR-shaped) bytes, GEN2 still contains the benign replacement bytes", async () => {
  const { fileFactory, calls } = createFakeGcsStore();
  const receipts = createFakeReceiptStore();
  const receiptPath = buildReceiptPath(VALID_BUILD_ID).receiptPath;

  const result = await prepareGenerationPinning({
    fileFactory,
    v1Buffer: V1_BUFFER,
    v2Buffer: V2_BUFFER,
    receiptPath,
    receiptContext: expectedContext(),
    writeReceipt: receipts.writeReceipt,
  });
  assert.equal(result.ok, true);

  const callsBeforeExternalRead = calls.length;

  // Simulated external consumer (the deployed candidate's own
  // gcsReader, in real life) — a plain read via the SAME fileFactory
  // shape, issued AFTER prepare has already returned.
  const [externalGen1Content] = await fileFactory(result.gen1).download();
  const [externalGen2Content] = await fileFactory(result.gen2).download();
  assert.ok(externalGen1Content.equals(V1_BUFFER), "GEN1 must still contain the original (EICAR-shaped) bytes when externally read");
  assert.ok(externalGen2Content.equals(V2_BUFFER), "GEN2 must still contain the benign replacement bytes when externally read");

  // No delete call occurred before these external reads.
  const callsSoFar = calls.slice(0, callsBeforeExternalRead);
  assert.ok(!callsSoFar.some((c) => c.op === "delete"), "cleanup must not have run before the external verification reads");

  // NOW cleanup runs, only after the simulated external verification.
  const cleanupResult = await cleanupGenerationPinning({
    fileFactory,
    receiptPath,
    expected: expectedContext(),
    readReceipt: receipts.readReceipt,
    removeReceipt: receipts.removeReceipt,
  });
  assert.equal(cleanupResult.ok, true);
  assert.equal(cleanupResult.cleaned, true);

  const deleteIndices = calls.map((c, i) => (c.op === "delete" ? i : -1)).filter((i) => i !== -1);
  assert.ok(deleteIndices.length === 2 && deleteIndices.every((i) => i >= callsBeforeExternalRead), "every delete call must occur strictly after the simulated external verification reads");
});

test("prepareGenerationPinning: a failure partway through (the overwrite step) self-cleans whatever was created, never writes a receipt, and reports the primary error — not a cleanup error", async () => {
  const { fileFactory, objects, calls } = createFakeGcsStore({ failSecondSave: true });
  const receipts = createFakeReceiptStore();
  const receiptPath = buildReceiptPath(VALID_BUILD_ID).receiptPath;

  const result = await prepareGenerationPinning({
    fileFactory,
    v1Buffer: V1_BUFFER,
    v2Buffer: V2_BUFFER,
    receiptPath,
    receiptContext: expectedContext(),
    writeReceipt: receipts.writeReceipt,
  });

  assert.equal(result.ok, false);
  assert.ok(/simulated write failure/.test(result.error), `expected the primary failure reason, got: ${result.error}`);
  assert.equal(objects.size, 0, "the one generation that WAS created (gen1) must be self-cleaned by prepare on its own failure path");
  assert.equal(receipts.readReceipt(receiptPath), null, "no receipt may ever be written when prepare itself fails");
  const deletes = calls.filter((c) => c.op === "delete");
  assert.equal(deletes.length, 1, "only the one generation actually created should be targeted for self-cleanup");
});

test("prepareGenerationPinning: if its OWN self-cleanup also fails after a primary failure, the primary error is still what is reported (a cleanup failure is a distinct diagnostic, never a replacement)", async () => {
  const { fileFactory } = createFakeGcsStore({ failSecondSave: true, failDeleteGenerations: new Set(["1000000000000000"]) });
  const receipts = createFakeReceiptStore();
  const receiptPath = buildReceiptPath(VALID_BUILD_ID).receiptPath;

  const result = await prepareGenerationPinning({
    fileFactory,
    v1Buffer: V1_BUFFER,
    v2Buffer: V2_BUFFER,
    receiptPath,
    receiptContext: expectedContext(),
    writeReceipt: receipts.writeReceipt,
  });

  assert.equal(result.ok, false);
  assert.ok(/simulated write failure/.test(result.error), `the primary error must still be the original write failure, got: ${result.error}`);
});

// ---------------------------------------------------------------------
// cleanupGenerationPinning
// ---------------------------------------------------------------------

async function prepareHappyPath({ store, receipts, buildId = VALID_BUILD_ID }) {
  const receiptPath = buildReceiptPath(buildId).receiptPath;
  const result = await prepareGenerationPinning({
    fileFactory: store.fileFactory,
    v1Buffer: V1_BUFFER,
    v2Buffer: V2_BUFFER,
    receiptPath,
    receiptContext: expectedContext(buildId),
    writeReceipt: receipts.writeReceipt,
  });
  assert.equal(result.ok, true);
  return { ...result, receiptPath };
}

test("cleanupGenerationPinning: the happy path deletes exactly GEN1 and GEN2 (each fenced by its own generation precondition), then removes the receipt — nothing left behind, no list call anywhere", async () => {
  const store = createFakeGcsStore();
  const receipts = createFakeReceiptStore();
  const { gen1, gen2, receiptPath } = await prepareHappyPath({ store, receipts });

  const result = await cleanupGenerationPinning({
    fileFactory: store.fileFactory,
    receiptPath,
    expected: expectedContext(),
    readReceipt: receipts.readReceipt,
    removeReceipt: receipts.removeReceipt,
  });

  assert.equal(result.ok, true);
  assert.equal(result.cleaned, true);
  assert.equal(store.objects.size, 0, "both generations must be gone");
  assert.equal(receipts.readReceipt(receiptPath), null, "the receipt must be removed after successful cleanup");
  const deletes = store.calls.filter((c) => c.op === "delete");
  assert.deepEqual(deletes.map((d) => d.generation).sort(), [gen1, gen2].sort());
  for (const d of deletes) {
    assert.equal(d.precondition, d.generation, "every delete must be fenced by its own exact generation precondition");
  }
  assert.ok(store.calls.every((c) => c.op !== "list" && c.op !== "getFiles"), "no list-shaped operation may occur");
});

test("cleanupGenerationPinning: calling cleanup with no receipt present is a safe, idempotent no-op — not an error", async () => {
  const store = createFakeGcsStore();
  const receipts = createFakeReceiptStore();
  const receiptPath = buildReceiptPath(VALID_BUILD_ID).receiptPath;

  const result = await cleanupGenerationPinning({
    fileFactory: store.fileFactory,
    receiptPath,
    expected: expectedContext(),
    readReceipt: receipts.readReceipt,
    removeReceipt: receipts.removeReceipt,
  });

  assert.equal(result.ok, true);
  assert.equal(result.cleaned, false);
  assert.equal(store.calls.length, 0, "no Storage call may occur when there is nothing to clean up");
});

test("cleanupGenerationPinning: a malformed/forged receipt is rejected BEFORE any Storage call is attempted — proven by a fileFactory that throws if ever invoked", async () => {
  const receipts = createFakeReceiptStore();
  const receiptPath = buildReceiptPath(VALID_BUILD_ID).receiptPath;
  receipts.raw.set(receiptPath, validReceiptData({ buildId: "00000000-0000-0000-0000-000000000000" }));

  const throwingFileFactory = () => {
    throw new Error("this must never be called — validation must fail before any Storage access");
  };

  const result = await cleanupGenerationPinning({
    fileFactory: throwingFileFactory,
    receiptPath,
    expected: expectedContext(),
    readReceipt: receipts.readReceipt,
    removeReceipt: receipts.removeReceipt,
  });

  assert.equal(result.ok, false);
  assert.ok(/receipt rejected/.test(result.error));
});

test("cleanupGenerationPinning: an already-deleted (404-shaped) generation is treated as a successfully-achieved goal state, not a failure — safe for idempotent retry", async () => {
  const store = createFakeGcsStore();
  const receipts = createFakeReceiptStore();
  const { gen1, gen2, receiptPath } = await prepareHappyPath({ store, receipts });

  // Simulate a PRIOR partial cleanup: gen1 already deleted out of band.
  store.objects.delete(gen1);

  const result = await cleanupGenerationPinning({
    fileFactory: store.fileFactory,
    receiptPath,
    expected: expectedContext(),
    readReceipt: receipts.readReceipt,
    removeReceipt: receipts.removeReceipt,
  });

  assert.equal(result.ok, true, `expected success treating the already-absent generation as achieved, got: ${JSON.stringify(result)}`);
  assert.equal(store.objects.has(gen2), false, "the still-present generation (gen2) must still be deleted");
  assert.equal(receipts.readReceipt(receiptPath), null);
});

test("cleanupGenerationPinning: a genuine (non-404) delete failure leaves the receipt in place and is reported as incomplete — safely retryable, and the retry (once the underlying failure is resolved) succeeds and IS exact", async () => {
  const store = createFakeGcsStore({ failDeleteGenerations: new Set() });
  const receipts = createFakeReceiptStore();
  const { gen1, gen2, receiptPath } = await prepareHappyPath({ store, receipts });

  // Inject a failure for gen1 specifically on the first attempt.
  store.calls.length = 0;
  const originalFactory = store.fileFactory;
  let failGen1Once = true;
  const flakyFactory = (generation) => {
    const handle = originalFactory(generation);
    if (generation === gen1 && failGen1Once) {
      return {
        ...handle,
        delete: async (opts) => {
          store.calls.push({ op: "delete", generation, precondition: opts && opts.preconditionOpts && opts.preconditionOpts.ifGenerationMatch, injectedFailure: true });
          throw new Error("fake: transient delete failure for gen1");
        },
      };
    }
    return handle;
  };

  const firstAttempt = await cleanupGenerationPinning({
    fileFactory: flakyFactory,
    receiptPath,
    expected: expectedContext(),
    readReceipt: receipts.readReceipt,
    removeReceipt: receipts.removeReceipt,
  });
  assert.equal(firstAttempt.ok, false, "cleanup must report incomplete when one delete genuinely fails");
  assert.ok(/incomplete/.test(firstAttempt.error));
  assert.ok(receipts.readReceipt(receiptPath), "the receipt must remain in place after an incomplete cleanup, so a retry can find it");
  assert.equal(store.objects.has(gen2), false, "gen2 (which succeeded) must already be gone even though the overall attempt is incomplete");
  assert.equal(store.objects.has(gen1), true, "gen1 (which failed) must still be present");

  failGen1Once = false;
  const callsBeforeSecondAttempt = store.calls.length;
  const secondAttempt = await cleanupGenerationPinning({
    fileFactory: flakyFactory,
    receiptPath,
    expected: expectedContext(),
    readReceipt: receipts.readReceipt,
    removeReceipt: receipts.removeReceipt,
  });
  assert.equal(secondAttempt.ok, true, "the retry must succeed once the underlying transient failure is resolved");
  assert.equal(store.objects.size, 0);
  assert.equal(receipts.readReceipt(receiptPath), null);
  // The retry's own delete calls remain exact — gen1 (the one still
  // outstanding) is genuinely re-deleted, and gen2 (already gone from
  // the first attempt) is harmlessly re-attempted and treated as
  // already-achieved — never a broader/list-based sweep, and never a
  // THIRD, unrelated generation touched.
  const secondAttemptDeletes = store.calls.slice(callsBeforeSecondAttempt).filter((c) => c.op === "delete");
  assert.deepEqual(secondAttemptDeletes.map((d) => d.generation).sort(), [gen1, gen2].sort());
});

test("cleanupGenerationPinning: success + a cleanup delete failure is reported distinctly (never silently swallowed), and the receipt is correctly NOT removed in that case", async () => {
  const store = createFakeGcsStore();
  const receipts = createFakeReceiptStore();
  const { gen1, receiptPath } = await prepareHappyPath({ store, receipts });
  store.calls.length = 0;

  const failingFactory = (generation) => {
    const handle = store.fileFactory(generation);
    if (generation === gen1) {
      return { ...handle, delete: async () => { throw new Error("fake: permanent delete failure"); } };
    }
    return handle;
  };

  const result = await cleanupGenerationPinning({
    fileFactory: failingFactory,
    receiptPath,
    expected: expectedContext(),
    readReceipt: receipts.readReceipt,
    removeReceipt: receipts.removeReceipt,
  });

  assert.equal(result.ok, false);
  assert.ok(/failed to delete generation.*1000000000000000|1000000000000000.*failed/.test(result.error) || /cleanup incomplete/.test(result.error));
  assert.ok(receipts.readReceipt(receiptPath), "the receipt must remain so a future retry can find it");
});

// ---------------------------------------------------------------------
// Real (but local-only, isolated-tmpdir) atomic receipt-write behavior
// ---------------------------------------------------------------------

test("writeReceiptExclusive: writes the receipt atomically (mode 0600, exact content, no leftover temp file), using an isolated local tmpdir — never the real /workspace", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "generation-pinning-receipt-test-"));
  try {
    const receiptPath = path.join(tmpDir, "receipts", `${VALID_BUILD_ID}.json`);
    const data = validReceiptData();
    writeReceiptExclusive(receiptPath, data);

    const stat = fs.statSync(receiptPath);
    assert.equal(stat.mode & 0o777, 0o600, "the receipt file must be created with mode 0600");
    const content = JSON.parse(fs.readFileSync(receiptPath, "utf8"));
    assert.deepEqual(content, data);

    const siblingEntries = fs.readdirSync(path.dirname(receiptPath));
    assert.deepEqual(siblingEntries, [`${VALID_BUILD_ID}.json`], "no leftover temp file may remain in the receipt directory");
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

function withTmpDir(fn) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "generation-pinning-receipt-test-"));
  try {
    return fn(tmpDir);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

function tempResiduesIn(dir) {
  return fs.readdirSync(dir).filter((name) => name.startsWith(".receipt.tmp-"));
}

test("writeReceiptExclusive: an existing REGULAR FILE at the destination is never overwritten — rejected outright, exact original bytes unchanged, and the failed publisher's own temp file is removed", () => {
  withTmpDir((tmpDir) => {
    const receiptPath = path.join(tmpDir, `${VALID_BUILD_ID}.json`);
    const adversarialBytes = JSON.stringify({ foreign: "content, not a real receipt" });
    fs.writeFileSync(receiptPath, adversarialBytes);

    assert.throws(
      () => writeReceiptExclusive(receiptPath, validReceiptData()),
      /already exists|pre-existing|untrusted/,
      "writing over a pre-existing regular file must be refused"
    );

    // Exact original adversarial bytes remain — not merely "still
    // valid JSON with the same meaning", but byte-for-byte identical.
    assert.equal(fs.readFileSync(receiptPath, "utf8"), adversarialBytes);
    assert.deepEqual(tempResiduesIn(tmpDir), [], "the failed publisher must remove its own temp file");
  });
});

test("writeReceiptExclusive: an existing SYMLINK at the destination is never followed or replaced — link(2)'s own EEXIST fires on the symlink's directory-entry name itself, without ever dereferencing it, and the symlink (and whatever it points to) is left completely untouched", () => {
  withTmpDir((tmpDir) => {
    const receiptPath = path.join(tmpDir, `${VALID_BUILD_ID}.json`);
    const symlinkTargetPath = path.join(tmpDir, "elsewhere.json");
    const adversarialBytes = JSON.stringify({ foreign: "symlink target content" });
    fs.writeFileSync(symlinkTargetPath, adversarialBytes);
    fs.symlinkSync(symlinkTargetPath, receiptPath);

    assert.throws(
      () => writeReceiptExclusive(receiptPath, validReceiptData()),
      /already exists|pre-existing|untrusted/,
      "writing over a pre-existing symlink must be refused"
    );

    // The symlink itself is untouched (still a symlink, still pointing
    // at the same target), and the target's own content is untouched.
    assert.equal(fs.lstatSync(receiptPath).isSymbolicLink(), true, "the destination must remain a symlink, never replaced by a regular file");
    assert.equal(fs.readlinkSync(receiptPath), symlinkTargetPath);
    assert.equal(fs.readFileSync(symlinkTargetPath, "utf8"), adversarialBytes, "the symlink's target content must be completely unaffected — it was never dereferenced or written through");
    assert.deepEqual(tempResiduesIn(tmpDir), []);
  });
});

test("writeReceiptExclusive: an existing DIRECTORY at the destination is never replaced — rejected outright, the directory (and its contents) untouched", () => {
  withTmpDir((tmpDir) => {
    const receiptPath = path.join(tmpDir, `${VALID_BUILD_ID}.json`);
    fs.mkdirSync(receiptPath);
    fs.writeFileSync(path.join(receiptPath, "sentinel.txt"), "adversarial directory contents");

    assert.throws(
      () => writeReceiptExclusive(receiptPath, validReceiptData()),
      /already exists|pre-existing|untrusted|EISDIR|EEXIST/,
      "writing over a pre-existing directory must be refused"
    );

    assert.equal(fs.statSync(receiptPath).isDirectory(), true, "the destination must remain a directory, never replaced");
    assert.equal(fs.readFileSync(path.join(receiptPath, "sentinel.txt"), "utf8"), "adversarial directory contents");
    assert.deepEqual(tempResiduesIn(tmpDir), []);
  });
});

test("writeReceiptExclusive: an adversarial destination created BETWEEN when a publisher would have written its temp file and when it publishes loses safely — there is no separate check-then-act window to race, because the existence check and the publish are the SAME atomic link(2) syscall; pre-creating the destination before calling this function is equivalent to any interleaving a concurrent creator could achieve", () => {
  withTmpDir((tmpDir) => {
    const receiptPath = path.join(tmpDir, `${VALID_BUILD_ID}.json`);
    // Simulates "the race was already lost" — an adversary (or a
    // concurrent legitimate publisher) claimed this exact path first,
    // by whatever means, before THIS call's link() ever executes.
    const winnerBytes = JSON.stringify({ winner: "adversary-or-concurrent-publisher" });
    fs.writeFileSync(receiptPath, winnerBytes);

    assert.throws(() => writeReceiptExclusive(receiptPath, validReceiptData()));
    assert.equal(fs.readFileSync(receiptPath, "utf8"), winnerBytes, "the exact winning content must remain unchanged — this call must never have touched it");
    assert.deepEqual(tempResiduesIn(tmpDir), [], "the losing call's own temp file must be cleaned up");
  });
});

test("writeReceiptExclusive: of two publishers racing for the SAME destination, only the first (whichever wins the single link() syscall) succeeds — the second necessarily fails, and the final on-disk content is exactly the winner's, never a merge, never corrupted, never the loser's", () => {
  withTmpDir((tmpDir) => {
    const receiptPath = path.join(tmpDir, `${VALID_BUILD_ID}.json`);
    const firstData = validReceiptData({ gen1: "1111111111111111", gen2: "2222222222222222" });
    const secondData = validReceiptData({ gen1: "3333333333333333", gen2: "4444444444444444" });

    // Two independent "publishers" — each writes its own temp file
    // first (proving they do not share or collide on temp names),
    // then races to publish to the SAME final path. JS is single-
    // threaded, so these calls are sequential, but the property under
    // test — link(2)'s mutual exclusion on the destination name — is a
    // per-call guarantee of the primitive itself, not a scheduling
    // artifact; calling it twice in immediate sequession against the
    // same destination is a valid, sufficient proof of that guarantee.
    writeReceiptExclusive(receiptPath, firstData);
    assert.throws(() => writeReceiptExclusive(receiptPath, secondData), /already exists|pre-existing|untrusted/);

    const finalContent = JSON.parse(fs.readFileSync(receiptPath, "utf8"));
    assert.deepEqual(finalContent, firstData, "the final content must be exactly the first (winning) publisher's data");
    assert.deepEqual(tempResiduesIn(tmpDir), [], "neither the winning nor the losing publisher may leave a temp residue");
  });
});

test("writeReceiptExclusive: the receipt is never partially readable — it only ever comes into existence via link() to an ALREADY fully-written-and-fsynced temp file, so any successful read of the destination is always the complete, valid content, never a truncated or in-progress write; the destination is also never opened for direct writing at any point", () => {
  const source = fs.readFileSync(path.join(__dirname, "verifyGenerationPinning.js"), "utf8");
  // Structural proof: this function must never open the FINAL
  // receiptPath itself for writing — every write happens against
  // tmpPath, and receiptPath only ever appears as a link() destination
  // or an lstat/readdir target, never as an argument to
  // openSync(...,"w")/writeSync/writeFileSync.
  const prepareCleanupSection = source.slice(source.indexOf("function writeReceiptExclusive"));
  assert.ok(!/writeSync\(\s*fd\s*,\s*buf\s*\)[\s\S]{0,40}receiptPath/.test(prepareCleanupSection), "sanity: content must be written to the temp fd, not directly associated with receiptPath");
  assert.ok(!/openSync\(\s*receiptPath/.test(prepareCleanupSection), "receiptPath must never be opened directly for writing");

  withTmpDir((tmpDir) => {
    const receiptPath = path.join(tmpDir, `${VALID_BUILD_ID}.json`);
    const data = validReceiptData();
    writeReceiptExclusive(receiptPath, data);
    // Every read of the now-published receipt returns the complete,
    // valid content — never partial.
    for (let i = 0; i < 5; i++) {
      const content = JSON.parse(fs.readFileSync(receiptPath, "utf8"));
      assert.deepEqual(content, data);
    }
  });
});

test("receipt content contains no payload/token/credential/authorization-shaped field — only the seven expected identifiers", async () => {
  const store = createFakeGcsStore();
  const receipts = createFakeReceiptStore();
  const receiptPath = buildReceiptPath(VALID_BUILD_ID).receiptPath;

  await prepareGenerationPinning({
    fileFactory: store.fileFactory,
    v1Buffer: V1_BUFFER,
    v2Buffer: V2_BUFFER,
    receiptPath,
    receiptContext: expectedContext(),
    writeReceipt: receipts.writeReceipt,
  });

  const stored = receipts.readReceipt(receiptPath);
  assert.deepEqual(Object.keys(stored).sort(), ["bucket", "buildId", "gen1", "gen2", "objectPath", "project", "schemaVersion"]);
  const serialized = JSON.stringify(stored).toLowerCase();
  for (const forbidden of ["token", "credential", "authorization", "bearer", "secret", "password"]) {
    assert.ok(!serialized.includes(forbidden), `receipt must never contain the substring "${forbidden}"`);
  }
});

// ---------------------------------------------------------------------
// Source-level regression guards
// ---------------------------------------------------------------------

test("verifyGenerationPinning.js: no list/wildcard/prefix Storage operation and no gcloud storage cp/ls/rm anywhere in its own EXECUTABLE source (the file's own doc comments legitimately discuss the OLD pattern being replaced, as history)", () => {
  assert.ok(!/\.list\s*\(/.test(EXECUTABLE_SOURCE));
  assert.ok(!/\.getFiles\s*\(/.test(EXECUTABLE_SOURCE));
  assert.ok(!/gcloud storage (cp|ls|rm)\b/.test(EXECUTABLE_SOURCE));
  assert.ok(!/add-iam-policy-binding|remove-iam-policy-binding|set-iam-policy\b/.test(EXECUTABLE_SOURCE));
});

test("verifyGenerationPinning.js: generation values are never coerced through Number()/parseInt()/parseFloat()/unary-plus on any executable line", () => {
  assert.ok(!/\bNumber\s*\(\s*(meta|generation|gen1|gen2)/.test(EXECUTABLE_SOURCE));
  assert.ok(!/\bparseInt\s*\(/.test(EXECUTABLE_SOURCE));
  assert.ok(!/\bparseFloat\s*\(/.test(EXECUTABLE_SOURCE));
  assert.ok(!/[^!=<>]\+(generation|gen1|gen2|meta1|meta2)\b/.test(EXECUTABLE_SOURCE));
});

test("verifyGenerationPinning.js: the old one-shot 'prepare then immediate cleanup' function no longer exists — only the two explicit, separately-owned operations remain", () => {
  assert.ok(!EXECUTABLE_SOURCE.includes("runGenerationPinningVerification"), "the prior single-shot function name must not remain anywhere in executable source");
  assert.ok(EXECUTABLE_SOURCE.includes("prepareGenerationPinning"));
  assert.ok(EXECUTABLE_SOURCE.includes("cleanupGenerationPinning"));
});
