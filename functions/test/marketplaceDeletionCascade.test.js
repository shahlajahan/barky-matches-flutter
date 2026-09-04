// Marketplace Revision 33 — the authoritative product/business deletion
// cascade and the shared cleanup primitive both paths use.
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
  cleanupProductFirestoreState,
  resolveProductMediaObjects,
  classifyMediaReference,
  CLEANUP_SOURCE,
  CLEANUP_OUTCOME,
  MEDIA_PRESERVED_REASON,
  CLEANUP_AUDIT_COLLECTION,
} = require("../src/marketplace/product/productCleanup");
const {
  runBusinessDeletionCascade,
  resumeIncompleteBusinessDeletionCascades,
  cascadeStateRef,
  CASCADE_STATUS,
} = require("../src/marketplace/product/businessDeletionCascade");
const {
  submitMarketplaceProduct,
  SUBMIT_REASON,
} = require("../src/marketplace/product/submitMarketplaceProduct");

const hasEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function itest(name, fn) {
  test(name, { skip: !hasEmulator }, fn);
}

const BUCKET = "demo-petsupo.appspot.com";
let seq = 0;
const nextId = (p) => `${p}-${Date.now()}-${++seq}`;

function mediaUrl(businessId, file) {
  const encoded = encodeURIComponent(`products_raw/${businessId}/${file}`);
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encoded}?alt=media&token=abc`;
}

async function seedBusiness({ generation = null } = {}) {
  const businessId = nextId("casc-biz");
  const gen = generation || `gen-${businessId}`;
  await db.collection("businesses").doc(businessId).set({
    ownerUid: `owner-${businessId}`,
    marketplaceSellerActivation: { active: true, grantedBy: "admin-1" },
    marketplaceBusinessGenerationId: gen,
    pilotActiveProductCount: 0,
  });
  return { businessId, ownerUid: `owner-${businessId}`, generation: gen };
}

async function seedProduct(businessId, generation, overrides = {}) {
  const productId = overrides.productId || nextId("casc-prod");
  await db.collection("businesses").doc(businessId).collection("products").doc(productId).set({
    businessId,
    marketplaceBusinessGenerationId: generation,
    name: "Dry Food",
    price: 10,
    isActive: false,
    moderationStatus: "pending_review",
    ...overrides,
  });
  return productId;
}

function cleanup(businessId, productId, expectedGenerationId, extra = {}) {
  return db.runTransaction((tx) =>
    cleanupProductFirestoreState({
      db, tx, businessId, productId, expectedGenerationId,
      source: CLEANUP_SOURCE.MANUAL_DELETE, bucketName: BUCKET, ...extra,
    })
  );
}

async function exists(businessId, productId) {
  const s = await db.collection("businesses").doc(businessId)
    .collection("products").doc(productId).get();
  return s.exists;
}

// ---- 1 / 2 / 21: one shared primitive, no unbounded fan-out -----------
test("1+2. both deletion paths delegate to the one shared cleanup primitive", () => {
  const manual = fs.readFileSync(
    path.join(__dirname, "../src/marketplace/compliance/productDeletion.js"), "utf8");
  const cascade = fs.readFileSync(
    path.join(__dirname, "../src/marketplace/product/businessDeletionCascade.js"), "utf8");
  assert.match(manual, /cleanupProductFirestoreState/);
  assert.match(cascade, /cleanupProductFirestoreState/);
  // Neither path invokes the other over HTTP.
  assert.doesNotMatch(cascade, /httpsCallable|fetch\(|axios/);
  assert.doesNotMatch(manual, /httpsCallable|fetch\(|axios/);
});

test("21. the cascade uses no unbounded Promise.all and no full-collection read", () => {
  const src = fs.readFileSync(
    path.join(__dirname, "../src/marketplace/product/businessDeletionCascade.js"), "utf8");
  // Strip comments: the module names the anti-pattern in prose to explain
  // why it is avoided. What must be absent is a code occurrence.
  const code = src
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/\/\/[^\n]*/g, "");
  assert.doesNotMatch(code, /Promise\.all/);
  assert.match(src, /\.limit\(pageSize\)/);
  assert.match(src, /startAfter\(cursor\)/);
});

// ---- 3 / 4 / 17: delete, free the ID, idempotence --------------------
itest("3+4. cleanup deletes the product document and frees the deterministic ID", async () => {
  const { businessId, ownerUid, generation } = await seedBusiness();
  const submitted = await submitMarketplaceProduct({
    db, auth: { uid: ownerUid }, submissionFlagValue: "true",
    data: { businessId, sku: "FREE-SKU-1", sellerRelationship: "reseller",
            draft: { name: "Dry Food", price: 10 } },
  });
  assert.equal(await exists(businessId, submitted.productId), true);

  const result = await cleanup(businessId, submitted.productId, generation);
  assert.equal(result.outcome, CLEANUP_OUTCOME.DELETED);
  assert.equal(await exists(businessId, submitted.productId), false);

  const again = await submitMarketplaceProduct({
    db, auth: { uid: ownerUid }, submissionFlagValue: "true",
    data: { businessId, sku: "FREE-SKU-1", sellerRelationship: "reseller",
            draft: { name: "Dry Food", price: 10 } },
  });
  assert.equal(again.productId, submitted.productId, "the deterministic ID is unchanged");
});

itest("17. cleaning an absent product is idempotent success, not an error", async () => {
  const { businessId, generation } = await seedBusiness();
  const result = await cleanup(businessId, "never-existed", generation);
  assert.equal(result.outcome, CLEANUP_OUTCOME.ALREADY_ABSENT);
});

// ---- 5 / 6 / 23: submission behaviour around cleanup ------------------
itest("5. a same-generation duplicate before cleanup is still duplicate_sku", async () => {
  const { businessId, ownerUid } = await seedBusiness();
  const args = { businessId, sku: "DUP-BEFORE-1", sellerRelationship: "reseller",
                 draft: { name: "Dry Food", price: 10 } };
  await submitMarketplaceProduct({ db, auth: { uid: ownerUid }, submissionFlagValue: "true", data: args });
  await assert.rejects(
    submitMarketplaceProduct({ db, auth: { uid: ownerUid }, submissionFlagValue: "true", data: args }),
    (e) => e.details.reasonCode === SUBMIT_REASON.DUPLICATE_SKU
  );
});

itest("6+23. an uncleaned old-generation ID blocks the recreated business fail-closed", async () => {
  const { businessId, ownerUid, generation } = await seedBusiness();
  const productId = await seedProduct(businessId, generation, { sku: "OLD-GEN-1",
    productId: `${businessId}_OLD-GEN-1` });
  await db.collection("businesses").doc(businessId)
    .update({ marketplaceBusinessGenerationId: `gen2-${businessId}` });

  await assert.rejects(
    submitMarketplaceProduct({ db, auth: { uid: ownerUid }, submissionFlagValue: "true",
      data: { businessId, sku: "OLD-GEN-1", sellerRelationship: "reseller",
              draft: { name: "Dry Food", price: 10 } } }),
    (e) => e.details.reasonCode === SUBMIT_REASON.PREVIOUS_GENERATION_CLEANUP_PENDING
  );
  assert.equal(await exists(businessId, productId), true, "the old product is untouched");
});

// ---- 7 / 22: generation separation ------------------------------------
itest("7+22. an old-generation cascade never deletes new-generation products", async () => {
  const { businessId, generation } = await seedBusiness();
  const oldA = await seedProduct(businessId, generation);
  const oldB = await seedProduct(businessId, generation);
  const newGen = `gen2-${businessId}`;
  const newA = await seedProduct(businessId, newGen);
  // A product with no generation binding at all: ownership cannot be
  // proven, so it must be skipped rather than assumed to belong here.
  const unbound = nextId("casc-prod");
  await db.collection("businesses").doc(businessId).collection("products").doc(unbound).set({
    businessId, name: "Unbound", isActive: false, moderationStatus: "pending_review",
  });

  const result = await runBusinessDeletionCascade({
    db, businessId, deletedGeneration: generation, bucketName: BUCKET, pageSize: 2,
  });

  assert.equal(result.deleted, 2);
  assert.equal(result.skippedGenerationMismatch, 2, "new-generation and unbound are skipped");
  assert.equal(await exists(businessId, oldA), false);
  assert.equal(await exists(businessId, oldB), false);
  assert.equal(await exists(businessId, newA), true, "new generation survives");
  assert.equal(await exists(businessId, unbound), true, "unprovable binding survives");
});

// ---- 8 / 9 / 10 / 11 / 12: evidence handling --------------------------
itest("8+10+12. the product's own decision and links are removed", async () => {
  const { businessId, generation } = await seedBusiness();
  const productId = await seedProduct(businessId, generation);
  const { deriveEvidenceLinkId } = require("../src/marketplace/compliance/complianceMatching");
  const linkId = deriveEvidenceLinkId({ productId, documentId: "doc-1", scopeId: "scope-1" });
  await db.collection("productEvidenceLinks").doc(linkId).set({ productId, documentId: "doc-1" });
  await db.collection("productComplianceDecisions").doc(productId).set({
    businessId, activeEvidenceRefs: [{ documentId: "doc-1", scopeId: "scope-1" }],
  });
  await db.collection("complianceDocuments").doc("doc-1").set({ businessId, status: "approved" });

  const result = await cleanup(businessId, productId, generation);
  assert.equal(result.outcome, CLEANUP_OUTCOME.DELETED);
  assert.equal((await db.collection("productEvidenceLinks").doc(linkId).get()).exists, false);
  assert.equal((await db.collection("productComplianceDecisions").doc(productId).get()).exists, false);
  // 11. the shared compliance document itself is preserved.
  assert.equal((await db.collection("complianceDocuments").doc("doc-1").get()).exists, true);
});

itest("9. another product's evidence link is preserved", async () => {
  const { businessId, generation } = await seedBusiness();
  const target = await seedProduct(businessId, generation);
  const other = await seedProduct(businessId, `gen2-${businessId}`);
  const { deriveEvidenceLinkId } = require("../src/marketplace/compliance/complianceMatching");
  const otherLink = deriveEvidenceLinkId({ productId: other, documentId: "doc-2", scopeId: "scope-2" });
  await db.collection("productEvidenceLinks").doc(otherLink).set({ productId: other });
  await db.collection("productComplianceDecisions").doc(other).set({
    businessId, activeEvidenceRefs: [{ documentId: "doc-2", scopeId: "scope-2" }],
  });

  await cleanup(businessId, target, generation);
  assert.equal((await db.collection("productEvidenceLinks").doc(otherLink).get()).exists, true);
  assert.equal((await db.collection("productComplianceDecisions").doc(other).get()).exists, true);
});

// ---- 13 / 14: media provenance ---------------------------------------
test("13. media under the business's own products_raw prefix is deletable", () => {
  const businessId = "biz-1";
  const plan = resolveProductMediaObjects({
    product: { media: [{ originalUrl: mediaUrl(businessId, "a.jpg"), thumbnailUrl: mediaUrl(businessId, "a.jpg") }] },
    businessId, bucketName: BUCKET,
  });
  assert.deepEqual(plan.deletable, [`products_raw/${businessId}/a.jpg`], "deduplicated");
  assert.equal(plan.preserved.length, 0);
});

test("14. external, foreign-bucket, traversal and malformed references are never followed", () => {
  const businessId = "biz-1";
  const cases = [
    ["https://evil.example.com/x.jpg", MEDIA_PRESERVED_REASON.FOREIGN_HOST],
    [`https://firebasestorage.googleapis.com/v0/b/other-bucket/o/${encodeURIComponent("products_raw/biz-1/a.jpg")}`,
      MEDIA_PRESERVED_REASON.FOREIGN_BUCKET],
    [`https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent("products_raw/other-biz/a.jpg")}`,
      MEDIA_PRESERVED_REASON.OTHER_BUSINESS_PREFIX],
    [`https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent("secrets/keys.json")}`,
      MEDIA_PRESERVED_REASON.UNEXPECTED_PATH],
    [`https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent("products_raw/biz-1/../../etc")}`,
      MEDIA_PRESERVED_REASON.UNEXPECTED_PATH],
    ["not a url", MEDIA_PRESERVED_REASON.UNPARSEABLE_URL],
    [42, MEDIA_PRESERVED_REASON.NOT_A_STRING],
  ];
  for (const [url, reason] of cases) {
    const verdict = classifyMediaReference({ url, businessId, bucketName: BUCKET });
    assert.equal(verdict.deletable, false, `${url} must not be deletable`);
    assert.equal(verdict.reason, reason);
  }
});

itest("14b. an untrusted reference is recorded, by reason only, never as a URL", async () => {
  const { businessId, generation } = await seedBusiness();
  const productId = await seedProduct(businessId, generation, {
    media: [{ originalUrl: "https://evil.example.com/x.jpg" }],
  });
  const result = await cleanup(businessId, productId, generation);
  assert.equal(result.media.deletable.length, 0);
  assert.equal(result.media.preserved[0].reason, MEDIA_PRESERVED_REASON.FOREIGN_HOST);

  const audit = await db.collection(CLEANUP_AUDIT_COLLECTION)
    .where("productId", "==", productId).get();
  assert.equal(audit.size, 1);
  const record = audit.docs[0].data();
  assert.deepEqual(record.mediaPreservedReasons, [MEDIA_PRESERVED_REASON.FOREIGN_HOST]);
  assert.equal(JSON.stringify(record).includes("evil.example.com"), false, "no URL is stored");
});

// ---- 15 / 16: historical records --------------------------------------
itest("15+16. orders and financial records are never touched by cleanup", async () => {
  const { businessId, generation } = await seedBusiness();
  const productId = await seedProduct(businessId, generation);
  await db.collection("orders").doc(`order-${productId}`).set({
    businessId, items: [{ productId, name: "Dry Food", price: 10, quantity: 1 }],
  });
  await db.collection("sellerOrders").doc(`fin-${productId}`).set({ businessId, amount: 10 });

  await cleanup(businessId, productId, generation);
  const order = await db.collection("orders").doc(`order-${productId}`).get();
  assert.equal(order.exists, true);
  assert.equal(order.data().items[0].name, "Dry Food", "the immutable snapshot survives");
  assert.equal((await db.collection("sellerOrders").doc(`fin-${productId}`).get()).exists, true);
});

// ---- 18 / 19 / 20 / 25: delivery, retry, scale, auditability ---------
itest("18. a repeated cascade delivery is safe and does not double-process", async () => {
  const { businessId, generation } = await seedBusiness();
  await seedProduct(businessId, generation);
  const first = await runBusinessDeletionCascade({ db, businessId, deletedGeneration: generation, bucketName: BUCKET });
  assert.equal(first.deleted, 1);
  const second = await runBusinessDeletionCascade({ db, businessId, deletedGeneration: generation, bucketName: BUCKET });
  assert.equal(second.claimed, false);
  assert.equal(second.reason, "already_completed");
});

itest("19+25. a deadline-truncated cascade persists a resumable, auditable state", async () => {
  const { businessId, generation } = await seedBusiness();
  for (let i = 0; i < 6; i += 1) await seedProduct(businessId, generation);

  // deadlineMs 0 stops after the first product, leaving the rest.
  const partial = await runBusinessDeletionCascade({
    db, businessId, deletedGeneration: generation, bucketName: BUCKET, pageSize: 2, deadlineMs: 0,
  });
  assert.equal(partial.status, CASCADE_STATUS.IN_PROGRESS);
  const state = await cascadeStateRef(db, businessId, generation).get();
  assert.equal(state.data().status, CASCADE_STATUS.IN_PROGRESS);
  assert.ok(state.data().cursor, "a continuation cursor is persisted");
  assert.equal(state.data().leaseOwner, null, "the lease is released for the resumer");

  // The starvation fix backs an unfinished cascade off, so it is not due
  // immediately. Nothing is due now...
  const notYet = await resumeIncompleteBusinessDeletionCascades({ db, bucketName: BUCKET });
  assert.equal(notYet.considered, 0, "an unfinished cascade backs off before retry");

  // ...and it becomes due once the backoff elapses.
  const later = () => new Date(Date.now() + 5 * 60 * 1000);
  const resumed = await resumeIncompleteBusinessDeletionCascades({
    db, bucketName: BUCKET, now: later,
  });
  assert.ok(resumed.considered >= 1);
  const after = await db.collection("businesses").doc(businessId).collection("products").get();
  assert.equal(after.size, 0, "resumption completes the remaining work");
});

itest("20. more than 500 products are paginated, not loaded at once", async () => {
  const { businessId, generation } = await seedBusiness();
  const total = 520;
  for (let start = 0; start < total; start += 500) {
    const batch = db.batch();
    for (let i = start; i < Math.min(start + 500, total); i += 1) {
      batch.set(
        db.collection("businesses").doc(businessId).collection("products").doc(`p-${String(i).padStart(4, "0")}`),
        { businessId, marketplaceBusinessGenerationId: generation, isActive: false,
          moderationStatus: "pending_review" }
      );
    }
    await batch.commit();
  }
  const result = await runBusinessDeletionCascade({
    db, businessId, deletedGeneration: generation, bucketName: BUCKET, pageSize: 100,
  });
  assert.equal(result.examined, total);
  assert.equal(result.deleted, total);
  const remaining = await db.collection("businesses").doc(businessId).collection("products").get();
  assert.equal(remaining.size, 0);
});

// ---- 24: failure leaves the product non-public ------------------------
itest("24. a product whose cleanup fails stays present and non-public", async () => {
  const { businessId, generation } = await seedBusiness();
  const productId = await seedProduct(businessId, generation, { isActive: false });
  // A structurally malformed decision makes the shared primitive fail closed.
  await db.collection("productComplianceDecisions").doc(productId).set({
    businessId, activeEvidenceRefs: "not-an-array",
  });

  const result = await runBusinessDeletionCascade({
    db, businessId, deletedGeneration: generation, bucketName: BUCKET,
  });
  assert.equal(result.productFailures, 1);
  assert.equal(result.status, CASCADE_STATUS.FAILED_RETRYABLE);

  const snap = await db.collection("businesses").doc(businessId)
    .collection("products").doc(productId).get();
  assert.equal(snap.exists, true);
  assert.equal(snap.data().isActive, false, "still non-public");
});

// ---- generation authority ---------------------------------------------
itest("the primitive proves generation from the product's own binding", async () => {
  const { businessId, generation } = await seedBusiness();
  const productId = await seedProduct(businessId, generation);
  const wrong = await cleanup(businessId, productId, `gen-other`);
  assert.equal(wrong.outcome, CLEANUP_OUTCOME.SKIPPED_GENERATION_MISMATCH);
  assert.equal(await exists(businessId, productId), true);
});

itest("a product located under the business but bound to another business is skipped", async () => {
  const { businessId, generation } = await seedBusiness();
  const productId = await seedProduct(businessId, generation, { businessId: "someone-else" });
  const result = await cleanup(businessId, productId, generation);
  assert.equal(result.outcome, CLEANUP_OUTCOME.SKIPPED_BUSINESS_MISMATCH);
  assert.equal(await exists(businessId, productId), true);
});
