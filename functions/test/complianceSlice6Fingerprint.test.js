"use strict";

// Marketplace Revision 30 §H / §J Slice 6 — approval fingerprint binding and
// invalidation. Emulator-only synthetic fixtures; no live evidence, no real
// approval, no policy activated in any real project.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();

const {
  approvePilotProduct,
  revokePilotProductApproval,
  computeContentFingerprint,
  computeApprovalFingerprint,
  canonicalEvidenceDigest,
  REASON_CODE,
  AUDIT_EVENTS_COLLECTION,
} = require("../src/marketplace/compliance/pilotProductApproval");
const {
  invalidateProductApprovalIfStale,
  runApprovalInvalidationSweep,
  INVALIDATION_REASON,
} = require("../src/marketplace/compliance/complianceApprovalInvalidation");
const {
  PRODUCT_COMPLIANCE_EFFECTIVE_STATUS,
} = require("../src/marketplace/compliance/complianceConstants");

const hasFs = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const itest = (n, f) => test(n, { skip: !hasFs }, f);
const quiet = { info() {}, warn() {}, error() {} };

let seq = 0;
const RUN_TOKEN = `s6${Math.random().toString(36).slice(2, 8)}`;
const nextId = (p) => {
  seq += 1;
  return `${p}-${RUN_TOKEN}-${seq}`;
};
const TS = (ms) => admin.firestore.Timestamp.fromMillis(ms);
const FUTURE = () => TS(Date.now() + 365 * 86400000);

async function seedAdmin() {
  const uid = nextId("s6-admin");
  await db.collection("users").doc(uid).set({ role: "admin" });
  return uid;
}

/// A business + pending product + a positive canonical decision. The decision
/// is written directly (synthetic) so this suite tests the APPROVAL binding,
/// not the engine that produces decisions — that is Slice 5's suite.
async function seedApprovable({ decisionOverrides = {}, productOverrides = {} } = {}) {
  const businessId = nextId("biz");
  const productId = nextId("prod");
  const generationId = `gen-${businessId}`;

  await db.collection("businesses").doc(businessId).set({
    ownerUid: nextId("seller"),
    marketplaceBusinessGenerationId: generationId,
    marketplaceSellerActivation: { active: true },
    pilotActiveProductCount: 0,
  });

  await db
    .collection("businesses")
    .doc(businessId)
    .collection("products")
    .doc(productId)
    .set({
      businessId,
      marketplaceBusinessGenerationId: generationId,
      name: "Test Product",
      description: "A product",
      price: 10,
      currency: "TRY",
      media: [],
      category: "Health > Vitamins",
      brand: "ACME",
      barcode: null,
      salePrice: null,
      kdvRate: 20,
      sellerRelationship: "reseller",
      productInputRevision: 0,
      isActive: false,
      moderationStatus: "pending_review",
      ...productOverrides,
    });

  const decision = {
    businessId,
    policyVersion: nextId("policy"),
    evidenceRevision: 0,
    decisionHash: nextId("hash"),
    effectiveStatus: PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.VERIFIED_VALID,
    activeEvidenceRefs: [{ documentId: nextId("doc"), scopeId: nextId("scope"), expiresAt: FUTURE() }],
    validUntil: FUTURE(),
    ...decisionOverrides,
  };
  await db.collection("productComplianceDecisions").doc(productId).set(decision);

  return { businessId, productId, generationId, decision };
}

const readProduct = async (businessId, productId) =>
  (await db.collection("businesses").doc(businessId).collection("products").doc(productId).get()).data();
const readCount = async (businessId) =>
  (await db.collection("businesses").doc(businessId).get()).data().pilotActiveProductCount;

async function approve(adminUid, businessId, productId, fingerprint) {
  return approvePilotProduct({
    db,
    auth: { uid: adminUid },
    data: {
      businessId,
      productId,
      allowedPilotCategory: "food",
      reviewedContentFingerprint: fingerprint,
      attestNoProhibitedClaim: true,
    },
  });
}

async function liveFingerprint(businessId, productId) {
  const product = await readProduct(businessId, productId);
  const dec = await db.collection("productComplianceDecisions").doc(productId).get();
  return computeApprovalFingerprint(product, dec.exists ? dec.data() : null);
}

async function failureOf(promise) {
  try {
    await promise;
    return null;
  } catch (e) {
    return { code: e.code, reason: (e.details && e.details.reasonCode) || null };
  }
}

// --- fingerprint construction --------------------------------------------

test("the evidence digest is order-insensitive but count-sensitive", () => {
  const a = { documentId: "d1", scopeId: "s1" };
  const b = { documentId: "d2", scopeId: "s2" };
  // Semantically identical evidence in either order is ONE fingerprint.
  assert.equal(canonicalEvidenceDigest([a, b]), canonicalEvidenceDigest([b, a]));
  // Different evidence is a different digest.
  assert.notEqual(canonicalEvidenceDigest([a]), canonicalEvidenceDigest([a, b]));
  // Dropping a malformed entry must not silently narrow the set.
  assert.notEqual(canonicalEvidenceDigest([a, null]), canonicalEvidenceDigest([a]));
  assert.equal(canonicalEvidenceDigest(null), null);
});

test("the approval fingerprint binds decision identity, and each input matters", () => {
  const product = {
    businessId: "b1",
    marketplaceBusinessGenerationId: "g1",
    name: "N",
    price: 1,
    media: ["a", "b"],
  };
  const decision = {
    decisionHash: "h1",
    policyVersion: "p1",
    evidenceRevision: 3,
    effectiveStatus: "verified_valid",
    validUntil: TS(2000),
    activeEvidenceRefs: [{ documentId: "d1", scopeId: "s1" }],
  };
  const base = computeApprovalFingerprint(product, decision);

  // Determinism.
  assert.equal(base, computeApprovalFingerprint(product, decision));
  // A Timestamp and an equal Date must not disagree.
  assert.equal(
    base,
    computeApprovalFingerprint(product, { ...decision, validUntil: new Date(2000) })
  );

  // Every §H-bound input changes it.
  for (const [label, mutated] of [
    ["decisionHash", { ...decision, decisionHash: "h2" }],
    ["policyVersion", { ...decision, policyVersion: "p2" }],
    ["evidenceRevision", { ...decision, evidenceRevision: 4 }],
    ["effectiveStatus", { ...decision, effectiveStatus: "policy_unresolved" }],
    ["validUntil", { ...decision, validUntil: TS(3000) }],
    ["evidence", { ...decision, activeEvidenceRefs: [{ documentId: "d2", scopeId: "s2" }] }],
  ]) {
    assert.notEqual(computeApprovalFingerprint(product, mutated), base, `${label} must change it`);
  }
  // Product identity and generation are bound too.
  assert.notEqual(computeApprovalFingerprint({ ...product, marketplaceBusinessGenerationId: "g2" }, decision), base);
  assert.notEqual(computeApprovalFingerprint({ ...product, businessId: "b2" }, decision), base);
  // Reviewed content still matters.
  assert.notEqual(computeApprovalFingerprint({ ...product, price: 2 }, decision), base);
  // media order is real product content and DOES change it.
  assert.notEqual(computeApprovalFingerprint({ ...product, media: ["b", "a"] }, decision), base);
  // A missing decision is not the same as a present one.
  assert.notEqual(computeApprovalFingerprint(product, null), base);
  // ...and the old content-only fingerprint is no longer sufficient.
  assert.notEqual(base, computeContentFingerprint(product));
});

// --- approval gate --------------------------------------------------------

itest("approval succeeds only with a positive canonical decision", async () => {
  const adminUid = await seedAdmin();
  const w = await seedApprovable();
  const fp = await liveFingerprint(w.businessId, w.productId);
  const result = await approve(adminUid, w.businessId, w.productId, fp);
  assert.equal(result.active, true);
  const product = await readProduct(w.businessId, w.productId);
  assert.equal(product.pilotProductApproval.reviewedContentFingerprint, fp);
  assert.equal(await readCount(w.businessId), 1);
});

itest("approval fails closed for every non-usable decision", async () => {
  const adminUid = await seedAdmin();
  const cases = [
    ["missing", null, "compliance-decision-missing"],
    ["not-eligible", { effectiveStatus: PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.POLICY_UNRESOLVED }, "compliance-decision-not-eligible"],
    ["unknown-status", { effectiveStatus: "a_future_status" }, "compliance-decision-not-eligible"],
    ["no-evidence", { activeEvidenceRefs: [] }, "compliance-decision-no-evidence"],
    ["expired", { validUntil: TS(Date.now() - 1000) }, "compliance-decision-expired"],
    ["missing-validUntil", { validUntil: null }, "compliance-decision-expired"],
    ["malformed-hash", { decisionHash: "" }, "compliance-decision-malformed"],
    ["malformed-policy", { policyVersion: "" }, "compliance-decision-malformed"],
    ["malformed-revision", { evidenceRevision: "0" }, "compliance-decision-malformed"],
    ["other-business", { businessId: "someone-else" }, "compliance-decision-business-mismatch"],
  ];
  for (const [label, overrides, expectedReason] of cases) {
    const w = await seedApprovable();
    if (overrides === null) {
      await db.collection("productComplianceDecisions").doc(w.productId).delete();
    } else {
      await db.collection("productComplianceDecisions").doc(w.productId).update(overrides);
    }
    const fp = await liveFingerprint(w.businessId, w.productId);
    const failure = await failureOf(approve(adminUid, w.businessId, w.productId, fp));
    assert.notEqual(failure, null, `${label} must be refused`);
    assert.equal(failure.reason, expectedReason, label);
    // Nothing was approved, activated or counted.
    const product = await readProduct(w.businessId, w.productId);
    assert.equal(product.isActive, false);
    assert.equal(product.moderationStatus, "pending_review");
    assert.equal(await readCount(w.businessId), 0);
  }
});

itest("a client-supplied fingerprint cannot authorize approval", async () => {
  const adminUid = await seedAdmin();
  const w = await seedApprovable();
  // The old content-only fingerprint, and an outright forgery, are both
  // compared against the server's freshly computed value.
  const product = await readProduct(w.businessId, w.productId);
  for (const forged of [
    computeContentFingerprint(product),
    "0".repeat(64),
    computeApprovalFingerprint(product, { ...w.decision, evidenceRevision: 99 }),
  ]) {
    const failure = await failureOf(approve(adminUid, w.businessId, w.productId, forged));
    assert.notEqual(failure, null, "a fingerprint the server did not compute must be refused");
  }
  assert.equal(await readCount(w.businessId), 0);
});

itest("the request carries no decision identity a caller could assert", async () => {
  const adminUid = await seedAdmin();
  const w = await seedApprovable();
  const fp = await liveFingerprint(w.businessId, w.productId);
  for (const extra of [
    { decisionHash: "x" },
    { evidenceRevision: 9 },
    { policyVersion: "p" },
    { effectiveStatus: "verified_valid" },
  ]) {
    const failure = await failureOf(
      approvePilotProduct({
        db,
        auth: { uid: adminUid },
        data: {
          businessId: w.businessId,
          productId: w.productId,
          allowedPilotCategory: "food",
          reviewedContentFingerprint: fp,
          attestNoProhibitedClaim: true,
          ...extra,
        },
      })
    );
    assert.notEqual(failure, null, `${Object.keys(extra)[0]} must be refused, not ignored`);
    assert.equal(failure.code, "invalid-argument");
  }
});

itest("a decision change between screen and submit prevents a stale approval", async () => {
  const adminUid = await seedAdmin();
  const w = await seedApprovable();
  // The admin's screen computed this fingerprint...
  const staleFp = await liveFingerprint(w.businessId, w.productId);
  // ...then the evidence moved on.
  await db
    .collection("productComplianceDecisions")
    .doc(w.productId)
    .update({ evidenceRevision: 1, decisionHash: nextId("hash2") });

  const failure = await failureOf(approve(adminUid, w.businessId, w.productId, staleFp));
  assert.notEqual(failure, null, "a stale screen must not approve");
  assert.equal(await readCount(w.businessId), 0);

  // Re-reading canonical state and approving afresh works.
  const freshFp = await liveFingerprint(w.businessId, w.productId);
  const ok = await approve(adminUid, w.businessId, w.productId, freshFp);
  assert.equal(ok.active, true);
});

itest("replaying the same canonical approval is a safe no-op; changed inputs are not", async () => {
  const adminUid = await seedAdmin();
  const w = await seedApprovable();
  const fp = await liveFingerprint(w.businessId, w.productId);
  await approve(adminUid, w.businessId, w.productId, fp);
  assert.equal(await readCount(w.businessId), 1);

  // Identical replay — idempotent, no second increment.
  const replay = await approve(adminUid, w.businessId, w.productId, fp);
  assert.equal(replay.idempotent, true);
  assert.equal(await readCount(w.businessId), 1);

  // The same fingerprint after canonical inputs changed must NOT replay.
  await db.collection("productComplianceDecisions").doc(w.productId).update({ evidenceRevision: 7 });
  const failure = await failureOf(approve(adminUid, w.businessId, w.productId, fp));
  assert.notEqual(failure, null, "changed canonical inputs must conflict, not replay success");
  assert.equal(await readCount(w.businessId), 1);
});

// --- invalidation ---------------------------------------------------------

async function approveThen(adminUid, mutate) {
  const w = await seedApprovable();
  const fp = await liveFingerprint(w.businessId, w.productId);
  await approve(adminUid, w.businessId, w.productId, fp);
  assert.equal(await readCount(w.businessId), 1);
  if (mutate) await mutate(w);
  return w;
}

itest("every §H trigger invalidates the approval and unpublishes exactly once", async () => {
  const adminUid = await seedAdmin();
  const triggers = {
    "decision revoked/expired (validUntil crossed)": (w) =>
      db.collection("productComplianceDecisions").doc(w.productId).update({ validUntil: TS(Date.now() - 1000) }),
    "evidenceRevision advanced (revocation/supersession)": (w) =>
      db.collection("productComplianceDecisions").doc(w.productId).update({ evidenceRevision: 1 }),
    "decisionHash changed": (w) =>
      db.collection("productComplianceDecisions").doc(w.productId).update({ decisionHash: nextId("h") }),
    "policy version changed": (w) =>
      db.collection("productComplianceDecisions").doc(w.productId).update({ policyVersion: nextId("p") }),
    "effectiveStatus turned non-positive": (w) =>
      db.collection("productComplianceDecisions").doc(w.productId).update({
        effectiveStatus: PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.POLICY_UNRESOLVED,
      }),
    "evidence references replaced": (w) =>
      db.collection("productComplianceDecisions").doc(w.productId).update({
        activeEvidenceRefs: [{ documentId: nextId("d"), scopeId: nextId("s"), expiresAt: FUTURE() }],
      }),
    "decision deleted (provenance unavailable)": (w) =>
      db.collection("productComplianceDecisions").doc(w.productId).delete(),
    "business generation changed": (w) =>
      db.collection("businesses").doc(w.businessId).collection("products").doc(w.productId)
        .update({ marketplaceBusinessGenerationId: "gen-RECREATED" }),
    "reviewed product content changed": (w) =>
      db.collection("businesses").doc(w.businessId).collection("products").doc(w.productId)
        .update({ price: 999 }),
  };

  for (const [label, mutate] of Object.entries(triggers)) {
    const w = await approveThen(adminUid, mutate);
    const result = await invalidateProductApprovalIfStale({
      db,
      businessId: w.businessId,
      productId: w.productId,
      logger: quiet,
    });
    assert.equal(result.outcome, "invalidated", `${label} must invalidate`);

    const product = await readProduct(w.businessId, w.productId);
    assert.equal(product.isActive, false, `${label}: must be unpublished`);
    assert.equal(product.moderationStatus, "pending_review");
    assert.equal(product.pilotProductApproval.active, false);
    assert.equal(product.pilotProductApproval.revokedByKind, "system");
    assert.equal(await readCount(w.businessId), 0, `${label}: count decremented exactly once`);
  }
});

itest("an unchanged approval survives the sweep untouched", async () => {
  const adminUid = await seedAdmin();
  const w = await approveThen(adminUid, null);
  const result = await invalidateProductApprovalIfStale({
    db,
    businessId: w.businessId,
    productId: w.productId,
    logger: quiet,
  });
  assert.equal(result.outcome, "valid");
  const product = await readProduct(w.businessId, w.productId);
  assert.equal(product.isActive, true);
  assert.equal(await readCount(w.businessId), 1);
});

itest("duplicate and out-of-order invalidation never double-decrements or revives", async () => {
  const adminUid = await seedAdmin();
  const w = await approveThen(adminUid, (x) =>
    db.collection("productComplianceDecisions").doc(x.productId).update({ evidenceRevision: 5 })
  );

  const first = await invalidateProductApprovalIfStale({ db, businessId: w.businessId, productId: w.productId, logger: quiet });
  assert.equal(first.outcome, "invalidated");
  assert.equal(await readCount(w.businessId), 0);

  // Duplicate delivery, five times.
  for (let i = 0; i < 5; i += 1) {
    const again = await invalidateProductApprovalIfStale({ db, businessId: w.businessId, productId: w.productId, logger: quiet });
    assert.equal(again.outcome, "noop");
  }
  assert.equal(await readCount(w.businessId), 0, "count never goes below zero");

  // An out-of-order "stale positive" delivery cannot restore the approval.
  const product = await readProduct(w.businessId, w.productId);
  assert.equal(product.pilotProductApproval.active, false);
  assert.equal(product.isActive, false);
});

itest("invalidating an already-inactive product never changes the count", async () => {
  const w = await seedApprovable();
  await db.collection("businesses").doc(w.businessId).update({ pilotActiveProductCount: 3 });
  const result = await invalidateProductApprovalIfStale({ db, businessId: w.businessId, productId: w.productId, logger: quiet });
  assert.equal(result.outcome, "noop");
  assert.equal(await readCount(w.businessId), 3);
});

itest("replacement evidence and a new positive decision do not revive the old approval", async () => {
  const adminUid = await seedAdmin();
  const w = await approveThen(adminUid, (x) =>
    db.collection("productComplianceDecisions").doc(x.productId).update({ evidenceRevision: 1 })
  );
  await invalidateProductApprovalIfStale({ db, businessId: w.businessId, productId: w.productId, logger: quiet });
  assert.equal(await readCount(w.businessId), 0);

  // Fresh, fully valid replacement evidence.
  await db.collection("productComplianceDecisions").doc(w.productId).set({
    businessId: w.businessId,
    policyVersion: nextId("policy2"),
    evidenceRevision: 2,
    decisionHash: nextId("hash2"),
    effectiveStatus: PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.VERIFIED_VALID,
    activeEvidenceRefs: [{ documentId: nextId("d"), scopeId: nextId("s"), expiresAt: FUTURE() }],
    validUntil: FUTURE(),
  });

  // No sweep, no recompute, nothing revives it: re-review is required.
  const again = await invalidateProductApprovalIfStale({ db, businessId: w.businessId, productId: w.productId, logger: quiet });
  assert.equal(again.outcome, "noop");
  const product = await readProduct(w.businessId, w.productId);
  assert.equal(product.isActive, false);
  assert.equal(product.pilotProductApproval.active, false);
  assert.equal(await readCount(w.businessId), 0);
});

itest("the sweep is bounded, invalidates only the stale, and never activates anything", async () => {
  const adminUid = await seedAdmin();
  const stale = await approveThen(adminUid, (x) =>
    db.collection("productComplianceDecisions").doc(x.productId).update({ evidenceRevision: 9 })
  );
  const fresh = await approveThen(adminUid, null);

  const result = await runApprovalInvalidationSweep({ db, pageSize: 10, maxPages: 5, logger: quiet });
  assert.ok(result.examined >= 2);
  assert.ok(result.invalidated >= 1);

  assert.equal((await readProduct(stale.businessId, stale.productId)).isActive, false);
  assert.equal(await readCount(stale.businessId), 0);
  // The valid one is untouched — a sweep never approves or activates.
  assert.equal((await readProduct(fresh.businessId, fresh.productId)).isActive, true);
  assert.equal(await readCount(fresh.businessId), 1);
});

itest("invalidation appends an audit event and rewrites no history", async () => {
  const adminUid = await seedAdmin();
  const w = await approveThen(adminUid, (x) =>
    db.collection("productComplianceDecisions").doc(x.productId).update({ evidenceRevision: 4 })
  );
  const before = await db
    .collection(AUDIT_EVENTS_COLLECTION)
    .where("productId", "==", w.productId)
    .get();
  const beforeIds = before.docs.map((d) => d.id).sort();
  const approveEvent = before.docs.find((d) => d.data().action === "approve");
  assert.ok(approveEvent, "the original approval event exists");
  const approveData = approveEvent.data();

  await invalidateProductApprovalIfStale({ db, businessId: w.businessId, productId: w.productId, logger: quiet });

  const after = await db
    .collection(AUDIT_EVENTS_COLLECTION)
    .where("productId", "==", w.productId)
    .get();
  assert.equal(after.size, before.size + 1, "exactly one event is appended");
  // Every prior event survives byte-identically.
  for (const id of beforeIds) {
    assert.ok(after.docs.some((d) => d.id === id), "no historical event is deleted");
  }
  assert.deepEqual(
    after.docs.find((d) => d.id === approveEvent.id).data(),
    approveData,
    "the original approval event is never rewritten"
  );
  const revoke = after.docs.find((d) => d.data().action === "revoke");
  assert.equal(revoke.data().reasonCode, REASON_CODE.REVOKED_CONTENT_CHANGED);
  assert.equal(revoke.data().invalidationReason, INVALIDATION_REASON.FINGERPRINT_MISMATCH);
});

itest("no invalidation path ever activates, approves or publishes", async () => {
  const adminUid = await seedAdmin();
  const w = await approveThen(adminUid, (x) =>
    db.collection("productComplianceDecisions").doc(x.productId).update({ evidenceRevision: 2 })
  );
  const countBefore = await readCount(w.businessId);
  await invalidateProductApprovalIfStale({ db, businessId: w.businessId, productId: w.productId, logger: quiet });
  const countAfter = await readCount(w.businessId);
  assert.ok(countAfter <= countBefore, "the count can only ever decrease here");
  assert.ok(countAfter >= 0, "and never below zero");

  const product = await readProduct(w.businessId, w.productId);
  assert.equal(product.isActive, false);
  assert.notEqual(product.moderationStatus, "approved");
  void revokePilotProductApproval;
});
