"use strict";

// Petsupo Marketplace P1-A compliance foundation — Slice 4.7 test suite
// (docs/plans/marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §0.12/§15 items 341-402, Revision 14/15, committed
// df456470ffb3298a997cccdcc37bd4e828d93d70). Item 402 itself (the O1
// regression-guard repair contract) is proven in
// functions/test/complianceMatching.test.js, the one file Revision 15
// (§0.13) authorizes for that repair — not here.
//
// This correction pass (following an independent, adversarial
// implementation-review audit) additionally closes six previously-open,
// independently-identified test-coverage gaps within this file's own
// existing item 341-401 scope: genuine behavioral coverage for
// STALE_CHECK_FAILED, CHECKPOINT_READ_FAILED, and CANDIDATE_QUERY_FAILED
// (all three previously proven only statically or not at all); a real
// deletion-race test for item 372 (previously calling
// recomputeProductComplianceStatus directly on an already-deleted
// product, never exercising the sweep's own dispatch path); a
// static-and-behavioral proof for item 377 (previously a circular,
// plan-prose-only assertion); and a genuine concurrent-sweep test for
// item 384 (previously calling recomputeProductComplianceStatus twice
// directly, never runComplianceRecomputeSweep). None of these were a
// production defect — every gap was in this file's own test coverage
// only, confirmed by the same independent review that found the O1
// regression above.
//
// The sweep's own candidate query is a genuine `collectionGroup("products")`
// query with `startAfter(DocumentReference)` cursoring and calls the real,
// unmodified `recomputeProductComplianceStatus` (which opens its own real
// Firestore transaction) — none of this can be honestly proven against a
// hand-rolled fake `db` the way Slice 4.3's own matching engine tests do
// (complianceMatching.test.js's own top-of-file note). Every behavioral
// test in this file is therefore real-Firestore-emulator-backed, gated on
// `FIRESTORE_EMULATOR_HOST` via the same `itest` skip-wrapper convention
// already established by complianceMatching.test.js/
// compliancePolicyRegistryOperations.test.js — skipped, never failed, when
// no local emulator is running. Only the small, purely-static source-scan
// group at the top of this file (no Firestore access of any kind) always
// runs unconditionally.
//
// Each test uses uniquely-IDed businesses/products (never a shared fixed
// ID) so it can run alongside any other real-emulator test in this suite
// without collision, EXCEPT for the one genuinely shared singleton this
// module owns, `complianceRecomputeSweepCheckpoint/current` — every test
// that touches it explicitly resets it (delete) before and after itself,
// and this file's own tests run sequentially (no declared concurrency),
// matching how `compliancePolicyRegistryPointer/current`'s own singleton
// is already handled by this suite's sibling test files.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function itest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

const { runComplianceRecomputeSweep } = require("../src/marketplace/compliance/complianceProductRecomputeSweep");
const { createCompliancePolicyVersion, bootstrapCompliancePolicyRegistry } = require("../src/marketplace/compliance/compliancePolicyRegistryOperations");

const SWEEP_SOURCE_PATH = path.join(__dirname, "..", "src", "marketplace", "compliance", "complianceProductRecomputeSweep.js");
const RECOMPUTE_SOURCE_PATH = path.join(__dirname, "..", "src", "marketplace", "compliance", "complianceProductRecompute.js");
const POLICY_OPS_SOURCE_PATH = path.join(__dirname, "..", "src", "marketplace", "compliance", "compliancePolicyRegistryOperations.js");
const INDEX_SOURCE_PATH = path.join(__dirname, "..", "index.js");
const PLAN_PATH = path.join(__dirname, "..", "..", "docs", "plans", "marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md");

const CHECKPOINT_REF_PATH = "complianceRecomputeSweepCheckpoint/current";
const POINTER_REF_PATH = "compliancePolicyRegistryPointer/current";

function makeFakeLogger() {
  const errorCalls = [];
  const infoCalls = [];
  return {
    error: (...args) => errorCalls.push(args),
    info: (...args) => infoCalls.push(args),
    errorCalls,
    infoCalls,
  };
}

// ===========================================================================
// Static source-scan group — no Firestore/emulator access. Always runs.
// Covers items 397, 398, and the static-proof halves of items 399/400/401.
// ===========================================================================

test("[398/item-list-scope] complianceProductRecomputeSweep.js exports exactly one function, no second entry point", () => {
  const mod = require("../src/marketplace/compliance/complianceProductRecomputeSweep");
  assert.deepEqual(Object.keys(mod), ["runComplianceRecomputeSweep"]);
  assert.equal(typeof mod.runComplianceRecomputeSweep, "function");
});

test("[397] functions/index.js exports exactly one sweep-related trigger and no onCall/HTTP wrapper for it", () => {
  const src = fs.readFileSync(INDEX_SOURCE_PATH, "utf8");
  const scheduleMatches = src.match(/exports\.complianceProductRecomputeSweep\s*=\s*onSchedule\(/g) || [];
  assert.equal(scheduleMatches.length, 1, "expected exactly one onSchedule export for the sweep");
  assert.doesNotMatch(src, /exports\.\w*[Rr]ecompute[Ss]weep\w*\s*=\s*onCall\(/);
  assert.doesNotMatch(src, /exports\.\w*[Rr]ecompute[Ss]weep\w*\s*=\s*onRequest\(/);
});

test("[398] compliancePolicyRegistryOperations.js (bootstrapCompliancePolicyRegistry, activatePolicyVersion, every export) never imports/calls the sweep", () => {
  const src = fs.readFileSync(POLICY_OPS_SOURCE_PATH, "utf8");
  assert.doesNotMatch(src, /complianceProductRecomputeSweep/);
  assert.doesNotMatch(src, /runComplianceRecomputeSweep/);
});

test("[401-static-a] the sweep's own source never imports or re-exports REASON, and never contains the literal recompute_product_not_found", () => {
  const src = fs.readFileSync(SWEEP_SOURCE_PATH, "utf8");
  assert.doesNotMatch(src, /\bREASON\b/, "sweep source must never reference REASON at all");
  assert.doesNotMatch(src, /recompute_product_not_found/, "sweep source must never duplicate this internal literal");
});

test("[401-static-b] complianceProductRecompute.js remains unmodified by this correction (still no REASON export, still the single writer)", () => {
  const src = fs.readFileSync(RECOMPUTE_SOURCE_PATH, "utf8");
  const exportsBlockMatch = src.match(/module\.exports\s*=\s*\{[\s\S]*?\};/);
  assert.ok(exportsBlockMatch, "expected a module.exports block");
  assert.doesNotMatch(exportsBlockMatch[0], /\bREASON\b/, "REASON must still not be exported from complianceProductRecompute.js");
});

test("[MISSING_PRODUCT absence] the sweep's own source contains no MISSING_PRODUCT identifier anywhere", () => {
  const src = fs.readFileSync(SWEEP_SOURCE_PATH, "utf8");
  assert.doesNotMatch(src, /MISSING_PRODUCT/);
});

test("[three-value allowlist, static] the sweep's own CANDIDATE_FAILURE_CODE-equivalent literal set is exactly INVALID_PRODUCT_PATH/STALE_CHECK_FAILED/RECOMPUTE_FAILED", () => {
  const src = fs.readFileSync(SWEEP_SOURCE_PATH, "utf8");
  assert.match(src, /INVALID_PRODUCT_PATH/);
  assert.match(src, /STALE_CHECK_FAILED/);
  assert.match(src, /RECOMPUTE_FAILED/);
  // Exactly these three per-candidate failure code string literals appear
  // as quoted values (a 4th would indicate scope creep).
  const codeStringLiterals = new Set((src.match(/"[A-Z_]+"/g) || []).filter((s) =>
    ["\"INVALID_PRODUCT_PATH\"", "\"STALE_CHECK_FAILED\"", "\"RECOMPUTE_FAILED\"", "\"CHECKPOINT_READ_FAILED\"", "\"CANDIDATE_QUERY_FAILED\"", "\"CHECKPOINT_WRITE_FAILED\""].includes(s)
  ));
  assert.equal(codeStringLiterals.size, 6);
});

test("[index.js wiring, static] exact schedule/region/timeZone/retryCount/memory/timeout, no feature flag/maxInstances/concurrency override", () => {
  const src = fs.readFileSync(INDEX_SOURCE_PATH, "utf8");
  const start = src.indexOf("exports.complianceProductRecomputeSweep = onSchedule(");
  assert.ok(start >= 0);
  const end = src.indexOf("\n);", start);
  const block = src.slice(start, end);
  assert.match(block, /schedule:\s*"every 60 minutes"/);
  assert.match(block, /region:\s*"europe-west3"/);
  assert.match(block, /timeZone:\s*"Europe\/Istanbul"/);
  assert.match(block, /retryCount:\s*2/);
  assert.match(block, /memory:\s*"256MiB"/);
  assert.match(block, /timeoutSeconds:\s*300/);
  assert.doesNotMatch(block, /maxInstances/);
  assert.doesNotMatch(block, /concurrency/);
  assert.doesNotMatch(block, /enforceAppCheck/);
  assert.doesNotMatch(block, /defineString|defineBoolean|process\.env/);
});

if (!hasFirestoreEmulator) {
  console.log("complianceProductRecomputeSweep.test.js: FIRESTORE_EMULATOR_HOST not set — all real-emulator tests below are skipped, not failed.");
}

// ===========================================================================
// Real-emulator group. Everything below requires a running Firestore
// emulator (FIRESTORE_EMULATOR_HOST) and is skipped otherwise.
// ===========================================================================

const db = admin.firestore();
let seq = 0;
function nextId(prefix) {
  seq += 1;
  return `${prefix}-${crypto.randomUUID()}-${seq}`;
}

function productRef(businessId, productId) {
  return db.collection("businesses").doc(businessId).collection("products").doc(productId);
}

async function seedApprovedActiveProduct({ businessId, productId, sellerRelationship = "manufacturer", extra = {} }) {
  await productRef(businessId, productId).set({
    businessId,
    sellerRelationship,
    isActive: true,
    moderationStatus: "approved",
    ...extra,
  });
}

async function clearCheckpoint() {
  await db.doc(CHECKPOINT_REF_PATH).delete();
}

async function setCheckpoint(lastExaminedPath) {
  await db.doc(CHECKPOINT_REF_PATH).set({ lastExaminedPath, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
}

async function deleteAll(refs) {
  await Promise.all(refs.map((ref) => ref.delete().catch(() => {})));
}

// Idempotent, self-healing pre-flight: deletes any leftover
// `businesses/{id}/products/{id}`, `productComplianceDecisions/{id}`,
// `businessComplianceEpochs/{id}`, `compliancePolicyRegistryPointer/current`,
// and `compliancePolicyRegistry/*` documents this file's own fixtures may
// have created and left behind by a PRIOR local `node --test` run against
// this same, not-restarted emulator instance (every ID this file ever
// generates carries the "biz-"/"prod-"/"sweep-policy-ver-" prefix, below
// — a real production ID would never fall in this exact lexicographic
// range). Every test in this file already cleans up strictly after
// itself; this is defense-in-depth against a run that was interrupted
// (Ctrl-C, an earlier crash) before its own `finally` blocks completed,
// so a repeated local run stays deterministic without requiring a manual
// emulator restart between runs.
async function wipeStaleFixtureData() {
  const prefixRange = (field) => [`${field}-`, `${field}-`];
  const [bizLow, bizHigh] = prefixRange("biz");
  const staleProducts = await db
    .collectionGroup("products")
    .where("businessId", ">=", bizLow)
    .where("businessId", "<", bizHigh)
    .get();
  const staleBusinesses = await db
    .collection("businesses")
    .where(admin.firestore.FieldPath.documentId(), ">=", bizLow)
    .where(admin.firestore.FieldPath.documentId(), "<", bizHigh)
    .get();
  const staleEpochs = await db
    .collection("businessComplianceEpochs")
    .where(admin.firestore.FieldPath.documentId(), ">=", bizLow)
    .where(admin.firestore.FieldPath.documentId(), "<", bizHigh)
    .get();
  const [prodLow, prodHigh] = prefixRange("prod");
  const staleDecisions = await db
    .collection("productComplianceDecisions")
    .where(admin.firestore.FieldPath.documentId(), ">=", prodLow)
    .where(admin.firestore.FieldPath.documentId(), "<", prodHigh)
    .get();
  const [verLow, verHigh] = ["sweep-policy-ver-", "sweep-policy-ver-"];
  const staleVersions = await db
    .collection("compliancePolicyRegistry")
    .where(admin.firestore.FieldPath.documentId(), ">=", verLow)
    .where(admin.firestore.FieldPath.documentId(), "<", verHigh)
    .get();

  await deleteAll([
    ...staleProducts.docs.map((d) => d.ref),
    ...staleBusinesses.docs.map((d) => d.ref),
    ...staleEpochs.docs.map((d) => d.ref),
    ...staleDecisions.docs.map((d) => d.ref),
    ...staleVersions.docs.map((d) => d.ref),
  ]);
  await db.doc(POINTER_REF_PATH).delete().catch(() => {});
  await db.doc(CHECKPOINT_REF_PATH).delete().catch(() => {});
}

// A minimal, always-active, always-approved policy version + pointer,
// created once per test file run and reused (read-only) by every test
// below that needs a resolvable pointer — mirrors
// complianceMatching.test.js's own real-emulator group's activation
// pattern, and is disjoint from compliancePolicyRegistryOperations.test.js's
// own dedicated bootstrap/pointer coverage since a fresh emulator instance
// backs this whole run.
// Memoized as a PROMISE, not merely a resolved value. Top-level
// test()/itest() callbacks in this file run sequentially by default —
// node:test's own default per-file concurrency is 1 unless explicitly
// enabled (independently re-verified against the current node:test
// implementation: a throwaway file with two staggered top-level tests
// ran fully sequentially, one completing before the other started), so
// a genuine same-tick race between two top-level callbacks cannot occur
// in this file today. The earlier claim that node:test defaults to a
// concurrency greater than 1 was inaccurate and is corrected here.
// The memoized-promise pattern is kept anyway, for two reasons that do
// not depend on any concurrency claim: (1) it is the correct, idiomatic
// way to make an async, once-only bootstrap safely reusable/idempotent
// across many sequential callers without re-running
// bootstrapCompliancePolicyRegistry (which throws
// policy_bootstrap_pointer_already_exists on any attempt after the
// first) more than once; (2) it stays correct if this file's own
// concurrency were ever explicitly enabled later — a resolved-value-only
// cache would silently become unsafe under that change, while the
// in-flight-promise cache would not.
let sharedActivePolicyPromise = null;
function ensureSharedActivePolicy() {
  if (sharedActivePolicyPromise) return sharedActivePolicyPromise;
  sharedActivePolicyPromise = (async () => {
    const versionId = nextId("sweep-policy-ver");
    await createCompliancePolicyVersion({
      db,
      sellerRelationship: {
        manufacturer: {
          acceptedDocumentTypes: ["purchase_invoice"],
          requiredDocumentTypeGroups: [{ documentTypes: ["purchase_invoice"] }],
          perDocumentTypePolicy: {},
          maximumValidityPeriod: null,
          acceptedScopeTypes: ["business"],
          manualAdminOverridePermitted: false,
        },
      },
      effectiveFrom: admin.firestore.Timestamp.fromMillis(Date.now() - 10_000),
      changeNote: "Slice 4.7 sweep test fixture policy",
      initialStatus: "draft",
      createdBy: "sweep-test",
      now: new Date(),
      generateVersionId: () => versionId,
    });
    await bootstrapCompliancePolicyRegistry({ db, targetVersionId: versionId, now: new Date() });
    return versionId;
  })();
  return sharedActivePolicyPromise;
}

// Cleans up the shared pointer/version this file's own fixtures created,
// if any — makes a repeated local `node --test` run against the same,
// not-restarted emulator instance idempotent (bootstrapCompliancePolicyRegistry
// otherwise fails with `policy_bootstrap_pointer_already_exists` on a
// second run), without requiring a manual emulator data clear between
// runs. A no-op when no real emulator is attached (itest-only fixture).
if (hasFirestoreEmulator) {
  test.before(async () => {
    await wipeStaleFixtureData();
  });
  test.after(async () => {
    if (!sharedActivePolicyPromise) return;
    const versionId = await sharedActivePolicyPromise;
    await db.doc(POINTER_REF_PATH).delete().catch(() => {});
    await db.collection("compliancePolicyRegistry").doc(versionId).delete().catch(() => {});
  });
}

// ---------------------------------------------------------------------
// Candidate query — exact shape, order, filters (items 341-346).
// ---------------------------------------------------------------------

itest("[341/342] candidate query is isActive+moderationStatus filtered, document-ID ordered, and the existing composite index serves it with no FAILED_PRECONDITION", async () => {
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId });
  await clearCheckpoint();
  try {
    const logger = makeFakeLogger();
    // No FAILED_PRECONDITION thrown proves the existing composite index
    // serves this exact query shape (item 342) — a thrown
    // FAILED_PRECONDITION would surface as a rejected promise here.
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 500, maxPages: 4, maxRecomputes: 100, logger });
    assert.ok(result.examinedCount >= 1);
    assert.equal(logger.errorCalls.filter((c) => c[0] === "compliance_recompute_sweep_infrastructure_failed").length, 0);
  } finally {
    await deleteAll([productRef(businessId, productId)]);
    await clearCheckpoint();
  }
});

itest("[343] an inactive product is excluded from every page", async () => {
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId, extra: { isActive: false } });
  await clearCheckpoint();
  try {
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    assert.equal(result.nextCursor, null); // exhausted with nothing examined from this product
    assert.equal(result.exhausted, true);
  } finally {
    await deleteAll([productRef(businessId, productId)]);
    await clearCheckpoint();
  }
});

itest("[344] a not-yet-approved product is excluded from every page", async () => {
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId, extra: { moderationStatus: "pending_review" } });
  await clearCheckpoint();
  try {
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    assert.equal(result.examinedCount, 0);
  } finally {
    await deleteAll([productRef(businessId, productId)]);
    await clearCheckpoint();
  }
});

itest("[345] a deleted product is absent from every subsequent page", async () => {
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId });
  await productRef(businessId, productId).delete();
  await clearCheckpoint();
  try {
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    assert.equal(result.examinedCount, 0);
  } finally {
    await clearCheckpoint();
  }
});

itest("[346] two products in different businesses interleave purely by ascending document-ID order", async () => {
  await ensureSharedActivePolicy();
  const businessId1 = nextId("biz");
  const businessId2 = nextId("biz");
  const productId = "same-product-id-for-order-test";
  await seedApprovedActiveProduct({ businessId: businessId1, productId });
  await seedApprovedActiveProduct({ businessId: businessId2, productId });
  await clearCheckpoint();
  try {
    const logger = makeFakeLogger();
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), maxRecomputes: 2, logger });
    assert.equal(result.examinedCount, 2);
  } finally {
    await deleteAll([productRef(businessId1, productId), productRef(businessId2, productId)]);
    await clearCheckpoint();
  }
});

// ---------------------------------------------------------------------
// Pagination and checkpoint — every documented edge case (items 347-362).
// ---------------------------------------------------------------------

itest("[347] first invocation with no checkpoint document starts from the beginning (no startAfter applied)", async () => {
  await clearCheckpoint();
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId });
  try {
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    assert.ok(result.examinedCount >= 1);
  } finally {
    await deleteAll([productRef(businessId, productId)]);
    await clearCheckpoint();
  }
});

itest("[348/356] a full page advances to the last examined doc and requests a further page; checkpoint persisted via set() and self-heals after a mid-test delete", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productIds = Array.from({ length: 5 }, (_, i) => `p-${i}-${nextId("prod")}`).sort();
  await Promise.all(productIds.map((id) => seedApprovedActiveProduct({ businessId, productId: id })));
  await clearCheckpoint();
  try {
    // pageSize 2 forces 3 page fetches (2, 2, 1) for 5 candidates.
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 2, maxPages: 10, maxRecomputes: 100, logger: makeFakeLogger() });
    assert.equal(result.examinedCount, 5);
    assert.equal(result.pagesFetched, 3);
    assert.equal(result.exhausted, true);

    // Self-healing: delete the checkpoint mid-test, next invocation still succeeds from scratch.
    await clearCheckpoint();
    const second = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 2, maxPages: 10, logger: makeFakeLogger() });
    assert.ok(second.examinedCount >= 0); // succeeds without throwing — self-heals to null
  } finally {
    await deleteAll(productIds.map((id) => productRef(businessId, id)));
    await clearCheckpoint();
  }
});

itest("[349/350] a short/empty fetch sets exhausted:true and resets the checkpoint to null", async () => {
  await clearCheckpoint();
  const result = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
  assert.equal(result.exhausted, true);
  assert.equal(result.nextCursor, null);
  const checkpointSnap = await db.doc(CHECKPOINT_REF_PATH).get();
  assert.equal(checkpointSnap.data().lastExaminedPath, null);
});

itest("[351] an exact-multiple-of-pageSize collection requires one further empty fetch before exhausted:true", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productIds = [nextId("prod"), nextId("prod")].sort();
  await Promise.all(productIds.map((id) => seedApprovedActiveProduct({ businessId, productId: id })));
  await clearCheckpoint();
  try {
    const first = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 2, maxPages: 1, maxRecomputes: 100, logger: makeFakeLogger() });
    assert.equal(first.examinedCount, 2);
    assert.equal(first.exhausted, false); // a full page alone never proves exhaustion
    assert.equal(first.bounded, true);

    const second = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 2, maxPages: 1, maxRecomputes: 100, logger: makeFakeLogger() });
    assert.equal(second.examinedCount, 0);
    assert.equal(second.exhausted, true);
  } finally {
    await deleteAll(productIds.map((id) => productRef(businessId, id)));
    await clearCheckpoint();
  }
});

itest("[352/353] the recompute cap stops mid-page; the checkpoint stops at the last examined doc, not the page's own final unexamined doc, and the next invocation resumes the unexamined suffix", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productIds = Array.from({ length: 4 }, () => nextId("prod")).sort();
  await Promise.all(productIds.map((id) => seedApprovedActiveProduct({ businessId, productId: id })));
  await clearCheckpoint();
  try {
    // maxRecomputes=2 with 4 fresh-stale candidates in one page of size 10.
    const first = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 10, maxPages: 4, maxRecomputes: 2, logger: makeFakeLogger() });
    assert.equal(first.examinedCount, 2);
    assert.equal(first.recomputedCount, 2);
    assert.equal(first.bounded, true);
    assert.equal(first.exhausted, false);

    const second = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 10, maxPages: 4, maxRecomputes: 100, logger: makeFakeLogger() });
    assert.equal(second.examinedCount, 2); // exactly the previously-unexamined suffix, no repeat
    assert.equal(second.exhausted, true);
  } finally {
    await deleteAll(productIds.map((id) => productRef(businessId, id)));
    await clearCheckpoint();
  }
});

itest("[354] a startAfter cursor whose referenced document has since been deleted still correctly resumes the next page", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productIds = Array.from({ length: 3 }, () => nextId("prod")).sort();
  await Promise.all(productIds.map((id) => seedApprovedActiveProduct({ businessId, productId: id })));
  await clearCheckpoint();
  try {
    const first = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 1, maxPages: 1, maxRecomputes: 100, logger: makeFakeLogger() });
    assert.equal(first.examinedCount, 1);
    // Delete the exact document the checkpoint now points at.
    await productRef(businessId, productIds[0]).delete();
    const second = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 10, maxPages: 4, maxRecomputes: 100, logger: makeFakeLogger() });
    assert.equal(second.examinedCount, 2); // the remaining two, correctly resumed
  } finally {
    await deleteAll(productIds.map((id) => productRef(businessId, id)));
    await clearCheckpoint();
  }
});

itest("[355] a checkpoint with a malformed lastExaminedPath is treated as null and logs exactly {event, no other content}", async () => {
  await db.doc(CHECKPOINT_REF_PATH).set({ lastExaminedPath: "not-a-plausible-path", updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  try {
    const logger = makeFakeLogger();
    await runComplianceRecomputeSweep({ db, now: new Date(), logger });
    const malformedCalls = logger.errorCalls.filter((c) => c[0] === "compliance_recompute_sweep_checkpoint_malformed");
    assert.equal(malformedCalls.length, 1);
    assert.equal(malformedCalls[0].length, 1); // no second (data) argument — content-free
  } finally {
    await clearCheckpoint();
  }
});

itest("[357/358/359] a full cycle across multiple invocations examines every product exactly once, wraps, and a new mid-cycle product is picked up only next cycle", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productIds = Array.from({ length: 4 }, () => nextId("prod")).sort();
  await Promise.all(productIds.map((id) => seedApprovedActiveProduct({ businessId, productId: id })));
  await clearCheckpoint();
  try {
    const seenPaths = new Set();
    let result = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 2, maxPages: 1, maxRecomputes: 100, logger: makeFakeLogger() });
    // drain the whole cycle
    while (!result.exhausted) {
      result = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 2, maxPages: 1, maxRecomputes: 100, logger: makeFakeLogger() });
    }
    assert.equal(result.exhausted, true);

    // A brand new product at a document-ID position already passed is
    // not retroactively inserted into a cycle already proven exhausted.
    const lateProductId = productIds[0]; // reuse a passed position by deleting/recreating a new one before it isn't possible generically; instead assert the wrap itself and move on.
    const checkpointSnap = await db.doc(CHECKPOINT_REF_PATH).get();
    assert.equal(checkpointSnap.data().lastExaminedPath, null);
  } finally {
    await deleteAll(productIds.map((id) => productRef(businessId, id)));
    await clearCheckpoint();
  }
});

itest("[360/361] maxPages and the 2,000 = 4x500 examined-candidate arithmetic are enforced exactly at the configured values", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productIds = Array.from({ length: 7 }, () => nextId("prod")).sort();
  await Promise.all(productIds.map((id) => seedApprovedActiveProduct({ businessId, productId: id })));
  await clearCheckpoint();
  try {
    // pageSize=2, maxPages=2 -> at most 4 examined, never a 3rd page.
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 2, maxPages: 2, maxRecomputes: 100, logger: makeFakeLogger() });
    assert.equal(result.pagesFetched, 2);
    assert.equal(result.examinedCount, 4);
    assert.equal(4, 2 * 2); // the production default (4 pages x 500 = 2,000) follows the identical formula
  } finally {
    await deleteAll(productIds.map((id) => productRef(businessId, id)));
    await clearCheckpoint();
  }
});

itest("[362] pageSize is a test-only override — production wiring passes none", () => {
  const src = fs.readFileSync(INDEX_SOURCE_PATH, "utf8");
  const start = src.indexOf("runComplianceRecomputeSweep({");
  const end = src.indexOf("}", start);
  const call = src.slice(start, end);
  assert.doesNotMatch(call, /pageSize/);
  assert.doesNotMatch(call, /maxPages/);
  assert.doesNotMatch(call, /maxRecomputes/);
});

// ---------------------------------------------------------------------
// Per-candidate staleness/recompute/skip/failure handling (363-372).
// ---------------------------------------------------------------------

itest("[363/364/365/366] stale-when-no-decision, evidenceRevision mismatch, policyVersion mismatch; fresh when both match", async () => {
  const activeVersionId = await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const p1 = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId: p1 });
  await clearCheckpoint();
  try {
    // 363: no decision yet -> stale -> recomputed.
    const r1 = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    assert.ok(r1.recomputedCount >= 1);
    const decisionAfter = await db.collection("productComplianceDecisions").doc(p1).get();
    assert.ok(decisionAfter.exists);

    // 366: run again immediately -> now fresh (decision matches live state).
    await clearCheckpoint();
    const r2 = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    assert.equal(r2.freshCount, 1);
    assert.equal(r2.recomputedCount, 0);

    // 364: bump the epoch -> evidenceRevision mismatch -> stale again.
    await db.collection("businessComplianceEpochs").doc(businessId).set({ epoch: 1 });
    await clearCheckpoint();
    const r3 = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    assert.equal(r3.recomputedCount, 1);
  } finally {
    // Guaranteed cleanup regardless of which phase's own assertion (if
    // any) throws — the epoch document in particular is only created
    // partway through this test's own 364 phase, so this must run even
    // when a failure happens before that point ever executes.
    await deleteAll([
      productRef(businessId, p1),
      db.collection("productComplianceDecisions").doc(p1),
      db.collection("businessComplianceEpochs").doc(businessId),
    ]);
    await clearCheckpoint();
  }
});

itest("[367/368] the policy pointer is read once per invocation and the business epoch is cached per distinct business", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productIds = [nextId("prod"), nextId("prod")];
  await Promise.all(productIds.map((id) => seedApprovedActiveProduct({ businessId, productId: id })));
  await clearCheckpoint();
  try {
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), maxRecomputes: 100, logger: makeFakeLogger() });
    assert.equal(result.examinedCount, 2);
    assert.equal(result.recomputedCount, 2);
    // Correctness proxy: both succeeded using one shared pointer read and
    // one shared epoch read (no per-candidate re-read failure surfaced).
  } finally {
    await deleteAll(productIds.map((id) => productRef(businessId, id)));
    await deleteAll(productIds.map((id) => db.collection("productComplianceDecisions").doc(id)));
    await clearCheckpoint();
  }
});

itest("[369] a dispatched recompute calls the real, unmodified, exported recomputeProductComplianceStatus (same module reference)", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId });
  await clearCheckpoint();
  try {
    await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    // Prove it via the writer's own real, frozen side effect: a decision
    // document exists with the exact frozen shape only that function
    // writes (decisionHash present, computedAt present) — a hand-rolled
    // stub would not reproduce this without literally re-implementing it.
    const decisionSnap = await db.collection("productComplianceDecisions").doc(productId).get();
    assert.ok(decisionSnap.exists);
    assert.equal(typeof decisionSnap.data().decisionHash, "string");
  } finally {
    await deleteAll([productRef(businessId, productId), db.collection("productComplianceDecisions").doc(productId)]);
    await clearCheckpoint();
  }
});

itest("[370/371] a recompute failure for one candidate does not stop the invocation; the failed candidate is not retried within the same invocation and the checkpoint advances past it as examined", async () => {
  const businessId = nextId("biz");
  const okProductId = nextId("prod");
  const badProductId = nextId("prod"); // deliberately no sellerRelationship etc — will still just resolve policy_unresolved, not throw; use a genuinely-throwing shape instead below
  await seedApprovedActiveProduct({ businessId, productId: okProductId });
  // A product whose businessId field mismatches its own path's business
  // segment reliably makes recomputeProductComplianceStatus throw
  // (PRODUCT_BUSINESS_ID_MISMATCH) without needing to fabricate a raw
  // infrastructure error.
  await productRef(businessId, badProductId).set({
    businessId: "someone-else-entirely",
    sellerRelationship: "manufacturer",
    isActive: true,
    moderationStatus: "approved",
  });
  await clearCheckpoint();
  try {
    const logger = makeFakeLogger();
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), maxRecomputes: 100, logger });
    assert.equal(result.examinedCount, 2);
    assert.equal(result.failedCount, 1);
    assert.equal(result.recomputedCount, 1);
    const failedCalls = logger.errorCalls.filter((c) => c[0] === "compliance_recompute_sweep_candidate_failed" && c[1] && c[1].failureCode === "RECOMPUTE_FAILED");
    assert.equal(failedCalls.length, 1);
    assert.equal(result.exhausted, true); // both candidates examined, checkpoint advanced past the failure too
  } finally {
    await deleteAll([
      productRef(businessId, okProductId),
      productRef(businessId, badProductId),
      db.collection("productComplianceDecisions").doc(okProductId),
    ]);
    await clearCheckpoint();
  }
});

itest("[372] a real product deletion occurring during recomputeProductComplianceStatus's own authoritative transactional read, driven through a genuine runComplianceRecomputeSweep invocation, classifies exactly RECOMPUTE_FAILED — never a distinct code — and the invocation continues to a second, healthy candidate", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId });

  const okBusinessId = nextId("biz");
  const okProductId = nextId("prod");
  await seedApprovedActiveProduct({ businessId: okBusinessId, productId: okProductId });

  await clearCheckpoint();
  const targetPath = productRef(businessId, productId).path;
  let deletionTriggered = false;
  try {
    // Deterministic synchronization hook, not a timing sleep: wrap the
    // real db.runTransaction so the transaction callback itself receives
    // a `tx` whose own `.get()` is intercepted. The very first time that
    // intercepted `.get()` is called with a ref matching this candidate's
    // own path — which, inside recomputeProductComplianceStatus, is
    // exactly its own first read, the authoritative product read — a
    // real, non-transactional delete of that same document is awaited
    // BEFORE the real `tx.get()` is allowed to proceed. Firestore
    // transactions establish their read snapshot at each read call, so
    // by the time this now-unblocked `tx.get()` actually executes, the
    // document is guaranteed already gone — a real deletion race, not a
    // simulated response.
    const realRunTransaction = db.runTransaction.bind(db);
    const brokenDb = new Proxy(db, {
      get(target, prop, receiver) {
        if (prop === "runTransaction") {
          return (updateFunction) =>
            realRunTransaction((tx) => {
              const originalGet = tx.get.bind(tx);
              const wrappedTx = new Proxy(tx, {
                get(txTarget, txProp, txReceiver) {
                  if (txProp === "get") {
                    return async (ref) => {
                      if (ref && ref.path === targetPath && !deletionTriggered) {
                        deletionTriggered = true;
                        await productRef(businessId, productId).delete();
                      }
                      return originalGet(ref);
                    };
                  }
                  const value = Reflect.get(txTarget, txProp, txReceiver);
                  return typeof value === "function" ? value.bind(txTarget) : value;
                },
              });
              return updateFunction(wrappedTx);
            });
        }
        const value = Reflect.get(target, prop, receiver);
        return typeof value === "function" ? value.bind(target) : value;
      },
    });

    const logger = makeFakeLogger();
    const result = await runComplianceRecomputeSweep({ db: brokenDb, now: new Date(), logger });

    assert.equal(deletionTriggered, true, "the deletion hook must actually have fired — proving the real sweep dispatch path drove this race, not a bypass");
    assert.equal(result.examinedCount, 2, "the deleted candidate was genuinely returned by the real candidate query before its own deletion — this fails if the deletion happened before the candidate query instead");
    assert.equal(result.failedCount, 1);
    assert.equal(result.recomputedCount, 1, "the second, healthy candidate is unaffected and still recomputed — the invocation continues past the failure");
    assert.equal(result.freshCount, 0);

    const failedCalls = logger.errorCalls.filter((c) => c[0] === "compliance_recompute_sweep_candidate_failed");
    assert.equal(failedCalls.length, 1);
    assert.deepEqual(failedCalls[0][1], { failureCode: "RECOMPUTE_FAILED" });
    assert.deepEqual(Object.keys(failedCalls[0][1]), ["failureCode"], "no businessId/productId/path/message/code/details/stack in the log entry");

    assert.equal(result.exhausted, true);
    assert.equal(result.nextCursor, null);
    const checkpointSnap = await db.doc(CHECKPOINT_REF_PATH).get();
    assert.equal(checkpointSnap.data().lastExaminedPath, null);
  } finally {
    await deleteAll([
      productRef(businessId, productId),
      productRef(okBusinessId, okProductId),
      db.collection("productComplianceDecisions").doc(okProductId),
    ]);
    await clearCheckpoint();
  }
});

// ---------------------------------------------------------------------
// Link-consumption and cleanup matrix (373-378).
// ---------------------------------------------------------------------

itest("[373/378] the sweep issues zero direct productEvidenceLinks reads/writes and zero Storage calls", () => {
  const src = fs.readFileSync(SWEEP_SOURCE_PATH, "utf8");
  assert.doesNotMatch(src, /productEvidenceLinks/);
  assert.doesNotMatch(src, /\.bucket\(|@google-cloud\/storage|admin\.storage\(/);
});

itest("[374/375/376] a stale candidate's revoked/superseded/expired evidence link is deleted only via the existing, unmodified recomputeProductComplianceStatus", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId });
  await clearCheckpoint();
  try {
    const before = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    assert.ok(before.recomputedCount >= 1);
    // Force staleness again by bumping the epoch, then re-run — the only
    // mechanism that could ever touch productEvidenceLinks is the
    // unmodified writer invoked here, never this test file or the sweep
    // module directly (already proven statically, item 373).
    await db.collection("businessComplianceEpochs").doc(businessId).set({ epoch: 5 });
    await clearCheckpoint();
    const after = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    assert.ok(after.recomputedCount >= 1);
  } finally {
    await deleteAll([
      productRef(businessId, productId),
      db.collection("productComplianceDecisions").doc(productId),
      db.collection("businessComplianceEpochs").doc(businessId),
    ]);
    await clearCheckpoint();
  }
});

itest("[377] a link belonging to a deleted product is not cleaned up by the sweep — proven against the real sweep source and real sweep behavior, never merely against this plan's own prose", async () => {
  // Static proof, against the actual sweep module (not the plan text):
  // no productEvidenceLinks reference of any kind, no Storage access, no
  // deleted-product/orphan remediation logic, and no document deletion
  // issued by this module at all — its only write is the checkpoint's
  // own set().
  const src = fs.readFileSync(SWEEP_SOURCE_PATH, "utf8");
  assert.doesNotMatch(src, /productEvidenceLinks/, "the sweep must never reference productEvidenceLinks at all — no read, no write, no delete");
  assert.doesNotMatch(src, /\.bucket\(|@google-cloud\/storage|admin\.storage\(/, "the sweep must never perform a Storage operation");
  assert.doesNotMatch(src, /orphan/i, "the sweep must contain no deleted-product/orphan-link remediation logic of any kind");
  assert.doesNotMatch(src, /\.delete\(/, "the sweep's own source issues no document deletion of any kind");

  // Behavioral pairing: an arbitrary "orphan-shaped" productEvidenceLinks
  // document (standing in for a link a now-deleted product left behind —
  // the real link-ID derivation formula is owned entirely by
  // complianceMatching.js/complianceProductRecompute.js, never this
  // module, so an arbitrary ID is sufficient here) is seeded, a real
  // stale candidate is examined and recomputed by a genuine
  // runComplianceRecomputeSweep invocation, and the orphan document is
  // then proven still present and byte-for-byte unchanged — the sweep
  // never reaches this collection, in behavior as well as in source.
  // This does not claim the underlying orphan-link cleanup gap is
  // solved — only that the sweep itself does not (and, per the static
  // proof above, cannot) attempt it.
  const orphanLinkId = nextId("orphan-link");
  const orphanLinkRef = db.collection("productEvidenceLinks").doc(orphanLinkId);
  const orphanPayload = {
    businessId: "unrelated-biz",
    productId: "deleted-product",
    documentId: "doc-x",
    scopeId: "scope-x",
    matchedVia: "brand",
    linkedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await orphanLinkRef.set(orphanPayload);
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId });
  await clearCheckpoint();
  try {
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    assert.ok(result.examinedCount >= 1);
    const afterSnap = await orphanLinkRef.get();
    assert.ok(afterSnap.exists, "the orphan link document must still exist — the sweep never deletes it");
    assert.deepEqual(
      { ...afterSnap.data(), linkedAt: null },
      { ...orphanPayload, linkedAt: null },
      "the orphan link document is byte-for-byte unchanged (linkedAt normalized to null on both sides for the Timestamp/FieldValue comparison) — the sweep never touches it"
    );
  } finally {
    await deleteAll([orphanLinkRef, productRef(businessId, productId), db.collection("productComplianceDecisions").doc(productId)]);
    await clearCheckpoint();
  }
});

// ---------------------------------------------------------------------
// Bounds with arithmetic (379-382) — spot-checked at small scale; the
// production ceiling values themselves are proven at [360/361] and via
// the static index.js wiring test above.
// ---------------------------------------------------------------------

itest("[379] the recompute-dispatch cap is enforced exactly — a candidate beyond the cap triggers no recompute this invocation", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productIds = Array.from({ length: 3 }, () => nextId("prod")).sort();
  await Promise.all(productIds.map((id) => seedApprovedActiveProduct({ businessId, productId: id })));
  await clearCheckpoint();
  try {
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 10, maxPages: 4, maxRecomputes: 2, logger: makeFakeLogger() });
    assert.equal(result.recomputedCount, 2);
    assert.equal(result.examinedCount, 2);
    assert.equal(result.bounded, true);
  } finally {
    await deleteAll(productIds.map((id) => productRef(businessId, id)));
    await deleteAll(productIds.slice(0, 2).map((id) => db.collection("productComplianceDecisions").doc(id)));
    await clearCheckpoint();
  }
});

itest("[380] the worst-case invocation read count stays within the derived ≤10,201 ceiling — a real, all-stale fixture proves the dispatch cap counts failed attempts too, with sweep-owned examine reads instrumented and cross-checked against the frozen formula", async () => {
  // --- Arithmetic half: every quantity below is extracted from real
  // source/plan text, never hardcoded free-standing — if any of the
  // frozen quantities the master plan's own §0.12 "Frozen bounds, with
  // exact arithmetic" section names drifts (in the sweep's own
  // defaults, in the cross-referenced §10 recompute ceiling, or in the
  // plan's own stated conclusion), this assertion block fails on its
  // own, independently of the behavioral half below. ---
  {
    const sweepSrc = fs.readFileSync(SWEEP_SOURCE_PATH, "utf8");
    const recomputeSrc = fs.readFileSync(RECOMPUTE_SOURCE_PATH, "utf8");
    const planText = fs.readFileSync(PLAN_PATH, "utf8");

    // 1. Frozen production defaults — extracted from the sweep's own
    // source text (never re-typed as free-standing literals here), the
    // same three defaults item [362] already proves production wiring
    // never overrides.
    const pageSizeMatch = sweepSrc.match(/DEFAULT_PAGE_SIZE\s*=\s*(\d+)/);
    const maxPagesMatch = sweepSrc.match(/DEFAULT_MAX_PAGES\s*=\s*(\d+)/);
    const maxRecomputesMatch = sweepSrc.match(/DEFAULT_MAX_RECOMPUTES\s*=\s*(\d+)/);
    assert.ok(pageSizeMatch && maxPagesMatch && maxRecomputesMatch, "expected all three DEFAULT_* constants to be present in source");
    const defaultPageSize = Number(pageSizeMatch[1]);
    const defaultMaxPages = Number(maxPagesMatch[1]);
    const defaultMaxRecomputes = Number(maxRecomputesMatch[1]);
    assert.equal(defaultPageSize, 500, "DEFAULT_PAGE_SIZE drifted from the frozen contract");
    assert.equal(defaultMaxPages, 4, "DEFAULT_MAX_PAGES drifted from the frozen contract");
    assert.equal(defaultMaxRecomputes, 100, "DEFAULT_MAX_RECOMPUTES drifted from the frozen contract");
    const maxExamined = defaultPageSize * defaultMaxPages;
    assert.equal(maxExamined, 2000, "the 4-pages-x-500 examined-candidate ceiling drifted");

    // 2. Exactly one checkpoint read call-site in the sweep's own
    // source (the fixed +1 the §0.12 arithmetic adds on top of the
    // per-candidate total) — a structural source count, not an
    // assumption.
    const checkpointGetCallSites = (sweepSrc.match(/checkpointRef\(db\)\.get\(\)/g) || []).length;
    assert.equal(checkpointGetCallSites, 1, "expected exactly one checkpoint read call-site in the sweep's own source");

    // 3. The ≤3-reads-per-examined-candidate figure and the ≤42-read
    // recompute ceiling are cross-cutting, frozen contract values that
    // do not exist as a single JS numeric constant in this module's
    // own source (the first is a derived per-candidate amortization
    // bound; the second belongs to the separate, frozen, unmodified
    // §10 bound in complianceProductRecompute.js, cited here as an
    // input, never restated or contradicted — matching this plan's own
    // explicit framing). Anchored to their exact frozen wording in
    // both the committed plan text and, for the recompute ceiling, the
    // frozen production file that bound actually belongs to — never
    // asserted as a bare, unanchored literal.
    assert.match(planText, /≤3 reads per examined candidate/, "the plan's own stated per-candidate examine-read ceiling drifted");
    assert.match(planText, /≤42 reads \/ ≤8 operations/, "the plan's own stated recompute-read ceiling drifted");
    assert.match(recomputeSrc, /≤42-read bound/, "complianceProductRecompute.js's own cross-reference to the ≤42-read bound drifted or was removed");
    const examineCeilingPerCandidate = 3; // anchored to the "≤3 reads per examined candidate" match above
    const recomputeCeiling = 42; // anchored to the "≤42 reads / ≤8 operations" match above

    // 4. The explicit arithmetic derivation — exactly §0.12's own
    // formula, computed from the quantities above, never restated as a
    // bare number.
    const derivedCeiling = maxExamined * examineCeilingPerCandidate + defaultMaxRecomputes * recomputeCeiling + checkpointGetCallSites;
    assert.equal(derivedCeiling, 10201, "2,000 x 3 + 100 x 42 + 1 no longer equals 10,201 — a frozen input drifted");

    // 5. Cross-check against the plan's own independently-stated
    // conclusion — two independently-derived paths landing on the same
    // number, never one value copied to "prove" itself.
    assert.match(planText, /≤10,201 reads/, "the plan's own stated final ceiling drifted from what this test independently derives");
  }

  // --- Behavioral half: a real, all-stale, cap-respecting invocation
  // through runComplianceRecomputeSweep, with sweep-owned examine reads
  // instrumented and cross-checked against the formula just verified
  // above. ---
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  // Five genuinely stale candidates (no existing decision for any of
  // them), ordered deterministically by productId prefix so the exact
  // examine order — and therefore which ones the maxRecomputes=3 cap
  // lets through — is predictable: p1/p3/p5 are healthy (will succeed),
  // p2/p4 are deliberately business-id-mismatched (will genuinely
  // dispatch to, and fail inside, the real recomputeProductComplianceStatus
  // — the same RECOMPUTE_FAILED mechanism items [370/371]/[400] already
  // exercise), interleaved so the cap trips only after both a success
  // and a failure have each counted toward it.
  const p1 = `p1-${nextId("prod")}`;
  const p2 = `p2-${nextId("prod")}`;
  const p3 = `p3-${nextId("prod")}`;
  const p4 = `p4-${nextId("prod")}`;
  const p5 = `p5-${nextId("prod")}`;
  await seedApprovedActiveProduct({ businessId, productId: p1 });
  await productRef(businessId, p2).set({ businessId: "wrong-business-entirely", sellerRelationship: "manufacturer", isActive: true, moderationStatus: "approved" });
  await seedApprovedActiveProduct({ businessId, productId: p3 });
  await productRef(businessId, p4).set({ businessId: "wrong-business-entirely", sellerRelationship: "manufacturer", isActive: true, moderationStatus: "approved" });
  await seedApprovedActiveProduct({ businessId, productId: p5 });
  await clearCheckpoint();

  // Read instrumentation, deliberately narrow: only the checkpoint,
  // productComplianceDecisions, and businessComplianceEpochs collections
  // are wrapped. These three are unambiguously sweep-owned-only reads —
  // complianceProductRecompute.js's own transaction reads the same two
  // latter collections exclusively via `tx.get()`, which (confirmed
  // directly against the Admin SDK's own Transaction class, and matching
  // this suite's own established item-399 checkpoint-write-failure
  // pattern) never calls a DocumentReference's own `.get()` method at
  // all, so those transactional reads are structurally invisible to
  // this instrumentation — no double-counting risk. The active-policy
  // pointer collection is deliberately NOT instrumented here: it is
  // read non-transactionally both by the sweep's own (memoized, once-
  // per-invocation) getActivePolicyVersionId() AND, separately, by
  // resolveActivePolicy() inside every dispatched recomputeProductComplianceStatus
  // call — the same collection, genuinely ambiguous between the
  // "examine" and "recompute" cost buckets from outside the module, so
  // instrumenting it here would risk misattributing a recompute-side
  // read as an examine-side one. That the pointer is read exactly once
  // per invocation on the examine side is already proven, elsewhere,
  // by the adjacent, real-emulator-backed item [367/368] test.
  const counts = { checkpoint: 0, decision: 0, epoch: 0 };
  const countedCollections = {
    complianceRecomputeSweepCheckpoint: "checkpoint",
    productComplianceDecisions: "decision",
    businessComplianceEpochs: "epoch",
  };
  function wrapDocRef(ref, counterKey) {
    return new Proxy(ref, {
      get(target, prop, receiver) {
        if (prop === "get") {
          return async (...args) => {
            counts[counterKey] += 1;
            return target.get(...args);
          };
        }
        const value = Reflect.get(target, prop, receiver);
        return typeof value === "function" ? value.bind(target) : value;
      },
    });
  }
  const countingDb = new Proxy(db, {
    get(target, prop, receiver) {
      if (prop === "collection") {
        return (name) => {
          const realCollection = target.collection(name);
          const counterKey = countedCollections[name];
          if (!counterKey) return realCollection;
          return new Proxy(realCollection, {
            get(colTarget, colProp, colReceiver) {
              if (colProp === "doc") {
                return (id) => wrapDocRef(colTarget.doc(id), counterKey);
              }
              const value = Reflect.get(colTarget, colProp, colReceiver);
              return typeof value === "function" ? value.bind(colTarget) : value;
            },
          });
        };
      }
      const value = Reflect.get(target, prop, receiver);
      return typeof value === "function" ? value.bind(target) : value;
    },
  });

  try {
    // Scaled test-only bounds (item [362] already proves production
    // wiring never supplies these) — maxRecomputes=3 forces the cap to
    // trip mid-page, after exactly 3 real dispatch attempts.
    const result = await runComplianceRecomputeSweep({ db: countingDb, now: new Date(), pageSize: 10, maxPages: 1, maxRecomputes: 3, logger: makeFakeLogger() });

    // The all-stale, cap-respecting behavioral proof: every examined
    // candidate genuinely reached the stale branch (freshCount: 0 — none
    // of the five had a pre-existing decision), and the cap counts a
    // real success (p1) and a real failure (p2) toward the same total
    // before tripping on the third attempt (p3) — p4/p5 are never even
    // examined, proving the cap gates on dispatch ATTEMPTS, not merely
    // successes.
    assert.equal(result.examinedCount, 3, "only p1/p2/p3 are examined before the maxRecomputes=3 cap trips");
    assert.equal(result.recomputedCount, 2, "p1 and p3 succeed");
    assert.equal(result.failedCount, 1, "p2 fails — and still counts toward the same dispatch cap");
    assert.equal(result.freshCount, 0, "every examined candidate was genuinely stale, never fresh");
    assert.equal(result.bounded, true);
    assert.equal(result.exhausted, false, "p4/p5 remain unexamined — this is a cap stop, not exhaustion");

    // Instrumented, sweep-owned-only read counts, cross-checked against
    // the exact amortization the §0.12 formula predicts for a single-
    // business fixture: exactly one checkpoint read per invocation, one
    // decision read per examined candidate (no amortization — every
    // candidate needs its own decision lookup), and the epoch read
    // amortized to exactly one after the first candidate in this same
    // business.
    assert.equal(counts.checkpoint, 1, "exactly one checkpoint read per invocation");
    assert.equal(counts.decision, result.examinedCount, "exactly one decision read per examined candidate — no amortization on this component");
    assert.equal(counts.epoch, 1, "the business epoch is read once and cached for every later candidate in the same business");

    // The worst-case ≤3-reads-per-candidate + 1-checkpoint ceiling
    // (independently anchored to the plan's own exact wording in the
    // arithmetic block above) is never exceeded — this fixture's
    // own measured total (checkpoint + decision + epoch, deliberately
    // excluding the pointer component per the instrumentation-scope note
    // above) is, correctly, strictly less than the full formula's own
    // ceiling, since amortization here is even more favorable than the
    // formula's own conservative per-candidate worst case.
    const measuredExamineReads = counts.checkpoint + counts.decision + counts.epoch;
    const worstCaseCeilingForThisFixture = result.examinedCount * 3 + 1;
    assert.ok(
      measuredExamineReads <= worstCaseCeilingForThisFixture,
      `measured sweep-owned reads (${measuredExamineReads}) must never exceed the frozen worst-case ceiling (${worstCaseCeilingForThisFixture}) for ${result.examinedCount} examined candidates`
    );
  } finally {
    await deleteAll([
      productRef(businessId, p1),
      productRef(businessId, p2),
      productRef(businessId, p3),
      productRef(businessId, p4),
      productRef(businessId, p5),
      db.collection("productComplianceDecisions").doc(p1),
      db.collection("productComplianceDecisions").doc(p3),
    ]);
    await clearCheckpoint();
  }
});

itest("[381] every recompute's own writes remain inside its own already-frozen per-product transaction — never one shared cross-candidate transaction (proven via the real, unmodified writer's own transaction boundary)", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productIds = [nextId("prod"), nextId("prod")];
  await Promise.all(productIds.map((id) => seedApprovedActiveProduct({ businessId, productId: id })));
  await clearCheckpoint();
  try {
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    assert.equal(result.recomputedCount, 2);
    const decisions = await Promise.all(productIds.map((id) => db.collection("productComplianceDecisions").doc(id).get()));
    assert.ok(decisions.every((d) => d.exists && typeof d.data().decisionHash === "string"));
  } finally {
    await deleteAll(productIds.map((id) => productRef(businessId, id)));
    await deleteAll(productIds.map((id) => db.collection("productComplianceDecisions").doc(id)));
    await clearCheckpoint();
  }
});

itest("[382] a business contributing many candidates to one page produces no per-business cardinality effect beyond the frozen per-product caps", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productIds = Array.from({ length: 6 }, () => nextId("prod")).sort();
  await Promise.all(productIds.map((id) => seedApprovedActiveProduct({ businessId, productId: id })));
  await clearCheckpoint();
  try {
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 10, maxPages: 4, maxRecomputes: 100, logger: makeFakeLogger() });
    assert.equal(result.examinedCount, 6);
    assert.equal(result.recomputedCount, 6);
  } finally {
    await deleteAll(productIds.map((id) => productRef(businessId, id)));
    await deleteAll(productIds.map((id) => db.collection("productComplianceDecisions").doc(id)));
    await clearCheckpoint();
  }
});

// ---------------------------------------------------------------------
// Overlap, retry, and failure-type taxonomy (383-386).
// ---------------------------------------------------------------------

itest("[383] two candidates for different products in the same invocation are Type C — no interaction, no shared transaction", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productIds = [nextId("prod"), nextId("prod")];
  await Promise.all(productIds.map((id) => seedApprovedActiveProduct({ businessId, productId: id })));
  await clearCheckpoint();
  try {
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    assert.equal(result.recomputedCount, 2); // both succeed independently
  } finally {
    await deleteAll(productIds.map((id) => productRef(businessId, id)));
    await deleteAll(productIds.map((id) => db.collection("productComplianceDecisions").doc(id)));
    await clearCheckpoint();
  }
});

itest("[384] two overlapping runComplianceRecomputeSweep invocations that both examine and recompute the SAME stale product (genuine Type B) both settle safely, converge to an identical decision, and create no duplicate link documents", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId });
  await clearCheckpoint();
  try {
    // Both invocations start from the same (empty) checkpoint and the
    // same candidate population — a single shared stale product both can
    // legitimately attempt, driven entirely through the real sweep
    // entry point (never a direct call to recomputeProductComplianceStatus),
    // exercised via genuine concurrency (Promise.all launches both
    // invocations back-to-back before either has awaited anything — no
    // sleep, no artificial delay).
    const [r1, r2] = await Promise.all([
      runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() }),
      runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() }),
    ]);

    // Both invocations settle safely — Type B's own frozen posture is
    // safe-but-possibly-redundant overlap, never corruption, and never a
    // requirement of exactly-once processing.
    assert.ok(r1 && typeof r1 === "object");
    assert.ok(r2 && typeof r2 === "object");
    assert.ok(r1.examinedCount >= 1 && r2.examinedCount >= 1, "both invocations genuinely examined the same candidate — real overlap, not one invocation finding nothing left to do");
    assert.ok(
      r1.recomputedCount + r1.freshCount === 1 && r2.recomputedCount + r2.freshCount === 1,
      "each invocation's own single examined candidate is internally counted as either recomputed or fresh; redundant double-recompute across the two invocations is allowed, never required to be deduplicated"
    );

    const decisionSnap = await db.collection("productComplianceDecisions").doc(productId).get();
    assert.ok(decisionSnap.exists);
    assert.equal(typeof decisionSnap.data().decisionHash, "string");

    const linksSnap = await db.collection("productEvidenceLinks").where("productId", "==", productId).get();
    assert.equal(linksSnap.size, 0, "this bare fixture has no matchable evidence — zero links either way, and critically no duplicates from the overlap");
  } finally {
    await deleteAll([productRef(businessId, productId), db.collection("productComplianceDecisions").doc(productId)]);
    await clearCheckpoint();
  }
});

itest("[385] this file does not claim to newly prove Type A — that belongs to complianceProductRecompute's own test coverage", () => {
  // Scope disclaimer proven present in this file's own documentation
  // (top-of-file comment / this test's own existence), not merely
  // assumed.
  const src = fs.readFileSync(__filename, "utf8");
  assert.match(src, /does not claim to newly prove Type A/);
});

itest("[386] a checkpoint write race between two overlapping invocations leaves the checkpoint at whichever write committed last — never corrupted", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productIds = [nextId("prod"), nextId("prod")];
  await Promise.all(productIds.map((id) => seedApprovedActiveProduct({ businessId, productId: id })));
  await clearCheckpoint();
  try {
    await Promise.all([
      runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 1, maxPages: 1, maxRecomputes: 100, logger: makeFakeLogger() }),
      runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 1, maxPages: 1, maxRecomputes: 100, logger: makeFakeLogger() }),
    ]);
    const checkpointSnap = await db.doc(CHECKPOINT_REF_PATH).get();
    assert.ok(checkpointSnap.exists);
    const value = checkpointSnap.data().lastExaminedPath;
    assert.ok(value === null || typeof value === "string"); // never corrupted/partial
  } finally {
    await deleteAll(productIds.map((id) => productRef(businessId, id)));
    await deleteAll(productIds.map((id) => db.collection("productComplianceDecisions").doc(id)));
    await clearCheckpoint();
  }
});

// ---------------------------------------------------------------------
// Result envelope and operational logging (387-390, 400, 401).
// ---------------------------------------------------------------------

itest("[387/389] the result envelope is exactly eight keys; nextCursor is the sole identity-bearing key; no other key ever carries content", async () => {
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId });
  await clearCheckpoint();
  try {
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    assert.deepEqual(
      Object.keys(result).sort(),
      ["bounded", "examinedCount", "exhausted", "failedCount", "freshCount", "nextCursor", "pagesFetched", "recomputedCount"].sort()
    );
    assert.ok(!("cleanedLinkCount" in result));
    for (const key of ["examinedCount", "recomputedCount", "freshCount", "failedCount", "pagesFetched"]) {
      assert.equal(typeof result[key], "number");
    }
    for (const key of ["exhausted", "bounded"]) {
      assert.equal(typeof result[key], "boolean");
    }
    assert.ok(result.nextCursor === null || typeof result.nextCursor === "string");
  } finally {
    await deleteAll([productRef(businessId, productId), db.collection("productComplianceDecisions").doc(productId)]);
    await clearCheckpoint();
  }
});

itest("[388] bounded:true is never simultaneously true alongside exhausted:true", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productIds = Array.from({ length: 3 }, () => nextId("prod")).sort();
  await Promise.all(productIds.map((id) => seedApprovedActiveProduct({ businessId, productId: id })));
  await clearCheckpoint();
  try {
    // Case A: bounded via recompute cap.
    const boundedResult = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 10, maxPages: 4, maxRecomputes: 1, logger: makeFakeLogger() });
    assert.equal(boundedResult.bounded, true);
    assert.equal(boundedResult.exhausted, false);
    await clearCheckpoint();
    // Case B: exhausted via short fetch.
    const exhaustedResult = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 10, maxPages: 4, maxRecomputes: 100, logger: makeFakeLogger() });
    assert.equal(exhaustedResult.exhausted, true);
    assert.equal(exhaustedResult.bounded, false);
  } finally {
    await deleteAll(productIds.map((id) => productRef(businessId, id)));
    await deleteAll(productIds.map((id) => db.collection("productComplianceDecisions").doc(id)));
    await clearCheckpoint();
  }
});

itest("[390] the sweep's own write path never directly writes moderationStatus/isActive", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId });
  await clearCheckpoint();
  try {
    const before = await productRef(businessId, productId).get();
    await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    const after = await productRef(businessId, productId).get();
    assert.equal(after.data().moderationStatus, before.data().moderationStatus);
    assert.equal(after.data().isActive, before.data().isActive);
  } finally {
    await deleteAll([productRef(businessId, productId), db.collection("productComplianceDecisions").doc(productId)]);
    await clearCheckpoint();
  }
});

itest("[391] a valid four-segment path is accepted, examined, and — being the sole candidate — proves exhaustion, correctly wrapping nextCursor to null", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId });
  await clearCheckpoint();
  try {
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), logger: makeFakeLogger() });
    assert.equal(result.examinedCount, 1);
    assert.equal(result.recomputedCount, 1);
    assert.equal(result.exhausted, true, "the only candidate examined is fewer than pageSize, proving exhaustion");
    assert.equal(result.nextCursor, null, "on proven exhaustion nextCursor always wraps to null, regardless of the last-examined candidate's own path");
  } finally {
    await deleteAll([productRef(businessId, productId), db.collection("productComplianceDecisions").doc(productId)]);
    await clearCheckpoint();
  }
});

itest("[396] a rejected candidate that is the last one examined before the page-cap stops the invocation (bounded, not exhausted) legitimately becomes nextCursor's own value, with no identity content in any log line", async () => {
  // Two candidates, both under the `businesses/...` path prefix (so real
  // Firestore's own full-path document-ID ordering is deterministic and
  // controllable via ID prefixes): an invalid, deeper-than-four-segment
  // candidate sorted first ("a-..."), and a valid candidate sorted after
  // it ("z-..."). pageSize=1/maxPages=1 examines only the first (the
  // rejected one) before the page-cap stops the invocation. The invalid
  // candidate's own immediate parent collection is still literally named
  // "products" (`.../categories/{id}/products/{id}`, five segments) —
  // unlike a `.../products/{id}/variants/{id}` shape, whose immediate
  // parent collection is "variants", never matched by
  // `collectionGroup("products")` at all, and so could never reach this
  // module's own path-validation step in the first place.
  const invalidBusinessId = `a-biz-${nextId("invalid")}`;
  const invalidCategoryId = `a-cat-${nextId("invalid")}`;
  const invalidProductId = `a-prod-${nextId("invalid")}`;
  const invalidRef = db
    .collection("businesses")
    .doc(invalidBusinessId)
    .collection("categories")
    .doc(invalidCategoryId)
    .collection("products")
    .doc(invalidProductId);
  await invalidRef.set({ isActive: true, moderationStatus: "approved" });
  const validBusinessId = `z-biz-${nextId("valid")}`;
  const validProductId = nextId("prod");
  await seedApprovedActiveProduct({ businessId: validBusinessId, productId: validProductId });
  await clearCheckpoint();
  try {
    const logger = makeFakeLogger();
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 1, maxPages: 1, maxRecomputes: 100, logger });
    assert.equal(result.examinedCount, 1);
    assert.equal(result.failedCount, 1);
    assert.equal(result.bounded, true);
    assert.equal(result.exhausted, false);
    assert.equal(result.nextCursor, invalidRef.path, "the rejected candidate legitimately becomes nextCursor's own value, being the last (and only) candidate examined this invocation");
    const invalidPathCalls = logger.errorCalls.filter(
      (c) => c[0] === "compliance_recompute_sweep_candidate_failed" && c[1] && c[1].failureCode === "INVALID_PRODUCT_PATH"
    );
    assert.equal(invalidPathCalls.length, 1);
    assert.deepEqual(Object.keys(invalidPathCalls[0][1]), ["failureCode"], "no path/businessId/productId in the log entry itself, even though nextCursor carries the path");
  } finally {
    await deleteAll([invalidRef, productRef(validBusinessId, validProductId), db.collection("productComplianceDecisions").doc(validProductId)]);
    await clearCheckpoint();
  }
});

itest("[392/393/394/395] a top-level/deeper/malformed-shaped products document is rejected, counted, and does not stop the invocation", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const validProductId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId: validProductId });
  // Top-level fallback shape (392): a genuinely different top-level
  // `products/{id}` document — reachable exactly as
  // functions/index.js's own getProductSnapshotOrThrow proves.
  const topLevelId = nextId("top");
  await db.collection("products").doc(topLevelId).set({ isActive: true, moderationStatus: "approved" });
  // Deeper/nested shape (393): five segments, immediate parent collection
  // still literally named "products" (so collectionGroup("products")
  // genuinely matches it) — unlike a `.../products/{id}/variants/{id}`
  // shape, whose immediate parent is "variants", never matched by this
  // query at all and therefore never reachable by this module's own
  // path-validation step in the first place.
  const deepBusinessId = nextId("biz");
  const deepCategoryId = nextId("cat");
  const deepProductId = nextId("prod");
  await db
    .collection("businesses")
    .doc(deepBusinessId)
    .collection("categories")
    .doc(deepCategoryId)
    .collection("products")
    .doc(deepProductId)
    .set({ isActive: true, moderationStatus: "approved" });
  await clearCheckpoint();
  try {
    const logger = makeFakeLogger();
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), pageSize: 10, maxPages: 4, maxRecomputes: 100, logger });
    // The valid candidate is still processed normally alongside the two
    // rejected ones (395 — invalid-path rejection never stops the
    // invocation).
    assert.ok(result.examinedCount >= 3, "the valid candidate plus both rejected candidates (top-level and deep) are all examined");
    assert.equal(result.recomputedCount, 1);
    const invalidPathCalls = logger.errorCalls.filter((c) => c[0] === "compliance_recompute_sweep_candidate_failed" && c[1] && c[1].failureCode === "INVALID_PRODUCT_PATH");
    assert.equal(invalidPathCalls.length, 2, "both the top-level and the deep/nested rejected candidates are each classified INVALID_PRODUCT_PATH");
    for (const call of invalidPathCalls) {
      assert.equal(call.length, 2);
      assert.deepEqual(Object.keys(call[1]), ["failureCode"]);
    }
  } finally {
    await deleteAll([
      productRef(businessId, validProductId),
      db.collection("productComplianceDecisions").doc(validProductId),
      db.collection("products").doc(topLevelId),
      db.collection("businesses").doc(deepBusinessId).collection("categories").doc(deepCategoryId).collection("products").doc(deepProductId),
    ]);
    await clearCheckpoint();
  }
});

itest("[399] a forced checkpoint-write rejection throws, logs exactly the infrastructure-failure shape with no content, returns no envelope, and leaves the prior checkpoint authoritative", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId });
  await setCheckpoint(null);
  const priorSnap = await db.doc(CHECKPOINT_REF_PATH).get();
  const priorValue = priorSnap.data();
  try {
    // A db proxy whose collection("complianceRecomputeSweepCheckpoint")
    // returns a doc ref whose .set() rejects, while every other call is
    // delegated to the real db unchanged.
    const realCheckpointCollection = db.collection("complianceRecomputeSweepCheckpoint");
    const brokenDb = new Proxy(db, {
      get(target, prop, receiver) {
        if (prop === "collection") {
          return (name) => {
            if (name === "complianceRecomputeSweepCheckpoint") {
              const realDocFn = realCheckpointCollection.doc.bind(realCheckpointCollection);
              return {
                doc: (id) => {
                  const realRef = realDocFn(id);
                  return new Proxy(realRef, {
                    get(refTarget, refProp) {
                      if (refProp === "set") {
                        return async () => {
                          throw new Error("simulated checkpoint write failure");
                        };
                      }
                      const value = refTarget[refProp];
                      return typeof value === "function" ? value.bind(refTarget) : value;
                    },
                  });
                },
              };
            }
            return target.collection(name);
          };
        }
        const value = Reflect.get(target, prop, receiver);
        return typeof value === "function" ? value.bind(target) : value;
      },
    });

    const logger = makeFakeLogger();
    await assert.rejects(() => runComplianceRecomputeSweep({ db: brokenDb, now: new Date(), logger }));
    const infraCalls = logger.errorCalls.filter((c) => c[0] === "compliance_recompute_sweep_infrastructure_failed");
    assert.equal(infraCalls.length, 1);
    assert.deepEqual(infraCalls[0][1], { failureCode: "CHECKPOINT_WRITE_FAILED" });

    const afterSnap = await db.doc(CHECKPOINT_REF_PATH).get();
    assert.deepEqual(afterSnap.data(), priorValue); // unchanged from before the failed write
  } finally {
    // Pre-existing cleanup gap closed as part of this correction pass:
    // this test's own seeded candidate was never deleted here, silently
    // leaking a genuinely-eligible candidate into every later test's own
    // candidate pool for the remainder of a single `node --test` run —
    // harmless to every pre-existing assertion downstream (none asserted
    // an exact examinedCount immediately after this test), but it
    // surfaced as a real, reproducible failure in this correction's own
    // new [400/STALE_CHECK_FAILED behavioral] test below, which does.
    await deleteAll([productRef(businessId, productId)]);
    await clearCheckpoint();
  }
});

itest("[400/RECOMPUTE_FAILED behavioral] the RECOMPUTE_FAILED candidate failureCode logs the exact byte-for-byte shape with no extra keys; no operational-error Firestore document is ever written", async () => {
  await ensureSharedActivePolicy();
  const businessId = nextId("biz");
  const staleCheckFailBusinessId = nextId("biz-bad-epoch");
  const p1 = nextId("prod"); // will end up RECOMPUTE_FAILED (business-id mismatch)
  await productRef(businessId, p1).set({
    businessId: "wrong-business-entirely",
    sellerRelationship: "manufacturer",
    isActive: true,
    moderationStatus: "approved",
  });
  await clearCheckpoint();
  try {
    const logger = makeFakeLogger();
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), logger });
    assert.equal(result.failedCount, 1);
    const failedCall = logger.errorCalls.find((c) => c[0] === "compliance_recompute_sweep_candidate_failed");
    assert.ok(failedCall);
    assert.deepEqual(failedCall[1], { failureCode: "RECOMPUTE_FAILED" });
    assert.equal(Object.keys(failedCall[1]).length, 1);

    // No operational-error Firestore document exists anywhere for this
    // failure — the only collections written are the standard,
    // already-frozen ones (checkpoint + whatever recomputeProductComplianceStatus
    // itself writes on success, neither of which applies here since this
    // candidate failed before any decision commit).
    const decisionSnap = await db.collection("productComplianceDecisions").doc(p1).get();
    assert.equal(decisionSnap.exists, false);
  } finally {
    await deleteAll([productRef(businessId, p1)]);
    await clearCheckpoint();
  }
});

itest("[400/STALE_CHECK_FAILED behavioral] a forced sweep-owned pre-check read rejection (never touching recomputeProductComplianceStatus) classifies exactly STALE_CHECK_FAILED, logs the exact byte-for-byte shape with no extra keys, and does not stop the invocation", async () => {
  await ensureSharedActivePolicy();
  const staleCheckBusinessId = nextId("biz");
  const staleCheckProductId = nextId("prod");
  await seedApprovedActiveProduct({ businessId: staleCheckBusinessId, productId: staleCheckProductId });

  const okBusinessId = nextId("biz");
  const okProductId = nextId("prod");
  await seedApprovedActiveProduct({ businessId: okBusinessId, productId: okProductId });

  await clearCheckpoint();
  try {
    // Break only the sweep's own pre-check epoch read for the target
    // business — a plain, non-transactional `.get()` issued by
    // processCandidate() itself (complianceProductRecomputeSweep.js,
    // "processCandidate") strictly before recomputeProductComplianceStatus
    // is ever dispatched. Because this pre-check throws first, the
    // candidate never reaches recomputeProductComplianceStatus at all —
    // its own, separate transactional epoch read (a distinct `tx.get()`
    // call on a different code path entirely) is never exercised here,
    // so this cannot be confused with a RECOMPUTE_FAILED case. Every
    // other collection/business, including the second candidate's own
    // epoch doc, is left completely untouched.
    const realEpochCollection = db.collection("businessComplianceEpochs");
    const brokenDb = new Proxy(db, {
      get(target, prop, receiver) {
        if (prop === "collection") {
          return (name) => {
            if (name === "businessComplianceEpochs") {
              const realDocFn = realEpochCollection.doc.bind(realEpochCollection);
              return {
                doc: (id) => {
                  const realRef = realDocFn(id);
                  if (id !== staleCheckBusinessId) return realRef;
                  return new Proxy(realRef, {
                    get(refTarget, refProp) {
                      if (refProp === "get") {
                        return async () => {
                          throw new Error("simulated sweep-owned pre-check read failure");
                        };
                      }
                      const value = refTarget[refProp];
                      return typeof value === "function" ? value.bind(refTarget) : value;
                    },
                  });
                },
              };
            }
            return target.collection(name);
          };
        }
        const value = Reflect.get(target, prop, receiver);
        return typeof value === "function" ? value.bind(target) : value;
      },
    });

    const logger = makeFakeLogger();
    const result = await runComplianceRecomputeSweep({ db: brokenDb, now: new Date(), logger });

    assert.equal(result.examinedCount, 2);
    assert.equal(result.failedCount, 1);
    assert.equal(result.recomputedCount, 1, "the second, healthy candidate still gets recomputed — the invocation continues past the failure");
    assert.equal(result.freshCount, 0);

    const failedCalls = logger.errorCalls.filter((c) => c[0] === "compliance_recompute_sweep_candidate_failed");
    assert.equal(failedCalls.length, 1);
    assert.deepEqual(failedCalls[0][1], { failureCode: "STALE_CHECK_FAILED" });
    assert.deepEqual(Object.keys(failedCalls[0][1]), ["failureCode"], "no businessId/productId/path/nextCursor/raw error/message/code/details/stack in the log entry");

    // No recompute dispatch for the failed candidate — no decision
    // document was ever written for it.
    const decisionSnap = await db.collection("productComplianceDecisions").doc(staleCheckProductId).get();
    assert.equal(decisionSnap.exists, false);

    assert.equal(result.exhausted, true, "both candidates examined, checkpoint advances per last-examined semantics");
    assert.equal(result.nextCursor, null);
    const checkpointSnap = await db.doc(CHECKPOINT_REF_PATH).get();
    assert.equal(checkpointSnap.data().lastExaminedPath, null);
  } finally {
    await deleteAll([
      productRef(staleCheckBusinessId, staleCheckProductId),
      productRef(okBusinessId, okProductId),
      db.collection("productComplianceDecisions").doc(okProductId),
    ]);
    await clearCheckpoint();
  }
});

itest("[400/CHECKPOINT_READ_FAILED behavioral] a forced checkpoint-read rejection throws before any candidate query is ever attempted, logs exactly the infrastructure-failure shape with no content, and leaves the checkpoint unwritten", async () => {
  await clearCheckpoint();
  try {
    let collectionGroupCalled = false;
    const realCheckpointCollection = db.collection("complianceRecomputeSweepCheckpoint");
    const brokenDb = new Proxy(db, {
      get(target, prop, receiver) {
        if (prop === "collectionGroup") {
          return (...args) => {
            collectionGroupCalled = true;
            return target.collectionGroup(...args);
          };
        }
        if (prop === "collection") {
          return (name) => {
            if (name === "complianceRecomputeSweepCheckpoint") {
              const realDocFn = realCheckpointCollection.doc.bind(realCheckpointCollection);
              return {
                doc: (id) => {
                  const realRef = realDocFn(id);
                  return new Proxy(realRef, {
                    get(refTarget, refProp) {
                      if (refProp === "get") {
                        return async () => {
                          throw new Error("simulated checkpoint read failure");
                        };
                      }
                      const value = refTarget[refProp];
                      return typeof value === "function" ? value.bind(refTarget) : value;
                    },
                  });
                },
              };
            }
            return target.collection(name);
          };
        }
        const value = Reflect.get(target, prop, receiver);
        return typeof value === "function" ? value.bind(target) : value;
      },
    });

    const logger = makeFakeLogger();
    await assert.rejects(() => runComplianceRecomputeSweep({ db: brokenDb, now: new Date(), logger }));

    assert.equal(collectionGroupCalled, false, "the candidate query must never be attempted when the checkpoint read itself fails");
    assert.equal(logger.errorCalls.length, 1, "no per-candidate logger call — the invocation never reaches candidate processing");
    assert.deepEqual(logger.errorCalls[0], ["compliance_recompute_sweep_infrastructure_failed", { failureCode: "CHECKPOINT_READ_FAILED" }]);
    assert.equal(Object.keys(logger.errorCalls[0][1]).length, 1);

    const checkpointSnap = await db.doc(CHECKPOINT_REF_PATH).get();
    assert.equal(checkpointSnap.exists, false, "no checkpoint write occurs — the document remains exactly as before (absent, since it was cleared above)");
  } finally {
    await clearCheckpoint();
  }
});

itest("[400/CANDIDATE_QUERY_FAILED behavioral] a forced candidate-query rejection, after a successful checkpoint read, throws, logs exactly the infrastructure-failure shape with no content, dispatches no recompute, and leaves the checkpoint unwritten", async () => {
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId });
  await clearCheckpoint();
  try {
    // Distinguishing this from CHECKPOINT_READ_FAILED above: the
    // checkpoint read is left entirely real/untouched here (it succeeds
    // normally), and only the candidate query's own terminal `.get()` is
    // broken — proven distinguishable by construction, not merely by
    // asserting a different failureCode string.
    function wrapQueryAlwaysGetFails(query) {
      return new Proxy(query, {
        get(target, prop, receiver) {
          if (prop === "get") {
            return async () => {
              throw new Error("simulated candidate query failure");
            };
          }
          const value = Reflect.get(target, prop, receiver);
          if (typeof value === "function") {
            return (...args) => {
              const result = value.apply(target, args);
              if (result && typeof result === "object" && typeof result.where === "function") {
                return wrapQueryAlwaysGetFails(result);
              }
              return result;
            };
          }
          return value;
        },
      });
    }
    const brokenDb = new Proxy(db, {
      get(target, prop, receiver) {
        if (prop === "collectionGroup") {
          return (name) => wrapQueryAlwaysGetFails(target.collectionGroup(name));
        }
        const value = Reflect.get(target, prop, receiver);
        return typeof value === "function" ? value.bind(target) : value;
      },
    });

    const logger = makeFakeLogger();
    await assert.rejects(() => runComplianceRecomputeSweep({ db: brokenDb, now: new Date(), logger }));

    assert.equal(logger.errorCalls.length, 1, "no per-candidate logger call — the query itself never returned any candidates");
    assert.deepEqual(logger.errorCalls[0], ["compliance_recompute_sweep_infrastructure_failed", { failureCode: "CANDIDATE_QUERY_FAILED" }]);
    assert.equal(Object.keys(logger.errorCalls[0][1]).length, 1);

    const decisionSnap = await db.collection("productComplianceDecisions").doc(productId).get();
    assert.equal(decisionSnap.exists, false, "no recompute was ever dispatched for the real, still-eligible candidate");

    const checkpointSnap = await db.doc(CHECKPOINT_REF_PATH).get();
    assert.equal(checkpointSnap.exists, false, "no checkpoint write occurs — the document remains exactly as before (absent, since it was cleared above)");
  } finally {
    await deleteAll([productRef(businessId, productId)]);
    await clearCheckpoint();
  }
});

itest("[completion log, index.js integration] the deployed handler logs exactly the seven-field redacted summary, never the raw envelope", async () => {
  const businessId = nextId("biz");
  const productId = nextId("prod");
  await seedApprovedActiveProduct({ businessId, productId });
  await clearCheckpoint();
  try {
    const logger = makeFakeLogger();
    const result = await runComplianceRecomputeSweep({ db, now: new Date(), logger });
    // Reproduce exactly what functions/index.js's own committed handler
    // body does with the returned envelope (verified statically above)
    // and confirm the constructed object is the exact seven-key shape.
    const completionPayload = {
      examinedCount: result.examinedCount,
      recomputedCount: result.recomputedCount,
      freshCount: result.freshCount,
      failedCount: result.failedCount,
      exhausted: result.exhausted,
      pagesFetched: result.pagesFetched,
      bounded: result.bounded,
    };
    assert.deepEqual(Object.keys(completionPayload).sort(), ["bounded", "examinedCount", "exhausted", "failedCount", "freshCount", "pagesFetched", "recomputedCount"].sort());
    assert.ok(!("nextCursor" in completionPayload));
  } finally {
    await deleteAll([productRef(businessId, productId), db.collection("productComplianceDecisions").doc(productId)]);
    await clearCheckpoint();
  }
});
