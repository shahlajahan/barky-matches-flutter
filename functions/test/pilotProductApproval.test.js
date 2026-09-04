"use strict";

// Marketplace P1-A Revision 28 (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §10.1 "Pilot Product Approval
// contract", §13.1, §15 items 781-935). Exercises the exported onCall
// wrappers via their .run() test helper (same established pattern as
// productDeletion.test.js), against a real Firestore emulator, seeding
// businesses/products directly via the Admin SDK exactly as production
// data would look — never through Firestore Rules, which never apply to
// this server-side path.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();
const functions = require("../index");
const {
  computeContentFingerprint,
  computeApprovalFingerprint,
  pilotApprovalBoundFields,
  AUDIT_EVENTS_COLLECTION,
} = require("../src/marketplace/compliance/pilotProductApproval");

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function itest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

let seq = 0;
function nextId(prefix) {
  seq += 1;
  return `${prefix}-${Date.now()}-${seq}`;
}

function baseProduct(overrides = {}) {
  return {
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
  };
}

async function seedBusiness(overrides = {}) {
  const businessId = nextId("pilot-biz");
  await db.collection("businesses").doc(businessId).set({
    ownerUid: overrides.ownerUid || `owner-${businessId}`,
    marketplaceSellerActivation: { active: true, grantedAt: null, grantedBy: "admin-1", revokedAt: null, revokedBy: null },
    marketplaceBusinessGenerationId: `gen-${businessId}`,
    pilotActiveProductCount: 0,
    ...overrides,
  });
  return businessId;
}

async function seedProduct(businessId, overrides = {}) {
  const productId = overrides.productId || nextId("pilot-prod");
  const businessSnap = await db.collection("businesses").doc(businessId).get();
  await db
    .collection("businesses")
    .doc(businessId)
    .collection("products")
    .doc(productId)
    .set(
      baseProduct({
        businessId,
        marketplaceBusinessGenerationId: businessSnap.data().marketplaceBusinessGenerationId,
        ...overrides,
      })
    );
  // Marketplace Revision 30 §H (Slice 6): approval now requires a positive
  // canonical compliance decision, and the approval fingerprint binds its
  // identity. Every product that is expected to reach approval therefore
  // needs one, exactly as production does. Tests that exercise the DECISION
  // gate itself override or delete this deliberately.
  await seedPositiveDecision(businessId, productId);
  return productId;
}

async function seedPositiveDecision(businessId, productId, overrides = {}) {
  await db
    .collection("productComplianceDecisions")
    .doc(productId)
    .set({
      businessId,
      policyVersion: `policy-${productId}`,
      evidenceRevision: 0,
      decisionHash: `hash-${productId}`,
      effectiveStatus: "verified_valid",
      activeEvidenceRefs: [
        {
          documentId: `doc-${productId}`,
          scopeId: `scope-${productId}`,
          expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 365 * 86400000),
        },
      ],
      validUntil: admin.firestore.Timestamp.fromMillis(Date.now() + 365 * 86400000),
      ...overrides,
    });
}

async function seedAdmin(uid = "admin-1") {
  await db.collection("users").doc(uid).set({ role: "admin" });
  return uid;
}

async function getProduct(businessId, productId) {
  const snap = await db.collection("businesses").doc(businessId).collection("products").doc(productId).get();
  return snap.data();
}

async function getBusiness(businessId) {
  const snap = await db.collection("businesses").doc(businessId).get();
  return snap.data();
}

function callApprove(args) {
  return functions.approvePilotProduct.run({ auth: args.uid ? { uid: args.uid } : null, data: args.data });
}
function callRevoke(args) {
  return functions.revokePilotProductApproval.run({ auth: args.uid ? { uid: args.uid } : null, data: args.data });
}
function callUnpublish(args) {
  return functions.unpublishPilotProductForRevision.run({ auth: args.uid ? { uid: args.uid } : null, data: args.data });
}

async function approvalPayloadFor(businessId, productId) {
  const product = await getProduct(businessId, productId);
  // Slice 6: the fingerprint binds the effective decision as well as the
  // reviewed content, so it is computed from BOTH canonical records.
  const decSnap = await db.collection("productComplianceDecisions").doc(productId).get();
  return {
    businessId,
    productId,
    allowedPilotCategory: "food",
    reviewedContentFingerprint: computeApprovalFingerprint(
      product,
      decSnap.exists ? decSnap.data() : null
    ),
    attestNoProhibitedClaim: true,
  };
}

// ---------------------------------------------------------------------
// approvePilotProduct
// ---------------------------------------------------------------------

itest("1. a real approval succeeds and sets the complete visible state", async () => {
  await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const payload = await approvalPayloadFor(businessId, productId);

  const result = await callApprove({ uid: "admin-1", data: payload });
  assert.equal(result.active, true);
  assert.equal(result.idempotent, false);

  const product = await getProduct(businessId, productId);
  assert.equal(product.isActive, true);
  assert.equal(product.moderationStatus, "approved");
  assert.equal(product.pilotProductApproval.active, true);
  assert.equal(product.pilotProductApproval.approvedBy, "admin-1");
  assert.equal(product.pilotProductApproval.allowedPilotCategory, "food");
  assert.equal(product.pilotProductApproval.reasonCode, "pilot_approved");

  const business = await getBusiness(businessId);
  assert.equal(business.pilotActiveProductCount, 1);
});

itest("2. a non-admin caller is denied", async () => {
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const payload = await approvalPayloadFor(businessId, productId);
  await assert.rejects(callApprove({ uid: "not-admin", data: payload }));
});

itest("3. redundant approval with an unchanged fingerprint is a true no-op idempotent replay", async () => {
  await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const payload = await approvalPayloadFor(businessId, productId);
  await callApprove({ uid: "admin-1", data: payload });

  const eventsBefore = (await db.collection(AUDIT_EVENTS_COLLECTION).where("productId", "==", productId).get()).size;
  const result = await callApprove({ uid: "admin-1", data: payload });
  assert.equal(result.idempotent, true);
  const eventsAfter = (await db.collection(AUDIT_EVENTS_COLLECTION).where("productId", "==", productId).get()).size;
  assert.equal(eventsAfter, eventsBefore, "no new audit event on idempotent replay");

  const business = await getBusiness(businessId);
  assert.equal(business.pilotActiveProductCount, 1, "counter unchanged on idempotent replay");
});

itest("4. approval with a stale fingerprint is denied — the live content changed since the caller last reviewed it", async () => {
  await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const payload = await approvalPayloadFor(businessId, productId);
  // Mutate a bound field directly (Admin SDK, bypasses Rules) after the
  // caller computed their own fingerprint.
  await db.collection("businesses").doc(businessId).collection("products").doc(productId).update({ name: "Different Name" });
  await assert.rejects(callApprove({ uid: "admin-1", data: payload }), /stale/i);
});

itest("5. approval against a business whose generation does not match the product's own is denied", async () => {
  await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  await db.collection("businesses").doc(businessId).update({ marketplaceBusinessGenerationId: "a-new-generation" });
  const payload = await approvalPayloadFor(businessId, productId);
  await assert.rejects(callApprove({ uid: "admin-1", data: payload }));
});

itest("6. approval against an inactive seller is denied", async () => {
  await seedAdmin();
  const businessId = await seedBusiness();
  await db.collection("businesses").doc(businessId).update({ "marketplaceSellerActivation.active": false });
  const productId = await seedProduct(businessId);
  const payload = await approvalPayloadFor(businessId, productId);
  await assert.rejects(callApprove({ uid: "admin-1", data: payload }));
});

itest("7. approval against a business already at the 5-product limit is denied, writing nothing", async () => {
  await seedAdmin();
  const businessId = await seedBusiness();
  await db.collection("businesses").doc(businessId).update({ pilotActiveProductCount: 5 });
  const productId = await seedProduct(businessId);
  const payload = await approvalPayloadFor(businessId, productId);
  await assert.rejects(callApprove({ uid: "admin-1", data: payload }));
  const product = await getProduct(businessId, productId);
  assert.equal(product.pilotProductApproval, undefined);
});

itest("8. approval against a business with a malformed counter is denied, fails closed", async () => {
  await seedAdmin();
  const businessId = await seedBusiness();
  await db.collection("businesses").doc(businessId).update({ pilotActiveProductCount: "not-a-number" });
  const productId = await seedProduct(businessId);
  const payload = await approvalPayloadFor(businessId, productId);
  await assert.rejects(callApprove({ uid: "admin-1", data: payload }));
});

itest("9. approval against a nonexistent business fails closed with not-found", async () => {
  await seedAdmin();
  await assert.rejects(
    callApprove({
      uid: "admin-1",
      data: { businessId: "no-such-business", productId: "no-such-product", allowedPilotCategory: "food", reviewedContentFingerprint: "x", attestNoProhibitedClaim: true },
    })
  );
});

itest("10. approval requires the literal boolean true for attestNoProhibitedClaim", async () => {
  await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const payload = await approvalPayloadFor(businessId, productId);
  payload.attestNoProhibitedClaim = "true";
  await assert.rejects(callApprove({ uid: "admin-1", data: payload }));
});

itest("11. approval requires a closed-enum allowedPilotCategory", async () => {
  await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  const payload = await approvalPayloadFor(businessId, productId);
  payload.allowedPilotCategory = "harnesses";
  await assert.rejects(callApprove({ uid: "admin-1", data: payload }));
});

itest("12. concurrent approvals from 4 to 5 allow exactly one to the limit, never both to 6", async () => {
  await seedAdmin();
  const businessId = await seedBusiness();
  await db.collection("businesses").doc(businessId).update({ pilotActiveProductCount: 4 });
  const productIdA = await seedProduct(businessId, { productId: nextId("concurrent-a") });
  const productIdB = await seedProduct(businessId, { productId: nextId("concurrent-b") });
  const payloadA = await approvalPayloadFor(businessId, productIdA);
  const payloadB = await approvalPayloadFor(businessId, productIdB);

  const results = await Promise.allSettled([
    callApprove({ uid: "admin-1", data: payloadA }),
    callApprove({ uid: "admin-1", data: payloadB }),
  ]);
  const succeeded = results.filter((r) => r.status === "fulfilled");
  const failed = results.filter((r) => r.status === "rejected");
  assert.equal(succeeded.length, 1, "exactly one of the two concurrent approvals succeeds");
  assert.equal(failed.length, 1);

  const business = await getBusiness(businessId);
  assert.equal(business.pilotActiveProductCount, 5, "counter never exceeds the limit");
});

// ---------------------------------------------------------------------
// revokePilotProductApproval
// ---------------------------------------------------------------------

itest("13. admin revocation restores a fail-closed, non-visible state and decrements the counter", async () => {
  await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  await callApprove({ uid: "admin-1", data: await approvalPayloadFor(businessId, productId) });

  const result = await callRevoke({
    uid: "admin-1",
    data: { businessId, productId, reasonCode: "pilot_revoked_admin_manual" },
  });
  assert.equal(result.active, false);
  assert.equal(result.idempotent, false);

  const product = await getProduct(businessId, productId);
  assert.equal(product.isActive, false);
  assert.equal(product.moderationStatus, "pending_review");
  assert.equal(product.pilotProductApproval.active, false);
  assert.equal(product.pilotProductApproval.revokedByKind, "admin");
  assert.equal(product.pilotProductApproval.revokedBy, "admin-1");
  // Preserved across revocation, per the frozen schema.
  assert.equal(product.pilotProductApproval.approvedBy, "admin-1");

  const business = await getBusiness(businessId);
  assert.equal(business.pilotActiveProductCount, 0);
});

itest("14. redundant revocation is a true no-op idempotent replay", async () => {
  await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  await callApprove({ uid: "admin-1", data: await approvalPayloadFor(businessId, productId) });
  await callRevoke({ uid: "admin-1", data: { businessId, productId, reasonCode: "pilot_revoked_admin_manual" } });
  const result = await callRevoke({ uid: "admin-1", data: { businessId, productId, reasonCode: "pilot_revoked_admin_manual" } });
  assert.equal(result.idempotent, true);
  const business = await getBusiness(businessId);
  assert.equal(business.pilotActiveProductCount, 0, "no double-decrement on redundant revocation");
});

itest("15. revoke rejects a reasonCode outside its own closed enum", async () => {
  await seedAdmin();
  const businessId = await seedBusiness();
  const productId = await seedProduct(businessId);
  await callApprove({ uid: "admin-1", data: await approvalPayloadFor(businessId, productId) });
  await assert.rejects(
    callRevoke({ uid: "admin-1", data: { businessId, productId, reasonCode: "pilot_revoked_business_deleted" } })
  );
});

// ---------------------------------------------------------------------
// unpublishPilotProductForRevision — seller-authorized, not admin
// ---------------------------------------------------------------------

itest("16. the owning seller can unpublish their own approved product for revision", async () => {
  const businessId = await seedBusiness({ ownerUid: "seller-16" });
  await seedAdmin();
  const productId = await seedProduct(businessId);
  await callApprove({ uid: "admin-1", data: await approvalPayloadFor(businessId, productId) });

  const result = await callUnpublish({ uid: "seller-16", data: { businessId, productId } });
  assert.equal(result.active, false);
  assert.equal(result.idempotent, false);

  const product = await getProduct(businessId, productId);
  assert.equal(product.isActive, false);
  assert.equal(product.pilotProductApproval.active, false);
  assert.equal(product.pilotProductApproval.revokedByKind, "seller_self_revision");
  assert.equal(product.pilotProductApproval.revokedBy, null);

  const business = await getBusiness(businessId);
  assert.equal(business.pilotActiveProductCount, 0);
});

itest("17. a non-owner is denied unpublish for someone else's product", async () => {
  const businessId = await seedBusiness({ ownerUid: "seller-owner-17" });
  await seedAdmin();
  const productId = await seedProduct(businessId);
  await callApprove({ uid: "admin-1", data: await approvalPayloadFor(businessId, productId) });
  await assert.rejects(callUnpublish({ uid: "seller-intruder-17", data: { businessId, productId } }));
});

itest("18. unpublish on an already-inactive product is a true no-op idempotent replay", async () => {
  const businessId = await seedBusiness({ ownerUid: "seller-18" });
  const productId = await seedProduct(businessId);
  const result = await callUnpublish({ uid: "seller-18", data: { businessId, productId } });
  assert.equal(result.idempotent, true);
});

// ---------------------------------------------------------------------
// deleteMarketplaceProduct / productDeletion.js — pilot-decrement
// integration
// ---------------------------------------------------------------------

itest("19. deleting an active pilot-approved product decrements the counter and writes a terminal audit event", async () => {
  const businessId = await seedBusiness({ ownerUid: "seller-19" });
  await seedAdmin();
  const productId = await seedProduct(businessId);
  await callApprove({ uid: "admin-1", data: await approvalPayloadFor(businessId, productId) });

  await functions.deleteMarketplaceProduct.run({
    auth: { uid: "seller-19" },
    data: { businessId, productId, clientIdempotencyKey: nextId("del-key") },
  });

  const business = await getBusiness(businessId);
  assert.equal(business.pilotActiveProductCount, 0);
  const events = await db
    .collection(AUDIT_EVENTS_COLLECTION)
    .where("productId", "==", productId)
    .where("action", "==", "cascade_revoke")
    .get();
  assert.equal(events.size, 1);
});

itest("20. deleting a never-approved product leaves the counter untouched", async () => {
  const businessId = await seedBusiness({ ownerUid: "seller-20" });
  const productId = await seedProduct(businessId);
  await functions.deleteMarketplaceProduct.run({
    auth: { uid: "seller-20" },
    data: { businessId, productId, clientIdempotencyKey: nextId("del-key") },
  });
  const business = await getBusiness(businessId);
  assert.equal(business.pilotActiveProductCount, 0);
});

// ---------------------------------------------------------------------
// Fingerprint canonicalization
// ---------------------------------------------------------------------

itest("21. the content fingerprint is deterministic regardless of source object key order", () => {
  const a = { name: "X", price: 1, media: [{ type: "image", originalUrl: "u" }] };
  const b = { price: 1, media: [{ type: "image", originalUrl: "u" }], name: "X" };
  assert.equal(computeContentFingerprint(a), computeContentFingerprint(b));
});

itest("22. the content fingerprint changes when a bound field's nested content changes", () => {
  const a = { name: "X", media: [{ type: "image", originalUrl: "u1" }] };
  const b = { name: "X", media: [{ type: "image", originalUrl: "u2" }] };
  assert.notEqual(computeContentFingerprint(a), computeContentFingerprint(b));
});

itest("23. the content fingerprint ignores non-bound fields", () => {
  const a = { name: "X", stock: 5 };
  const b = { name: "X", stock: 999 };
  assert.equal(computeContentFingerprint(a), computeContentFingerprint(b));
});

itest("24. pilotApprovalBoundFields() matches the frozen 11-field set exactly", () => {
  assert.deepEqual(
    [...pilotApprovalBoundFields()].sort(),
    ["barcode", "brand", "category", "currency", "description", "kdvRate", "media", "name", "price", "salePrice", "sellerRelationship"].sort()
  );
});
