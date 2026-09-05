"use strict";

// Marketplace Revision 47 §0.45 (Slice 7F-2) — behavioural coverage for the
// bounded basket.
//
// Two layers, both against real production code:
//
//   1. the pure contract (`validateAndNormalizeBasket`), exercised directly
//      so every boundary and rejection code is pinned; and
//   2. the real `createMarketplaceOrderV2` callable against the emulator,
//      proving an oversized basket is refused with NO order, seller order or
//      other side effect, while an at-limit basket still checks out.
//
// The invariant: no client-supplied basket can drive unbounded transactional
// work, and no bound can be bypassed by splitting a product across lines.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test, after } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();
const functions = require("../index");

const {
  BASKET_LIMITS,
  BASKET_REJECTION,
  isValidQuantity,
  validateAndNormalizeBasket,
} = require("../src/marketplace/orders/basketLimits");
const {
  COMPLIANCE_DOCUMENT_TYPE,
  COMPLIANCE_DOCUMENT_STATUS,
  COMPLIANCE_SCOPE_TYPE,
  COMPLIANCE_SCOPE_STATUS,
  COMPLIANCE_POLICY_REGISTRY_STATUS,
  isValidPilotProductClass,
} = require("../src/marketplace/compliance/complianceConstants");
const {
  computeApprovalFingerprint,
} = require("../src/marketplace/compliance/pilotProductApproval");
const {
  computeDecisionHash,
} = require("../src/marketplace/compliance/complianceProductRecompute");
const {
  buildRevision30PolicyVersion,
} = require("../src/marketplace/compliance/complianceRevision30Policy");

const hasEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function itest(name, fn) {
  test(name, { skip: !hasEmulator }, fn);
}

const RUN = Math.random().toString(36).slice(2, 8);
let seq = 0;
const nextId = (p) => `${p}-${RUN}-${(seq += 1)}`;

const created = {
  businesses: [], products: [], decisions: [], admins: [],
  policies: [], documents: [], scopes: [], orders: [], sellerOrders: [],
};

const line = (businessId, productId, quantity = 1) => ({
  shopId: businessId, productId, quantity,
});

// =====================================================================
// 1. The pure contract
// =====================================================================

test("the frozen bounds are positive integers and internally consistent", () => {
  for (const [name, value] of Object.entries(BASKET_LIMITS)) {
    assert.ok(Number.isInteger(value) && value >= 1, `${name} must be a positive integer`);
  }
  assert.ok(BASKET_LIMITS.MAX_DISTINCT_PRODUCTS <= BASKET_LIMITS.MAX_SUBMITTED_LINES);
  assert.ok(BASKET_LIMITS.MAX_TOTAL_UNITS >= BASKET_LIMITS.MAX_QUANTITY_PER_PRODUCT);
  assert.equal(Object.isFrozen(BASKET_LIMITS), true, "the bounds must be immutable");
});

test("the distinct-product bound equals the batch hydration bound it was derived from", () => {
  // Not a coincidence: a cart must never hold more products than the batch
  // hydration callable can serve in one request. If that bound moves, this
  // fails and the derivation must be revisited rather than silently drift.
  const {
    getMarketplaceProductBatch,
  } = require("../src/marketplace/publicCatalog/marketplaceListing");
  assert.ok(getMarketplaceProductBatch, "the batch callable must exist");
  const listingSource = require("node:fs").readFileSync(
    require("node:path").join(__dirname, "..", "src/marketplace/publicCatalog/marketplaceListing.js"),
    "utf8"
  );
  const match = listingSource.match(/const BATCH_MAX_ITEMS = (\d+);/);
  assert.ok(match, "BATCH_MAX_ITEMS must be declared");
  assert.equal(
    Number(match[1]),
    BASKET_LIMITS.MAX_DISTINCT_PRODUCTS,
    "MAX_DISTINCT_PRODUCTS is derived from BATCH_MAX_ITEMS and must equal it"
  );
});

test("2. items that are missing, not a list, or empty are rejected", () => {
  const cases = [
    [undefined, BASKET_REJECTION.ITEMS_MISSING],
    [null, BASKET_REJECTION.ITEMS_MISSING],
    ["nope", BASKET_REJECTION.ITEMS_NOT_A_LIST],
    [42, BASKET_REJECTION.ITEMS_NOT_A_LIST],
    [{ 0: line("b", "p") }, BASKET_REJECTION.ITEMS_NOT_A_LIST],
    [[], BASKET_REJECTION.BASKET_EMPTY],
  ];
  for (const [input, code] of cases) {
    assert.throws(
      () => validateAndNormalizeBasket(input),
      (e) => e.details.reasonCode === code,
      JSON.stringify(input)
    );
  }
});

test("3. a raw line count above the bound is rejected", () => {
  const ok = Array.from({ length: BASKET_LIMITS.MAX_SUBMITTED_LINES }, (_, i) =>
    line(`b${i % BASKET_LIMITS.MAX_BUSINESSES}`, `p${i}`)
  );
  // At the raw bound the distinct-product bound bites first, which is the
  // designed ordering — the raw bound only guards the payload.
  assert.throws(
    () => validateAndNormalizeBasket(ok),
    (e) => e.details.reasonCode === BASKET_REJECTION.TOO_MANY_PRODUCTS
  );
  const tooMany = Array.from(
    { length: BASKET_LIMITS.MAX_SUBMITTED_LINES + 1 },
    (_, i) => line("b1", `p${i}`)
  );
  assert.throws(
    () => validateAndNormalizeBasket(tooMany),
    (e) => e.details.reasonCode === BASKET_REJECTION.TOO_MANY_LINES
  );
});

test("4. distinct-product boundary: max succeeds, max plus one fails", () => {
  const atLimit = Array.from({ length: BASKET_LIMITS.MAX_DISTINCT_PRODUCTS }, (_, i) =>
    line("b1", `p${i}`)
  );
  const result = validateAndNormalizeBasket(atLimit);
  assert.equal(result.lines.length, BASKET_LIMITS.MAX_DISTINCT_PRODUCTS);

  const overLimit = [...atLimit, line("b1", "p-extra")];
  assert.throws(
    () => validateAndNormalizeBasket(overLimit),
    (e) => e.details.reasonCode === BASKET_REJECTION.TOO_MANY_PRODUCTS
  );
});

test("5-9. malformed identities and quantities are rejected, never coerced", () => {
  const bad = [
    [line("b", "p", 0), BASKET_REJECTION.QUANTITY_INVALID],
    [line("b", "p", -1), BASKET_REJECTION.QUANTITY_INVALID],
    [line("b", "p", -100), BASKET_REJECTION.QUANTITY_INVALID],
    [line("b", "p", 0.5), BASKET_REJECTION.QUANTITY_INVALID],
    [line("b", "p", 1.0001), BASKET_REJECTION.QUANTITY_INVALID],
    [line("b", "p", "2"), BASKET_REJECTION.QUANTITY_INVALID],
    [line("b", "p", NaN), BASKET_REJECTION.QUANTITY_INVALID],
    [line("b", "p", Infinity), BASKET_REJECTION.QUANTITY_INVALID],
    [line("b", "p", -Infinity), BASKET_REJECTION.QUANTITY_INVALID],
    [line("b", "p", null), BASKET_REJECTION.QUANTITY_INVALID],
    // Written out rather than via the helper: its `quantity = 1` default
    // would substitute for `undefined` and hide the case under test.
    [{ shopId: "b", productId: "p", quantity: undefined }, BASKET_REJECTION.QUANTITY_INVALID],
    [{ shopId: "b", productId: "p" }, BASKET_REJECTION.QUANTITY_INVALID],
    [line("b", "p", true), BASKET_REJECTION.QUANTITY_INVALID],
    [line("", "p", 1), BASKET_REJECTION.ITEM_MALFORMED],
    [line("b", "", 1), BASKET_REJECTION.ITEM_MALFORMED],
    [line("   ", "p", 1), BASKET_REJECTION.ITEM_MALFORMED],
    [{ productId: "p", quantity: 1 }, BASKET_REJECTION.ITEM_MALFORMED],
    [{ shopId: "b", quantity: 1 }, BASKET_REJECTION.ITEM_MALFORMED],
    [null, BASKET_REJECTION.ITEM_MALFORMED],
    ["line", BASKET_REJECTION.ITEM_MALFORMED],
    [["nested"], BASKET_REJECTION.ITEM_MALFORMED],
  ];
  for (const [item, code] of bad) {
    assert.throws(
      () => validateAndNormalizeBasket([item]),
      (e) => e.details.reasonCode === code,
      JSON.stringify(item)
    );
  }
  // The strict quantity predicate itself.
  assert.equal(isValidQuantity(1), true);
  assert.equal(isValidQuantity(BASKET_LIMITS.MAX_QUANTITY_PER_PRODUCT), true);
  for (const v of [0, -1, 0.5, "1", NaN, Infinity, null, undefined, true, []]) {
    assert.equal(isValidQuantity(v), false, String(v));
  }
});

test("10. per-product quantity boundary: max succeeds, max plus one fails", () => {
  const atLimit = validateAndNormalizeBasket([
    line("b1", "p1", BASKET_LIMITS.MAX_QUANTITY_PER_PRODUCT),
  ]);
  assert.equal(atLimit.lines[0].quantity, BASKET_LIMITS.MAX_QUANTITY_PER_PRODUCT);

  assert.throws(
    () => validateAndNormalizeBasket([
      line("b1", "p1", BASKET_LIMITS.MAX_QUANTITY_PER_PRODUCT + 1),
    ]),
    (e) => e.details.reasonCode === BASKET_REJECTION.QUANTITY_TOO_LARGE
  );
});

test("11. total-unit boundary is enforced across products", () => {
  const perProduct = BASKET_LIMITS.MAX_QUANTITY_PER_PRODUCT;
  const productsNeeded = Math.ceil(BASKET_LIMITS.MAX_TOTAL_UNITS / perProduct);
  const atLimit = Array.from({ length: productsNeeded }, (_, i) =>
    line("b1", `p${i}`, perProduct)
  );
  const result = validateAndNormalizeBasket(atLimit);
  assert.equal(result.totalUnits, BASKET_LIMITS.MAX_TOTAL_UNITS);

  assert.throws(
    () => validateAndNormalizeBasket([...atLimit, line("b1", "p-extra", 1)]),
    (e) => e.details.reasonCode === BASKET_REJECTION.TOO_MANY_UNITS
  );
});

test("12. duplicate product entries are merged and cannot bypass any bound", () => {
  // Merged, not double-counted.
  const merged = validateAndNormalizeBasket([
    line("b1", "p1", 2),
    line("b1", "p1", 3),
  ]);
  assert.equal(merged.lines.length, 1, "duplicates must merge into one line");
  assert.equal(merged.lines[0].quantity, 5);
  assert.equal(merged.totalUnits, 5);

  // Splitting across lines cannot exceed the per-product cap.
  const half = Math.ceil(BASKET_LIMITS.MAX_QUANTITY_PER_PRODUCT / 2) + 1;
  assert.throws(
    () => validateAndNormalizeBasket([
      line("b1", "p1", half),
      line("b1", "p1", half),
    ]),
    (e) => e.details.reasonCode === BASKET_REJECTION.QUANTITY_TOO_LARGE,
    "a split product must not exceed the per-product cap"
  );

  // Nor the distinct-product cap.
  const dupes = [];
  for (let i = 0; i < BASKET_LIMITS.MAX_DISTINCT_PRODUCTS; i += 1) {
    dupes.push(line("b1", `p${i}`), line("b1", `p${i}`));
  }
  const ok = validateAndNormalizeBasket(dupes);
  assert.equal(ok.lines.length, BASKET_LIMITS.MAX_DISTINCT_PRODUCTS);
  assert.equal(ok.totalUnits, BASKET_LIMITS.MAX_DISTINCT_PRODUCTS * 2);

  // The same product under two DIFFERENT businesses is two products.
  const crossBusiness = validateAndNormalizeBasket([
    line("b1", "same", 1),
    line("b2", "same", 1),
  ]);
  assert.equal(crossBusiness.lines.length, 2);
});

test("15/16. business boundary: max succeeds, max plus one fails", () => {
  const atLimit = Array.from({ length: BASKET_LIMITS.MAX_BUSINESSES }, (_, i) =>
    line(`b${i}`, `p${i}`)
  );
  assert.equal(
    validateAndNormalizeBasket(atLimit).businessIds.length,
    BASKET_LIMITS.MAX_BUSINESSES
  );
  assert.throws(
    () => validateAndNormalizeBasket([
      ...atLimit,
      line(`b${BASKET_LIMITS.MAX_BUSINESSES}`, "p-extra"),
    ]),
    (e) => e.details.reasonCode === BASKET_REJECTION.TOO_MANY_BUSINESSES
  );
});

test("26/27. equivalent baskets normalize identically; different ones do not", () => {
  const a = validateAndNormalizeBasket([
    line("b2", "p2", 1),
    line("b1", "p1", 2),
    line("b1", "p1", 1),
  ]);
  const b = validateAndNormalizeBasket([
    line("b1", "p1", 3),
    line("b2", "p2", 1),
  ]);
  const shape = (r) => r.lines.map((l) => [l.businessId, l.productId, l.quantity]);
  assert.deepEqual(
    shape(a),
    shape(b),
    "submission order and splitting must not change the normalized basket"
  );
  assert.deepEqual(shape(a), [["b1", "p1", 3], ["b2", "p2", 1]]);

  const different = validateAndNormalizeBasket([
    line("b1", "p1", 4),
    line("b2", "p2", 1),
  ]);
  assert.notDeepEqual(shape(a), shape(different));
});

test("the validator performs no database access", () => {
  // It must be safe to call before any read; a db handle is never taken.
  assert.equal(validateAndNormalizeBasket.length, 1, "it takes only the raw items");
  const source = require("node:fs").readFileSync(
    require("node:path").join(__dirname, "..", "src/marketplace/orders/basketLimits.js"),
    "utf8"
  );
  for (const token of ["collection(", "runTransaction", "firestore(", "admin."]) {
    assert.ok(!source.includes(token), `the validator must not reference ${token}`);
  }
});

// =====================================================================
// End-to-end: the real callable
// =====================================================================

async function seedAdmin() {
  const id = nextId("bl-admin");
  created.admins.push(id);
  await db.collection("users").doc(id).set({ role: "admin" });
  return id;
}

async function seedBusiness() {
  const businessId = nextId("bl-biz");
  created.businesses.push(businessId);
  await db.collection("businesses").doc(businessId).set({
    ownerUid: `owner-${businessId}`,
    status: "approved",
    marketplaceSellerActivation: { active: true },
    marketplaceBusinessGenerationId: `gen-${businessId}`,
    pilotActiveProductCount: 0,
  });
  await db.collection("shipping_configs").doc(businessId).set({
    basePrice: 20, pricePerKg: 5, pricePerDesi: 5,
  });
  return businessId;
}

async function seedProduct(businessId) {
  const productId = nextId("bl-prod");
  created.products.push({ businessId, productId });
  const biz = (await db.collection("businesses").doc(businessId).get()).data();
  await db.collection("businesses").doc(businessId)
    .collection("products").doc(productId).set({
      businessId,
      marketplaceBusinessGenerationId: biz.marketplaceBusinessGenerationId,
      name: "Collar", description: "Ordinary accessory.",
      price: 100, currency: "TRY",
      media: [{ type: "image", originalUrl: "https://example.test/1.jpg" }],
      category: "Accessories > Collar", brand: "Acme",
      salePrice: null, kdvRate: 10, sellerRelationship: "reseller",
      stock: 50, isActive: false, moderationStatus: "pending_review",
      weightKg: 1, lengthCm: 10, widthCm: 10, heightCm: 10, fixedDesi: 2,
    });
  return productId;
}

let activePolicyVersionId = null;

/// The policy pointer is a SINGLETON document. Re-seeding it per product
/// would rotate the active version and invalidate every decision already
/// written for earlier products, so it is seeded once per run.
async function seedPolicy() {
  if (activePolicyVersionId) return;
  const versionId = nextId("bl-policy");
  activePolicyVersionId = versionId;
  created.policies.push(versionId);
  await db.collection("compliancePolicyRegistry").doc(versionId).set(
    buildRevision30PolicyVersion({
      createdBy: "emulator-test-fixture",
      effectiveFrom: admin.firestore.Timestamp.fromMillis(Date.now() - 86400000),
      createdAt: admin.firestore.Timestamp.fromMillis(Date.now() - 86400000),
      changeNote: "SYNTHETIC emulator-only Revision 30 §D transcription",
      status: COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE,
    })
  );
  await db.collection("compliancePolicyRegistryPointer").doc("current")
    .set({ activeVersionId: versionId });
}

async function seedEvidence(businessId, productId) {
  await seedPolicy();
  const generationId = (await db.collection("businesses").doc(businessId).get())
    .data().marketplaceBusinessGenerationId;
  const documentId = nextId("bl-doc");
  const scopeId = nextId("bl-scope");
  created.documents.push(documentId);
  created.scopes.push(scopeId);
  const validUntil = admin.firestore.Timestamp.fromMillis(Date.now() + 365 * 86400000);
  await db.collection("complianceDocuments").doc(documentId).set({
    businessId, marketplaceBusinessGenerationId: generationId,
    documentType: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE,
    sellerRelationship: "reseller",
    status: COMPLIANCE_DOCUMENT_STATUS.APPROVED,
    validUntil, contentHash: `hash-${documentId}`,
    storagePath: `compliance_docs/${businessId}/${documentId}/o.pdf`,
  });
  await db.collection("complianceDocumentScopes").doc(scopeId).set({
    businessId, documentId, sellerRelationship: "reseller",
    documentType: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE,
    scopeType: COMPLIANCE_SCOPE_TYPE.PRODUCT, scopeValue: productId,
    status: COMPLIANCE_SCOPE_STATUS.APPROVED,
    approvedAt: admin.firestore.Timestamp.fromMillis(Date.now() - 86400000),
    validUntil,
  });
}

const productRef = (b, p) =>
  db.collection("businesses").doc(b).collection("products").doc(p);
const getProduct = async (b, p) => (await productRef(b, p).get()).data();

async function seedDecision(businessId, productId) {
  const product = await getProduct(businessId, productId);
  const policyId = (
    await db.collection("compliancePolicyRegistryPointer").doc("current").get()
  ).data().activeVersionId;
  const epochSnap = await db.collection("businessComplianceEpochs").doc(businessId).get();
  const epoch = epochSnap.exists && typeof epochSnap.data().epoch === "number"
    ? epochSnap.data().epoch : 0;
  const validUntil = admin.firestore.Timestamp.fromMillis(Date.now() + 365 * 86400000);
  const content = {
    businessId, policyVersion: policyId, evidenceRevision: epoch,
    productInputRevisionSnapshot:
      typeof product.productInputRevision === "number" ? product.productInputRevision : 0,
    sellerRelationshipSnapshot: product.sellerRelationship,
    pilotProductClassSnapshot: isValidPilotProductClass(product.pilotProductClass)
      ? product.pilotProductClass : null,
    requiredEvidenceSlots: [], satisfiedEvidenceSlots: [],
    activeEvidenceRefs: [{
      documentId: `doc-${productId}`, scopeId: `scope-${productId}`, expiresAt: validUntil,
    }],
    validUntil, effectiveStatus: "verified_valid",
  };
  created.decisions.push(productId);
  await db.collection("productComplianceDecisions").doc(productId).set({
    ...content, decisionHash: computeDecisionHash(content),
  });
}

async function publishable(adminUid, businessId) {
  const productId = await seedProduct(businessId);
  await seedEvidence(businessId, productId);
  await functions.setPilotProductClassification.run({
    auth: { uid: adminUid },
    data: {
      businessId, productId,
      pilotProductClass: "collars_harnesses_leashes",
      reason: "ordinary accessory",
    },
  });
  await seedDecision(businessId, productId);
  const product = await getProduct(businessId, productId);
  const dec = await db.collection("productComplianceDecisions").doc(productId).get();
  await functions.approvePilotProduct.run({
    auth: { uid: adminUid },
    data: {
      businessId, productId, allowedPilotCategory: "collars_leads",
      reviewedContentFingerprint: computeApprovalFingerprint(
        product, dec.exists ? dec.data() : null, productId
      ),
      attestNoProhibitedClaim: true,
    },
  });
  return productId;
}

function checkoutRequest(buyerUid, items) {
  return {
    auth: { uid: buyerUid },
    data: {
      buyer: { name: "A", surname: "B", email: "a@b.test", phone: "5550000000" },
      billing: {
        invoiceType: "individual", identityNumber: "11111111111",
        name: "A", surname: "B",
      },
      delivery: {
        city: "Istanbul", district: "X", address: "Y",
        fullName: "A B", phone: "5550000000",
      },
      payment: {}, legal: {}, carrier: "YURTICI", currency: "TRY",
      items,
    },
  };
}

async function assertNoSideEffect(buyerUid) {
  const orders = await db.collection("orders").where("buyerUid", "==", buyerUid).get();
  assert.equal(orders.size, 0, "a rejected basket must create no order");
  const sellerOrders = await db.collection("sellerOrders")
    .where("buyerUid", "==", buyerUid).get();
  assert.equal(sellerOrders.size, 0, "a rejected basket must create no seller order");
  const attempts = await db.collection("marketplaceCheckoutAttempts").get();
  for (const doc of attempts.docs) {
    assert.notEqual(doc.data().buyerUid, buyerUid, "no attempt record may be created");
  }
}

after(async () => {
  if (!hasEmulator) return;
  await Promise.allSettled([
    ...created.products.map(({ businessId, productId }) =>
      productRef(businessId, productId).delete()),
    ...created.businesses.map((id) => db.collection("businesses").doc(id).delete()),
    ...created.businesses.map((id) =>
      db.collection("businessComplianceEpochs").doc(id).delete()),
    ...created.businesses.map((id) => db.collection("shipping_configs").doc(id).delete()),
    ...created.decisions.map((id) =>
      db.collection("productComplianceDecisions").doc(id).delete()),
    ...created.admins.map((id) => db.collection("users").doc(id).delete()),
    ...created.policies.map((id) =>
      db.collection("compliancePolicyRegistry").doc(id).delete()),
    ...created.documents.map((id) => db.collection("complianceDocuments").doc(id).delete()),
    ...created.scopes.map((id) => db.collection("complianceDocumentScopes").doc(id).delete()),
    ...created.orders.map((id) => db.collection("orders").doc(id).delete()),
    ...created.sellerOrders.map((id) => db.collection("sellerOrders").doc(id).delete()),
  ]);
});

itest("E2E/18-20. an oversized basket is rejected with no order or side effect", async () => {
  const buyerUid = nextId("bl-buyer-over");
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);

  const tooMany = Array.from(
    { length: BASKET_LIMITS.MAX_SUBMITTED_LINES + 1 },
    (_, i) => line(businessId, `${productId}-${i}`)
  );
  await assert.rejects(
    () => functions.createMarketplaceOrderV2.run(checkoutRequest(buyerUid, tooMany)),
    (e) =>
      e.code === "invalid-argument" &&
      e.details.reasonCode === BASKET_REJECTION.TOO_MANY_LINES
  );
  await assertNoSideEffect(buyerUid);
});

itest("E2E. rejection happens BEFORE any product read", async () => {
  // The oversized basket names products that do not exist. If validation ran
  // after the reads, the failure would be "Product not found" instead.
  const buyerUid = nextId("bl-buyer-early");
  const tooMany = Array.from(
    { length: BASKET_LIMITS.MAX_SUBMITTED_LINES + 1 },
    (_, i) => line("no-such-business", `no-such-product-${i}`)
  );
  await assert.rejects(
    () => functions.createMarketplaceOrderV2.run(checkoutRequest(buyerUid, tooMany)),
    (e) => e.details.reasonCode === BASKET_REJECTION.TOO_MANY_LINES,
    "the bound must be enforced before any lookup"
  );
});

itest("E2E/13/15. a multi-line, multi-business in-bounds basket still checks out", async () => {
  const adminUid = await seedAdmin();
  const buyerUid = nextId("bl-buyer-ok");

  // One product per business. `setPilotProductClassification` bumps the
  // BUSINESS compliance epoch, which invalidates decisions already written
  // for other products of the same business — so a multi-product basket
  // within one business would need all classifications to precede all
  // decisions. Using separate businesses avoids that ordering entirely and
  // exercises the multi-business path at the same time.
  const shops = [];
  for (let i = 0; i < 3; i += 1) {
    const businessId = await seedBusiness();
    shops.push({ businessId, productId: await publishable(adminUid, businessId) });
  }
  assert.ok(shops.length <= BASKET_LIMITS.MAX_BUSINESSES);
  const items = shops.map((s) => line(s.businessId, s.productId, 2));

  const result = await functions.createMarketplaceOrderV2.run(
    checkoutRequest(buyerUid, items)
  );
  assert.ok(result.orderId, "an in-bounds basket must check out");
  created.orders.push(result.orderId);
  const order = (await db.collection("orders").doc(result.orderId).get()).data();
  created.sellerOrders.push(...(order.sellerOrderIds || []));

  // One seller-order projection per business, with unambiguous ownership.
  assert.equal(order.sellerCount, shops.length);
  assert.equal((order.sellerOrderIds || []).length, shops.length);
  // Server-derived totals, unchanged by this slice.
  assert.equal(order.pricing.currency, "TRY");
  assert.ok(order.pricing.grandTotal > 0);
});

itest("E2E/22. one ineligible product still rejects an in-bounds basket", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const buyerUid = nextId("bl-buyer-inelig");

  const good = await publishable(adminUid, businessId);
  const bad = await seedProduct(businessId); // never classified or approved

  await assert.rejects(
    () => functions.createMarketplaceOrderV2.run(
      checkoutRequest(buyerUid, [line(businessId, good), line(businessId, bad)])
    ),
    (e) => e.code === "failed-precondition",
    "bounding the basket must not weaken eligibility"
  );
  await assertNoSideEffect(buyerUid);
});

itest("E2E/12. duplicate lines merge into one order line", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const buyerUid = nextId("bl-buyer-dup");
  const productId = await publishable(adminUid, businessId);

  const result = await functions.createMarketplaceOrderV2.run(
    checkoutRequest(buyerUid, [
      line(businessId, productId, 2),
      line(businessId, productId, 3),
    ])
  );
  created.orders.push(result.orderId);
  const order = (await db.collection("orders").doc(result.orderId).get()).data();
  created.sellerOrders.push(...(order.sellerOrderIds || []));

  const sellerOrder = (
    await db.collection("sellerOrders").doc(order.sellerOrderIds[0]).get()
  ).data();
  const matching = (sellerOrder.items || []).filter((i) => i.productId === productId);
  assert.equal(matching.length, 1, "duplicates must produce exactly one order line");
  assert.equal(matching[0].quantity, 5, "quantities must be summed");
});

itest("E2E/24. an old client sending a fractional quantity gets a stable rejection", async () => {
  // Previously `Math.max(1, Math.floor(...))` silently turned this into 1.
  const buyerUid = nextId("bl-buyer-frac");
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  await assert.rejects(
    () => functions.createMarketplaceOrderV2.run(
      checkoutRequest(buyerUid, [line(businessId, productId, 0.5)])
    ),
    (e) =>
      e.code === "invalid-argument" &&
      e.details.reasonCode === BASKET_REJECTION.QUANTITY_INVALID
  );
  await assertNoSideEffect(buyerUid);
});

itest("E2E/25. concurrent at-limit requests stay bounded and isolated", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await publishable(adminUid, businessId);

  const buyers = [nextId("bl-c1"), nextId("bl-c2"), nextId("bl-c3")];
  const results = await Promise.all(
    buyers.map((uid) =>
      functions.createMarketplaceOrderV2.run(
        checkoutRequest(uid, [line(businessId, productId, 2)])
      )
    )
  );
  const orderIds = new Set(results.map((r) => r.orderId));
  assert.equal(orderIds.size, buyers.length, "each buyer gets its own order");
  for (const r of results) {
    created.orders.push(r.orderId);
    const order = (await db.collection("orders").doc(r.orderId).get()).data();
    created.sellerOrders.push(...(order.sellerOrderIds || []));
    assert.ok(buyers.includes(order.buyerUid), "orders must not cross buyers");
  }
});
