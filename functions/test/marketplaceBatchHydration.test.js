"use strict";

// Marketplace Revision 39 §0.37 (Slice 7B-C1) — `getMarketplaceProductBatch`.
//
// Runs the REAL compliance engine against the Firestore emulator with
// clearly-labelled SYNTHETIC fixtures, so an "available" result is produced by
// a genuinely valid world rather than a hand-planted decision no real path
// could have written. No policy is activated in any real project.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();

const {
  getMarketplaceProductBatch,
} = require("../src/marketplace/publicCatalog/marketplaceListing");
const {
  PUBLIC_PRODUCT_FIELDS,
  PUBLIC_FORBIDDEN_FIELDS,
} = require("../src/marketplace/publicCatalog/marketplacePublicVisibility");
const {
  recomputeProductComplianceStatus,
} = require("../src/marketplace/compliance/complianceProductRecompute");
const {
  buildRevision30PolicyVersion,
} = require("../src/marketplace/compliance/complianceRevision30Policy");
const {
  SELLER_RELATIONSHIP,
  COMPLIANCE_DOCUMENT_TYPE,
  COMPLIANCE_DOCUMENT_STATUS,
  COMPLIANCE_SCOPE_TYPE,
  COMPLIANCE_SCOPE_STATUS,
  COMPLIANCE_POLICY_REGISTRY_STATUS,
  PILOT_PRODUCT_CLASS,
} = require("../src/marketplace/compliance/complianceConstants");

const hasFs = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const itest = (n, f) => test(n, { skip: !hasFs }, f);

let seq = 0;
const RUN = `bat${Math.random().toString(36).slice(2, 8)}`;
const nextId = (p) => `${p}-${RUN}-${++seq}`;
const FUTURE = () => admin.firestore.Timestamp.fromMillis(Date.now() + 365 * 86400000);
const PAST = () => admin.firestore.Timestamp.fromMillis(Date.now() - 86400000);

const prodRef = (b, p) => db.collection("businesses").doc(b).collection("products").doc(p);
const bizRef = (b) => db.collection("businesses").doc(b);
const decRef = (p) => db.collection("productComplianceDecisions").doc(p);
const epochRef = (b) => db.collection("businessComplianceEpochs").doc(b);

async function seedSyntheticActivePolicy() {
  const versionId = nextId("synthetic-policy");
  await db.collection("compliancePolicyRegistry").doc(versionId).set(
    buildRevision30PolicyVersion({
      createdBy: "emulator-test-fixture",
      effectiveFrom: PAST(),
      createdAt: PAST(),
      changeNote: "SYNTHETIC emulator-only Revision 30 §D transcription",
      status: COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE,
    })
  );
  await db.collection("compliancePolicyRegistryPointer").doc("current").set({
    activeVersionId: versionId,
  });
  return versionId;
}

/// A genuinely publicly-visible product, produced by the real engine.
async function seedVisibleProduct({ productOverrides = {}, businessOverrides = {} } = {}) {
  await seedSyntheticActivePolicy();
  const businessId = nextId("biz");
  const productId = nextId("prod");
  const generationId = `gen-${businessId}`;

  await bizRef(businessId).set({
    ownerUid: nextId("seller"),
    status: "approved",
    marketplaceSellerActivation: { active: true },
    marketplaceBusinessGenerationId: generationId,
    pilotActiveProductCount: 0,
    businessName: "ACME Pets",
    ...businessOverrides,
  });
  await prodRef(businessId, productId).set({
    businessId,
    marketplaceBusinessGenerationId: generationId,
    name: "Sealed Dry Dog Food",
    description: "Ordinary packaged dog food.",
    price: 100,
    currency: "TRY",
    media: [
      {
        type: "image",
        status: "ready",
        originalUrl: "https://cdn.example.test/a.jpg",
        thumbnailUrl: "https://cdn.example.test/t.jpg",
        storagePath: "marketplace/secret/a.jpg",
      },
    ],
    category: "Food > Dry Food",
    brand: "ACME",
    barcode: "1234567890",
    salePrice: null,
    kdvRate: 10,
    sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
    sku: "SKU-1",
    productInputRevision: 0,
    stock: 5,
    isActive: true,
    moderationStatus: "approved",
    pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD,
    ...productOverrides,
  });

  const documentId = nextId("doc");
  const validUntil = FUTURE();
  await db.collection("complianceDocuments").doc(documentId).set({
    businessId,
    marketplaceBusinessGenerationId: generationId,
    documentType: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE,
    sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
    status: COMPLIANCE_DOCUMENT_STATUS.APPROVED,
    validUntil,
    contentHash: `hash-${documentId}`,
    storagePath: `compliance_docs/${businessId}/${documentId}/o.pdf`,
  });
  await db.collection("complianceDocumentScopes").doc(nextId("scope")).set({
    businessId,
    documentId,
    sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
    documentType: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE,
    scopeType: COMPLIANCE_SCOPE_TYPE.PRODUCT,
    scopeValue: productId,
    status: COMPLIANCE_SCOPE_STATUS.APPROVED,
    approvedAt: PAST(),
    validUntil,
  });

  await recomputeProductComplianceStatus({ db, businessId, productId });
  return { businessId, productId, generationId, documentId };
}

const batch = (products) =>
  getMarketplaceProductBatch({ db, data: { products }, featureEnabled: true });

async function expectInvalid(promise) {
  let error = null;
  try {
    await promise;
  } catch (e) {
    error = e;
  }
  assert.ok(error, "expected the call to be rejected");
  assert.equal(error.code, "invalid-argument");
  return error;
}

const keyOf = (w) => ({ businessId: w.businessId, productId: w.productId });

// =====================================================================
// Request contract — items 1-6
// =====================================================================

itest("1. an empty products array returns an empty results array, not an error", async () => {
  const result = await batch([]);
  assert.deepEqual(result, { results: [] });
});

itest("2. more than 20 entries is rejected", async () => {
  const many = Array.from({ length: 21 }, (_, i) => ({
    businessId: "b",
    productId: `p${i}`,
  }));
  await expectInvalid(batch(many));
  // Exactly 20 is accepted.
  const twenty = Array.from({ length: 20 }, (_, i) => ({
    businessId: "b",
    productId: `p${i}`,
  }));
  const ok = await batch(twenty);
  assert.equal(ok.results.length, 20);
});

itest("3. duplicate canonical pairs are deduplicated for reads but still answered per position", async () => {
  const w = await seedVisibleProduct();
  const k = keyOf(w);
  const result = await batch([k, k, k]);
  assert.equal(result.results.length, 3, "one result per REQUESTED position");
  for (const r of result.results) {
    assert.equal(r.available, true);
    assert.equal(r.productId, w.productId);
  }
});

itest("4. results are returned in request order, positionally mappable", async () => {
  const a = await seedVisibleProduct();
  const b = await seedVisibleProduct();
  // Seeding B activated a new policy, staling A — recompute so both are
  // genuinely visible under the current pointer.
  await recomputeProductComplianceStatus({ db, businessId: a.businessId, productId: a.productId });

  const forward = await batch([keyOf(a), keyOf(b)]);
  assert.deepEqual(
    forward.results.map((r) => r.productId),
    [a.productId, b.productId]
  );
  const reverse = await batch([keyOf(b), keyOf(a)]);
  assert.deepEqual(
    reverse.results.map((r) => r.productId),
    [b.productId, a.productId]
  );
});

itest("5. unknown top-level or per-item keys are rejected", async () => {
  const w = await seedVisibleProduct();
  await expectInvalid(
    getMarketplaceProductBatch({
      db,
      data: { products: [keyOf(w)], pageSize: 5 },
      featureEnabled: true,
    })
  );
  await expectInvalid(batch([{ ...keyOf(w), quantity: 1 }]));
  await expectInvalid(batch([{ ...keyOf(w), available: true }]));
});

itest("6. malformed identities are rejected as a malformed REQUEST, never silently unavailable", async () => {
  for (const bad of [
    "not-an-object",
    null,
    [],
    {},
    { businessId: "b" },
    { productId: "p" },
    { businessId: "", productId: "p" },
    { businessId: "b", productId: "" },
    { businessId: 7, productId: "p" },
    { businessId: "b", productId: { nested: true } },
  ]) {
    await expectInvalid(batch([bad]));
  }
  await expectInvalid(getMarketplaceProductBatch({ db, data: { products: "nope" }, featureEnabled: true }));
  await expectInvalid(getMarketplaceProductBatch({ db, data: {}, featureEnabled: true }));
});

// =====================================================================
// Eligibility — items 7-16
// =====================================================================

itest("7. a genuinely eligible product is returned with its public projection", async () => {
  const w = await seedVisibleProduct();
  const result = await batch([keyOf(w)]);
  assert.equal(result.results.length, 1);
  const only = result.results[0];
  assert.equal(only.available, true);
  assert.equal(only.businessId, w.businessId);
  assert.equal(only.productId, w.productId);
  assert.notEqual(only.product, null);
  assert.equal(only.product.name, "Sealed Dry Dog Food");
});

const OMISSION_CASES = [
  ["8. inactive", async (w) => prodRef(w.businessId, w.productId).update({ isActive: false })],
  ["9a. pending_review", async (w) => prodRef(w.businessId, w.productId).update({ moderationStatus: "pending_review" })],
  ["9b. rejected", async (w) => prodRef(w.businessId, w.productId).update({ moderationStatus: "rejected" })],
  ["10. expired decision", async (w) => decRef(w.productId).update({ validUntil: PAST() })],
  ["11. stale decisionHash", async (w) => decRef(w.productId).update({ decisionHash: "0".repeat(64) })],
  ["12a. stale evidence revision", async (w) => epochRef(w.businessId).set({ epoch: 9 }, { merge: true })],
  ["12b. stale evidence digest", async (w) => {
    const d = (await decRef(w.productId).get()).data();
    await decRef(w.productId).update({
      activeEvidenceRefs: [
        ...d.activeEvidenceRefs,
        { documentId: nextId("planted"), scopeId: nextId("planted"), expiresAt: FUTURE() },
      ],
    });
  }],
  ["13a. unsupported class", async (w) => prodRef(w.businessId, w.productId).update({ pilotProductClass: "vitamins" })],
  ["13b. missing class", async (w) => prodRef(w.businessId, w.productId).update({ pilotProductClass: admin.firestore.FieldValue.delete() })],
  ["14. wrong generation", async (w) => prodRef(w.businessId, w.productId).update({ marketplaceBusinessGenerationId: "gen-previous" })],
  ["15. seller activation revoked", async (w) => bizRef(w.businessId).update({ marketplaceSellerActivation: { active: false } })],
  ["15b. business not approved", async (w) => bizRef(w.businessId).update({ status: "suspended" })],
  ["15c. missing decision", async (w) => decRef(w.productId).delete()],
  ["15d. product deleted", async (w) => prodRef(w.businessId, w.productId).update({ deletedAt: admin.firestore.Timestamp.now() })],
  ["15e. product missing entirely", async (w) => prodRef(w.businessId, w.productId).delete()],
];

for (const [label, mutate] of OMISSION_CASES) {
  itest(`${label} is reported unavailable with no product body`, async () => {
    const w = await seedVisibleProduct();
    assert.equal((await batch([keyOf(w)])).results[0].available, true, "fixture must start visible");
    await mutate(w);
    const result = await batch([keyOf(w)]);
    assert.equal(result.results.length, 1);
    assert.equal(result.results[0].available, false, label);
    assert.equal(result.results[0].product, null, label);
    // The key is echoed so a client can map the result, but nothing else.
    assert.deepEqual(Object.keys(result.results[0]).sort(), [
      "available", "businessId", "product", "productId",
    ]);
  });
}

itest("16. one unavailable product never hides its valid siblings", async () => {
  const a = await seedVisibleProduct();
  const b = await seedVisibleProduct();
  const c = await seedVisibleProduct();
  for (const w of [a, b]) {
    await recomputeProductComplianceStatus({ db, businessId: w.businessId, productId: w.productId });
  }
  // Break the middle one, and add a wholly non-existent key at the end.
  await prodRef(b.businessId, b.productId).update({ isActive: false });
  const ghost = { businessId: nextId("ghost-biz"), productId: nextId("ghost-prod") };

  const result = await batch([keyOf(a), keyOf(b), keyOf(c), ghost]);
  assert.deepEqual(
    result.results.map((r) => r.available),
    [true, false, true, false]
  );
  assert.equal(result.results[0].product.name, "Sealed Dry Dog Food");
  assert.equal(result.results[2].product.name, "Sealed Dry Dog Food");
});

// =====================================================================
// Projection, privacy and side-effects — items 17-19
// =====================================================================

itest("17. an available product carries exactly the 29 frozen public fields", async () => {
  const w = await seedVisibleProduct();
  const only = (await batch([keyOf(w)])).results[0];
  assert.deepEqual(Object.keys(only.product).sort(), [...PUBLIC_PRODUCT_FIELDS]);
});

itest("18. the response leaks no internal failure reason and no private field", async () => {
  const visible = await seedVisibleProduct();
  const hidden = await seedVisibleProduct();
  await recomputeProductComplianceStatus({
    db, businessId: visible.businessId, productId: visible.productId,
  });
  await decRef(hidden.productId).update({ decisionHash: "0".repeat(64) });

  const result = await batch([keyOf(visible), keyOf(hidden)]);
  const serialized = JSON.stringify(result);

  // No compliance vocabulary, no internal visibility reason, no storage path.
  for (const leak of [
    "reason", "eligibility_", "visibility_", "decisionHash", "policyVersion",
    "evidenceRevision", "activeEvidenceRefs", "effectiveStatus", "validUntil",
    "compliance_docs/", "marketplace/secret", "storagePath", "ownerUid",
    "pilotProductClass", "marketplaceBusinessGenerationId", "moderationStatus",
    "isActive", "sellerRelationship", "sku", "scanStatus",
  ]) {
    assert.equal(serialized.includes(leak), false, `leaked ${leak}`);
  }
  for (const forbidden of PUBLIC_FORBIDDEN_FIELDS) {
    assert.equal(serialized.includes(`"${forbidden}"`), false, `leaked key ${forbidden}`);
  }
});

itest("19. batch hydration performs zero writes", async () => {
  const w = await seedVisibleProduct();
  const before = {
    product: (await prodRef(w.businessId, w.productId).get()).data(),
    business: (await bizRef(w.businessId).get()).data(),
    decision: (await decRef(w.productId).get()).data(),
    epoch: (await epochRef(w.businessId).get()).data() || null,
  };
  await batch([keyOf(w), keyOf(w)]);
  await batch([keyOf(w)]);
  assert.deepEqual((await prodRef(w.businessId, w.productId).get()).data(), before.product);
  assert.deepEqual((await bizRef(w.businessId).get()).data(), before.business);
  assert.deepEqual((await decRef(w.productId).get()).data(), before.decision);
  assert.deepEqual((await epochRef(w.businessId).get()).data() || null, before.epoch);
});

// =====================================================================
// Flag and wiring
// =====================================================================

itest("38a. the disabled Marketplace flag is fail-closed for batch, checked before any read", async () => {
  const w = await seedVisibleProduct();
  let error = null;
  try {
    await getMarketplaceProductBatch({ db, data: { products: [keyOf(w)] }, featureEnabled: false });
  } catch (e) {
    error = e;
  }
  assert.ok(error);
  assert.equal(error.code, "failed-precondition");
  // Even a malformed request is refused by the flag first — no request
  // validation oracle exists while the feature is off.
  let second = null;
  try {
    await getMarketplaceProductBatch({ db, data: { products: "nope" }, featureEnabled: false });
  } catch (e) {
    second = e;
  }
  assert.equal(second.code, "failed-precondition");
});

itest("wiring. the batch callable is exported exactly once, in the correct region, sharing the list flag", async () => {
  const indexText = fs.readFileSync(path.join(__dirname, "..", "index.js"), "utf8");
  assert.equal((indexText.match(/exports\.getMarketplaceProductBatch\s*=/g) || []).length, 1);
  const block = indexText.slice(indexText.indexOf("exports.getMarketplaceProductBatch"));
  assert.match(block.slice(0, 400), /region: "europe-west3"/);
  assert.match(block.slice(0, 400), /enforceAppCheck: false/);
  assert.match(block.slice(0, 600), /MARKETPLACE_LISTING_ENABLED\.value\(\) === "true"/);
  assert.equal(/onRequest\([^)]*\)[^;]*getMarketplaceProductBatch/.test(indexText), false);
  assert.equal(/onSchedule\([^)]*\)[^;]*getMarketplaceProductBatch/.test(indexText), false);
});
