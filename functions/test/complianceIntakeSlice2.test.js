"use strict";

// Marketplace Revision 30 §J Slice 2 — compliance intake backend hardening.
//
// The intake pipeline (session -> quarantine upload -> scan -> promotion)
// already existed and is NOT rebuilt here. This suite covers exactly the
// three contract gaps Slice 2 closes, plus the invariants that must hold
// while it does so:
//
//   A. Revision 30 §D — the declared sellerRelationship and the
//      relationship/document-type pair are validated at intake against the
//      frozen evidence matrix, and a document type the table assigns to no
//      relationship fails closed rather than being silently accepted.
//   B. Revision 30 §F — every session, every quarantine write and every
//      promoted document is bound to the business generation, so a business
//      deleted and recreated mid-flow can never inherit earlier evidence.
//   C. Business-existence probing on the intake endpoint is closed.
//
// Nothing here approves, verifies, links or publishes anything.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();
const functions = require("../index");

const {
  COMPLIANCE_INTAKE_EVIDENCE_MATRIX,
  COMPLIANCE_INTAKE_UNRESOLVED_DOCUMENT_TYPES,
  COMPLIANCE_DOCUMENT_TYPE,
  SELLER_RELATIONSHIP,
} = require("../src/marketplace/compliance/complianceConstants");
const {
  COMPLIANCE_INTAKE_PAIR_REASON,
  classifyComplianceIntakePair,
  isValidComplianceGenerationId,
} = require("../src/marketplace/compliance/complianceValidators");

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function itest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

let seq = 0;
function nextBusinessId() {
  seq += 1;
  return `slice2-intake-biz-${Date.now()}-${seq}`;
}

function allowCanary(businessId) {
  const existing = process.env.COMPLIANCE_UPLOAD_CANARY_BUSINESS_IDS || "";
  const entries = existing.split(",").map((e) => e.trim()).filter(Boolean);
  entries.push(businessId);
  process.env.COMPLIANCE_UPLOAD_CANARY_BUSINESS_IDS = entries.join(",");
}

async function seedBusiness(ownerUid, { generation = undefined, canary = true } = {}) {
  const businessId = nextBusinessId();
  const doc = { ownerUid };
  const gen = generation === undefined ? `gen-${businessId}` : generation;
  if (gen !== null) doc.marketplaceBusinessGenerationId = gen;
  await db.collection("businesses").doc(businessId).set(doc);
  if (canary) allowCanary(businessId);
  return { businessId, generation: gen };
}

const request = (businessId, overrides = {}) => ({
  businessId,
  originalFilename: "invoice.pdf",
  declaredMimeType: "application/pdf",
  declaredSizeBytes: 2048,
  documentType: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE,
  sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
  ...overrides,
});

async function callOrError(auth, data) {
  try {
    const result = await functions.createComplianceUploadSession.run({ auth, data });
    return { ok: true, result };
  } catch (error) {
    return { ok: false, code: error.code, message: error.message, details: error.details };
  }
}

// --- A. Evidence matrix (Revision 30 §D) -------------------------------

test("the intake matrix is transcribed exactly from Revision 30 §D", () => {
  assert.deepEqual(Object.keys(COMPLIANCE_INTAKE_EVIDENCE_MATRIX).sort(), [
    "authorized_dealer",
    "authorized_distributor",
    "brand_owner",
    "importer",
    "manufacturer",
    "reseller",
  ]);
  // Each row's own minimum evidence type, exactly as the table states it.
  assert.equal(COMPLIANCE_INTAKE_EVIDENCE_MATRIX.brand_owner[0], "trademark_evidence");
  assert.equal(COMPLIANCE_INTAKE_EVIDENCE_MATRIX.manufacturer[0], "manufacturer_evidence");
  assert.equal(
    COMPLIANCE_INTAKE_EVIDENCE_MATRIX.authorized_distributor[0],
    "dealership_distribution_agreement"
  );
  assert.equal(COMPLIANCE_INTAKE_EVIDENCE_MATRIX.authorized_dealer[0], "authorization_letter");
  assert.equal(COMPLIANCE_INTAKE_EVIDENCE_MATRIX.importer[0], "importer_evidence");
  assert.equal(COMPLIANCE_INTAKE_EVIDENCE_MATRIX.reseller[0], "purchase_invoice");

  // Every listed value is a real frozen document type — no invented ones.
  const known = Object.values(COMPLIANCE_DOCUMENT_TYPE);
  for (const [relationship, types] of Object.entries(COMPLIANCE_INTAKE_EVIDENCE_MATRIX)) {
    assert.ok(Object.values(SELLER_RELATIONSHIP).includes(relationship));
    for (const t of types) assert.ok(known.includes(t), `${t} is not a frozen document type`);
  }
});

test("category_compliance_evidence is assigned to no relationship and fails closed", () => {
  for (const types of Object.values(COMPLIANCE_INTAKE_EVIDENCE_MATRIX)) {
    assert.equal(
      types.includes(COMPLIANCE_DOCUMENT_TYPE.CATEGORY_COMPLIANCE_EVIDENCE),
      false
    );
  }
  assert.deepEqual(COMPLIANCE_INTAKE_UNRESOLVED_DOCUMENT_TYPES, [
    "category_compliance_evidence",
  ]);
  // Reported distinctly from an ordinary bad pair: it is a pending policy
  // question for the owner/counsel, not a caller mistake.
  for (const relationship of Object.values(SELLER_RELATIONSHIP)) {
    assert.equal(
      classifyComplianceIntakePair(
        relationship,
        COMPLIANCE_DOCUMENT_TYPE.CATEGORY_COMPLIANCE_EVIDENCE
      ),
      COMPLIANCE_INTAKE_PAIR_REASON.POLICY_UNRESOLVED
    );
  }
});

test("every permitted pair is accepted and every unlisted pair is refused", () => {
  const allTypes = Object.values(COMPLIANCE_DOCUMENT_TYPE);
  for (const relationship of Object.values(SELLER_RELATIONSHIP)) {
    const permitted = COMPLIANCE_INTAKE_EVIDENCE_MATRIX[relationship];
    for (const documentType of allTypes) {
      const verdict = classifyComplianceIntakePair(relationship, documentType);
      if (permitted.includes(documentType)) {
        assert.equal(verdict, COMPLIANCE_INTAKE_PAIR_REASON.OK, `${relationship}/${documentType}`);
      } else {
        assert.notEqual(verdict, COMPLIANCE_INTAKE_PAIR_REASON.OK, `${relationship}/${documentType}`);
      }
    }
  }
});

test("a malformed or absent relationship is rejected before the pair is considered", () => {
  for (const bad of [undefined, null, "", "Reseller", "RESELLER", " reseller", 1, {}, ["reseller"]]) {
    assert.equal(
      classifyComplianceIntakePair(bad, COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE),
      COMPLIANCE_INTAKE_PAIR_REASON.INVALID_RELATIONSHIP
    );
  }
});

itest("the callable refuses a document type the declared relationship does not list", async () => {
  const { businessId } = await seedBusiness("seller-1");
  const denied = await callOrError(
    { uid: "seller-1" },
    request(businessId, {
      sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
      documentType: COMPLIANCE_DOCUMENT_TYPE.TRADEMARK_EVIDENCE,
    })
  );
  assert.equal(denied.ok, false);
  assert.equal(denied.code, "invalid-argument");
  assert.equal(
    denied.details.reasonCode,
    COMPLIANCE_INTAKE_PAIR_REASON.NOT_PERMITTED
  );
  const sessions = await db.collection("complianceUploadSessions").get();
  const mine = sessions.docs.filter((d) => d.data().businessId === businessId);
  assert.equal(mine.length, 0, "a refused pair must create no session");
});

itest("the callable fails closed on the unresolved document type", async () => {
  const { businessId } = await seedBusiness("seller-1");
  const denied = await callOrError(
    { uid: "seller-1" },
    request(businessId, {
      documentType: COMPLIANCE_DOCUMENT_TYPE.CATEGORY_COMPLIANCE_EVIDENCE,
    })
  );
  assert.equal(denied.ok, false);
  assert.equal(denied.code, "failed-precondition");
  assert.equal(
    denied.details.reasonCode,
    COMPLIANCE_INTAKE_PAIR_REASON.POLICY_UNRESOLVED
  );
});

itest("each of the six relationships can open a session for its own minimum evidence type", async () => {
  for (const relationship of Object.values(SELLER_RELATIONSHIP)) {
    const documentType = COMPLIANCE_INTAKE_EVIDENCE_MATRIX[relationship][0];
    const { businessId } = await seedBusiness("seller-1");
    const created = await callOrError(
      { uid: "seller-1" },
      request(businessId, { sellerRelationship: relationship, documentType })
    );
    assert.equal(created.ok, true, `${relationship}/${documentType} must be accepted`);
    assert.equal(created.result.status, "upload_authorized");
  }
});

itest("the declared relationship is recorded as a claim and never as the document's own", async () => {
  const { businessId } = await seedBusiness("seller-1");
  const created = await callOrError({ uid: "seller-1" }, request(businessId));
  assert.equal(created.ok, true);
  const snap = await db
    .collection("complianceUploadSessions")
    .doc(created.result.sessionId)
    .get();
  // Recorded under its own distinct name...
  assert.equal(snap.data().declaredSellerRelationship, SELLER_RELATIONSHIP.RESELLER);
  // ...and the document's authoritative field stays null: Revision 30 §G
  // keeps submitComplianceDocument its one and only writer.
  assert.equal(snap.data().sellerRelationship, null);
});

itest("an idempotency key cannot be reused to swap the declared relationship", async () => {
  const { businessId } = await seedBusiness("seller-1");
  const key = `idem-${Date.now()}`;
  const first = await callOrError(
    { uid: "seller-1" },
    request(businessId, {
      clientIdempotencyKey: key,
      sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
      documentType: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE,
    })
  );
  assert.equal(first.ok, true);

  const swapped = await callOrError(
    { uid: "seller-1" },
    request(businessId, {
      clientIdempotencyKey: key,
      sellerRelationship: SELLER_RELATIONSHIP.IMPORTER,
      documentType: COMPLIANCE_DOCUMENT_TYPE.PURCHASE_INVOICE,
    })
  );
  assert.equal(swapped.ok, false);
  assert.equal(swapped.code, "failed-precondition");
  assert.match(swapped.message, /idempotency_conflict/);
});

// --- B. Generation binding (Revision 30 §F) ----------------------------

test("an absent, empty or wrong-typed generation is never read as valid", () => {
  for (const bad of [undefined, null, "", 0, 1, {}, [], true]) {
    assert.equal(isValidComplianceGenerationId(bad), false);
  }
  assert.equal(isValidComplianceGenerationId("gen-1"), true);
});

itest("a business with no generation binding cannot open a session", async () => {
  const { businessId } = await seedBusiness("seller-1", { generation: null });
  const denied = await callOrError({ uid: "seller-1" }, request(businessId));
  assert.equal(denied.ok, false);
  assert.equal(denied.code, "failed-precondition");
});

itest("a business with a malformed generation binding cannot open a session", async () => {
  for (const bad of ["", 42, {}]) {
    const { businessId } = await seedBusiness("seller-1", { generation: bad });
    const denied = await callOrError({ uid: "seller-1" }, request(businessId));
    assert.equal(denied.ok, false, `generation ${JSON.stringify(bad)} must deny`);
    assert.equal(denied.code, "failed-precondition");
  }
});

itest("the session records the exact generation it was issued under", async () => {
  const { businessId, generation } = await seedBusiness("seller-1");
  const created = await callOrError({ uid: "seller-1" }, request(businessId));
  assert.equal(created.ok, true);
  const snap = await db
    .collection("complianceUploadSessions")
    .doc(created.result.sessionId)
    .get();
  assert.equal(snap.data().marketplaceBusinessGenerationId, generation);
  // The client never supplied it and cannot influence it.
  assert.notEqual(generation, undefined);
});

itest("the generation is server-derived and unaffected by any client-supplied value", async () => {
  const { businessId, generation } = await seedBusiness("seller-1");
  // Supplying it at all is rejected by the closed request schema, so a
  // caller cannot even attempt to choose its own generation.
  const rejected = await callOrError(
    { uid: "seller-1" },
    request(businessId, { marketplaceBusinessGenerationId: "attacker-generation" })
  );
  assert.equal(rejected.ok, false);
  assert.equal(rejected.code, "invalid-argument");

  const created = await callOrError({ uid: "seller-1" }, request(businessId));
  assert.equal(created.result.marketplaceBusinessGenerationId, undefined,
    "the generation is not echoed back to the client");
  const snap = await db
    .collection("complianceUploadSessions")
    .doc(created.result.sessionId)
    .get();
  assert.equal(snap.data().marketplaceBusinessGenerationId, generation);
});

// --- C. Existence probing ---------------------------------------------

itest("a nonexistent, a non-owned and a malformed-owner business are all indistinguishable", async () => {
  const owned = await seedBusiness("someone-else");
  const malformed = nextBusinessId();
  await db.collection("businesses").doc(malformed).set({
    ownerUid: 12345,
    marketplaceBusinessGenerationId: "gen-x",
  });
  allowCanary(malformed);

  const absent = await callOrError({ uid: "seller-1" }, request("no-such-business-at-all"));
  const nonOwned = await callOrError({ uid: "seller-1" }, request(owned.businessId));
  const badOwner = await callOrError({ uid: "seller-1" }, request(malformed));

  for (const r of [absent, nonOwned, badOwner]) {
    assert.equal(r.ok, false);
    assert.equal(r.code, "permission-denied");
  }
  assert.equal(absent.message, nonOwned.message);
  assert.equal(absent.message, badOwner.message);
});

itest("the canary gate denies before existence can be inferred from it", async () => {
  // A business that exists, is owned by the caller and has a valid
  // generation, but is not canaried, is refused — and the refusal is the
  // canary's own failed-precondition, never a success.
  const { businessId } = await seedBusiness("seller-1", { canary: false });
  const previous = process.env.COMPLIANCE_UPLOAD_CANARY_BUSINESS_IDS;
  process.env.COMPLIANCE_UPLOAD_CANARY_BUSINESS_IDS = "";
  try {
    const denied = await callOrError({ uid: "seller-1" }, request(businessId));
    assert.equal(denied.ok, false);
    assert.equal(denied.code, "failed-precondition");
  } finally {
    process.env.COMPLIANCE_UPLOAD_CANARY_BUSINESS_IDS = previous;
  }
});

// --- D. Intake is never approval --------------------------------------

itest("opening a session creates no document, scope, link or decision", async () => {
  const { businessId } = await seedBusiness("seller-1");
  const created = await callOrError({ uid: "seller-1" }, request(businessId));
  assert.equal(created.ok, true);

  for (const collection of [
    "complianceDocuments",
    "complianceDocumentScopes",
    "productEvidenceLinks",
    "productComplianceDecisions",
  ]) {
    const snap = await db
      .collection(collection)
      .where("businessId", "==", businessId)
      .get();
    assert.equal(snap.size, 0, `${collection} must be untouched by intake`);
  }

  // And the business itself is not activated, approved or published by
  // having requested an upload.
  const biz = (await db.collection("businesses").doc(businessId).get()).data();
  assert.equal(biz.pilotProductApproval, undefined);
  assert.equal(biz.isActive, undefined);
  assert.equal(biz.moderationStatus, undefined);
});

itest("the session response carries no signed URL, token or document content", async () => {
  const { businessId } = await seedBusiness("seller-1");
  const created = await callOrError({ uid: "seller-1" }, request(businessId));
  assert.equal(created.ok, true);
  const serialized = JSON.stringify(created.result);
  for (const forbidden of [
    "firebaseStorageDownloadTokens",
    "X-Goog-Signature",
    "GoogleAccessId",
    "Authorization",
    "storage.googleapis.com",
    "token",
  ]) {
    assert.equal(
      serialized.includes(forbidden),
      false,
      `response must not contain ${forbidden}`
    );
  }
  // Exactly the frozen, non-sensitive fields.
  assert.deepEqual(Object.keys(created.result).sort(), [
    "allowedMimeTypes",
    "expiresAt",
    "maxSizeBytes",
    "objectPath",
    "sessionId",
    "status",
  ]);
});
