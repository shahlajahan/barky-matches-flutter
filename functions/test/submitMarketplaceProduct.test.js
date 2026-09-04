// Marketplace Revision 31 prerequisite 1 — server-authoritative seller
// product submission (functions/src/marketplace/product/
// submitMarketplaceProduct.js), exercised against a real Firestore
// emulator exactly like pilotProductApproval.test.js.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");
const { test } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();
const {
  submitMarketplaceProduct,
  SUBMIT_REASON,
  isSubmissionEnabled,
  SELLER_RELATIONSHIP_VALUES,
  SERVER_OWNED_SUBMIT_FIELDS,
  normalizeSku,
  isValidSellerRelationshipValue,
} = require("../src/marketplace/product/submitMarketplaceProduct");

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function itest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

let seq = 0;
function nextId(prefix) {
  seq += 1;
  return `${prefix}-${Date.now()}-${seq}`;
}

async function seedBusiness(overrides = {}) {
  const businessId = nextId("submit-biz");
  await db
    .collection("businesses")
    .doc(businessId)
    .set({
      ownerUid: overrides.ownerUid || `owner-${businessId}`,
      marketplaceSellerActivation: { active: true, grantedBy: "admin-1" },
      marketplaceBusinessGenerationId: `gen-${businessId}`,
      pilotActiveProductCount: 0,
      ...overrides,
    });
  const snap = await db.collection("businesses").doc(businessId).get();
  return { businessId, ownerUid: snap.data().ownerUid };
}

function baseDraft(overrides = {}) {
  return {
    name: "Dry Dog Food",
    description: "Ordinary sealed packaged dry dog food.",
    price: 100,
    currency: "TRY",
    category: "Food > Dry Food",
    brand: "Acme",
    stock: 5,
    kdvRate: 10,
    media: [{ type: "image", originalUrl: "https://example.test/1.jpg" }],
    ...overrides,
  };
}

function call({ businessId, ownerUid, sku, sellerRelationship = "reseller", draft, flag = "true" }) {
  return submitMarketplaceProduct({
    db,
    auth: ownerUid === null ? null : { uid: ownerUid },
    data: { businessId, sku, sellerRelationship, draft: draft || baseDraft() },
    submissionFlagValue: flag,
  });
}

async function reasonOf(promise) {
  try {
    await promise;
    return null;
  } catch (error) {
    return (error.details && error.details.reasonCode) || `UNEXPECTED:${error.code}`;
  }
}

// --- 1 / 8: first-ever submission creates a non-public draft ------------
itest("first-ever submission creates exactly one non-public pending draft", async () => {
  const { businessId, ownerUid } = await seedBusiness();
  const result = await call({ businessId, ownerUid, sku: "FIRST-SKU-1" });

  assert.equal(result.created, true);
  assert.equal(result.businessId, businessId);
  assert.equal(result.productId, `${businessId}_FIRST-SKU-1`);

  const snap = await db
    .collection("businesses").doc(businessId)
    .collection("products").doc(result.productId).get();
  assert.equal(snap.exists, true);
  const data = snap.data();
  assert.equal(data.isActive, false);
  assert.equal(data.moderationStatus, "pending_review");
  assert.equal(data.productInputRevision, 0);
  assert.equal(data.businessId, businessId);
  assert.equal(data.sku, "FIRST-SKU-1");
  assert.equal(data.marketplaceBusinessGenerationId, `gen-${businessId}`);
  assert.equal("pilotProductApproval" in data, false);
  assert.equal("pilotProductClass" in data, false);
  assert.ok(data.createdAt);
});

// --- 2: no non-existent-document client read is required ----------------
test("the submission module performs its collision check with the Admin SDK, not a client read", () => {
  const src = fs.readFileSync(
    path.join(__dirname, "../src/marketplace/product/submitMarketplaceProduct.js"),
    "utf8"
  );
  assert.match(src, /tx\.get\(productRef\)/);
  assert.doesNotMatch(src, /FirebaseFirestore\.instance/);
});

// --- 3: duplicate SKU -------------------------------------------------
itest("a duplicate SKU is rejected with duplicate_sku and creates no second document", async () => {
  const { businessId, ownerUid } = await seedBusiness();
  await call({ businessId, ownerUid, sku: "DUPE-SKU-1" });
  assert.equal(await reasonOf(call({ businessId, ownerUid, sku: "DUPE-SKU-1" })), SUBMIT_REASON.DUPLICATE_SKU);

  const products = await db.collection("businesses").doc(businessId).collection("products").get();
  assert.equal(products.size, 1);
});

// --- 4: concurrency ----------------------------------------------------
itest("two concurrent identical submissions create exactly one product", async () => {
  const { businessId, ownerUid } = await seedBusiness();
  const results = await Promise.allSettled([
    call({ businessId, ownerUid, sku: "RACE-SKU-1" }),
    call({ businessId, ownerUid, sku: "RACE-SKU-1" }),
  ]);
  const fulfilled = results.filter((r) => r.status === "fulfilled");
  const rejected = results.filter((r) => r.status === "rejected");
  assert.equal(fulfilled.length, 1);
  assert.equal(rejected.length, 1);

  const products = await db.collection("businesses").doc(businessId).collection("products").get();
  assert.equal(products.size, 1);
});

// --- 5 / 6 / 7: preconditions -----------------------------------------
itest("a non-owner is rejected", async () => {
  const { businessId } = await seedBusiness();
  assert.equal(
    await reasonOf(call({ businessId, ownerUid: "someone-else", sku: "OWNER-SKU-1" })),
    SUBMIT_REASON.PERMISSION_DENIED
  );
});

itest("an unauthenticated caller is rejected", async () => {
  const { businessId } = await seedBusiness();
  assert.equal(
    await reasonOf(call({ businessId, ownerUid: null, sku: "AUTH-SKU-1" })),
    SUBMIT_REASON.PERMISSION_DENIED
  );
});

itest("an inactive Marketplace seller is rejected", async () => {
  const { businessId, ownerUid } = await seedBusiness({
    marketplaceSellerActivation: { active: false },
  });
  assert.equal(
    await reasonOf(call({ businessId, ownerUid, sku: "INACTIVE-SKU-1" })),
    SUBMIT_REASON.SELLER_ACTIVATION_REQUIRED
  );
});

itest("a missing/malformed activation object fails closed", async () => {
  const { businessId, ownerUid } = await seedBusiness({ marketplaceSellerActivation: "yes" });
  assert.equal(
    await reasonOf(call({ businessId, ownerUid, sku: "MALFORMED-SKU-1" })),
    SUBMIT_REASON.SELLER_ACTIVATION_REQUIRED
  );
});

test("a disabled Marketplace flag is rejected before any database access", async () => {
  assert.equal(
    await reasonOf(
      submitMarketplaceProduct({
        db: null,
        auth: { uid: "u" },
        data: { businessId: "b", sku: "FLAG-SKU-1", sellerRelationship: "reseller", draft: {} },
        submissionFlagValue: "",
      })
    ),
    SUBMIT_REASON.MARKETPLACE_DISABLED
  );
});

// --- 9-13: server-owned field injection --------------------------------
itest("a seller cannot inject any server-owned field", async () => {
  const { businessId, ownerUid } = await seedBusiness();
  const injections = {
    isActive: true,
    moderationStatus: "approved",
    pilotProductClass: "sealed_dry_food",
    pilotProductApproval: { active: true },
    complianceEffectiveStatus: "verified_valid",
    evidenceRevision: 9,
    productInputRevision: 7,
    marketplaceBusinessGenerationId: "forged-gen",
    reviewedBy: "admin-1",
  };
  for (const [field, value] of Object.entries(injections)) {
    const reason = await reasonOf(
      call({ businessId, ownerUid, sku: `INJECT-${field}`.toUpperCase().slice(0, 20), draft: baseDraft({ [field]: value }) })
    );
    assert.equal(reason, SUBMIT_REASON.PERMISSION_DENIED, `${field} must be rejected`);
  }
  const products = await db.collection("businesses").doc(businessId).collection("products").get();
  assert.equal(products.size, 0);
});

test("every server-owned field the plan names is in the rejection list", () => {
  for (const field of [
    "isActive", "moderationStatus", "pilotProductApproval", "pilotProductClass",
    "complianceEffectiveStatus", "complianceValidUntil", "evidenceRevision",
    "complianceUpdatedAt", "complianceReasonCode", "productInputRevision",
    "marketplaceBusinessGenerationId", "businessId", "sku", "createdAt",
  ]) {
    assert.ok(SERVER_OWNED_SUBMIT_FIELDS.includes(field), `${field} must be server-owned`);
  }
});

// --- 14 / 15: sellerRelationship --------------------------------------
itest("each of the six frozen sellerRelationship values is accepted", async () => {
  assert.equal(SELLER_RELATIONSHIP_VALUES.length, 6);
  for (const relationship of SELLER_RELATIONSHIP_VALUES) {
    const { businessId, ownerUid } = await seedBusiness();
    const result = await call({
      businessId, ownerUid, sellerRelationship: relationship, sku: `REL-${relationship}`.toUpperCase().slice(0, 24),
    });
    assert.equal(result.created, true);
    const snap = await db.collection("businesses").doc(businessId)
      .collection("products").doc(result.productId).get();
    assert.equal(snap.data().sellerRelationship, relationship);
  }
});

test("invalid sellerRelationship values are rejected without any database access", async () => {
  const invalid = [
    undefined, null, "", "Reseller", "RESELLER", " reseller", "reseller ",
    "Bayi", "Yetkili Bayi", "authorized-dealer", "unknown_value", 1, true,
    ["reseller"], { value: "reseller" },
  ];
  for (const value of invalid) {
    const reason = await reasonOf(
      submitMarketplaceProduct({
        db: null,
        auth: { uid: "u" },
        data: { businessId: "b", sku: "REL-BAD-SKU", sellerRelationship: value, draft: {} },
        submissionFlagValue: "true",
      })
    );
    assert.equal(reason, SUBMIT_REASON.INVALID_SELLER_RELATIONSHIP, `${JSON.stringify(value)} must be rejected`);
  }
});

test("isValidSellerRelationshipValue does no trimming or case folding", () => {
  assert.equal(isValidSellerRelationshipValue("reseller"), true);
  assert.equal(isValidSellerRelationshipValue(" reseller"), false);
  assert.equal(isValidSellerRelationshipValue("Reseller"), false);
});

// --- Revision 31 category boundary ------------------------------------
test("the submission flag is independent and deny-by-default", () => {
  // Revision 33 §B — only the exact string "true" enables submission.
  assert.equal(isSubmissionEnabled("true"), true);
  for (const value of [undefined, null, "", "TRUE", "True", "1", "yes", "false", "0", true, 1]) {
    assert.equal(
      isSubmissionEnabled(value),
      false,
      `${JSON.stringify(value)} must not enable submission`
    );
  }
});

test("the submission path never reads the public catalogue flag", () => {
  const src = fs.readFileSync(
    path.join(__dirname, "../src/marketplace/product/submitMarketplaceProduct.js"),
    "utf8"
  );
  // Strip comments first: the module deliberately *names* the catalogue flag
  // in prose to explain why it is not used. What must be absent is any code
  // reference to it.
  const code = src.replace(/\/\/[^\n]*/g, "");
  assert.doesNotMatch(code, /MARKETPLACE_LISTING_ENABLED/);
  const index = fs.readFileSync(path.join(__dirname, "../index.js"), "utf8");
  const block = index.slice(index.indexOf("exports.submitMarketplaceProduct"));
  const wiring = block.slice(0, block.indexOf(");") + 2).replace(/\/\/[^\n]*/g, "");
  assert.match(wiring, /MARKETPLACE_PRODUCT_SUBMISSION_ENABLED/);
  assert.doesNotMatch(wiring, /MARKETPLACE_LISTING_ENABLED/);
});

test("the deferred seller hint is absent from the submission contract", () => {
  const src = fs.readFileSync(
    path.join(__dirname, "../src/marketplace/product/submitMarketplaceProduct.js"),
    "utf8"
  );
  assert.doesNotMatch(src, /sellerSuggestedPilotProductClass/);
});

// --- request/draft shape ----------------------------------------------
test("unsupported request and draft fields are rejected", async () => {
  const badRequest = await reasonOf(
    submitMarketplaceProduct({
      db: null, auth: { uid: "u" }, submissionFlagValue: "true",
      data: { businessId: "b", sku: "SHAPE-SKU", sellerRelationship: "reseller", draft: {}, extra: 1 },
    })
  );
  assert.equal(badRequest, SUBMIT_REASON.INVALID_PRODUCT_DATA);

  const badDraft = await reasonOf(
    submitMarketplaceProduct({
      db: null, auth: { uid: "u" }, submissionFlagValue: "true",
      data: { businessId: "b", sku: "SHAPE-SKU", sellerRelationship: "reseller", draft: { notAField: 1 } },
    })
  );
  assert.equal(badDraft, SUBMIT_REASON.INVALID_PRODUCT_DATA);
});

test("normalizeSku matches the client cleaning contract", () => {
  assert.equal(normalizeSku("abc def"), "ABC-DEF");
  assert.equal(normalizeSku("a!b@c#d"), "ABCD");
  assert.throws(() => normalizeSku("ab"), /invalid/i);
  assert.throws(() => normalizeSku(""), /required/i);
});

// --- Revision 33: generation-aware SKU scoping -------------------------
itest("a same-generation duplicate SKU is rejected as duplicate_sku", async () => {
  const { businessId, ownerUid } = await seedBusiness();
  await call({ businessId, ownerUid, sku: "GEN-SAME-1" });
  assert.equal(
    await reasonOf(call({ businessId, ownerUid, sku: "GEN-SAME-1" })),
    SUBMIT_REASON.DUPLICATE_SKU
  );
});

itest("a stale previous-generation product is never overwritten or adopted", async () => {
  const { businessId, ownerUid } = await seedBusiness();
  const result = await call({ businessId, ownerUid, sku: "GEN-STALE-1" });

  // The business is deleted and recreated under the same ID: a new
  // server-generated generation, with the old product still present because
  // its authoritative cleanup has not completed.
  await db.collection("businesses").doc(businessId).update({
    marketplaceBusinessGenerationId: `gen2-${businessId}`,
  });

  assert.equal(
    await reasonOf(call({ businessId, ownerUid, sku: "GEN-STALE-1" })),
    SUBMIT_REASON.PREVIOUS_GENERATION_CLEANUP_PENDING
  );

  // The old document is untouched — not overwritten, not reactivated, and
  // still bound to its own original generation.
  const snap = await db.collection("businesses").doc(businessId)
    .collection("products").doc(result.productId).get();
  assert.equal(snap.data().marketplaceBusinessGenerationId, `gen-${businessId}`);
  assert.equal(snap.data().isActive, false);
  assert.equal(snap.data().moderationStatus, "pending_review");
});

itest("an old-generation product cannot be inherited even when it was active", async () => {
  const { businessId, ownerUid } = await seedBusiness();
  const result = await call({ businessId, ownerUid, sku: "GEN-ACTIVE-1" });
  // Simulate a previously approved and public old-generation product.
  await db.collection("businesses").doc(businessId).collection("products")
    .doc(result.productId)
    .update({ isActive: true, moderationStatus: "approved" });
  await db.collection("businesses").doc(businessId).update({
    marketplaceBusinessGenerationId: `gen2-${businessId}`,
  });

  assert.equal(
    await reasonOf(call({ businessId, ownerUid, sku: "GEN-ACTIVE-1" })),
    SUBMIT_REASON.PREVIOUS_GENERATION_CLEANUP_PENDING
  );
  const snap = await db.collection("businesses").doc(businessId)
    .collection("products").doc(result.productId).get();
  assert.equal(snap.data().isActive, true, "the stale product is left exactly as found");
});

itest("a missing or malformed generation binding on the occupying product fails closed", async () => {
  for (const bad of [null, "", 42, { id: "x" }, undefined]) {
    const { businessId, ownerUid } = await seedBusiness();
    const result = await call({ businessId, ownerUid, sku: "GEN-BAD-1" });
    const ref = db.collection("businesses").doc(businessId)
      .collection("products").doc(result.productId);
    if (bad === undefined) {
      await ref.update({
        marketplaceBusinessGenerationId: admin.firestore.FieldValue.delete(),
      });
    } else {
      await ref.update({ marketplaceBusinessGenerationId: bad });
    }
    assert.equal(
      await reasonOf(call({ businessId, ownerUid, sku: "GEN-BAD-1" })),
      SUBMIT_REASON.PREVIOUS_GENERATION_CLEANUP_PENDING,
      `binding ${JSON.stringify(bad)} must fail closed`
    );
  }
});

itest("freeing the deterministic ID lets the new generation submit the same SKU", async () => {
  const { businessId, ownerUid } = await seedBusiness();
  const result = await call({ businessId, ownerUid, sku: "GEN-FREED-1" });
  await db.collection("businesses").doc(businessId).update({
    marketplaceBusinessGenerationId: `gen2-${businessId}`,
  });
  // Stands in for the authoritative deletion primitive completing its
  // cleanup: once the product document is gone the deterministic SKU is
  // free, with no reservation collection and no ID change involved.
  await db.collection("businesses").doc(businessId)
    .collection("products").doc(result.productId).delete();

  const reborn = await call({ businessId, ownerUid, sku: "GEN-FREED-1" });
  assert.equal(reborn.created, true);
  assert.equal(reborn.productId, result.productId, "the deterministic ID is unchanged");
  const snap = await db.collection("businesses").doc(businessId)
    .collection("products").doc(reborn.productId).get();
  assert.equal(snap.data().marketplaceBusinessGenerationId, `gen2-${businessId}`);
});

test("no generation-scoped document ID and no reservation collection are introduced", () => {
  const src = fs.readFileSync(
    path.join(__dirname, "../src/marketplace/product/submitMarketplaceProduct.js"),
    "utf8"
  );
  // The ID formula stays exactly `${businessId}_${sku}` (Revision 19).
  assert.match(src, /const productId = `\$\{businessId\}_\$\{sku\}`;/);
  assert.doesNotMatch(src, /generationId\}_/);
  assert.doesNotMatch(src, /skuReservation|sku_reservations|reservationRef/i);
});
