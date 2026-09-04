"use strict";

// Marketplace Revision 30 §J Slice 4 — admin evidence viewing (Phase A).
//
// Every case drives the real module against the Firestore and Storage
// emulators. The URL signer is injected, because a v4 signature needs real
// IAM the emulator does not provide — the signing STEP is faked, never any
// authorization, binding or validation step.

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const admin = require("firebase-admin");
const { test } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();
const BUCKET_NAME = "p1a-evidence-access-test-bucket";
const bucket = admin.storage().bucket(BUCKET_NAME);

const {
  getComplianceDocumentEvidence,
  ADMIN_VIEWABLE_DOCUMENT_STATUSES,
  EVIDENCE_REQUEST_ALLOWED_FIELDS,
  EVIDENCE_SIGNED_URL_TTL_MS,
  EVIDENCE_REASON,
  isCanonicalDocsPath,
  extensionAgreesWithContentType,
} = require("../src/marketplace/compliance/complianceEvidenceAccess");

const hasFs = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const hasStorage = Boolean(process.env.FIREBASE_STORAGE_EMULATOR_HOST);
const itest = (n, f) => test(n, { skip: !(hasFs && hasStorage) }, f);

const quietLogger = { info() {}, warn() {}, error() {} };
const PDF_BYTES = Buffer.from([0x25, 0x50, 0x44, 0x46, 1, 2, 3, 4, 5]);

let seq = 0;
function nextId(p) {
  seq += 1;
  return `${p}-${Date.now()}-${seq}`;
}

async function seedAdmin() {
  const uid = nextId("admin");
  await db.collection("users").doc(uid).set({ role: "admin" });
  return uid;
}

/// Builds a fully consistent promoted document: Firestore document, its
/// session, and the real object with the closed metadata promotion writes.
async function seedPromotedDocument(overrides = {}) {
  const businessId = overrides.businessId || nextId("biz");
  const documentId = overrides.documentId || nextId("doc");
  const sessionId = nextId("sess");
  const generationId = overrides.generationId || `gen-${businessId}`;
  const contentType = overrides.contentType || "application/pdf";
  const ext = contentType === "application/pdf" ? "pdf" : contentType === "image/png" ? "png" : "jpg";
  const objectId = `${nextId("tok")}.${ext}`;
  const storagePath =
    overrides.storagePath || `compliance_docs/${businessId}/${documentId}/${objectId}`;
  const bytes = overrides.bytes || PDF_BYTES;
  const contentHash = crypto.createHash("sha256").update(bytes).digest("hex");

  await bucket.file(storagePath).save(bytes, {
    resumable: false,
    contentType,
    metadata: { metadata: { businessId, documentId, sessionId } },
  });
  const [meta] = await bucket.file(storagePath).getMetadata();

  await db.collection("complianceUploadSessions").doc(sessionId).set({
    businessId,
    sessionId,
    documentId,
    marketplaceBusinessGenerationId: generationId,
    destinationPath: storagePath,
    contentHash,
    actualContentType: contentType,
    actualSizeBytes: bytes.length,
    promotedGeneration: String(meta.generation),
    status: "consumed",
    ...(overrides.session || {}),
  });

  await db.collection("complianceDocuments").doc(documentId).set({
    businessId,
    marketplaceBusinessGenerationId: generationId,
    sessionId,
    documentType: "purchase_invoice",
    sellerRelationship: "reseller",
    storagePath,
    originalFilename: "invoice.pdf",
    contentHash,
    sizeBytes: bytes.length,
    status: "pending_review",
    ...(overrides.document || {}),
  });

  return { businessId, documentId, sessionId, storagePath, contentHash, contentType, generationId };
}

let signCalls = 0;
let lastSigned = null;
function fakeSigner({ file, expiresAtMs, contentType }) {
  signCalls += 1;
  lastSigned = { name: file.name, expiresAtMs, contentType };
  return Promise.resolve(`https://signed.example/${encodeURIComponent(file.name)}`);
}

function call({ auth, data, signer = fakeSigner }) {
  return getComplianceDocumentEvidence({
    db,
    bucket,
    auth,
    data,
    signer,
    logger: quietLogger,
  });
}

async function reasonOf(promise) {
  try {
    await promise;
    return null;
  } catch (error) {
    return {
      code: error.code,
      reason: (error.details && error.details.reasonCode) || null,
      message: error.message,
    };
  }
}

// --- authorization ------------------------------------------------------

itest("an unauthenticated caller is denied before anything is disclosed", async () => {
  const { documentId } = await seedPromotedDocument();
  signCalls = 0;
  const failure = await reasonOf(call({ auth: null, data: { documentId } }));
  assert.equal(failure.code, "unauthenticated");
  assert.equal(signCalls, 0, "no URL may be signed for an unauthenticated caller");
});

itest("a non-admin authenticated caller is denied", async () => {
  const { businessId, documentId } = await seedPromotedDocument();
  // Even the owning seller — authorized to READ the record — cannot obtain
  // the object. Slice 3's owner read is metadata only.
  const sellerUid = nextId("seller");
  await db.collection("users").doc(sellerUid).set({ role: "user" });
  await db.collection("businesses").doc(businessId).set({ ownerUid: sellerUid });
  signCalls = 0;
  const failure = await reasonOf(call({ auth: { uid: sellerUid }, data: { documentId } }));
  assert.equal(failure.code, "permission-denied");
  assert.equal(signCalls, 0);
});

itest("a caller with a missing or malformed role claim is denied", async () => {
  const { documentId } = await seedPromotedDocument();
  const noDoc = nextId("ghost");
  const malformed = nextId("weird");
  await db.collection("users").doc(malformed).set({ role: 12345 });
  for (const uid of [noDoc, malformed]) {
    const failure = await reasonOf(call({ auth: { uid }, data: { documentId } }));
    assert.equal(failure.code, "permission-denied", `${uid} must be denied`);
  }
});

// --- closed request schema ---------------------------------------------

test("the request schema admits documentId and nothing else", () => {
  assert.deepEqual(EVIDENCE_REQUEST_ALLOWED_FIELDS, ["documentId"]);
});

itest("every path/bucket/business/identity override is refused", async () => {
  const adminUid = await seedAdmin();
  const { documentId, businessId } = await seedPromotedDocument();
  for (const override of [
    { storagePath: "compliance_docs/other/other/x.pdf" },
    { objectPath: "compliance_quarantine/b/s/o.pdf" },
    { bucket: "some-other-bucket" },
    { businessId },
    { ownerUid: adminUid },
    { marketplaceBusinessGenerationId: "gen-x" },
    { contentType: "text/html" },
    { sizeBytes: 1 },
    { contentHash: "deadbeef" },
    { downloadUrl: "https://evil.example/x" },
    { reviewedBy: adminUid },
    { expiresAtMs: Date.now() + 86400000 },
  ]) {
    const failure = await reasonOf(
      call({ auth: { uid: adminUid }, data: { documentId, ...override } })
    );
    assert.equal(
      failure.code,
      "invalid-argument",
      `${Object.keys(override)[0]} must be refused, not ignored`
    );
  }
});

// --- eligibility --------------------------------------------------------

test("only pending_review is admin-viewable", () => {
  assert.deepEqual(ADMIN_VIEWABLE_DOCUMENT_STATUSES, ["pending_review"]);
});

itest("a document in any other, unknown or malformed status is denied", async () => {
  const adminUid = await seedAdmin();
  for (const status of [
    "clean",
    "approved",
    "rejected",
    "revoked",
    "expired",
    "superseded",
    "a_future_state",
    "",
    null,
    42,
  ]) {
    const { documentId } = await seedPromotedDocument({ document: { status } });
    const failure = await reasonOf(call({ auth: { uid: adminUid }, data: { documentId } }));
    assert.equal(failure.code, "failed-precondition", `status ${status} must deny`);
    assert.equal(failure.reason, EVIDENCE_REASON.NOT_VIEWABLE);
  }
  // An entirely absent status field is the same fail-closed outcome.
  const absent = await seedPromotedDocument();
  await db
    .collection("complianceDocuments")
    .doc(absent.documentId)
    .update({ status: admin.firestore.FieldValue.delete() });
  const failure = await reasonOf(
    call({ auth: { uid: adminUid }, data: { documentId: absent.documentId } })
  );
  assert.equal(failure.code, "failed-precondition");
  assert.equal(failure.reason, EVIDENCE_REASON.NOT_VIEWABLE);
});

itest("an absent document is a plain not-found and signs nothing", async () => {
  const adminUid = await seedAdmin();
  signCalls = 0;
  const failure = await reasonOf(
    call({ auth: { uid: adminUid }, data: { documentId: "no-such-document-at-all" } })
  );
  assert.equal(failure.code, "not-found");
  assert.equal(signCalls, 0);
});

// --- object binding -----------------------------------------------------

itest("the happy path returns exactly the viewer fields and nothing else", async () => {
  const adminUid = await seedAdmin();
  const seeded = await seedPromotedDocument();
  signCalls = 0;
  const before = Date.now();
  const result = await call({ auth: { uid: adminUid }, data: { documentId: seeded.documentId } });

  assert.deepEqual(Object.keys(result).sort(), [
    "contentHash",
    "contentType",
    "documentId",
    "downloadUrl",
    "expiresAtMs",
    "sizeBytes",
  ]);
  assert.equal(result.documentId, seeded.documentId);
  assert.equal(result.contentType, "application/pdf");
  assert.equal(result.contentHash, seeded.contentHash);
  assert.equal(signCalls, 1);
  // The signer was pointed at the server-resolved canonical object.
  assert.equal(lastSigned.name, seeded.storagePath);
  // Short-lived, and bounded by the frozen TTL.
  assert.ok(result.expiresAtMs >= before + EVIDENCE_SIGNED_URL_TTL_MS - 5000);
  assert.ok(result.expiresAtMs <= Date.now() + EVIDENCE_SIGNED_URL_TTL_MS + 5000);

  // No address-shaped or owner-shaped FIELD is returned.
  //
  // `downloadUrl` is excluded from this scan deliberately and for a reason
  // worth stating: a v4 signed URL structurally contains the bucket and
  // object path — that is what signing a URL means. The authorization that
  // permitted this delivery mechanism accepted that inherent property. What
  // must not happen, and is asserted here, is the server handing back a
  // path, bucket, owner or session as SEPARATE consumable fields, which a
  // client could then compose into other addresses.
  const { downloadUrl, ...withoutUrl } = result;
  assert.ok(downloadUrl.length > 0);
  const serialized = JSON.stringify(withoutUrl);
  for (const leak of [
    "compliance_docs/",
    "compliance_quarantine",
    BUCKET_NAME,
    seeded.businessId,
    seeded.sessionId,
    seeded.storagePath,
    "ownerUid",
    "promotedGeneration",
    "storagePath",
    "bucket",
    "firebaseStorageDownloadTokens",
  ]) {
    assert.equal(serialized.includes(leak), false, `${leak} must not be returned as a field`);
  }
  // And the URL is single-use-shaped: it is never a Firebase download token.
  assert.equal(downloadUrl.includes("firebaseStorageDownloadTokens"), false);
  assert.equal(downloadUrl.includes("alt=media&token="), false);
});

itest("one admin cannot reach another document's object by id substitution", async () => {
  const adminUid = await seedAdmin();
  const a = await seedPromotedDocument();
  const b = await seedPromotedDocument();
  const forA = await call({ auth: { uid: adminUid }, data: { documentId: a.documentId } });
  const forB = await call({ auth: { uid: adminUid }, data: { documentId: b.documentId } });
  // Each id resolves strictly to its own object; nothing is shared or crossed.
  assert.notEqual(forA.downloadUrl, forB.downloadUrl);
  assert.notEqual(a.storagePath, b.storagePath);
});

itest("a document whose storagePath does not match its own identity is denied", async () => {
  const adminUid = await seedAdmin();
  const victim = await seedPromotedDocument();
  // A record pointing at ANOTHER business/document's object, or escaping the
  // canonical prefix, is refused even though the record itself is well-formed.
  for (const badPath of [
    victim.storagePath, // belongs to a different documentId
    "compliance_quarantine/b/s/o.pdf",
    "compliance_docs/../../etc/passwd",
    "compliance_docs//x/y.pdf",
    "/compliance_docs/x/y/z.pdf",
    "compliance_docs/x/y/nested/deep.pdf",
    "other_prefix/x/y/z.pdf",
  ]) {
    const { documentId } = await seedPromotedDocument({ document: { storagePath: badPath } });
    const failure = await reasonOf(call({ auth: { uid: adminUid }, data: { documentId } }));
    assert.equal(failure.code, "failed-precondition", `${badPath} must deny`);
  }
});

test("the canonical path predicate rejects traversal and quarantine", () => {
  assert.equal(isCanonicalDocsPath("compliance_docs/b1/d1/o.pdf", "b1", "d1"), true);
  for (const bad of [
    ["compliance_quarantine/b1/d1/o.pdf", "b1", "d1"],
    ["compliance_docs/b2/d1/o.pdf", "b1", "d1"],
    ["compliance_docs/b1/d2/o.pdf", "b1", "d1"],
    ["compliance_docs/b1/d1/../../x.pdf", "b1", "d1"],
    ["compliance_docs/b1/d1/sub/o.pdf", "b1", "d1"],
    ["compliance_docs/b1/d1/", "b1", "d1"],
    ["", "b1", "d1"],
  ]) {
    assert.equal(isCanonicalDocsPath(bad[0], bad[1], bad[2]), false, `${bad[0]} must be rejected`);
  }
});

itest("a session binding mismatch denies", async () => {
  const adminUid = await seedAdmin();
  for (const sessionOverride of [
    { businessId: "someone-else" },
    { documentId: "another-document" },
    { marketplaceBusinessGenerationId: "gen-DIFFERENT" },
    { destinationPath: "compliance_docs/x/y/z.pdf" },
    { contentHash: "0".repeat(64) },
    { status: "promotion_pending" },
    { promotedGeneration: null },
    { promotedGeneration: "999999" },
  ]) {
    const { documentId } = await seedPromotedDocument({ session: sessionOverride });
    const failure = await reasonOf(call({ auth: { uid: adminUid }, data: { documentId } }));
    assert.equal(
      failure.code,
      "failed-precondition",
      `session ${JSON.stringify(sessionOverride)} must deny`
    );
    assert.equal(failure.reason, EVIDENCE_REASON.BINDING_MISMATCH);
  }
});

itest("a size or hash mismatch between record and object denies", async () => {
  const adminUid = await seedAdmin();
  for (const documentOverride of [
    { sizeBytes: 999999 },
    { sizeBytes: 0 },
    { sizeBytes: -1 },
    { sizeBytes: "9" },
    { sizeBytes: 16 * 1024 * 1024 },
    { contentHash: "" },
    { marketplaceBusinessGenerationId: "" },
    { sessionId: "" },
  ]) {
    const { documentId } = await seedPromotedDocument({ document: documentOverride });
    const failure = await reasonOf(call({ auth: { uid: adminUid }, data: { documentId } }));
    assert.equal(
      failure.code,
      "failed-precondition",
      `document ${JSON.stringify(documentOverride)} must deny`
    );
  }
});

itest("an unsupported or mismatched content type denies", async () => {
  const adminUid = await seedAdmin();
  // Session says a type the frozen set does not allow.
  for (const badType of ["text/html", "image/svg+xml", "application/zip", "", null]) {
    const { documentId } = await seedPromotedDocument({
      session: { actualContentType: badType },
    });
    const failure = await reasonOf(call({ auth: { uid: adminUid }, data: { documentId } }));
    assert.equal(failure.code, "failed-precondition", `${badType} must deny`);
  }
});

itest("the MIME allowlist and extension agreement are each independently enforced", async () => {
  const adminUid = await seedAdmin();

  // (a) Extension disagrees with a type everything ELSE agrees on. The object
  // really is a PNG and the session really says PNG, so the object-metadata
  // check passes — only the extension-agreement gate can catch this.
  const businessId = nextId("biz");
  const documentId = nextId("doc");
  const mismatchedPath = `compliance_docs/${businessId}/${documentId}/tok.pdf`;
  const seededMismatch = await seedPromotedDocument({
    businessId,
    documentId,
    contentType: "image/png",
    storagePath: mismatchedPath,
  });
  const extFailure = await reasonOf(
    call({ auth: { uid: adminUid }, data: { documentId: seededMismatch.documentId } })
  );
  assert.equal(extFailure.code, "failed-precondition");
  assert.equal(extFailure.reason, EVIDENCE_REASON.UNSUPPORTED_TYPE);

  // (b) A type outside the frozen intake set, consistent everywhere: the
  // object is text/html, the session says text/html, the extension is .html.
  // Only the allowlist gate can catch this one.
  const b2 = nextId("biz");
  const d2 = nextId("doc");
  const s2 = nextId("sess");
  const htmlPath = `compliance_docs/${b2}/${d2}/tok.html`;
  await bucket.file(htmlPath).save(Buffer.from("<script>1</script>"), {
    resumable: false,
    contentType: "text/html",
    metadata: { metadata: { businessId: b2, documentId: d2, sessionId: s2 } },
  });
  const [htmlMeta] = await bucket.file(htmlPath).getMetadata();
  await db.collection("complianceUploadSessions").doc(s2).set({
    businessId: b2,
    sessionId: s2,
    documentId: d2,
    marketplaceBusinessGenerationId: `gen-${b2}`,
    destinationPath: htmlPath,
    contentHash: "h",
    actualContentType: "text/html",
    promotedGeneration: String(htmlMeta.generation),
    status: "consumed",
  });
  await db.collection("complianceDocuments").doc(d2).set({
    businessId: b2,
    marketplaceBusinessGenerationId: `gen-${b2}`,
    sessionId: s2,
    storagePath: htmlPath,
    contentHash: "h",
    sizeBytes: 18,
    status: "pending_review",
  });
  signCalls = 0;
  const typeFailure = await reasonOf(call({ auth: { uid: adminUid }, data: { documentId: d2 } }));
  assert.equal(typeFailure.code, "failed-precondition");
  assert.equal(typeFailure.reason, EVIDENCE_REASON.UNSUPPORTED_TYPE);
  assert.equal(signCalls, 0, "active content must never be signed for delivery");
});

test("extension and content type must agree", () => {
  assert.equal(extensionAgreesWithContentType("a/b/c.pdf", "application/pdf"), true);
  assert.equal(extensionAgreesWithContentType("a/b/c.PDF", "application/pdf"), true);
  assert.equal(extensionAgreesWithContentType("a/b/c.jpg", "image/jpeg"), true);
  assert.equal(extensionAgreesWithContentType("a/b/c.jpeg", "image/jpeg"), true);
  assert.equal(extensionAgreesWithContentType("a/b/c.png", "image/png"), true);
  // Disagreement, and every unsupported type, refused.
  assert.equal(extensionAgreesWithContentType("a/b/c.png", "application/pdf"), false);
  assert.equal(extensionAgreesWithContentType("a/b/c.pdf", "image/png"), false);
  assert.equal(extensionAgreesWithContentType("a/b/c.svg", "image/svg+xml"), false);
  assert.equal(extensionAgreesWithContentType("a/b/c.html", "text/html"), false);
  assert.equal(extensionAgreesWithContentType("a/b/c", "application/pdf"), false);
});

itest("a missing object denies rather than signing a URL to nothing", async () => {
  const adminUid = await seedAdmin();
  const seeded = await seedPromotedDocument();
  await bucket.file(seeded.storagePath).delete();
  signCalls = 0;
  const failure = await reasonOf(
    call({ auth: { uid: adminUid }, data: { documentId: seeded.documentId } })
  );
  assert.equal(failure.code, "failed-precondition");
  assert.equal(failure.reason, EVIDENCE_REASON.OBJECT_MISSING);
  assert.equal(signCalls, 0);
});

itest("an object whose own metadata does not name this document denies", async () => {
  const adminUid = await seedAdmin();
  const seeded = await seedPromotedDocument();
  // Re-write the object with foreign closed metadata, as a mis-promotion or
  // a substituted object would look.
  await bucket.file(seeded.storagePath).save(PDF_BYTES, {
    resumable: false,
    contentType: "application/pdf",
    metadata: {
      metadata: { businessId: "other", documentId: "other", sessionId: "other" },
    },
  });
  const failure = await reasonOf(
    call({ auth: { uid: adminUid }, data: { documentId: seeded.documentId } })
  );
  assert.equal(failure.code, "failed-precondition");
  assert.equal(failure.reason, EVIDENCE_REASON.BINDING_MISMATCH);
});

itest("each object-metadata binding field is independently enforced", async () => {
  const adminUid = await seedAdmin();
  // One field at a time: a substituted object that still agrees on the other
  // two must be rejected, so no single check is load-bearing for all three.
  for (const field of ["businessId", "documentId", "sessionId"]) {
    const seeded = await seedPromotedDocument();
    const [meta] = await bucket.file(seeded.storagePath).getMetadata();
    const custom = { ...(meta.metadata || {}) };
    custom[field] = "substituted-value";
    await bucket.file(seeded.storagePath).save(PDF_BYTES, {
      resumable: false,
      contentType: seeded.contentType,
      metadata: { metadata: custom },
    });
    // The object generation changes on rewrite, so realign the session's
    // recorded generation — otherwise the generation check, not the field
    // under test, would be what fails.
    const [fresh] = await bucket.file(seeded.storagePath).getMetadata();
    await db
      .collection("complianceUploadSessions")
      .doc(seeded.sessionId)
      .update({ promotedGeneration: String(fresh.generation) });

    signCalls = 0;
    const failure = await reasonOf(
      call({ auth: { uid: adminUid }, data: { documentId: seeded.documentId } })
    );
    assert.equal(failure.code, "failed-precondition", `${field} substitution must deny`);
    assert.equal(failure.reason, EVIDENCE_REASON.BINDING_MISMATCH);
    assert.equal(signCalls, 0);
  }
});

itest("an object whose size no longer matches the record denies", async () => {
  const adminUid = await seedAdmin();
  const seeded = await seedPromotedDocument();
  // Same metadata, same type — only the bytes changed, as a swapped object
  // would look.
  await bucket.file(seeded.storagePath).save(Buffer.concat([PDF_BYTES, PDF_BYTES]), {
    resumable: false,
    contentType: seeded.contentType,
    metadata: {
      metadata: {
        businessId: seeded.businessId,
        documentId: seeded.documentId,
        sessionId: seeded.sessionId,
      },
    },
  });
  const [fresh] = await bucket.file(seeded.storagePath).getMetadata();
  await db
    .collection("complianceUploadSessions")
    .doc(seeded.sessionId)
    .update({ promotedGeneration: String(fresh.generation) });

  const failure = await reasonOf(
    call({ auth: { uid: adminUid }, data: { documentId: seeded.documentId } })
  );
  assert.equal(failure.code, "failed-precondition");
  assert.equal(failure.reason, EVIDENCE_REASON.BINDING_MISMATCH);
});

itest("a signing failure never degrades into a public or token URL", async () => {
  const adminUid = await seedAdmin();
  const { documentId } = await seedPromotedDocument();
  const failure = await reasonOf(
    call({
      auth: { uid: adminUid },
      data: { documentId },
      signer: () => Promise.reject(new Error("no IAM")),
    })
  );
  assert.equal(failure.code, "internal");
  assert.equal(failure.reason, EVIDENCE_REASON.SIGNING_UNAVAILABLE);
  // The failure text says nothing about the object.
  assert.equal(failure.message.includes("compliance_docs"), false);
  assert.equal(failure.message.includes("no IAM"), false);
});

itest("an empty signed URL is treated as a failure, never returned", async () => {
  const adminUid = await seedAdmin();
  const { documentId } = await seedPromotedDocument();
  const failure = await reasonOf(
    call({ auth: { uid: adminUid }, data: { documentId }, signer: () => Promise.resolve("") })
  );
  assert.equal(failure.code, "internal");
});

itest("quarantine objects are never reachable through this contract", async () => {
  const adminUid = await seedAdmin();
  const businessId = nextId("biz");
  const documentId = nextId("doc");
  const sessionId = nextId("sess");
  const quarantinePath = `compliance_quarantine/${businessId}/${sessionId}/tok.pdf`;
  await bucket.file(quarantinePath).save(PDF_BYTES, {
    resumable: false,
    contentType: "application/pdf",
    metadata: { metadata: { businessId, documentId, sessionId } },
  });
  const [meta] = await bucket.file(quarantinePath).getMetadata();
  await db.collection("complianceUploadSessions").doc(sessionId).set({
    businessId,
    sessionId,
    documentId,
    marketplaceBusinessGenerationId: `gen-${businessId}`,
    destinationPath: quarantinePath,
    contentHash: "x",
    actualContentType: "application/pdf",
    promotedGeneration: String(meta.generation),
    status: "consumed",
  });
  await db.collection("complianceDocuments").doc(documentId).set({
    businessId,
    marketplaceBusinessGenerationId: `gen-${businessId}`,
    sessionId,
    storagePath: quarantinePath,
    contentHash: "x",
    sizeBytes: PDF_BYTES.length,
    status: "pending_review",
  });
  signCalls = 0;
  const failure = await reasonOf(call({ auth: { uid: adminUid }, data: { documentId } }));
  assert.equal(failure.code, "failed-precondition");
  assert.equal(signCalls, 0, "no quarantine object may ever be signed");
});

itest("no permanent download token is created on the promoted object", async () => {
  const adminUid = await seedAdmin();
  const seeded = await seedPromotedDocument();
  await call({ auth: { uid: adminUid }, data: { documentId: seeded.documentId } });
  const [meta] = await bucket.file(seeded.storagePath).getMetadata();
  const custom = meta.metadata || {};
  assert.equal(custom.firebaseStorageDownloadTokens, undefined);
  assert.deepEqual(Object.keys(custom).sort(), ["businessId", "documentId", "sessionId"]);
});

itest("nothing sensitive reaches the logger", async () => {
  const adminUid = await seedAdmin();
  const seeded = await seedPromotedDocument();
  const lines = [];
  const capturing = {
    info: (m, p) => lines.push(JSON.stringify([m, p])),
    warn: (m, p) => lines.push(JSON.stringify([m, p])),
    error: (m, p) => lines.push(JSON.stringify([m, p])),
  };
  await getComplianceDocumentEvidence({
    db,
    bucket,
    auth: { uid: adminUid },
    data: { documentId: seeded.documentId },
    signer: fakeSigner,
    logger: capturing,
  });
  const joined = lines.join(" ");
  for (const leak of [
    seeded.storagePath,
    seeded.contentHash,
    seeded.businessId,
    BUCKET_NAME,
    "https://signed.example",
    "compliance_docs",
  ]) {
    assert.equal(joined.includes(leak), false, `${leak} must never be logged`);
  }
});
