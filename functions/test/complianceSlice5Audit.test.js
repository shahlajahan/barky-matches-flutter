"use strict";

// Marketplace Revision 30 §J Slice 5 — completeness and non-vacuity audit.
//
// Reachability, staleness, isolation, link-vs-decision separation, and the
// compound proof that the "redundant" relationship/expiry guards are real.
// Emulator-only synthetic fixtures throughout; no live document, no
// production data, no policy activated in any real project.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();

const {
  recomputeProductComplianceStatus,
} = require("../src/marketplace/compliance/complianceProductRecompute");
const {
  evaluateProductComplianceDecision,
  EVALUATION_REQUEST_ALLOWED_FIELDS,
} = require("../src/marketplace/compliance/complianceProductEvaluation");
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
  PRODUCT_COMPLIANCE_ELIGIBLE_STATUSES,
} = require("../src/marketplace/compliance/complianceConstants");

const hasFs = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const itest = (n, f) => test(n, { skip: !hasFs }, f);
const quiet = { info() {}, warn() {}, error() {} };

let seq = 0;
// A per-RUN random token. These suites run as separate files, which node's
// test runner executes in parallel, so a `${prefix}-${Date.now()}-${seq}`
// id can collide across files within the same millisecond — producing a
// shared businessId whose scopes then satisfy both suites' products and
// silently corrupting evidence-ref counts. The token makes every id unique
// to one process regardless of timing.
const RUN_TOKEN = `aud${Math.random().toString(36).slice(2, 8)}`;
const nextId = (p) => {
  seq += 1;
  return `${p}-${RUN_TOKEN}-${seq}`;
};
const FUTURE = () => admin.firestore.Timestamp.fromMillis(Date.now() + 365 * 86400000);
const PAST = () => admin.firestore.Timestamp.fromMillis(Date.now() - 86400000);

async function seedAdmin() {
  const uid = nextId("audit-admin");
  await db.collection("users").doc(uid).set({ role: "admin" });
  return uid;
}

async function seedPolicy() {
  const versionId = nextId("audit-policy");
  await db
    .collection("compliancePolicyRegistry")
    .doc(versionId)
    .set(
      buildRevision30PolicyVersion({
        createdBy: "emulator-audit-fixture",
        effectiveFrom: PAST(),
        createdAt: PAST(),
        changeNote: "SYNTHETIC emulator-only",
        status: COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE,
      })
    );
  await db
    .collection("compliancePolicyRegistryPointer")
    .doc("current")
    .set({ activeVersionId: versionId });
  return versionId;
}

/// A pending, inactive product with eligible evidence — the exact shape the
/// hourly sweep cannot see.
async function seedPendingWorld({
  relationship = SELLER_RELATIONSHIP.RESELLER,
  documentType = COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE,
  scopeType = COMPLIANCE_SCOPE_TYPE.PRODUCT,
  scopeValueOverride,
  documentOverrides = {},
  scopeOverrides = {},
} = {}) {
  const businessId = nextId("biz");
  const productId = nextId("prod");
  const documentId = nextId("doc");
  const scopeId = nextId("scope");
  const generationId = `gen-${businessId}`;
  const validUntil = FUTURE();

  await db
    .collection("businesses")
    .doc(businessId)
    .set({ ownerUid: nextId("seller"), marketplaceBusinessGenerationId: generationId });

  await db
    .collection("businesses")
    .doc(businessId)
    .collection("products")
    .doc(productId)
    .set({
      businessId,
      marketplaceBusinessGenerationId: generationId,
      sellerRelationship: relationship,
      brand: "ACME",
      sku: "SKU-1",
      category: "Health > Vitamins",
      productInputRevision: 0,
      isActive: false,
      moderationStatus: "pending_review",
    });

  await db.collection("complianceDocuments").doc(documentId).set({
    businessId,
    marketplaceBusinessGenerationId: generationId,
    documentType,
    sellerRelationship: relationship,
    status: COMPLIANCE_DOCUMENT_STATUS.APPROVED,
    validUntil,
    contentHash: `hash-${documentId}`,
    ...documentOverrides,
  });

  await db.collection("complianceDocumentScopes").doc(scopeId).set({
    businessId,
    documentId,
    sellerRelationship: relationship,
    documentType,
    scopeType,
    scopeValue:
      scopeValueOverride !== undefined
        ? scopeValueOverride
        : scopeType === COMPLIANCE_SCOPE_TYPE.PRODUCT
          ? productId
          : "ACME",
    status: COMPLIANCE_SCOPE_STATUS.APPROVED,
    approvedAt: PAST(),
    validUntil,
    ...scopeOverrides,
  });

  return { businessId, productId, documentId, scopeId, generationId, validUntil };
}

const decisionFor = async (productId) => {
  const s = await db.collection("productComplianceDecisions").doc(productId).get();
  return s.exists ? s.data() : null;
};
const linksFor = async (productId) =>
  (await db.collection("productEvidenceLinks").where("productId", "==", productId).get()).docs;
const isPositive = (d) =>
  d != null && PRODUCT_COMPLIANCE_ELIGIBLE_STATUSES.includes(d.effectiveStatus);

// =========================================================================
// Q1 — first-decision reachability for a pending, inactive product
// =========================================================================

itest("Q1. the sweep's own candidate filter cannot see a pending product", async () => {
  await seedPolicy();
  const { businessId, productId } = await seedPendingWorld();

  // The exact query complianceProductRecomputeSweep.js runs.
  const swept = await db
    .collectionGroup("products")
    .where("isActive", "==", true)
    .where("moderationStatus", "==", "approved")
    .get();
  const paths = swept.docs.map((d) => d.ref.path);
  assert.equal(
    paths.some((p) => p.includes(productId)),
    false,
    "a pending, inactive product is outside the sweep by construction"
  );
  // ...and it therefore has no decision at all yet.
  assert.equal(await decisionFor(productId), null);
  void businessId;
});

itest("Q1. the explicit evaluation gives a pending product its first decision", async () => {
  await seedPolicy();
  const adminUid = await seedAdmin();
  const { businessId, productId } = await seedPendingWorld();
  assert.equal(await decisionFor(productId), null, "no decision before");

  const result = await evaluateProductComplianceDecision({
    db,
    auth: { uid: adminUid },
    data: { businessId, productId },
    logger: quiet,
  });

  const decision = await decisionFor(productId);
  assert.ok(decision, "a decision now exists for a pending product");
  assert.ok(isPositive(decision));
  assert.equal(result.productId, productId);
  assert.equal(result.effectiveStatus, decision.effectiveStatus);
});

itest("Q1. evaluating never activates, approves, classifies or publishes", async () => {
  await seedPolicy();
  const adminUid = await seedAdmin();
  const { businessId, productId } = await seedPendingWorld();
  await evaluateProductComplianceDecision({
    db,
    auth: { uid: adminUid },
    data: { businessId, productId },
    logger: quiet,
  });
  const product = (
    await db.collection("businesses").doc(businessId).collection("products").doc(productId).get()
  ).data();
  assert.equal(product.isActive, false);
  assert.equal(product.moderationStatus, "pending_review");
  assert.equal(product.pilotProductApproval, undefined);
  assert.equal(product.pilotProductClass, undefined);
  assert.equal(product.complianceEffectiveStatus, undefined);
  assert.equal(product.complianceValidUntil, undefined);
});

itest("Q1. the evaluation is admin-only and accepts no result from the caller", async () => {
  await seedPolicy();
  const { businessId, productId } = await seedPendingWorld();

  for (const auth of [null, { uid: nextId("stranger") }]) {
    await assert.rejects(
      evaluateProductComplianceDecision({ db, auth, data: { businessId, productId }, logger: quiet }),
      "only an admin may evaluate"
    );
  }
  assert.equal(await decisionFor(productId), null, "a denied call writes nothing");

  const adminUid = await seedAdmin();
  assert.deepEqual(EVALUATION_REQUEST_ALLOWED_FIELDS, ["businessId", "productId"]);
  for (const override of [
    { effectiveStatus: "verified_valid" },
    { decisionHash: "forged" },
    { policyVersion: "attacker-policy" },
    { marketplaceBusinessGenerationId: "gen-x" },
    { activeEvidenceRefs: [] },
    { evidenceRevision: 99 },
    { computedAt: Date.now() },
  ]) {
    await assert.rejects(
      evaluateProductComplianceDecision({
        db,
        auth: { uid: adminUid },
        data: { businessId, productId, ...override },
        logger: quiet,
      }),
      `${Object.keys(override)[0]} must be refused, not ignored`
    );
  }
});

itest("Q1. the system never claims a decision exists when none does", async () => {
  await seedPolicy();
  const { productId } = await seedPendingWorld();
  // The regression the audit asks for: absence is absence. Nothing anywhere
  // fabricates a decision document for a product that was never evaluated.
  assert.equal(await decisionFor(productId), null);
  assert.equal((await linksFor(productId)).length, 0);
});

// =========================================================================
// Q2 — stale and out-of-order evaluation
// =========================================================================

itest("Q2. an evaluation running after a state change reflects the NEW state, never a restored older one", async () => {
  await seedPolicy();
  const adminUid = await seedAdmin();
  const { businessId, productId, documentId } = await seedPendingWorld();

  // A: a positive decision from the original evidence.
  await recomputeProductComplianceStatus({ db, businessId, productId });
  const first = await decisionFor(productId);
  assert.ok(isPositive(first));

  // Canonical state changes: the document is revoked.
  await db
    .collection("complianceDocuments")
    .doc(documentId)
    .update({ status: COMPLIANCE_DOCUMENT_STATUS.REVOKED });

  // B: the newer decision.
  await recomputeProductComplianceStatus({ db, businessId, productId });
  const second = await decisionFor(productId);
  assert.equal(isPositive(second), false);

  // A "late" evaluation — dispatched from an older intent — cannot restore
  // the older positive decision, because every authoritative input is read
  // INSIDE the transaction at execution time. There is no carried-over
  // input for a stale run to write back.
  await evaluateProductComplianceDecision({
    db,
    auth: { uid: adminUid },
    data: { businessId, productId },
    logger: quiet,
  });
  const third = await decisionFor(productId);
  assert.equal(isPositive(third), false, "an older intent must not restore eligibility");
  assert.equal(third.decisionHash, second.decisionHash);
});

itest("Q2. concurrent evaluations converge on the final canonical state and leave one decision", async () => {
  await seedPolicy();
  const { businessId, productId, documentId } = await seedPendingWorld();

  // Fire several evaluations while the canonical state flips underneath.
  const flip = (async () => {
    await db
      .collection("complianceDocuments")
      .doc(documentId)
      .update({ status: COMPLIANCE_DOCUMENT_STATUS.REVOKED });
  })();
  await Promise.allSettled([
    recomputeProductComplianceStatus({ db, businessId, productId }),
    recomputeProductComplianceStatus({ db, businessId, productId }),
    flip,
    recomputeProductComplianceStatus({ db, businessId, productId }),
  ]);

  // Whatever the interleaving, a final settling evaluation must agree with
  // the final canonical state, and exactly one decision document exists.
  await recomputeProductComplianceStatus({ db, businessId, productId });
  const decision = await decisionFor(productId);
  assert.equal(isPositive(decision), false);
  const all = await db
    .collection("productComplianceDecisions")
    .where("businessId", "==", businessId)
    .get();
  assert.equal(all.size, 1);
});

test("Q2. the prior decision is read inside the transaction, putting it in the read set", () => {
  // This is WHY a concurrent write forces a retry rather than a blind
  // overwrite: Firestore aborts and re-runs a transaction whose read set
  // changed, so a late evaluation re-reads fresh inputs before committing.
  const fs = require("node:fs");
  const src = fs.readFileSync(
    "src/marketplace/compliance/complianceProductRecompute.js",
    "utf8"
  );
  const body = src.slice(
    src.indexOf("await db.runTransaction"),
    src.indexOf("return result;")
  );
  for (const readInTx of [
    "tx.get(productRef(db, businessId, productId))",
    "tx.get(epochRef(db, businessId))",
    "tx.get(decisionRef(db, productId))",
  ]) {
    assert.ok(body.includes(readInTx), `${readInTx} must be read inside the transaction`);
  }
  // And the decision is written in that same transaction, not outside it.
  assert.ok(body.includes("tx.set(decisionRef(db, productId), decisionDoc)"));
});

// =========================================================================
// Q3 — product, scope and generation isolation
// =========================================================================

itest("Q3. product-scoped evidence for product A cannot satisfy product B in the same business", async () => {
  await seedPolicy();
  const a = await seedPendingWorld();

  // Product B in the SAME business, same relationship, same everything —
  // only its id differs, and the scope names A.
  const productB = nextId("prod-b");
  await db
    .collection("businesses")
    .doc(a.businessId)
    .collection("products")
    .doc(productB)
    .set({
      businessId: a.businessId,
      marketplaceBusinessGenerationId: a.generationId,
      sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
      brand: "ACME",
      sku: "SKU-2",
      category: "Health > Vitamins",
      productInputRevision: 0,
      isActive: false,
      moderationStatus: "pending_review",
    });

  await recomputeProductComplianceStatus({ db, businessId: a.businessId, productId: productB });
  assert.equal(
    isPositive(await decisionFor(productB)),
    false,
    "a product-scoped document must not authorize a sibling product"
  );
  // ...while A itself is satisfied by the very same document.
  await recomputeProductComplianceStatus({ db, businessId: a.businessId, productId: a.productId });
  assert.ok(isPositive(await decisionFor(a.productId)));
});

itest("Q3. a business-wide scope satisfies only a relationship whose policy accepts it", async () => {
  await seedPolicy();
  // reseller's frozen branch accepts product and sku_set — NOT business.
  const w = await seedPendingWorld({
    scopeType: COMPLIANCE_SCOPE_TYPE.BUSINESS,
    scopeValueOverride: undefined,
  });
  await db
    .collection("complianceDocumentScopes")
    .doc(w.scopeId)
    .update({ scopeValue: w.businessId });

  await recomputeProductComplianceStatus({ db, businessId: w.businessId, productId: w.productId });
  assert.equal(
    isPositive(await decisionFor(w.productId)),
    false,
    "business-wide evidence must not widen into a product-scoped relationship"
  );
});

itest("Q3. widening a copied scope field cannot broaden a product-scoped document", async () => {
  await seedPolicy();
  const w = await seedPendingWorld();
  const other = nextId("prod-other");
  await db
    .collection("businesses")
    .doc(w.businessId)
    .collection("products")
    .doc(other)
    .set({
      businessId: w.businessId,
      marketplaceBusinessGenerationId: w.generationId,
      sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
      brand: "ACME",
      sku: "SKU-3",
      category: "Health > Vitamins",
      productInputRevision: 0,
      isActive: false,
      moderationStatus: "pending_review",
    });
  // Flip the scope's own type/value to "business" — the widening a tampered
  // copy would attempt. reseller does not accept business scope, so it fails
  // closed rather than covering every product.
  await db
    .collection("complianceDocumentScopes")
    .doc(w.scopeId)
    .update({ scopeType: COMPLIANCE_SCOPE_TYPE.BUSINESS, scopeValue: w.businessId });

  await recomputeProductComplianceStatus({ db, businessId: w.businessId, productId: other });
  assert.equal(isPositive(await decisionFor(other)), false);
});

itest("Q3. a forged or stale productEvidenceLink cannot make a decision positive", async () => {
  await seedPolicy();
  const w = await seedPendingWorld({ documentOverrides: { status: COMPLIANCE_DOCUMENT_STATUS.REJECTED } });

  // A hand-written link that looks exactly like a real one. The engine never
  // reads productEvidenceLinks when deciding — links are output, not input.
  await db
    .collection("productEvidenceLinks")
    .doc(nextId("forged-link"))
    .set({
      businessId: w.businessId,
      productId: w.productId,
      documentId: w.documentId,
      scopeId: w.scopeId,
      matchedVia: COMPLIANCE_SCOPE_TYPE.PRODUCT,
      linkedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  await recomputeProductComplianceStatus({ db, businessId: w.businessId, productId: w.productId });
  assert.equal(
    isPositive(await decisionFor(w.productId)),
    false,
    "a forged link must confer nothing; the rejected document still governs"
  );
});

itest("Q3. a link naming the wrong product, scope, document or generation confers nothing", async () => {
  await seedPolicy();
  const good = await seedPendingWorld();
  const victim = await seedPendingWorld({ documentOverrides: { status: COMPLIANCE_DOCUMENT_STATUS.REJECTED } });

  for (const forged of [
    { productId: victim.productId, documentId: good.documentId, scopeId: good.scopeId },
    { productId: victim.productId, documentId: victim.documentId, scopeId: good.scopeId },
    { productId: victim.productId, documentId: good.documentId, scopeId: victim.scopeId },
  ]) {
    await db
      .collection("productEvidenceLinks")
      .doc(nextId("cross-link"))
      .set({
        businessId: victim.businessId,
        matchedVia: COMPLIANCE_SCOPE_TYPE.PRODUCT,
        linkedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...forged,
      });
  }
  await recomputeProductComplianceStatus({
    db,
    businessId: victim.businessId,
    productId: victim.productId,
  });
  assert.equal(isPositive(await decisionFor(victim.productId)), false);
});

// =========================================================================
// Q4 — link vs decision vs product state
// =========================================================================

itest("Q4. links are written as OUTPUT of a decision and never read as input", async () => {
  await seedPolicy();
  const w = await seedPendingWorld();
  assert.equal((await linksFor(w.productId)).length, 0, "no link before evaluation");

  await recomputeProductComplianceStatus({ db, businessId: w.businessId, productId: w.productId });
  assert.ok(isPositive(await decisionFor(w.productId)));
  assert.equal((await linksFor(w.productId)).length, 1, "the link is produced by the decision");

  // The engine reads no link collection at all.
  const fs = require("node:fs");
  const matching = fs.readFileSync(
    "src/marketplace/compliance/complianceMatching.js",
    "utf8"
  );
  assert.equal(
    /collection\((?:"|')productEvidenceLinks/.test(matching),
    false,
    "the matching engine must never read productEvidenceLinks"
  );
});

itest("Q4. a positive decision writes nothing to the product document", async () => {
  await seedPolicy();
  const w = await seedPendingWorld();
  const productRef = db
    .collection("businesses")
    .doc(w.businessId)
    .collection("products")
    .doc(w.productId);
  const before = (await productRef.get()).data();

  await recomputeProductComplianceStatus({ db, businessId: w.businessId, productId: w.productId });
  assert.ok(isPositive(await decisionFor(w.productId)));

  const after = (await productRef.get()).data();
  assert.deepEqual(after, before, "the product document is byte-identical after a positive decision");
  for (const field of [
    "isActive",
    "moderationStatus",
    "pilotProductApproval",
    "pilotProductClass",
    "complianceEffectiveStatus",
    "complianceValidUntil",
    "evidenceRevision",
  ]) {
    assert.deepEqual(after[field], before[field], `${field} must be untouched`);
  }
  assert.equal(after.isActive, false);
  assert.equal(after.moderationStatus, "pending_review");
});

// =========================================================================
// Q5 — relationship and expiry: consistent-but-wrong fixtures
// =========================================================================

itest("Q5. a scope and document that AGREE on the wrong relationship are still refused", async () => {
  await seedPolicy();
  // Both sides say importer; the product says reseller. Copy consistency is
  // satisfied, so only policy/relationship matching can refuse this.
  const w = await seedPendingWorld({ relationship: SELLER_RELATIONSHIP.IMPORTER });
  await db
    .collection("businesses")
    .doc(w.businessId)
    .collection("products")
    .doc(w.productId)
    .update({ sellerRelationship: SELLER_RELATIONSHIP.RESELLER });

  await recomputeProductComplianceStatus({ db, businessId: w.businessId, productId: w.productId });
  assert.equal(
    isPositive(await decisionFor(w.productId)),
    false,
    "evidence for a different relationship must never satisfy this product"
  );
});

itest("Q5. a scope and document that AGREE on an expired date are still refused", async () => {
  await seedPolicy();
  const expired = admin.firestore.Timestamp.fromMillis(Date.now() - 60000);
  const w = await seedPendingWorld({
    documentOverrides: { validUntil: expired },
    scopeOverrides: { validUntil: expired },
  });
  await recomputeProductComplianceStatus({ db, businessId: w.businessId, productId: w.productId });
  assert.equal(
    isPositive(await decisionFor(w.productId)),
    false,
    "consistently-expired evidence must never satisfy a slot"
  );
});

test("Q5. every scope, link and decision writer is server-only, and clients are denied", () => {
  const fs = require("node:fs");
  const rules = fs
    .readFileSync("../firestore.rules", "utf8")
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/^[ \t]*\/\/.*$/gm, "");
  for (const collection of [
    "complianceDocumentScopes",
    "productEvidenceLinks",
    "productComplianceDecisions",
    "complianceDocuments",
    "compliancePolicyRegistry",
  ]) {
    const block = rules.slice(
      rules.indexOf(`match /${collection}/`),
      rules.indexOf(`match /${collection}/`) + 600
    );
    assert.ok(
      /allow create, update, delete: if false;/.test(block) ||
        /allow read, create, update, delete: if false;/.test(block),
      `${collection} must deny every client write`
    );
  }
});
