"use strict";

// Marketplace Revision 35 / Slice 7A (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §0.33) — the admin-only
// `setPilotProductClassification` callable: the sole write authority for
// `pilotProductClass`, the precondition that makes pilot approval reachable
// at all, and the reclassification transition that unpublishes an already
// active product.
//
// Exercises the exported onCall wrapper through its `.run()` helper against
// a real Firestore emulator, seeding businesses/products directly via the
// Admin SDK exactly as production data looks — the same established pattern
// as pilotProductApproval.test.js. Rules never apply to this server-side
// path; the client-side closure is covered separately by the Rules suite.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();
const functions = require("../index");
const {
  computeApprovalFingerprint,
  AUDIT_EVENTS_COLLECTION,
} = require("../src/marketplace/compliance/pilotProductApproval");
const {
  CLASSIFICATION_AUDIT_COLLECTION,
  CLASSIFY_ALLOWED_FIELDS,
} = require("../src/marketplace/compliance/pilotProductClassification");
const {
  PILOT_PRODUCT_CLASS,
  PILOT_PRODUCT_CLASS_VALUES,
  isValidPilotProductClass,
  PILOT_CLASSIFICATION_MAX_REASON_LENGTH,
} = require("../src/marketplace/compliance/complianceConstants");
const {
  DECISION_HASH_INCLUDED_FIELDS,
  computeDecisionHash,
} = require("../src/marketplace/compliance/complianceProductRecompute");

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function itest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

// A per-run token keeps ids unique across parallel test FILES sharing one
// emulator, which a bare counter or Date.now() alone does not.
const RUN = Math.random().toString(36).slice(2, 10);
let seq = 0;
function nextId(prefix) {
  seq += 1;
  return `${prefix}-${RUN}-${seq}`;
}

function call(args) {
  return functions.setPilotProductClassification.run({
    auth: args.uid ? { uid: args.uid } : null,
    data: args.data,
  });
}

async function seedAdmin(uid) {
  const id = uid || nextId("admin");
  await db.collection("users").doc(id).set({ role: "admin" });
  return id;
}

async function seedNonAdmin(role) {
  const id = nextId("user");
  await db.collection("users").doc(id).set(role ? { role } : {});
  return id;
}

async function seedBusiness(overrides = {}) {
  const businessId = nextId("cls-biz");
  await db
    .collection("businesses")
    .doc(businessId)
    .set({
      ownerUid: `owner-${businessId}`,
      marketplaceSellerActivation: { active: true },
      marketplaceBusinessGenerationId: `gen-${businessId}`,
      pilotActiveProductCount: 0,
      ...overrides,
    });
  return businessId;
}

async function seedProduct(businessId, overrides = {}) {
  const productId = overrides.productId || nextId("cls-prod");
  delete overrides.productId;
  const biz = (await db.collection("businesses").doc(businessId).get()).data();
  await db
    .collection("businesses")
    .doc(businessId)
    .collection("products")
    .doc(productId)
    .set({
      businessId,
      marketplaceBusinessGenerationId: biz.marketplaceBusinessGenerationId,
      name: "Dry Dog Food",
      description: "Ordinary packaged dog food.",
      price: 100,
      currency: "TRY",
      media: [{ type: "image", originalUrl: "https://example.test/1.jpg" }],
      category: "Food > Dry Food",
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

const productRef = (businessId, productId) =>
  db.collection("businesses").doc(businessId).collection("products").doc(productId);

const getProduct = async (businessId, productId) =>
  (await productRef(businessId, productId).get()).data();
const getBusiness = async (businessId) =>
  (await db.collection("businesses").doc(businessId).get()).data();

async function classificationEventsFor(productId) {
  const snap = await db
    .collection(CLASSIFICATION_AUDIT_COLLECTION)
    .where("productId", "==", productId)
    .get();
  return snap.docs.map((d) => d.data());
}

async function approvalEventsFor(productId) {
  const snap = await db.collection(AUDIT_EVENTS_COLLECTION).where("productId", "==", productId).get();
  return snap.docs.map((d) => d.data());
}

/// Places a product in the exact state a real `approvePilotProduct` leaves
/// behind, including the business counter — so the unpublish transition is
/// exercised against production-shaped state, not a hand-waved marker.
async function makeActivelyApproved(businessId, productId, fingerprint = "fp-live") {
  await productRef(businessId, productId).update({
    isActive: true,
    moderationStatus: "approved",
    pilotProductApproval: {
      active: true,
      approvedAt: admin.firestore.Timestamp.now(),
      approvedBy: "admin-x",
      allowedPilotCategory: "food",
      reviewedContentFingerprint: fingerprint,
      reasonCode: "pilot_approved",
    },
  });
  await db.collection("businesses").doc(businessId).update({ pilotActiveProductCount: 1 });
}

async function expectFails(promise, { code, reasonCode } = {}) {
  let error = null;
  try {
    await promise;
  } catch (err) {
    error = err;
  }
  assert.ok(error, "expected the call to fail, but it resolved");
  if (code) assert.equal(error.code, code, `unexpected error code: ${error.code}`);
  if (reasonCode) {
    assert.equal(
      error.details && error.details.reasonCode,
      reasonCode,
      `unexpected reasonCode: ${JSON.stringify(error.details)}`
    );
  }
  return error;
}

// =====================================================================
// A. Authorization — re-derived server-side, never taken from the caller.
// =====================================================================

itest("A1. an unauthenticated caller is denied and writes nothing", async () => {
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  await expectFails(
    call({ uid: null, data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD, reason: "r" } }),
    { code: "unauthenticated" }
  );
  const product = await getProduct(businessId, productId);
  assert.equal(product.pilotProductClass, undefined);
  assert.deepEqual(await classificationEventsFor(productId), []);
});

itest("A2. an authenticated non-admin is denied, including a user with no role at all", async () => {
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  for (const uid of [await seedNonAdmin(), await seedNonAdmin("seller"), await seedNonAdmin("moderator")]) {
    await expectFails(
      call({ uid, data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_WET_FOOD, reason: "r" } }),
      { code: "permission-denied" }
    );
  }
  assert.equal((await getProduct(businessId, productId)).pilotProductClass, undefined);
});

itest("A3. the owning seller cannot classify their own product", async () => {
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const business = await getBusiness(businessId);
  await db.collection("users").doc(business.ownerUid).set({ role: "seller" });
  await expectFails(
    call({ uid: business.ownerUid, data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD, reason: "r" } }),
    { code: "permission-denied" }
  );
  assert.equal((await getProduct(businessId, productId)).pilotProductClass, undefined);
});

// =====================================================================
// B. Request schema — closed, and never a channel for privileged state.
// =====================================================================

itest("B1. the request schema is exactly the four frozen fields", () => {
  assert.deepEqual(
    [...CLASSIFY_ALLOWED_FIELDS].sort(),
    ["businessId", "pilotProductClass", "productId", "reason"]
  );
});

itest("B2. an unrecognized field is refused outright, never ignored — including attempts to supply privileged state", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const base = { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD, reason: "r" };
  const forgeries = [
    { ...base, pilotProductClassificationRevision: 99 },
    { ...base, pilotProductClassifiedAt: Date.now() },
    { ...base, pilotProductClassifiedByUid: "someone-else" },
    { ...base, marketplaceBusinessGenerationId: "gen-forged" },
    { ...base, pilotProductApproval: { active: true } },
    { ...base, isActive: true },
    { ...base, moderationStatus: "approved" },
  ];
  for (const data of forgeries) {
    await expectFails(call({ uid: adminUid, data }), {
      code: "invalid-argument",
      reasonCode: "classification-malformed-request",
    });
  }
  assert.equal((await getProduct(businessId, productId)).pilotProductClass, undefined);
});

itest("B3. missing/blank/non-string identifiers and reasons are refused", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const cls = PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD;
  const bad = [
    {},
    { businessId, pilotProductClass: cls, reason: "r" },
    { productId, pilotProductClass: cls, reason: "r" },
    { businessId: "", productId, pilotProductClass: cls, reason: "r" },
    { businessId, productId: "", pilotProductClass: cls, reason: "r" },
    { businessId: 7, productId, pilotProductClass: cls, reason: "r" },
    { businessId, productId, pilotProductClass: cls },
    { businessId, productId, pilotProductClass: cls, reason: "" },
    { businessId, productId, pilotProductClass: cls, reason: "   " },
    { businessId, productId, pilotProductClass: cls, reason: 5 },
    { businessId, productId, pilotProductClass: cls, reason: null },
    { businessId, productId, pilotProductClass: cls, reason: "x".repeat(PILOT_CLASSIFICATION_MAX_REASON_LENGTH + 1) },
  ];
  for (const data of bad) {
    await expectFails(call({ uid: adminUid, data }), { code: "invalid-argument" });
  }
  assert.equal((await getProduct(businessId, productId)).pilotProductClass, undefined);
});

// =====================================================================
// C. The class allowlist — exact, closed, and never coerced.
// =====================================================================

itest("C1. the allowlist is exactly the four frozen pilot classes", () => {
  assert.deepEqual([...PILOT_PRODUCT_CLASS_VALUES].sort(), [
    "non_biocidal_litter",
    "non_medicinal_treats",
    "sealed_dry_food",
    "sealed_wet_food",
  ]);
});

itest("C2. every one of the four classes is individually accepted and stored verbatim", async () => {
  const adminUid = await seedAdmin();
  for (const pilotProductClass of PILOT_PRODUCT_CLASS_VALUES) {
    const businessId = await seedBusiness();
    const productId = await seedProduct(businessId);
    const result = await call({ uid: adminUid, data: { businessId, productId, pilotProductClass, reason: "classified" } });
    assert.equal(result.changed, true);
    assert.equal(result.pilotProductClass, pilotProductClass);
    assert.equal((await getProduct(businessId, productId)).pilotProductClass, pilotProductClass);
  }
});

itest("C3. every non-member value is rejected — near-misses, casings, whitespace, legacy categories and non-strings alike", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const rejected = [
    undefined, null, "", "   ", 1, true, [], {},
    "SEALED_DRY_FOOD",
    "Sealed_Dry_Food",
    " sealed_dry_food",
    "sealed_dry_food ",
    "sealed-dry-food",
    "sealeddryfood",
    "sealed_dry_foods",
    "dry_food",
    // Legacy/adjacent vocabularies that must never be silently accepted:
    // the approval categories, the seller's own draft `category` string,
    // and the medicinal/biocidal families the pilot deliberately excludes.
    "food",
    "treats",
    "litter",
    "Food > Dry Food",
    "medicinal_treats",
    "biocidal_litter",
    "vitamins",
    "supplements",
  ];
  for (const pilotProductClass of rejected) {
    await expectFails(call({ uid: adminUid, data: { businessId, productId, pilotProductClass, reason: "r" } }), {
      code: "invalid-argument",
      reasonCode: "classification-unsupported-class",
    });
  }
  assert.equal((await getProduct(businessId, productId)).pilotProductClass, undefined);
  assert.deepEqual(await classificationEventsFor(productId), []);
});

// =====================================================================
// D. Target resolution, cross-tenant isolation and generation binding.
// =====================================================================

itest("D1. a missing business or product is not-found, and never partially written", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const cls = PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD;
  await expectFails(
    call({ uid: adminUid, data: { businessId: nextId("ghost-biz"), productId, pilotProductClass: cls, reason: "r" } }),
    { code: "not-found", reasonCode: "classification-business-not-found" }
  );
  await expectFails(
    call({ uid: adminUid, data: { businessId, productId: nextId("ghost-prod"), pilotProductClass: cls, reason: "r" } }),
    { code: "not-found", reasonCode: "classification-product-not-found" }
  );
  assert.equal((await getProduct(businessId, productId)).pilotProductClass, undefined);
});

itest("D2. a product may never be classified through a business it does not belong to", async () => {
  const adminUid = await seedAdmin();
  const businessA = await seedBusiness();
  const businessB = await seedBusiness();
  // A product document physically under B, but whose canonical businessId
  // still claims A — the exact shape a copy/restore bug produces.
  const productId = await seedProduct(businessB, { businessId: businessA });
  await expectFails(
    call({ uid: adminUid, data: { businessId: businessB, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD, reason: "r" } }),
    { code: "not-found", reasonCode: "classification-product-not-found" }
  );
  assert.equal((await getProduct(businessB, productId)).pilotProductClass, undefined);
});

itest("D3. a same-named product under a different business is never touched", async () => {
  const adminUid = await seedAdmin();
  const sharedName = nextId("shared-prod");
  const businessA = await seedBusiness();
  const businessB = await seedBusiness();
  await seedProduct(businessA, { productId: sharedName });
  await seedProduct(businessB, { productId: sharedName });
  await call({
    uid: adminUid,
    data: { businessId: businessA, productId: sharedName, pilotProductClass: PILOT_PRODUCT_CLASS.NON_BIOCIDAL_LITTER, reason: "r" },
  });
  assert.equal((await getProduct(businessA, sharedName)).pilotProductClass, "non_biocidal_litter");
  assert.equal((await getProduct(businessB, sharedName)).pilotProductClass, undefined);
  assert.equal((await classificationEventsFor(sharedName)).length, 1);
});

itest("D4. an uninitialized, absent or mismatched generation fails closed", async () => {
  const adminUid = await seedAdmin();
  const cls = PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD;

  const noneBiz = await seedBusiness({ marketplaceBusinessGenerationId: null });
  const noneProd = await seedProduct(noneBiz, { marketplaceBusinessGenerationId: "gen-orphan" });
  await expectFails(
    call({ uid: adminUid, data: { businessId: noneBiz, productId: noneProd, pilotProductClass: cls, reason: "r" } }),
    { code: "failed-precondition", reasonCode: "classification-generation-not-initialized" }
  );

  // A product left behind by a PREVIOUS generation of a same-id business
  // must never be adopted into the live one.
  const staleBiz = await seedBusiness();
  const staleProd = await seedProduct(staleBiz, { marketplaceBusinessGenerationId: "gen-previous" });
  await expectFails(
    call({ uid: adminUid, data: { businessId: staleBiz, productId: staleProd, pilotProductClass: cls, reason: "r" } }),
    { code: "failed-precondition", reasonCode: "classification-stale-generation" }
  );

  const absentBiz = await seedBusiness();
  const absentProd = await seedProduct(absentBiz);
  await productRef(absentBiz, absentProd).update({
    marketplaceBusinessGenerationId: admin.firestore.FieldValue.delete(),
  });
  await expectFails(
    call({ uid: adminUid, data: { businessId: absentBiz, productId: absentProd, pilotProductClass: cls, reason: "r" } }),
    { code: "failed-precondition", reasonCode: "classification-stale-generation" }
  );

  for (const [b, p] of [[noneBiz, noneProd], [staleBiz, staleProd], [absentBiz, absentProd]]) {
    assert.equal((await getProduct(b, p)).pilotProductClass, undefined);
  }
});

itest("D5. a soft-deleted product is not classifiable", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, { deletedAt: admin.firestore.Timestamp.now() });
  await expectFails(
    call({ uid: adminUid, data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD, reason: "r" } }),
    { code: "failed-precondition", reasonCode: "classification-invalid-transition" }
  );
  assert.equal((await getProduct(businessId, productId)).pilotProductClass, undefined);
});

// =====================================================================
// E. Persistence, provenance and the immutable audit trail.
// =====================================================================

itest("E1. a first classification records the class, its provenance and revision 1", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const before = Date.now();
  const result = await call({
    uid: adminUid,
    data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.NON_MEDICINAL_TREATS, reason: "  sealed, non-medicinal  " },
  });

  assert.deepEqual(
    { changed: result.changed, idempotent: result.idempotent, previousClass: result.previousClass, unpublished: result.unpublished },
    { changed: true, idempotent: false, previousClass: null, unpublished: false }
  );

  const product = await getProduct(businessId, productId);
  assert.equal(product.pilotProductClass, "non_medicinal_treats");
  assert.equal(product.pilotProductClassifiedByUid, adminUid);
  assert.equal(product.pilotProductClassificationRevision, 1);
  const stampedMs = product.pilotProductClassifiedAt.toMillis();
  assert.ok(stampedMs >= before - 60000 && stampedMs <= Date.now() + 60000);

  // Nothing publication-facing moved.
  assert.equal(product.isActive, false);
  assert.equal(product.moderationStatus, "pending_review");
  assert.equal(product.pilotProductApproval, undefined);
});

itest("E2. every classification action writes exactly one immutable audit event carrying full provenance", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const generation = (await getBusiness(businessId)).marketplaceBusinessGenerationId;

  await call({ uid: adminUid, data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD, reason: "first pass" } });
  await call({ uid: adminUid, data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_WET_FOOD, reason: "corrected on re-review" } });

  const events = (await classificationEventsFor(productId)).sort(
    (a, b) => a.classificationRevision - b.classificationRevision
  );
  assert.equal(events.length, 2);

  assert.equal(events[0].previousPilotProductClass, null);
  assert.equal(events[0].newPilotProductClass, "sealed_dry_food");
  assert.equal(events[0].classificationRevision, 1);
  assert.equal(events[0].reason, "first pass");

  assert.equal(events[1].previousPilotProductClass, "sealed_dry_food");
  assert.equal(events[1].newPilotProductClass, "sealed_wet_food");
  assert.equal(events[1].classificationRevision, 2);
  assert.equal(events[1].reason, "corrected on re-review");

  for (const event of events) {
    assert.equal(event.productId, productId);
    assert.equal(event.businessId, businessId);
    assert.equal(event.marketplaceBusinessGenerationId, generation);
    assert.equal(event.adminUid, adminUid);
    assert.equal(event.actorKind, "admin");
    assert.ok(event.createdAt, "expected a server-written timestamp");
  }
});

itest("E3. the recorded reason is the trimmed caller text, and history is appended, never rewritten", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  await call({ uid: adminUid, data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD, reason: "\n  original rationale \t" } });
  const first = await classificationEventsFor(productId);
  assert.equal(first[0].reason, "original rationale");

  await call({ uid: adminUid, data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.NON_BIOCIDAL_LITTER, reason: "second rationale" } });
  const after = await classificationEventsFor(productId);
  assert.equal(after.length, 2);
  // The original entry survives byte-identically — the trail is append-only.
  assert.ok(after.some((e) => e.reason === "original rationale" && e.newPilotProductClass === "sealed_dry_food"));
});

// =====================================================================
// F. Idempotency and the revision counter.
// =====================================================================

itest("F1. replaying the identical class is a true no-op — no event, no revision bump, no epoch bump", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const data = { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD, reason: "r" };

  await call({ uid: adminUid, data });
  const afterFirst = await getProduct(businessId, productId);
  const epochAfterFirst = (await db.collection("businessComplianceEpochs").doc(businessId).get()).data();

  for (let i = 0; i < 3; i += 1) {
    const replay = await call({ uid: adminUid, data: { ...data, reason: `retry ${i}` } });
    assert.equal(replay.changed, false);
    assert.equal(replay.idempotent, true);
  }

  const afterReplays = await getProduct(businessId, productId);
  assert.equal(afterReplays.pilotProductClassificationRevision, 1);
  assert.equal(
    afterReplays.pilotProductClassifiedAt.toMillis(),
    afterFirst.pilotProductClassifiedAt.toMillis(),
    "an idempotent replay must not re-stamp the classification time"
  );
  assert.equal((await classificationEventsFor(productId)).length, 1, "a retry storm must not inflate the audit trail");
  const epochNow = (await db.collection("businessComplianceEpochs").doc(businessId).get()).data();
  assert.deepEqual(epochNow, epochAfterFirst, "an idempotent replay must not bump the compliance epoch");
});

itest("F2. the revision counter advances monotonically per real change, and never accepts a client value", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const order = [
    PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD,
    PILOT_PRODUCT_CLASS.SEALED_WET_FOOD,
    PILOT_PRODUCT_CLASS.NON_MEDICINAL_TREATS,
    PILOT_PRODUCT_CLASS.NON_BIOCIDAL_LITTER,
  ];
  for (let i = 0; i < order.length; i += 1) {
    const result = await call({ uid: adminUid, data: { businessId, productId, pilotProductClass: order[i], reason: `step ${i}` } });
    assert.equal(result.classificationRevision, i + 1);
  }
  assert.equal((await getProduct(businessId, productId)).pilotProductClassificationRevision, 4);
});

itest("F3. a malformed stored revision restarts at 1 rather than propagating garbage", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, { pilotProductClassificationRevision: "not-a-number" });
  const result = await call({
    uid: adminUid,
    data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD, reason: "r" },
  });
  assert.equal(result.classificationRevision, 1);
});

itest("F4. a legacy or unrecognized stored class is treated as unclassified, and replaced rather than preserved", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, { pilotProductClass: "legacy_value_from_an_older_vocabulary" });
  const result = await call({
    uid: adminUid,
    data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD, reason: "r" },
  });
  assert.equal(result.changed, true);
  assert.equal(result.previousClass, null, "an unrecognized stored value is not a valid previous class");
  assert.equal((await getProduct(businessId, productId)).pilotProductClass, "sealed_dry_food");
  // The raw prior value is still recorded in the trail, so the correction
  // is auditable rather than silently erased.
  const events = await classificationEventsFor(productId);
  assert.equal(events[0].previousPilotProductClass, "legacy_value_from_an_older_vocabulary");
});

// =====================================================================
// G. Reclassification unpublishes — atomically, and exactly once.
// =====================================================================

itest("G1. reclassifying an ACTIVE product unpublishes it through the canonical revocation transition", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, { pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD });
  await makeActivelyApproved(businessId, productId);

  const result = await call({
    uid: adminUid,
    data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_WET_FOOD, reason: "reclassified on appeal" },
  });
  assert.equal(result.unpublished, true);

  const product = await getProduct(businessId, productId);
  assert.equal(product.pilotProductClass, "sealed_wet_food");
  assert.equal(product.isActive, false, "an active product must be unpublished by reclassification");
  assert.equal(product.moderationStatus, "pending_review");
  assert.equal(product.pilotProductApproval.active, false);
  assert.ok(product.pilotProductApproval.revokedAt, "the approval must carry a revocation stamp");
  assert.equal((await getBusiness(businessId)).pilotActiveProductCount, 0);

  // The approval trail records the revocation alongside the classification
  // trail's own entry — two records, one atomic transition.
  const revocations = await approvalEventsFor(productId);
  assert.equal(revocations.length, 1);
  assert.equal(revocations[0].reasonCode, "pilot_revoked_content_changed");
  assert.equal(revocations[0].invalidationReason, "pilot_class_changed");
});

itest("G2. reclassifying an already-inactive product never touches the counter", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness({ pilotActiveProductCount: 3 });
  const productId = await seedProduct(businessId, {
    pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD,
    pilotProductApproval: { active: false, reasonCode: "pilot_revoked_admin_manual" },
  });
  const result = await call({
    uid: adminUid,
    data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_WET_FOOD, reason: "r" },
  });
  assert.equal(result.unpublished, false);
  assert.equal((await getBusiness(businessId)).pilotActiveProductCount, 3);
  assert.deepEqual(await approvalEventsFor(productId), []);
});

itest("G3. concurrent reclassifications of the same active product decrement the counter exactly once", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId, { pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD });
  await makeActivelyApproved(businessId, productId);

  const settled = await Promise.allSettled([
    call({ uid: adminUid, data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_WET_FOOD, reason: "a" } }),
    call({ uid: adminUid, data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.NON_MEDICINAL_TREATS, reason: "b" } }),
  ]);
  assert.ok(settled.some((s) => s.status === "fulfilled"), "at least one call must succeed");

  // Whatever interleaving the transaction retries produce, the product ends
  // inactive and the counter can never go below zero or be double-charged.
  const product = await getProduct(businessId, productId);
  assert.equal(product.isActive, false);
  assert.equal((await getBusiness(businessId)).pilotActiveProductCount, 0);
  assert.equal(
    (await approvalEventsFor(productId)).length,
    1,
    "the active->inactive transition, and its decrement, must happen exactly once"
  );
});

itest("G4. reclassification never activates, approves or publishes anything", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  await call({ uid: adminUid, data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD, reason: "r" } });
  await call({ uid: adminUid, data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_WET_FOOD, reason: "r2" } });
  const product = await getProduct(businessId, productId);
  assert.equal(product.isActive, false);
  assert.equal(product.moderationStatus, "pending_review");
  assert.equal(product.pilotProductApproval, undefined);
  assert.equal((await getBusiness(businessId)).pilotActiveProductCount, 0);
});

itest("G5. a real classification change bumps the business compliance epoch, staling every decision of that business", async () => {
  const adminUid = await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const epochRef = db.collection("businessComplianceEpochs").doc(businessId);
  const before = (await epochRef.get()).exists ? (await epochRef.get()).data().epoch : 0;
  await call({ uid: adminUid, data: { businessId, productId, pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD, reason: "r" } });
  assert.equal((await epochRef.get()).data().epoch, before + 1);
});

// =====================================================================
// H. Binding — the class is an input of the decision hash and the
//    approval fingerprint, and a precondition of approval.
// =====================================================================

itest("H1. pilotProductClassSnapshot is a bound input of decisionHash", () => {
  assert.ok(DECISION_HASH_INCLUDED_FIELDS.includes("pilotProductClassSnapshot"));
  assert.equal(DECISION_HASH_INCLUDED_FIELDS.length, 11);

  const content = {
    businessId: "b",
    pilotProductClassSnapshot: "sealed_dry_food",
    policyVersion: "v1",
    evidenceRevision: 0,
    productInputRevisionSnapshot: 0,
    sellerRelationshipSnapshot: "reseller",
    requiredEvidenceSlots: [],
    satisfiedEvidenceSlots: [],
    activeEvidenceRefs: [],
    validUntil: null,
    effectiveStatus: "verified_valid",
  };
  const baseline = computeDecisionHash(content);
  for (const other of PILOT_PRODUCT_CLASS_VALUES.filter((v) => v !== "sealed_dry_food").concat([null])) {
    assert.notEqual(
      computeDecisionHash({ ...content, pilotProductClassSnapshot: other }),
      baseline,
      `changing the class to ${other} must change the decision hash`
    );
  }
});

itest("H2. pilotProductClass is a bound input of the approval fingerprint", () => {
  const product = {
    name: "n", description: "d", price: 1, currency: "TRY", media: [], category: "c",
    brand: "b", barcode: null, salePrice: null, kdvRate: 10, sellerRelationship: "reseller",
    pilotProductClass: "sealed_dry_food",
  };
  const decision = { policyVersion: "v1", evidenceRevision: 0, effectiveStatus: "verified_valid", activeEvidenceRefs: [], validUntil: null };
  const baseline = computeApprovalFingerprint(product, decision, "prod-1");
  for (const other of PILOT_PRODUCT_CLASS_VALUES.filter((v) => v !== "sealed_dry_food").concat([null])) {
    assert.notEqual(
      computeApprovalFingerprint({ ...product, pilotProductClass: other }, decision, "prod-1"),
      baseline,
      `changing the class to ${other} must change the approval fingerprint`
    );
  }
});

itest("H3. approval fails closed on an absent, null or unrecognized class — approval never selects or infers one", async () => {
  const adminUid = await seedAdmin();
  for (const override of [{}, { pilotProductClass: null }, { pilotProductClass: "vitamins" }, { pilotProductClass: "SEALED_DRY_FOOD" }]) {
    const businessId = await seedBusiness();
    const productId = await seedProduct(businessId, override);
    await db.collection("productComplianceDecisions").doc(productId).set({
      businessId,
      policyVersion: `policy-${productId}`,
      evidenceRevision: 0,
      decisionHash: `hash-${productId}`,
      effectiveStatus: "verified_valid",
      activeEvidenceRefs: [],
      validUntil: admin.firestore.Timestamp.fromMillis(Date.now() + 365 * 86400000),
    });
    const product = await getProduct(businessId, productId);
    const decision = (await db.collection("productComplianceDecisions").doc(productId).get()).data();
    await expectFails(
      functions.approvePilotProduct.run({
        auth: { uid: adminUid },
        data: {
          businessId,
          productId,
          allowedPilotCategory: "food",
          reviewedContentFingerprint: computeApprovalFingerprint(product, decision, productId),
          attestNoProhibitedClaim: true,
        },
      }),
      { code: "failed-precondition", reasonCode: "pilot-class-missing-or-invalid" }
    );
    const after = await getProduct(businessId, productId);
    assert.equal(after.isActive, false);
    assert.equal(after.pilotProductApproval, undefined);
  }
});

// =====================================================================
// I. Static contract — this module is the sole writer and never publishes.
// =====================================================================

const CLASSIFICATION_SOURCE = fs.readFileSync(
  path.join(__dirname, "..", "src", "marketplace", "compliance", "pilotProductClassification.js"),
  "utf8"
);
const nonComment = (text) =>
  text
    .split("\n")
    .filter((line) => !line.trim().startsWith("//"))
    .join("\n");
const CLASSIFICATION_EXECUTABLE = nonComment(CLASSIFICATION_SOURCE);

itest("I1. the classification module never writes an activation, approval or publication field", async () => {
  for (const forbidden of ["isActive: true", "moderationStatus: \"approved\"", "reviewedContentFingerprint", "allowedPilotCategory"]) {
    assert.equal(
      CLASSIFICATION_EXECUTABLE.includes(forbidden),
      false,
      `the classification path must never write ${forbidden}`
    );
  }
});

itest("I2. the unpublish transition is delegated, never duplicated — no second copy of the revocation or counter logic", () => {
  assert.ok(CLASSIFICATION_EXECUTABLE.includes("applyPilotApprovalRevocation("));
  assert.equal(CLASSIFICATION_EXECUTABLE.includes("pilotActiveProductCount"), false);
  assert.equal(CLASSIFICATION_EXECUTABLE.includes("FieldValue.increment(-1)"), false);
});

itest("I3. recomputation is scheduled through the existing epoch helper, not a new mechanism", () => {
  assert.ok(CLASSIFICATION_EXECUTABLE.includes("bumpBusinessComplianceEpoch("));
  assert.equal(CLASSIFICATION_EXECUTABLE.includes("businessComplianceEpochs"), false);
});

itest("I4. every write happens inside the single transaction, and the class allowlist is never re-implemented locally", () => {
  assert.ok(CLASSIFICATION_EXECUTABLE.includes("db.runTransaction("));
  assert.ok(CLASSIFICATION_EXECUTABLE.includes("isValidPilotProductClass("));
  for (const value of PILOT_PRODUCT_CLASS_VALUES) {
    assert.equal(
      CLASSIFICATION_EXECUTABLE.includes(`"${value}"`),
      false,
      "class values must come from the frozen constant, never be re-listed here"
    );
  }
  assert.equal(typeof isValidPilotProductClass, "function");
});

itest("I5. exactly one callable wrapper exists for classification, with no HTTP or scheduled entry point", () => {
  const indexText = fs.readFileSync(path.join(__dirname, "..", "index.js"), "utf8");
  assert.equal((indexText.match(/exports\.setPilotProductClassification\s*=/g) || []).length, 1);
  assert.equal(/onRequest\([^)]*\)\s*,?\s*async \(request\) =>\s*\n?\s*setPilotProductClassification/.test(indexText), false);
  assert.equal(indexText.includes("onSchedule") && /onSchedule\([^)]*\)[^;]*setPilotProductClassification/.test(indexText), false);
});
