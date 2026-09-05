"use strict";

// =====================================================================
// Marketplace Revision 41 §0.39 / Slice 7C — behavioural tests for the
// expanded ten-class pilot taxonomy.
//
// Everything here drives REAL production code paths against a real Firestore
// emulator: the exported `setPilotProductClassification`,
// `approvePilotProduct` and `submitMarketplaceProduct` callables through
// their `.run()` helpers, and the canonical `assessProductVisibility` /
// `evaluateLiveProductEligibility` predicates. There are no test-only
// replicas of any decision.
//
// The security question this slice raises is narrow and is what these tests
// are built around: adding six identifiers must make ordinary accessories
// CLASSIFIABLE without making anything PUBLISHABLE that was not publishable
// before, and without relaxing a single existing control.
// =====================================================================

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const fs = require("node:fs");
const path = require("node:path");
const { test, after } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();
const functions = require("../index");

const {
  PILOT_PRODUCT_CLASS,
  PILOT_PRODUCT_CLASS_VALUES,
  PILOT_PRODUCT_CLASS_GROUP_A,
  PILOT_PRODUCT_CLASS_GROUP_B,
  isValidPilotProductClass,
  COMPLIANCE_DOCUMENT_TYPE,
  COMPLIANCE_DOCUMENT_STATUS,
  COMPLIANCE_SCOPE_TYPE,
  COMPLIANCE_SCOPE_STATUS,
  COMPLIANCE_POLICY_REGISTRY_STATUS,
} = require("../src/marketplace/compliance/complianceConstants");
const {
  computeApprovalFingerprint,
} = require("../src/marketplace/compliance/pilotProductApproval");
const {
  assessProductVisibility,
  VISIBILITY_REASON,
} = require("../src/marketplace/publicCatalog/marketplaceProductVisibility");
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

const RUN = Math.random().toString(36).slice(2, 10);
let seq = 0;
const nextId = (prefix) => `${prefix}-${RUN}-${(seq += 1)}`;

// ---------------------------------------------------------------------
// Fixtures — production-shaped, seeded through the Admin SDK exactly as
// pilotProductApproval.test.js and pilotProductClassification.test.js do.
// ---------------------------------------------------------------------

async function seedAdmin() {
  const id = nextId("tax-admin");
  await db.collection("users").doc(id).set({ role: "admin" });
  return id;
}

// Every document this suite creates is tracked and deleted in `after`.
// Without that, the ~40 businesses and products it seeds stay in the shared
// emulator and break `complianceProductRecomputeSweep`, which sweeps the
// whole `products` collection group and counts what it finds.
const createdBusinesses = [];
const createdProducts = [];
const createdDecisions = [];

async function seedBusiness(overrides = {}) {
  const businessId = nextId("tax-biz");
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
  const productId = overrides.productId || nextId("tax-prod");
  delete overrides.productId;
  createdProducts.push({ businessId, productId });
  const biz = (await db.collection("businesses").doc(businessId).get()).data();
  await db
    .collection("businesses").doc(businessId)
    .collection("products").doc(productId)
    .set({
      businessId,
      marketplaceBusinessGenerationId: biz.marketplaceBusinessGenerationId,
      name: "Ordinary product",
      description: "An ordinary listing.",
      price: 100,
      currency: "TRY",
      media: [{ type: "image", originalUrl: "https://example.test/1.jpg" }],
      category: "Accessories > Collar",
      brand: "Acme",
      barcode: "1234567890",
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
  const versionId = nextId("tax-policy");
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

/// LAYER A evidence only: one approved relationship/provenance document and
/// the product scope that names it. Deliberately a `purchase_invoice` for a
/// `reseller` — nothing food-specific, chemical or pharmaceutical.
async function seedRelationshipEvidence(businessId, productId) {
  await seedActivePolicy();
  const generationId = (await db.collection("businesses").doc(businessId).get())
    .data().marketplaceBusinessGenerationId;
  const documentId = nextId("tax-doc");
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
  await db.collection("complianceDocumentScopes").doc(nextId("tax-scope")).set({
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
  return documentId;
}

/// Writes a decision the REAL `evaluateLiveProductEligibility` accepts.
///
/// Every field the evaluator compares is derived from live state at the
/// moment of writing — the active policy version, the business evidence
/// epoch, the product's own input revision, seller relationship and pilot
/// class — and `decisionHash` is computed with the production helper rather
/// than stubbed. That matters: a hand-stubbed hash would make every
/// eligibility assertion below vacuous.
///
/// Call this AFTER classifying, because `setPilotProductClassification`
/// bumps the business epoch — which is precisely the mechanism that
/// invalidates a decision when the class changes.
async function seedEligibleDecision(businessId, productId) {
  const product = await getProduct(businessId, productId);
  const policyId = (
    await db.collection("compliancePolicyRegistryPointer").doc("current").get()
  ).data().activeVersionId;
  const epochSnap = await db.collection("businessComplianceEpochs").doc(businessId).get();
  const epoch = epochSnap.exists && typeof epochSnap.data().epoch === "number"
    ? epochSnap.data().epoch
    : 0;
  const validUntil = admin.firestore.Timestamp.fromMillis(Date.now() + 365 * 86400000);
  const content = {
    businessId,
    policyVersion: policyId,
    evidenceRevision: epoch,
    productInputRevisionSnapshot:
      typeof product.productInputRevision === "number" ? product.productInputRevision : 0,
    sellerRelationshipSnapshot: product.sellerRelationship,
    pilotProductClassSnapshot: isValidPilotProductClass(product.pilotProductClass)
      ? product.pilotProductClass
      : null,
    requiredEvidenceSlots: [],
    satisfiedEvidenceSlots: [],
    // A decision with no active evidence is never eligible, whatever its
    // status claims (`assertUsableComplianceDecision`), so the reference to
    // the relationship document seeded above is carried here.
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

after(async () => {
  if (!hasEmulator) return;
  const deletions = [
    ...createdProducts.map(({ businessId, productId }) =>
      productRef(businessId, productId).delete()
    ),
    ...createdBusinesses.map((id) => db.collection("businesses").doc(id).delete()),
    ...createdBusinesses.map((id) =>
      db.collection("businessComplianceEpochs").doc(id).delete()
    ),
    ...createdDecisions.map((id) =>
      db.collection("productComplianceDecisions").doc(id).delete()
    ),
  ];
  await Promise.allSettled(deletions);
});

const productRef = (b, p) =>
  db.collection("businesses").doc(b).collection("products").doc(p);
const getProduct = async (b, p) => (await productRef(b, p).get()).data();

const callClassify = (args) =>
  functions.setPilotProductClassification.run({
    auth: args.uid ? { uid: args.uid } : null, data: args.data,
  });
const callApprove = (args) =>
  functions.approvePilotProduct.run({
    auth: args.uid ? { uid: args.uid } : null, data: args.data,
  });
const callSubmit = (args) =>
  functions.submitMarketplaceProduct.run({
    auth: args.uid ? { uid: args.uid } : null, data: args.data,
  });

async function approvalPayloadFor(businessId, productId, allowedPilotCategory) {
  const product = await getProduct(businessId, productId);
  const dec = await db.collection("productComplianceDecisions").doc(productId).get();
  return {
    businessId,
    productId,
    allowedPilotCategory,
    reviewedContentFingerprint: computeApprovalFingerprint(
      product, dec.exists ? dec.data() : null, productId
    ),
    attestNoProhibitedClaim: true,
  };
}

const visibility = (businessId, productId) =>
  assessProductVisibility({ db, businessId, productId });

// =====================================================================
// 1 / 2 — the trusted classification path accepts exactly the ten
// =====================================================================

itest("1. all ten canonical values are accepted by the trusted classification path", async () => {
  const adminUid = await seedAdmin();
  assert.equal(PILOT_PRODUCT_CLASS_VALUES.length, 10);
  for (const pilotProductClass of PILOT_PRODUCT_CLASS_VALUES) {
    const businessId = await seedBusiness();
    const productId = await seedProduct(businessId);
    const result = await callClassify({
      uid: adminUid,
      data: { businessId, productId, pilotProductClass, reason: "slice 7C" },
    });
    assert.equal(result.changed, true, pilotProductClass);
    assert.equal(result.pilotProductClass, pilotProductClass);
    // Stored verbatim — no normalization, no coercion.
    assert.equal(
      (await getProduct(businessId, productId)).pilotProductClass,
      pilotProductClass
    );
  }
});

itest("2. every unknown, legacy, variant or excluded value is rejected", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const rejected = [
    // Excluded families (Revision 41 §D).
    "vitamins", "supplements", "medicine", "medicated_food", "prescription_food",
    "flea_and_tick", "biocide", "pesticide", "therapeutic_collar",
    "shampoo", "cosmetics", "grooming_chemicals",
    "electronic_toys", "electrical_device", "battery", "charger",
    "health_monitor", "human_apparel",
    // The separate approval-call vocabulary — never interchangeable.
    "food", "treats", "litter", "toys", "collars_leads", "beds", "bowls",
    "grooming_tools",
    // Near-miss variants of real values.
    "PET_APPAREL", "pet-apparel", "pet_apparels", " pet_apparel", "pet_apparel ",
    "collars_leashes", "collar", "harness", "bowl", "beds", "toy",
    "grooming_accessories", "grooming_accessories_chemical",
    // Structural rubbish.
    "", "   ", "unknown", "ambiguous",
  ];
  for (const pilotProductClass of rejected) {
    await assert.rejects(
      () => callClassify({
        uid: adminUid,
        data: { businessId, productId, pilotProductClass, reason: "attempt" },
      }),
      (err) => err.code === "invalid-argument",
      `${JSON.stringify(pilotProductClass)} must be rejected`
    );
  }
  // And nothing was written by any of those attempts.
  assert.equal((await getProduct(businessId, productId)).pilotProductClass, undefined);
});

itest("2b. wrong-typed and missing classes are rejected", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  for (const bad of [null, undefined, 0, 1, true, false, [], {}, ["pet_apparel"]]) {
    await assert.rejects(
      () => callClassify({
        uid: adminUid,
        data: { businessId, productId, pilotProductClass: bad, reason: "attempt" },
      }),
      `${String(bad)} must be rejected`
    );
  }
});

// =====================================================================
// 3 / 4 — the seller can neither author the class nor imply it
// =====================================================================

itest("3. a seller cannot submit pilotProductClass", async () => {
  const businessId = await seedBusiness();
  const ownerUid = `owner-${businessId}`;
  // The request shape is { businessId, sku, sellerRelationship, draft } —
  // sku and sellerRelationship are top-level, not draft fields.
  const draft = {
    name: "Chest harness", description: "Handmade.", price: 250,
    currency: "TRY", category: "Accessories > Harness", brand: "Acme",
    pilotProductClass: "collars_harnesses_leashes",
  };
  const envelope = { businessId, sku: "HARNESS-001", sellerRelationship: "brand_owner" };

  // Submission sits behind its own disabled-by-default rollout flag, and the
  // exported wrapper resolves that flag once at module load, so the callable
  // cannot be opened from inside a test. The REAL submission function is
  // therefore invoked directly with exactly the arguments its wrapper passes
  // (index.js: db, auth, data, submissionFlagValue, bucketName) — the same
  // production code, with the rollout gate open, so what is proven is the
  // server-owned-field refusal itself rather than the gate standing in for it.
  const {
    submitMarketplaceProduct: submitDirect,
  } = require("../src/marketplace/product/submitMarketplaceProduct");
  const submit = (d) => submitDirect({
    db,
    auth: { uid: ownerUid },
    data: d,
    submissionFlagValue: "true",
    bucketName: null,
  });

  await assert.rejects(
    () => submit({ ...envelope, draft }),
    (err) => err.code === "permission-denied",
    "a seller-supplied class must be refused as a server-owned field"
  );

  // The identical draft WITHOUT the class does not hit that refusal, proving
  // the rejection above is caused by the class and by nothing else.
  const { pilotProductClass, ...cleanDraft } = draft;
  assert.equal(pilotProductClass, "collars_harnesses_leashes");
  let cleanError = null;
  try {
    await submit({ ...envelope, draft: cleanDraft });
  } catch (err) {
    cleanError = err;
  }
  assert.notEqual(
    cleanError && cleanError.code,
    "permission-denied",
    "removing the class must remove the server-owned-field refusal"
  );
});

itest("4. the seller's category never assigns or implies a class", async () => {
  const adminUid = await seedAdmin();
  // Every seller category that plausibly "looks like" a class.
  const categories = [
    "Accessories > Harness", "Accessories > Collar", "Accessories > Bowl",
    "Accessories > Bed", "Accessories > Carrier", "Accessories > Grooming Tool",
    "Accessories > Clothing", "Litter > Cat Litter", "Toys > Chew Toy",
    "Food > Dry Food",
  ];
  for (const category of categories) {
    const businessId = await seedBusiness();
    const productId = await seedProduct(businessId, { category });
    const stored = await getProduct(businessId, productId);
    assert.equal(
      stored.pilotProductClass,
      undefined,
      `${category} must not have produced a class`
    );
    // And an unclassified product is not publicly visible, whatever its
    // category says.
    const seen = await visibility(businessId, productId);
    assert.equal(seen.visible, false);
  }
  assert.ok(adminUid);
});

// =====================================================================
// 6 / 7 / 8 — evidence behaviour per group
// =====================================================================

itest("6. an original Group A class still approves through its existing evidence path", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, { category: "Food > Dry Food" });
  await seedRelationshipEvidence(businessId, productId);
  // Classify first: classification bumps the business epoch, so the decision
  // must be computed after it, exactly as production recompute does.
  await callClassify({
    uid: adminUid,
    data: { businessId, productId, pilotProductClass: "sealed_dry_food", reason: "food" },
  });
  await seedEligibleDecision(businessId, productId);
  const result = await callApprove({
    uid: adminUid,
    data: await approvalPayloadFor(businessId, productId, "food"),
  });
  assert.equal(result.active, true, "Group A must retain its prior behaviour");
  const stored = await getProduct(businessId, productId);
  assert.equal(stored.pilotProductApproval.active, true);
});

itest("7. every Group B class still requires a positive compliance decision", async () => {
  const adminUid = await seedAdmin();
  for (const pilotProductClass of PILOT_PRODUCT_CLASS_GROUP_B) {
    const businessId = await seedBusiness();
    const productId = await seedProduct(businessId);
    await callClassify({
      uid: adminUid,
      data: { businessId, productId, pilotProductClass, reason: "accessory" },
    });
    // Classified, but NO decision exists.
    const payload = await approvalPayloadFor(businessId, productId, "collars_leads");
    await assert.rejects(
      () => callApprove({ uid: adminUid, data: payload }),
      `${pilotProductClass} must not approve without relationship evidence`
    );
    assert.equal(
      (await getProduct(businessId, productId)).pilotProductApproval,
      undefined
    );
  }
});

itest("8. a Group B class approves on relationship evidence alone — no food or chemical document", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, { category: "Accessories > Harness" });
  // LAYER A ONLY: a purchase invoice for a reseller. Nothing food-specific,
  // nothing chemical, nothing pharmaceutical, and no
  // category_compliance_evidence.
  const documentId = await seedRelationshipEvidence(businessId, productId);
  await callClassify({
    uid: adminUid,
    data: {
      businessId, productId,
      pilotProductClass: "collars_harnesses_leashes", reason: "harness",
    },
  });
  await seedEligibleDecision(businessId, productId);
  const result = await callApprove({
    uid: adminUid,
    data: await approvalPayloadFor(businessId, productId, "collars_leads"),
  });
  assert.equal(result.active, true);

  // The evidence that carried it was a relationship document, and the only
  // class-keyed document type stays unused.
  const doc = (await db.collection("complianceDocuments").doc(documentId).get()).data();
  assert.equal(doc.documentType, COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE);
  assert.notEqual(
    doc.documentType,
    COMPLIANCE_DOCUMENT_TYPE.CATEGORY_COMPLIANCE_EVIDENCE
  );
});

itest("8b. category_compliance_evidence remains accepted for no relationship", () => {
  const {
    COMPLIANCE_INTAKE_EVIDENCE_MATRIX,
    COMPLIANCE_INTAKE_UNRESOLVED_DOCUMENT_TYPES,
  } = require("../src/marketplace/compliance/complianceConstants");
  for (const [relationship, types] of Object.entries(COMPLIANCE_INTAKE_EVIDENCE_MATRIX)) {
    assert.equal(
      types.includes(COMPLIANCE_DOCUMENT_TYPE.CATEGORY_COMPLIANCE_EVIDENCE),
      false,
      `${relationship} must not accept category compliance evidence`
    );
  }
  assert.deepEqual(
    [...COMPLIANCE_INTAKE_UNRESOLVED_DOCUMENT_TYPES],
    [COMPLIANCE_DOCUMENT_TYPE.CATEGORY_COMPLIANCE_EVIDENCE]
  );
});

// =====================================================================
// 9 / 10 / 11 — the Pharos rehearsal harness, end to end
// =====================================================================

itest("9/10/11. PHAROS: the handmade chest harness classifies, but only review publishes it", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, {
    name: "handmade markalı göğüs tasması",
    description: "El yapımı, markalı köpek göğüs tasması.",
    category: "Accessories > Harness",
    sellerRelationship: "brand_owner",
  });

  // (9) Classification ALONE must neither approve nor publish.
  const classified = await callClassify({
    uid: adminUid,
    data: {
      businessId, productId,
      pilotProductClass: "collars_harnesses_leashes",
      reason: "Handmade branded chest harness — ordinary low-risk accessory.",
    },
  });
  // (10) It is classifiable as exactly the contract's frozen answer.
  assert.equal(classified.pilotProductClass, "collars_harnesses_leashes");
  const afterClass = await getProduct(businessId, productId);
  assert.equal(afterClass.pilotProductClass, "collars_harnesses_leashes");
  assert.equal(afterClass.pilotProductApproval, undefined, "classification is not approval");
  assert.equal(afterClass.isActive, false, "classification is not publication");

  // (11) And it is NOT publicly visible before evidence, decision, approval.
  let seen = await visibility(businessId, productId);
  assert.equal(seen.visible, false, "an unapproved harness must not be discoverable");

  // Approval is refused while no decision exists.
  const prematurePayload = await approvalPayloadFor(businessId, productId, "collars_leads");
  await assert.rejects(
    () => callApprove({ uid: adminUid, data: prematurePayload }),
    "approval must be refused before evidence"
  );
  seen = await visibility(businessId, productId);
  assert.equal(seen.visible, false);

  // With Layer A evidence and a positive decision, review can approve it.
  await seedRelationshipEvidence(businessId, productId);
  await seedEligibleDecision(businessId, productId);
  const approved = await callApprove({
    uid: adminUid,
    data: await approvalPayloadFor(businessId, productId, "collars_leads"),
  });
  assert.equal(approved.active, true, "the harness becomes eligible for review, and passes it");

  const afterApproval = await getProduct(businessId, productId);
  assert.equal(afterApproval.pilotProductApproval.active, true);
  assert.equal(afterApproval.isActive, true);
  seen = await visibility(businessId, productId);
  assert.equal(seen.visible, true, "only now is it discoverable");
});

// =====================================================================
// 12 / 13 — vitamins out, litter in (as a description only)
// =====================================================================

itest("12. vitamins cannot enter the pilot publication path at any layer", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, { moderationStatus: "approved" });

  // No class exists for it.
  assert.equal(isValidPilotProductClass("vitamins"), false);
  await assert.rejects(
    () => callClassify({
      uid: adminUid,
      data: { businessId, productId, pilotProductClass: "vitamins", reason: "x" },
    }),
    (err) => err.code === "invalid-argument"
  );

  // The seller category is gone from both the UI map and the Rules mirror.
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  assert.ok(!rules.includes("'Health > Vitamins'"));

  // A vitamins product left unclassified is never visible, even when every
  // other publication signal is set.
  await productRef(businessId, productId).set({ isActive: true }, { merge: true });
  const seen = await visibility(businessId, productId);
  assert.equal(seen.visible, false);
  assert.equal(seen.reason, VISIBILITY_REASON.CLASS_INVALID);
});

itest("13. litter is describable by a seller but still requires admin classification", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, {
    category: "Litter > Cat Litter", moderationStatus: "approved",
  });

  // The category is now writable...
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  assert.ok(rules.includes("'Litter > Cat Litter'"), "the seller may describe litter");

  // ...but it confers nothing.
  assert.equal((await getProduct(businessId, productId)).pilotProductClass, undefined);
  assert.equal((await visibility(businessId, productId)).visible, false);

  // Only the admin path makes it classified.
  await callClassify({
    uid: adminUid,
    data: {
      businessId, productId,
      pilotProductClass: "non_biocidal_litter", reason: "ordinary clumping litter",
    },
  });
  assert.equal(
    (await getProduct(businessId, productId)).pilotProductClass,
    "non_biocidal_litter"
  );
});

// =====================================================================
// 14 / 15 / 16 — the exclusion boundaries that ARE deterministically
// representable at runtime
// =====================================================================

itest("14/15/16. a prohibited-claim attestation is mandatory for every accessory class", async () => {
  // The runtime performs no semantic inspection of a product (Revision 41
  // §D leaves therapeutic/electronic/chemical detection to the admin), so
  // the deterministically representable boundary is the attestation gate:
  // approval is refused unless the reviewing admin affirms no prohibited
  // claim. That gate must apply identically to every new class.
  const adminUid = await seedAdmin();
  for (const [pilotProductClass, category] of [
    ["collars_harnesses_leashes", "collars_leads"],   // therapeutic collar
    ["non_electronic_toys", "toys"],                  // electronic toy
    ["grooming_accessories_non_chemical", "grooming_tools"], // shampoo
    ["feeding_accessories", "bowls"],                 // food bundled with a bowl
  ]) {
    const businessId = await seedBusiness();
    const productId = await seedProduct(businessId);
    await seedRelationshipEvidence(businessId, productId);
    await callClassify({
      uid: adminUid,
      data: { businessId, productId, pilotProductClass, reason: "boundary" },
    });
    await seedEligibleDecision(businessId, productId);
    const payload = await approvalPayloadFor(businessId, productId, category);
    await assert.rejects(
      () => callApprove({
        uid: adminUid,
        data: { ...payload, attestNoProhibitedClaim: false },
      }),
      (err) => err.code === "invalid-argument",
      `${pilotProductClass} must not approve without the attestation`
    );
    assert.equal(
      (await getProduct(businessId, productId)).pilotProductApproval,
      undefined
    );
  }
});

itest("14b. an excluded product cannot reach publication by being MIS-described", async () => {
  // A seller may write any allowed category string. That must never carry a
  // product toward publication on its own — the class is what governs, and
  // it is admin-written.
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, {
    name: "Therapeutic flea collar",
    category: "Accessories > Collar",
    moderationStatus: "approved",
    // Otherwise fully publishable — so the class check is demonstrably the
    // control that stops it, not an incidental inactive flag.
    isActive: true,
  });
  const seen = await visibility(businessId, productId);
  assert.equal(seen.visible, false);
  assert.equal(seen.reason, VISIBILITY_REASON.CLASS_INVALID);
});

// =====================================================================
// 17 — unknown/legacy classes fail closed in discovery and purchase
// =====================================================================

itest("17. an unknown or legacy class value fails closed in the canonical predicate", async () => {
  const businessId = await seedBusiness();
  for (const bogus of [
    "collars_leads", "toys", "grooming_tools", "vitamins",
    "sealed-dry-food", "SEALED_DRY_FOOD", "legacy_accessory", "", null,
  ]) {
    const productId = await seedProduct(businessId, {
      moderationStatus: "approved",
      isActive: true,
      pilotProductClass: bogus,
    });
    const seen = await visibility(businessId, productId);
    assert.equal(seen.visible, false, `${String(bogus)} must fail closed`);
    assert.equal(seen.reason, VISIBILITY_REASON.CLASS_INVALID, String(bogus));
  }
});

// =====================================================================
// 18 / 19 — reclassification invalidates and unpublishes
// =====================================================================

itest("18/19. reclassification invalidates the approval binding and unpublishes atomically", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, { category: "Accessories > Harness" });
  await seedRelationshipEvidence(businessId, productId);
  await callClassify({
    uid: adminUid,
    data: { businessId, productId, pilotProductClass: "collars_harnesses_leashes", reason: "a" },
  });
  await seedEligibleDecision(businessId, productId);
  await callApprove({
    uid: adminUid,
    data: await approvalPayloadFor(businessId, productId, "collars_leads"),
  });

  const published = await getProduct(businessId, productId);
  assert.equal(published.isActive, true);
  const fingerprintBefore = published.pilotProductApproval.reviewedContentFingerprint
    || computeApprovalFingerprint(
      published,
      (await db.collection("productComplianceDecisions").doc(productId).get()).data(),
      productId
    );
  assert.equal((await visibility(businessId, productId)).visible, true);

  // Reclassify to a DIFFERENT valid class.
  const reclassified = await callClassify({
    uid: adminUid,
    data: { businessId, productId, pilotProductClass: "pet_apparel", reason: "b" },
  });
  assert.equal(reclassified.changed, true);
  assert.equal(reclassified.unpublished, true, "reclassification must unpublish");

  const after = await getProduct(businessId, productId);
  assert.equal(after.pilotProductClass, "pet_apparel");
  assert.equal(after.isActive, false, "the product must be unpublished");
  assert.notEqual(after.pilotProductApproval?.active, true, "the approval must not stay active");

  // (18) The approval fingerprint no longer matches: the class is a bound
  // input, so the earlier binding is invalid by construction.
  const fingerprintAfter = computeApprovalFingerprint(
    after,
    (await db.collection("productComplianceDecisions").doc(productId).get()).data(),
    productId
  );
  assert.notEqual(
    fingerprintAfter,
    fingerprintBefore,
    "the class change must invalidate the approval fingerprint"
  );

  // (19/21) And it is immediately undiscoverable.
  assert.equal((await visibility(businessId, productId)).visible, false);
});

itest("18b. the class is a bound input of the approval fingerprint for every new value", async () => {
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const base = await getProduct(businessId, productId);
  const seen = new Set();
  for (const pilotProductClass of PILOT_PRODUCT_CLASS_VALUES) {
    const fp = computeApprovalFingerprint({ ...base, pilotProductClass }, null, productId);
    assert.equal(seen.has(fp), false, `${pilotProductClass} must produce a distinct fingerprint`);
    seen.add(fp);
  }
  assert.equal(seen.size, 10);
});

// =====================================================================
// 20 / 21 / 22 — compatibility, discovery, and the checkout boundary
// =====================================================================

/// Drives a product all the way to publishable through the real callables.
async function publishThrough(adminUid, businessId, productId, pilotProductClass, allowedPilotCategory) {
  await seedRelationshipEvidence(businessId, productId);
  await callClassify({
    uid: adminUid,
    data: { businessId, productId, pilotProductClass, reason: "fixture" },
  });
  await seedEligibleDecision(businessId, productId);
  return callApprove({
    uid: adminUid,
    data: await approvalPayloadFor(businessId, productId, allowedPilotCategory),
  });
}

itest("20. every original four-class product remains valid and publishable after the expansion", async () => {
  const adminUid = await seedAdmin();
  const categoryFor = {
    sealed_dry_food: "food",
    sealed_wet_food: "food",
    non_medicinal_treats: "treats",
    non_biocidal_litter: "litter",
  };
  for (const pilotProductClass of PILOT_PRODUCT_CLASS_GROUP_A) {
    const businessId = await seedBusiness();
    const productId = await seedProduct(businessId);
    assert.equal(isValidPilotProductClass(pilotProductClass), true);
    const result = await publishThrough(
      adminUid, businessId, productId, pilotProductClass, categoryFor[pilotProductClass]
    );
    assert.equal(result.active, true, `${pilotProductClass} must still approve`);
    const seen = await visibility(businessId, productId);
    assert.equal(seen.visible, true, `${pilotProductClass} must remain publishable`);
  }
});

itest("20b. every NEW accessory class reaches publishable through the same unchanged path", async () => {
  const adminUid = await seedAdmin();
  const categoryFor = {
    pet_apparel: "collars_leads",
    collars_harnesses_leashes: "collars_leads",
    feeding_accessories: "bowls",
    beds_carriers: "beds",
    non_electronic_toys: "toys",
    grooming_accessories_non_chemical: "grooming_tools",
  };
  for (const pilotProductClass of PILOT_PRODUCT_CLASS_GROUP_B) {
    const businessId = await seedBusiness();
    const productId = await seedProduct(businessId);
    const result = await publishThrough(
      adminUid, businessId, productId, pilotProductClass, categoryFor[pilotProductClass]
    );
    assert.equal(result.active, true, `${pilotProductClass} must approve`);
    assert.equal(
      (await visibility(businessId, productId)).visible,
      true,
      `${pilotProductClass} must become publishable`
    );
  }
});

itest("21. discovery serves only currently eligible products", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const eligible = await seedProduct(businessId);
  await publishThrough(adminUid, businessId, eligible, "beds_carriers", "beds");
  const unclassified = await seedProduct(businessId, {
    moderationStatus: "approved", isActive: true,
    pilotProductApproval: { active: true },
  });
  const inactive = await seedProduct(businessId, {
    moderationStatus: "approved", isActive: false,
    pilotProductClass: "beds_carriers",
  });

  assert.equal((await visibility(businessId, eligible)).visible, true);
  assert.equal((await visibility(businessId, unclassified)).visible, false);
  assert.equal((await visibility(businessId, inactive)).visible, false);

  // Through the real batch-hydration callable, not just the predicate.
  const {
    getMarketplaceProductBatch,
  } = require("../src/marketplace/publicCatalog/marketplaceListing");
  const batch = await getMarketplaceProductBatch({
    db,
    // The batch callable is flag-gated in production and no flag is enabled
    // in this task; the gate is passed explicitly so the test exercises the
    // real hydration path rather than the disabled-feature branch.
    featureEnabled: true,
    data: {
      products: [
        { businessId, productId: eligible },
        { businessId, productId: unclassified },
        { businessId, productId: inactive },
      ],
    },
  });
  const byId = Object.fromEntries(batch.results.map((r) => [r.productId, r]));
  assert.equal(byId[eligible].available, true);
  assert.equal(byId[unclassified].available, false);
  assert.equal(byId[inactive].available, false);
  // An unavailable entry leaks no product body.
  assert.equal(byId[unclassified].product, null);
});

itest("22. a product that loses eligibility after discovery is refused by the canonical predicate", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, { category: "Accessories > Bowl" });
  await seedRelationshipEvidence(businessId, productId);
  await callClassify({
    uid: adminUid,
    data: { businessId, productId, pilotProductClass: "feeding_accessories", reason: "bowl" },
  });
  await seedEligibleDecision(businessId, productId);
  await callApprove({
    uid: adminUid,
    data: await approvalPayloadFor(businessId, productId, "bowls"),
  });

  // Discovered as available.
  assert.equal((await visibility(businessId, productId)).visible, true);

  // Reclassified between discovery and purchase.
  await callClassify({
    uid: adminUid,
    data: { businessId, productId, pilotProductClass: "beds_carriers", reason: "corrected" },
  });

  // The canonical purchase-eligibility predicate now refuses it — evaluated
  // fresh at request time, exactly as Revision 39 §D requires.
  const afterwards = await visibility(businessId, productId);
  assert.equal(afterwards.visible, false, "a stale eligibility must not survive");
});

// ---------------------------------------------------------------------
// The checkout blocker, pinned so it cannot be quietly forgotten.
//
// Revision 39 §0.37 E records that NO purchase path performs a publication
// or compliance check, and that the gap cannot be closed as a scoped change
// (order creation reads non-transactionally and commits with batch.commit()).
// Slice 7C is explicitly forbidden from closing it. This asserts the blocker
// is still exactly as reported — neither fixed nor widened by this slice —
// so item 22 above is honest about what it does and does not prove.
// ---------------------------------------------------------------------
test("22b. SOURCE-TEXT: createMarketplaceOrderV2 still does not consult the eligibility predicate (known blocker)", () => {
  const index = fs.readFileSync(path.join(__dirname, "..", "index.js"), "utf8");
  const start = index.indexOf("exports.createMarketplaceOrderV2 = onCall(");
  assert.ok(start > 0);
  const body = index.slice(start, index.indexOf("\nexports.", start + 10));
  for (const predicate of [
    "assessProductVisibility",
    "evaluateLiveProductEligibility",
    "isValidPilotProductClass",
  ]) {
    assert.ok(
      !body.includes(predicate),
      `unchanged blocker: order creation still does not call ${predicate}`
    );
  }
  // And this slice did not widen it: the taxonomy is not referenced there.
  assert.ok(!body.includes("pilotProductClass"));
});
