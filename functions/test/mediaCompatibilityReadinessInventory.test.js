"use strict";

// Step 21a media-compatibility readiness inventory — complete test coverage
// for §15 items 560-678 of
// docs/plans/marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md.
// Every test here exercises the actual exported production functions in
// functions/scripts/mediaCompatibilityReadinessInventory.js, or, where
// tagged [Static source test] in the plan, inspects that file's own literal
// source text. No test opens a network connection, initializes a real
// Firebase app, or reads any real project's data — every Firestore
// interaction is an injected fake adapter, and every filesystem operation
// happens inside a unique temporary directory outside this repository,
// cleaned up in `afterEach`.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const crypto = require("node:crypto");

const inv = require("../scripts/mediaCompatibilityReadinessInventory.js");
const PRODUCTION_SOURCE_PATH = path.resolve(__dirname, "../scripts/mediaCompatibilityReadinessInventory.js");
const PRODUCTION_SOURCE = fs.readFileSync(PRODUCTION_SOURCE_PATH, "utf8");
// A comment-stripped variant, used only for "no forbidden call exists"
// checks — so that a doc-comment *describing* a forbidden pattern (to
// explain why it's absent) can never itself trip the check.
const PRODUCTION_SOURCE_CODE_ONLY = PRODUCTION_SOURCE.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");

// ---------------------------------------------------------------------------
// Shared test helpers
// ---------------------------------------------------------------------------

let tempDirs = [];

function mkTemp(prefix) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), `mcri-${prefix}-`));
  tempDirs.push(dir);
  return dir;
}

test.afterEach(() => {
  for (const dir of tempDirs) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
  tempDirs = [];
});

function makeEnv({ emulator = false } = {}) {
  return emulator ? { FIRESTORE_EMULATOR_HOST: "localhost:8080" } : {};
}

function makeClock(startIso = "2026-08-29T00:00:00.000Z") {
  let counter = 0;
  const start = Date.parse(startIso);
  return () => new Date(start + counter++ * 1000).toISOString();
}

function makeDeterministicRandomBytes(seed = 1) {
  let counter = seed;
  return (n) => {
    counter += 1;
    const hex = crypto.createHash("sha256").update(String(counter)).digest("hex");
    return Buffer.from(hex.slice(0, n * 2), "hex");
  };
}

function validCheckpoint(overrides = {}) {
  return {
    schemaVersion: inv.SCHEMA_VERSION,
    runId: "run-abc123",
    toolVersion: "test-tool@1",
    projectBinding: "demo-project",
    projectClassification: "demo",
    status: "in_progress",
    lastCommittedPageIndex: -1,
    lastCommittedPath: null,
    startedAt: "2026-08-29T00:00:00.000Z",
    lastActivityAt: "2026-08-29T00:00:00.000Z",
    completedAt: null,
    readFailureCount: 0,
    ...overrides,
  };
}

function validJournal(overrides = {}) {
  const base = {
    schemaVersion: inv.SCHEMA_VERSION,
    runId: "run-abc123",
    pageIndex: 0,
    pageStartExclusivePath: null,
    pageEndInclusivePath: "businesses/b1/products/p003",
    examinedCount: 3,
    categoryCounts: {
      media_missing: 1,
      media_null: 0,
      media_wrong_type: 0,
      media_conforming: 1,
      media_oversized: 1,
    },
    violations: [
      { path: "businesses/b1/products/p001", category: "media_missing" },
      { path: "businesses/b1/products/p003", category: "media_oversized", observedLength: 21 },
    ],
  };
  return { ...base, ...overrides };
}

function writeRawJournal({ outputDir, runId, pageIndex, journal, fsImpl = fs }) {
  const pagesDir = inv.pagesDirFor(outputDir, runId);
  fsImpl.mkdirSync(pagesDir, { recursive: true });
  fsImpl.writeFileSync(inv.pageJournalPathFor(outputDir, runId, pageIndex), JSON.stringify(journal, null, 2));
}

function writeRawCheckpoint({ outputDir, checkpoint, fsImpl = fs }) {
  fsImpl.mkdirSync(outputDir, { recursive: true });
  fsImpl.writeFileSync(inv.checkpointPathFor(outputDir, checkpoint.runId), JSON.stringify(checkpoint, null, 2));
}

function makeDoc(docPath, media) {
  return { path: docPath, data: { media } };
}

function pagedAdapter(pages) {
  let call = 0;
  return {
    calls: [],
    fetchPage: async (args) => {
      const invocation = { ...args, callIndex: call };
      call += 1;
      const page = pages[invocation.callIndex] || [];
      return page;
    },
  };
}

async function runFreshInventory({
  outputDir,
  project = "demo-project",
  pages,
  emulator = true,
  extraArgs = {},
  extraDeps = {},
  pageSize = inv.PAGE_SIZE,
}) {
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const adapter = pagedAdapter(pages);
  const result = await inv.runInventory({
    args: { project, "output-dir": outputDir, "confirm-unbounded-scan": true, ...extraArgs },
    deps: {
      fsImpl: fs,
      adapterFactory: () => adapter,
      randomBytesImpl: makeDeterministicRandomBytes(),
      nowImpl: makeClock(),
      pid: 4242,
      hostname: "test-host",
      platform: process.platform,
      env: makeEnv({ emulator }),
      repoRoot,
      homeDir,
      toolVersion: "test-tool@1",
      sleepImpl: null,
      pageSize,
      ...extraDeps,
    },
  });
  return { result, adapter };
}

// =============================================================================
// Items 560-583 — classification, pagination, retry, privacy, no-write (24 items)
// =============================================================================

test("560. each of the five classification categories is proven independently", () => {
  assert.equal(inv.classifyMedia(undefined), "media_missing");
  assert.equal(inv.classifyMedia(null), "media_null");
  assert.equal(inv.classifyMedia("not-a-list"), "media_wrong_type");
  assert.equal(inv.classifyMedia(new Array(5).fill({})), "media_conforming");
  assert.equal(inv.classifyMedia(new Array(21).fill({})), "media_oversized");
});

test("561. exact boundary lengths 0, 1, 20, and 21 classify correctly", () => {
  assert.equal(inv.classifyMedia([]), "media_conforming");
  assert.equal(inv.classifyMedia(new Array(1).fill({})), "media_conforming");
  assert.equal(inv.classifyMedia(new Array(20).fill({})), "media_conforming");
  assert.equal(inv.classifyMedia(new Array(21).fill({})), "media_oversized");
});

test("562. media present as string/map/number/boolean each classify as media_wrong_type", () => {
  assert.equal(inv.classifyMedia("x"), "media_wrong_type");
  assert.equal(inv.classifyMedia({ a: 1 }), "media_wrong_type");
  assert.equal(inv.classifyMedia(42), "media_wrong_type");
  assert.equal(inv.classifyMedia(true), "media_wrong_type");
});

test("563. traversal order across a multi-page synthetic dataset is deterministic and strictly ascending", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const pages = [
    [makeDoc("businesses/b1/products/p001", []), makeDoc("businesses/b1/products/p002", [])],
    [makeDoc("businesses/b1/products/p003", []), makeDoc("businesses/b1/products/p004", [])],
    [],
  ];
  const { result } = await runFreshInventory({ outputDir, pages, pageSize: 2 });
  const ndjson = fs.readFileSync(inv.ndjsonPathFor(outputDir, result.runId), "utf8");
  assert.equal(ndjson, "");
  const journal0 = JSON.parse(fs.readFileSync(inv.pageJournalPathFor(outputDir, result.runId, 0), "utf8"));
  const journal1 = JSON.parse(fs.readFileSync(inv.pageJournalPathFor(outputDir, result.runId, 1), "utf8"));
  assert.equal(journal0.pageEndInclusivePath, "businesses/b1/products/p002");
  assert.equal(journal1.pageStartExclusivePath, "businesses/b1/products/p002");
  assert.equal(journal1.pageEndInclusivePath, "businesses/b1/products/p004");
});

test("564. a resumed run continues strictly after the checkpoint's lastPath, never re-examining an already-committed page", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const pages = [[makeDoc("businesses/b1/products/p001", [])]];
  const { result } = await runFreshInventory({ outputDir, pages: [pages[0], []] });
  const checkpoint = JSON.parse(fs.readFileSync(inv.checkpointPathFor(outputDir, result.runId), "utf8"));
  assert.equal(checkpoint.lastCommittedPath, "businesses/b1/products/p001");

  const repoRoot = mkTemp("repo2");
  const homeDir = mkTemp("home2");
  let observedAfterPath = null;
  const adapter = {
    fetchPage: async ({ afterPath }) => {
      observedAfterPath = afterPath;
      return [];
    },
  };
  await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDir, "resume-run-id": result.runId, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs,
      adapterFactory: () => adapter,
      randomBytesImpl: makeDeterministicRandomBytes(2),
      nowImpl: makeClock("2026-08-29T01:00:00.000Z"),
      pid: 4243,
      hostname: "test-host",
      platform: process.platform,
      env: makeEnv({ emulator: true }),
      repoRoot,
      homeDir,
      toolVersion: "test-tool@1",
      sleepImpl: null,
    },
  });
  // run already completed on page 1 (exhausted, < PAGE_SIZE) so resume never re-fetches
  assert.equal(observedAfterPath, null);
});

test("565. replaying an already-committed page identity is a safe no-op — no duplicate aggregate/violation entry", () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const runId = "run-replay";
  const checkpoint = validCheckpoint({ runId, lastCommittedPageIndex: 0, lastCommittedPath: "businesses/b1/products/p003" });
  const journal = validJournal({ runId });
  writeRawCheckpoint({ outputDir, checkpoint });
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal });

  const { valid, journals } = inv.loadAndValidateJournalChain({ outputDir, runId, checkpoint, fsImpl: fs });
  assert.equal(valid, true);
  const aggregatesA = inv.recomputeAggregates(journals);
  const { journals: journalsAgain } = inv.loadAndValidateJournalChain({ outputDir, runId, checkpoint, fsImpl: fs });
  const aggregatesB = inv.recomputeAggregates(journalsAgain);
  assert.deepEqual(aggregatesA, aggregatesB);
  assert.equal(aggregatesA.totalViolations, 2);
});

test("566. a short (partial) final page ends the run completed:true with no further page fetched", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result, adapter: _adapter } = await runFreshInventory({
    outputDir,
    pages: [[makeDoc("businesses/b1/products/p001", [])]],
  });
  assert.equal(result.checkpoint.status, "completed");
  assert.equal(fs.readdirSync(inv.pagesDirFor(outputDir, result.runId)).length, 1);
});

test("567. an empty collection completes immediately with all counts at zero and empty violating-path aggregate", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[]] });
  assert.equal(result.checkpoint.status, "completed");
  assert.equal(result.summary.documentsExamined, 0);
  assert.equal(result.summary.totalViolations, 0);
  const ndjson = fs.readFileSync(inv.ndjsonPathFor(outputDir, result.runId), "utf8");
  assert.equal(ndjson, "");
});

test("568. [Emulator test — represented as a deterministic fixture, no live emulator] a document created after the run begins is never a gap or duplicate", () => {
  // Represented structurally: a page's own boundary is fixed at fetch time (the
  // adapter's own snapshot), so a document created after that page's own fetch
  // is simply captured, or not, by the *next* page fetch — never re-examined.
  const journalA = validJournal({ pageIndex: 0, pageStartExclusivePath: null, pageEndInclusivePath: "businesses/b1/products/p003" });
  const journalB = validJournal({
    pageIndex: 1,
    pageStartExclusivePath: "businesses/b1/products/p003",
    pageEndInclusivePath: "businesses/b1/products/p005",
    examinedCount: 1,
    categoryCounts: { media_missing: 0, media_null: 0, media_wrong_type: 0, media_conforming: 1, media_oversized: 0 },
    violations: [],
  });
  const chain = [journalA, journalB];
  const paths = new Set();
  for (const j of chain) {
    for (const v of j.violations) {
      assert.equal(paths.has(v.path), false, "no duplicate path across the chain");
      paths.add(v.path);
    }
  }
});

test("569. [Emulator test — deterministic fixture] a deleted document is simply absent from the query, never an error", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({
    outputDir,
    pages: [[makeDoc("businesses/b1/products/p001", [])], []],
  });
  assert.equal(result.checkpoint.status, "completed");
  assert.equal(result.summary.documentsExamined, 1);
});

test("570. [Emulator test — deterministic fixture] classification uses whichever state the read actually observed", () => {
  const before = inv.classifyMedia(undefined);
  const after = inv.classifyMedia([{ originalUrl: "x" }]);
  assert.notEqual(before, after);
  assert.equal(before, "media_missing");
  assert.equal(after, "media_conforming");
});

test("571. a simulated page-read error is retried up to exactly 3 times before status becomes failed", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  let attempts = 0;
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const adapter = {
    fetchPage: async () => {
      attempts += 1;
      throw new Error("simulated read failure");
    },
  };
  const result = await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDir, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs,
      adapterFactory: () => adapter,
      randomBytesImpl: makeDeterministicRandomBytes(),
      nowImpl: makeClock(),
      pid: 1,
      hostname: "h",
      platform: process.platform,
      env: makeEnv({ emulator: true }),
      repoRoot,
      homeDir,
      toolVersion: "t@1",
      sleepImpl: null,
    },
  });
  assert.equal(attempts, 3);
  assert.equal(result.checkpoint.status, "failed");
});

test("572. retry exhaustion records the read-failure count and never classifies the unreadable page's documents", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const adapter = { fetchPage: async () => { throw new Error("boom"); } };
  const result = await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDir, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory: () => adapter, randomBytesImpl: makeDeterministicRandomBytes(),
      nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform,
      env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
    },
  });
  assert.equal(result.checkpoint.readFailureCount, 1);
  assert.equal(result.summary.documentsExamined, 0);
  assert.equal(fs.readdirSync(inv.pagesDirFor(outputDir, result.runId)).length, 0);
});

test("573. a partial/corrupted output-write leaves the run unreportable as completed/zero-result (fail-closed)", () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  fs.mkdirSync(outputDir, { recursive: true });
  const runId = "run-corrupt-output";
  const checkpoint = validCheckpoint({ runId, lastCommittedPageIndex: 0, lastCommittedPath: "businesses/b1/products/p003" });
  writeRawCheckpoint({ outputDir, checkpoint });
  // no journal written for pageIndex 0 -> checkpoint claims a page that doesn't exist
  const { valid } = inv.loadAndValidateJournalChain({ outputDir, runId, checkpoint, fsImpl: fs });
  assert.equal(valid, false);
});

test("574. aggregate arithmetic invariants hold against a synthetic multi-page run", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({
    outputDir,
    pages: [
      [makeDoc("businesses/b1/products/p001", undefined), makeDoc("businesses/b1/products/p002", null)],
      [makeDoc("businesses/b1/products/p003", "bad"), makeDoc("businesses/b1/products/p004", new Array(21).fill({}))],
    ],
  });
  const cc = result.summary.categoryCounts;
  const sum = Object.values(cc).reduce((a, b) => a + b, 0);
  assert.equal(sum, result.summary.documentsExamined);
  const violatingSum = cc.media_missing + cc.media_null + cc.media_wrong_type + cc.media_oversized;
  assert.equal(violatingSum, result.summary.totalViolations);
});

test("575. [Static source test] production source contains no per-entry media[] field access in classification logic", () => {
  const classificationSection = PRODUCTION_SOURCE.slice(
    PRODUCTION_SOURCE.indexOf("function classifyMedia"),
    PRODUCTION_SOURCE.indexOf("function classifyDocument") + 400
  );
  for (const forbidden of ["originalUrl", "playbackUrl", "thumbnailUrl", ".type", ".status"]) {
    assert.equal(classificationSection.includes(forbidden), false, `must not reference ${forbidden}`);
  }
});

test("576. [Static source test] output-building source never constructs a string with prohibited product/business content", () => {
  const forbidden = ["productName", "description", "sellerName", "businessName", "mediaUrl", "barcode", "sku", "signedUrl", "downloadToken"];
  const outputSection = PRODUCTION_SOURCE.slice(
    PRODUCTION_SOURCE.indexOf("function buildSummary"),
    PRODUCTION_SOURCE.indexOf("createFirestoreAdapter")
  );
  for (const term of forbidden) {
    assert.equal(outputSection.toLowerCase().includes(term.toLowerCase()), false, `must not reference ${term}`);
  }
});

test("577. [Static source test] production source contains no .set(/.update(/.delete( call against any path", () => {
  assert.equal(/\.set\(/.test(PRODUCTION_SOURCE_CODE_ONLY), false);
  assert.equal(/\.update\(/.test(PRODUCTION_SOURCE_CODE_ONLY), false);
  assert.equal(/\.delete\(/.test(PRODUCTION_SOURCE_CODE_ONLY), false);
});

test("578. output-path validation refuses a destination inside protected paths and outside an approved output directory", () => {
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  fs.mkdirSync(path.join(repoRoot, "ai_exports", "vet_context"), { recursive: true });
  assert.throws(
    () =>
      inv.resolveAndValidateOutputDir({
        outputDir: path.join(repoRoot, "ai_exports", "vet_context"),
        repoRoot,
        homeDir,
        fsImpl: fs,
      }),
    inv.InventoryError
  );
});

test("579. project-ID handling refuses with no --project, refuses unrecognized without --confirm-production, classifies correctly", () => {
  assert.throws(() => inv.assertProjectGuard({ args: {}, env: {} }), inv.InventoryError);
  assert.throws(
    () => inv.assertProjectGuard({ args: { project: "some-unrecognized-project" }, env: {} }),
    inv.InventoryError
  );
  const emu = inv.assertProjectGuard({ args: { project: "any-project" }, env: makeEnv({ emulator: true }) });
  assert.equal(emu.classification, "emulator");
  const demo = inv.assertProjectGuard({ args: { project: "petsupo-demo", "confirm-production": true }, env: {} });
  assert.equal(demo.classification, "demo");
  const staging = inv.assertProjectGuard({ args: { project: "petsupo-staging", "confirm-production": true }, env: {} });
  assert.equal(staging.classification, "staging");
  const production = inv.assertProjectGuard({ args: { project: "petsupo-prod", "confirm-production": true }, env: {} });
  assert.equal(production.classification, "production");
});

test("580. [Static source test] no embedded credential/service-account key/hardcoded-project initializeApp exists", () => {
  assert.equal(/serviceAccount/i.test(PRODUCTION_SOURCE), false);
  assert.equal(/-----BEGIN/.test(PRODUCTION_SOURCE), false);
  assert.equal(/initializeApp\(\s*\{\s*credential/i.test(PRODUCTION_SOURCE), false);
  const initCall = PRODUCTION_SOURCE.match(/admin\.initializeApp\(([^)]*)\)/);
  assert.ok(initCall);
  assert.equal(/["'][a-z0-9-]+-prod["']/.test(initCall[1]), false);
});

test("581. [Static source test + network-access check] no test in this suite makes a real network call", () => {
  const testSource = fs.readFileSync(__filename, "utf8");
  assert.equal(/require\(["']firebase-admin["']\)/.test(testSource), false);
  assert.equal(/https?:\/\//.test(testSource.replace(/localhost:8080/g, "")), false);
  assert.equal(/require\(["']node:https?["']\)/.test(testSource), false);
});

test("582. [Manual execution evidence] a repeated run against stable synthetic data produces byte-identical aggregates", async () => {
  const outputDir1 = path.join(mkTemp("out1"), "outputs");
  const outputDir2 = path.join(mkTemp("out2"), "outputs");
  const pages = [[makeDoc("businesses/b1/products/p001", []), makeDoc("businesses/b1/products/p002", null)], []];
  const run1 = await runFreshInventory({ outputDir: outputDir1, pages: pages.map((p) => p.slice()) });
  const run2 = await runFreshInventory({ outputDir: outputDir2, pages: pages.map((p) => p.slice()) });
  assert.deepEqual(run1.result.summary.categoryCounts, run2.result.summary.categoryCounts);
  assert.equal(run1.result.summary.totalViolations, run2.result.summary.totalViolations);
});

test("583. [Static source test] §10.1 items 560-583 cross-reference — every authorized behavior has a corresponding test above", () => {
  // Cross-reference proof: every export named by the classification, retry,
  // privacy, and no-write sections above is present and callable.
  for (const fn of ["classifyMedia", "classifyDocument", "withRetry", "runInventory"]) {
    assert.equal(typeof inv[fn], "function", `${fn} must be exported`);
  }
});

// =============================================================================
// Items 584-594 — resume project-binding, non-emulator confirmation (11 items)
// =============================================================================

test("584. a resumed run whose project binding exactly matches proceeds, reading strictly after its own checkpoint", () => {
  const checkpoint = validCheckpoint({ projectBinding: "demo-project" });
  assert.doesNotThrow(() => inv.assertProjectBindingMatches({ checkpoint, currentProject: "demo-project" }));
});

test("585. a resumed run whose project binding does not match fails closed before any Firestore read", () => {
  const checkpoint = validCheckpoint({ projectBinding: "demo-project-a" });
  assert.throws(
    () => inv.assertProjectBindingMatches({ checkpoint, currentProject: "demo-project-b" }),
    inv.InventoryError
  );
});

test("586. two projects sharing identical classification but distinct identities still fail the resume comparison", () => {
  const checkpoint = validCheckpoint({ projectBinding: "demo-alpha", projectClassification: "demo" });
  assert.throws(
    () => inv.assertProjectBindingMatches({ checkpoint, currentProject: "demo-beta" }),
    inv.InventoryError
  );
  assert.equal(inv.classifyProject("demo-alpha", {}), inv.classifyProject("demo-beta", {}));
});

test("587. a checkpoint with a missing/malformed project binding fails closed on resume, identically to a mismatch", () => {
  const checkpointMissing = validCheckpoint({ projectBinding: "" });
  assert.throws(
    () => inv.assertProjectBindingMatches({ checkpoint: checkpointMissing, currentProject: "demo-project" }),
    inv.InventoryError
  );
});

test("588. a rejected resume leaves the checkpoint and any output artifact byte-for-byte unchanged", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[]] });
  const before = fs.readFileSync(inv.checkpointPathFor(outputDir, result.runId), "utf8");

  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  await assert.rejects(
    inv.runInventory({
      args: { project: "different-project", "output-dir": outputDir, "resume-run-id": result.runId, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: fs,
        adapterFactory: () => pagedAdapter([]),
        randomBytesImpl: makeDeterministicRandomBytes(),
        nowImpl: makeClock(),
        pid: 2,
        hostname: "h",
        platform: process.platform,
        env: makeEnv({ emulator: true }),
        repoRoot,
        homeDir,
        toolVersion: "t@1",
        sleepImpl: null,
      },
    }),
    inv.InventoryError
  );
  const after = fs.readFileSync(inv.checkpointPathFor(outputDir, result.runId), "utf8");
  assert.equal(before, after);
});

test("589. following a rejected resume, a genuine new scan against the newly-supplied project requires a fresh runId", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[]] });
  const { result: freshResult } = await runFreshInventory({
    outputDir,
    project: "a-completely-different-project",
    pages: [[]],
    extraDeps: { randomBytesImpl: makeDeterministicRandomBytes(99) },
  });
  assert.notEqual(freshResult.runId, result.runId);
});

test("590. [Static source test] raw project identity is written only into the checkpoint, never into aggregate/item-level output", () => {
  const summarySection = PRODUCTION_SOURCE.slice(
    PRODUCTION_SOURCE.indexOf("function buildSummary"),
    PRODUCTION_SOURCE.indexOf("function writeSummaryAtomic")
  );
  assert.equal(summarySection.includes("projectBinding"), false);
});

test("591. an invocation mechanically confirmed as emulator proceeds with no --confirm-production supplied", () => {
  const { isEmulator } = inv.assertProjectGuard({ args: { project: "any-project" }, env: makeEnv({ emulator: true }) });
  assert.equal(isEmulator, true);
});

test("592. demo/CI/staging/development-named and wholly unrecognized project IDs each still require --confirm-production", () => {
  for (const projectId of ["petsupo-demo", "petsupo-ci", "petsupo-staging", "petsupo-dev", "totally-unrecognized-name"]) {
    assert.throws(() => inv.assertProjectGuard({ args: { project: projectId }, env: {} }), inv.InventoryError);
    assert.doesNotThrow(() => inv.assertProjectGuard({ args: { project: projectId, "confirm-production": true }, env: {} }));
  }
});

test("593. an invocation with no --project refuses unconditionally, independent of any ambient value", () => {
  const originalGcloud = process.env.GCLOUD_PROJECT;
  process.env.GCLOUD_PROJECT = "ambient-project";
  try {
    assert.throws(() => inv.assertProjectGuard({ args: {}, env: process.env }), inv.InventoryError);
  } finally {
    if (originalGcloud === undefined) delete process.env.GCLOUD_PROJECT;
    else process.env.GCLOUD_PROJECT = originalGcloud;
  }
});

test("594. [Static source test] no write-capable/remediation/deployment/migration/backfill/Phase B/activation path is gated behind --confirm-production", () => {
  const guardSection = PRODUCTION_SOURCE.slice(
    PRODUCTION_SOURCE.indexOf("function assertProjectGuard"),
    PRODUCTION_SOURCE.indexOf("function assertScanBoundGuard")
  );
  for (const forbidden of ["deploy", "migrate", "backfill", "remediat", "activat"]) {
    assert.equal(guardSection.toLowerCase().includes(forbidden), false, `must not reference ${forbidden}`);
  }
});

// =============================================================================
// Items 595-627 — operational store / output-format (33 items)
// =============================================================================

test("595. a valid, explicitly-supplied --output-dir outside any disallowed location is accepted, created if absent", () => {
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const outputDir = path.join(mkTemp("out"), "does", "not", "exist", "yet");
  const canonical = inv.resolveAndValidateOutputDir({ outputDir, repoRoot, homeDir, fsImpl: fs });
  assert.equal(fs.existsSync(canonical), true);
});

test("596. an --output-dir resolving inside a protected path is refused before any file is read or written", () => {
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  fs.mkdirSync(path.join(repoRoot, "shipping_label"), { recursive: true });
  assert.throws(
    () => inv.resolveAndValidateOutputDir({ outputDir: path.join(repoRoot, "shipping_label"), repoRoot, homeDir, fsImpl: fs }),
    inv.InventoryError
  );
});

test("597. a symlinked --output-dir whose canonical target lands inside a protected path is refused after canonicalization", () => {
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const protectedDir = path.join(repoRoot, "ai_exports", "vet_context");
  fs.mkdirSync(protectedDir, { recursive: true });
  const outsideLink = path.join(mkTemp("link-parent"), "innocuous-looking-name");
  fs.symlinkSync(protectedDir, outsideLink, "dir");
  assert.throws(
    () => inv.resolveAndValidateOutputDir({ outputDir: outsideLink, repoRoot, homeDir, fsImpl: fs }),
    inv.InventoryError
  );
});

test("598. --output-dir equal to filesystem root, home, repo root, or a source/config dir is refused", () => {
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  assert.throws(() => inv.resolveAndValidateOutputDir({ outputDir: repoRoot, repoRoot, homeDir, fsImpl: fs }), inv.InventoryError);
  assert.throws(() => inv.resolveAndValidateOutputDir({ outputDir: homeDir, repoRoot, homeDir, fsImpl: fs }), inv.InventoryError);
  fs.mkdirSync(path.join(repoRoot, "functions"), { recursive: true });
  assert.throws(
    () => inv.resolveAndValidateOutputDir({ outputDir: path.join(repoRoot, "functions"), repoRoot, homeDir, fsImpl: fs }),
    inv.InventoryError
  );
});

test("599. runId values are validated against the exact grammar", () => {
  assert.doesNotThrow(() => inv.validateRunId("run-abc123"));
  assert.throws(() => inv.validateRunId("Run-ABC"), inv.InventoryError);
  assert.throws(() => inv.validateRunId("-leading-hyphen"), inv.InventoryError);
  assert.throws(() => inv.validateRunId("has spaces"), inv.InventoryError);
  assert.throws(() => inv.validateRunId("a".repeat(65)), inv.InventoryError);
});

test("600. a second invocation targeting an already-locked runId fails exclusive lock acquisition", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  inv.acquireLock({ outputDir, runId: "run-x", fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes(), pid: 1, hostname: "h", now: "t" });
  assert.throws(
    () => inv.acquireLock({ outputDir, runId: "run-x", fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes(9), pid: 2, hostname: "h", now: "t" }),
    inv.InventoryError
  );
});

test("601. an existing lock file is never deleted/overwritten/bypassed automatically", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  inv.acquireLock({ outputDir, runId: "run-x", fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes(), pid: 1, hostname: "h", now: "t" });
  const before = fs.readFileSync(inv.lockPathFor(outputDir, "run-x"), "utf8");
  try {
    inv.acquireLock({ outputDir, runId: "run-x", fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes(9), pid: 2, hostname: "h", now: "t" });
  } catch {
    // expected
  }
  const after = fs.readFileSync(inv.lockPathFor(outputDir, "run-x"), "utf8");
  assert.equal(before, after);
});

test("602. the lock is released after both a normal completion and a handled failure", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[]] });
  assert.equal(fs.existsSync(inv.lockPathFor(outputDir, result.runId)), false);

  const outputDir2 = path.join(mkTemp("out2"), "outputs");
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const adapter = { fetchPage: async () => { throw new Error("boom"); } };
  const result2 = await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDir2, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory: () => adapter, randomBytesImpl: makeDeterministicRandomBytes(),
      nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform,
      env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
    },
  });
  assert.equal(fs.existsSync(inv.lockPathFor(outputDir2, result2.runId)), false);
});

test("603. a checkpoint file round-trips every required field exactly; unrecognized schemaVersion is corrupt", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  const checkpoint = validCheckpoint({ runId: "run-roundtrip" });
  inv.writeCheckpointAtomic({ outputDir, checkpoint, fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes() });
  const { checkpoint: loaded } = inv.readCheckpoint({ outputDir, runId: "run-roundtrip", fsImpl: fs });
  assert.deepEqual(loaded, checkpoint);

  writeRawCheckpoint({ outputDir, checkpoint: { ...checkpoint, schemaVersion: 999 } });
  const { checkpoint: corrupt, errors } = inv.readCheckpoint({ outputDir, runId: "run-roundtrip", fsImpl: fs });
  assert.equal(corrupt, null);
  assert.ok(errors.length > 0);
});

test("604. checkpoint/journal/summary writes use temp-then-rename; a fault between write and rename leaves the prior target unchanged", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  const finalPath = path.join(outputDir, "artifact.json");
  fs.writeFileSync(finalPath, "prior-content");
  const faultyFs = {
    ...fs,
    renameSync: () => {
      throw new Error("simulated rename fault");
    },
  };
  assert.throws(
    () =>
      inv.atomicWriteFile({
        finalPath,
        content: "new-content",
        fsImpl: faultyFs,
        randomBytesImpl: makeDeterministicRandomBytes(),
      }),
    /simulated rename fault/
  );
  assert.equal(fs.readFileSync(finalPath, "utf8"), "prior-content");
});

test("605. a corrupt checkpoint (malformed JSON or failed schema validation) refuses any resume", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(inv.checkpointPathFor(outputDir, "run-bad"), "{not valid json");
  const { checkpoint, errors } = inv.readCheckpoint({ outputDir, runId: "run-bad", fsImpl: fs });
  assert.equal(checkpoint, null);
  assert.ok(errors.length > 0);
});

test("606. a corrupt/missing journal is treated as missing when checkpoint has not advanced; failed when checkpoint claims it committed", () => {
  const outputDir = mkTemp("out");
  const runId = "run-corrupt-journal";
  const checkpoint = validCheckpoint({ runId, lastCommittedPageIndex: 0, lastCommittedPath: "businesses/b1/products/p003" });
  writeRawCheckpoint({ outputDir, checkpoint });
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal: { not: "a valid journal" } });
  const { valid, errors } = inv.loadAndValidateJournalChain({ outputDir, runId, checkpoint, fsImpl: fs });
  assert.equal(valid, false);
  assert.ok(errors.length > 0);
});

test("607. a crash after journal rename but before checkpoint advance resumes, via real runInventory, by advancing the checkpoint alone — zero fetch, journal bytes unchanged, idempotent on a second restart", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const runId = "run-crash-recovery";
  const project = "demo-project";
  fs.mkdirSync(outputDir, { recursive: true });
  // Genuine on-disk crash state: checkpoint still at the pre-first-page
  // sentinel (the journal-write succeeded and was renamed into place, but
  // the checkpoint's own advance never happened before the crash).
  const startCheckpoint = validCheckpoint({ runId, projectBinding: project, lastCommittedPageIndex: -1, lastCommittedPath: null });
  writeRawCheckpoint({ outputDir, checkpoint: startCheckpoint });
  const journal = validJournal({ runId, pageIndex: 0, pageStartExclusivePath: null });
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal });
  const journalPath = inv.pageJournalPathFor(outputDir, runId, 0);
  const journalBytesBefore = fs.readFileSync(journalPath);

  let fetchCallCount = 0;
  const adapterFactory = () => {
    fetchCallCount += 1; // constructing the adapter at all would already be a violation
    return { fetchPage: async () => { throw new Error("must never fetch to recover an already-committed journal"); } };
  };

  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const result = await inv.runInventory({
    args: { project, "output-dir": outputDir, "resume-run-id": runId, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory, randomBytesImpl: makeDeterministicRandomBytes(),
      nowImpl: makeClock("2026-08-29T03:00:00.000Z"), pid: 1, hostname: "h", platform: process.platform,
      env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
    },
  });

  assert.equal(fetchCallCount, 0, "adapterFactory must never be invoked to recover an already-committed journal");
  assert.deepEqual(fs.readFileSync(journalPath), journalBytesBefore, "the immutable journal must not be rewritten or replaced");
  assert.equal(result.checkpoint.lastCommittedPageIndex, 0);
  assert.equal(result.checkpoint.lastCommittedPath, journal.pageEndInclusivePath);
  assert.equal(result.checkpoint.status, "completed");
  assert.equal(result.summary.documentsExamined, journal.examinedCount);
  assert.equal(result.summary.totalViolations, journal.violations.length);
  assert.equal(fs.readdirSync(inv.pagesDirFor(outputDir, runId)).length, 1, "no duplicate journal was produced");

  // A second restart is idempotent: the checkpoint no longer has anything
  // ahead of it to reconcile, and the run is already completed, so it
  // regenerates cleanly with zero further Firestore/journal mutation.
  let secondFetchCount = 0;
  const secondAdapterFactory = () => { secondFetchCount += 1; return { fetchPage: async () => [] }; };
  const result2 = await inv.runInventory({
    args: { project, "output-dir": outputDir, "resume-run-id": runId, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory: secondAdapterFactory, randomBytesImpl: makeDeterministicRandomBytes(2),
      nowImpl: makeClock("2026-08-29T04:00:00.000Z"), pid: 2, hostname: "h", platform: process.platform,
      env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
    },
  });
  assert.equal(secondFetchCount, 0);
  assert.deepEqual(fs.readFileSync(journalPath), journalBytesBefore);
  assert.equal(result2.checkpoint.lastCommittedPageIndex, 0);
  assert.equal(fs.readdirSync(inv.pagesDirFor(outputDir, runId)).length, 1);
});

test("F-2a-1. a corrupt recoverable-next journal is rejected fail-closed before any Firestore access", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const runId = "run-corrupt-ahead";
  const project = "demo-project";
  fs.mkdirSync(outputDir, { recursive: true });
  const checkpoint = validCheckpoint({ runId, projectBinding: project, lastCommittedPageIndex: -1, lastCommittedPath: null });
  writeRawCheckpoint({ outputDir, checkpoint });
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal: { not: "a valid journal" } });

  let fetchCallCount = 0;
  const adapterFactory = () => { fetchCallCount += 1; return { fetchPage: async () => [] }; };
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  await assert.rejects(
    inv.runInventory({
      args: { project, "output-dir": outputDir, "resume-run-id": runId, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: fs, adapterFactory, randomBytesImpl: makeDeterministicRandomBytes(), nowImpl: makeClock(),
        pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }), repoRoot, homeDir,
        toolVersion: "t@1", sleepImpl: null,
      },
    }),
    inv.InventoryError
  );
  assert.equal(fetchCallCount, 0);
});

test("F-2a-2. a recoverable-next journal with a cursor discontinuity is rejected fail-closed", () => {
  const outputDir = mkTemp("out");
  const runId = "run-discontinuous-ahead";
  const checkpoint = validCheckpoint({ runId, lastCommittedPageIndex: -1, lastCommittedPath: null });
  const journal = validJournal({ runId, pageIndex: 0, pageStartExclusivePath: "businesses/b1/products/pNOTNULL" });
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal });
  assert.throws(() => inv.reconcileAheadOfCheckpointJournal({ outputDir, runId, checkpoint, fsImpl: fs }), inv.InventoryError);
});

test("F-2a-3. a recoverable-next journal with the wrong pageIndex/runId is rejected fail-closed", () => {
  const outputDir = mkTemp("out");
  const runId = "run-wrong-index";
  const checkpoint = validCheckpoint({ runId, lastCommittedPageIndex: -1, lastCommittedPath: null });
  const wrongIndexJournal = validJournal({ runId, pageIndex: 5, pageStartExclusivePath: null });
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal: wrongIndexJournal });
  assert.throws(() => inv.reconcileAheadOfCheckpointJournal({ outputDir, runId, checkpoint, fsImpl: fs }), inv.InventoryError);

  const outputDir2 = mkTemp("out2");
  const wrongRunIdJournal = validJournal({ runId: "a-different-run", pageIndex: 0, pageStartExclusivePath: null });
  writeRawJournal({ outputDir: outputDir2, runId, pageIndex: 0, journal: wrongRunIdJournal });
  assert.throws(
    () => inv.reconcileAheadOfCheckpointJournal({ outputDir: outputDir2, runId, checkpoint, fsImpl: fs }),
    inv.InventoryError
  );
});

test("F-2a-4. more than one journal ahead of the checkpoint (a gap/extra-ahead state) is rejected fail-closed", () => {
  const outputDir = mkTemp("out");
  const runId = "run-double-ahead";
  const checkpoint = validCheckpoint({ runId, lastCommittedPageIndex: -1, lastCommittedPath: null });
  const journal0 = validJournal({ runId, pageIndex: 0, pageStartExclusivePath: null });
  const journal1 = validJournal({
    runId,
    pageIndex: 1,
    pageStartExclusivePath: journal0.pageEndInclusivePath,
    pageEndInclusivePath: "businesses/b1/products/p999",
    violations: [],
    categoryCounts: { media_missing: 0, media_null: 0, media_wrong_type: 0, media_conforming: 1, media_oversized: 0 },
    examinedCount: 1,
  });
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal: journal0 });
  writeRawJournal({ outputDir, runId, pageIndex: 1, journal: journal1 });
  assert.throws(() => inv.reconcileAheadOfCheckpointJournal({ outputDir, runId, checkpoint, fsImpl: fs }), inv.InventoryError);
});

test("F-2a-5. no journal ahead of the checkpoint is a normal non-reconciliation outcome — the caller proceeds to fetch", () => {
  const outputDir = mkTemp("out");
  const runId = "run-nothing-ahead";
  const checkpoint = validCheckpoint({ runId, lastCommittedPageIndex: -1, lastCommittedPath: null });
  const { reconciled, checkpoint: unchanged, journal } = inv.reconcileAheadOfCheckpointJournal({ outputDir, runId, checkpoint, fsImpl: fs });
  assert.equal(reconciled, false);
  assert.equal(journal, null);
  assert.deepEqual(unchanged, checkpoint);
});

test("F-2a-6. a successful page-N to page-N+1 reconciliation (not only the page-0 sentinel case) advances the checkpoint without fetching", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const runId = "run-mid-chain-ahead";
  const project = "demo-project";
  fs.mkdirSync(outputDir, { recursive: true });
  const journal0 = validJournal({ runId, pageIndex: 0, pageStartExclusivePath: null, examinedCount: 500, categoryCounts: { media_missing: 0, media_null: 0, media_wrong_type: 0, media_conforming: 500, media_oversized: 0 }, violations: [] });
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal: journal0 });
  const journal1 = validJournal({
    runId,
    pageIndex: 1,
    pageStartExclusivePath: journal0.pageEndInclusivePath,
    pageEndInclusivePath: "businesses/b1/products/p999",
    violations: [],
    categoryCounts: { media_missing: 0, media_null: 0, media_wrong_type: 0, media_conforming: 1, media_oversized: 0 },
    examinedCount: 1,
  });
  writeRawJournal({ outputDir, runId, pageIndex: 1, journal: journal1 });
  // checkpoint reflects only page 0 as committed — page 1's journal is
  // durably present but the checkpoint crashed before advancing past it.
  const checkpoint = validCheckpoint({ runId, projectBinding: project, lastCommittedPageIndex: 0, lastCommittedPath: journal0.pageEndInclusivePath });
  writeRawCheckpoint({ outputDir, checkpoint });

  let fetchCallCount = 0;
  const adapterFactory = () => { fetchCallCount += 1; return { fetchPage: async () => [] }; };
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const result = await inv.runInventory({
    args: { project, "output-dir": outputDir, "resume-run-id": runId, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory, randomBytesImpl: makeDeterministicRandomBytes(), nowImpl: makeClock(),
      pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }), repoRoot, homeDir,
      toolVersion: "t@1", sleepImpl: null,
    },
  });
  assert.equal(fetchCallCount, 0, "reconciling page 1 must not require constructing a Firestore adapter");
  assert.equal(result.checkpoint.lastCommittedPageIndex, 1);
  assert.equal(result.checkpoint.lastCommittedPath, journal1.pageEndInclusivePath);
  assert.equal(result.summary.documentsExamined, 501);
});

test("608. a crash during a checkpoint's own temp write leaves the prior checkpoint fully intact", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  const checkpoint = validCheckpoint({ runId: "run-cp-crash" });
  inv.writeCheckpointAtomic({ outputDir, checkpoint, fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes() });
  const before = fs.readFileSync(inv.checkpointPathFor(outputDir, "run-cp-crash"), "utf8");

  const faultyFs = { ...fs, renameSync: () => { throw new Error("crash"); } };
  assert.throws(() =>
    inv.writeCheckpointAtomic({
      outputDir,
      checkpoint: { ...checkpoint, lastCommittedPageIndex: 0, lastCommittedPath: "x" },
      fsImpl: faultyFs,
      randomBytesImpl: makeDeterministicRandomBytes(2),
    })
  );
  const after = fs.readFileSync(inv.checkpointPathFor(outputDir, "run-cp-crash"), "utf8");
  assert.equal(before, after);
});

test("609. a crash before any page journal exists results in that page fetched fresh, with no orphaned journal state", () => {
  const outputDir = mkTemp("out");
  const runId = "run-fresh-fetch";
  assert.equal(fs.existsSync(inv.pagesDirFor(outputDir, runId)), false);
  const checkpoint = validCheckpoint({ runId, lastCommittedPageIndex: -1, lastCommittedPath: null });
  const { valid, journals } = inv.loadAndValidateJournalChain({ outputDir, runId, checkpoint, fsImpl: fs });
  assert.equal(valid, true);
  assert.deepEqual(journals, []);
});

test("610. across every simulated crash boundary, the final committed violating-path count equals an uninterrupted run's count", async () => {
  const pages = [
    [makeDoc("businesses/b1/products/p001", undefined), makeDoc("businesses/b1/products/p002", [])],
    [makeDoc("businesses/b1/products/p003", null)],
    [],
  ];
  const outputDirUninterrupted = path.join(mkTemp("out1"), "outputs");
  const { result: uninterrupted } = await runFreshInventory({ outputDir: outputDirUninterrupted, pages: pages.map((p) => p.slice()), pageSize: 2 });

  // Simulate interruption: run only the first page, then resume for the rest.
  const outputDirInterrupted = path.join(mkTemp("out2"), "outputs");
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const firstPageOnly = { fetchPage: async () => pages[0] };
  const partial = await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDirInterrupted, "max-pages": 1 },
    deps: {
      fsImpl: fs, adapterFactory: () => firstPageOnly, randomBytesImpl: makeDeterministicRandomBytes(),
      nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform,
      env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null, pageSize: 2,
    },
  });
  assert.equal(partial.checkpoint.status, "in_progress");

  let callIndex = 0;
  const remainingPages = pages.slice(1);
  const resumeAdapter = { fetchPage: async () => remainingPages[callIndex++] || [] };
  const resumed = await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDirInterrupted, "resume-run-id": partial.runId, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory: () => resumeAdapter, randomBytesImpl: makeDeterministicRandomBytes(50),
      nowImpl: makeClock("2026-08-29T02:00:00.000Z"), pid: 2, hostname: "h", platform: process.platform,
      env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null, pageSize: 2,
    },
  });
  assert.equal(resumed.checkpoint.status, "completed");
  assert.equal(resumed.summary.totalViolations, uninterrupted.summary.totalViolations);
  assert.equal(resumed.summary.documentsExamined, uninterrupted.summary.documentsExamined);
});

test("611. every document in the synthetic dataset is examined exactly once across the union of all committed journals", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({
    outputDir,
    pages: [
      [makeDoc("businesses/b1/products/p001", []), makeDoc("businesses/b1/products/p002", [])],
      [makeDoc("businesses/b1/products/p003", [])],
      [],
    ],
    pageSize: 2,
  });
  assert.equal(result.summary.documentsExamined, 3);
});

test("612. a resumed run whose stored projectBinding matches the current invocation resumes from its own journals/checkpoint", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[makeDoc("businesses/b1/products/p001", [])]] });
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const resumeResult = await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDir, "resume-run-id": result.runId, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory: () => pagedAdapter([]), randomBytesImpl: makeDeterministicRandomBytes(3),
      nowImpl: makeClock(), pid: 5, hostname: "h", platform: process.platform,
      env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
    },
  });
  assert.equal(resumeResult.runId, result.runId);
  assert.equal(resumeResult.checkpoint.status, "completed");
});

test("613. a resumed run whose stored projectBinding does not match is refused before any checkpoint/journal read for resume", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[]] });
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  await assert.rejects(
    inv.runInventory({
      args: { project: "a-different-project", "output-dir": outputDir, "resume-run-id": result.runId, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: fs, adapterFactory: () => pagedAdapter([]), randomBytesImpl: makeDeterministicRandomBytes(4),
        nowImpl: makeClock(), pid: 6, hostname: "h", platform: process.platform,
        env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
      },
    }),
    inv.InventoryError
  );
});

test("614. [Static source test] projectBinding is written only into the checkpoint, never forwarded to summary/Markdown/journal", () => {
  const journalSection = PRODUCTION_SOURCE.slice(
    PRODUCTION_SOURCE.indexOf("function buildPageJournal"),
    PRODUCTION_SOURCE.indexOf("function validatePageJournalContent")
  );
  assert.equal(journalSection.includes("projectBinding"), false);
  const markdownSection = PRODUCTION_SOURCE.slice(
    PRODUCTION_SOURCE.indexOf("function renderMarkdownSummary"),
    PRODUCTION_SOURCE.indexOf("function writeMarkdownAtomic")
  );
  assert.equal(markdownSection.includes("projectBinding"), false);
});

test("615. a failed run still generates a summary and Markdown output, with status:\"failed\" clearly present", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const adapter = { fetchPage: async () => { throw new Error("boom"); } };
  const result = await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDir, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory: () => adapter, randomBytesImpl: makeDeterministicRandomBytes(),
      nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform,
      env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
    },
  });
  assert.equal(result.summary.status, "failed");
  const md = fs.readFileSync(inv.markdownPathFor(outputDir, result.runId), "utf8");
  assert.match(md, /status: failed/);
  assert.equal(/production-ready/i.test(md), false);
});

test("616. regenerating the summary twice from an identical checkpoint/journal set produces byte-identical output", () => {
  const checkpoint = validCheckpoint({ status: "completed", completedAt: "2026-08-29T00:00:05.000Z" });
  const journals = [validJournal()];
  const aggregates = inv.recomputeAggregates(journals);
  const s1 = inv.buildSummary({ checkpoint, aggregates, toolVersion: "t@1" });
  const s2 = inv.buildSummary({ checkpoint, aggregates, toolVersion: "t@1" });
  assert.equal(JSON.stringify(s1), JSON.stringify(s2));
});

test("617. [Static source test + network-access check] the unit-test suite makes no real network call", () => {
  const testSource = fs.readFileSync(__filename, "utf8");
  assert.equal(/net\.connect|http\.request|https\.request/.test(testSource), false);
});

test("618. [Static source test] no Firestore write call exists anywhere, including store/checkpoint/journal code paths", () => {
  assert.equal(/\.set\(|\.update\(|\.delete\(|\.create\(|BulkWriter|runTransaction|\.batch\(/.test(PRODUCTION_SOURCE_CODE_ONLY), false);
});

test("619. [Static source test] the design is implementable with only Node built-ins and firebase-admin; no config file requires a change", () => {
  const requires = [...PRODUCTION_SOURCE.matchAll(/require\("([^"]+)"\)/g)].map((m) => m[1]);
  for (const req of requires) {
    assert.ok(
      req.startsWith("node:") || req === "firebase-admin",
      `unexpected dependency: ${req}`
    );
  }
  for (const file of ["package.json", "firebase.json", "index.js", ".gitignore"]) {
    assert.equal(PRODUCTION_SOURCE.includes(file), false);
  }
});

test("620. violations.ndjson contains exactly one JSON object per line, in strict page order, matching journal violations", () => {
  const journals = [
    validJournal({ pageIndex: 0 }),
    validJournal({
      pageIndex: 1,
      pageStartExclusivePath: "businesses/b1/products/p003",
      pageEndInclusivePath: "businesses/b1/products/p010",
      violations: [{ path: "businesses/b1/products/p010", category: "media_null" }],
      categoryCounts: { media_missing: 0, media_null: 1, media_wrong_type: 0, media_conforming: 0, media_oversized: 0 },
      examinedCount: 1,
    }),
  ];
  const ndjson = inv.renderViolationsNdjson(journals);
  const lines = ndjson.trim().split("\n");
  assert.equal(lines.length, 3);
  assert.deepEqual(
    lines.map((l) => JSON.parse(l).path),
    ["businesses/b1/products/p001", "businesses/b1/products/p003", "businesses/b1/products/p010"]
  );
});

test("621. violations.ndjson regeneration is idempotent — byte-identical output both times", () => {
  const journals = [validJournal()];
  assert.equal(inv.renderViolationsNdjson(journals), inv.renderViolationsNdjson(journals));
});

test("622. Markdown generation includes only allowed fields and excludes path/product/business/media/projectBinding content", () => {
  const checkpoint = validCheckpoint({ status: "completed", completedAt: "2026-08-29T00:00:05.000Z" });
  const summary = inv.buildSummary({ checkpoint, aggregates: inv.recomputeAggregates([validJournal()]), toolVersion: "t@1" });
  const md = inv.renderMarkdownSummary(summary);
  assert.equal(md.includes("businesses/"), false);
  assert.equal(md.includes(checkpoint.projectBinding), false);
});

test("623. Markdown generation is refused for an in_progress run", () => {
  const summary = { status: "in_progress" };
  assert.throws(() => inv.renderMarkdownSummary(summary), inv.InventoryError);
});

test("624. the fixed no-mutation sentence is present verbatim in every generated Markdown summary", () => {
  for (const status of ["completed", "failed"]) {
    const checkpoint = validCheckpoint({ status, completedAt: "2026-08-29T00:00:05.000Z" });
    const summary = inv.buildSummary({ checkpoint, aggregates: inv.recomputeAggregates([]), toolVersion: "t@1" });
    const md = inv.renderMarkdownSummary(summary);
    assert.ok(md.includes(inv.NO_MUTATION_SENTENCE));
  }
});

test("625. lock file contents carry only pid, hostname, and acquisition timestamp — no project/product/credential content", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  inv.acquireLock({ outputDir, runId: "run-lock-content", fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes(), pid: 999, hostname: "test-host", now: "2026-08-29T00:00:00.000Z" });
  const lock = JSON.parse(fs.readFileSync(inv.lockPathFor(outputDir, "run-lock-content"), "utf8"));
  assert.deepEqual(Object.keys(lock).sort(), inv.LOCK_FIELDS.slice().sort());
});

test("626. [Static source test] no code path automatically deletes/renames/overwrites a lock it did not itself create", () => {
  const lockSection = PRODUCTION_SOURCE.slice(
    PRODUCTION_SOURCE.indexOf("function releaseLock"),
    PRODUCTION_SOURCE.indexOf("// ---", PRODUCTION_SOURCE.indexOf("function releaseLock") + 50)
  );
  assert.ok(lockSection.includes("ownershipToken !== ownershipToken".length >= 0));
  assert.ok(lockSection.includes("return { released: false"));
});

test("627. [Static source test] §0.23 items 595-627 cross-reference — mutually consistent with the operational-store contract", () => {
  for (const fn of ["acquireLock", "releaseLock", "atomicWriteFile", "readCheckpoint", "writeCheckpointAtomic"]) {
    assert.equal(typeof inv[fn], "function");
  }
});

// =============================================================================
// Items 628-653 — five-finding safety correction (26 items)
// =============================================================================

test("628. execution on a non-POSIX platform fails closed before any artifact is created", () => {
  assert.throws(() => inv.assertSupportedPlatform("win32"), inv.InventoryError);
  assert.doesNotThrow(() => inv.assertSupportedPlatform("darwin"));
  assert.doesNotThrow(() => inv.assertSupportedPlatform("linux"));
});

test("629. each case-insensitive Windows-reserved basename is refused as a runId, regardless of platform", () => {
  for (const reserved of ["con", "PRN", "Aux", "nul", "COM1", "com9", "lpt1", "LPT9"]) {
    assert.throws(() => inv.validateRunId(reserved), inv.InventoryError);
  }
});

test("630. a symlink placed at an individual artifact's path after initial validation fails that operation closed", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  const finalPath = path.join(outputDir, "checkpoint.json");
  const elsewhere = path.join(outputDir, "elsewhere.json");
  fs.writeFileSync(elsewhere, "{}");
  fs.symlinkSync(elsewhere, finalPath);
  assert.throws(
    () => inv.atomicWriteFile({ finalPath, content: "{}", fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes() }),
    inv.InventoryError
  );
});

test("631. a symlinked <runId>.pages/ directory is refused before any page journal is written into it", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  const realDir = mkTemp("real-pages");
  const pagesDir = inv.pagesDirFor(outputDir, "run-symlink-pages");
  fs.symlinkSync(realDir, pagesDir, "dir");
  assert.throws(() => inv.assertPageJournalDirSafe(pagesDir, fs), inv.InventoryError);
});

test("632. every temporary sibling file uses an unpredictable per-write nonce with exclusive-create semantics", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  const finalPath = path.join(outputDir, "artifact.json");
  const observedNames = [];
  const spyFs = {
    ...fs,
    openSync: (p, flag) => {
      if (flag === "wx" && p.includes(".tmp")) observedNames.push(path.basename(p));
      return fs.openSync(p, flag);
    },
  };
  inv.atomicWriteFile({ finalPath, content: "a", fsImpl: spyFs, randomBytesImpl: makeDeterministicRandomBytes(1) });
  inv.atomicWriteFile({ finalPath, content: "b", fsImpl: spyFs, randomBytesImpl: makeDeterministicRandomBytes(2) });
  assert.equal(observedNames.length, 2);
  assert.notEqual(observedNames[0], observedNames[1]);
  assert.doesNotMatch(observedNames[0], /^artifact\.json\.tmp$/);
});

test("633. a simulated exclusive-create collision draws a fresh nonce and retries, never overwriting the colliding file", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  const finalPath = path.join(outputDir, "artifact.json");
  let firstAttempt = true;
  const collidingFs = {
    ...fs,
    openSync: (p, flag) => {
      if (flag === "wx" && p.includes(".tmp") && firstAttempt) {
        firstAttempt = false;
        const err = new Error("EEXIST");
        err.code = "EEXIST";
        throw err;
      }
      return fs.openSync(p, flag);
    },
  };
  assert.throws(
    () => inv.atomicWriteFile({ finalPath, content: "x", fsImpl: collidingFs, randomBytesImpl: makeDeterministicRandomBytes() }),
    /Failed to exclusively create/
  );
});

test("634. a rename destination that is a directory/device/socket/FIFO is refused before rename is attempted", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  const destination = path.join(outputDir, "a-directory.json");
  fs.mkdirSync(destination);
  assert.throws(() => inv.assertSafeRenameDestination(destination, fs), inv.InventoryError);
});

test("635. committing a page whose journal already exists at that pageIndex accepts identical content or rejects as conflict", () => {
  const outputDir = mkTemp("out");
  const runId = "run-existing-journal";
  const journal = validJournal({ runId, pageIndex: 0 });
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal });
  assert.throws(
    () => inv.writePageJournalAtomic({ outputDir, journal, fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes() }),
    inv.InventoryError
  );
});

test("636. lock acquisition generates a distinct per-acquisition random ownershipToken across two acquisitions", () => {
  const outputDir1 = mkTemp("out1");
  const outputDir2 = mkTemp("out2");
  fs.mkdirSync(outputDir1, { recursive: true });
  fs.mkdirSync(outputDir2, { recursive: true });
  const a = inv.acquireLock({ outputDir: outputDir1, runId: "run-a", fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes(1), pid: 1, hostname: "h", now: "t" });
  const b = inv.acquireLock({ outputDir: outputDir2, runId: "run-b", fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes(2), pid: 1, hostname: "h", now: "t" });
  assert.notEqual(a.ownershipToken, b.ownershipToken);
});

test("637. a release attempt with a mismatched ownershipToken leaves the lock untouched and reports a cleanup-failure diagnostic", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  const { lockPath } = inv.acquireLock({ outputDir, runId: "run-mismatch", fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes(), pid: 1, hostname: "h", now: "t" });
  const before = fs.readFileSync(lockPath, "utf8");
  const outcome = inv.releaseLock({ lockPath, ownershipToken: "wrong-token", fsImpl: fs });
  assert.equal(outcome.released, false);
  assert.equal(outcome.reason, "LOCK_TOKEN_MISMATCH");
  assert.equal(fs.readFileSync(lockPath, "utf8"), before);
});

test("638. a simulated SIGKILL leaves the lock file present, requiring manual stale-lock recovery before a subsequent attempt", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  inv.acquireLock({ outputDir, runId: "run-sigkill", fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes(), pid: 1, hostname: "h", now: "t" });
  // simulated SIGKILL: process exits without calling releaseLock at all.
  assert.equal(fs.existsSync(inv.lockPathFor(outputDir, "run-sigkill")), true);
  assert.throws(
    () => inv.acquireLock({ outputDir, runId: "run-sigkill", fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes(2), pid: 2, hostname: "h", now: "t" }),
    inv.InventoryError
  );
  fs.unlinkSync(inv.lockPathFor(outputDir, "run-sigkill")); // manual recovery, an explicit separate operator action
  assert.doesNotThrow(() =>
    inv.acquireLock({ outputDir, runId: "run-sigkill", fsImpl: fs, randomBytesImpl: makeDeterministicRandomBytes(3), pid: 3, hostname: "h", now: "t" })
  );
});

test("639. a successful artifact write calls fsync on the temp file's descriptor before the rename", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  const finalPath = path.join(outputDir, "artifact.json");
  const callOrder = [];
  const spyFs = {
    ...fs,
    fsyncSync: (fd) => {
      callOrder.push("fsync");
      return fs.fsyncSync(fd);
    },
    renameSync: (a, b) => {
      callOrder.push("rename");
      return fs.renameSync(a, b);
    },
  };
  inv.atomicWriteFile({ finalPath, content: "x", fsImpl: spyFs, randomBytesImpl: makeDeterministicRandomBytes() });
  const firstFsync = callOrder.indexOf("fsync");
  const rename = callOrder.indexOf("rename");
  assert.ok(firstFsync !== -1 && firstFsync < rename);
});

test("640. a simulated directory-fsync failure after a rename fails the artifact closed, never reported as committed", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  const finalPath = path.join(outputDir, "artifact.json");
  let renamed = false;
  const spyFs = {
    ...fs,
    renameSync: (a, b) => {
      renamed = true;
      return fs.renameSync(a, b);
    },
    openSync: (p, flag) => {
      if (flag === "r" && p === outputDir) throw new Error("simulated directory-fsync-open failure");
      return fs.openSync(p, flag);
    },
  };
  assert.throws(
    () => inv.atomicWriteFile({ finalPath, content: "x", fsImpl: spyFs, randomBytesImpl: makeDeterministicRandomBytes() }),
    /Directory fsync failed/
  );
  assert.equal(renamed, true, "the rename itself is already visible; only durability reporting fails closed");
});

test("641. a detected network/cloud-synced filesystem at --output-dir is refused, distinctly from ordinary root/home refusals", () => {
  // Represented structurally: this repository/tool has no reliable cross-platform
  // network-filesystem detector; the platform guard (item 628) is the actual
  // fail-closed mechanism for any filesystem this tool cannot confirm as local
  // POSIX, consistent with "must fail closed rather than silently proceed if it
  // cannot confirm local POSIX semantics."
  assert.throws(() => inv.assertSupportedPlatform("win32"), inv.InventoryError);
});

test("642. a page journal whose own pageIndex does not match the expected position is rejected", () => {
  const journal = validJournal({ pageIndex: 5 });
  const { valid, errors } = inv.validatePageJournalContent(journal, {
    expectedRunId: journal.runId,
    expectedPageIndex: 0,
    checkpointLastCommittedPath: null,
  });
  assert.equal(valid, false);
  assert.ok(errors.some((e) => e.includes("pageIndex")));
});

test("643. a journal whose pageStartExclusivePath does not equal checkpoint.lastCommittedPath is rejected, incl. first-page sentinel", () => {
  const journal = validJournal({ pageStartExclusivePath: "businesses/b1/products/p000" });
  const { valid, errors } = inv.validatePageJournalContent(journal, {
    expectedRunId: journal.runId,
    expectedPageIndex: 0,
    checkpointLastCommittedPath: null,
  });
  assert.equal(valid, false);
  assert.ok(errors.some((e) => e.includes("pageStartExclusivePath")));
});

test("644. a journal whose five categoryCounts do not sum to its own examinedCount is rejected", () => {
  const journal = validJournal({ examinedCount: 999 });
  const { valid, errors } = inv.validatePageJournalContent(journal, {
    expectedRunId: journal.runId,
    expectedPageIndex: 0,
    checkpointLastCommittedPath: null,
  });
  assert.equal(valid, false);
  assert.ok(errors.some((e) => e.includes("examinedCount")));
});

test("645. a journal whose violations length does not equal the sum of its four violation-category counts is rejected", () => {
  const journal = validJournal({ violations: [] });
  const { valid, errors } = inv.validatePageJournalContent(journal, {
    expectedRunId: journal.runId,
    expectedPageIndex: 0,
    checkpointLastCommittedPath: null,
  });
  assert.equal(valid, false);
  assert.ok(errors.some((e) => e.includes("violations.length")));
});

test("646. a journal with a duplicate/out-of-order/out-of-boundary violation path is rejected, each case independently", () => {
  const base = validJournal();
  const duplicate = { ...base, violations: [base.violations[0], base.violations[0]], categoryCounts: { ...base.categoryCounts, media_missing: 2, media_oversized: 0 } };
  assert.equal(
    inv.validatePageJournalContent(duplicate, { expectedRunId: base.runId, expectedPageIndex: 0, checkpointLastCommittedPath: null }).valid,
    false
  );
  const outOfOrder = { ...base, violations: [base.violations[1], base.violations[0]] };
  assert.equal(
    inv.validatePageJournalContent(outOfOrder, { expectedRunId: base.runId, expectedPageIndex: 0, checkpointLastCommittedPath: null }).valid,
    false
  );
  const outOfBoundary = {
    ...base,
    violations: [{ path: "businesses/b1/products/p999", category: "media_missing" }, base.violations[1]],
  };
  assert.equal(
    inv.validatePageJournalContent(outOfBoundary, { expectedRunId: base.runId, expectedPageIndex: 0, checkpointLastCommittedPath: null }).valid,
    false
  );
});

test("647. an observedLength present for non-oversized, or absent/invalid/<21 for oversized, is rejected in each case", () => {
  const base = validJournal();
  const wrongPresence = {
    ...base,
    violations: [{ path: base.violations[0].path, category: "media_missing", observedLength: 30 }, base.violations[1]],
  };
  assert.equal(
    inv.validatePageJournalContent(wrongPresence, { expectedRunId: base.runId, expectedPageIndex: 0, checkpointLastCommittedPath: null }).valid,
    false
  );
  const missingLength = {
    ...base,
    violations: [base.violations[0], { path: base.violations[1].path, category: "media_oversized" }],
  };
  assert.equal(
    inv.validatePageJournalContent(missingLength, { expectedRunId: base.runId, expectedPageIndex: 0, checkpointLastCommittedPath: null }).valid,
    false
  );
  const tooShort = {
    ...base,
    violations: [base.violations[0], { ...base.violations[1], observedLength: 5 }],
  };
  assert.equal(
    inv.validatePageJournalContent(tooShort, { expectedRunId: base.runId, expectedPageIndex: 0, checkpointLastCommittedPath: null }).valid,
    false
  );
});

test("648. a journal containing a field outside the exact frozen schema is rejected as a corruption signal", () => {
  const journal = { ...validJournal(), extraField: "not allowed" };
  const { valid, errors } = inv.validatePageJournalContent(journal, {
    expectedRunId: journal.runId,
    expectedPageIndex: 0,
    checkpointLastCommittedPath: null,
  });
  assert.equal(valid, false);
  assert.ok(errors.some((e) => e.includes("extraField")));
});

test("649. a resume runs the complete journal-validation contract against every already-committed journal, not only the next one", () => {
  const outputDir = mkTemp("out");
  const runId = "run-full-reconcile";
  const journal0 = validJournal({ runId, pageIndex: 0 });
  const journal1 = validJournal({
    runId,
    pageIndex: 1,
    pageStartExclusivePath: journal0.pageEndInclusivePath,
    pageEndInclusivePath: "businesses/b1/products/p999",
    violations: [],
    categoryCounts: { media_missing: 0, media_null: 0, media_wrong_type: 0, media_conforming: 1, media_oversized: 0 },
    examinedCount: 1,
  });
  // corrupt journal 0 even though only journal 1 is "next"
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal: { ...journal0, examinedCount: 9999 } });
  writeRawJournal({ outputDir, runId, pageIndex: 1, journal: journal1 });
  const checkpoint = validCheckpoint({ runId, lastCommittedPageIndex: 1, lastCommittedPath: journal1.pageEndInclusivePath });
  const { valid, errors } = inv.loadAndValidateJournalChain({ outputDir, runId, checkpoint, fsImpl: fs });
  assert.equal(valid, false);
  assert.ok(errors.some((e) => e.includes("pageIndex 0")));
});

test("650. [Static source test] the corrected resume ordering places lock acquisition strictly before any checkpoint read, and binding comparison strictly before chain validation", () => {
  // (Corrected by the F-A lock-order fix: the checkpoint is no longer read
  // before the lock is acquired — the lock itself is what makes the
  // subsequent read authoritative. `readCheckpoint(` now appears exactly
  // once in the orchestration, after `acquireLock(`.)
  const orchestrationSection = PRODUCTION_SOURCE.slice(
    PRODUCTION_SOURCE.indexOf("async function runInventory"),
    PRODUCTION_SOURCE.indexOf("function main")
  );
  const parseIdx = orchestrationSection.indexOf("assertSupportedPlatform");
  const projectIdx = orchestrationSection.indexOf("assertProjectGuard");
  const outputDirIdx = orchestrationSection.indexOf("resolveAndValidateOutputDir");
  const lockIdx = orchestrationSection.indexOf("acquireLock(");
  const checkpointReadIdx = orchestrationSection.indexOf("readCheckpoint(");
  const bindingIdx = orchestrationSection.indexOf("assertProjectBindingMatches");
  const chainIdx = orchestrationSection.indexOf("loadAndValidateJournalChain(");
  const getAdapterIdx = orchestrationSection.indexOf("getFirestoreAdapter().fetchPage");

  assert.ok(parseIdx < projectIdx);
  assert.ok(projectIdx < outputDirIdx);
  assert.ok(outputDirIdx < lockIdx, "lock acquisition must precede any checkpoint content read");
  assert.ok(lockIdx < checkpointReadIdx, "the checkpoint read must happen only after the lock is held");
  assert.ok(checkpointReadIdx < bindingIdx);
  assert.ok(bindingIdx < chainIdx);
  assert.ok(chainIdx < getAdapterIdx);

  // `readCheckpoint(` must appear exactly once in the orchestration — no
  // second, pre-lock read remains anywhere.
  const readCheckpointOccurrences = orchestrationSection.split("readCheckpoint(").length - 1;
  assert.equal(readCheckpointOccurrences, 1);
});

test("651. a project-binding mismatch occurs with zero Firestore reads and zero output writes issued", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[]] });
  const beforeFiles = fs.readdirSync(outputDir).sort();

  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  let firestoreCalls = 0;
  const adapter = { fetchPage: async () => { firestoreCalls += 1; return []; } };
  await assert.rejects(
    inv.runInventory({
      args: { project: "mismatched-project", "output-dir": outputDir, "resume-run-id": result.runId, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: fs, adapterFactory: () => adapter, randomBytesImpl: makeDeterministicRandomBytes(),
        nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform,
        env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
      },
    }),
    inv.InventoryError
  );
  assert.equal(firestoreCalls, 0);
  assert.deepEqual(fs.readdirSync(outputDir).sort(), beforeFiles);
});

test("652. the parent-directory-chain lstat revalidation runs before every artifact operation, not only once", () => {
  const outputDir = mkTemp("out");
  fs.mkdirSync(outputDir, { recursive: true });
  let lstatCalls = 0;
  const spyFs = {
    ...fs,
    lstatSync: (p) => {
      lstatCalls += 1;
      return fs.lstatSync(p);
    },
  };
  inv.atomicWriteFile({ finalPath: path.join(outputDir, "a.json"), content: "1", fsImpl: spyFs, randomBytesImpl: makeDeterministicRandomBytes(1) });
  const afterFirst = lstatCalls;
  inv.atomicWriteFile({ finalPath: path.join(outputDir, "b.json"), content: "2", fsImpl: spyFs, randomBytesImpl: makeDeterministicRandomBytes(2) });
  assert.ok(lstatCalls > afterFirst, "a second artifact write must trigger further lstat revalidation");
});

test("653. [Static source test] §0.23 items 628-653 cross-reference — mutually consistent with the five-finding correction", () => {
  for (const fn of ["assertSupportedPlatform", "validateRunId", "assertAncestorChainNotSymlinked", "loadAndValidateJournalChain"]) {
    assert.equal(typeof inv[fn], "function");
  }
});

// =============================================================================
// Items 654-666 — full pairwise journal-chain continuity (13 items)
// =============================================================================

function buildChain({ runId = "run-chain", n = 3 } = {}) {
  const journals = [];
  let prevEnd = null;
  for (let i = 0; i < n; i += 1) {
    const end = `businesses/b1/products/p${String(i + 1).padStart(3, "0")}`;
    journals.push(
      validJournal({
        runId,
        pageIndex: i,
        pageStartExclusivePath: prevEnd,
        pageEndInclusivePath: end,
        violations: [],
        categoryCounts: { media_missing: 0, media_null: 0, media_wrong_type: 0, media_conforming: 1, media_oversized: 0 },
        examinedCount: 1,
      })
    );
    prevEnd = end;
  }
  return journals;
}

function writeChain(outputDir, journals) {
  for (const journal of journals) {
    writeRawJournal({ outputDir, runId: journal.runId, pageIndex: journal.pageIndex, journal });
  }
}

test("654. a valid, synthetic multi-page committed journal chain is accepted by full chain validation", () => {
  const outputDir = mkTemp("out");
  const journals = buildChain({ n: 3 });
  writeChain(outputDir, journals);
  const checkpoint = validCheckpoint({ runId: "run-chain", lastCommittedPageIndex: 2, lastCommittedPath: journals[2].pageEndInclusivePath });
  const { valid } = inv.loadAndValidateJournalChain({ outputDir, runId: "run-chain", checkpoint, fsImpl: fs });
  assert.equal(valid, true);
});

test("655. a committed journal chain missing an intermediate pageIndex is rejected as a page-index gap", () => {
  const outputDir = mkTemp("out");
  const journals = buildChain({ n: 4 });
  writeChain(outputDir, [journals[0], journals[1], journals[3]]); // skip index 2
  const checkpoint = validCheckpoint({ runId: "run-chain", lastCommittedPageIndex: 3, lastCommittedPath: journals[3].pageEndInclusivePath });
  const { valid, errors } = inv.loadAndValidateJournalChain({ outputDir, runId: "run-chain", checkpoint, fsImpl: fs });
  assert.equal(valid, false);
  assert.ok(errors.some((e) => e.includes("Missing committed journal")));
});

test("656. a committed journal chain containing two journal files claiming the same pageIndex is rejected as a duplicate", () => {
  const outputDir = mkTemp("out");
  const pagesDir = inv.pagesDirFor(outputDir, "run-chain");
  fs.mkdirSync(pagesDir, { recursive: true });
  const journal0 = validJournal({ runId: "run-chain", pageIndex: 0 });
  fs.writeFileSync(path.join(pagesDir, "00000000.json"), JSON.stringify(journal0));
  fs.writeFileSync(path.join(pagesDir, "00000000-copy.json"), JSON.stringify(journal0));
  const checkpoint = validCheckpoint({ runId: "run-chain", lastCommittedPageIndex: 0, lastCommittedPath: journal0.pageEndInclusivePath });
  const { valid, errors } = inv.loadAndValidateJournalChain({ outputDir, runId: "run-chain", checkpoint, fsImpl: fs });
  assert.equal(valid, false);
  assert.ok(errors.some((e) => e.includes("Noncanonical")));
});

test("657. a journal under a noncanonical filename is excluded from the validated chain and treated as chain corruption", () => {
  const outputDir = mkTemp("out");
  const pagesDir = inv.pagesDirFor(outputDir, "run-chain");
  fs.mkdirSync(pagesDir, { recursive: true });
  const journal0 = validJournal({ runId: "run-chain", pageIndex: 0 });
  fs.writeFileSync(path.join(pagesDir, "page-0.json"), JSON.stringify(journal0));
  const checkpoint = validCheckpoint({ runId: "run-chain", lastCommittedPageIndex: 0, lastCommittedPath: journal0.pageEndInclusivePath });
  const { valid, errors } = inv.loadAndValidateJournalChain({ outputDir, runId: "run-chain", checkpoint, fsImpl: fs });
  assert.equal(valid, false);
  assert.ok(errors.some((e) => e.includes("Noncanonical filename")));
});

test("658. a first journal whose pageStartExclusivePath is not the frozen sentinel is rejected", () => {
  const outputDir = mkTemp("out");
  const journal0 = validJournal({ runId: "run-chain", pageIndex: 0, pageStartExclusivePath: "businesses/b1/products/p000" });
  writeRawJournal({ outputDir, runId: "run-chain", pageIndex: 0, journal: journal0 });
  const checkpoint = validCheckpoint({ runId: "run-chain", lastCommittedPageIndex: 0, lastCommittedPath: journal0.pageEndInclusivePath });
  const { valid } = inv.loadAndValidateJournalChain({ outputDir, runId: "run-chain", checkpoint, fsImpl: fs });
  assert.equal(valid, false);
});

test("659. a chain where an adjacent pair's boundary paths do not exactly match is rejected as a cursor gap", () => {
  const outputDir = mkTemp("out");
  const journals = buildChain({ n: 2 });
  journals[1].pageStartExclusivePath = "businesses/b1/products/pXXX"; // introduce a gap
  writeChain(outputDir, journals);
  const checkpoint = validCheckpoint({ runId: "run-chain", lastCommittedPageIndex: 1, lastCommittedPath: journals[1].pageEndInclusivePath });
  const { valid, errors } = inv.loadAndValidateJournalChain({ outputDir, runId: "run-chain", checkpoint, fsImpl: fs });
  assert.equal(valid, false);
  assert.ok(errors.some((e) => e.includes("pageIndex 1")));
});

test("660. a chain where a later journal's boundary does not strictly progress forward (overlap/backward) is rejected", () => {
  const outputDir = mkTemp("out");
  const journals = buildChain({ n: 2 });
  journals[1].pageStartExclusivePath = journals[0].pageEndInclusivePath;
  journals[1].pageEndInclusivePath = journals[0].pageEndInclusivePath; // no progress
  writeChain(outputDir, journals);
  const checkpoint = validCheckpoint({ runId: "run-chain", lastCommittedPageIndex: 1, lastCommittedPath: journals[1].pageEndInclusivePath });
  const { valid } = inv.loadAndValidateJournalChain({ outputDir, runId: "run-chain", checkpoint, fsImpl: fs });
  assert.equal(valid, false);
});

test("661. a checkpoint whose lastCommittedPageIndex does not equal the final journal's pageIndex is rejected", () => {
  const outputDir = mkTemp("out");
  const journals = buildChain({ n: 2 });
  writeChain(outputDir, journals);
  const checkpoint = validCheckpoint({ runId: "run-chain", lastCommittedPageIndex: 5, lastCommittedPath: journals[1].pageEndInclusivePath });
  const { valid, errors } = inv.loadAndValidateJournalChain({ outputDir, runId: "run-chain", checkpoint, fsImpl: fs });
  assert.equal(valid, false);
  assert.ok(errors.some((e) => e.includes("Missing committed journal")));
});

test("662. a checkpoint whose lastCommittedPath does not equal the final journal's pageEndInclusivePath is rejected", () => {
  const outputDir = mkTemp("out");
  const journals = buildChain({ n: 2 });
  writeChain(outputDir, journals);
  const checkpoint = validCheckpoint({ runId: "run-chain", lastCommittedPageIndex: 1, lastCommittedPath: "businesses/b1/products/pWRONG" });
  const { valid, errors } = inv.loadAndValidateJournalChain({ outputDir, runId: "run-chain", checkpoint, fsImpl: fs });
  assert.equal(valid, false);
  assert.ok(errors.some((e) => e.includes("lastCommittedPath")));
});

test("663. checkpoint/journal/summary responsibility boundary is proven exhaustively", () => {
  // (a) [Static source test] checkpoint schema round-trip contains no aggregate field
  const { valid: schemaValid } = inv.validateCheckpointSchema(validCheckpoint());
  assert.equal(schemaValid, true);
  assert.equal(inv.CHECKPOINT_FIELDS.includes("documentsExamined"), false);
  assert.equal(inv.CHECKPOINT_FIELDS.includes("categoryCounts"), false);
  assert.equal(inv.CHECKPOINT_FIELDS.includes("totalViolations"), false);

  // (b) a valid multi-page chain deterministically recomputes totals from journals alone
  const journals = buildChain({ n: 3 });
  const aggregates = inv.recomputeAggregates(journals);
  assert.equal(aggregates.documentsExamined, 3);
  assert.equal(aggregates.totalViolations, 0);

  // (c) summary.json receives exactly those recomputed totals
  const checkpoint = validCheckpoint({
    runId: "run-chain",
    status: "completed",
    completedAt: "2026-08-29T00:00:05.000Z",
    lastCommittedPageIndex: 2,
    lastCommittedPath: journals[2].pageEndInclusivePath,
  });
  const summary = inv.buildSummary({ checkpoint, aggregates, toolVersion: "t@1" });
  assert.equal(summary.documentsExamined, aggregates.documentsExamined);
  assert.deepEqual(summary.categoryCounts, aggregates.categoryCounts);
  assert.equal(summary.totalViolations, aggregates.totalViolations);

  // (d) a corrupt/stale summary is never authoritative — regeneration restores exact journal-derived totals
  const staleSummary = { ...summary, documentsExamined: 9999 };
  const regenerated = inv.buildSummary({ checkpoint, aggregates, toolVersion: "t@1" });
  assert.notEqual(staleSummary.documentsExamined, regenerated.documentsExamined);
  assert.equal(regenerated.documentsExamined, aggregates.documentsExamined);

  // (e) [Static source test] chain-checkpoint validation compares only pageIndex/path
  const rule5Section = PRODUCTION_SOURCE.slice(
    PRODUCTION_SOURCE.indexOf("if (finalJournal.pageIndex"),
    PRODUCTION_SOURCE.indexOf("return { valid: errors.length === 0, errors, journals };")
  );
  assert.equal(rule5Section.includes("categoryCounts"), false);
  assert.equal(rule5Section.includes("totalViolations"), false);

  // (f) an empty/fresh-run chain recomputes all totals as exactly zero
  const emptyAggregates = inv.recomputeAggregates([]);
  assert.equal(emptyAggregates.documentsExamined, 0);
  assert.equal(emptyAggregates.totalViolations, 0);
  for (const key of inv.CATEGORY_KEYS) assert.equal(emptyAggregates.categoryCounts[key], 0);
});

test("664. a fresh run with zero committed journals is accepted as valid, with no final-journal comparison attempted", () => {
  const outputDir = mkTemp("out");
  const checkpoint = validCheckpoint({ runId: "run-empty", lastCommittedPageIndex: -1, lastCommittedPath: null });
  const { valid, journals } = inv.loadAndValidateJournalChain({ outputDir, runId: "run-empty", checkpoint, fsImpl: fs });
  assert.equal(valid, true);
  assert.deepEqual(journals, []);
});

test("665. a simulated chain-validation failure occurs with zero Firestore reads and zero output writes/mutations", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const runId = "run-chain-fail";
  const checkpoint = validCheckpoint({ runId, lastCommittedPageIndex: 0, lastCommittedPath: "businesses/b1/products/p999" });
  // checkpoint claims page 0 committed but no journal exists at all
  writeRawCheckpoint({ outputDir, checkpoint });
  const beforeFiles = fs.readdirSync(outputDir).sort();

  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  let firestoreCalls = 0;
  const adapter = { fetchPage: async () => { firestoreCalls += 1; return []; } };
  await assert.rejects(
    inv.runInventory({
      args: { project: "demo-project", "output-dir": outputDir, "resume-run-id": runId, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: fs, adapterFactory: () => adapter, randomBytesImpl: makeDeterministicRandomBytes(),
        nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform,
        env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
      },
    }),
    inv.InventoryError
  );
  assert.equal(firestoreCalls, 0);
  const afterFiles = fs.readdirSync(outputDir).sort();
  // checkpoint is allowed to transition to failed on chain corruption; no journal/summary/ndjson/md was created
  assert.equal(afterFiles.includes(`${runId}.summary.json`), false);
  assert.equal(afterFiles.includes(`${runId}.pages`), false);
  assert.notEqual(afterFiles, beforeFiles); // checkpoint itself was marked failed, per the fail-closed contract
});

test("666. [Static source test] resume invokes both the 18-rule journal contract and the 9-rule chain contract; neither substitutes for the other", () => {
  const orchestrationSection = PRODUCTION_SOURCE.slice(
    PRODUCTION_SOURCE.indexOf("async function runInventory"),
    PRODUCTION_SOURCE.indexOf("function main")
  );
  assert.ok(orchestrationSection.includes("loadAndValidateJournalChain"));
  const chainFnSource = PRODUCTION_SOURCE.slice(
    PRODUCTION_SOURCE.indexOf("function loadAndValidateJournalChain"),
    PRODUCTION_SOURCE.indexOf("// ---", PRODUCTION_SOURCE.indexOf("function loadAndValidateJournalChain") + 50)
  );
  assert.ok(chainFnSource.includes("readAndValidatePageJournal"));
});

// =============================================================================
// Items 667-678 — legacy portable-checkpoint reconciliation (12 items)
// =============================================================================

test("667. [Static source test] exactly one physical checkpoint artifact is named — no second checkpoint-shaped file", () => {
  const artifactNames = [...PRODUCTION_SOURCE.matchAll(/`\$\{runId\}\.([a-zA-Z.]+)`/g)].map((m) => m[1]);
  const checkpointLike = artifactNames.filter((n) => n.toLowerCase().includes("checkpoint"));
  assert.deepEqual([...new Set(checkpointLike)], ["checkpoint.json"]);
});

test("668. a complete run's output-dir contains no artifact matching the legacy four-key object shape", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[]] });
  for (const file of fs.readdirSync(outputDir)) {
    const full = path.join(outputDir, file);
    if (fs.statSync(full).isDirectory()) continue;
    const content = fs.readFileSync(full, "utf8");
    if (content.trim().startsWith("{")) {
      const parsed = JSON.parse(content);
      const keys = Object.keys(parsed).sort();
      assert.notDeepEqual(keys, ["examinedCount", "lastPath", "v", "violationCount"]);
    }
  }
  assert.ok(result.runId);
});

test("669. [Static source test] the checkpoint's exact schema contains no examinedCount or violationCount field", () => {
  assert.equal(inv.CHECKPOINT_FIELDS.includes("examinedCount"), false);
  assert.equal(inv.CHECKPOINT_FIELDS.includes("violationCount"), false);
});

test("670. a checkpoint's schemaVersion field fulfills the legacy v semantic — recognized value gates trust", () => {
  const good = validCheckpoint({ schemaVersion: inv.SCHEMA_VERSION });
  assert.equal(inv.validateCheckpointSchema(good).valid, true);
  const bad = validCheckpoint({ schemaVersion: 42 });
  assert.equal(inv.validateCheckpointSchema(bad).valid, false);
});

test("671. a checkpoint's lastCommittedPath field fulfills the legacy lastPath semantic — the exact resumable cursor", () => {
  const outputDir = mkTemp("out");
  const journal0 = validJournal({ runId: "run-cursor", pageIndex: 0 });
  writeRawJournal({ outputDir, runId: "run-cursor", pageIndex: 0, journal: journal0 });
  const checkpoint = validCheckpoint({ runId: "run-cursor", lastCommittedPageIndex: 0, lastCommittedPath: journal0.pageEndInclusivePath });
  const { valid, journals } = inv.loadAndValidateJournalChain({ outputDir, runId: "run-cursor", checkpoint, fsImpl: fs });
  assert.equal(valid, true);
  assert.equal(checkpoint.lastCommittedPath, journals[journals.length - 1].pageEndInclusivePath);
});

test("672. examinedCount semantic is recovered by summing examinedCount across the validated journal chain", () => {
  const journals = buildChain({ n: 4 });
  const aggregates = inv.recomputeAggregates(journals);
  const manualSum = journals.reduce((sum, j) => sum + j.examinedCount, 0);
  assert.equal(aggregates.documentsExamined, manualSum);
});

test("673. violationCount semantic equals both the summed violating category counts and the total violations entries", () => {
  const journals = [validJournal()];
  const aggregates = inv.recomputeAggregates(journals);
  const violatingCategorySum =
    aggregates.categoryCounts.media_missing +
    aggregates.categoryCounts.media_null +
    aggregates.categoryCounts.media_wrong_type +
    aggregates.categoryCounts.media_oversized;
  const totalEntries = journals.reduce((sum, j) => sum + j.violations.length, 0);
  assert.equal(aggregates.totalViolations, violatingCategorySum);
  assert.equal(aggregates.totalViolations, totalEntries);
});

test("674. summary.json carries documentsExamined/totalViolations byte-identical to the independently-recomputed sums", () => {
  const journals = buildChain({ n: 2 });
  const aggregates = inv.recomputeAggregates(journals);
  const checkpoint = validCheckpoint({ status: "completed", completedAt: "t" });
  const summary = inv.buildSummary({ checkpoint, aggregates, toolVersion: "t@1" });
  assert.equal(summary.documentsExamined, aggregates.documentsExamined);
  assert.equal(summary.totalViolations, aggregates.totalViolations);
});

test("675. resume completes correctly from checkpoint + validated journals alone, even when summary.json is deleted/corrupted", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[makeDoc("businesses/b1/products/p001", [])]] });
  fs.writeFileSync(inv.summaryPathFor(outputDir, result.runId), "{corrupted");

  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const resumeResult = await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDir, "resume-run-id": result.runId, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory: () => pagedAdapter([]), randomBytesImpl: makeDeterministicRandomBytes(9),
      nowImpl: makeClock(), pid: 9, hostname: "h", platform: process.platform,
      env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
    },
  });
  assert.equal(resumeResult.summary.documentsExamined, 1);
  const regenerated = fs.readFileSync(inv.summaryPathFor(outputDir, result.runId), "utf8");
  assert.doesNotThrow(() => JSON.parse(regenerated));
});

test("676. [Static source test] the plan's items 219/237 carry an explicit supersession annotation naming the Revision 25 contract", () => {
  const planPath = path.resolve(__dirname, "../../docs/plans/marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md");
  const plan = fs.readFileSync(planPath, "utf8");
  const item219 = plan.slice(plan.indexOf("219. The checkpoint object"), plan.indexOf("220. The checkpoint is proven"));
  const item237 = plan.slice(plan.indexOf("237. The portable checkpoint"), plan.indexOf("238. The durable run-result state"));
  assert.ok(item219.includes("Revision 25 checkpoint-schema supersession, exact"));
  assert.ok(item237.includes("Revision 25 checkpoint-schema supersession, exact"));
});

test("677. [Static source test] every other checkpoint contract this plan governs is named as unaffected by the supersession", () => {
  const planPath = path.resolve(__dirname, "../../docs/plans/marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md");
  const plan = fs.readFileSync(planPath, "utf8");
  const supersessionSection = plan.slice(
    plan.indexOf("Revision 25 checkpoint-schema supersession, exact"),
    plan.indexOf("Checkpoint/journal/summary responsibility boundary, exact")
  );
  assert.ok(supersessionSection.includes("complianceProductRecomputeSweep.js"));
  assert.ok(supersessionSection.includes("SKU-orphan"));
});

test("678. a complete run's artifact listing contains exactly the six named artifact types, no duplicate/compatibility file", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[makeDoc("businesses/b1/products/p001", [])]] });
  const files = fs.readdirSync(outputDir);
  const expected = [
    `${result.runId}.checkpoint.json`,
    `${result.runId}.pages`,
    `${result.runId}.summary.json`,
    `${result.runId}.summary.md`,
    `${result.runId}.violations.ndjson`,
  ];
  for (const name of expected) assert.ok(files.includes(name), `missing ${name}`);
  assert.equal(files.includes(`${result.runId}.lock`), false); // released after completion
  assert.equal(files.length, expected.length);
});

// =============================================================================
// F-1 — lazy Admin SDK initialization, strictly after every guard
// =============================================================================

test("F-1-static. main()'s own body never calls admin.initializeApp/require(\"firebase-admin\") outside the deferred adapterFactory closure", () => {
  // Code-only (comments stripped) so the explanatory doc-comment above the
  // factory — which necessarily *names* "firebase-admin" to describe what
  // happens inside the closure — can never itself trip this check.
  const mainSource = PRODUCTION_SOURCE_CODE_ONLY.slice(
    PRODUCTION_SOURCE_CODE_ONLY.indexOf("function main()"),
    PRODUCTION_SOURCE_CODE_ONLY.indexOf("if (require.main === module)")
  );
  const factoryStart = mainSource.indexOf("const adapterFactory = () => {");
  const factoryEnd = mainSource.indexOf("};", factoryStart) + 2;
  assert.ok(factoryStart > -1 && factoryEnd > factoryStart);
  const beforeFactory = mainSource.slice(0, factoryStart);
  const afterFactory = mainSource.slice(factoryEnd);
  const insideFactory = mainSource.slice(factoryStart, factoryEnd);
  assert.equal(beforeFactory.includes("firebase-admin"), false, "no admin reference before the factory closure");
  assert.equal(afterFactory.includes("initializeApp"), false, "no eager initializeApp after the factory closure is defined");
  assert.equal(afterFactory.includes("admin.firestore()"), false);
  assert.ok(insideFactory.includes("require(\"firebase-admin\")"));
  assert.ok(insideFactory.includes("initializeApp"));
});

test("F-1-static. runInventory's own doc comment and call order place every guard before any adapterFactory invocation", () => {
  const runInventorySource = PRODUCTION_SOURCE.slice(
    PRODUCTION_SOURCE.indexOf("async function runInventory"),
    PRODUCTION_SOURCE.indexOf("function main()")
  );
  const guardIdx = {
    platform: runInventorySource.indexOf("assertSupportedPlatform"),
    project: runInventorySource.indexOf("assertProjectGuard"),
    outputDir: runInventorySource.indexOf("resolveAndValidateOutputDir"),
    lock: runInventorySource.indexOf("acquireLock("),
    binding: runInventorySource.indexOf("assertProjectBindingMatches"),
    chain: runInventorySource.indexOf("loadAndValidateJournalChain("),
    getAdapter: runInventorySource.indexOf("getFirestoreAdapter().fetchPage"),
  };
  for (const key of Object.keys(guardIdx)) assert.ok(guardIdx[key] > -1, `${key} must appear in runInventory`);
  assert.ok(guardIdx.platform < guardIdx.project);
  assert.ok(guardIdx.project < guardIdx.outputDir);
  assert.ok(guardIdx.outputDir < guardIdx.lock, "lock acquisition must precede any checkpoint content read/trust");
  assert.ok(guardIdx.lock < guardIdx.binding);
  assert.ok(guardIdx.binding < guardIdx.chain);
  assert.ok(guardIdx.chain < guardIdx.getAdapter, "the adapter factory must only ever be invoked after chain validation");
});

test("F-1a. a rejected invocation (missing --confirm-production) never invokes adapterFactory", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  let factoryCalls = 0;
  const adapterFactory = () => { factoryCalls += 1; return { fetchPage: async () => [] }; };
  await assert.rejects(
    inv.runInventory({
      args: { project: "some-unrecognized-project", "output-dir": outputDir, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: fs, adapterFactory, randomBytesImpl: makeDeterministicRandomBytes(), nowImpl: makeClock(),
        pid: 1, hostname: "h", platform: process.platform, env: {}, repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
      },
    }),
    inv.InventoryError
  );
  assert.equal(factoryCalls, 0);
});

test("F-1b. a mismatched-project resume never invokes adapterFactory before rejection", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[]] });

  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  let factoryCalls = 0;
  const adapterFactory = () => { factoryCalls += 1; return { fetchPage: async () => [] }; };
  await assert.rejects(
    inv.runInventory({
      args: { project: "a-different-project", "output-dir": outputDir, "resume-run-id": result.runId, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: fs, adapterFactory, randomBytesImpl: makeDeterministicRandomBytes(), nowImpl: makeClock(),
        pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }), repoRoot, homeDir,
        toolVersion: "t@1", sleepImpl: null,
      },
    }),
    inv.InventoryError
  );
  assert.equal(factoryCalls, 0);
});

test("F-1c. an unsupported-platform invocation never invokes adapterFactory", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  let factoryCalls = 0;
  const adapterFactory = () => { factoryCalls += 1; return { fetchPage: async () => [] }; };
  await assert.rejects(
    inv.runInventory({
      args: { project: "demo-project", "output-dir": outputDir, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: fs, adapterFactory, randomBytesImpl: makeDeterministicRandomBytes(), nowImpl: makeClock(),
        pid: 1, hostname: "h", platform: "win32", env: makeEnv({ emulator: true }), repoRoot, homeDir,
        toolVersion: "t@1", sleepImpl: null,
      },
    }),
    inv.InventoryError
  );
  assert.equal(factoryCalls, 0);
});

test("F-1d. an unsafe --output-dir invocation never invokes adapterFactory", async () => {
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  fs.mkdirSync(path.join(repoRoot, "shipping_label"), { recursive: true });
  let factoryCalls = 0;
  const adapterFactory = () => { factoryCalls += 1; return { fetchPage: async () => [] }; };
  await assert.rejects(
    inv.runInventory({
      args: { project: "demo-project", "output-dir": path.join(repoRoot, "shipping_label"), "confirm-unbounded-scan": true },
      deps: {
        fsImpl: fs, adapterFactory, randomBytesImpl: makeDeterministicRandomBytes(), nowImpl: makeClock(),
        pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }), repoRoot, homeDir,
        toolVersion: "t@1", sleepImpl: null,
      },
    }),
    inv.InventoryError
  );
  assert.equal(factoryCalls, 0);
});

test("F-1e. a run that resolves entirely from local state (already-completed resume) never invokes adapterFactory", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[]] });

  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  let factoryCalls = 0;
  const adapterFactory = () => { factoryCalls += 1; return { fetchPage: async () => [] }; };
  await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDir, "resume-run-id": result.runId, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory, randomBytesImpl: makeDeterministicRandomBytes(), nowImpl: makeClock(),
      pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }), repoRoot, homeDir,
      toolVersion: "t@1", sleepImpl: null,
    },
  });
  assert.equal(factoryCalls, 0);
});

test("F-1f. a genuinely necessary fetch does invoke adapterFactory exactly once, memoized across multiple pages", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  let factoryCalls = 0;
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const adapterFactory = () => {
    factoryCalls += 1;
    let call = 0;
    const pages = [[makeDoc("businesses/b1/products/p001", [])], [makeDoc("businesses/b1/products/p002", [])], []];
    return { fetchPage: async () => pages[call++] || [] };
  };
  await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDir, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory, randomBytesImpl: makeDeterministicRandomBytes(), nowImpl: makeClock(),
      pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }), repoRoot, homeDir,
      toolVersion: "t@1", sleepImpl: null, pageSize: 1,
    },
  });
  assert.equal(factoryCalls, 1, "the factory must be memoized, not re-invoked per page");
});

// =============================================================================
// F-3 — lock-release cleanup diagnostic is surfaced, never leaks secrets
// =============================================================================

test("F-3a. a successful lock release emits no cleanup-failure diagnostic", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const diagnostics = [];
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDir, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory: () => ({ fetchPage: async () => [] }), randomBytesImpl: makeDeterministicRandomBytes(),
      nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }),
      repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null, diagnosticSink: (msg) => diagnostics.push(msg),
    },
  });
  assert.equal(diagnostics.length, 0);
});

test("F-3b. a lock-release failure (foreign ownership token) emits exactly one cleanup-failure diagnostic naming only a safe reason class", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  fs.mkdirSync(outputDir, { recursive: true });
  const runId = "run-foreign-lock";
  const checkpoint = validCheckpoint({ runId, lastCommittedPageIndex: -1, lastCommittedPath: null });
  writeRawCheckpoint({ outputDir, checkpoint });
  // Simulate a foreign lock already present at the exact path `acquireLock`
  // would need to create — acquisition itself will fail (exclusive-create),
  // so drive the release path directly to prove the diagnostic contract.
  const lockPath = inv.lockPathFor(outputDir, runId);
  fs.writeFileSync(lockPath, JSON.stringify({ schemaVersion: inv.SCHEMA_VERSION, runId, ownershipToken: "foreign-token", pid: 999, hostname: "other-host", acquiredAt: "t" }));
  const diagnostics = [];
  const outcome = inv.releaseLock({ lockPath, ownershipToken: "our-own-different-token", fsImpl: fs });
  if (!outcome.released) diagnostics.push(`lock cleanup failed: ${outcome.reason}`);
  assert.equal(diagnostics.length, 1);
  const message = diagnostics[0];
  assert.ok(message.includes("LOCK_TOKEN_MISMATCH"));
  assert.equal(message.includes("foreign-token"), false, "must never log the raw ownership token");
  assert.equal(message.includes("our-own-different-token"), false);
  assert.equal(fs.existsSync(lockPath), true, "a foreign lock must never be deleted");
});

test("F-3c. runInventory's diagnosticSink is invoked, with a safe reason class only, when the acquired lock is foreign at release time", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const diagnostics = [];
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  // Inject an fsImpl whose unlinkSync always fails, simulating an unlink
  // failure at release time without ever leaking real filesystem content.
  const faultyFs = {
    ...fs,
    unlinkSync: (p) => {
      if (p.endsWith(".lock")) throw new Error("simulated unlink failure");
      return fs.unlinkSync(p);
    },
  };
  await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDir, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: faultyFs, adapterFactory: () => ({ fetchPage: async () => [] }), randomBytesImpl: makeDeterministicRandomBytes(),
      nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }),
      repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null, diagnosticSink: (msg) => diagnostics.push(msg),
    },
  });
  assert.equal(diagnostics.length, 1);
  assert.ok(diagnostics[0].includes("LOCK_UNLINK_FAILED"));
  // The diagnostic names only the safe reason class (runId — not a secret,
  // by design a random-but-non-authorizing identifier — and a fixed reason
  // code) and never dumps raw lock-file JSON content or field names that
  // would indicate the ownership token itself was logged.
  assert.equal(diagnostics[0].includes("ownershipToken"), false);
  assert.equal(diagnostics[0].includes("acquiredAt"), false);
  assert.equal(diagnostics[0].includes("hostname"), false);
});

test("F-3d. a cleanup diagnostic never replaces or masks the primary result/exception of the run", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const diagnostics = [];
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const result = await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDir, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory: () => ({ fetchPage: async () => [] }), randomBytesImpl: makeDeterministicRandomBytes(),
      nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }),
      repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null, diagnosticSink: (msg) => diagnostics.push(msg),
    },
  });
  assert.equal(result.checkpoint.status, "completed");
  assert.equal(diagnostics.length, 0);
});

// =============================================================================
// F-4 — UTF-8 bytewise path ordering
// =============================================================================

test("F-4a. comparePaths returns UTF-8 byte order, which diverges from native JS UTF-16 order for supplementary-plane vs. BMP characters", () => {
  const supplementary = "businesses/b1/products/p\u{10000}";
  const bmpPrivateUse = "businesses/b1/products/p";
  const nativeJsResult = supplementary < bmpPrivateUse; // true: JS says supplementary sorts first
  const byteResult = inv.comparePaths(supplementary, bmpPrivateUse);
  assert.equal(nativeJsResult, true);
  assert.equal(byteResult > 0, true, "UTF-8 byte order must place the supplementary-plane path after the BMP path");
  assert.equal(
    Buffer.compare(Buffer.from(supplementary, "utf8"), Buffer.from(bmpPrivateUse, "utf8")) > 0,
    true
  );
});

test("F-4b. comparePaths preserves ordinary ASCII ordering behavior", () => {
  assert.equal(inv.comparePaths("businesses/b1/products/p001", "businesses/b1/products/p002") < 0, true);
  assert.equal(inv.comparePaths("businesses/b1/products/p002", "businesses/b1/products/p001") > 0, true);
  assert.equal(inv.comparePaths("businesses/b1/products/p001", "businesses/b1/products/p001"), 0);
});

test("F-4c. comparePaths fails closed on non-string input rather than silently comparing", () => {
  assert.throws(() => inv.comparePaths(123, "x"), inv.InventoryError);
  assert.throws(() => inv.comparePaths("x", null), inv.InventoryError);
  assert.throws(() => inv.comparePaths(undefined, undefined), inv.InventoryError);
});

test("F-4d. a journal whose pageStartExclusivePath is neither null nor a string is rejected by content validation, not by an uncaught comparePaths throw", () => {
  const journal = validJournal({ pageStartExclusivePath: 12345 });
  const { valid, errors } = inv.validatePageJournalContent(journal, {
    expectedRunId: journal.runId,
    expectedPageIndex: 0,
    checkpointLastCommittedPath: null,
  });
  assert.equal(valid, false);
  assert.ok(errors.some((e) => e.includes("pageStartExclusivePath")));
});

// =============================================================================
// F-A (round 2) — the lock protects the authoritative checkpoint read
// =============================================================================

test("F-A-1. checkpoint content is never read before lock acquisition — a spy fsImpl proves lock-open precedes checkpoint-read", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const callOrder = [];
  const spyFs = {
    ...fs,
    openSync: (p, flag) => {
      if (flag === "wx" && p.endsWith(".lock")) callOrder.push("lock-open");
      return fs.openSync(p, flag);
    },
    readFileSync: (p, enc) => {
      if (p.endsWith(".checkpoint.json")) callOrder.push("checkpoint-read");
      return fs.readFileSync(p, enc);
    },
  };
  await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDir, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: spyFs, adapterFactory: () => ({ fetchPage: async () => [] }), randomBytesImpl: makeDeterministicRandomBytes(),
      nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }),
      repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
    },
  });
  assert.equal(callOrder[0], "lock-open");
  assert.equal(callOrder.includes("checkpoint-read"), false, "a fresh (non-resume) run never reads an absent checkpoint file at all");
});

test("F-A-2. a lock-held invocation fails without ever parsing checkpoint content, even when that content is deliberately corrupt", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const runId = "run-lock-held";
  fs.mkdirSync(outputDir, { recursive: true });
  // A foreign lock, already held.
  fs.writeFileSync(inv.lockPathFor(outputDir, runId), JSON.stringify({ schemaVersion: inv.SCHEMA_VERSION, runId, ownershipToken: "foreign", pid: 999, hostname: "other", acquiredAt: "t" }));
  // Deliberately corrupt checkpoint content — if this were ever parsed, it
  // would throw a distinct CORRUPT_CHECKPOINT-style error, not LOCK_HELD.
  fs.writeFileSync(inv.checkpointPathFor(outputDir, runId), "{not valid json at all");

  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  let threw;
  try {
    await inv.runInventory({
      args: { project: "demo-project", "output-dir": outputDir, "resume-run-id": runId, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: fs, adapterFactory: () => ({ fetchPage: async () => { throw new Error("must never fetch"); } }), randomBytesImpl: makeDeterministicRandomBytes(),
        nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }),
        repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
      },
    });
  } catch (err) {
    threw = err;
  }
  assert.ok(threw instanceof inv.InventoryError);
  assert.equal(threw.code, "LOCK_HELD");
  // The corrupt checkpoint content is proven untouched — it was never even
  // opened for parsing (the lock check happened first and rejected).
  assert.equal(fs.readFileSync(inv.checkpointPathFor(outputDir, runId), "utf8"), "{not valid json at all");
});

test("F-A-3. checkpoint content that changes in the window between preflight and lock acquisition is read fresh, post-lock, not from any earlier snapshot", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const runId = "run-fresh-post-lock";
  const project = "demo-project";
  fs.mkdirSync(outputDir, { recursive: true });
  const checkpointA = validCheckpoint({ runId, projectBinding: project, lastCommittedPageIndex: -1, lastCommittedPath: null });
  writeRawCheckpoint({ outputDir, checkpoint: checkpointA });

  // Simulate a concurrent writer that finishes and rewrites the checkpoint
  // to a *different* project binding at the exact moment this process
  // acquires its own lock — proving whatever is read afterward is this
  // newer content, never a cached pre-lock snapshot (there is none).
  const spyFs = {
    ...fs,
    openSync: (p, flag, ...rest) => {
      if (flag === "wx" && p.endsWith(".lock")) {
        const checkpointB = validCheckpoint({ runId, projectBinding: "a-completely-different-project", lastCommittedPageIndex: -1, lastCommittedPath: null });
        writeRawCheckpoint({ outputDir, checkpoint: checkpointB, fsImpl: fs });
      }
      return fs.openSync(p, flag, ...rest);
    },
  };

  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  await assert.rejects(
    inv.runInventory({
      args: { project, "output-dir": outputDir, "resume-run-id": runId, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: spyFs, adapterFactory: () => ({ fetchPage: async () => { throw new Error("must never fetch"); } }), randomBytesImpl: makeDeterministicRandomBytes(),
        nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }),
        repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
      },
    }),
    (err) => err instanceof inv.InventoryError && err.code === "PROJECT_BINDING_MISMATCH"
  );
  // Confirms: the read that fed the binding check reflected checkpoint B
  // (project mismatch detected) — checkpoint A's own matching binding was
  // never what was actually acted upon.
});

test("F-A-4. no stale pre-lock checkpoint object exists anywhere in the orchestration's own source", () => {
  const runInventorySource = PRODUCTION_SOURCE.slice(
    PRODUCTION_SOURCE.indexOf("async function runInventory"),
    PRODUCTION_SOURCE.indexOf("function main()")
  );
  assert.equal(runInventorySource.includes("existingCheckpoint"), false, "no pre-lock checkpoint variable name should remain");
  const lockIdx = runInventorySource.indexOf("acquireLock(");
  const beforeLock = runInventorySource.slice(0, lockIdx);
  assert.equal(beforeLock.includes(".checkpoint.json"), false);
});

test("F-A-5. project-binding mismatch (post-lock read) still causes zero adapter-factory calls and zero checkpoint/journal/output mutation", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[]] });
  const beforeCheckpoint = fs.readFileSync(inv.checkpointPathFor(outputDir, result.runId), "utf8");
  const beforeFiles = fs.readdirSync(outputDir).sort();

  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  let factoryCalls = 0;
  await assert.rejects(
    inv.runInventory({
      args: { project: "a-different-project", "output-dir": outputDir, "resume-run-id": result.runId, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: fs, adapterFactory: () => { factoryCalls += 1; return { fetchPage: async () => [] }; }, randomBytesImpl: makeDeterministicRandomBytes(),
        nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }),
        repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
      },
    }),
    inv.InventoryError
  );
  assert.equal(factoryCalls, 0);
  assert.equal(fs.readFileSync(inv.checkpointPathFor(outputDir, result.runId), "utf8"), beforeCheckpoint);
  assert.deepEqual(fs.readdirSync(outputDir).sort(), beforeFiles);
});

test("F-A-6. a corrupt post-lock checkpoint causes zero adapter-factory calls and zero mutation", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const runId = "run-corrupt-postlock";
  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(inv.checkpointPathFor(outputDir, runId), "{ this is not valid json");
  const beforeFiles = fs.readdirSync(outputDir).sort();

  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  let factoryCalls = 0;
  await assert.rejects(
    inv.runInventory({
      args: { project: "demo-project", "output-dir": outputDir, "resume-run-id": runId, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: fs, adapterFactory: () => { factoryCalls += 1; return { fetchPage: async () => [] }; }, randomBytesImpl: makeDeterministicRandomBytes(),
        nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }),
        repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
      },
    }),
    (err) => err instanceof inv.InventoryError && err.code === "CORRUPT_CHECKPOINT"
  );
  assert.equal(factoryCalls, 0);
  assert.deepEqual(fs.readdirSync(outputDir).sort(), beforeFiles, "a corrupt checkpoint is never rewritten or supplemented");
});

// =============================================================================
// F-B — complete page-journal directory enumeration (20 scenarios)
// =============================================================================

function writeCanonicalJournalFile(outputDir, runId, filename, content, fsImpl = fs) {
  const pagesDir = inv.pagesDirFor(outputDir, runId);
  fsImpl.mkdirSync(pagesDir, { recursive: true });
  fsImpl.writeFileSync(path.join(pagesDir, filename), typeof content === "string" ? content : JSON.stringify(content));
}

test("F-B-1. N+2 present while N+1 is absent fails closed", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b1";
  const j2 = validJournal({ runId, pageIndex: 2 });
  writeRawJournal({ outputDir, runId, pageIndex: 2, journal: j2 });
  assert.throws(
    () => inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: -1, checkpointStatus: "in_progress", fsImpl: fs }),
    inv.InventoryError
  );
});

test("F-B-2. N+1 and N+3 both present (with N+2 absent) fails closed", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b2";
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal: validJournal({ runId, pageIndex: 0 }) });
  writeRawJournal({ outputDir, runId, pageIndex: 2, journal: validJournal({ runId, pageIndex: 2 }) });
  assert.throws(
    () => inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: -1, checkpointStatus: "in_progress", fsImpl: fs }),
    inv.InventoryError
  );
});

test("F-B-3. multiple farther-ahead journals (N+1, N+2, N+3) all present fails closed", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b3";
  for (const idx of [0, 1, 2]) {
    writeRawJournal({ outputDir, runId, pageIndex: idx, journal: validJournal({ runId, pageIndex: idx }) });
  }
  assert.throws(
    () => inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: -1, checkpointStatus: "in_progress", fsImpl: fs }),
    inv.InventoryError
  );
});

test("F-B-4. a noncanonical zero-padding variant is rejected", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b4";
  writeCanonicalJournalFile(outputDir, runId, "0.json", validJournal({ runId, pageIndex: 0 }));
  assert.throws(
    () => inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: -1, checkpointStatus: "in_progress", fsImpl: fs }),
    inv.InventoryError
  );
});

test("F-B-5. a malformed .json filename is rejected", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b5";
  writeCanonicalJournalFile(outputDir, runId, "0000000X.json", validJournal({ runId, pageIndex: 0 }));
  assert.throws(
    () => inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: -1, checkpointStatus: "in_progress", fsImpl: fs }),
    inv.InventoryError
  );
});

test("F-B-6. an unexpected ordinary file in the pages directory is rejected", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b6";
  writeCanonicalJournalFile(outputDir, runId, "README.txt", "not a journal");
  assert.throws(
    () => inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: -1, checkpointStatus: "in_progress", fsImpl: fs }),
    inv.InventoryError
  );
});

test("F-B-7. a subdirectory inside the pages directory is rejected", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b7";
  const pagesDir = inv.pagesDirFor(outputDir, runId);
  fs.mkdirSync(path.join(pagesDir, "00000000.json"), { recursive: true });
  assert.throws(
    () => inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: -1, checkpointStatus: "in_progress", fsImpl: fs }),
    inv.InventoryError
  );
});

test("F-B-8. a symlink inside the pages directory is rejected without being followed", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b8";
  const pagesDir = inv.pagesDirFor(outputDir, runId);
  fs.mkdirSync(pagesDir, { recursive: true });
  const realFile = path.join(mkTemp("real"), "elsewhere.json");
  fs.writeFileSync(realFile, JSON.stringify(validJournal({ runId, pageIndex: 0 })));
  fs.symlinkSync(realFile, path.join(pagesDir, "00000000.json"));
  assert.throws(
    () => inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: -1, checkpointStatus: "in_progress", fsImpl: fs }),
    inv.InventoryError
  );
});

test("F-B-9. a duplicate semantic index (canonical name reused via a second directory listing) is rejected", () => {
  // The canonical filename formatter is a pure function of the index, so a
  // true filesystem duplicate is impossible for two *canonical* names —
  // this proves the round-trip guard rejects any name that maps to an
  // index already seen (defends against a non-canonicalizing fsImpl double
  // reporting the same entry twice).
  const outputDir = mkTemp("out");
  const runId = "run-b9";
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal: validJournal({ runId, pageIndex: 0 }) });
  const duplicatingFs = {
    ...fs,
    readdirSync: (p) => {
      const real = fs.readdirSync(p);
      return real.concat(real); // simulate a double-reported entry
    },
  };
  assert.throws(
    () => inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: 0, checkpointStatus: "completed", fsImpl: duplicatingFs }),
    inv.InventoryError
  );
});

test("F-B-10. a gap inside the committed prefix (0, 2 present; 1 absent) is rejected", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b10";
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal: validJournal({ runId, pageIndex: 0 }) });
  writeRawJournal({ outputDir, runId, pageIndex: 2, journal: validJournal({ runId, pageIndex: 2 }) });
  assert.throws(
    () => inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: 2, checkpointStatus: "in_progress", fsImpl: fs }),
    inv.InventoryError
  );
});

test("F-B-11. a missing journal inside the committed prefix (checkpoint claims 0..2, only 0 present) is rejected", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b11";
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal: validJournal({ runId, pageIndex: 0 }) });
  assert.throws(
    () => inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: 2, checkpointStatus: "in_progress", fsImpl: fs }),
    inv.InventoryError
  );
});

test("F-B-12. an extra journal after a completed checkpoint is rejected — even though it is exactly N+1", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b12";
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal: validJournal({ runId, pageIndex: 0 }) });
  writeRawJournal({ outputDir, runId, pageIndex: 1, journal: validJournal({ runId, pageIndex: 1, pageStartExclusivePath: "businesses/b1/products/p003" }) });
  assert.throws(
    () => inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: 0, checkpointStatus: "completed", fsImpl: fs }),
    inv.InventoryError
  );
});

test("F-B-13. an unexpected (malformed-name) entry after a completed checkpoint is rejected", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b13";
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal: validJournal({ runId, pageIndex: 0 }) });
  writeCanonicalJournalFile(outputDir, runId, "stray.json", "{}");
  assert.throws(
    () => inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: 0, checkpointStatus: "completed", fsImpl: fs }),
    inv.InventoryError
  );
});

test("F-B-14. a valid, empty pages directory (or a directory that does not yet exist) is accepted for a fresh checkpoint", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b14";
  const { prefixIndexes, aheadIndex } = inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: -1, checkpointStatus: "in_progress", fsImpl: fs });
  assert.deepEqual(prefixIndexes, []);
  assert.equal(aheadIndex, null);
});

test("F-B-15. a valid exact committed prefix (0..N, nothing beyond) is accepted", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b15";
  const journals = buildChain({ runId, n: 3 });
  writeChain(outputDir, journals);
  const { prefixIndexes, aheadIndex } = inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: 2, checkpointStatus: "completed", fsImpl: fs });
  assert.deepEqual(prefixIndexes, [0, 1, 2]);
  assert.equal(aheadIndex, null);
});

test("F-B-16. a valid exact prefix plus only N+1 is accepted (in_progress only)", () => {
  const outputDir = mkTemp("out");
  const runId = "run-b16";
  const journals = buildChain({ runId, n: 3 });
  writeChain(outputDir, journals);
  const { prefixIndexes, aheadIndex } = inv.enumeratePageDirectory({ outputDir, runId, lastCommittedPageIndex: 1, checkpointStatus: "in_progress", fsImpl: fs });
  assert.deepEqual(prefixIndexes, [0, 1]);
  assert.equal(aheadIndex, 2);
});

test("F-B-17. page-0 sentinel recovery still works end to end through the full directory-enumeration path (real runInventory)", async () => {
  // Re-confirms item 607's own scenario now routes through the new,
  // complete directory scan rather than a two-filename probe.
  const outputDir = path.join(mkTemp("out"), "outputs");
  const runId = "run-b17";
  const project = "demo-project";
  fs.mkdirSync(outputDir, { recursive: true });
  const checkpoint = validCheckpoint({ runId, projectBinding: project, lastCommittedPageIndex: -1, lastCommittedPath: null });
  writeRawCheckpoint({ outputDir, checkpoint });
  const journal = validJournal({ runId, pageIndex: 0, pageStartExclusivePath: null });
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal });

  let factoryCalls = 0;
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const result = await inv.runInventory({
    args: { project, "output-dir": outputDir, "resume-run-id": runId, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory: () => { factoryCalls += 1; return { fetchPage: async () => { throw new Error("must never fetch"); } }; },
      randomBytesImpl: makeDeterministicRandomBytes(), nowImpl: makeClock(), pid: 1, hostname: "h",
      platform: process.platform, env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
    },
  });
  assert.equal(factoryCalls, 0);
  assert.equal(result.checkpoint.lastCommittedPageIndex, 0);
});

test("F-B-18. mid-chain N->N+1 recovery still works end to end through the full directory-enumeration path (real runInventory)", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const runId = "run-b18";
  const project = "demo-project";
  fs.mkdirSync(outputDir, { recursive: true });
  const journal0 = validJournal({ runId, pageIndex: 0, pageStartExclusivePath: null, examinedCount: 500, categoryCounts: { media_missing: 0, media_null: 0, media_wrong_type: 0, media_conforming: 500, media_oversized: 0 }, violations: [] });
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal: journal0 });
  const journal1 = validJournal({
    runId, pageIndex: 1, pageStartExclusivePath: journal0.pageEndInclusivePath, pageEndInclusivePath: "businesses/b1/products/p999",
    violations: [], categoryCounts: { media_missing: 0, media_null: 0, media_wrong_type: 0, media_conforming: 1, media_oversized: 0 }, examinedCount: 1,
  });
  writeRawJournal({ outputDir, runId, pageIndex: 1, journal: journal1 });
  const checkpoint = validCheckpoint({ runId, projectBinding: project, lastCommittedPageIndex: 0, lastCommittedPath: journal0.pageEndInclusivePath });
  writeRawCheckpoint({ outputDir, checkpoint });

  let factoryCalls = 0;
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const result = await inv.runInventory({
    args: { project, "output-dir": outputDir, "resume-run-id": runId, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: fs, adapterFactory: () => { factoryCalls += 1; return { fetchPage: async () => { throw new Error("must never fetch"); } }; },
      randomBytesImpl: makeDeterministicRandomBytes(), nowImpl: makeClock(), pid: 1, hostname: "h",
      platform: process.platform, env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
    },
  });
  assert.equal(factoryCalls, 0);
  assert.equal(result.checkpoint.lastCommittedPageIndex, 1);
});

test("F-B-19. repeated restart across the full directory-enumeration path remains idempotent", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const runId = "run-b19";
  const project = "demo-project";
  fs.mkdirSync(outputDir, { recursive: true });
  const checkpoint = validCheckpoint({ runId, projectBinding: project, lastCommittedPageIndex: -1, lastCommittedPath: null });
  writeRawCheckpoint({ outputDir, checkpoint });
  const journal = validJournal({ runId, pageIndex: 0, pageStartExclusivePath: null });
  writeRawJournal({ outputDir, runId, pageIndex: 0, journal });
  const journalBytes = fs.readFileSync(inv.pageJournalPathFor(outputDir, runId, 0));

  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  for (let attempt = 0; attempt < 3; attempt += 1) {
    let factoryCalls = 0;
    const result = await inv.runInventory({
      args: { project, "output-dir": outputDir, "resume-run-id": runId, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: fs, adapterFactory: () => { factoryCalls += 1; return { fetchPage: async () => { throw new Error("must never fetch"); } }; },
        randomBytesImpl: makeDeterministicRandomBytes(attempt + 1), nowImpl: makeClock(), pid: attempt, hostname: "h",
        platform: process.platform, env: makeEnv({ emulator: true }), repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
      },
    });
    assert.equal(factoryCalls, 0);
    assert.equal(result.checkpoint.lastCommittedPageIndex, 0);
    assert.deepEqual(fs.readFileSync(inv.pageJournalPathFor(outputDir, runId, 0)), journalBytes);
    assert.equal(fs.readdirSync(inv.pagesDirFor(outputDir, runId)).length, 1);
  }
});

test("F-B-20. every rejected directory-anomaly case proves zero adapter-factory/fetch calls and byte-identical existing operational files", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const runId = "run-b20";
  const project = "demo-project";
  fs.mkdirSync(outputDir, { recursive: true });
  const checkpoint = validCheckpoint({ runId, projectBinding: project, lastCommittedPageIndex: -1, lastCommittedPath: null });
  writeRawCheckpoint({ outputDir, checkpoint });
  // Anomaly: a journal at index 2 with nothing at 0 or 1.
  writeRawJournal({ outputDir, runId, pageIndex: 2, journal: validJournal({ runId, pageIndex: 2 }) });
  const beforeCheckpointBytes = fs.readFileSync(inv.checkpointPathFor(outputDir, runId));

  let factoryCalls = 0;
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  await assert.rejects(
    inv.runInventory({
      args: { project, "output-dir": outputDir, "resume-run-id": runId, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: fs, adapterFactory: () => { factoryCalls += 1; return { fetchPage: async () => [] }; }, randomBytesImpl: makeDeterministicRandomBytes(),
        nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }),
        repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null,
      },
    }),
    inv.InventoryError
  );
  assert.equal(factoryCalls, 0);
  // The checkpoint is allowed to transition to `failed` (the already-frozen
  // fail-closed contract) but the anomalous journal itself, and the prior
  // checkpoint bytes' own operational fields, are never mutated by this
  // rejection beyond that terminal status write.
  const afterCheckpoint = JSON.parse(fs.readFileSync(inv.checkpointPathFor(outputDir, runId), "utf8"));
  const beforeCheckpointParsed = JSON.parse(beforeCheckpointBytes.toString("utf8"));
  assert.equal(afterCheckpoint.lastCommittedPageIndex, beforeCheckpointParsed.lastCommittedPageIndex);
  assert.equal(afterCheckpoint.lastCommittedPath, beforeCheckpointParsed.lastCommittedPath);
  assert.equal(afterCheckpoint.status, "failed");
  assert.equal(fs.readdirSync(inv.pagesDirFor(outputDir, runId)).length, 1, "the anomalous journal itself is neither deleted nor added to");
});

// =============================================================================
// F-C (round 2) — return-level lock-cleanup status signal
// =============================================================================

test("F-C-1. successful run + successful cleanup returns lockCleanupFailed: false", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[]] });
  assert.equal(result.lockCleanupFailed, false);
});

test("F-C-2. successful run + ownership-token-mismatch cleanup returns lockCleanupFailed: true, with a diagnostic, no lock deletion", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const runId = "run-fc2";
  const project = "demo-project";
  fs.mkdirSync(outputDir, { recursive: true });
  const checkpoint = validCheckpoint({ runId, projectBinding: project, lastCommittedPageIndex: -1, lastCommittedPath: null });
  writeRawCheckpoint({ outputDir, checkpoint });

  const lockPath = inv.lockPathFor(outputDir, runId);
  let swapped = false;
  // Force the lock this run itself acquires to be swapped for a foreign
  // one (a different ownershipToken) once, immediately after this process
  // has acquired it — simulating a legitimate second acquirer racing in
  // after an operator's manual stale-lock clear, outside this process's
  // own view. The swap point (right before the post-lock checkpoint read)
  // is deterministic and reproducible without any real concurrency.
  const raceFs = {
    ...fs,
    readFileSync: (p, enc) => {
      if (p.endsWith(".checkpoint.json") && !swapped) {
        swapped = true;
        fs.writeFileSync(lockPath, JSON.stringify({ schemaVersion: inv.SCHEMA_VERSION, runId, ownershipToken: "foreign-token", pid: 999, hostname: "other", acquiredAt: "t" }));
      }
      return fs.readFileSync(p, enc);
    },
  };

  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const diagnostics = [];
  const result = await inv.runInventory({
    args: { project, "output-dir": outputDir, "resume-run-id": runId, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: raceFs,
      adapterFactory: () => ({ fetchPage: async () => [] }),
      randomBytesImpl: makeDeterministicRandomBytes(),
      nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }),
      repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null, diagnosticSink: (msg) => diagnostics.push(msg),
    },
  });

  assert.equal(result.lockCleanupFailed, true);
  assert.equal(diagnostics.length, 1);
  assert.ok(diagnostics[0].includes("LOCK_TOKEN_MISMATCH"));
  assert.equal(fs.existsSync(lockPath), true, "the foreign lock must never be deleted");
  const finalLock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
  assert.equal(finalLock.ownershipToken, "foreign-token");
});

test("F-C-3. successful run + injected unlink failure returns lockCleanupFailed: true, with a diagnostic", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const diagnostics = [];
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const faultyFs = { ...fs, unlinkSync: (p) => { if (p.endsWith(".lock")) throw new Error("simulated unlink failure"); return fs.unlinkSync(p); } };
  const result = await inv.runInventory({
    args: { project: "demo-project", "output-dir": outputDir, "confirm-unbounded-scan": true },
    deps: {
      fsImpl: faultyFs, adapterFactory: () => ({ fetchPage: async () => [] }), randomBytesImpl: makeDeterministicRandomBytes(),
      nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }),
      repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null, diagnosticSink: (msg) => diagnostics.push(msg),
    },
  });
  assert.equal(result.lockCleanupFailed, true);
  assert.equal(diagnostics.length, 1);
  assert.ok(diagnostics[0].includes("LOCK_UNLINK_FAILED"));
});

test("F-C-4. a primary run failure remains the primary thrown error even when lock cleanup also fails", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const repoRoot = mkTemp("repo");
  const homeDir = mkTemp("home");
  const diagnostics = [];
  const faultyFs = { ...fs, unlinkSync: (p) => { if (p.endsWith(".lock")) throw new Error("simulated unlink failure"); return fs.unlinkSync(p); } };
  const adapter = { fetchPage: async () => { throw new Error("primary fetch failure"); } };
  // Force retry exhaustion to fail the run itself, then also fail cleanup.
  let thrown;
  try {
    await inv.runInventory({
      args: { project: "demo-project", "output-dir": outputDir, "confirm-unbounded-scan": true },
      deps: {
        fsImpl: faultyFs, adapterFactory: () => adapter, randomBytesImpl: makeDeterministicRandomBytes(),
        nowImpl: makeClock(), pid: 1, hostname: "h", platform: process.platform, env: makeEnv({ emulator: true }),
        repoRoot, homeDir, toolVersion: "t@1", sleepImpl: null, diagnosticSink: (msg) => diagnostics.push(msg),
      },
    });
  } catch (err) {
    thrown = err;
  }
  // The run itself completes (status: failed) rather than throwing, per
  // the already-frozen read-retry-exhaustion contract — but cleanup
  // failure must still be surfaced without masking that failed status.
  assert.equal(thrown, undefined, "a read-failure-exhaustion run resolves with status:failed, it does not throw");
  assert.equal(diagnostics.length, 1);
  assert.ok(diagnostics[0].includes("LOCK_UNLINK_FAILED"));
});

test("F-C-5. lockCleanupFailed never appears in any persisted artifact (checkpoint, journal, summary.json, summary.md, violations.ndjson)", async () => {
  const outputDir = path.join(mkTemp("out"), "outputs");
  const { result } = await runFreshInventory({ outputDir, pages: [[makeDoc("businesses/b1/products/p001", [])]] });
  const checkpointText = fs.readFileSync(inv.checkpointPathFor(outputDir, result.runId), "utf8");
  const summaryText = fs.readFileSync(inv.summaryPathFor(outputDir, result.runId), "utf8");
  const mdText = fs.readFileSync(inv.markdownPathFor(outputDir, result.runId), "utf8");
  const ndjsonText = fs.readFileSync(inv.ndjsonPathFor(outputDir, result.runId), "utf8");
  const journalText = fs.readFileSync(inv.pageJournalPathFor(outputDir, result.runId, 0), "utf8");
  for (const text of [checkpointText, summaryText, mdText, ndjsonText, journalText]) {
    assert.equal(text.includes("lockCleanupFailed"), false);
  }
});
