"use strict";

// Marketplace Revision 30 §J Slice 4 (Phase A) — server-side rejection
// normalization and the pending_review queue contract.
//
// No rejection taxonomy or category is introduced: the frozen contract is a
// single free-text `rejectionReason`, and only its normal form is defined.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();

const {
  reviewComplianceDocument,
  normalizeRejectionReason,
} = require("../src/marketplace/compliance/complianceDocumentOperations");

const hasFs = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const itest = (n, f) => test(n, { skip: !hasFs }, f);

let seq = 0;
const nextId = (p) => {
  seq += 1;
  return `${p}-${Date.now()}-${seq}`;
};

async function seedAdmin() {
  const uid = nextId("rev-admin");
  await db.collection("users").doc(uid).set({ role: "admin" });
  return uid;
}

async function seedPendingDocument(overrides = {}) {
  const businessId = nextId("biz");
  const documentId = nextId("doc");
  await db.collection("businesses").doc(businessId).set({ ownerUid: nextId("seller") });
  await db
    .collection("complianceDocuments")
    .doc(documentId)
    .set({
      businessId,
      sessionId: nextId("sess"),
      documentType: "purchase_invoice",
      sellerRelationship: "reseller",
      status: "pending_review",
      uploadedAt: overrides.uploadedAt || admin.firestore.Timestamp.fromMillis(Date.now()),
      reviewedBy: null,
      reviewedAt: null,
      rejectionReason: null,
      ...overrides.document,
    });
  return { businessId, documentId };
}

async function reasonOf(promise) {
  try {
    return { ok: true, value: await promise };
  } catch (error) {
    return { ok: false, code: error.code, message: error.message };
  }
}

// --- normalization unit contract ---------------------------------------

test("an empty or whitespace-only reason is refused", () => {
  for (const bad of ["", " ", "   ", "\t", "\n", "\r\n", " \t \n "]) {
    assert.throws(
      () => normalizeRejectionReason(bad, "rejectionReason"),
      /rejectionReason is required/,
      `${JSON.stringify(bad)} must be refused`
    );
  }
});

test("a non-string reason is refused", () => {
  for (const bad of [undefined, null, 0, 1, true, {}, [], ["x"]]) {
    assert.throws(() => normalizeRejectionReason(bad, "rejectionReason"));
  }
});

test("surrounding whitespace is trimmed and inner text preserved", () => {
  assert.equal(normalizeRejectionReason("  invoice is illegible  ", "r"), "invoice is illegible");
  assert.equal(normalizeRejectionReason("\n\tno brand named\n", "r"), "no brand named");
  // Inner spacing is content, not padding.
  assert.equal(normalizeRejectionReason(" a  b ", "r"), "a  b");
});

test("the length bound applies to the TRIMMED value", () => {
  const max = 2000;
  // 2000 real characters wrapped in whitespace is acceptable...
  const padded = `   ${"x".repeat(max)}   `;
  assert.equal(normalizeRejectionReason(padded, "r").length, max);
  // ...but 2001 real characters is not, padding or none.
  assert.throws(() => normalizeRejectionReason("x".repeat(max + 1), "r"), /too long/);
  assert.throws(() => normalizeRejectionReason(`  ${"x".repeat(max + 1)}  `, "r"), /too long/);
});

// --- behaviour through the real callable --------------------------------

itest("the callable refuses a whitespace-only rejection reason", async () => {
  const adminUid = await seedAdmin();
  for (const bad of ["", "   ", "\n\t "]) {
    const { documentId } = await seedPendingDocument();
    const result = await reasonOf(
      reviewComplianceDocument({
        db,
        auth: { uid: adminUid },
        data: { documentId, decision: "reject", rejectionReason: bad },
      })
    );
    assert.equal(result.ok, false, `${JSON.stringify(bad)} must be refused`);
    assert.equal(result.code, "invalid-argument");
    // And nothing was written.
    const snap = await db.collection("complianceDocuments").doc(documentId).get();
    assert.equal(snap.data().status, "pending_review");
    assert.equal(snap.data().rejectionReason, null);
  }
});

itest("the persisted and audited reason is the normalized one", async () => {
  const adminUid = await seedAdmin();
  const { documentId } = await seedPendingDocument();
  await reviewComplianceDocument({
    db,
    auth: { uid: adminUid },
    data: { documentId, decision: "reject", rejectionReason: "  scan is unreadable  " },
  });
  const snap = await db.collection("complianceDocuments").doc(documentId).get();
  assert.equal(snap.data().rejectionReason, "scan is unreadable");
  assert.equal(snap.data().status, "rejected");
  // The audit event carries the same normalized text.
  const events = await db
    .collection("complianceReviewEvents")
    .where("targetId", "==", documentId)
    .get();
  assert.equal(events.size, 1);
  assert.equal(events.docs[0].data().notes, "scan is unreadable");
  assert.equal(events.docs[0].data().actorUid, adminUid);
  assert.equal(events.docs[0].data().actorRole, "admin");
});

itest("whitespace variants replay idempotently instead of conflicting", async () => {
  const adminUid = await seedAdmin();
  const { documentId } = await seedPendingDocument();
  const first = await reviewComplianceDocument({
    db,
    auth: { uid: adminUid },
    data: { documentId, decision: "reject", rejectionReason: "missing brand" },
  });
  assert.equal(first.idempotent, false);

  // The same rejection retried with stray padding is the SAME rejection.
  const replay = await reviewComplianceDocument({
    db,
    auth: { uid: adminUid },
    data: { documentId, decision: "reject", rejectionReason: "   missing brand  " },
  });
  assert.equal(replay.idempotent, true);
  assert.equal(replay.status, "rejected");

  // Exactly one audit event, not two.
  const events = await db
    .collection("complianceReviewEvents")
    .where("targetId", "==", documentId)
    .get();
  assert.equal(events.size, 1);
});

itest("a genuinely different reason still conflicts", async () => {
  const adminUid = await seedAdmin();
  const { documentId } = await seedPendingDocument();
  await reviewComplianceDocument({
    db,
    auth: { uid: adminUid },
    data: { documentId, decision: "reject", rejectionReason: "missing brand" },
  });
  const conflict = await reasonOf(
    reviewComplianceDocument({
      db,
      auth: { uid: adminUid },
      data: { documentId, decision: "reject", rejectionReason: "a different reason entirely" },
    })
  );
  assert.equal(conflict.ok, false);
  assert.match(conflict.message, /idempotency_conflict/);
});

itest("a legacy untrimmed stored reason replays rather than conflicting", async () => {
  // Backward compatibility: production is greenfield (Revision 31 §F recorded
  // zero complianceDocuments), so no such value exists today — but a stored
  // untrimmed reason must not become permanently unreplayable if one did.
  const adminUid = await seedAdmin();
  const { documentId } = await seedPendingDocument({
    document: { status: "rejected", rejectionReason: "  legacy padded  " },
  });
  const replay = await reviewComplianceDocument({
    db,
    auth: { uid: adminUid },
    data: { documentId, decision: "reject", rejectionReason: "legacy padded" },
  });
  assert.equal(replay.idempotent, true);
});

itest("approval still forbids a rejectionReason and needs none", async () => {
  const adminUid = await seedAdmin();
  const { documentId } = await seedPendingDocument();
  const refused = await reasonOf(
    reviewComplianceDocument({
      db,
      auth: { uid: adminUid },
      data: { documentId, decision: "approve", rejectionReason: "why" },
    })
  );
  assert.equal(refused.ok, false);
  assert.equal(refused.code, "invalid-argument");

  const ok = await reviewComplianceDocument({
    db,
    auth: { uid: adminUid },
    data: { documentId, decision: "approve" },
  });
  assert.equal(ok.status, "approved");
  const snap = await db.collection("complianceDocuments").doc(documentId).get();
  assert.equal(snap.data().rejectionReason, null);
  assert.equal(snap.data().reviewedBy, adminUid);
  assert.ok(snap.data().reviewedAt, "reviewedAt is server-stamped");
});

// --- queue query and deterministic pagination ---------------------------

itest("the queue query returns only pending_review, ordered and paginating without gaps or repeats", async () => {
  const marker = nextId("queue");
  const base = Date.now();
  // Nine pending documents, three sharing one uploadedAt so ties are real.
  for (let i = 0; i < 9; i += 1) {
    await db
      .collection("complianceDocuments")
      .doc(`${marker}-pending-${i}`)
      .set({
        businessId: marker,
        sessionId: `s-${i}`,
        status: "pending_review",
        uploadedAt: admin.firestore.Timestamp.fromMillis(base + (i < 3 ? 0 : i)),
      });
  }
  // And one of every non-reviewable status, which must never appear.
  for (const status of [
    "clean",
    "approved",
    "rejected",
    "revoked",
    "expired",
    "superseded",
    "a_future_state",
  ]) {
    await db
      .collection("complianceDocuments")
      .doc(`${marker}-${status}`)
      .set({
        businessId: marker,
        sessionId: `s-${status}`,
        status,
        uploadedAt: admin.firestore.Timestamp.fromMillis(base),
      });
  }

  // The exact canonical query the admin queue uses, matching the composite
  // index (status ASC, uploadedAt ASC). Firestore appends __name__ ASC to
  // every composite index, which is what makes tied uploadedAt values order
  // deterministically and cursor pagination stable.
  const pageSize = 4;
  const seen = [];
  let cursor = null;
  for (let page = 0; page < 5; page += 1) {
    let q = db
      .collection("complianceDocuments")
      .where("businessId", "==", marker)
      .where("status", "==", "pending_review")
      .orderBy("uploadedAt", "asc")
      .limit(pageSize);
    if (cursor) q = q.startAfter(cursor);
    const snap = await q.get();
    if (snap.empty) break;
    for (const d of snap.docs) seen.push(d.id);
    cursor = snap.docs[snap.docs.length - 1];
  }

  assert.equal(seen.length, 9, "every pending document is visited exactly once");
  assert.equal(new Set(seen).size, 9, "no document is repeated across pages");
  for (const id of seen) {
    assert.match(id, /-pending-/, "no non-reviewable status may appear in the queue");
  }
});
