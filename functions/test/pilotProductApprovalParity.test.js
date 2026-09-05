"use strict";

// Marketplace Revision 37 §0.35 — APPROVAL AUTHORITY PARITY.
//
// THE INVARIANT THIS PINS:
//
//   If `getPilotProductApprovalReadiness` rejects an authoritative state for a
//   COMPLIANCE reason, `approvePilotProduct` must reject the same state.
//
// Readiness is advisory; `approvePilotProduct` is the authoritative mutation
// boundary. Before this revision the stricter predicate lived only on the
// advisory side, and ten drifted states were rejected by readiness yet
// accepted AND published by approval — reachable directly, because
// `productComplianceDecisions` is admin-readable by the frozen Rules, so a
// caller who could read a decision could recompute the live approval
// fingerprint and satisfy the only remaining check.
//
// Every scenario below therefore invokes approval with a FRESHLY RECOMPUTED
// LIVE fingerprint — the strongest token any direct caller could possibly
// construct — never a deliberately stale one. A scenario that rejects here
// rejects on compliance grounds, not because the token drifted.
//
// Runs the real engine against the emulator with clearly-labelled SYNTHETIC
// fixtures; no policy is activated in any real project.

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
  AUDIT_EVENTS_COLLECTION,
  PILOT_PRODUCT_ACTIVE_LIMIT,
} = require("../src/marketplace/compliance/pilotProductApproval");
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
const RUN = `par${Math.random().toString(36).slice(2, 8)}`;
const nextId = (p) => `${p}-${RUN}-${++seq}`;
const FUTURE = () => admin.firestore.Timestamp.fromMillis(Date.now() + 365 * 86400000);
const PAST = () => admin.firestore.Timestamp.fromMillis(Date.now() - 86400000);

const prodRef = (b, p) => db.collection("businesses").doc(b).collection("products").doc(p);
const bizRef = (b) => db.collection("businesses").doc(b);
const decRef = (p) => db.collection("productComplianceDecisions").doc(p);
const epochRef = (b) => db.collection("businessComplianceEpochs").doc(b);

async function seedAdmin() {
  const uid = nextId("admin");
  await db.collection("users").doc(uid).set({ role: "admin" });
  return uid;
}

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
  await db.collection("compliancePolicyRegistryPointer").doc("current").set({
    activeVersionId: versionId,
  });
  return versionId;
}

/// A genuinely approvable world, produced by the real engine.
async function seedWorld({ productOverrides = {}, businessOverrides = {} } = {}) {
  await seedSyntheticActivePolicy();
  const businessId = nextId("biz");
  const productId = nextId("prod");
  const generationId = `gen-${businessId}`;

  await bizRef(businessId).set({
    ownerUid: nextId("seller"),
    marketplaceSellerActivation: { active: true },
    marketplaceBusinessGenerationId: generationId,
    pilotActiveProductCount: 0,
    ...businessOverrides,
  });
  await prodRef(businessId, productId).set({
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
    sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
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

const readiness = (uid, businessId, productId) =>
  functions.getPilotProductApprovalReadiness.run({
    auth: { uid },
    data: { businessId, productId },
  });

/// Approves using the strongest token a direct caller could construct: the
/// LIVE fingerprint recomputed from current canonical state.
async function approveWithLiveFingerprint(uid, businessId, productId) {
  const product = (await prodRef(businessId, productId).get()).data();
  const decSnap = await decRef(productId).get();
  const fingerprint = computeApprovalFingerprint(
    product,
    decSnap.exists ? decSnap.data() : null,
    productId
  );
  return functions.approvePilotProduct.run({
    auth: { uid },
    data: {
      businessId,
      productId,
      allowedPilotCategory: "food",
      reviewedContentFingerprint: fingerprint,
      attestNoProhibitedClaim: true,
    },
  });
}

async function outcomeOf(promise) {
  try {
    const value = await promise;
    return { ok: true, value };
  } catch (error) {
    return {
      ok: false,
      code: error.code,
      reasonCode: (error.details && error.details.reasonCode) || null,
      eligibilityReason: (error.details && error.details.eligibilityReason) || null,
    };
  }
}

/// The full authoritative footprint a rejection must leave untouched.
async function snapshotState(businessId, productId) {
  const product = (await prodRef(businessId, productId).get()).data();
  const business = (await bizRef(businessId).get()).data();
  const decisionSnap = await decRef(productId).get();
  const audit = await db
    .collection(AUDIT_EVENTS_COLLECTION)
    .where("productId", "==", productId)
    .get();
  const evidence = await db.collection("complianceDocuments").where("businessId", "==", businessId).get();
  return {
    isActive: product.isActive,
    moderationStatus: product.moderationStatus,
    pilotProductApproval: product.pilotProductApproval || null,
    pilotProductClass: product.pilotProductClass || null,
    pilotActiveProductCount: business.pilotActiveProductCount,
    decision: decisionSnap.exists ? decisionSnap.data() : null,
    auditEvents: audit.size,
    evidenceDocs: evidence.size,
    evidenceStatuses: evidence.docs.map((d) => d.data().status).sort(),
  };
}

// =====================================================================
// THE DIFFERENTIAL TABLE.
//
// `readinessRejects: true` means the invariant applies: approval must reject
// the same authoritative state.
// =====================================================================

const SCENARIOS = [
  {
    id: 1,
    name: "fully valid state",
    mutate: async () => {},
    readinessRejects: false,
    approvalSucceeds: true,
  },
  {
    id: 2,
    name: "live policy pointer drift",
    mutate: async () => {
      await seedSyntheticActivePolicy();
    },
    readinessRejects: true,
    eligibilityReason: "eligibility_policy_version_mismatch",
  },
  {
    id: 3,
    name: "decisionHash drift",
    mutate: async ({ productId }) => decRef(productId).update({ decisionHash: "0".repeat(64) }),
    readinessRejects: true,
    eligibilityReason: "eligibility_decision_hash_mismatch",
  },
  {
    id: 4,
    name: "product input revision drift",
    mutate: async ({ businessId, productId }) =>
      prodRef(businessId, productId).update({ productInputRevision: 7 }),
    readinessRejects: true,
    eligibilityReason: "eligibility_product_input_revision_mismatch",
  },
  {
    id: 5,
    name: "class snapshot drift",
    mutate: async ({ productId }) =>
      decRef(productId).update({ pilotProductClassSnapshot: PILOT_PRODUCT_CLASS.SEALED_WET_FOOD }),
    readinessRejects: true,
    eligibilityReason: "eligibility_pilot_product_class_snapshot_mismatch",
  },
  {
    id: 6,
    name: "relationship snapshot drift",
    mutate: async ({ productId }) =>
      decRef(productId).update({ sellerRelationshipSnapshot: SELLER_RELATIONSHIP.IMPORTER }),
    readinessRejects: true,
    eligibilityReason: "eligibility_seller_relationship_snapshot_mismatch",
  },
  {
    id: 7,
    name: "evidence revision drift",
    mutate: async ({ businessId }) => epochRef(businessId).set({ epoch: 9 }, { merge: true }),
    readinessRejects: true,
    eligibilityReason: "eligibility_evidence_revision_mismatch",
  },
  {
    id: 8,
    name: "evidence digest drift",
    mutate: async ({ productId }) => {
      const d = (await decRef(productId).get()).data();
      await decRef(productId).update({
        activeEvidenceRefs: [
          ...d.activeEvidenceRefs,
          { documentId: nextId("planted"), scopeId: nextId("planted"), expiresAt: FUTURE() },
        ],
      });
    },
    readinessRejects: true,
    eligibilityReason: "eligibility_decision_hash_mismatch",
  },
  {
    id: 9,
    name: "expired validUntil",
    mutate: async ({ productId }) => decRef(productId).update({ validUntil: PAST() }),
    readinessRejects: true,
  },
  {
    id: 10,
    name: "non-eligible effectiveStatus",
    mutate: async ({ productId }) => decRef(productId).update({ effectiveStatus: "evidence_missing" }),
    readinessRejects: true,
  },
  {
    id: 11,
    name: "sibling product decision replay",
    mutate: async ({ productId }) => {
      const sibling = await seedWorld();
      const siblingDecision = (await decRef(sibling.productId).get()).data();
      await decRef(productId).set(siblingDecision);
    },
    readinessRejects: true,
  },
  {
    id: 12,
    name: "earlier business generation",
    mutate: async ({ businessId, productId }) =>
      prodRef(businessId, productId).update({
        marketplaceBusinessGenerationId: "gen-previous",
      }),
    readinessRejects: true,
  },
  {
    id: 13,
    name: "missing decision",
    mutate: async ({ productId }) => decRef(productId).delete(),
    readinessRejects: true,
  },
  {
    id: 14,
    name: "malformed decision (unknown field)",
    mutate: async ({ productId }) => decRef(productId).update({ injectedField: "surprise" }),
    readinessRejects: true,
    eligibilityReason: "eligibility_decision_malformed",
  },
  {
    id: "14b",
    name: "malformed decision (wrong-typed required slots)",
    mutate: async ({ productId }) => decRef(productId).update({ requiredEvidenceSlots: "nope" }),
    readinessRejects: true,
    eligibilityReason: "eligibility_decision_malformed",
  },
  {
    id: "14c",
    name: "malformed live state (invalid seller relationship)",
    mutate: async ({ businessId, productId }) =>
      prodRef(businessId, productId).update({ sellerRelationship: "not_a_relationship" }),
    readinessRejects: true,
    eligibilityReason: "eligibility_seller_relationship_invalid",
  },
  {
    id: 15,
    name: "unsupported pilot class",
    mutate: async ({ businessId, productId }) =>
      prodRef(businessId, productId).update({ pilotProductClass: "vitamins" }),
    readinessRejects: true,
  },
  {
    id: "15b",
    name: "missing pilot class",
    mutate: async ({ businessId, productId }) =>
      prodRef(businessId, productId).update({
        pilotProductClass: admin.firestore.FieldValue.delete(),
      }),
    readinessRejects: true,
  },
];

for (const scenario of SCENARIOS) {
  itest(
    `PARITY-${scenario.id}. ${scenario.name}: readiness and approval agree`,
    async () => {
      const adminUid = await seedAdmin();
      const world = await seedWorld();
      await scenario.mutate(world);

      const before = await snapshotState(world.businessId, world.productId);
      const r = await readiness(adminUid, world.businessId, world.productId);
      const a = await outcomeOf(
        approveWithLiveFingerprint(adminUid, world.businessId, world.productId)
      );

      if (!scenario.readinessRejects) {
        assert.equal(r.ready, true, `readiness should be ready, got ${r.reasonCode}`);
        assert.equal(a.ok, true, `approval should succeed, got ${JSON.stringify(a)}`);
        assert.equal(a.value.active, true);
        return;
      }

      // --- THE INVARIANT ---
      assert.equal(r.ready, false, "fixture must actually be rejected by readiness");
      assert.ok(r.reasonCode, "readiness must give a reason");
      assert.equal(
        a.ok,
        false,
        `INVARIANT VIOLATED: readiness rejected (${r.reasonCode}) but approval ACCEPTED`
      );
      if (scenario.eligibilityReason) {
        assert.equal(a.reasonCode, "compliance-not-live-eligible", scenario.name);
        assert.equal(a.eligibilityReason, scenario.eligibilityReason, scenario.name);
      }

      // --- and the rejection left nothing behind ---
      const after = await snapshotState(world.businessId, world.productId);
      assert.equal(after.isActive, false, "must not publish");
      assert.notEqual(after.moderationStatus, "approved", "must stay unpublished");
      assert.equal(after.pilotProductApproval, null, "no approval object may be written");
      assert.equal(after.pilotActiveProductCount, before.pilotActiveProductCount, "counter frozen");
      assert.equal(after.auditEvents, before.auditEvents, "no approval audit event");
      assert.equal(after.pilotProductClass, before.pilotProductClass, "classification untouched");
      assert.deepEqual(after.decision, before.decision, "decision untouched");
      assert.equal(after.evidenceDocs, before.evidenceDocs, "evidence untouched");
      assert.deepEqual(after.evidenceStatuses, before.evidenceStatuses, "evidence untouched");
    }
  );
}

// =====================================================================
// The legitimate asymmetry: approval may reject MORE than readiness, but
// only for non-compliance reasons.
// =====================================================================

itest("16. readiness ready may still be rejected by approval for a stale fingerprint", async () => {
  const adminUid = await seedAdmin();
  const { businessId, productId } = await seedWorld();
  const r = await readiness(adminUid, businessId, productId);
  assert.equal(r.ready, true);

  // Content moves after readiness; the token is now stale but the product is
  // still fully compliance-eligible.
  await prodRef(businessId, productId).update({ price: 999 });
  const rAgain = await readiness(adminUid, businessId, productId);
  assert.equal(rAgain.ready, true, "still compliance-eligible");

  const a = await outcomeOf(
    functions.approvePilotProduct.run({
      auth: { uid: adminUid },
      data: {
        businessId,
        productId,
        allowedPilotCategory: "food",
        reviewedContentFingerprint: r.approvalFingerprint,
        attestNoProhibitedClaim: true,
      },
    })
  );
  assert.equal(a.ok, false);
  assert.equal(a.reasonCode, "stale-content");
  assert.equal((await prodRef(businessId, productId).get()).data().isActive, false);
});

itest("16b. readiness ready may still be rejected for an invalid moderation transition", async () => {
  const adminUid = await seedAdmin();
  const { businessId, productId } = await seedWorld();
  assert.equal((await readiness(adminUid, businessId, productId)).ready, true);
  // `rejected` is not a state approval may transition from. Readiness reports
  // it too; the point here is that approval refuses independently.
  await prodRef(businessId, productId).update({ moderationStatus: "rejected" });
  const a = await outcomeOf(approveWithLiveFingerprint(adminUid, businessId, productId));
  assert.equal(a.ok, false);
  assert.equal(a.reasonCode, "invalid-transition");
});

itest("16c. an already-approved product: readiness blocks, approval replays idempotently and publishes nothing new", async () => {
  const adminUid = await seedAdmin();
  const { businessId, productId } = await seedWorld();
  const first = await approveWithLiveFingerprint(adminUid, businessId, productId);
  assert.equal(first.active, true);

  const r = await readiness(adminUid, businessId, productId);
  assert.equal(r.ready, false);
  assert.equal(r.reasonCode, "readiness-already-approved");

  const countBefore = (await bizRef(businessId).get()).data().pilotActiveProductCount;
  const auditBefore = (
    await db.collection(AUDIT_EVENTS_COLLECTION).where("productId", "==", productId).get()
  ).size;

  const replay = await approveWithLiveFingerprint(adminUid, businessId, productId);
  assert.equal(replay.idempotent, true, "an unchanged replay is a no-op, never a second approval");
  assert.equal((await bizRef(businessId).get()).data().pilotActiveProductCount, countBefore);
  assert.equal(
    (await db.collection(AUDIT_EVENTS_COLLECTION).where("productId", "==", productId).get()).size,
    auditBefore
  );
});

itest("16d. readiness ready may still be rejected for the active-product limit", async () => {
  const adminUid = await seedAdmin();
  const { businessId, productId } = await seedWorld();
  await bizRef(businessId).update({ pilotActiveProductCount: PILOT_PRODUCT_ACTIVE_LIMIT });
  const r = await readiness(adminUid, businessId, productId);
  assert.equal(r.ready, false);
  assert.equal(r.reasonCode, "readiness-limit-exceeded");
  const a = await outcomeOf(approveWithLiveFingerprint(adminUid, businessId, productId));
  assert.equal(a.ok, false);
  assert.equal(a.reasonCode, "limit-exceeded");
  assert.equal((await prodRef(businessId, productId).get()).data().isActive, false);
});

// =====================================================================
// 17. Direct invocation cannot bypass the readiness gate.
// =====================================================================

itest("17. a direct callable invocation cannot approve a state readiness rejects, even with a perfect live fingerprint", async () => {
  const adminUid = await seedAdmin();
  // The full drift matrix, exercised WITHOUT ever consulting readiness — the
  // exact posture of a caller that never loaded the Admin screen.
  const drifts = [
    ["policy pointer", async () => seedSyntheticActivePolicy()],
    ["decisionHash", async (w) => decRef(w.productId).update({ decisionHash: "1".repeat(64) })],
    ["input revision", async (w) => prodRef(w.businessId, w.productId).update({ productInputRevision: 3 })],
    ["class snapshot", async (w) => decRef(w.productId).update({ pilotProductClassSnapshot: null })],
    ["relationship snapshot", async (w) => decRef(w.productId).update({ sellerRelationshipSnapshot: "brand_owner" })],
    ["evidence revision", async (w) => epochRef(w.businessId).set({ epoch: 4 }, { merge: true })],
  ];
  for (const [label, mutate] of drifts) {
    const world = await seedWorld();
    await mutate(world);
    const a = await outcomeOf(
      approveWithLiveFingerprint(adminUid, world.businessId, world.productId)
    );
    assert.equal(a.ok, false, `${label}: direct invocation must not approve`);
    assert.equal(a.reasonCode, "compliance-not-live-eligible", label);
    const product = (await prodRef(world.businessId, world.productId).get()).data();
    assert.equal(product.isActive, false, label);
    assert.equal(product.pilotProductApproval, undefined, label);
    assert.equal((await bizRef(world.businessId).get()).data().pilotActiveProductCount, 0, label);
  }
});

itest("18. readiness itself never publishes and never writes, on ready and blocked alike", async () => {
  const adminUid = await seedAdmin();
  const ready = await seedWorld();
  const blocked = await seedWorld();
  await decRef(blocked.productId).delete();

  for (const world of [ready, blocked]) {
    const before = await snapshotState(world.businessId, world.productId);
    await readiness(adminUid, world.businessId, world.productId);
    await readiness(adminUid, world.businessId, world.productId);
    const after = await snapshotState(world.businessId, world.productId);
    assert.deepEqual(after, before, "readiness must be byte-for-byte read-only");
  }
});

itest("19. approval remains the only activation mutation on this path", async () => {
  const source = fs.readFileSync(
    path.join(__dirname, "..", "src", "marketplace", "compliance", "pilotProductApprovalReadiness.js"),
    "utf8"
  );
  const executable = source
    .split("\n")
    .filter((l) => !l.trim().startsWith("//"))
    .join("\n");
  for (const write of ["tx.set(", "tx.update(", "tx.create(", "tx.delete(", "FieldValue"]) {
    assert.equal(executable.includes(write), false, `readiness must never ${write}`);
  }

  // And approval consumes the canonical predicate rather than a private copy.
  const approvalSource = fs.readFileSync(
    path.join(__dirname, "..", "src", "marketplace", "compliance", "pilotProductApproval.js"),
    "utf8"
  );
  const approvalExecutable = approvalSource
    .split("\n")
    .filter((l) => !l.trim().startsWith("//"))
    .join("\n");
  assert.ok(
    approvalExecutable.includes("evaluateLiveProductEligibility("),
    "approval must call the canonical predicate"
  );
  assert.ok(
    /evaluateLiveProductEligibility\(\{[^}]*\btx,/s.test(approvalExecutable),
    "approval must pass its own transaction to the predicate"
  );
  // Exactly one definition of the predicate exists anywhere in src/.
  const evaluatorSource = fs.readFileSync(
    path.join(__dirname, "..", "src", "marketplace", "compliance", "complianceEligibilityEvaluator.js"),
    "utf8"
  );
  assert.equal(
    (evaluatorSource.match(/async function evaluateLiveProductEligibility/g) || []).length,
    1
  );
});

// =====================================================================
// Phase 6 — CONCURRENCY: changes landing AFTER readiness but BEFORE the
// approval transaction.
//
// Each case loads a genuinely ready snapshot, mutates authoritative state,
// then approves with the fingerprint readiness handed back — the realistic
// race. The approval transaction must see the LATEST state and reject with no
// partial mutation.
// =====================================================================

const CONCURRENT_MUTATIONS = [
  {
    name: "product content changed",
    mutate: async (w) => prodRef(w.businessId, w.productId).update({ price: 4242 }),
  },
  {
    name: "pilotProductClass changed",
    mutate: async (w) =>
      prodRef(w.businessId, w.productId).update({
        pilotProductClass: PILOT_PRODUCT_CLASS.NON_BIOCIDAL_LITTER,
      }),
  },
  {
    name: "policy pointer changed",
    mutate: async () => seedSyntheticActivePolicy(),
  },
  {
    name: "decision replaced",
    mutate: async (w) => {
      const other = await seedWorld();
      await decRef(w.productId).set((await decRef(other.productId).get()).data());
    },
  },
  {
    name: "decision expired",
    mutate: async (w) => decRef(w.productId).update({ validUntil: PAST() }),
  },
  {
    name: "evidence revision changed",
    mutate: async (w) => epochRef(w.businessId).set({ epoch: 11 }, { merge: true }),
  },
  {
    name: "business generation changed",
    mutate: async (w) =>
      bizRef(w.businessId).update({ marketplaceBusinessGenerationId: "gen-next" }),
  },
  {
    name: "seller activation revoked",
    mutate: async (w) =>
      bizRef(w.businessId).update({ marketplaceSellerActivation: { active: false } }),
  },
];

for (const c of CONCURRENT_MUTATIONS) {
  itest(
    `CONCURRENCY. ${c.name} between readiness and approval rejects with no partial mutation`,
    async () => {
      const adminUid = await seedAdmin();
      const world = await seedWorld();

      const r = await readiness(adminUid, world.businessId, world.productId);
      assert.equal(r.ready, true, `fixture must start ready, got ${r.reasonCode}`);

      const before = await snapshotState(world.businessId, world.productId);
      await c.mutate(world);

      const a = await outcomeOf(
        functions.approvePilotProduct.run({
          auth: { uid: adminUid },
          data: {
            businessId: world.businessId,
            productId: world.productId,
            allowedPilotCategory: "food",
            // The token readiness handed back, exactly as the Admin UI sends it.
            reviewedContentFingerprint: r.approvalFingerprint,
            attestNoProhibitedClaim: true,
          },
        })
      );

      assert.equal(a.ok, false, `${c.name}: approval must reject the changed state`);
      const after = await snapshotState(world.businessId, world.productId);
      assert.equal(after.isActive, false, `${c.name}: nothing may be published`);
      assert.notEqual(after.moderationStatus, "approved", c.name);
      assert.equal(after.pilotProductApproval, null, `${c.name}: no approval object`);
      assert.equal(
        after.pilotActiveProductCount,
        before.pilotActiveProductCount,
        `${c.name}: counter`
      );
      assert.equal(after.auditEvents, before.auditEvents, `${c.name}: no audit event`);
      assert.equal(after.evidenceDocs, before.evidenceDocs, `${c.name}: evidence`);
    }
  );
}

itest("CONCURRENCY. the approval transaction reads the LATEST state, not the state readiness saw", async () => {
  const adminUid = await seedAdmin();
  const world = await seedWorld();
  const r = await readiness(adminUid, world.businessId, world.productId);
  assert.equal(r.ready, true);

  // Drift, then repair back to a genuinely valid decision. If approval were
  // reusing anything readiness observed, the repaired state would be invisible
  // to it; because it re-reads inside its own transaction, the repaired state
  // is what it acts on.
  await decRef(world.productId).update({ decisionHash: "2".repeat(64) });
  const drifted = await outcomeOf(
    approveWithLiveFingerprint(adminUid, world.businessId, world.productId)
  );
  assert.equal(drifted.ok, false);
  assert.equal(drifted.reasonCode, "compliance-not-live-eligible");

  await recomputeProductComplianceStatus({
    db,
    businessId: world.businessId,
    productId: world.productId,
  });
  const repaired = await outcomeOf(
    approveWithLiveFingerprint(adminUid, world.businessId, world.productId)
  );
  assert.equal(repaired.ok, true, "the repaired, re-derived state is approvable");
  assert.equal(repaired.value.active, true);
});

itest("CONCURRENCY. two genuinely concurrent approvals of the same product produce exactly one activation", async () => {
  const adminUid = await seedAdmin();
  const world = await seedWorld();
  const product = (await prodRef(world.businessId, world.productId).get()).data();
  const decision = (await decRef(world.productId).get()).data();
  const fingerprint = computeApprovalFingerprint(product, decision, world.productId);
  const payload = {
    businessId: world.businessId,
    productId: world.productId,
    allowedPilotCategory: "food",
    reviewedContentFingerprint: fingerprint,
    attestNoProhibitedClaim: true,
  };

  const settled = await Promise.allSettled([
    functions.approvePilotProduct.run({ auth: { uid: adminUid }, data: payload }),
    functions.approvePilotProduct.run({ auth: { uid: adminUid }, data: payload }),
  ]);
  assert.ok(settled.some((s) => s.status === "fulfilled"), "at least one must succeed");

  assert.equal((await bizRef(world.businessId).get()).data().pilotActiveProductCount, 1);
  const audit = await db
    .collection(AUDIT_EVENTS_COLLECTION)
    .where("productId", "==", world.productId)
    .get();
  assert.equal(audit.size, 1, "exactly one approval audit event");
});
