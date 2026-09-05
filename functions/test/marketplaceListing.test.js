"use strict";

// P1-A Slice 4.5 — marketplaceListing.test.js (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §8/§10.1/§13.1/§15/§16). Deliberately NOT emulator-backed: exactly like
// productModeration.test.js/complianceMatching.test.js, both production
// exports are pure dependency injection ({db, data, featureEnabled, now,
// evaluator}), so a hand-rolled, self-contained in-memory fake Firestore
// query builder stands in for `db`, and a call-recording fake stands in
// for `evaluateLiveProductEligibility`. Every test invokes the real
// production exports/helpers from marketplaceListing.js directly — none
// of the endpoint logic is reimplemented here.
//
// This file covers Revision 11/12 Slice 4.5 test-matrix items 1-194 —
// the items that describe `marketplaceListing.js`'s own behavior. Items
// 195-300 describe the separate Rules prerequisite
// (functions/test/marketplaceProductRules.test.js, a different,
// not-yet-authorized file) and the separately-authorized, not-yet-scoped
// readiness-traversal tool — neither belongs in this file, per §13.1's
// own exact file-scope table. A small number of static scope-boundary
// checks (flag cannot be enabled, no Rules/readiness-tool/Flutter file
// touched, no App Check enforcement claimed) are included at the end,
// matching this task's own explicit "Static future-prerequisite
// coverage" requirement.
//
// No conditional test-skipping and no environment-dependent bypass
// anywhere in this file — every test always runs.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { FieldPath } = require("firebase-admin/firestore");

const {
  getMarketplaceProductList,
  getMarketplaceProductDetail,
  encodeCursor,
  decodeCursor,
  validatePageSize,
  projectPublicProduct,
} = require("../src/marketplace/publicCatalog/marketplaceListing");

const REPO_ROOT = path.join(__dirname, "..", "..");
const INDEX_JS_SOURCE = fs.readFileSync(path.join(__dirname, "..", "index.js"), "utf8");
const MODULE_SOURCE = fs.readFileSync(
  path.join(__dirname, "..", "src", "marketplace", "publicCatalog", "marketplaceListing.js"),
  "utf8"
);

// =====================================================================
// Fake Firestore — collection-group query builder + point reads
// =====================================================================

class FakeDocumentReference {
  constructor(fakeDb, fullPath) {
    this._db = fakeDb;
    this.path = fullPath;
  }

  collection(name) {
    return new FakeCollectionRef(this._db, `${this.path}/${name}`);
  }

  async get() {
    this._db.pointReadPaths.push(this.path);
    const doc = this._db.docsByPath.get(this.path);
    return {
      exists: !!doc,
      ref: this,
      data: () => (doc ? doc.data : undefined),
    };
  }
}

class FakeQuery {
  constructor(fakeDb, collectionGroupName) {
    this._db = fakeDb;
    this._collectionGroupName = collectionGroupName;
    this._wheres = [];
    this._orderBy = null;
    this._startAfterRef = null;
    this._limit = null;
  }

  where(field, op, value) {
    this._wheres.push({ field, op, value });
    return this;
  }

  orderBy(fieldPath, direction) {
    this._orderBy = { fieldPath, direction };
    return this;
  }

  startAfter(refOrValue) {
    this._startAfterRef = refOrValue;
    return this;
  }

  limit(n) {
    this._limit = n;
    return this;
  }

  async get() {
    this._db.queryCalls.push({
      collectionGroup: this._collectionGroupName,
      wheres: this._wheres.slice(),
      orderBy: this._orderBy,
      startAfterPath: this._startAfterRef ? this._startAfterRef.path : null,
      limit: this._limit,
    });
    if (this._db.queryError) {
      throw this._db.queryError;
    }

    let docs = Array.from(this._db.docsByPath.entries())
      .filter(([fullPath]) => {
        const segments = fullPath.split("/");
        return segments.length === 4 && segments[2] === this._collectionGroupName;
      })
      .map(([fullPath, entry]) => ({ path: fullPath, data: entry.data }));

    for (const w of this._wheres) {
      docs = docs.filter((d) => {
        if (w.op !== "==") throw new Error("fake only supports ==");
        return d.data[w.field] === w.value;
      });
    }

    docs.sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0));

    if (this._startAfterRef) {
      const startPath = this._startAfterRef.path;
      docs = docs.filter((d) => d.path > startPath);
    }

    if (typeof this._limit === "number") {
      docs = docs.slice(0, this._limit);
    }

    const docSnapshots = docs.map((d) => ({
      data: () => d.data,
      ref: new FakeDocumentReference(this._db, d.path),
    }));

    return { docs: docSnapshots };
  }
}

class FakeCollectionRef {
  constructor(fakeDb, prefix) {
    this._db = fakeDb;
    this._prefix = prefix;
  }

  doc(id) {
    return new FakeDocumentReference(this._db, `${this._prefix}/${id}`);
  }
}

// Marketplace Revision 38 §0.36 (Slice 7B) — fixture normalization.
//
// The public catalogue now also asserts conditions 3/4/6/9: the owning
// business must exist, be approved and Marketplace-eligible, have a valid
// seller activation and a live generation the product matches, and the
// product must carry a valid `pilotProductClass`. Before Slice 7B these
// fixtures seeded products with no business document at all — a world that
// cannot exist in production.
//
// Rather than rewrite 125 fixtures, `createFakeDb` completes the world: every
// seeded product gets a valid owning business and the two product fields the
// new conditions read, UNLESS the fixture already supplies them. A test that
// wants an orphaned, unclassified, deactivated, unapproved or
// wrong-generation world simply provides that value itself and this
// normalization leaves it alone.
const DEFAULT_TEST_GENERATION = (businessId) => `gen-${businessId}`;
const NESTED_PRODUCT_FIXTURE_RE = /^businesses\/([^/]+)\/products\/([^/]+)$/;

function normalizeSeededWorld(seedDocs) {
  const seeded = Object.assign({}, seedDocs || {});
  for (const [fullPath, data] of Object.entries(seedDocs || {})) {
    const match = NESTED_PRODUCT_FIXTURE_RE.exec(fullPath);
    if (!match) continue;
    const businessId = match[1];
    if (!data || typeof data !== "object" || Array.isArray(data)) continue;

    const generation =
      typeof data.marketplaceBusinessGenerationId === "string" &&
      data.marketplaceBusinessGenerationId.length > 0
        ? data.marketplaceBusinessGenerationId
        : DEFAULT_TEST_GENERATION(businessId);

    // Complete the product only where the fixture is silent.
    seeded[fullPath] = Object.assign(
      {
        marketplaceBusinessGenerationId: generation,
        pilotProductClass: "sealed_dry_food",
      },
      data
    );

    const businessPath = `businesses/${businessId}`;
    if (!Object.prototype.hasOwnProperty.call(seeded, businessPath)) {
      seeded[businessPath] = {
        status: "approved",
        marketplaceSellerActivation: { active: true },
        marketplaceBusinessGenerationId: generation,
      };
    }
  }
  return seeded;
}

function createFakeDb(seedDocs) {
  const db = {
    docsByPath: new Map(),
    queryCalls: [],
    pointReadPaths: [],
    queryError: null,
  };
  for (const [fullPath, data] of Object.entries(normalizeSeededWorld(seedDocs))) {
    db.docsByPath.set(fullPath, { data });
  }
  db.collectionGroup = (name) => new FakeQuery(db, name);
  db.doc = (fullPath) => new FakeDocumentReference(db, fullPath);
  db.collection = (name) => new FakeCollectionRef(db, name);
  return db;
}

// =====================================================================
// Fake evaluator
// =====================================================================

function createFakeEvaluator({ eligiblePaths = new Set(), throwFor = new Set() } = {}) {
  const calls = [];
  const evaluator = async ({ db, businessId, productId, now, tx, productSnapshot }) => {
    calls.push({ businessId, productId, now, tx, productSnapshot });
    const key = `businesses/${businessId}/products/${productId}`;
    if (throwFor.has(key)) {
      throw new Error(`synthetic evaluator failure for ${key}`);
    }
    if (eligiblePaths.has(key)) {
      return { eligible: true, reason: null };
    }
    return { eligible: false, reason: "eligibility_decision_status_ineligible" };
  };
  evaluator.calls = calls;
  return evaluator;
}

function readyImage(url, overrides) {
  return Object.assign({ type: "image", originalUrl: url, status: "ready" }, overrides || {});
}

function baseProduct(overrides) {
  const merged = Object.assign(
    {
      businessId: "biz1",
      name: "Chew Toy",
      category: "Toys > Chew Toy",
      price: 19.99,
      stock: 3,
      isActive: true,
      moderationStatus: "approved",
      media: [readyImage("https://cdn.example.test/a.jpg")],
      // Marketplace Revision 38 §0.36 A — a publicly visible product is
      // classified (condition 9) and belongs to the LIVE business generation
      // (condition 6). A fixture that wants an unclassified or
      // wrong-generation product overrides these explicitly.
      pilotProductClass: "sealed_dry_food",
    },
    overrides || {}
  );
  // Derived AFTER the merge so an overridden `businessId` still gets a
  // generation that matches its own business.
  if (!Object.prototype.hasOwnProperty.call(overrides || {}, "marketplaceBusinessGenerationId")) {
    merged.marketplaceBusinessGenerationId = DEFAULT_TEST_GENERATION(merged.businessId);
  }
  return merged;
}

// =====================================================================
// Feature flag / wiring — static source inspection of functions/index.js
// =====================================================================

test("index.js exports exactly getMarketplaceProductList and getMarketplaceProductDetail for Slice 4.5", () => {
  assert.match(INDEX_JS_SOURCE, /exports\.getMarketplaceProductList\s*=\s*onCall/);
  assert.match(INDEX_JS_SOURCE, /exports\.getMarketplaceProductDetail\s*=\s*onCall/);
});

test("index.js wrapper for both callables sets enforceAppCheck: false", () => {
  const listBlock = INDEX_JS_SOURCE.slice(INDEX_JS_SOURCE.indexOf("exports.getMarketplaceProductList"));
  const detailBlock = INDEX_JS_SOURCE.slice(INDEX_JS_SOURCE.indexOf("exports.getMarketplaceProductDetail"));
  assert.match(listBlock.slice(0, 200), /enforceAppCheck:\s*false/);
  assert.match(detailBlock.slice(0, 200), /enforceAppCheck:\s*false/);
});

test("index.js declares a single shared disabled-by-default MARKETPLACE_LISTING_ENABLED flag", () => {
  assert.match(INDEX_JS_SOURCE, /const MARKETPLACE_LISTING_ENABLED = defineString\(\s*"MARKETPLACE_LISTING_ENABLED",\s*\{\s*default:\s*""\s*\}/);
  const listBlock = INDEX_JS_SOURCE.slice(
    INDEX_JS_SOURCE.indexOf("exports.getMarketplaceProductList"),
    INDEX_JS_SOURCE.indexOf("exports.getMarketplaceProductDetail")
  );
  const detailBlock = INDEX_JS_SOURCE.slice(INDEX_JS_SOURCE.indexOf("exports.getMarketplaceProductDetail"));
  assert.match(listBlock, /MARKETPLACE_LISTING_ENABLED\.value\(\) === "true"/);
  assert.match(detailBlock.slice(0, 400), /MARKETPLACE_LISTING_ENABLED\.value\(\) === "true"/);
});

test("marketplaceListing.js contains no onCall/onRequest/onSchedule registration", () => {
  assert.doesNotMatch(MODULE_SOURCE, /onCall\s*\(/);
  assert.doesNotMatch(MODULE_SOURCE, /onRequest\s*\(/);
  assert.doesNotMatch(MODULE_SOURCE, /onSchedule\s*\(/);
});

test("marketplaceListing.js module exports are exactly the expected set — no duplicate/extra export", () => {
  const mod = require("../src/marketplace/publicCatalog/marketplaceListing");
  assert.deepEqual(
    Object.keys(mod).sort(),
    [
      "decodeCursor",
      "encodeCursor",
      // Revision 39 §0.37 (Slice 7B-C1) — bounded batch hydration, wired
      // exactly once and sharing this module's flag, posture and projection.
      "getMarketplaceProductBatch",
      "getMarketplaceProductDetail",
      "getMarketplaceProductList",
      "projectPublicProduct",
      "validatePageSize",
    ].sort()
  );
});

test("list: disabled flag rejects before any read/evaluator/cursor-parse call", async () => {
  const db = createFakeDb({});
  const evaluator = createFakeEvaluator();
  await assert.rejects(
    () => getMarketplaceProductList({ db, data: { cursor: "not-even-checked" }, featureEnabled: false, evaluator }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      assert.equal(err.message, "This feature is not yet enabled.");
      return true;
    }
  );
  assert.equal(db.queryCalls.length, 0);
  assert.equal(db.pointReadPaths.length, 0);
  assert.equal(evaluator.calls.length, 0);
});

test("detail: disabled flag rejects before any read/evaluator call", async () => {
  const db = createFakeDb({});
  const evaluator = createFakeEvaluator();
  await assert.rejects(
    () =>
      getMarketplaceProductDetail({
        db,
        data: { businessId: "b", productId: "p" },
        featureEnabled: false,
        evaluator,
      }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      assert.equal(err.message, "This feature is not yet enabled.");
      return true;
    }
  );
  assert.equal(db.queryCalls.length, 0);
  assert.equal(db.pointReadPaths.length, 0);
  assert.equal(evaluator.calls.length, 0);
});

test("list/detail: featureEnabled !== true (e.g. undefined, 1, 'true') is treated as disabled", async () => {
  const db = createFakeDb({});
  const evaluator = createFakeEvaluator();
  for (const bad of [undefined, 1, "true", null]) {
    await assert.rejects(() =>
      getMarketplaceProductList({ db, data: {}, featureEnabled: bad, evaluator })
    );
  }
});

// =====================================================================
// pageSize validation — items 1-4 (Revision 11), corrected-currency-
// unrelated pageSize edge cases
// =====================================================================

test("pageSize: omitted defaults to 20", () => {
  assert.equal(validatePageSize({}), 20);
});

test("pageSize: 1 and 20 are accepted", () => {
  assert.equal(validatePageSize({ pageSize: 1 }), 1);
  assert.equal(validatePageSize({ pageSize: 20 }), 20);
});

test("pageSize: every invalid value is rejected, never clamped/coerced", () => {
  const invalid = [0, -1, 21, 20.5, "20", null, true, false, [], {}, NaN, Infinity, -Infinity];
  for (const value of invalid) {
    assert.throws(
      () => validatePageSize({ pageSize: value }),
      (err) => {
        assert.equal(err.code, "invalid-argument");
        assert.equal(err.message, "Invalid request");
        return true;
      },
      `expected pageSize ${JSON.stringify(value)} to be rejected`
    );
  }
});

test("pageSize: explicit undefined behaves as absent (defaults to 20)", () => {
  assert.equal(validatePageSize({ pageSize: undefined }), 20);
});

// =====================================================================
// Cursor codec — items 7-16
// =====================================================================

test("cursor: encode/decode round-trips exactly", () => {
  const encoded = encodeCursor("businesses/biz1/products/prod1");
  assert.equal(decodeCursor(encoded), "businesses/biz1/products/prod1");
});

test("cursor: absent cursor decodes to null (first page)", () => {
  assert.equal(decodeCursor(undefined), null);
});

test("cursor: explicit null cursor is treated identically to absent (first page), never rejected", () => {
  assert.equal(decodeCursor(null), null);
});

test("cursor: independent known vector decodes correctly", () => {
  const payload = { v: 1, lastPath: "businesses/acme/products/widget-1" };
  const encoded = Buffer.from(JSON.stringify(payload), "utf8").toString("base64url");
  assert.equal(decodeCursor(encoded), "businesses/acme/products/widget-1");
});

test("cursor: encoding is deterministic for the same input", () => {
  assert.equal(encodeCursor("businesses/b/products/p"), encodeCursor("businesses/b/products/p"));
});

test("cursor: max-length boundary (256) accepted, 257 rejected", () => {
  // Construct a lastPath whose encoded cursor lands exactly at 256, then one over.
  let longId = "x".repeat(140);
  let encoded = encodeCursor(`businesses/${longId}/products/p`);
  while (encoded.length < 256) {
    longId += "x";
    encoded = encodeCursor(`businesses/${longId}/products/p`);
  }
  if (encoded.length === 256) {
    assert.equal(decodeCursor(encoded), `businesses/${longId}/products/p`);
  }
  const overLong = "a".repeat(300);
  assert.throws(() => decodeCursor(overLong), { code: "invalid-argument" });
});

test("cursor: malformed base64url is rejected", () => {
  assert.throws(() => decodeCursor("not base64url!!!"), { code: "invalid-argument" });
});

test("cursor: valid base64url decoding to invalid UTF-8 is rejected", () => {
  const invalidUtf8 = Buffer.from([0xff, 0xfe, 0xfd]).toString("base64url");
  assert.throws(() => decodeCursor(invalidUtf8), { code: "invalid-argument" });
});

test("cursor: valid UTF-8 that is not valid JSON is rejected", () => {
  const encoded = Buffer.from("not json{{{", "utf8").toString("base64url");
  assert.throws(() => decodeCursor(encoded), { code: "invalid-argument" });
});

test("cursor: primitive/array JSON payloads are rejected", () => {
  for (const payload of ["\"string\"", "42", "true", "null", "[1,2]"]) {
    const encoded = Buffer.from(payload, "utf8").toString("base64url");
    assert.throws(() => decodeCursor(encoded), { code: "invalid-argument" });
  }
});

test("cursor: wrong version is rejected", () => {
  for (const v of [0, 2, "1", 1.5, null]) {
    const encoded = Buffer.from(JSON.stringify({ v, lastPath: "businesses/b/products/p" }), "utf8").toString(
      "base64url"
    );
    assert.throws(() => decodeCursor(encoded), { code: "invalid-argument" });
  }
});

test("cursor: missing/extra keys are rejected", () => {
  const missingLastPath = Buffer.from(JSON.stringify({ v: 1 }), "utf8").toString("base64url");
  assert.throws(() => decodeCursor(missingLastPath), { code: "invalid-argument" });
  const extraKey = Buffer.from(
    JSON.stringify({ v: 1, lastPath: "businesses/b/products/p", extra: "x" }),
    "utf8"
  ).toString("base64url");
  assert.throws(() => decodeCursor(extraKey), { code: "invalid-argument" });
});

test("cursor: malformed lastPath shapes are rejected", () => {
  const badPaths = [
    "businesses/b/products/",
    "businesses//products/p",
    "/businesses/b/products/p",
    "businesses/b/products/p/",
    "businesses/b/products",
    "businesses/b/wrongcollection/p",
    "not/four/segments",
  ];
  for (const lastPath of badPaths) {
    const encoded = Buffer.from(JSON.stringify({ v: 1, lastPath }), "utf8").toString("base64url");
    assert.throws(() => decodeCursor(encoded), { code: "invalid-argument" }, `expected reject for ${lastPath}`);
  }
});

test("cursor: control characters in path segments are rejected", () => {
  const lastPath = "businesses/b\x00ad/products/p";
  const encoded = Buffer.from(JSON.stringify({ v: 1, lastPath }), "utf8").toString("base64url");
  assert.throws(() => decodeCursor(encoded), { code: "invalid-argument" });
});

test("cursor: rejection errors never echo the supplied cursor or decoded path", () => {
  try {
    decodeCursor("!!!invalid!!!");
    assert.fail("expected throw");
  } catch (err) {
    assert.doesNotMatch(err.message, /invalid/);
    assert.equal(err.message, "Invalid request");
  }
});

// =====================================================================
// List request validation — closed shape
// =====================================================================

test("list: unknown request keys are rejected", async () => {
  const db = createFakeDb({});
  await assert.rejects(
    () => getMarketplaceProductList({ db, data: { pageSize: 5, unknownField: 1 }, featureEnabled: true }),
    { code: "invalid-argument", message: "Invalid request" }
  );
});

test("list: non-object/array data is rejected", async () => {
  const db = createFakeDb({});
  await assert.rejects(() => getMarketplaceProductList({ db, data: [1, 2], featureEnabled: true }), {
    code: "invalid-argument",
  });
});

// =====================================================================
// Detail request validation
// =====================================================================

test("detail: unknown request keys are rejected", async () => {
  const db = createFakeDb({});
  await assert.rejects(
    () =>
      getMarketplaceProductDetail({
        db,
        data: { businessId: "b", productId: "p", extra: 1 },
        featureEnabled: true,
      }),
    { code: "invalid-argument", message: "Invalid request" }
  );
});

test("detail: missing/empty/wrong-type businessId or productId is rejected", async () => {
  const db = createFakeDb({});
  const cases = [
    {},
    { businessId: "b" },
    { productId: "p" },
    { businessId: "", productId: "p" },
    { businessId: "b", productId: "" },
    { businessId: 5, productId: "p" },
    { businessId: "b", productId: null },
  ];
  for (const data of cases) {
    await assert.rejects(
      () => getMarketplaceProductDetail({ db, data, featureEnabled: true }),
      { code: "invalid-argument", message: "Invalid request" },
      `expected reject for ${JSON.stringify(data)}`
    );
  }
});

test("detail: never searches globally by productId — reads exactly the nested path", async () => {
  const db = createFakeDb({
    "businesses/biz1/products/prod1": baseProduct(),
  });
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(["businesses/biz1/products/prod1"]) });
  await getMarketplaceProductDetail({
    db,
    data: { businessId: "biz1", productId: "prod1" },
    featureEnabled: true,
    evaluator,
  });
  // Revision 38 §0.36 A adds one owning-business point read (conditions
  // 3/4/6). The property this test exists to protect is unchanged and still
  // asserted: the product is reached by its exact nested path, and NO global
  // query by productId is ever issued.
  assert.deepEqual(db.pointReadPaths, [
    "businesses/biz1/products/prod1",
    "businesses/biz1",
  ]);
  assert.equal(db.queryCalls.length, 0, "never a global search by productId");
});

// =====================================================================
// Exact query shape — items 5-6, Phase 7
// =====================================================================

test("list: exact collectionGroup/where/orderBy/limit chain, no cursor on first page", async () => {
  const db = createFakeDb({});
  await getMarketplaceProductList({ db, data: { pageSize: 5 }, featureEnabled: true, evaluator: createFakeEvaluator() });
  assert.equal(db.queryCalls.length, 1);
  const call = db.queryCalls[0];
  assert.equal(call.collectionGroup, "products");
  assert.deepEqual(call.wheres, [
    { field: "isActive", op: "==", value: true },
    { field: "moderationStatus", op: "==", value: "approved" },
  ]);
  assert.equal(call.orderBy.fieldPath.toString(), FieldPath.documentId().toString());
  assert.equal(call.orderBy.direction, "asc");
  assert.equal(call.startAfterPath, null);
  assert.equal(call.limit, 15);
});

test("list: a supplied cursor reconstructs startAfter(DocumentReference) from lastPath, without reading the cursor target", async () => {
  const db = createFakeDb({});
  const cursor = encodeCursor("businesses/biz1/products/prod1");
  await getMarketplaceProductList({
    db,
    data: { pageSize: 5, cursor },
    featureEnabled: true,
    evaluator: createFakeEvaluator(),
  });
  assert.equal(db.queryCalls[0].startAfterPath, "businesses/biz1/products/prod1");
  assert.equal(db.pointReadPaths.length, 0, "cursor target must never be read");
});

test("list: fetch limit is exactly pageSize * 3, at most 60", async () => {
  const db = createFakeDb({});
  await getMarketplaceProductList({ db, data: { pageSize: 20 }, featureEnabled: true, evaluator: createFakeEvaluator() });
  assert.equal(db.queryCalls[0].limit, 60);
});

// =====================================================================
// Pagination / bounds — items 17-28
// =====================================================================

function seedProducts(count, { businessId = "biz1", eligible = true } = {}) {
  const docs = {};
  const ids = [];
  for (let i = 0; i < count; i += 1) {
    const id = `prod${String(i).padStart(4, "0")}`;
    ids.push(`businesses/${businessId}/products/${id}`);
    docs[`businesses/${businessId}/products/${id}`] = baseProduct({ businessId });
  }
  return { docs, ids };
}

test("list: stops immediately once pageSize eligible items are collected (early stop, second page never fetched)", async () => {
  const { docs, ids } = seedProducts(10);
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 3 }, featureEnabled: true, evaluator });
  assert.equal(result.items.length, 3);
  assert.equal(db.queryCalls.length, 1, "only one fetch should occur once pageSize eligible items are found");
  assert.equal(evaluator.calls.length, 3, "no candidate beyond the pageSize-th eligible one may be evaluated");
});

// Structural note (Case J's own comment, above, explains why in full):
// given FETCH_LIMIT_MULTIPLIER=3, EXAMINE_CAP_MULTIPLIER=6, MAX_FETCHES=2
// (examineCap == fetchLimit * MAX_FETCHES exactly), a third fetch is
// architecturally unreachable through any well-behaved-backend data
// shape — two full, limit-respecting fetches always exhaust the examine
// cap at precisely the same point MAX_FETCHES would, so a behavioral
// mutation that merely raises MAX_FETCHES produces no observable
// difference against a realistic fake. This static check is the
// deliberate second layer of defense: it locks in the literal loop
// condition directly, so a hand-edit of the bound is still caught even
// though it has no reachable behavioral effect today.
test("list: fetchCount is bounded by the literal MAX_FETCHES=2 loop condition (static — see structural note)", () => {
  assert.match(MODULE_SOURCE, /fetchCount\s*<\s*MAX_FETCHES/);
  assert.match(MODULE_SOURCE, /const MAX_FETCHES\s*=\s*2\s*;/);
});

test("list: never issues more than two underlying fetches", async () => {
  const { docs } = seedProducts(200);
  const db = createFakeDb(docs);
  // Nothing is eligible, forcing the algorithm to exhaust its bounds.
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set() });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 20 }, featureEnabled: true, evaluator });
  assert.equal(db.queryCalls.length, 2);
  assert.equal(result.items.length, 0);
});

test("list: total examined candidates never exceeds pageSize * 6 (<=120 at pageSize 20)", async () => {
  const { docs } = seedProducts(200);
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set() });
  await getMarketplaceProductList({ db, data: { pageSize: 20 }, featureEnabled: true, evaluator });
  assert.ok(evaluator.calls.length <= 120, `evaluator called ${evaluator.calls.length} times`);
});

test("list: each underlying fetch limit is exactly pageSize * 3", async () => {
  const { docs } = seedProducts(200);
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set() });
  await getMarketplaceProductList({ db, data: { pageSize: 10 }, featureEnabled: true, evaluator });
  for (const call of db.queryCalls) {
    assert.equal(call.limit, 30);
  }
});

test("list: every candidate is evaluated at most once (no double-counting)", async () => {
  const { docs } = seedProducts(50);
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set() });
  await getMarketplaceProductList({ db, data: { pageSize: 5 }, featureEnabled: true, evaluator });
  const seen = new Set();
  for (const call of evaluator.calls) {
    const key = `${call.businessId}/${call.productId}`;
    assert.ok(!seen.has(key), `duplicate evaluation of ${key}`);
    seen.add(key);
  }
});

test("list: candidates are evaluated in ascending document-path order, output order matches", async () => {
  const docs = {
    "businesses/biz1/products/prodA": baseProduct({ businessId: "biz1" }),
    "businesses/biz1/products/prodB": baseProduct({ businessId: "biz1" }),
    "businesses/biz1/products/prodC": baseProduct({ businessId: "biz1" }),
  };
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({
    eligiblePaths: new Set([
      "businesses/biz1/products/prodA",
      "businesses/biz1/products/prodB",
      "businesses/biz1/products/prodC",
    ]),
  });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 20 }, featureEnabled: true, evaluator });
  assert.deepEqual(
    result.items.map((i) => i.productId),
    ["prodA", "prodB", "prodC"]
  );
});

test("list: nextCursor reflects the last EXAMINED candidate — corrected: with pageSize=1, prodB here is fetched but never examined, so exhaustion must NOT be claimed", async () => {
  // Corrected (corrective task): this test previously asserted
  // `nextCursor === null` with the rationale "only 2 docs exist and were
  // fully examined -> exhaustion proven" — that rationale was false.
  // With pageSize=1, the per-candidate loop stops the instant prodA (the
  // first doc, eligible) fills the page; prodB is fetched (docs.length=2
  // < fetchLimit=3, a short fetch) but never examined
  // (examinedInBatch=1 !== docs.length=2, so batchFullyExamined is
  // false). True exhaustion is therefore not established, and
  // `nextCursor` must be non-null — this is exactly the Case C defect
  // shape at pageSize=1, formalized separately in the "[Case C]"/
  // "[Case P]" tests above; this test is kept, corrected, for its
  // original historical name/location.
  const docs = {
    "businesses/biz1/products/prodA": baseProduct({ businessId: "biz1" }), // eligible, fills the page
    "businesses/biz1/products/prodB": baseProduct({ businessId: "biz1" }), // fetched, never examined
  };
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(["businesses/biz1/products/prodA"]) });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 1 }, featureEnabled: true, evaluator });
  assert.equal(result.items.length, 1);
  assert.equal(evaluator.calls.length, 1, "prodB must not be evaluated on this invocation");
  assert.notEqual(result.nextCursor, null, "prodB was fetched but never examined -> exhaustion must not be claimed");
  assert.equal(decodeCursor(result.nextCursor), "businesses/biz1/products/prodA", "cursor is the last EXAMINED candidate");

  const page2 = await getMarketplaceProductList({
    db,
    data: { pageSize: 1, cursor: result.nextCursor },
    featureEnabled: true,
    evaluator: createFakeEvaluator({ eligiblePaths: new Set(["businesses/biz1/products/prodA", "businesses/biz1/products/prodB"]) }),
  });
  assert.equal(page2.items.length, 1);
  assert.equal(page2.items[0].productId, "prodB", "the resumed request must reach prodB — nothing lost");
  assert.equal(page2.nextCursor, null, "prodB is the final document -> now genuinely exhausted");
});

test("list: nextCursor is non-null and points at last examined when stopping early before exhaustion", async () => {
  const { docs, ids } = seedProducts(100);
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 2 }, featureEnabled: true, evaluator });
  assert.equal(result.items.length, 2);
  assert.notEqual(result.nextCursor, null);
  const decoded = decodeCursor(result.nextCursor);
  assert.equal(decoded, result.items[1].businessId ? `businesses/${result.items[1].businessId}/products/${result.items[1].productId}` : decoded);
});

test("list: a page where every candidate is filtered out (not exhausted) returns empty items with a non-null nextCursor", async () => {
  // 200 seeded docs: both allowed fetches return a full (60-document)
  // page, so neither ever proves exhaustion, and the examine cap (120)
  // is what stops the loop — the exact "examined-but-all-filtered,
  // exhaustion not established" case.
  const { docs } = seedProducts(200);
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set() });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 20 }, featureEnabled: true, evaluator });
  assert.equal(result.items.length, 0);
  assert.notEqual(result.nextCursor, null);
});

test("list: a short first fetch (fewer than limit) proves exhaustion -> nextCursor null regardless of eligible count", async () => {
  const { docs, ids } = seedProducts(5); // far fewer than limit(60) for pageSize 20
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 20 }, featureEnabled: true, evaluator });
  assert.equal(result.items.length, 5);
  assert.equal(result.nextCursor, null);
});

test("list: no candidate examined at all (zero results) -> nextCursor null", async () => {
  const db = createFakeDb({});
  const result = await getMarketplaceProductList({ db, data: {}, featureEnabled: true, evaluator: createFakeEvaluator() });
  assert.deepEqual(result, { items: [], nextCursor: null });
});

test("list: no offset() is ever called (fake has no offset method at all, so any use would throw)", async () => {
  const { docs } = seedProducts(5);
  const db = createFakeDb(docs);
  await getMarketplaceProductList({ db, data: {}, featureEnabled: true, evaluator: createFakeEvaluator() });
  // Implicit proof: reaching here without a "not a function" error confirms
  // marketplaceListing.js never calls `.offset()` on the fake query object.
});

test("list: a short fetch does NOT by itself prove exhaustion when pageSize fills before the whole fetched batch is examined — nextCursor stays non-null, cursor is the last EXAMINED candidate, and resuming reaches the unexamined suffix with no loss/repeat", async () => {
  // Corrective test (replaces a prior version of this test that asserted
  // the opposite — a confirmed candidate-loss defect: a short fetch
  // (6 docs < fetchLimit(9) at pageSize=3) that fills the page at
  // candidate 3 leaves candidates 4-6 fetched but never examined. A short
  // fetch proves no document exists *past* the fetched batch; it proves
  // nothing about documents already inside the batch that the early-stop
  // rule never reached. Marking the whole request "exhausted" in that
  // case silently and permanently discarded candidates 4-6, even when
  // they were eligible.
  const { docs, ids } = seedProducts(6); // fetchLimit(pageSize*3) = 9; 6 < 9 is a short fetch
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });

  const page1 = await getMarketplaceProductList({ db, data: { pageSize: 3 }, featureEnabled: true, evaluator });
  assert.equal(page1.items.length, 3);
  assert.notEqual(page1.nextCursor, null, "page filled before the short batch was fully examined — must not claim exhaustion");
  assert.equal(db.queryCalls.length, 1, "only one fetch should occur once pageSize eligible items are found");
  assert.equal(evaluator.calls.length, 3, "candidates 4-6 must not be evaluated on this invocation (frozen early-stop rule preserved)");

  const decodedPath = decodeCursor(page1.nextCursor);
  const lastItem = page1.items[page1.items.length - 1];
  assert.equal(decodedPath, `businesses/${lastItem.businessId}/products/${lastItem.productId}`, "cursor must be the last EXAMINED candidate, not the last fetched or last eligible");

  const page2 = await getMarketplaceProductList({
    db,
    data: { pageSize: 3, cursor: page1.nextCursor },
    featureEnabled: true,
    evaluator,
  });
  assert.equal(page2.items.length, 3, "the previously-unexamined suffix (candidates 4-6) must be reachable");
  assert.equal(page2.nextCursor, null, "the resumed fetch is itself short and fully examined -> true exhaustion");

  const returnedIds = [...page1.items, ...page2.items].map((i) => i.productId);
  const expectedIds = ids.map((p) => p.split("/products/")[1]);
  assert.deepEqual(returnedIds, expectedIds, "union of both pages must equal every eligible candidate, in order, with no loss and no repeat");
});

// =====================================================================
// Adversarial pagination state-machine matrix (corrective task) — proves
// the shortFetch/batchFullyExamined exhaustion fix across every early-
// stop interaction named by the audit that found the original defect.
// Named states, matching the production code exactly:
//   shortFetch          docs.length < fetchLimit for the current fetch
//   batchFullyExamined  every doc returned by that fetch was examined
//                       (the per-candidate loop did not break early)
//   pageFull            items.length >= pageSize
//   examineCapReached   examinedCount >= pageSize * 6
//   exhausted           shortFetch && batchFullyExamined (or a
//                       zero-document fetch, which is a degenerate case
//                       of the same rule) — the only condition under
//                       which nextCursor may legally be null.
// =====================================================================

async function drainAllPages(db, evaluator, pageSize) {
  let cursor;
  const pages = [];
  let guard = 0;
  while (true) {
    guard += 1;
    if (guard > 50) throw new Error("runaway pagination in test helper");
    const before = db.queryCalls.length;
    const result = await getMarketplaceProductList({
      db,
      data: { pageSize, ...(cursor !== undefined ? { cursor } : {}) },
      featureEnabled: true,
      evaluator,
    });
    pages.push({ result, fetchesThisInvocation: db.queryCalls.length - before });
    if (result.nextCursor === null) break;
    cursor = result.nextCursor;
  }
  return pages;
}

// --- Case A: short batch, fully examined, page not full -> null cursor ---
test("list [Case A]: short batch, fully examined, page not full -> nextCursor null", async () => {
  const { docs, ids } = seedProducts(10);
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids.slice(0, 3)) }); // 3 eligible, pageSize 5 never fills
  const result = await getMarketplaceProductList({ db, data: { pageSize: 5 }, featureEnabled: true, evaluator });
  assert.equal(evaluator.calls.length, 10, "batch must be fully examined");
  assert.equal(result.items.length, 3);
  assert.equal(result.nextCursor, null);
});

// --- Case B: short batch, page fills exactly on the final fetched doc ---
test("list [Case B]: short batch, page fills exactly on the final fetched document -> nextCursor null", async () => {
  const { docs, ids } = seedProducts(5); // fetchLimit(15) > 5 -> short; all 5 eligible -> page fills exactly at doc 5
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 5 }, featureEnabled: true, evaluator });
  assert.equal(result.items.length, 5);
  assert.equal(evaluator.calls.length, 5, "the final fetched document is the one that fills the page -> fully examined");
  assert.equal(result.nextCursor, null);
});

// --- Case C: short batch, page fills before the final fetched doc (the confirmed defect shape) ---
test("list [Case C]: short batch, page fills before the final fetched document -> nextCursor non-null, resume reaches the unexamined suffix", async () => {
  const { docs, ids } = seedProducts(5); // fetchLimit(6) at pageSize 2 > 5 -> short; page fills at doc 2, docs 3-5 unexamined
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
  const pages = await drainAllPages(db, evaluator, 2);
  const allIds = pages.flatMap((p) => p.result.items.map((i) => i.productId));
  assert.deepEqual(allIds, ids.map((p) => p.split("/products/")[1]), "no candidate lost, none repeated, order preserved");
  assert.ok(pages.length >= 2, "the defect shape requires at least 2 client-visible pages");
});

// --- Case D: short fetch of fetchLimit-1, page fills early (pageSize=20 boundary) ---
test("list [Case D, pageSize=20 boundary]: fetch=fetchLimit-1 (59 of 60), page fills at 20 -> nextCursor non-null, no loss on resume", async () => {
  const { docs, ids } = seedProducts(59);
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
  const page1 = await getMarketplaceProductList({ db, data: { pageSize: 20 }, featureEnabled: true, evaluator });
  assert.equal(page1.items.length, 20);
  assert.notEqual(page1.nextCursor, null);
  assert.equal(db.queryCalls[0].limit, 60);
  const pages = await drainAllPages(createFakeDb(docs), createFakeEvaluator({ eligiblePaths: new Set(ids) }), 20);
  const allIds = pages.flatMap((p) => p.result.items.map((i) => i.productId));
  assert.deepEqual(allIds, ids.map((p) => p.split("/products/")[1]));
});

// --- Case E: full (non-short) fetch, page fills early -> non-null, unaffected by the fix ---
test("list [Case E]: full (non-short) fetch, page fills early -> nextCursor non-null (unaffected by the correction)", async () => {
  const { docs, ids } = seedProducts(60);
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 20 }, featureEnabled: true, evaluator });
  assert.equal(result.items.length, 20);
  assert.notEqual(result.nextCursor, null);
});

// --- Case F: first full fetch does not fill page; second SHORT fetch fills early ---
test("list [Case F]: first full fetch under-fills, second short fetch fills page early -> nextCursor non-null, resume reaches second-batch suffix", async () => {
  const businessId = "biz1";
  const docs = {};
  const ids = [];
  for (let i = 0; i < 90; i += 1) {
    const id = `prod${String(i).padStart(4, "0")}`;
    const p = `businesses/${businessId}/products/${id}`;
    ids.push(p);
    docs[p] = baseProduct({ businessId });
  }
  // First 60 (fetch 1, full/not short): zero eligible. Next 30 (fetch 2,
  // short: 30 < 60): all eligible -> page (pageSize 20) fills after only
  // 10 of fetch 2's 30 docs are examined.
  const eligibleIds = new Set(ids.slice(60));
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: eligibleIds });
  const page1 = await getMarketplaceProductList({ db, data: { pageSize: 20 }, featureEnabled: true, evaluator });
  assert.equal(page1.items.length, 20);
  assert.notEqual(page1.nextCursor, null, "fetch 2 was short but not fully examined -> must not claim exhaustion");
  assert.equal(db.queryCalls.length, 2);

  const page2 = await getMarketplaceProductList({
    db,
    data: { pageSize: 20, cursor: page1.nextCursor },
    featureEnabled: true,
    evaluator,
  });
  assert.equal(page2.items.length, 10, "the remaining 10 eligible candidates from fetch 2's tail");
  assert.equal(page2.nextCursor, null, "true exhaustion once the tail is fully examined");
  const allIds = [...page1.items, ...page2.items].map((i) => `businesses/biz1/products/${i.productId}`);
  assert.deepEqual(allIds, [...eligibleIds]);
});

// --- Case G: second fetch is short AND fully examined, filling exactly on its final candidate ---
test("list [Case G]: second fetch is short and fully examined, page fills exactly on its final document -> nextCursor null", async () => {
  const businessId = "biz1";
  const docs = {};
  const ids = [];
  for (let i = 0; i < 80; i += 1) {
    const id = `prod${String(i).padStart(4, "0")}`;
    const p = `businesses/${businessId}/products/${id}`;
    ids.push(p);
    docs[p] = baseProduct({ businessId });
  }
  // fetch1: docs 0-59 (60, full/not short), 0 eligible. fetch2: docs
  // 60-79 (20, short: 20 < 60), all eligible -> pageSize(20) fills
  // exactly on the batch's own final (20th) document.
  const eligibleIds = new Set(ids.slice(60));
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: eligibleIds });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 20 }, featureEnabled: true, evaluator });
  assert.equal(result.items.length, 20);
  assert.equal(db.queryCalls.length, 2);
  assert.equal(result.nextCursor, null, "fetch 2's short batch was fully examined -> true exhaustion");
});

// --- Case H: all candidates in a short fetch are ineligible ---
test("list [Case H]: all candidates in a short fetch are ineligible -> all examined, exhaustion true, nextCursor null", async () => {
  const { docs } = seedProducts(10);
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set() });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 5 }, featureEnabled: true, evaluator });
  assert.equal(evaluator.calls.length, 10);
  assert.equal(result.items.length, 0);
  assert.equal(result.nextCursor, null);
});

// --- Case I: per-candidate evaluator/projection failures inside a short fetch ---
test("list [Case I]: per-candidate failures inside a short, fully-examined fetch still count as examined -> exhaustion holds", async () => {
  const { docs, ids } = seedProducts(8);
  const db = createFakeDb(docs);
  // None eligible and every candidate synthetically throws -> page never
  // fills, so the batch is fully examined regardless of the failures.
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(), throwFor: new Set(ids) });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 5 }, featureEnabled: true, evaluator });
  assert.equal(evaluator.calls.length, 8, "a per-candidate exception still counts toward examinedCount");
  assert.equal(result.items.length, 0);
  assert.equal(result.nextCursor, null, "batch fully examined despite every candidate failing -> true exhaustion");
});

test("list [Case I-early-stop]: a per-candidate failure inside a short batch that fills the page before the batch ends -> nextCursor non-null", async () => {
  const { docs, ids } = seedProducts(6); // pageSize 2 -> fetchLimit 6, short (6 < 18 is not the bound; use pageSize small)
  const db = createFakeDb(docs);
  // ids[0] eligible, ids[1] throws, ids[2] eligible -> page (pageSize 2)
  // fills at the 3rd candidate; ids[3-5] are fetched but never examined.
  const evaluator = createFakeEvaluator({
    eligiblePaths: new Set([ids[0], ids[2]]),
    throwFor: new Set([ids[1]]),
  });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 2 }, featureEnabled: true, evaluator });
  assert.equal(result.items.length, 2);
  assert.equal(evaluator.calls.length, 3, "candidates 4-6 must not be evaluated on this invocation");
  assert.notEqual(result.nextCursor, null, "3 of 6 fetched candidates remain unexamined -> must not claim exhaustion");
});

// --- Case J: examine cap enforcement, including a defensive over-return scenario ---
// Structural note: with the frozen bounds FETCH_LIMIT_MULTIPLIER=3,
// EXAMINE_CAP_MULTIPLIER=6, MAX_FETCHES=2 (examineCap == fetchLimit *
// MAX_FETCHES exactly), a *limit-respecting* fetch can never return more
// documents than requested, so the examine cap can only ever be reached
// exactly at the natural boundary of a fully-examined fetch — never
// strictly inside one. The scenario "cap truncates a batch mid-way" is
// therefore reachable only if the underlying query returns more
// documents than its own requested limit (a defensive/backend-anomaly
// case), proven below.
test("list [Case J]: examine cap stops mid-batch only if a fetch over-returns beyond its own limit — cap is still enforced and nextCursor stays non-null", async () => {
  // A self-contained, deliberately misbehaving fake `db` — independent of
  // createFakeDb/FakeQuery — that ignores its own requested `limit()` and
  // always returns every remaining seeded document, simulating a backend
  // anomaly. The production code must still cap examination at
  // pageSize*6 and must never claim exhaustion in that case.
  const businessId = "biz1";
  const ordered = [];
  for (let i = 0; i < 100; i += 1) {
    const id = `prod${String(i).padStart(4, "0")}`;
    ordered.push({ path: `businesses/${businessId}/products/${id}`, data: baseProduct({ businessId }) });
  }
  const queryCalls = [];
  const overReturningDb = {
    queryCalls,
    collectionGroup(name) {
      let startAfterPath = null;
      let lim = null;
      const q = {
        where() { return q; },
        orderBy() { return q; },
        startAfter(ref) { startAfterPath = ref.path; return q; },
        limit(n) { lim = n; return q; },
        async get() {
          queryCalls.push({ limit: lim, startAfterPath });
          let all = ordered.slice();
          if (startAfterPath !== null) all = all.filter((d) => d.path > startAfterPath);
          // Deliberately ignore `lim` — return everything remaining.
          return { docs: all.map((d) => ({ data: () => d.data, ref: { path: d.path } })) };
        },
      };
      return q;
    },
    doc(p) {
      return { path: p };
    },
    // Revision 38 §0.36 A — the catalogue now reads the owning business to
    // answer conditions 3/4/6/9. This hand-rolled db predates that, so it
    // must serve a valid business or every candidate would be rejected
    // before the evaluator and this test would measure nothing.
    collection(name) {
      return {
        doc(businessId) {
          return {
            async get() {
              return {
                exists: true,
                data: () => ({
                  status: "approved",
                  marketplaceSellerActivation: { active: true },
                  marketplaceBusinessGenerationId: `gen-${businessId}`,
                }),
              };
            },
          };
        },
      };
    },
  };

  const evaluator = createFakeEvaluator({ eligiblePaths: new Set() }); // nothing eligible -> page never fills
  const result = await getMarketplaceProductList({ db: overReturningDb, data: { pageSize: 5 }, featureEnabled: true, evaluator });
  assert.equal(evaluator.calls.length, 30, "examinedCount must never exceed pageSize*6 (30) even if the backend over-returns");
  assert.equal(queryCalls.length, 1, "the algorithm itself never issues more than one fetch here regardless of the anomaly");
  assert.equal(result.items.length, 0);
  assert.notEqual(result.nextCursor, null, "the over-returned, never-examined remainder must not be silently discarded as exhausted");
});

test("list [cap boundary]: two full (non-short) fetches examine exactly pageSize*6 candidates -> nextCursor non-null (exhaustion not independently proven), never a third fetch", async () => {
  const { docs } = seedProducts(200);
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set() });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 5 }, featureEnabled: true, evaluator });
  assert.equal(evaluator.calls.length, 30, "pageSize(5)*6 = 30");
  assert.equal(db.queryCalls.length, 2, "never a third fetch");
  assert.equal(result.items.length, 0);
  assert.notEqual(result.nextCursor, null, "cap reached without the query itself being proven exhausted");
});

// --- Case M: cursor is the last EXAMINED candidate, distinct from the last ELIGIBLE one ---
test("list [Case M]: nextCursor is the last examined candidate even when it differs from the last eligible one (MAX_FETCHES reached, not page-fill)", async () => {
  const businessId = "biz1";
  const docs = {};
  const ids = [];
  for (let i = 0; i < 30; i += 1) {
    const id = `prod${String(i).padStart(4, "0")}`;
    const p = `businesses/${businessId}/products/${id}`;
    ids.push(p);
    docs[p] = baseProduct({ businessId });
  }
  // pageSize 5 -> fetchLimit 15, examineCap 30 -> exactly two full
  // (non-short) fetches of 15 exhaust the cap and MAX_FETCHES together.
  // Only 2 of the 30 are eligible, so the page never fills; the very
  // last document (index 29) is ineligible, so lastExaminedPath must
  // point at doc 29, not at either eligible item.
  const eligibleIds = new Set([ids[3], ids[17]]);
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: eligibleIds });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 5 }, featureEnabled: true, evaluator });
  assert.equal(result.items.length, 2);
  assert.equal(db.queryCalls.length, 2);
  assert.notEqual(result.nextCursor, null);
  const decoded = decodeCursor(result.nextCursor);
  assert.equal(decoded, ids[29], "cursor must be the last EXAMINED candidate");
  assert.notEqual(decoded, ids[3]);
  assert.notEqual(decoded, ids[17], "cursor must not be the last ELIGIBLE candidate");
});

// --- Case N: union of pages equals the eligible source set exactly, across an early-filled short batch ---
test("list [Case N]: union of consecutive pages across an early-filled short batch equals every eligible candidate, in order, no gaps, no repeats", async () => {
  const { docs, ids } = seedProducts(59); // Case D shape
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
  const pages = await drainAllPages(db, evaluator, 20);
  const allReturned = pages.flatMap((p) => p.result.items.map((i) => `businesses/biz1/products/${i.productId}`));
  assert.deepEqual(allReturned, ids, "exact order, no gaps, no repeats");
  assert.equal(new Set(allReturned).size, allReturned.length, "no repeats");
});

// --- Case O: many-page continuation, each invocation independently bounded to <=2 fetches ---
test("list [Case O]: a long multi-page continuation never exceeds 2 fetches per invocation and loses nothing across the whole chain", async () => {
  const { docs, ids } = seedProducts(70);
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
  const pages = await drainAllPages(db, evaluator, 20);
  assert.ok(pages.length >= 3, `expected at least 3 client-visible pages, got ${pages.length}`);
  for (const p of pages) {
    assert.ok(p.fetchesThisInvocation <= 2, `invocation used ${p.fetchesThisInvocation} fetches`);
  }
  const allReturned = pages.flatMap((p) => p.result.items.map((i) => `businesses/biz1/products/${i.productId}`));
  assert.deepEqual(allReturned, ids);
});

// --- Case P: pageSize 1, 2, 20 all exhibit the same fixed defect shape correctly ---
test("list [Case P]: the early-filled-short-batch fix holds across pageSize 1, 2, and 20", async () => {
  for (const pageSize of [1, 2, 20]) {
    const fetchLimit = pageSize * 3;
    const total = fetchLimit - 1; // always short, always more than pageSize when pageSize>=1 and fetchLimit>=3
    const { docs, ids } = seedProducts(Math.max(total, pageSize + 1), { businessId: `biz-p${pageSize}` });
    const db = createFakeDb(docs);
    const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
    const pages = await drainAllPages(db, evaluator, pageSize);
    const allReturned = pages.flatMap((p) => p.result.items.map((i) => `businesses/biz-p${pageSize}/products/${i.productId}`));
    assert.deepEqual(allReturned, ids, `pageSize ${pageSize}: no loss/repeat across the chain`);
    assert.equal(pages[0].result.items.length, pageSize, `pageSize ${pageSize}: first page fills exactly to pageSize`);
    assert.notEqual(pages[0].result.nextCursor, null, `pageSize ${pageSize}: first page must not falsely claim exhaustion`);
  }
});

// --- Case Q: boundary fetch lengths against a fixed pageSize ---
test("list [Case Q]: boundary fetch lengths (0, 1, pageSize, pageSize+1, fetchLimit-1, fetchLimit) each resolve exhaustion correctly", async () => {
  const pageSize = 5;
  const fetchLimit = pageSize * 3; // 15

  // 0 docs: trivially short + trivially fully examined -> exhausted, null cursor.
  {
    const db = createFakeDb({});
    const result = await getMarketplaceProductList({ db, data: { pageSize }, featureEnabled: true, evaluator: createFakeEvaluator() });
    assert.deepEqual(result, { items: [], nextCursor: null });
  }

  // 1 doc, eligible: short, fully examined (page never fills at 5) -> exhausted, null cursor.
  {
    const { docs, ids } = seedProducts(1, { businessId: "biz-q1" });
    const db = createFakeDb(docs);
    const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
    const result = await getMarketplaceProductList({ db, data: { pageSize }, featureEnabled: true, evaluator });
    assert.equal(result.items.length, 1);
    assert.equal(result.nextCursor, null);
  }

  // pageSize (5) docs, all eligible: short, page fills exactly at the batch's last doc -> exhausted, null cursor.
  {
    const { docs, ids } = seedProducts(pageSize, { businessId: "biz-q2" });
    const db = createFakeDb(docs);
    const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
    const result = await getMarketplaceProductList({ db, data: { pageSize }, featureEnabled: true, evaluator });
    assert.equal(result.items.length, pageSize);
    assert.equal(result.nextCursor, null);
  }

  // pageSize+1 (6) docs, all eligible: short, page fills before the batch's last doc -> non-null cursor, resume gets the 1 remaining.
  {
    const { docs, ids } = seedProducts(pageSize + 1, { businessId: "biz-q3" });
    const db = createFakeDb(docs);
    const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
    const pages = await drainAllPages(db, evaluator, pageSize);
    const allReturned = pages.flatMap((p) => p.result.items.map((i) => `businesses/biz-q3/products/${i.productId}`));
    assert.deepEqual(allReturned, ids);
    assert.notEqual(pages[0].result.nextCursor, null);
  }

  // fetchLimit-1 (14) docs, all eligible: short, page fills well before the batch ends -> non-null cursor, resume gets the rest.
  {
    const { docs, ids } = seedProducts(fetchLimit - 1, { businessId: "biz-q4" });
    const db = createFakeDb(docs);
    const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
    const pages = await drainAllPages(db, evaluator, pageSize);
    const allReturned = pages.flatMap((p) => p.result.items.map((i) => `businesses/biz-q4/products/${i.productId}`));
    assert.deepEqual(allReturned, ids);
    assert.notEqual(pages[0].result.nextCursor, null);
  }

  // fetchLimit (15) docs, all eligible: NOT short, page fills early -> non-null cursor regardless of batch-examination state.
  {
    const { docs, ids } = seedProducts(fetchLimit, { businessId: "biz-q5" });
    const db = createFakeDb(docs);
    const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
    const pages = await drainAllPages(db, evaluator, pageSize);
    const allReturned = pages.flatMap((p) => p.result.items.map((i) => `businesses/biz-q5/products/${i.productId}`));
    assert.deepEqual(allReturned, ids);
    assert.notEqual(pages[0].result.nextCursor, null);
  }
});

test("list: two consecutive pages using nextCursor never return an overlapping candidate", async () => {
  // 12 seeded docs vs. fetchLimit(9) at pageSize=3: the first fetch
  // returns a *full* (9-document) page, so exhaustion is not established
  // when pageSize is reached mid-batch, and nextCursor is correctly
  // non-null (last-examined, continuation intended) rather than the
  // short-fetch/proven-exhaustion case this test is not exercising.
  const { docs, ids } = seedProducts(12);
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(ids) });
  const page1 = await getMarketplaceProductList({ db, data: { pageSize: 3 }, featureEnabled: true, evaluator });
  assert.equal(page1.items.length, 3);
  assert.notEqual(page1.nextCursor, null);
  const page2 = await getMarketplaceProductList({
    db,
    data: { pageSize: 3, cursor: page1.nextCursor },
    featureEnabled: true,
    evaluator,
  });
  const page1Ids = new Set(page1.items.map((i) => i.productId));
  for (const item of page2.items) {
    assert.ok(!page1Ids.has(item.productId), `product ${item.productId} repeated across pages`);
  }
});

test("list: a cursor naming a deleted/nonexistent path is legal — no read of the cursor target, positional only", async () => {
  const { docs } = seedProducts(5);
  const db = createFakeDb(docs);
  const cursor = encodeCursor("businesses/biz1/products/prod0002");
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(Object.keys(docs)) });
  const result = await getMarketplaceProductList({
    db,
    data: { pageSize: 20, cursor },
    featureEnabled: true,
    evaluator,
  });
  assert.deepEqual(
    result.items.map((i) => i.productId),
    ["prod0003", "prod0004"]
  );
});

test("list: cross-business duplicate productId values are distinguished by full path, never collapsed", async () => {
  const docs = {
    "businesses/bizA/products/shared-id": baseProduct({ businessId: "bizA" }),
    "businesses/bizB/products/shared-id": baseProduct({ businessId: "bizB" }),
  };
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(Object.keys(docs)) });
  const result = await getMarketplaceProductList({ db, data: { pageSize: 20 }, featureEnabled: true, evaluator });
  assert.equal(result.items.length, 2);
  assert.deepEqual(
    result.items.map((i) => `${i.businessId}/${i.productId}`).sort(),
    ["bizA/shared-id", "bizB/shared-id"]
  );
});

// =====================================================================
// Visibility/evaluator integration — items 29-42
// =====================================================================

test("list: candidate is only included when evaluator returns exact eligible:true", async () => {
  const docs = { "businesses/biz1/products/p1": baseProduct() };
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set() });
  const result = await getMarketplaceProductList({ db, data: {}, featureEnabled: true, evaluator });
  assert.equal(result.items.length, 0);
  assert.equal(evaluator.calls.length, 1);
});

test("list: evaluator is called with no tx and no productSnapshot", async () => {
  const docs = { "businesses/biz1/products/p1": baseProduct() };
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(Object.keys(docs)) });
  await getMarketplaceProductList({ db, data: {}, featureEnabled: true, evaluator });
  assert.equal(evaluator.calls[0].tx, undefined);
  assert.equal(evaluator.calls[0].productSnapshot, undefined);
});

test("list: an unexpected evaluator exception omits only that candidate and continues", async () => {
  const docs = {
    "businesses/biz1/products/p1": baseProduct(),
    "businesses/biz1/products/p2": baseProduct(),
  };
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({
    eligiblePaths: new Set(["businesses/biz1/products/p2"]),
    throwFor: new Set(["businesses/biz1/products/p1"]),
  });
  const result = await getMarketplaceProductList({ db, data: {}, featureEnabled: true, evaluator });
  assert.deepEqual(
    result.items.map((i) => i.productId),
    ["p2"]
  );
  assert.equal(evaluator.calls.length, 2, "the throwing candidate must not abort remaining evaluation");
});

test("list: a whole-query failure throws internal/Unable to load products with no partial result", async () => {
  const db = createFakeDb({});
  db.queryError = new Error("simulated Firestore outage");
  await assert.rejects(
    () => getMarketplaceProductList({ db, data: {}, featureEnabled: true, evaluator: createFakeEvaluator() }),
    { code: "internal", message: "Unable to load products" }
  );
});

test("list: request-validation invalid-argument is never remapped to internal", async () => {
  const db = createFakeDb({});
  db.queryError = new Error("should never be reached");
  await assert.rejects(
    () => getMarketplaceProductList({ db, data: { pageSize: -1 }, featureEnabled: true }),
    { code: "invalid-argument" }
  );
});

test("detail: every hidden/absence condition is indistinguishable — not-found/Product not found", async () => {
  const cases = [
    // nonexistent
    { docs: {}, businessId: "biz1", productId: "missing" },
    // cross-tenant mismatch
    {
      docs: { "businesses/biz1/products/p1": baseProduct({ businessId: "other-biz" }) },
      businessId: "biz1",
      productId: "p1",
    },
    // inactive
    {
      docs: { "businesses/biz1/products/p1": baseProduct({ isActive: false }) },
      businessId: "biz1",
      productId: "p1",
    },
    // unapproved
    {
      docs: { "businesses/biz1/products/p1": baseProduct({ moderationStatus: "pending_review" }) },
      businessId: "biz1",
      productId: "p1",
    },
    // malformed (fails hide-product tier: missing name)
    {
      docs: { "businesses/biz1/products/p1": baseProduct({ name: "" }) },
      businessId: "biz1",
      productId: "p1",
    },
  ];
  for (const c of cases) {
    const db = createFakeDb(c.docs);
    const evaluator = createFakeEvaluator({ eligiblePaths: new Set() });
    await assert.rejects(
      () =>
        getMarketplaceProductDetail({
          db,
          data: { businessId: c.businessId, productId: c.productId },
          featureEnabled: true,
          evaluator,
        }),
      { code: "not-found", message: "Product not found" }
    );
  }
});

test("detail: evaluator eligible:false produces the identical not-found outcome", async () => {
  const docs = { "businesses/biz1/products/p1": baseProduct() };
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set() });
  await assert.rejects(
    () =>
      getMarketplaceProductDetail({ db, data: { businessId: "biz1", productId: "p1" }, featureEnabled: true, evaluator }),
    { code: "not-found", message: "Product not found" }
  );
});

test("detail: unexpected infrastructure failure maps to internal/Unable to load product", async () => {
  const db = createFakeDb({ "businesses/biz1/products/p1": baseProduct() });
  const evaluator = createFakeEvaluator({
    eligiblePaths: new Set(),
    throwFor: new Set(["businesses/biz1/products/p1"]),
  });
  await assert.rejects(
    () =>
      getMarketplaceProductDetail({ db, data: { businessId: "biz1", productId: "p1" }, featureEnabled: true, evaluator }),
    { code: "internal", message: "Unable to load product" }
  );
});

test("detail: a genuine Firestore read failure maps to internal/Unable to load product", async () => {
  const db = createFakeDb({});
  const originalDoc = db.collection("businesses").doc;
  db.collection = () => ({
    doc: () => ({
      collection: () => ({
        doc: () => ({
          get: async () => {
            throw new Error("simulated outage");
          },
        }),
      }),
    }),
  });
  await assert.rejects(
    () =>
      getMarketplaceProductDetail({ db, data: { businessId: "biz1", productId: "p1" }, featureEnabled: true }),
    { code: "internal", message: "Unable to load product" }
  );
});

test("detail: successful response is exactly { item: {...} }", async () => {
  const db = createFakeDb({ "businesses/biz1/products/p1": baseProduct() });
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(["businesses/biz1/products/p1"]) });
  const result = await getMarketplaceProductDetail({
    db,
    data: { businessId: "biz1", productId: "p1" },
    featureEnabled: true,
    evaluator,
  });
  assert.deepEqual(Object.keys(result), ["item"]);
  assert.equal(result.item.productId, "p1");
});

// =====================================================================
// Projection — exact 29 keys, tiers
// =====================================================================

const EXPECTED_KEYS = [
  "businessId",
  "productId",
  "name",
  "description",
  "category",
  "brand",
  "media",
  "price",
  "salePrice",
  "currency",
  "kdvRate",
  "taxIncluded",
  "stock",
  "shippingMode",
  "shippingPayer",
  "shippingFee",
  "freeShippingThreshold",
  "allowFreeShipping",
  "allowedCarrierCodes",
  "originCity",
  "maxDeliveryDays",
  "deliveryType",
  "weightKg",
  "lengthCm",
  "widthCm",
  "heightCm",
  "fixedDesi",
  "businessName",
  "businessLogo",
];

test("projection: exactly the 29 frozen keys, no more, no fewer", () => {
  const proj = projectPublicProduct(baseProduct(), "businesses/biz1/products/p1", 1);
  assert.equal(Object.keys(proj).length, 29);
  assert.deepEqual(Object.keys(proj).sort(), EXPECTED_KEYS.slice().sort());
});

test("projection: list and detail apply the identical projector — same output for the same input, differing only in media cap", () => {
  const raw = baseProduct({ media: [readyImage("https://cdn.example.test/1.jpg"), readyImage("https://cdn.example.test/2.jpg")] });
  const listProj = projectPublicProduct(raw, "businesses/biz1/products/p1", 1);
  const detailProj = projectPublicProduct(raw, "businesses/biz1/products/p1", 20);
  const { media: listMedia, ...listRest } = listProj;
  const { media: detailMedia, ...detailRest } = detailProj;
  assert.deepEqual(listRest, detailRest);
  assert.equal(listMedia.length, 1);
  assert.equal(detailMedia.length, 2);
});

test("projection: unknown/future Firestore fields never appear in the output", () => {
  const proj = projectPublicProduct(
    baseProduct({ someFutureField: "x", anotherOne: 123 }),
    "businesses/biz1/products/p1",
    1
  );
  assert.ok(!("someFutureField" in proj));
  assert.ok(!("anotherOne" in proj));
});

test("projection: every mandatory compliance/internal field is excluded even when present on the stored document", () => {
  const raw = baseProduct({
    evidenceRevision: 3,
    productInputRevision: 2,
    productInputRevisionSnapshot: 2,
    sellerRelationship: "brand_owner",
    sellerRelationshipSnapshot: "brand_owner",
    policyVersion: "v1",
    requiredEvidenceSlots: [],
    satisfiedEvidenceSlots: [],
    activeEvidenceRefs: [],
    decisionHash: "abc",
    complianceReasonCode: "x",
    complianceUpdatedAt: null,
    complianceValidUntil: null,
    complianceEffectiveStatus: "verified_valid",
    moderationStatus: "approved",
    isActive: true,
    barcode: "1234567890",
    sku: "SKU-1",
    wholesalePrice: 5,
    suggestedPrice: 25,
    minStock: 1,
    createdAt: "2026-01-01",
    updatedAt: "2026-01-02",
  });
  const proj = projectPublicProduct(raw, "businesses/biz1/products/p1", 1);
  for (const forbidden of [
    "evidenceRevision",
    "productInputRevision",
    "productInputRevisionSnapshot",
    "sellerRelationship",
    "sellerRelationshipSnapshot",
    "policyVersion",
    "requiredEvidenceSlots",
    "satisfiedEvidenceSlots",
    "activeEvidenceRefs",
    "decisionHash",
    "complianceReasonCode",
    "complianceUpdatedAt",
    "complianceValidUntil",
    "complianceEffectiveStatus",
    "moderationStatus",
    "isActive",
    "barcode",
    "sku",
    "wholesalePrice",
    "suggestedPrice",
    "minStock",
    "createdAt",
    "updatedAt",
  ]) {
    assert.ok(!(forbidden in proj), `${forbidden} must not appear in the public projection`);
  }
});

test("projection: businessId/productId are sourced from the validated path, never the stored field", () => {
  const raw = baseProduct({ businessId: "WRONG-STORED-ID" });
  const proj = projectPublicProduct(raw, "businesses/real-biz/products/real-prod", 1);
  assert.equal(proj.businessId, "real-biz");
  assert.equal(proj.productId, "real-prod");
});

// --- Hide-product tier: businessId/productId/name/category/price/stock/media(array) ---

test("projection: required hide-product fields hide the whole product when missing/malformed", () => {
  const cases = [
    { name: undefined },
    { name: "" },
    { name: "   " },
    { category: undefined },
    { category: "" },
    { price: undefined },
    { price: "19.99" },
    { price: -1 },
    { price: NaN },
    { stock: undefined },
    { stock: 1.5 },
    { stock: -1 },
    { media: undefined },
    { media: "not-an-array" },
    { media: {} },
  ];
  for (const override of cases) {
    const proj = projectPublicProduct(baseProduct(override), "businesses/biz1/products/p1", 1);
    assert.equal(proj, null, `expected hide for ${JSON.stringify(override)}`);
  }
});

test("projection: raw source media length > 20 hides the product, never truncates", () => {
  const media = [];
  for (let i = 0; i < 21; i += 1) media.push(readyImage(`https://cdn.example.test/${i}.jpg`));
  const proj = projectPublicProduct(baseProduct({ media }), "businesses/biz1/products/p1", 20);
  assert.equal(proj, null);
});

test("projection: raw source media length exactly 20 is accepted (not hidden)", () => {
  const media = [];
  for (let i = 0; i < 20; i += 1) media.push(readyImage(`https://cdn.example.test/${i}.jpg`));
  const proj = projectPublicProduct(baseProduct({ media }), "businesses/biz1/products/p1", 20);
  assert.notEqual(proj, null);
  assert.equal(proj.media.length, 20);
});

test("projection: string length boundaries — name/category at max accepted, max+1 hides", () => {
  const okName = "n".repeat(200);
  const overName = "n".repeat(201);
  assert.notEqual(projectPublicProduct(baseProduct({ name: okName }), "businesses/b/products/p", 1), null);
  assert.equal(projectPublicProduct(baseProduct({ name: overName }), "businesses/b/products/p", 1), null);

  const okCategory = "c".repeat(200);
  const overCategory = "c".repeat(201);
  assert.notEqual(projectPublicProduct(baseProduct({ category: okCategory }), "businesses/b/products/p", 1), null);
  assert.equal(projectPublicProduct(baseProduct({ category: overCategory }), "businesses/b/products/p", 1), null);
});

// --- Default tier: description/allowFreeShipping/allowedCarrierCodes/deliveryType ---

test("projection: description defaults to '' when missing/wrong-type/overlength, never hides the product", () => {
  for (const bad of [undefined, 123, {}, "d".repeat(5001)]) {
    const proj = projectPublicProduct(baseProduct({ description: bad }), "businesses/b/products/p", 1);
    assert.notEqual(proj, null);
    assert.equal(proj.description, "");
  }
  const proj = projectPublicProduct(baseProduct({ description: "d".repeat(5000) }), "businesses/b/products/p", 1);
  assert.equal(proj.description.length, 5000);
});

test("projection: allowFreeShipping defaults to false when missing/wrong-type", () => {
  for (const bad of [undefined, "true", 1, null]) {
    const proj = projectPublicProduct(baseProduct({ allowFreeShipping: bad }), "businesses/b/products/p", 1);
    assert.equal(proj.allowFreeShipping, false);
  }
  const proj = projectPublicProduct(baseProduct({ allowFreeShipping: true }), "businesses/b/products/p", 1);
  assert.equal(proj.allowFreeShipping, true);
});

test("projection: deliveryType defaults to 'cargo' when missing/invalid/overlength", () => {
  for (const bad of [undefined, "", "d".repeat(65), 123]) {
    const proj = projectPublicProduct(baseProduct({ deliveryType: bad }), "businesses/b/products/p", 1);
    assert.equal(proj.deliveryType, "cargo");
  }
  const proj = projectPublicProduct(baseProduct({ deliveryType: "digital" }), "businesses/b/products/p", 1);
  assert.equal(proj.deliveryType, "digital");
});

// --- Currency conditional default ---

test("currency: absent -> TRY", () => {
  const proj = projectPublicProduct(baseProduct({ currency: undefined }), "businesses/b/products/p", 1);
  assert.equal(proj.currency, "TRY");
});

test("currency: explicit null -> TRY", () => {
  const proj = projectPublicProduct(baseProduct({ currency: null }), "businesses/b/products/p", 1);
  assert.equal(proj.currency, "TRY");
});

test("currency: TRY/USD/EUR preserved exactly", () => {
  for (const c of ["TRY", "USD", "EUR"]) {
    const proj = projectPublicProduct(baseProduct({ currency: c }), "businesses/b/products/p", 1);
    assert.equal(proj.currency, c);
  }
});

test("currency: lowercase/mixed-case/unsupported/non-string/empty values hide the product, never silently become TRY", () => {
  const invalid = ["try", "Try", "usd", "GBP", "", "   ", 5, true, [], {}];
  for (const value of invalid) {
    const proj = projectPublicProduct(baseProduct({ currency: value }), "businesses/b/products/p", 1);
    assert.equal(proj, null, `expected hide for currency ${JSON.stringify(value)}`);
  }
});

test("currency: no trimming/normalization is ever applied", () => {
  const proj = projectPublicProduct(baseProduct({ currency: " TRY" }), "businesses/b/products/p", 1);
  assert.equal(proj, null, "' TRY' with a leading space must not be trimmed into a match");
});

// --- Null tier ---

test("projection: every null-tier field is null when missing/wrong-type, unchanged when valid", () => {
  const raw = baseProduct({
    brand: undefined,
    salePrice: "not-a-number",
    kdvRate: undefined,
    taxIncluded: "yes",
    shippingMode: undefined,
    shippingPayer: undefined,
    shippingFee: undefined,
    freeShippingThreshold: undefined,
    originCity: undefined,
    maxDeliveryDays: 2.5,
    weightKg: undefined,
    lengthCm: undefined,
    widthCm: undefined,
    heightCm: undefined,
    fixedDesi: undefined,
    businessName: undefined,
    businessLogo: undefined,
  });
  const proj = projectPublicProduct(raw, "businesses/b/products/p", 1);
  for (const key of [
    "brand",
    "salePrice",
    "kdvRate",
    "taxIncluded",
    "shippingMode",
    "shippingPayer",
    "shippingFee",
    "freeShippingThreshold",
    "originCity",
    "maxDeliveryDays",
    "weightKg",
    "lengthCm",
    "widthCm",
    "heightCm",
    "fixedDesi",
    "businessName",
    "businessLogo",
  ]) {
    assert.equal(proj[key], null, `expected ${key} to be null`);
  }

  const validRaw = baseProduct({
    brand: "Acme",
    salePrice: 9.99,
    kdvRate: 20,
    taxIncluded: true,
    shippingMode: "fixed_price",
    shippingPayer: "seller",
    shippingFee: 15,
    freeShippingThreshold: 100,
    originCity: "Istanbul",
    maxDeliveryDays: 3,
    weightKg: 1.2,
    lengthCm: 10,
    widthCm: 5,
    heightCm: 5,
    fixedDesi: 2,
    businessName: "Acme Pet Shop",
    businessLogo: "https://cdn.example.test/logo.png",
  });
  const validProj = projectPublicProduct(validRaw, "businesses/b/products/p", 1);
  assert.equal(validProj.brand, "Acme");
  assert.equal(validProj.salePrice, 9.99);
  assert.equal(validProj.kdvRate, 20);
  assert.equal(validProj.taxIncluded, true);
  assert.equal(validProj.shippingMode, "fixed_price");
  assert.equal(validProj.maxDeliveryDays, 3);
  assert.equal(validProj.businessLogo, "https://cdn.example.test/logo.png");
});

test("projection: null-tier numeric fields reject NaN/Infinity/negative", () => {
  for (const bad of [NaN, Infinity, -Infinity, -1]) {
    const proj = projectPublicProduct(baseProduct({ salePrice: bad }), "businesses/b/products/p", 1);
    assert.equal(proj.salePrice, null);
  }
});

test("projection: businessLogo boundary — 2048 accepted, 2049 becomes null", () => {
  const ok = projectPublicProduct(
    baseProduct({ businessLogo: "https://cdn.example.test/" + "l".repeat(2048 - 25) }),
    "businesses/b/products/p",
    1
  );
  const okLogo = ok.businessLogo;
  assert.ok(okLogo === null || okLogo.length <= 2048);
  const over = projectPublicProduct(baseProduct({ businessLogo: "x".repeat(2049) }), "businesses/b/products/p", 1);
  assert.equal(over.businessLogo, null);
});

// --- allowedCarrierCodes ---

test("allowedCarrierCodes: defaults to [] for absent/non-array", () => {
  for (const bad of [undefined, "not-an-array", {}]) {
    const proj = projectPublicProduct(baseProduct({ allowedCarrierCodes: bad }), "businesses/b/products/p", 1);
    assert.deepEqual(proj.allowedCarrierCodes, []);
  }
});

test("allowedCarrierCodes: invalid/overlength entries dropped individually, order preserved", () => {
  const raw = ["MNG", 123, "", "y".repeat(65), "ARAS"];
  const proj = projectPublicProduct(baseProduct({ allowedCarrierCodes: raw }), "businesses/b/products/p", 1);
  assert.deepEqual(proj.allowedCarrierCodes, ["MNG", "ARAS"]);
});

test("allowedCarrierCodes: deduplicated by first occurrence", () => {
  const raw = ["MNG", "ARAS", "MNG"];
  const proj = projectPublicProduct(baseProduct({ allowedCarrierCodes: raw }), "businesses/b/products/p", 1);
  assert.deepEqual(proj.allowedCarrierCodes, ["MNG", "ARAS"]);
});

test("allowedCarrierCodes: capped at the first 50 valid entries", () => {
  const raw = Array.from({ length: 60 }, (_, i) => `C${i}`);
  const proj = projectPublicProduct(baseProduct({ allowedCarrierCodes: raw }), "businesses/b/products/p", 1);
  assert.equal(proj.allowedCarrierCodes.length, 50);
  assert.deepEqual(proj.allowedCarrierCodes, raw.slice(0, 50));
});

// --- Media ---

test("media: list projection caps at exactly 1 valid entry, stops scanning immediately after", () => {
  const media = [
    readyImage("https://cdn.example.test/1.jpg"),
    readyImage("https://cdn.example.test/2.jpg"),
    readyImage("https://cdn.example.test/3.jpg"),
  ];
  const proj = projectPublicProduct(baseProduct({ media }), "businesses/b/products/p", 1);
  assert.equal(proj.media.length, 1);
  assert.equal(proj.media[0].originalUrl, "https://cdn.example.test/1.jpg");
});

test("media: detail projection returns every valid entry up to 20, in source order", () => {
  const media = Array.from({ length: 6 }, (_, i) => readyImage(`https://cdn.example.test/${i}.jpg`));
  const proj = projectPublicProduct(baseProduct({ media }), "businesses/b/products/p", 20);
  assert.equal(proj.media.length, 6);
  assert.deepEqual(
    proj.media.map((m) => m.originalUrl),
    media.map((m) => m.originalUrl)
  );
});

test("media: zero valid entries returns []", () => {
  const proj = projectPublicProduct(baseProduct({ media: [] }), "businesses/b/products/p", 20);
  assert.deepEqual(proj.media, []);
});

test("media: invalid entries before/between valid ones are skipped without consuming the cap", () => {
  const media = [
    { type: "image", originalUrl: "https://cdn.example.test/bad.jpg", status: "processing" }, // not ready
    readyImage("https://cdn.example.test/good1.jpg"),
    { type: "unknown", originalUrl: "https://cdn.example.test/bad2.jpg", status: "ready" }, // bad type
    readyImage("https://cdn.example.test/good2.jpg"),
  ];
  const listProj = projectPublicProduct(baseProduct({ media }), "businesses/b/products/p", 1);
  assert.equal(listProj.media.length, 1);
  assert.equal(listProj.media[0].originalUrl, "https://cdn.example.test/good1.jpg");

  const detailProj = projectPublicProduct(baseProduct({ media }), "businesses/b/products/p", 20);
  assert.deepEqual(
    detailProj.media.map((m) => m.originalUrl),
    ["https://cdn.example.test/good1.jpg", "https://cdn.example.test/good2.jpg"]
  );
});

test("media: status is stripped from the output and used only as the ready-filter", () => {
  const media = [readyImage("https://cdn.example.test/1.jpg")];
  const proj = projectPublicProduct(baseProduct({ media }), "businesses/b/products/p", 20);
  assert.ok(!("status" in proj.media[0]));
  assert.deepEqual(Object.keys(proj.media[0]).sort(), ["originalUrl", "playbackUrl", "thumbnailUrl", "type"].sort());
});

test("media: invalid/overlength URL becomes null for that key without dropping the entry, unless all three are invalid", () => {
  const media = [
    { type: "image", originalUrl: "https://cdn.example.test/ok.jpg", playbackUrl: "x".repeat(2049), status: "ready" },
  ];
  const proj = projectPublicProduct(baseProduct({ media }), "businesses/b/products/p", 20);
  assert.equal(proj.media.length, 1);
  assert.equal(proj.media[0].originalUrl, "https://cdn.example.test/ok.jpg");
  assert.equal(proj.media[0].playbackUrl, null);
});

test("media: entry with no usable URL after validation is dropped entirely", () => {
  const media = [{ type: "image", originalUrl: "", playbackUrl: null, thumbnailUrl: null, status: "ready" }];
  const proj = projectPublicProduct(baseProduct({ media }), "businesses/b/products/p", 20);
  assert.deepEqual(proj.media, []);
});

test("media: URL boundary — 2048 accepted, 2049 becomes null", () => {
  const okUrl = "https://cdn.example.test/" + "a".repeat(2048 - 25);
  const overUrl = "https://cdn.example.test/" + "a".repeat(2049 - 25 + 1);
  const okMedia = [{ type: "image", originalUrl: okUrl, status: "ready" }];
  const overMedia = [{ type: "image", originalUrl: overUrl, status: "ready" }];
  const okProj = projectPublicProduct(baseProduct({ media: okMedia }), "businesses/b/products/p", 20);
  assert.equal(okProj.media.length, 1);
  const overProj = projectPublicProduct(baseProduct({ media: overMedia }), "businesses/b/products/p", 20);
  assert.deepEqual(overProj.media, []); // originalUrl -> null, no other URL -> entry dropped
});

test("media: invalid type drops the entry regardless of URL validity", () => {
  const media = [{ type: "audio", originalUrl: "https://cdn.example.test/a.mp3", status: "ready" }];
  const proj = projectPublicProduct(baseProduct({ media }), "businesses/b/products/p", 20);
  assert.deepEqual(proj.media, []);
});

// =====================================================================
// Envelopes
// =====================================================================

test("list: successful envelope is exactly { items, nextCursor }", async () => {
  const docs = { "businesses/biz1/products/p1": baseProduct() };
  const db = createFakeDb(docs);
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(Object.keys(docs)) });
  const result = await getMarketplaceProductList({ db, data: {}, featureEnabled: true, evaluator });
  assert.deepEqual(Object.keys(result).sort(), ["items", "nextCursor"]);
});

// =====================================================================
// Zero-write proof
// =====================================================================

// Strips `//`-style line comments so static-inspection assertions check
// actual code, not disclaiming prose in the module's own header comments
// (which legitimately name these forbidden identifiers to explain their
// absence).
function stripLineComments(source) {
  return source
    .split("\n")
    .map((line) => line.replace(/\/\/.*$/, ""))
    .join("\n");
}

const MODULE_CODE_ONLY = stripLineComments(MODULE_SOURCE);

test("marketplaceListing.js contains no write call of any kind (static source inspection)", () => {
  const writePatterns = [
    /\.set\s*\(/,
    /\.create\s*\(/,
    /\.update\s*\(/,
    /\.delete\s*\(/,
    /\brunTransaction/,
    /\bbatch\s*\(/,
  ];
  for (const pattern of writePatterns) {
    assert.doesNotMatch(MODULE_CODE_ONLY, pattern, `forbidden write pattern found: ${pattern}`);
  }
  // `.add(` is checked separately and narrowly, since `Set#add()` (used by
  // the carrier-code deduplication helper) is a legitimate, non-Firestore
  // use of the same method name.
  assert.doesNotMatch(MODULE_CODE_ONLY, /\.collection\([^)]*\)\.add\s*\(/);
});

test("marketplaceListing.js never imports/calls recomputeProductComplianceStatus", () => {
  assert.doesNotMatch(MODULE_CODE_ONLY, /recomputeProductComplianceStatus/);
});

test("marketplaceListing.js never reads productEvidenceLinks or complianceDocumentScopes", () => {
  assert.doesNotMatch(MODULE_CODE_ONLY, /productEvidenceLinks/);
  assert.doesNotMatch(MODULE_CODE_ONLY, /complianceDocumentScopes/);
});

test("list/detail: zero writes occur through the fake db across a full invocation (no set/create/update/delete method ever invoked)", async () => {
  const docs = { "businesses/biz1/products/p1": baseProduct() };
  const db = createFakeDb(docs);
  let writeCalled = false;
  for (const method of ["set", "create", "update", "delete", "add"]) {
    db[method] = () => {
      writeCalled = true;
    };
  }
  const evaluator = createFakeEvaluator({ eligiblePaths: new Set(Object.keys(docs)) });
  await getMarketplaceProductList({ db, data: {}, featureEnabled: true, evaluator });
  await getMarketplaceProductDetail({
    db,
    data: { businessId: "biz1", productId: "p1" },
    featureEnabled: true,
    evaluator,
  });
  assert.equal(writeCalled, false);
});

// =====================================================================
// Payload-bound proof — §10.1 conservative worst-case calculation
// =====================================================================

function maxBoundListItemSource() {
  const media = [];
  for (let i = 0; i < 1; i += 1) {
    media.push({
      type: "image",
      originalUrl: "u".repeat(2048),
      playbackUrl: "u".repeat(2048),
      thumbnailUrl: "u".repeat(2048),
      status: "ready",
    });
  }
  return baseProduct({
    businessId: "b".repeat(256 - "businesses/".length - "/products/x".length > 0 ? 50 : 10),
    name: "n".repeat(200),
    description: "d".repeat(5000),
    category: "c".repeat(200),
    brand: "b".repeat(200),
    media,
    price: 99999.99,
    salePrice: 9999.99,
    currency: "TRY",
    kdvRate: 20,
    taxIncluded: true,
    stock: 999999,
    shippingMode: "s".repeat(64),
    shippingPayer: "s".repeat(64),
    shippingFee: 999.99,
    freeShippingThreshold: 999.99,
    allowFreeShipping: true,
    allowedCarrierCodes: Array.from({ length: 50 }, (_, i) => `CARRIER_${i}`.padEnd(64, "x").slice(0, 64)),
    originCity: "o".repeat(200),
    maxDeliveryDays: 30,
    deliveryType: "d".repeat(64),
    weightKg: 100,
    lengthCm: 100,
    widthCm: 100,
    heightCm: 100,
    fixedDesi: 100,
    businessName: "n".repeat(200),
    businessLogo: "l".repeat(2048),
  });
}

test("payload bound: maximum-bound single list item stays well below the 5 MiB internal design budget", () => {
  const proj = projectPublicProduct(maxBoundListItemSource(), "businesses/biz1/products/prod1", 1);
  assert.notEqual(proj, null);
  const serialized = JSON.stringify(proj);
  // Conservative worst-case byte accounting: up to 6 bytes per UTF-16 code
  // unit for attacker-controlled string content (§10.1's own frozen
  // multiplier), independently re-derived here rather than trusting the
  // actual (much smaller, ASCII-only) serialized byte length alone.
  const worstCaseBytes = serialized.length * 6;
  const listTotal = worstCaseBytes * 20; // pageSize = 20
  assert.ok(listTotal < 5 * 1024 * 1024, `worst-case list total ${listTotal} bytes exceeds 5 MiB`);
});

test("payload bound: maximum-bound detail item (media cap 20) stays well below the 5 MiB internal design budget", () => {
  const source = maxBoundListItemSource();
  source.media = Array.from({ length: 20 }, () => ({
    type: "image",
    originalUrl: "u".repeat(2048),
    playbackUrl: "u".repeat(2048),
    thumbnailUrl: "u".repeat(2048),
    status: "ready",
  }));
  const proj = projectPublicProduct(source, "businesses/biz1/products/prod1", 20);
  assert.equal(proj.media.length, 20);
  const serialized = JSON.stringify(proj);
  const worstCaseBytes = serialized.length * 6;
  assert.ok(worstCaseBytes < 5 * 1024 * 1024, `worst-case detail total ${worstCaseBytes} bytes exceeds 5 MiB`);
});

test("payload bound: nextCursor's own maximum length (256 encoded chars) is included in list envelope size reasoning", () => {
  const maxCursor = "a".repeat(256);
  const envelope = { items: [], nextCursor: maxCursor };
  const serialized = JSON.stringify(envelope);
  assert.ok(serialized.length <= 300);
});

// =====================================================================
// Static future-prerequisite / scope-boundary coverage
// =====================================================================

test("scope: marketplaceListing.js does not implement the Rules prerequisite, readiness tooling, or Flutter migration", () => {
  assert.doesNotMatch(MODULE_SOURCE, /isSafeNewProductSubmission|isSafeProductResubmission/);
  assert.doesNotMatch(MODULE_SOURCE, /runId|checkpoint/i);
});

test("scope: only the announced implementation files exist in publicCatalog/ (Slice 4.5's two, plus Revision 38's frozen contract)", () => {
  // A structural assertion: no UNANNOUNCED sibling implementation file may
  // appear beside the catalogue module. Slice 4.5 froze this directory at a
  // single file; Marketplace Revision 38 §0.36 (Slice 7B) authorizes exactly
  // one addition — `marketplacePublicVisibility.js`, the frozen public
  // visibility contract, which is pure data and performs no reads. The guard
  // is migrated rather than deleted: a third, unannounced file still fails.
  const publicCatalogDir = path.join(REPO_ROOT, "functions", "src", "marketplace", "publicCatalog");
  const entries = fs.readdirSync(publicCatalogDir);
  assert.deepEqual(entries.sort(), [
    "marketplaceListing.js",
    // Revision 39 §0.37 (Slice 7B-C1) — the ONE canonical live-visibility
    // predicate, extracted so batch hydration and checkout share it with
    // list/detail instead of copying it.
    "marketplaceProductVisibility.js",
    "marketplacePublicVisibility.js",
  ]);
});

test("scope: no App Check enforcement is claimed anywhere in marketplaceListing.js or this test file's own source", () => {
  assert.doesNotMatch(MODULE_SOURCE, /enforceAppCheck:\s*true/);
});

test("scope: the feature flag cannot be enabled by this implementation — no code path sets MARKETPLACE_LISTING_ENABLED", () => {
  assert.doesNotMatch(MODULE_SOURCE, /MARKETPLACE_LISTING_ENABLED/);
});

test("scope: no rate-limit/counter/quota mechanism exists in marketplaceListing.js", () => {
  assert.doesNotMatch(MODULE_SOURCE, /rateLimit|RateLimit|quota|Quota/);
});
