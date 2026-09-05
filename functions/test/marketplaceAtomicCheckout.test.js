"use strict";

// Marketplace Revision 44 §0.42 (Slice 7E) — behavioural coverage for the
// atomic checkout acceptance boundary.
//
// Everything here drives REAL production code against a real Firestore
// emulator: `assertCheckoutItemsAcceptable` (the transactional gate) with the
// real `assessProductVisibility`/`evaluateLiveProductEligibility` behind it,
// and the exported `createMarketplaceOrderV2` callable end to end.
//
// The invariant under test: an order is accepted only if every item passes
// the canonical live eligibility predicate AT ACCEPTANCE TIME, inside the
// same transaction that writes the order — so state that changed after
// discovery, hydration, cart addition or a previous attempt cannot be sold.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test, after } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();
const functions = require("../index");

const {
  assertCheckoutItemsAcceptable,
  CHECKOUT_REJECTION,
} = require("../src/marketplace/orders/atomicCheckoutGuard");
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
const {
  assessProductVisibility,
} = require("../src/marketplace/publicCatalog/marketplaceProductVisibility");

const hasEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function itest(name, fn) {
  test(name, { skip: !hasEmulator }, fn);
}

const RUN = Math.random().toString(36).slice(2, 10);
let seq = 0;
const nextId = (p) => `${p}-${RUN}-${(seq += 1)}`;

const createdBusinesses = [];
const createdProducts = [];
const createdDecisions = [];
const createdAdmins = [];
const createdPolicies = [];
const createdDocuments = [];
const createdScopes = [];
const createdOrders = [];
const createdSellerOrders = [];

// ---------------------------------------------------------------------
// Fixtures — production-shaped, driven through the real callables so a
// "publishable" product is genuinely publishable.
// ---------------------------------------------------------------------

async function seedAdmin() {
  const id = nextId("ac-admin");
  createdAdmins.push(id);
  await db.collection("users").doc(id).set({ role: "admin" });
  return id;
}

async function seedBusiness(overrides = {}) {
  const businessId = nextId("ac-biz");
  createdBusinesses.push(businessId);
  await db.collection("businesses").doc(businessId).set({
    ownerUid: `owner-${businessId}`,
    status: "approved",
    marketplaceSellerActivation: { active: true },
    marketplaceBusinessGenerationId: `gen-${businessId}`,
    pilotActiveProductCount: 0,
    ...overrides,
  });
  return businessId;
}

async function seedProduct(businessId, overrides = {}) {
  const productId = overrides.productId || nextId("ac-prod");
  delete overrides.productId;
  createdProducts.push({ businessId, productId });
  const biz = (await db.collection("businesses").doc(businessId).get()).data();
  await db
    .collection("businesses").doc(businessId)
    .collection("products").doc(productId)
    .set({
      businessId,
      marketplaceBusinessGenerationId: biz.marketplaceBusinessGenerationId,
      name: "Chest harness",
      description: "Ordinary accessory.",
      price: 100,
      currency: "TRY",
      media: [{ type: "image", originalUrl: "https://example.test/1.jpg" }],
      category: "Accessories > Harness",
      brand: "Acme",
      salePrice: null,
      kdvRate: 10,
      sellerRelationship: "reseller",
      stock: 5,
      isActive: false,
      moderationStatus: "pending_review",
      ...overrides,
    });
  return productId;
}

async function seedActivePolicy() {
  const versionId = nextId("ac-policy");
  createdPolicies.push(versionId);
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
  return versionId;
}

async function seedRelationshipEvidence(businessId, productId) {
  await seedActivePolicy();
  const generationId = (await db.collection("businesses").doc(businessId).get())
    .data().marketplaceBusinessGenerationId;
  const documentId = nextId("ac-doc");
  createdDocuments.push(documentId);
  const validUntil = admin.firestore.Timestamp.fromMillis(Date.now() + 365 * 86400000);
  await db.collection("complianceDocuments").doc(documentId).set({
    businessId,
    marketplaceBusinessGenerationId: generationId,
    documentType: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE,
    sellerRelationship: "reseller",
    status: COMPLIANCE_DOCUMENT_STATUS.APPROVED,
    validUntil,
    contentHash: `hash-${documentId}`,
    storagePath: `compliance_docs/${businessId}/${documentId}/o.pdf`,
  });
  const scopeId = nextId("ac-scope");
  createdScopes.push(scopeId);
  await db.collection("complianceDocumentScopes").doc(scopeId).set({
    businessId,
    documentId,
    sellerRelationship: "reseller",
    documentType: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE,
    scopeType: COMPLIANCE_SCOPE_TYPE.PRODUCT,
    scopeValue: productId,
    status: COMPLIANCE_SCOPE_STATUS.APPROVED,
    approvedAt: admin.firestore.Timestamp.fromMillis(Date.now() - 86400000),
    validUntil,
  });
}

const productRef = (b, p) =>
  db.collection("businesses").doc(b).collection("products").doc(p);
const getProduct = async (b, p) => (await productRef(b, p).get()).data();

async function seedEligibleDecision(businessId, productId) {
  const product = await getProduct(businessId, productId);
  const policyId = (
    await db.collection("compliancePolicyRegistryPointer").doc("current").get()
  ).data().activeVersionId;
  const epochSnap = await db.collection("businessComplianceEpochs").doc(businessId).get();
  const epoch = epochSnap.exists && typeof epochSnap.data().epoch === "number"
    ? epochSnap.data().epoch : 0;
  const validUntil = admin.firestore.Timestamp.fromMillis(Date.now() + 365 * 86400000);
  const content = {
    businessId,
    policyVersion: policyId,
    evidenceRevision: epoch,
    productInputRevisionSnapshot:
      typeof product.productInputRevision === "number" ? product.productInputRevision : 0,
    sellerRelationshipSnapshot: product.sellerRelationship,
    pilotProductClassSnapshot: isValidPilotProductClass(product.pilotProductClass)
      ? product.pilotProductClass : null,
    requiredEvidenceSlots: [],
    satisfiedEvidenceSlots: [],
    activeEvidenceRefs: [{
      documentId: `doc-${productId}`,
      scopeId: `scope-${productId}`,
      expiresAt: validUntil,
    }],
    validUntil,
    effectiveStatus: "verified_valid",
  };
  createdDecisions.push(productId);
  await db.collection("productComplianceDecisions").doc(productId).set({
    ...content,
    decisionHash: computeDecisionHash(content),
  });
}

const callClassify = (args) =>
  functions.setPilotProductClassification.run({
    auth: { uid: args.uid }, data: args.data,
  });
const callApprove = (args) =>
  functions.approvePilotProduct.run({ auth: { uid: args.uid }, data: args.data });

async function approvalPayloadFor(businessId, productId, allowedPilotCategory) {
  const product = await getProduct(businessId, productId);
  const dec = await db.collection("productComplianceDecisions").doc(productId).get();
  return {
    businessId, productId, allowedPilotCategory,
    reviewedContentFingerprint: computeApprovalFingerprint(
      product, dec.exists ? dec.data() : null, productId
    ),
    attestNoProhibitedClaim: true,
  };
}

/// Produces a genuinely publishable product through the real callables.
async function publishableProduct(adminUid, overrides = {}) {
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, overrides);
  await seedRelationshipEvidence(businessId, productId);
  await callClassify({
    uid: adminUid,
    data: {
      businessId, productId,
      pilotProductClass: "collars_harnesses_leashes",
      reason: "ordinary accessory",
    },
  });
  await seedEligibleDecision(businessId, productId);
  await callApprove({
    uid: adminUid,
    data: await approvalPayloadFor(businessId, productId, "collars_leads"),
  });
  return { businessId, productId };
}

/// Runs the acceptance gate exactly as production does: inside a real
/// transaction, with the real visibility predicate.
function acceptInTransaction(items, currency = "TRY") {
  return db.runTransaction((tx) =>
    assertCheckoutItemsAcceptable({ db, tx, items, currency })
  );
}

const line = (businessId, productId, unitPrice = 100) => ({
  businessId, productId, quantity: 1, unitPrice,
});

// This suite seeds businesses, products, policies, evidence and orders. The
// inventory coordinator suite asserts ABSOLUTE collection sizes, so anything
// left behind breaks it under a shared emulator. Everything created here is
// tracked and removed.
after(async () => {
  if (!hasEmulator) return;
  const deletions = [
    ...createdProducts.map(({ businessId, productId }) =>
      productRef(businessId, productId).delete()),
    ...createdBusinesses.map((id) => db.collection("businesses").doc(id).delete()),
    ...createdBusinesses.map((id) =>
      db.collection("businessComplianceEpochs").doc(id).delete()),
    ...createdBusinesses.map((id) =>
      db.collection("shipping_configs").doc(id).delete()),
    ...createdDecisions.map((id) =>
      db.collection("productComplianceDecisions").doc(id).delete()),
    ...createdAdmins.map((id) => db.collection("users").doc(id).delete()),
    ...createdPolicies.map((id) =>
      db.collection("compliancePolicyRegistry").doc(id).delete()),
    ...createdDocuments.map((id) =>
      db.collection("complianceDocuments").doc(id).delete()),
    ...createdScopes.map((id) =>
      db.collection("complianceDocumentScopes").doc(id).delete()),
    ...createdOrders.map((id) => db.collection("orders").doc(id).delete()),
    ...createdSellerOrders.map((id) =>
      db.collection("sellerOrders").doc(id).delete()),
  ];
  await Promise.allSettled(deletions);
});

// =====================================================================
// 1 — the authorized path genuinely works (guards against a vacuous suite)
// =====================================================================

itest("1. a fully eligible product is accepted by the transactional gate", async () => {
  const adminUid = await seedAdmin();
  const { businessId, productId } = await publishableProduct(adminUid);
  // Sanity: the public predicate agrees it is visible.
  const seen = await assessProductVisibility({ db, businessId, productId });
  assert.equal(seen.visible, true, "fixture must be genuinely publishable");

  const accepted = await acceptInTransaction([line(businessId, productId)]);
  assert.equal(accepted.length, 1);
  assert.equal(accepted[0].productId, productId);
  assert.equal(accepted[0].unitPrice, 100);
  assert.equal(accepted[0].currency, "TRY");
  // The generation is captured from the transactionally-read product.
  assert.ok(accepted[0].marketplaceBusinessGenerationId);
  assert.equal(accepted[0].pilotProductClass, "collars_harnesses_leashes");
});

// =====================================================================
// 2-10, 34 — every ineligibility class is refused AT ACCEPTANCE
// =====================================================================

itest("2/3/4. unpublished, unclassified and unknown-class products are refused", async () => {
  const adminUid = await seedAdmin();

  // Unpublished: never approved, so isActive stays false.
  const b1 = await seedBusiness();
  const p1 = await seedProduct(b1, { moderationStatus: "approved" });
  await assert.rejects(
    () => acceptInTransaction([line(b1, p1)]),
    (e) => e.code === "failed-precondition"
      && e.details.reasonCode === CHECKOUT_REJECTION.ITEM_UNAVAILABLE
  );

  // Classified-looking but with no valid class value.
  const b2 = await seedBusiness();
  const p2 = await seedProduct(b2, {
    isActive: true, moderationStatus: "approved",
  });
  await assert.rejects(() => acceptInTransaction([line(b2, p2)]),
    (e) => e.details.reasonCode === CHECKOUT_REJECTION.ITEM_UNAVAILABLE);

  // Unknown / legacy class fails closed.
  for (const bogus of ["collars_leads", "vitamins", "SEALED_DRY_FOOD", "", null]) {
    const b = await seedBusiness();
    const p = await seedProduct(b, {
      isActive: true, moderationStatus: "approved", pilotProductClass: bogus,
      pilotProductApproval: { active: true },
    });
    await assert.rejects(() => acceptInTransaction([line(b, p)]),
      (e) => e.details.reasonCode === CHECKOUT_REJECTION.ITEM_UNAVAILABLE,
      `${String(bogus)} must be refused`);
  }
  assert.ok(adminUid);
});

itest("5/6/7. missing, stale or invalid Decision and Approval are refused", async () => {
  const adminUid = await seedAdmin();

  // No decision at all: never approvable, so never acceptable.
  const { businessId, productId } = await publishableProduct(adminUid);
  await db.collection("productComplianceDecisions").doc(productId).delete();
  await assert.rejects(() => acceptInTransaction([line(businessId, productId)]),
    (e) => e.details.reasonCode === CHECKOUT_REJECTION.ITEM_UNAVAILABLE,
    "a deleted decision must refuse acceptance");

  // A tampered decisionHash is refused by the evaluator's recomputation.
  const second = await publishableProduct(adminUid);
  await db.collection("productComplianceDecisions").doc(second.productId)
    .set({ decisionHash: "tampered" }, { merge: true });
  await assert.rejects(
    () => acceptInTransaction([line(second.businessId, second.productId)]),
    (e) => e.details.reasonCode === CHECKOUT_REJECTION.ITEM_UNAVAILABLE);

  // An expired decision is refused.
  const third = await publishableProduct(adminUid);
  await db.collection("productComplianceDecisions").doc(third.productId).set(
    { validUntil: admin.firestore.Timestamp.fromMillis(Date.now() - 1000) },
    { merge: true }
  );
  await assert.rejects(
    () => acceptInTransaction([line(third.businessId, third.productId)]),
    (e) => e.details.reasonCode === CHECKOUT_REJECTION.ITEM_UNAVAILABLE);
});

itest("9. a rotated Business generation refuses acceptance", async () => {
  const adminUid = await seedAdmin();
  const { businessId, productId } = await publishableProduct(adminUid);
  await db.collection("businesses").doc(businessId).set(
    { marketplaceBusinessGenerationId: "rotated-generation" }, { merge: true }
  );
  await assert.rejects(() => acceptInTransaction([line(businessId, productId)]),
    (e) => e.details.reasonCode === CHECKOUT_REJECTION.ITEM_UNAVAILABLE);
});

itest("10. a deactivated or unpublishable Business refuses acceptance", async () => {
  const adminUid = await seedAdmin();

  const a = await publishableProduct(adminUid);
  await db.collection("businesses").doc(a.businessId).set(
    { marketplaceSellerActivation: { active: false } }, { merge: true });
  await assert.rejects(() => acceptInTransaction([line(a.businessId, a.productId)]),
    (e) => e.details.reasonCode === CHECKOUT_REJECTION.ITEM_UNAVAILABLE,
    "a deactivated seller must not sell");

  const b = await publishableProduct(adminUid);
  await db.collection("businesses").doc(b.businessId).set(
    { status: "suspended" }, { merge: true });
  await assert.rejects(() => acceptInTransaction([line(b.businessId, b.productId)]),
    (e) => e.details.reasonCode === CHECKOUT_REJECTION.ITEM_UNAVAILABLE);
});

itest("8/11/34. a product that becomes ineligible AFTER discovery is refused at acceptance", async () => {
  const adminUid = await seedAdmin();
  const { businessId, productId } = await publishableProduct(adminUid);

  // Discovery-time: visible.
  assert.equal(
    (await assessProductVisibility({ db, businessId, productId })).visible,
    true
  );
  const cartLine = line(businessId, productId);

  // Between discovery and checkout the admin reclassifies it, which
  // unpublishes it and invalidates the approval binding.
  await callClassify({
    uid: adminUid,
    data: {
      businessId, productId,
      pilotProductClass: "pet_apparel", reason: "corrected",
    },
  });

  await assert.rejects(
    () => acceptInTransaction([cartLine]),
    (e) => e.details.reasonCode === CHECKOUT_REJECTION.ITEM_UNAVAILABLE,
    "stale cart eligibility must not be honoured"
  );
});

// =====================================================================
// 12/13/14 — client-supplied commercial values are not authority
// =====================================================================

itest("12/13. a client-offered price that disagrees with the product is refused", async () => {
  const adminUid = await seedAdmin();
  const { businessId, productId } = await publishableProduct(adminUid);

  for (const tampered of [1, 0.01, 99.99, 1000000]) {
    await assert.rejects(
      () => acceptInTransaction([line(businessId, productId, tampered)]),
      (e) => e.details.reasonCode === CHECKOUT_REJECTION.PRICE_CHANGED,
      `offered ${tampered} must not be accepted`
    );
  }
  // Only the authoritative price is accepted, and it is the value returned.
  const accepted = await acceptInTransaction([line(businessId, productId, 100)]);
  assert.equal(accepted[0].unitPrice, 100);
});

itest("12b. a price change between discovery and acceptance is refused, never silently repriced", async () => {
  const adminUid = await seedAdmin();
  const { businessId, productId } = await publishableProduct(adminUid);
  const shownLine = line(businessId, productId, 100);

  await productRef(businessId, productId).set({ price: 250 }, { merge: true });

  await assert.rejects(
    () => acceptInTransaction([shownLine]),
    (e) => e.details.reasonCode === CHECKOUT_REJECTION.PRICE_CHANGED,
    "the customer must never be charged a price they were not shown"
  );
});

itest("14. a spoofed Seller/Business cannot carry a product into acceptance", async () => {
  const adminUid = await seedAdmin();
  const victim = await publishableProduct(adminUid);
  const attacker = await seedBusiness();

  // The attacker names their own business with the victim's productId.
  await assert.rejects(
    () => acceptInTransaction([line(attacker, victim.productId)]),
    (e) => e.details.reasonCode === CHECKOUT_REJECTION.ITEM_UNAVAILABLE,
    "a product must not be reachable under another business"
  );
});

itest("23. a currency that disagrees with the product is refused", async () => {
  const adminUid = await seedAdmin();
  const { businessId, productId } = await publishableProduct(adminUid);
  await assert.rejects(
    () => acceptInTransaction([line(businessId, productId)], "USD"),
    (e) => e.details.reasonCode === CHECKOUT_REJECTION.CURRENCY_MISMATCH
  );
});

// =====================================================================
// 36/37 — all-or-nothing acceptance
// =====================================================================

itest("36. one ineligible item refuses the WHOLE basket — no partial acceptance", async () => {
  const adminUid = await seedAdmin();
  const good = await publishableProduct(adminUid);
  const badBiz = await seedBusiness();
  const badProd = await seedProduct(badBiz, {
    isActive: true, moderationStatus: "approved",
  });

  await assert.rejects(
    () => acceptInTransaction([
      line(good.businessId, good.productId),
      line(badBiz, badProd),
    ]),
    (e) => e.details.reasonCode === CHECKOUT_REJECTION.ITEM_UNAVAILABLE
  );
});

itest("14b. defence in depth: a mismatched business on an otherwise-visible product is refused", async () => {
  // `assessProductVisibility` already rejects a product whose stored
  // businessId disagrees with the addressed one, so this branch is not
  // reachable through the real predicate today. It exists so that a future
  // change to the predicate cannot silently make checkout accept a product
  // under the wrong seller — and it is exercised here through the module's
  // own assessor seam rather than left as untested dead code.
  const rogueAssessor = async () => ({
    visible: true,
    reason: null,
    product: {
      businessId: "a-different-business",
      price: 100,
      currency: "TRY",
      marketplaceBusinessGenerationId: "g",
      pilotProductClass: "collars_harnesses_leashes",
    },
    business: {},
  });

  await assert.rejects(
    () =>
      db.runTransaction((tx) =>
        assertCheckoutItemsAcceptable({
          db,
          tx,
          items: [line("addressed-business", "p1")],
          currency: "TRY",
          visibilityAssessor: rogueAssessor,
        })
      ),
    (e) => e.details.reasonCode === CHECKOUT_REJECTION.BUSINESS_MISMATCH,
    "an ownership disagreement must refuse acceptance"
  );
});

itest("14c. defence in depth: a visible product with no usable price is refused", async () => {
  const pricelessAssessor = async () => ({
    visible: true,
    reason: null,
    product: {
      businessId: "b1",
      price: 0,
      salePrice: null,
      currency: "TRY",
    },
    business: {},
  });
  await assert.rejects(
    () =>
      db.runTransaction((tx) =>
        assertCheckoutItemsAcceptable({
          db,
          tx,
          items: [line("b1", "p1")],
          currency: "TRY",
          visibilityAssessor: pricelessAssessor,
        })
      ),
    (e) => e.details.reasonCode === CHECKOUT_REJECTION.ITEM_UNAVAILABLE
  );
});

// =====================================================================
// End-to-end through the real callable — the defect this slice closes
// =====================================================================

async function seedShippingConfig(businessId) {
  // Unrelated to eligibility; it only lets the line be priced so the
  // request reaches the acceptance question.
  await db.collection("shipping_configs").doc(businessId).set({
    basePrice: 20, pricePerKg: 5, pricePerDesi: 5,
  });
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

const shippable = {
  weightKg: 1, lengthCm: 10, widthCm: 10, heightCm: 10, fixedDesi: 2,
};

itest("E2E/37. createMarketplaceOrderV2 REFUSES an ineligible product and writes no order", async () => {
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, shippable);
  await seedShippingConfig(businessId);
  const buyerUid = nextId("ac-buyer");

  // The canonical predicate refuses it (no class, no approval, no decision).
  assert.equal(
    (await assessProductVisibility({ db, businessId, productId })).visible,
    false
  );

  await assert.rejects(
    () => functions.createMarketplaceOrderV2.run(
      checkoutRequest(buyerUid, [{ shopId: businessId, productId, quantity: 1 }])
    ),
    (e) => e.code === "failed-precondition",
    "checkout must refuse an ineligible product"
  );

  // And NO order exists for this buyer — no stock effect, no order tree.
  const orders = await db.collection("orders")
    .where("buyerUid", "==", buyerUid).get();
  assert.equal(orders.size, 0, "no order may be created for a refused basket");
  const sellerOrders = await db.collection("sellerOrders")
    .where("buyerUid", "==", buyerUid).get();
  assert.equal(sellerOrders.size, 0, "no seller projection may be created either");
});

itest("E2E/1. createMarketplaceOrderV2 ACCEPTS a genuinely eligible product", async () => {
  // The positive path, so the refusal above is not passing vacuously.
  const adminUid = await seedAdmin();
  const { businessId, productId } = await publishableProduct(adminUid, shippable);
  await seedShippingConfig(businessId);
  const buyerUid = nextId("ac-buyer-ok");

  const result = await functions.createMarketplaceOrderV2.run(
    checkoutRequest(buyerUid, [{ shopId: businessId, productId, quantity: 1 }])
  );
  assert.ok(result && result.orderId, "an eligible basket must produce an order");
  createdOrders.push(result.orderId);

  const order = (await db.collection("orders").doc(result.orderId).get()).data();
  assert.ok(order, "the canonical order document must exist");
  assert.equal(order.buyerUid, buyerUid);
  assert.equal(order.pricing.currency, "TRY");
  assert.equal(order.sellerCount, 1);
  // The product's stored price is KDV-inclusive; the order splits it into a
  // net subtotal plus tax, so the line's gross value is what must equal the
  // authoritative unit price.
  assert.equal(
    Number((order.pricing.subtotal + order.pricing.taxTotal).toFixed(2)),
    100,
    "the line total must be derived from the authoritative product price"
  );
  assert.ok(order.pricing.grandTotal > 100, "shipping is added on top");

  await db.collection("orders").doc(result.orderId).delete();
  for (const id of order.sellerOrderIds || []) {
    await db.collection("sellerOrders").doc(id).delete();
  }
});

itest("E2E/12. a client-supplied price in the request cannot change the stored total", async () => {
  const adminUid = await seedAdmin();
  const { businessId, productId } = await publishableProduct(adminUid, shippable);
  await seedShippingConfig(businessId);
  const buyerUid = nextId("ac-buyer-tamper");

  // Two identical checkouts, one carrying tampered commercial values. The
  // stored pricing must be byte-identical: the client's numbers are ignored
  // rather than merely bounded.
  const clean = await functions.createMarketplaceOrderV2.run(
    checkoutRequest(buyerUid, [{ shopId: businessId, productId, quantity: 1 }])
  );
  createdOrders.push(clean.orderId);
  const tampered = await functions.createMarketplaceOrderV2.run(
    checkoutRequest(`${buyerUid}-2`, [{
      shopId: businessId, productId, quantity: 1,
      price: 1, unitPrice: 1, total: 1, grandTotal: 1, subtotal: 1,
      kdvRate: 0, currency: "USD", businessId: "attacker-biz",
    }])
  );
  createdOrders.push(tampered.orderId);

  const cleanOrder = (await db.collection("orders").doc(clean.orderId).get()).data();
  const tamperedOrder =
    (await db.collection("orders").doc(tampered.orderId).get()).data();

  assert.deepEqual(
    tamperedOrder.pricing,
    cleanOrder.pricing,
    "tampered client values must not change a single stored figure"
  );
  assert.notEqual(tamperedOrder.pricing.grandTotal, 1);
  assert.equal(tamperedOrder.pricing.currency, "TRY");

  for (const [id, order] of [[clean.orderId, cleanOrder], [tampered.orderId, tamperedOrder]]) {
    await db.collection("orders").doc(id).delete();
    for (const sid of order.sellerOrderIds || []) {
      await db.collection("sellerOrders").doc(sid).delete();
    }
  }
});

itest("the gate refuses to run outside a transaction", async () => {
  // A caller that forgot the transaction would reintroduce the exact TOCTOU
  // defect this module closes, so it is a hard error rather than a warning.
  await assert.rejects(
    () => assertCheckoutItemsAcceptable({
      db, tx: null, items: [line("b", "p")], currency: "TRY",
    }),
    /tx is required/
  );
});

itest("refusals never disclose why a product is compliance-ineligible", async () => {
  const adminUid = await seedAdmin();
  const { businessId, productId } = await publishableProduct(adminUid);
  await db.collection("productComplianceDecisions").doc(productId).delete();
  try {
    await acceptInTransaction([line(businessId, productId)]);
    assert.fail("must reject");
  } catch (err) {
    const blob = `${err.message} ${JSON.stringify(err.details || {})}`;
    for (const leak of [
      "decision", "approval", "evidence", "fingerprint", "policy",
      "generation", "class", "compliance",
    ]) {
      assert.ok(
        !blob.toLowerCase().includes(leak),
        `a customer-facing refusal must not mention ${leak}: ${blob}`
      );
    }
  }
});
