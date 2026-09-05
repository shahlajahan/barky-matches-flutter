"use strict";

// Marketplace Revision 30 §J Slice 5 — evidence linkage and decision engine.
//
// Everything here runs the REAL engine (`recomputeProductComplianceStatus` ->
// `runComplianceMatching` -> `resolveActivePolicy`) against the Firestore
// emulator, using clearly-labelled SYNTHETIC fixtures only. No live document,
// no production data, and no policy is ever activated in production — the
// registry rows below exist solely inside the emulator for the life of a test.

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
  REVISION_30_POLICY_BRANCHES,
  buildRevision30PolicyVersion,
} = require("../src/marketplace/compliance/complianceRevision30Policy");
const {
  SELLER_RELATIONSHIP,
  COMPLIANCE_DOCUMENT_TYPE,
  COMPLIANCE_DOCUMENT_STATUS,
  COMPLIANCE_SCOPE_TYPE,
  COMPLIANCE_SCOPE_STATUS,
  COMPLIANCE_POLICY_REGISTRY_STATUS,
  PRODUCT_COMPLIANCE_EFFECTIVE_STATUS,
  PRODUCT_COMPLIANCE_ELIGIBLE_STATUSES,
} = require("../src/marketplace/compliance/complianceConstants");

const hasFs = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const itest = (n, f) => test(n, { skip: !hasFs }, f);

let seq = 0;
// A per-RUN random token. These suites run as separate files, which node's
// test runner executes in parallel, so a `${prefix}-${Date.now()}-${seq}`
// id can collide across files within the same millisecond — producing a
// shared businessId whose scopes then satisfy both suites' products and
// silently corrupting evidence-ref counts. The token makes every id unique
// to one process regardless of timing.
const RUN_TOKEN = `lnk${Math.random().toString(36).slice(2, 8)}`;
const nextId = (p) => {
  seq += 1;
  return `${p}-${RUN_TOKEN}-${seq}`;
};

const FUTURE = () => admin.firestore.Timestamp.fromMillis(Date.now() + 365 * 86400000);
const PAST = () => admin.firestore.Timestamp.fromMillis(Date.now() - 86400000);

/// EMULATOR-ONLY synthetic policy. Written to the emulator's registry and
/// pointer so `resolveActivePolicy` resolves it exactly as production would;
/// never written to, or activated in, any real project.
async function seedSyntheticActivePolicy(overrides = {}) {
  const versionId = nextId("synthetic-policy");
  const body = buildRevision30PolicyVersion({
    createdBy: "emulator-test-fixture",
    effectiveFrom: PAST(),
    createdAt: PAST(),
    changeNote: "SYNTHETIC emulator-only Revision 30 §D transcription",
    status: COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE,
    ...overrides,
  });
  if (overrides.sellerRelationship) body.sellerRelationship = overrides.sellerRelationship;
  await db.collection("compliancePolicyRegistry").doc(versionId).set(body);
  await db
    .collection("compliancePolicyRegistryPointer")
    .doc("current")
    .set({ activeVersionId: versionId });
  return versionId;
}

async function clearPolicyPointer() {
  await db.collection("compliancePolicyRegistryPointer").doc("current").delete();
}

/// A complete, internally consistent world: business, product, approved
/// document(s), and an approved scope naming each document.
async function seedWorld({
  relationship = SELLER_RELATIONSHIP.RESELLER,
  documents = [{ type: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE }],
  scopeType = COMPLIANCE_SCOPE_TYPE.PRODUCT,
  productOverrides = {},
  documentOverrides = {},
  scopeOverrides = {},
} = {}) {
  const businessId = nextId("biz");
  const productId = nextId("prod");
  const generationId = `gen-${businessId}`;

  await db.collection("businesses").doc(businessId).set({
    ownerUid: nextId("seller"),
    marketplaceBusinessGenerationId: generationId,
  });

  const scopeValue = scopeType === COMPLIANCE_SCOPE_TYPE.PRODUCT ? productId : "ACME";

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
      productInputRevision: 0,
      isActive: false,
      moderationStatus: "pending_review",
      ...productOverrides,
    });

  const documentIds = [];
  for (const spec of documents) {
    const documentId = nextId("doc");
    documentIds.push(documentId);
    // ONE validity value shared by the document and its scope copy. The
    // engine requires every denormalized scope copy to agree with its source
    // to the millisecond — a disagreement invalidates the whole group — so
    // generating two separate timestamps here would test the inconsistency
    // guard rather than the happy path it is meant to set up.
    const validUntil = spec.validUntil || FUTURE();
    await db.collection("complianceDocuments").doc(documentId).set({
      businessId,
      marketplaceBusinessGenerationId: generationId,
      documentType: spec.type,
      sellerRelationship: spec.relationship || relationship,
      status: spec.status === undefined ? COMPLIANCE_DOCUMENT_STATUS.APPROVED : spec.status,
      validUntil,
      contentHash: `hash-${documentId}`,
      storagePath: `compliance_docs/${businessId}/${documentId}/o.pdf`,
      ...documentOverrides,
    });

    await db.collection("complianceDocumentScopes").doc(nextId("scope")).set({
      businessId,
      documentId,
      sellerRelationship: spec.relationship || relationship,
      documentType: spec.type,
      scopeType,
      scopeValue,
      status: COMPLIANCE_SCOPE_STATUS.APPROVED,
      approvedAt: PAST(),
      validUntil,
      ...scopeOverrides,
    });
  }

  return { businessId, productId, generationId, documentIds };
}

async function decisionFor(productId) {
  const snap = await db.collection("productComplianceDecisions").doc(productId).get();
  return snap.exists ? snap.data() : null;
}

async function linksFor(productId) {
  const snap = await db
    .collection("productEvidenceLinks")
    .where("productId", "==", productId)
    .get();
  return snap.docs;
}

function isPositive(decision) {
  return (
    decision != null &&
    PRODUCT_COMPLIANCE_ELIGIBLE_STATUSES.includes(decision.effectiveStatus)
  );
}

// --- the frozen §D transcription -----------------------------------------

test("the transcribed policy covers exactly the six frozen relationships", () => {
  assert.deepEqual(
    Object.keys(REVISION_30_POLICY_BRANCHES).sort(),
    Object.values(SELLER_RELATIONSHIP).sort()
  );
});

test("category_compliance_evidence appears in no branch and is never accepted", () => {
  const serialized = JSON.stringify(REVISION_30_POLICY_BRANCHES);
  assert.equal(
    serialized.includes(COMPLIANCE_DOCUMENT_TYPE.CATEGORY_COMPLIANCE_EVIDENCE),
    false
  );
});

test("the importer branch encodes a CONJUNCTION, not an OR", () => {
  const importer = REVISION_30_POLICY_BRANCHES[SELLER_RELATIONSHIP.IMPORTER];
  // Two required slots — a single slot listing all three types would be an
  // OR and would let one invoice satisfy the whole requirement.
  assert.equal(importer.requiredDocumentTypeGroups.length, 2);
  const [g1, g2] = importer.requiredDocumentTypeGroups.map((g) => g.documentTypes);
  assert.deepEqual([...g1], ["importer_evidence", "purchase_invoice"]);
  assert.deepEqual([...g2], ["importer_evidence", "supplier_agreement"]);
  // Neither conjunct alone appears in both groups.
  assert.equal(g1.includes("supplier_agreement"), false);
  assert.equal(g2.includes("purchase_invoice"), false);
});

test("every branch names only structurally usable scope types", () => {
  for (const branch of Object.values(REVISION_30_POLICY_BRANCHES)) {
    assert.ok(branch.acceptedScopeTypes.length >= 1);
    for (const t of branch.acceptedScopeTypes) {
      // supplier and product_family are ALWAYS_UNAVAILABLE and satisfy nothing.
      assert.notEqual(t, COMPLIANCE_SCOPE_TYPE.SUPPLIER);
      assert.notEqual(t, COMPLIANCE_SCOPE_TYPE.PRODUCT_FAMILY);
    }
  }
});

// --- the happy path -------------------------------------------------------

itest("eligible approved evidence yields a positive decision naming its evidence and policy version", async () => {
  const versionId = await seedSyntheticActivePolicy();
  const { productId, businessId, documentIds } = await seedWorld();

  await recomputeProductComplianceStatus({ db, businessId, productId });

  const decision = await decisionFor(productId);
  assert.ok(decision, "a decision document must exist");
  assert.ok(isPositive(decision), `expected eligible, got ${decision.effectiveStatus}`);
  // A positive decision identifies exactly what produced it.
  //
  // Asserted as "names a real, active policy version" rather than "names the
  // id THIS test seeded": `compliancePolicyRegistryPointer/current` is a
  // singleton by contract, so two test files running in parallel necessarily
  // contend for it. The invariant that matters — a positive decision records
  // the exact policy version it was computed against — is checked directly by
  // reading that version back and confirming it is active.
  assert.ok(
    typeof decision.policyVersion === "string" && decision.policyVersion.length > 0
  );
  const usedPolicy = await db
    .collection("compliancePolicyRegistry")
    .doc(decision.policyVersion)
    .get();
  assert.equal(usedPolicy.exists, true, "the recorded policy version must exist");
  assert.equal(usedPolicy.data().status, COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE);
  void versionId;
  assert.equal(decision.businessId, businessId);
  assert.equal(decision.activeEvidenceRefs.length, 1);
  assert.equal(decision.activeEvidenceRefs[0].documentId, documentIds[0]);
  assert.ok(decision.activeEvidenceRefs[0].scopeId);
  assert.ok(decision.decisionHash);
  assert.equal(typeof decision.evidenceRevision, "number");
  assert.equal(decision.sellerRelationshipSnapshot, SELLER_RELATIONSHIP.RESELLER);

  // A link is written as provenance.
  const links = await linksFor(productId);
  assert.equal(links.length, 1);
  assert.equal(links[0].data().documentId, documentIds[0]);
});

itest("a positive decision activates and publishes nothing", async () => {
  await seedSyntheticActivePolicy();
  const { productId, businessId } = await seedWorld();
  await recomputeProductComplianceStatus({ db, businessId, productId });
  assert.ok(isPositive(await decisionFor(productId)));

  // The product is untouched: still inactive, still pending, unclassified,
  // with no pilot approval. Slice 5 decides evidence, never publication.
  const product = (
    await db
      .collection("businesses")
      .doc(businessId)
      .collection("products")
      .doc(productId)
      .get()
  ).data();
  assert.equal(product.isActive, false);
  assert.equal(product.moderationStatus, "pending_review");
  assert.equal(product.pilotProductApproval, undefined);
  assert.equal(product.pilotProductClass, undefined);
  assert.equal(product.complianceEffectiveStatus, undefined);
});

// --- document lifecycle fail-closed ---------------------------------------

itest("only an approved document can support a positive decision", async () => {
  await seedSyntheticActivePolicy();
  for (const status of [
    COMPLIANCE_DOCUMENT_STATUS.CLEAN,
    COMPLIANCE_DOCUMENT_STATUS.PENDING_REVIEW,
    COMPLIANCE_DOCUMENT_STATUS.REJECTED,
    COMPLIANCE_DOCUMENT_STATUS.REVOKED,
    COMPLIANCE_DOCUMENT_STATUS.SUPERSEDED,
    COMPLIANCE_DOCUMENT_STATUS.EXPIRED,
    "a_future_status",
    "",
  ]) {
    const { productId, businessId } = await seedWorld({
      documents: [{ type: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE, status }],
    });
    await recomputeProductComplianceStatus({ db, businessId, productId });
    assert.equal(
      isPositive(await decisionFor(productId)),
      false,
      `status "${status}" must not produce a positive decision`
    );
  }
});

itest("expired validity fails closed", async () => {
  await seedSyntheticActivePolicy();
  const { productId, businessId } = await seedWorld({
    documents: [
      { type: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE, validUntil: PAST() },
    ],
  });
  await recomputeProductComplianceStatus({ db, businessId, productId });
  assert.equal(isPositive(await decisionFor(productId)), false);
});

// --- identity boundaries ---------------------------------------------------

itest("a document from another business cannot support a decision", async () => {
  await seedSyntheticActivePolicy();
  const mine = await seedWorld();
  const theirs = await seedWorld();
  // Re-point my scope at THEIR document — an id substitution attempt.
  const scopes = await db
    .collection("complianceDocumentScopes")
    .where("businessId", "==", mine.businessId)
    .get();
  await scopes.docs[0].ref.update({ documentId: theirs.documentIds[0] });

  await recomputeProductComplianceStatus({
    db,
    businessId: mine.businessId,
    productId: mine.productId,
  });
  assert.equal(isPositive(await decisionFor(mine.productId)), false);
});

itest("the business check alone blocks a foreign document that is otherwise identical", async () => {
  // Isolation matters here. The engine also rejects a scope copy that
  // disagrees with its source, so a foreign document with a different
  // validUntil would be caught by THAT guard and prove nothing about the
  // businessId check. This foreign document agrees on every other field —
  // type, relationship, validity, to the millisecond — so businessId is the
  // only thing that can refuse it.
  await seedSyntheticActivePolicy();
  const mine = await seedWorld();
  const scopeSnap = await db
    .collection("complianceDocumentScopes")
    .where("businessId", "==", mine.businessId)
    .get();
  const scope = scopeSnap.docs[0].data();

  const foreignId = nextId("foreign-doc");
  await db.collection("complianceDocuments").doc(foreignId).set({
    businessId: nextId("other-biz"), // the ONLY difference
    marketplaceBusinessGenerationId: mine.generationId,
    documentType: scope.documentType,
    sellerRelationship: scope.sellerRelationship,
    status: COMPLIANCE_DOCUMENT_STATUS.APPROVED,
    validUntil: scope.validUntil,
    contentHash: "hash-foreign",
  });
  await scopeSnap.docs[0].ref.update({ documentId: foreignId });

  await recomputeProductComplianceStatus({
    db,
    businessId: mine.businessId,
    productId: mine.productId,
  });
  assert.equal(
    isPositive(await decisionFor(mine.productId)),
    false,
    "a document owned by another business must never satisfy a slot"
  );
});

itest("the generation check alone blocks a document that is otherwise identical", async () => {
  // Same isolation discipline: everything agrees except the generation.
  await seedSyntheticActivePolicy();
  const mine = await seedWorld();
  const scopeSnap = await db
    .collection("complianceDocumentScopes")
    .where("businessId", "==", mine.businessId)
    .get();
  const scope = scopeSnap.docs[0].data();

  const staleId = nextId("stale-gen-doc");
  await db.collection("complianceDocuments").doc(staleId).set({
    businessId: mine.businessId,
    marketplaceBusinessGenerationId: "gen-PREVIOUS", // the ONLY difference
    documentType: scope.documentType,
    sellerRelationship: scope.sellerRelationship,
    status: COMPLIANCE_DOCUMENT_STATUS.APPROVED,
    validUntil: scope.validUntil,
    contentHash: "hash-stale",
  });
  await scopeSnap.docs[0].ref.update({ documentId: staleId });

  await recomputeProductComplianceStatus({
    db,
    businessId: mine.businessId,
    productId: mine.productId,
  });
  assert.equal(
    isPositive(await decisionFor(mine.productId)),
    false,
    "Revision 30 §F: earlier-generation evidence is never inherited"
  );
});

itest("evidence from a previous business generation is never inherited", async () => {
  await seedSyntheticActivePolicy();
  const { productId, businessId, documentIds } = await seedWorld();
  // The business was deleted and recreated: same id, new generation. The
  // product moves to the new generation; the document keeps the old one.
  await db
    .collection("businesses")
    .doc(businessId)
    .collection("products")
    .doc(productId)
    .update({ marketplaceBusinessGenerationId: "gen-RECREATED" });

  await recomputeProductComplianceStatus({ db, businessId, productId });
  assert.equal(
    isPositive(await decisionFor(productId)),
    false,
    "Revision 30 §F: no recreated generation may inherit earlier evidence"
  );
  // And the inverse: a document with no generation at all is not usable.
  await db
    .collection("complianceDocuments")
    .doc(documentIds[0])
    .update({ marketplaceBusinessGenerationId: admin.firestore.FieldValue.delete() });
  await db
    .collection("businesses")
    .doc(businessId)
    .collection("products")
    .doc(productId)
    .update({ marketplaceBusinessGenerationId: `gen-${businessId}` });
  await recomputeProductComplianceStatus({ db, businessId, productId });
  assert.equal(isPositive(await decisionFor(productId)), false);
});

itest("a mismatched seller relationship fails closed", async () => {
  await seedSyntheticActivePolicy();
  const { productId, businessId } = await seedWorld({
    relationship: SELLER_RELATIONSHIP.RESELLER,
    documents: [
      {
        type: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE,
        relationship: SELLER_RELATIONSHIP.IMPORTER,
      },
    ],
  });
  await recomputeProductComplianceStatus({ db, businessId, productId });
  assert.equal(isPositive(await decisionFor(productId)), false);
});

itest("a document type the branch does not accept fails closed", async () => {
  await seedSyntheticActivePolicy();
  for (const type of [
    COMPLIANCE_DOCUMENT_TYPE.TRADEMARK_EVIDENCE,
    COMPLIANCE_DOCUMENT_TYPE.CATEGORY_COMPLIANCE_EVIDENCE,
    "not_a_real_type",
  ]) {
    // reseller accepts only purchase_invoice / supplier_agreement.
    const { productId, businessId } = await seedWorld({
      relationship: SELLER_RELATIONSHIP.RESELLER,
      documents: [{ type }],
    });
    await recomputeProductComplianceStatus({ db, businessId, productId });
    assert.equal(
      isPositive(await decisionFor(productId)),
      false,
      `${type} must not satisfy a reseller slot`
    );
  }
});

// --- the importer conjunction, end to end ---------------------------------

itest("importer: neither conjunct alone suffices, and both together do", async () => {
  await seedSyntheticActivePolicy();

  // purchase_invoice alone — group 2 unsatisfied.
  const onlyInvoice = await seedWorld({
    relationship: SELLER_RELATIONSHIP.IMPORTER,
    scopeType: COMPLIANCE_SCOPE_TYPE.PRODUCT,
    documents: [{ type: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE }],
  });
  await recomputeProductComplianceStatus({
    db,
    businessId: onlyInvoice.businessId,
    productId: onlyInvoice.productId,
  });
  assert.equal(
    isPositive(await decisionFor(onlyInvoice.productId)),
    false,
    "purchase_invoice alone must never satisfy the importer conjunction"
  );

  // supplier_agreement alone — group 1 unsatisfied.
  const onlyAgreement = await seedWorld({
    relationship: SELLER_RELATIONSHIP.IMPORTER,
    documents: [{ type: COMPLIANCE_DOCUMENT_TYPE.SUPPLIER_AGREEMENT }],
  });
  await recomputeProductComplianceStatus({
    db,
    businessId: onlyAgreement.businessId,
    productId: onlyAgreement.productId,
  });
  assert.equal(
    isPositive(await decisionFor(onlyAgreement.productId)),
    false,
    "supplier_agreement alone must never satisfy the importer conjunction"
  );

  // Both together — accepted.
  const both = await seedWorld({
    relationship: SELLER_RELATIONSHIP.IMPORTER,
    documents: [
      { type: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE },
      { type: COMPLIANCE_DOCUMENT_TYPE.SUPPLIER_AGREEMENT },
    ],
  });
  await recomputeProductComplianceStatus({
    db,
    businessId: both.businessId,
    productId: both.productId,
  });
  const decision = await decisionFor(both.productId);
  assert.ok(isPositive(decision), "both conjuncts together must satisfy importer");
  assert.equal(decision.activeEvidenceRefs.length, 2);

  // And the minimum alone — importer_evidence — satisfies both groups.
  const minimum = await seedWorld({
    relationship: SELLER_RELATIONSHIP.IMPORTER,
    documents: [{ type: COMPLIANCE_DOCUMENT_TYPE.IMPORTER_EVIDENCE }],
  });
  await recomputeProductComplianceStatus({
    db,
    businessId: minimum.businessId,
    productId: minimum.productId,
  });
  assert.ok(isPositive(await decisionFor(minimum.productId)));
});

// --- policy fail-closed ---------------------------------------------------

itest("an absent policy pointer produces no positive decision", async () => {
  await clearPolicyPointer();
  const { productId, businessId } = await seedWorld();
  await assert.rejects(
    recomputeProductComplianceStatus({ db, businessId, productId }),
    "an unresolvable policy must not silently produce a decision"
  );
  assert.equal(isPositive(await decisionFor(productId)), false);
});

itest("an inactive or malformed policy version produces no positive decision", async () => {
  for (const overrides of [
    { status: COMPLIANCE_POLICY_REGISTRY_STATUS.DRAFT },
    { sellerRelationship: {} },
    { sellerRelationship: { reseller: { requiredDocumentTypeGroups: [] } } },
    { effectiveFrom: admin.firestore.Timestamp.fromMillis(Date.now() + 86400000) },
  ]) {
    await seedSyntheticActivePolicy(overrides);
    const { productId, businessId } = await seedWorld();
    try {
      await recomputeProductComplianceStatus({ db, businessId, productId });
    } catch (_) {
      // Failing closed by throwing is an acceptable outcome; what must never
      // happen is a positive decision.
    }
    assert.equal(
      isPositive(await decisionFor(productId)),
      false,
      `policy ${JSON.stringify(Object.keys(overrides))} must not yield eligibility`
    );
  }
});

itest("a relationship the active policy does not cover is policy_unresolved", async () => {
  // A policy naming only reseller, used by an importer product.
  await seedSyntheticActivePolicy({
    sellerRelationship: {
      reseller: JSON.parse(
        JSON.stringify(REVISION_30_POLICY_BRANCHES[SELLER_RELATIONSHIP.RESELLER])
      ),
    },
  });
  const { productId, businessId } = await seedWorld({
    relationship: SELLER_RELATIONSHIP.IMPORTER,
    documents: [{ type: COMPLIANCE_DOCUMENT_TYPE.IMPORTER_EVIDENCE }],
  });
  await recomputeProductComplianceStatus({ db, businessId, productId });
  const decision = await decisionFor(productId);
  assert.equal(
    decision.effectiveStatus,
    PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.POLICY_UNRESOLVED
  );
  assert.equal(isPositive(decision), false);
});

// --- idempotency and staleness --------------------------------------------

itest("repeated evaluation is idempotent: no duplicate link or decision", async () => {
  await seedSyntheticActivePolicy();
  const { productId, businessId } = await seedWorld();

  await recomputeProductComplianceStatus({ db, businessId, productId });
  const first = await decisionFor(productId);
  const firstLinks = await linksFor(productId);

  for (let i = 0; i < 3; i += 1) {
    await recomputeProductComplianceStatus({ db, businessId, productId });
  }
  const again = await decisionFor(productId);
  const againLinks = await linksFor(productId);

  assert.equal(againLinks.length, firstLinks.length, "links must not duplicate");
  assert.equal(againLinks.length, 1);
  assert.equal(again.decisionHash, first.decisionHash, "the decision is deterministic");
  assert.equal(again.effectiveStatus, first.effectiveStatus);
  assert.deepEqual(
    again.activeEvidenceRefs.map((r) => r.documentId),
    first.activeEvidenceRefs.map((r) => r.documentId)
  );

  const decisions = await db
    .collection("productComplianceDecisions")
    .where("businessId", "==", businessId)
    .get();
  assert.equal(decisions.size, 1, "exactly one decision document per product");
});

itest("losing the evidence turns a positive decision non-positive on re-evaluation", async () => {
  await seedSyntheticActivePolicy();
  const { productId, businessId, documentIds } = await seedWorld();
  await recomputeProductComplianceStatus({ db, businessId, productId });
  assert.ok(isPositive(await decisionFor(productId)));

  // The document is revoked. Re-evaluation must not keep the old positive
  // state — a link that still exists is provenance, never current eligibility.
  await db
    .collection("complianceDocuments")
    .doc(documentIds[0])
    .update({ status: COMPLIANCE_DOCUMENT_STATUS.REVOKED });
  await recomputeProductComplianceStatus({ db, businessId, productId });

  assert.equal(isPositive(await decisionFor(productId)), false);
  // The link record may survive as provenance; it must not confer eligibility.
  const links = await linksFor(productId);
  assert.ok(links.length >= 0);
});

itest("the decision records server-derived time, never a caller-supplied value", async () => {
  await seedSyntheticActivePolicy();
  const { productId, businessId } = await seedWorld();
  const before = Date.now();
  await recomputeProductComplianceStatus({ db, businessId, productId });
  const decision = await decisionFor(productId);
  // `computedAt` is written by the server inside the decision transaction.
  const computedMs = decision.computedAt.toMillis();
  assert.ok(computedMs >= before - 60000 && computedMs <= Date.now() + 60000);

  // The decision schema is closed: no caller-supplied override, reviewer
  // identity or precomputed result can appear in it.
  assert.deepEqual(Object.keys(decision).sort(), [
    "activeEvidenceRefs",
    "businessId",
    "computedAt",
    "decisionHash",
    "effectiveStatus",
    "evidenceRevision",
    // Marketplace Revision 35 (Slice 7A) — the authoritative pilot class the
    // decision was computed under, a bound decision-hash input.
    "pilotProductClassSnapshot",
    "policyVersion",
    "productInputRevisionSnapshot",
    "requiredEvidenceSlots",
    "satisfiedEvidenceSlots",
    "sellerRelationshipSnapshot",
    "validUntil",
  ]);
});
