"use strict";

// Marketplace Revision 36 — `getPilotProductApprovalReadiness`, the
// server-authoritative Admin approval handshake.
//
// Everything here runs the REAL engine (`recomputeProductComplianceStatus` ->
// `runComplianceMatching` -> `resolveActivePolicy`) against the Firestore
// emulator with clearly-labelled SYNTHETIC fixtures, so a `ready: true` result
// is produced by a genuinely valid world rather than by a hand-planted
// decision that no real path could have written. No policy is ever activated
// in production; the registry rows below live only inside the emulator.

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
  recomputeProductComplianceStatus,
} = require("../src/marketplace/compliance/complianceProductRecompute");
const {
  buildRevision30PolicyVersion,
} = require("../src/marketplace/compliance/complianceRevision30Policy");
const {
  computeApprovalFingerprint,
  computeContentFingerprint,
} = require("../src/marketplace/compliance/pilotProductApproval");
const {
  READINESS_ALLOWED_FIELDS,
  READINESS_REASON,
} = require("../src/marketplace/compliance/pilotProductApprovalReadiness");
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
const RUN = `rdy${Math.random().toString(36).slice(2, 8)}`;
const nextId = (p) => {
  seq += 1;
  return `${p}-${RUN}-${seq}`;
};

const FUTURE = () => admin.firestore.Timestamp.fromMillis(Date.now() + 365 * 86400000);
const PAST = () => admin.firestore.Timestamp.fromMillis(Date.now() - 86400000);

function callReadiness({ uid, data }) {
  return functions.getPilotProductApprovalReadiness.run({
    auth: uid ? { uid } : null,
    data,
  });
}

function callApprove({ uid, data }) {
  return functions.approvePilotProduct.run({ auth: uid ? { uid } : null, data });
}

async function seedUser(role) {
  const uid = nextId(role || "anon-role");
  await db.collection("users").doc(uid).set(role ? { role } : {});
  return uid;
}

/// EMULATOR-ONLY synthetic active policy — identical construction to the
/// Slice 5 suite's own fixture.
async function seedSyntheticActivePolicy() {
  const versionId = nextId("synthetic-policy");
  await db
    .collection("compliancePolicyRegistry")
    .doc(versionId)
    .set(
      buildRevision30PolicyVersion({
        createdBy: "emulator-test-fixture",
        effectiveFrom: PAST(),
        createdAt: PAST(),
        changeNote: "SYNTHETIC emulator-only Revision 30 §D transcription",
        status: COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE,
      })
    );
  await db
    .collection("compliancePolicyRegistryPointer")
    .doc("current")
    .set({ activeVersionId: versionId });
  return versionId;
}

/// A complete, internally consistent, genuinely approvable world: active
/// policy, activated seller, classified product, approved evidence and scope,
/// and a decision produced by the real recompute engine.
async function seedApprovableWorld({
  productOverrides = {},
  businessOverrides = {},
  relationship = SELLER_RELATIONSHIP.RESELLER,
  documentType = COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE,
  recompute = true,
} = {}) {
  const policyVersion = await seedSyntheticActivePolicy();
  const businessId = nextId("rdy-biz");
  const productId = nextId("rdy-prod");
  const generationId = `gen-${businessId}`;

  await db
    .collection("businesses")
    .doc(businessId)
    .set({
      ownerUid: nextId("seller"),
      marketplaceSellerActivation: { active: true },
      marketplaceBusinessGenerationId: generationId,
      pilotActiveProductCount: 0,
      ...businessOverrides,
    });

  await db
    .collection("businesses")
    .doc(businessId)
    .collection("products")
    .doc(productId)
    .set({
      businessId,
      marketplaceBusinessGenerationId: generationId,
      name: "Sealed Dry Dog Food",
      description: "Ordinary packaged dog food.",
      price: 100,
      currency: "TRY",
      media: [{ type: "image", originalUrl: "https://example.test/1.jpg" }],
      category: "Food > Dry Food",
      brand: "ACME",
      barcode: "1234567890",
      salePrice: null,
      kdvRate: 10,
      sellerRelationship: relationship,
      sku: "SKU-1",
      productInputRevision: 0,
      stock: 5,
      isActive: false,
      moderationStatus: "pending_review",
      pilotProductClass: PILOT_PRODUCT_CLASS.SEALED_DRY_FOOD,
      ...productOverrides,
    });

  const documentId = nextId("doc");
  const validUntil = FUTURE();
  await db.collection("complianceDocuments").doc(documentId).set({
    businessId,
    marketplaceBusinessGenerationId: generationId,
    documentType,
    sellerRelationship: relationship,
    status: COMPLIANCE_DOCUMENT_STATUS.APPROVED,
    validUntil,
    contentHash: `hash-${documentId}`,
    storagePath: `compliance_docs/${businessId}/${documentId}/o.pdf`,
  });
  await db.collection("complianceDocumentScopes").doc(nextId("scope")).set({
    businessId,
    documentId,
    sellerRelationship: relationship,
    documentType,
    scopeType: COMPLIANCE_SCOPE_TYPE.PRODUCT,
    scopeValue: productId,
    status: COMPLIANCE_SCOPE_STATUS.APPROVED,
    approvedAt: PAST(),
    validUntil,
  });

  if (recompute) {
    await recomputeProductComplianceStatus({ db, businessId, productId });
  }
  return { businessId, productId, generationId, documentId, policyVersion };
}

const productRef = (b, p) =>
  db.collection("businesses").doc(b).collection("products").doc(p);
const decisionRef = (p) => db.collection("productComplianceDecisions").doc(p);
const getProduct = async (b, p) => (await productRef(b, p).get()).data();
const getBusiness = async (b) => (await db.collection("businesses").doc(b).get()).data();

async function expectThrows(promise, code) {
  let error = null;
  try {
    await promise;
  } catch (e) {
    error = e;
  }
  assert.ok(error, "expected the call to fail, but it resolved");
  if (code) assert.equal(error.code, code, `unexpected code ${error.code}`);
  return error;
}

// =====================================================================
// A. Authorization — items 1-5.
// =====================================================================

itest("1. an unauthenticated caller is denied readiness", async () => {
  const { businessId, productId } = await seedApprovableWorld();
  await expectThrows(
    callReadiness({ uid: null, data: { businessId, productId } }),
    "unauthenticated"
  );
});

itest("2. a seller is denied readiness", async () => {
  const { businessId, productId } = await seedApprovableWorld();
  const seller = await seedUser("seller");
  await expectThrows(
    callReadiness({ uid: seller, data: { businessId, productId } }),
    "permission-denied"
  );
});

itest("3. a customer (no role at all) is denied readiness", async () => {
  const { businessId, productId } = await seedApprovableWorld();
  const customer = await seedUser(null);
  await expectThrows(
    callReadiness({ uid: customer, data: { businessId, productId } }),
    "permission-denied"
  );
});

itest("4. the owning business's own uid is denied readiness — ownership is not admin", async () => {
  const { businessId, productId } = await seedApprovableWorld();
  const business = await getBusiness(businessId);
  await db.collection("users").doc(business.ownerUid).set({ role: "seller" });
  await expectThrows(
    callReadiness({ uid: business.ownerUid, data: { businessId, productId } }),
    "permission-denied"
  );
  // And an admin of nothing in particular — a moderator — is equally denied.
  const moderator = await seedUser("moderator");
  await expectThrows(
    callReadiness({ uid: moderator, data: { businessId, productId } }),
    "permission-denied"
  );
});

itest("5. an admin is allowed, and authorization precedes any disclosure", async () => {
  const adminUid = await seedUser("admin");
  // A product that does not exist at all: a non-admin must still be refused
  // with permission-denied, never told whether it exists.
  const seller = await seedUser("seller");
  const ghost = { businessId: nextId("ghost-biz"), productId: nextId("ghost-prod") };
  const denied = await expectThrows(callReadiness({ uid: seller, data: ghost }), "permission-denied");
  assert.equal(denied.code, "permission-denied");
  const asAdmin = await callReadiness({ uid: adminUid, data: ghost });
  assert.equal(asAdmin.ready, false);
  assert.equal(asAdmin.reasonCode, READINESS_REASON.BUSINESS_NOT_FOUND);
});

// =====================================================================
// B. The happy path and the fingerprint's identity — items 6, 7.
// =====================================================================

itest("6. a genuinely valid product returns ready with a fingerprint and a bounded summary", async () => {
  const adminUid = await seedUser("admin");
  const { businessId, productId } = await seedApprovableWorld();
  const result = await callReadiness({ uid: adminUid, data: { businessId, productId } });

  assert.equal(result.ready, true, `expected ready, got ${result.reasonCode}`);
  assert.equal(result.reasonCode, null);
  assert.equal(typeof result.approvalFingerprint, "string");
  assert.equal(result.approvalFingerprint.length, 64);
  assert.equal(result.pilotProductClass, "sealed_dry_food");
  assert.equal(result.decisionStatus, "verified_valid");
  assert.equal(typeof result.decisionValidUntilMillis, "number");
  assert.ok(result.activeEvidenceCount >= 1);

  // The response is a closed, bounded shape — no paths, no urls, no uids.
  assert.deepEqual(Object.keys(result).sort(), [
    "activeEvidenceCount",
    "approvalFingerprint",
    "businessId",
    "decisionStatus",
    "decisionValidUntilMillis",
    "pilotProductClass",
    "productId",
    "ready",
    "reasonCode",
  ]);
  const serialized = JSON.stringify(result);
  const business = await getBusiness(businessId);
  for (const forbidden of [business.ownerUid, "compliance_docs/", "storagePath", "https://", "googleapis"]) {
    assert.equal(serialized.includes(forbidden), false, `leaked ${forbidden}`);
  }
});

itest("7. the returned value is exactly the canonical eleven-input server fingerprint, and is NOT the content fingerprint", async () => {
  const adminUid = await seedUser("admin");
  const { businessId, productId } = await seedApprovableWorld();
  const result = await callReadiness({ uid: adminUid, data: { businessId, productId } });

  const product = await getProduct(businessId, productId);
  const decision = (await decisionRef(productId).get()).data();
  assert.equal(
    result.approvalFingerprint,
    computeApprovalFingerprint(product, decision, productId),
    "readiness must return the canonical approval fingerprint"
  );
  // The legacy value the Admin page used to send can never be mistaken for it.
  assert.notEqual(result.approvalFingerprint, computeContentFingerprint(product));

  // And it is the value approval actually accepts — the whole point.
  const approved = await callApprove({
    uid: adminUid,
    data: {
      businessId,
      productId,
      allowedPilotCategory: "food",
      reviewedContentFingerprint: result.approvalFingerprint,
      attestNoProhibitedClaim: true,
    },
  });
  assert.equal(approved.active, true);
});

itest("7b. REGRESSION: the content fingerprint the Admin page used to send is always rejected as stale", async () => {
  const adminUid = await seedUser("admin");
  const { businessId, productId } = await seedApprovableWorld();
  const product = await getProduct(businessId, productId);
  const error = await expectThrows(
    callApprove({
      uid: adminUid,
      data: {
        businessId,
        productId,
        allowedPilotCategory: "food",
        // Exactly what the page computed before this repair.
        reviewedContentFingerprint: computeContentFingerprint(product),
        attestNoProhibitedClaim: true,
      },
    }),
    "failed-precondition"
  );
  assert.equal(error.details.reasonCode, "stale-content");
  assert.equal((await getProduct(businessId, productId)).isActive, false);
});

// =====================================================================
// C. Blocking states — items 8-18.
// =====================================================================

itest("8. a product with no classification is blocked, distinctly from an unsupported one", async () => {
  const adminUid = await seedUser("admin");
  const { businessId, productId } = await seedApprovableWorld();
  await productRef(businessId, productId).update({
    pilotProductClass: admin.firestore.FieldValue.delete(),
  });
  const result = await callReadiness({ uid: adminUid, data: { businessId, productId } });
  assert.equal(result.ready, false);
  assert.equal(result.reasonCode, READINESS_REASON.CLASS_MISSING);
  assert.equal(result.approvalFingerprint, null);
  assert.equal(result.pilotProductClass, null);
});

itest("9. a product carrying an unsupported class is blocked with its own reason", async () => {
  const adminUid = await seedUser("admin");
  for (const bad of ["vitamins", "SEALED_DRY_FOOD", "food", "sealed_dry_food "]) {
    const { businessId, productId } = await seedApprovableWorld();
    await productRef(businessId, productId).update({ pilotProductClass: bad });
    const result = await callReadiness({ uid: adminUid, data: { businessId, productId } });
    assert.equal(result.ready, false, bad);
    assert.equal(result.reasonCode, READINESS_REASON.CLASS_UNSUPPORTED, bad);
    assert.equal(result.approvalFingerprint, null);
  }
});

itest("10. a missing compliance decision is blocked", async () => {
  const adminUid = await seedUser("admin");
  const { businessId, productId } = await seedApprovableWorld();
  await decisionRef(productId).delete();
  const result = await callReadiness({ uid: adminUid, data: { businessId, productId } });
  assert.equal(result.ready, false);
  assert.equal(result.reasonCode, READINESS_REASON.DECISION_MISSING);
  assert.equal(result.approvalFingerprint, null);
});

itest("11. an expired decision is blocked", async () => {
  const adminUid = await seedUser("admin");
  const { businessId, productId } = await seedApprovableWorld();
  await decisionRef(productId).update({ validUntil: PAST() });
  const result = await callReadiness({ uid: adminUid, data: { businessId, productId } });
  assert.equal(result.ready, false);
  assert.equal(result.reasonCode, READINESS_REASON.DECISION_EXPIRED);
});

itest("12. a decision belonging to another business is blocked as a product mismatch", async () => {
  const adminUid = await seedUser("admin");
  const { businessId, productId } = await seedApprovableWorld();
  await decisionRef(productId).update({ businessId: nextId("other-biz") });
  const result = await callReadiness({ uid: adminUid, data: { businessId, productId } });
  assert.equal(result.ready, false);
  assert.equal(result.reasonCode, READINESS_REASON.DECISION_PRODUCT_MISMATCH);
});

itest("13. a sibling product's decision replayed onto this product is blocked", async () => {
  const adminUid = await seedUser("admin");
  const a = await seedApprovableWorld();
  const b = await seedApprovableWorld();
  const aRef = { businessId: a.businessId, productId: a.productId };
  // Each seedApprovableWorld() activates its own synthetic policy version, so
  // seeding B leaves A's decision computed under a superseded policy — which
  // test 17 proves is itself a blocking condition. Recomputing A under the
  // now-current pointer isolates THIS test's subject instead of re-testing
  // the policy check.
  await recomputeProductComplianceStatus({
    db,
    businessId: a.businessId,
    productId: a.productId,
  });
  // Both are individually ready.
  assert.equal((await callReadiness({ uid: adminUid, data: aRef })).ready, true);

  // Copy sibling B's decision content onto A's decision document. The
  // document id is A's productId, so this is the closest a replay can get.
  const bDecision = (await decisionRef(b.productId).get()).data();
  await decisionRef(a.productId).set(bDecision);

  const result = await callReadiness({ uid: adminUid, data: aRef });
  assert.equal(result.ready, false);
  assert.equal(result.reasonCode, READINESS_REASON.DECISION_PRODUCT_MISMATCH);
});

itest("14. a stale product generation is blocked, as is an uninitialized business generation", async () => {
  const adminUid = await seedUser("admin");

  const stale = await seedApprovableWorld();
  await productRef(stale.businessId, stale.productId).update({
    marketplaceBusinessGenerationId: "gen-previous",
  });
  const r1 = await callReadiness({
    uid: adminUid,
    data: { businessId: stale.businessId, productId: stale.productId },
  });
  assert.equal(r1.ready, false);
  assert.equal(r1.reasonCode, READINESS_REASON.GENERATION_MISMATCH);

  const uninit = await seedApprovableWorld();
  await db
    .collection("businesses")
    .doc(uninit.businessId)
    .update({ marketplaceBusinessGenerationId: admin.firestore.FieldValue.delete() });
  const r2 = await callReadiness({
    uid: adminUid,
    data: { businessId: uninit.businessId, productId: uninit.productId },
  });
  assert.equal(r2.ready, false);
  assert.equal(r2.reasonCode, READINESS_REASON.GENERATION_NOT_INITIALIZED);
});

itest("15. a stale evidence revision (the business epoch moved) is blocked", async () => {
  const adminUid = await seedUser("admin");
  const { businessId, productId } = await seedApprovableWorld();
  await db
    .collection("businessComplianceEpochs")
    .doc(businessId)
    .set({ epoch: admin.firestore.FieldValue.increment(5) }, { merge: true });
  const result = await callReadiness({ uid: adminUid, data: { businessId, productId } });
  assert.equal(result.ready, false);
  assert.equal(result.reasonCode, READINESS_REASON.EVIDENCE_STALE);
});

itest("16. a tampered evidence digest — activeEvidenceRefs changed without recompute — is blocked", async () => {
  const adminUid = await seedUser("admin");
  const { businessId, productId } = await seedApprovableWorld();
  const decision = (await decisionRef(productId).get()).data();
  await decisionRef(productId).update({
    activeEvidenceRefs: [
      ...decision.activeEvidenceRefs,
      { documentId: nextId("planted-doc"), scopeId: nextId("planted-scope"), expiresAt: FUTURE() },
    ],
  });
  const result = await callReadiness({ uid: adminUid, data: { businessId, productId } });
  assert.equal(result.ready, false);
  assert.equal(result.reasonCode, READINESS_REASON.EVIDENCE_STALE);
});

itest("17. a decision computed under a different policy version is blocked", async () => {
  const adminUid = await seedUser("admin");
  const { businessId, productId } = await seedApprovableWorld();
  // Activate a different policy version after the decision was computed.
  await seedSyntheticActivePolicy();
  const result = await callReadiness({ uid: adminUid, data: { businessId, productId } });
  assert.equal(result.ready, false);
  assert.equal(result.reasonCode, READINESS_REASON.POLICY_MISMATCH);
});

itest("18. malformed authoritative state fails closed, never ready", async () => {
  const adminUid = await seedUser("admin");
  const cases = [
    ["decision missing its own hash", async (b, p) => decisionRef(p).update({ decisionHash: admin.firestore.FieldValue.delete() })],
    ["decision with a non-integer revision", async (b, p) => decisionRef(p).update({ evidenceRevision: "two" })],
    ["decision with no active evidence", async (b, p) => decisionRef(p).update({ activeEvidenceRefs: [] })],
    ["decision with a non-enum status", async (b, p) => decisionRef(p).update({ effectiveStatus: "made_up" })],
    ["malformed active-product counter", async (b) => db.collection("businesses").doc(b).update({ pilotActiveProductCount: "many" })],
    ["product with an invalid seller relationship", async (b, p) => productRef(b, p).update({ sellerRelationship: "not_a_relationship" })],
  ];
  for (const [label, mutate] of cases) {
    const { businessId, productId } = await seedApprovableWorld();
    await mutate(businessId, productId);
    const result = await callReadiness({ uid: adminUid, data: { businessId, productId } });
    assert.equal(result.ready, false, label);
    assert.equal(result.approvalFingerprint, null, label);
    assert.ok(typeof result.reasonCode === "string" && result.reasonCode.length > 0, label);
  }
});

itest("18b. an inactive seller, a non-pending product and an already-approved product each block distinctly", async () => {
  const adminUid = await seedUser("admin");

  const inactive = await seedApprovableWorld();
  await db
    .collection("businesses")
    .doc(inactive.businessId)
    .update({ marketplaceSellerActivation: { active: false } });
  assert.equal(
    (
      await callReadiness({
        uid: adminUid,
        data: { businessId: inactive.businessId, productId: inactive.productId },
      })
    ).reasonCode,
    READINESS_REASON.SELLER_NOT_ACTIVE
  );

  const wrongStatus = await seedApprovableWorld();
  await productRef(wrongStatus.businessId, wrongStatus.productId).update({
    moderationStatus: "rejected",
  });
  assert.equal(
    (
      await callReadiness({
        uid: adminUid,
        data: { businessId: wrongStatus.businessId, productId: wrongStatus.productId },
      })
    ).reasonCode,
    READINESS_REASON.INVALID_TRANSITION
  );

  const already = await seedApprovableWorld();
  await productRef(already.businessId, already.productId).update({
    pilotProductApproval: { active: true, reviewedContentFingerprint: "x" },
  });
  assert.equal(
    (
      await callReadiness({
        uid: adminUid,
        data: { businessId: already.businessId, productId: already.productId },
      })
    ).reasonCode,
    READINESS_REASON.ALREADY_APPROVED
  );
});

itest("18c. the request schema is closed to exactly businessId and productId", async () => {
  const adminUid = await seedUser("admin");
  const { businessId, productId } = await seedApprovableWorld();
  assert.deepEqual([...READINESS_ALLOWED_FIELDS].sort(), ["businessId", "productId"]);
  const forgeries = [
    { businessId, productId, approvalFingerprint: "forged" },
    { businessId, productId, ready: true },
    { businessId, productId, decisionHash: "forged" },
    { businessId, productId, pilotProductClass: "sealed_dry_food" },
    {},
    { businessId },
    { productId },
    { businessId: "", productId },
    { businessId, productId: 7 },
  ];
  for (const data of forgeries) {
    const error = await expectThrows(callReadiness({ uid: adminUid, data }), "invalid-argument");
    assert.equal(error.details.reasonCode, READINESS_REASON.MALFORMED_REQUEST);
  }
});

// =====================================================================
// D. Read-only — item 19.
// =====================================================================

itest("19. readiness performs zero writes — no product, business, decision, counter or audit change", async () => {
  const adminUid = await seedUser("admin");
  const { businessId, productId } = await seedApprovableWorld();

  const before = {
    product: await getProduct(businessId, productId),
    business: await getBusiness(businessId),
    decision: (await decisionRef(productId).get()).data(),
    approvalEvents: (await db.collection("pilotProductApprovalAuditEvents").get()).size,
    classificationEvents: (await db.collection("pilotProductClassificationAuditEvents").get()).size,
    epoch: (await db.collection("businessComplianceEpochs").doc(businessId).get()).data(),
  };

  // Both a ready call and a blocked call.
  await callReadiness({ uid: adminUid, data: { businessId, productId } });
  const blocked = await seedApprovableWorld();
  await decisionRef(blocked.productId).delete();
  await callReadiness({
    uid: adminUid,
    data: { businessId: blocked.businessId, productId: blocked.productId },
  });

  assert.deepEqual(await getProduct(businessId, productId), before.product);
  assert.deepEqual(await getBusiness(businessId), before.business);
  assert.deepEqual((await decisionRef(productId).get()).data(), before.decision);
  assert.equal(
    (await db.collection("pilotProductApprovalAuditEvents").get()).size,
    before.approvalEvents,
    "readiness is a preview: it must record no approval audit event"
  );
  assert.equal(
    (await db.collection("pilotProductClassificationAuditEvents").get()).size,
    before.classificationEvents
  );
  assert.deepEqual(
    (await db.collection("businessComplianceEpochs").doc(businessId).get()).data(),
    before.epoch
  );
});

// =====================================================================
// E. Optimistic concurrency — items 24-27.
// =====================================================================

async function readinessThenMutateThenApprove(mutate) {
  const adminUid = await seedUser("admin");
  const { businessId, productId } = await seedApprovableWorld();
  const readiness = await callReadiness({ uid: adminUid, data: { businessId, productId } });
  assert.equal(readiness.ready, true, `fixture must start ready, got ${readiness.reasonCode}`);

  await mutate({ businessId, productId });

  const error = await expectThrows(
    callApprove({
      uid: adminUid,
      data: {
        businessId,
        productId,
        allowedPilotCategory: "food",
        reviewedContentFingerprint: readiness.approvalFingerprint,
        attestNoProhibitedClaim: true,
      },
    })
  );
  assert.equal((await getProduct(businessId, productId)).isActive, false, "nothing may be published");
  return error;
}

itest("24. a product content change between readiness and approval fails stale", async () => {
  const error = await readinessThenMutateThenApprove(({ businessId, productId }) =>
    productRef(businessId, productId).update({ price: 999 })
  );
  assert.equal(error.details.reasonCode, "stale-content");
});

itest("25. a classification change between readiness and approval fails closed", async () => {
  const error = await readinessThenMutateThenApprove(({ businessId, productId }) =>
    productRef(businessId, productId).update({
      pilotProductClass: PILOT_PRODUCT_CLASS.NON_MEDICINAL_TREATS,
    })
  );
  // The class is bound into the fingerprint, so the token no longer matches.
  assert.equal(error.details.reasonCode, "stale-content");
});

itest("26. a decision change between readiness and approval fails closed", async () => {
  const error = await readinessThenMutateThenApprove(({ productId }) =>
    decisionRef(productId).update({ decisionHash: "0".repeat(64) })
  );
  assert.equal(error.details.reasonCode, "stale-content");
});

itest("27. expiry crossing between readiness and approval fails closed", async () => {
  const error = await readinessThenMutateThenApprove(({ productId }) =>
    decisionRef(productId).update({ validUntil: PAST() })
  );
  assert.equal(error.details.reasonCode, "compliance-decision-expired");
});

itest("27b. a fingerprint obtained for one product is rejected for another", async () => {
  const adminUid = await seedUser("admin");
  const a = await seedApprovableWorld();
  const b = await seedApprovableWorld();
  // Each seedApprovableWorld() activates its own synthetic policy version, so
  // seeding B leaves A's decision computed under a superseded policy — which
  // test 17 proves is itself a blocking condition. Recomputing A under the
  // now-current pointer isolates THIS test's subject instead of re-testing
  // the policy check.
  await recomputeProductComplianceStatus({
    db,
    businessId: a.businessId,
    productId: a.productId,
  });
  const readinessA = await callReadiness({
    uid: adminUid,
    data: { businessId: a.businessId, productId: a.productId },
  });
  assert.equal(readinessA.ready, true);

  const error = await expectThrows(
    callApprove({
      uid: adminUid,
      data: {
        businessId: b.businessId,
        productId: b.productId,
        allowedPilotCategory: "food",
        reviewedContentFingerprint: readinessA.approvalFingerprint,
        attestNoProhibitedClaim: true,
      },
    }),
    "failed-precondition"
  );
  assert.equal(error.details.reasonCode, "stale-content");
  assert.equal((await getProduct(b.businessId, b.productId)).isActive, false);
});

itest("27c. the fingerprint binds product identity: the SAME content and the SAME decision under a different productId hash differently", async () => {
  // A unit-level proof, because two separately-seeded worlds necessarily
  // differ in content and evidence too — which would let this pass even if
  // productId were not bound at all.
  const product = {
    name: "n",
    description: "d",
    price: 1,
    currency: "TRY",
    media: [],
    category: "c",
    brand: "b",
    barcode: null,
    salePrice: null,
    kdvRate: 10,
    sellerRelationship: "reseller",
    pilotProductClass: "sealed_dry_food",
    businessId: "biz-1",
    marketplaceBusinessGenerationId: "gen-1",
  };
  const decision = {
    decisionHash: "dh",
    policyVersion: "v1",
    evidenceRevision: 0,
    effectiveStatus: "verified_valid",
    validUntil: null,
    activeEvidenceRefs: [{ documentId: "doc-1", scopeId: "scope-1" }],
  };
  const base = computeApprovalFingerprint(product, decision, "product-A");
  for (const other of ["product-B", "product-a", "", null, undefined]) {
    assert.notEqual(
      computeApprovalFingerprint(product, decision, other),
      base,
      `productId ${String(other)} must not reuse product-A's fingerprint`
    );
  }
  // Business identity and generation are bound for the same reason.
  assert.notEqual(
    computeApprovalFingerprint({ ...product, businessId: "biz-2" }, decision, "product-A"),
    base
  );
  assert.notEqual(
    computeApprovalFingerprint(
      { ...product, marketplaceBusinessGenerationId: "gen-2" },
      decision,
      "product-A"
    ),
    base
  );
});

// =====================================================================
// F. Static contract — items 20, 21, 31 (client side).
// =====================================================================

const PAGE = fs.readFileSync(
  path.join(__dirname, "..", "..", "lib", "ui", "admin", "pages", "pilot_product_approval_detail_page.dart"),
  "utf8"
);

itest("20. the Admin page never reads productComplianceDecisions, or any compliance collection, directly", async () => {
  // Executable lines only: the page's own comments legitimately NAME the
  // collections it is forbidden to touch, and a raw substring scan would
  // read that documentation as the violation it describes.
  const executable = PAGE.split("\n")
    .filter((l) => {
      const t = l.trim();
      return t.length > 0 && !t.startsWith("//") && !t.startsWith("///") && !t.startsWith("*");
    })
    .join("\n");
  for (const forbidden of [
    "productComplianceDecisions",
    "productEvidenceLinks",
    "complianceDocuments",
    "complianceDocumentScopes",
    "compliancePolicyRegistry",
    "businessComplianceEpochs",
  ]) {
    assert.equal(
      executable.includes(forbidden),
      false,
      `page must not reference ${forbidden}`
    );
  }
});

itest("21. the Admin page never computes an approval fingerprint — the content fingerprint is gone from this page entirely", async () => {
  assert.equal(PAGE.includes("computePilotProductContentFingerprint"), false);
  assert.equal(PAGE.includes("pilot_product_fingerprint.dart"), false);
  assert.equal(PAGE.includes("sha256"), false);
  assert.equal(PAGE.includes("crypto"), false);
  // The only fingerprint it can send is the one it received.
  assert.ok(PAGE.includes("getPilotProductApprovalReadiness"));
  assert.ok(PAGE.includes("_readinessFingerprint"));
  assert.ok(PAGE.includes("'reviewedContentFingerprint': fingerprint"));
});

itest("21b. the legitimate content-fingerprint helper still exists and still has its own tests", async () => {
  const helper = path.join(__dirname, "..", "..", "lib", "ui", "admin", "pilot_product_fingerprint.dart");
  const helperTest = path.join(__dirname, "..", "..", "test", "ui", "admin", "pilot_product_fingerprint_test.dart");
  assert.equal(fs.existsSync(helper), true, "the server-mirror helper must not be deleted");
  assert.equal(fs.existsSync(helperTest), true, "its contract tests must not be deleted");
  assert.ok(
    fs.readFileSync(helper, "utf8").includes("computePilotProductContentFingerprint"),
    "the helper keeps documenting the frozen content half of the definition"
  );
});

itest("F-wiring. exactly one callable wrapper exists for readiness, in the correct region, with no HTTP or scheduled entry point", async () => {
  const indexText = fs.readFileSync(path.join(__dirname, "..", "index.js"), "utf8");
  assert.equal((indexText.match(/exports\.getPilotProductApprovalReadiness\s*=/g) || []).length, 1);
  assert.match(
    indexText,
    /exports\.getPilotProductApprovalReadiness = onCall\(\{ region: "europe-west3" \}/
  );
  assert.equal(/onRequest\([^)]*\)[^;]*getPilotProductApprovalReadiness/.test(indexText), false);
  assert.equal(/onSchedule\([^)]*\)[^;]*getPilotProductApprovalReadiness/.test(indexText), false);
});

itest("F-noSecondPredicate. readiness reuses the canonical validators rather than reimplementing them", async () => {
  const source = fs.readFileSync(
    path.join(__dirname, "..", "src", "marketplace", "compliance", "pilotProductApprovalReadiness.js"),
    "utf8"
  );
  const executable = source
    .split("\n")
    .filter((l) => !l.trim().startsWith("//"))
    .join("\n");
  // It delegates rather than re-deriving.
  assert.ok(executable.includes("assertUsableComplianceDecision("));
  assert.ok(executable.includes("evaluateLiveProductEligibility("));
  assert.ok(executable.includes("computeApprovalFingerprint("));
  assert.ok(executable.includes("isValidPilotProductClass("));
  // And it never writes.
  for (const write of ["tx.set(", "tx.update(", "tx.create(", "tx.delete(", ".add(", "FieldValue"]) {
    assert.equal(executable.includes(write), false, `readiness must never ${write}`);
  }
});
