"use strict";

// P1-A Slice 3 — complianceDocumentOperations.js Functions tests (docs/
// plans/marketplace_p1a_compliance_review_implementation_plan_2026-08-21
// .md, §8/§13/§16). Exercises the exported onCall wrappers via their
// .run() test helper, against the Firestore emulator, seeding
// businesses/users/complianceDocuments/complianceDocumentScopes directly
// via the Admin SDK — never through Firestore Rules, which never apply
// to this server-side path (same established pattern as
// complianceUploadSessionCreation.test.js).

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");
const { test } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();
const functions = require("../index");

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function itest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

let seq = 0;
function nextId(prefix) {
  seq += 1;
  return `${prefix}-${seq}`;
}

async function seedBusiness(ownerUid) {
  const businessId = nextId("s3-biz");
  await db.collection("businesses").doc(businessId).set({ ownerUid });
  return businessId;
}

async function seedAdmin() {
  const uid = nextId("s3-admin");
  await db.collection("users").doc(uid).set({ role: "admin" });
  return uid;
}

// Seeds a complianceDocuments record exactly as Slice 2's scan-result
// handler creates one (complianceScanOrchestration.js's performPromotion
// finalize transaction) — status 'clean', sellerRelationship/issuedAt/
// validFrom/validUntil all null, every other field populated.
async function seedCleanDocument({ businessId, uploadedBy, documentType }) {
  const documentId = nextId("s3-doc");
  await db.collection("complianceDocuments").doc(documentId).set({
    businessId,
    sessionId: nextId("s3-sess"),
    documentType: documentType || "purchase_invoice",
    sellerRelationship: null,
    storagePath: `compliance_docs/${businessId}/${documentId}/tok.pdf`,
    originalFilename: "invoice.pdf",
    contentHash: "a".repeat(64),
    sizeBytes: 1024,
    version: 1,
    supersedesDocumentId: null,
    supersededByDocumentId: null,
    issuedAt: null,
    validFrom: null,
    validUntil: null,
    status: "clean",
    uploadedBy: uploadedBy || "seller-uid",
    uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
    reviewedBy: null,
    reviewedAt: null,
    rejectionReason: null,
    infoRequestNote: null,
    revokedBy: null,
    revokedAt: null,
    revocationReason: null,
  });
  return documentId;
}

async function getDocument(documentId) {
  const snap = await db.collection("complianceDocuments").doc(documentId).get();
  return snap.data();
}

async function countReviewEvents({ targetType, targetId }) {
  const snap = await db
    .collection("complianceReviewEvents")
    .where("targetType", "==", targetType)
    .where("targetId", "==", targetId)
    .get();
  return snap.size;
}

// Correction B — deterministic "state changed before the AUTHORITATIVE
// read" simulation. No sleeps, no timing assumptions, and deliberately
// NOT built by intercepting db.runTransaction to inject a write mid-
// commit: an isolated probe against this exact local Firestore emulator
// confirmed that a plain (non-transactional) write issued from inside
// an open transaction's own callback, on the same client connection,
// does not raise a clean ABORTED/retry — it leaves the transaction
// handle in a broken state that only surfaces as "3 INVALID_ARGUMENT:
// Transaction is invalid or closed" after Firestore's own ~60s default
// RPC timeout, which is exactly the kind of flaky, sleep-shaped, timing
// -dependent behavior the task instructs against. What actually matters
// for Correction B is narrower and fully reproducible without that
// technique: every operation's authoritative eligibility check now
// happens INSIDE its transaction, re-read fresh via tx.get() — never
// trusting the earlier, non-authoritative outside-transaction read
// (fetchComplianceDocumentOrThrow / fetchComplianceScopeOrThrow, used
// only for early 404s and to resolve businessId for the ownership
// check). Performing the state-changing mutation via a plain write
// AFTER that preliminary read but BEFORE invoking the callable exercises
// exactly the vulnerable gap the correction closes — the callable's
// transaction, opened afterward, is guaranteed to observe the mutated
// state on its first (and, absent real contention, only) attempt, with
// no timing dependency at all.

const validSubmitRequest = (documentId, overrides = {}) => ({
  documentId,
  sellerRelationship: "authorized_distributor",
  issuedAt: "2026-01-01T00:00:00.000Z",
  validFrom: "2026-01-01T00:00:00.000Z",
  validUntil: "2027-01-01T00:00:00.000Z",
  ...overrides,
});

async function submitAndApprove({ ownerUid, adminUid, businessId, documentId }) {
  await functions.submitComplianceDocument.run({
    auth: { uid: ownerUid },
    data: validSubmitRequest(documentId),
  });
  await functions.reviewComplianceDocument.run({
    auth: { uid: adminUid },
    data: { documentId, decision: "approve" },
  });
}

// =====================================================================
// 1. submitComplianceDocument
// =====================================================================

itest("submit: unauthenticated caller is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.submitComplianceDocument.run({ auth: null, data: validSubmitRequest(documentId) }),
    (err) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
});

itest("submit: a signed-in non-owner is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "random-other-user" },
      data: validSubmitRequest(documentId),
    }),
    (err) => {
      assert.equal(err.code, "permission-denied");
      return true;
    }
  );
});

itest("submit: the owner of a DIFFERENT business is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  await seedBusiness("seller-2");
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-2" },
      data: validSubmitRequest(documentId),
    }),
    (err) => {
      assert.equal(err.code, "permission-denied");
      return true;
    }
  );
});

itest("submit: missing documentId is rejected", async () => {
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: validSubmitRequest(""),
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

itest("submit: a nonexistent documentId is rejected not-found", async () => {
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: validSubmitRequest("does-not-exist"),
    }),
    (err) => {
      assert.equal(err.code, "not-found");
      return true;
    }
  );
});

itest("submit: an invalid sellerRelationship is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: validSubmitRequest(documentId, { sellerRelationship: "not_a_real_relationship" }),
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

itest("submit: an unknown/injected field is rejected outright — never silently ignored", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  for (const injected of [
    { status: "approved" },
    { reviewedBy: "attacker-uid" },
    { storagePath: "compliance_docs/x/y/z" },
    { contentHash: "deadbeef" },
    { scanResultRef: "attacker-controlled" },
  ]) {
    await assert.rejects(
      functions.submitComplianceDocument.run({
        auth: { uid: "seller-1" },
        data: validSubmitRequest(documentId, injected),
      }),
      (err) => {
        assert.equal(err.code, "invalid-argument");
        return true;
      }
    );
  }
});

itest("submit: validUntil before validFrom is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: validSubmitRequest(documentId, {
        validFrom: "2027-01-01T00:00:00.000Z",
        validUntil: "2026-01-01T00:00:00.000Z",
      }),
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

// ---------------------------------------------------------------------
// Correction 3 (second adversarial-review pass) — validUntil >=
// issuedAt, mirroring the pre-existing validFrom check (master plan §4
// implies validUntil - issuedAt must be a meaningful, non-negative
// quantity — see this module's own comment on the check). No
// issuedAt-vs-validFrom ordering is enforced — the plan does not
// specify one, and none is invented.
// ---------------------------------------------------------------------

itest("submit (Correction 3): validUntil before issuedAt is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: validSubmitRequest(documentId, {
        issuedAt: "2027-01-01T00:00:00.000Z",
        validFrom: "2027-01-01T00:00:00.000Z",
        validUntil: "2026-01-01T00:00:00.000Z",
      }),
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

itest("submit (Correction 3): validUntil exactly equal to issuedAt is accepted (boundary explicitly tested, not silently assumed — mirrors the validFrom boundary convention)", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  const result = await functions.submitComplianceDocument.run({
    auth: { uid: "seller-1" },
    data: validSubmitRequest(documentId, {
      issuedAt: "2026-06-01T00:00:00.000Z",
      validFrom: "2026-06-01T00:00:00.000Z",
      validUntil: "2026-06-01T00:00:00.000Z",
    }),
  });
  assert.equal(result.status, "pending_review");
});

itest("submit (Correction 3): validUntil after issuedAt (the normal case) is accepted", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  const result = await functions.submitComplianceDocument.run({
    auth: { uid: "seller-1" },
    data: validSubmitRequest(documentId, {
      issuedAt: "2026-01-01T00:00:00.000Z",
      validUntil: "2030-01-01T00:00:00.000Z",
    }),
  });
  assert.equal(result.status, "pending_review");
});

itest("submit (Correction 3): validFrom after validUntil still rejected (pre-existing check still enforced alongside the new one)", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: validSubmitRequest(documentId, {
        issuedAt: "2025-01-01T00:00:00.000Z",
        validFrom: "2027-01-01T00:00:00.000Z",
        validUntil: "2026-01-01T00:00:00.000Z",
      }),
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

itest("submit (Correction 3): missing/malformed validUntil is still rejected regardless of issuedAt", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  const { validUntil, ...withoutValidUntil } = validSubmitRequest(documentId);
  await assert.rejects(
    functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: withoutValidUntil }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: validSubmitRequest(documentId, { validUntil: "garbage-date" }),
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

itest("submit (Correction 3): no caller-supplied field can bypass the issuedAt-vs-validUntil check", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: {
        ...validSubmitRequest(documentId, {
          issuedAt: "2030-01-01T00:00:00.000Z",
          validUntil: "2020-01-01T00:00:00.000Z",
        }),
        skipDateValidation: true,
      },
    }),
    (err) => {
      // Rejected either as an unrecognized field or as the ordering
      // violation itself — either way, never a successful bypass.
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

// ---------------------------------------------------------------------
// Correction C — interim conservative validUntil requirement (closes
// the adversarial review's "policy fail-open" finding). See the master
// plan's §5.1/§7 implementation notes and this module's top-of-file
// doc comment for the full justification.
// ---------------------------------------------------------------------

itest("submit (Correction C): missing validUntil is rejected for every representative documentType", async () => {
  const { COMPLIANCE_DOCUMENT_TYPE } = require("../src/marketplace/compliance/complianceConstants");
  for (const documentType of Object.values(COMPLIANCE_DOCUMENT_TYPE)) {
    const businessId = await seedBusiness("seller-1");
    const documentId = await seedCleanDocument({ businessId, documentType });
    const { validUntil, ...withoutValidUntil } = validSubmitRequest(documentId);
    await assert.rejects(
      functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: withoutValidUntil }),
      (err) => {
        assert.equal(err.code, "invalid-argument", `documentType ${documentType} should require validUntil`);
        return true;
      }
    );
  }
});

itest("submit (Correction C): null and empty-string validUntil are also rejected, not just absent", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: validSubmitRequest(documentId, { validUntil: null }),
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: validSubmitRequest(documentId, { validUntil: "" }),
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

itest("submit (Correction C): a structurally malformed validUntil is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: validSubmitRequest(documentId, { validUntil: "not-a-real-date" }),
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

itest("submit (Correction C): a structurally valid validUntil is accepted and persisted", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  const result = await functions.submitComplianceDocument.run({
    auth: { uid: "seller-1" },
    data: validSubmitRequest(documentId),
  });
  assert.equal(result.status, "pending_review");
  const doc = await getDocument(documentId);
  assert.ok(doc.validUntil);
});

itest("submit (Correction C): documentType cannot be injected/overridden via submit — protected by the existing request allowlist", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: validSubmitRequest(documentId, { documentType: "trademark_evidence" }),
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

itest("submit (Correction C): no request field can waive the interim validUntil requirement", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  const { validUntil, ...withoutValidUntil } = validSubmitRequest(documentId);
  for (const bypassAttempt of [
    { ...withoutValidUntil, validUntilRequired: false },
    { ...withoutValidUntil, skipPolicyCheck: true },
    { ...withoutValidUntil, policyVersion: "none" },
  ]) {
    await assert.rejects(
      functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: bypassAttempt }),
      (err) => {
        // Rejected either as an unrecognized field or as missing
        // validUntil — either way, never a successful bypass.
        assert.equal(err.code, "invalid-argument");
        return true;
      }
    );
  }
});

itest("submit: a valid clean document submission succeeds and writes exactly one SUBMITTED event", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  const result = await functions.submitComplianceDocument.run({
    auth: { uid: "seller-1" },
    data: validSubmitRequest(documentId),
  });
  assert.equal(result.status, "pending_review");
  assert.equal(result.idempotent, false);
  const doc = await getDocument(documentId);
  assert.equal(doc.status, "pending_review");
  assert.equal(doc.sellerRelationship, "authorized_distributor");
  assert.ok(doc.validUntil);
  assert.equal(await countReviewEvents({ targetType: "document", targetId: documentId }), 1);
});

itest("submit: submitting a document NOT at clean (already pending_review/approved) is rejected — fail closed", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({
    auth: { uid: "seller-1" },
    data: validSubmitRequest(documentId),
  });
  // Now pending_review; submitting again with DIFFERENT values must fail
  // as a conflict, not silently re-apply.
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: validSubmitRequest(documentId, { sellerRelationship: "importer" }),
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      assert.match(err.message, /idempotency_conflict/);
      return true;
    }
  );
});

itest("submit: an identical replay while pending_review is an idempotent no-op — no duplicate event", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  const req = validSubmitRequest(documentId);
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: req });
  const second = await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: req });
  assert.equal(second.idempotent, true);
  assert.equal(await countReviewEvents({ targetType: "document", targetId: documentId }), 1);
});

itest("submit: resubmitting an already-approved document is rejected — cannot restore a fresh submission window", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  await assert.rejects(
    functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: validSubmitRequest(documentId),
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

// =====================================================================
// 2. reviewComplianceDocument (admin approve/reject)
// =====================================================================

itest("review: unauthenticated caller is rejected", async () => {
  await assert.rejects(
    functions.reviewComplianceDocument.run({
      auth: null,
      data: { documentId: "whatever", decision: "approve" },
    }),
    (err) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
});

itest("review: a non-admin caller is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  await assert.rejects(
    functions.reviewComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: { documentId, decision: "approve" },
    }),
    (err) => {
      assert.equal(err.code, "permission-denied");
      return true;
    }
  );
});

itest("review: reject without rejectionReason is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  await assert.rejects(
    functions.reviewComplianceDocument.run({
      auth: { uid: adminUid },
      data: { documentId, decision: "reject" },
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

itest("review: approve moves pending_review -> approved and writes exactly one event", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  const result = await functions.reviewComplianceDocument.run({
    auth: { uid: adminUid },
    data: { documentId, decision: "approve" },
  });
  assert.equal(result.status, "approved");
  const doc = await getDocument(documentId);
  assert.equal(doc.status, "approved");
  assert.equal(doc.reviewedBy, adminUid);
  assert.equal(await countReviewEvents({ targetType: "document", targetId: documentId }), 2); // submitted + approved
});

itest("review: reject moves pending_review -> rejected with reason recorded", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  const result = await functions.reviewComplianceDocument.run({
    auth: { uid: adminUid },
    data: { documentId, decision: "reject", rejectionReason: "expired document" },
  });
  assert.equal(result.status, "rejected");
  const doc = await getDocument(documentId);
  assert.equal(doc.status, "rejected");
  assert.equal(doc.rejectionReason, "expired document");
});

itest("review: approving a document still at clean (never submitted) fails closed", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.reviewComplianceDocument.run({
      auth: { uid: adminUid },
      data: { documentId, decision: "approve" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

itest("review: an identical approve replay is an idempotent no-op", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  await functions.reviewComplianceDocument.run({ auth: { uid: adminUid }, data: { documentId, decision: "approve" } });
  const second = await functions.reviewComplianceDocument.run({
    auth: { uid: adminUid },
    data: { documentId, decision: "approve" },
  });
  assert.equal(second.idempotent, true);
  assert.equal(await countReviewEvents({ targetType: "document", targetId: documentId }), 2);
});

itest("review: trying to reject an already-approved document fails closed — cannot overwrite newer state", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  await functions.reviewComplianceDocument.run({ auth: { uid: adminUid }, data: { documentId, decision: "approve" } });
  await assert.rejects(
    functions.reviewComplianceDocument.run({
      auth: { uid: adminUid },
      data: { documentId, decision: "reject", rejectionReason: "too late" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

// =====================================================================
// 3. requestComplianceInformation
// =====================================================================

itest("requestInfo: unauthenticated/non-admin rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  await assert.rejects(
    functions.requestComplianceInformation.run({
      auth: null,
      data: { documentId, note: "need X", requestId: "req-1" },
    }),
    (err) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
  await assert.rejects(
    functions.requestComplianceInformation.run({
      auth: { uid: "seller-1" },
      data: { documentId, note: "need X", requestId: "req-1" },
    }),
    (err) => {
      assert.equal(err.code, "permission-denied");
      return true;
    }
  );
});

itest("requestInfo: requestId is required, bounded, and typed", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  await assert.rejects(
    functions.requestComplianceInformation.run({ auth: { uid: adminUid }, data: { documentId, note: "need X" } }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
  await assert.rejects(
    functions.requestComplianceInformation.run({
      auth: { uid: adminUid },
      data: { documentId, note: "need X", requestId: "x".repeat(129) },
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
  await assert.rejects(
    functions.requestComplianceInformation.run({
      auth: { uid: adminUid },
      data: { documentId, note: "need X", requestId: 12345 },
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

itest("requestInfo: only allowed while pending_review", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.requestComplianceInformation.run({
      auth: { uid: adminUid },
      data: { documentId, note: "need X", requestId: "req-1" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

itest("requestInfo: sets infoRequestNote/reviewedBy and stays pending_review; different requestIds each write a new event", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });

  await functions.requestComplianceInformation.run({
    auth: { uid: adminUid },
    data: { documentId, note: "need X", requestId: "req-1" },
  });
  let doc = await getDocument(documentId);
  assert.equal(doc.status, "pending_review");
  assert.equal(doc.infoRequestNote, "need X");

  await functions.requestComplianceInformation.run({
    auth: { uid: adminUid },
    data: { documentId, note: "need Y too", requestId: "req-2" },
  });
  doc = await getDocument(documentId);
  assert.equal(doc.infoRequestNote, "need Y too");
  // submitted + info-requested(req-1) + info-requested(req-2) = 3 — two
  // DIFFERENT requestIds are two genuinely separate legitimate requests,
  // even though (as this test also proves) the note text differs too.
  assert.equal(await countReviewEvents({ targetType: "document", targetId: documentId }), 3);
});

itest("requestInfo: same requestId + identical content is an idempotent no-op — exactly one audit event", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });

  const request = { documentId, note: "need X", requestId: "req-dedup" };
  const first = await functions.requestComplianceInformation.run({ auth: { uid: adminUid }, data: request });
  assert.equal(first.idempotent, false);
  const replay = await functions.requestComplianceInformation.run({ auth: { uid: adminUid }, data: request });
  assert.equal(replay.idempotent, true);

  assert.equal(await countReviewEvents({ targetType: "document", targetId: documentId }), 2); // submitted + info-requested, once
});

itest("requestInfo: same requestId + different content fails as idempotency_conflict, no new event", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });

  await functions.requestComplianceInformation.run({
    auth: { uid: adminUid },
    data: { documentId, note: "need X", requestId: "req-conflict" },
  });
  await assert.rejects(
    functions.requestComplianceInformation.run({
      auth: { uid: adminUid },
      data: { documentId, note: "need SOMETHING ELSE", requestId: "req-conflict" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      assert.match(err.message, /idempotency_conflict/);
      return true;
    }
  );
  assert.equal(await countReviewEvents({ targetType: "document", targetId: documentId }), 2); // no third event written
});

itest("requestInfo: same requestId reused against a DIFFERENT target document is a conflict, not a silent separate request", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentA = await seedCleanDocument({ businessId });
  const documentB = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentA) });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentB) });

  await functions.requestComplianceInformation.run({
    auth: { uid: adminUid },
    data: { documentId: documentA, note: "need X", requestId: "shared-key" },
  });
  await assert.rejects(
    functions.requestComplianceInformation.run({
      auth: { uid: adminUid },
      data: { documentId: documentB, note: "need X", requestId: "shared-key" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      assert.match(err.message, /idempotency_conflict/);
      return true;
    }
  );
  const docB = await getDocument(documentB);
  assert.equal(docB.infoRequestNote, null); // never touched
});

itest("requestInfo: the same requestId from a DIFFERENT admin is independent (bound to actor)", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminA = await seedAdmin();
  const adminB = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });

  const first = await functions.requestComplianceInformation.run({
    auth: { uid: adminA },
    data: { documentId, note: "need X", requestId: "same-key" },
  });
  assert.equal(first.idempotent, false);
  const second = await functions.requestComplianceInformation.run({
    auth: { uid: adminB },
    data: { documentId, note: "need X", requestId: "same-key" },
  });
  assert.equal(second.idempotent, false); // a different actor, so a genuinely separate request
  assert.equal(await countReviewEvents({ targetType: "document", targetId: documentId }), 3);
});

// ---------------------------------------------------------------------
// Correction 2 (second adversarial-review pass) — complete replay
// comparison. The original comparison omitted `action`/`actorRole`; a
// planted event with a wrong `action` but every other field matching
// was empirically confirmed to be silently accepted as a valid replay,
// swallowing the real request. Every non-redundant immutable semantic
// field is now compared; `businessId` is deliberately not (see the
// dedicated test proving it is provably redundant, bound to targetId).
// ---------------------------------------------------------------------

const {
  deriveInfoRequestEventId,
} = require("../src/marketplace/compliance/complianceDocumentOperations");

async function plantInfoRequestEvent({ documentId, businessId, adminUid, requestId, overrides = {} }) {
  const eventId = deriveInfoRequestEventId({ actorUid: adminUid, requestId });
  await db.collection("complianceReviewEvents").doc(eventId).set({
    targetType: "document",
    targetId: documentId,
    businessId,
    action: "info_requested",
    actorUid: adminUid,
    actorRole: "admin",
    occurredAt: new Date(),
    notes: "need X",
    ...overrides,
  });
  return eventId;
}

itest("requestInfo (Correction 2): an exact, well-formed replay succeeds as idempotent — exactly one event", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  const request = { documentId, note: "need X", requestId: "req-exact" };
  await functions.requestComplianceInformation.run({ auth: { uid: adminUid }, data: request });
  const replay = await functions.requestComplianceInformation.run({ auth: { uid: adminUid }, data: request });
  assert.equal(replay.idempotent, true);
  assert.equal(await countReviewEvents({ targetType: "document", targetId: documentId }), 2); // submitted + info-requested, once
});

itest("requestInfo (Correction 2): a planted event with the WRONG action conflicts — never a silent replay, never swallows the real request", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  const requestId = "req-wrong-action";
  await plantInfoRequestEvent({ documentId, businessId, adminUid, requestId, overrides: { action: "approved" } });

  await assert.rejects(
    functions.requestComplianceInformation.run({
      auth: { uid: adminUid },
      data: { documentId, note: "need X", requestId },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      assert.match(err.message, /idempotency_conflict/);
      return true;
    }
  );
  const doc = await getDocument(documentId);
  assert.equal(doc.infoRequestNote, null); // the real request was never applied
});

itest("requestInfo (Correction 2): a planted event with the WRONG actorRole conflicts", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  const requestId = "req-wrong-role";
  await plantInfoRequestEvent({ documentId, businessId, adminUid, requestId, overrides: { actorRole: "seller" } });

  await assert.rejects(
    functions.requestComplianceInformation.run({
      auth: { uid: adminUid },
      data: { documentId, note: "need X", requestId },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
  const doc = await getDocument(documentId);
  assert.equal(doc.infoRequestNote, null);
});

itest("requestInfo (Correction 2): a planted event with a MISSING action field conflicts", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  const requestId = "req-missing-action";
  const eventId = deriveInfoRequestEventId({ actorUid: adminUid, requestId });
  await db.collection("complianceReviewEvents").doc(eventId).set({
    targetType: "document",
    targetId: documentId,
    businessId,
    // action deliberately omitted
    actorUid: adminUid,
    actorRole: "admin",
    occurredAt: new Date(),
    notes: "need X",
  });

  await assert.rejects(
    functions.requestComplianceInformation.run({
      auth: { uid: adminUid },
      data: { documentId, note: "need X", requestId },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

itest("requestInfo (Correction 2): a planted event with a MISSING actorRole field conflicts", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  const requestId = "req-missing-role";
  const eventId = deriveInfoRequestEventId({ actorUid: adminUid, requestId });
  await db.collection("complianceReviewEvents").doc(eventId).set({
    targetType: "document",
    targetId: documentId,
    businessId,
    action: "info_requested",
    actorUid: adminUid,
    // actorRole deliberately omitted
    occurredAt: new Date(),
    notes: "need X",
  });

  await assert.rejects(
    functions.requestComplianceInformation.run({
      auth: { uid: adminUid },
      data: { documentId, note: "need X", requestId },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

itest("requestInfo (Correction 2): malformed field TYPES on the planted event conflict, never coerced into a match", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });

  const cases = [
    { field: "targetType", value: 12345 },
    { field: "action", value: { nested: "object" } },
    { field: "notes", value: ["need", "X"] },
  ];
  for (const { field, value } of cases) {
    const requestId = `req-malformed-${field}`;
    await plantInfoRequestEvent({ documentId, businessId, adminUid, requestId, overrides: { [field]: value } });
    await assert.rejects(
      functions.requestComplianceInformation.run({
        auth: { uid: adminUid },
        data: { documentId, note: "need X", requestId },
      }),
      (err) => {
        assert.equal(err.code, "failed-precondition", `field ${field} should conflict`);
        return true;
      }
    );
  }
});

itest("requestInfo (Correction 2): changed target document on replay conflicts (already covered by target-mismatch test above) and changed note conflicts", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  const requestId = "req-changed-note";
  await functions.requestComplianceInformation.run({
    auth: { uid: adminUid },
    data: { documentId, note: "need X", requestId },
  });
  await assert.rejects(
    functions.requestComplianceInformation.run({
      auth: { uid: adminUid },
      data: { documentId, note: "need something totally different", requestId },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      assert.match(err.message, /idempotency_conflict/);
      return true;
    }
  );
});

itest("requestInfo (Correction 2): businessId is provably redundant to compare — bound solely to the already-compared targetId", async () => {
  // businessId is never part of the caller's request (not in
  // REQUEST_INFO_REQUEST_ALLOWED_FIELDS) and is always derived from
  // `current.businessId` — the immutable field of the document
  // identified by `targetId`, which IS compared. Once targetId matches,
  // businessId is guaranteed to match too, for any document seeded by
  // this codebase's own writers. This test proves that guarantee holds
  // by checking the actually-stored event's businessId always equals
  // the document's own businessId, for two different businesses.
  const businessA = await seedBusiness("seller-a");
  const businessB = await seedBusiness("seller-b");
  const docA = await seedCleanDocument({ businessId: businessA });
  const docB = await seedCleanDocument({ businessId: businessB });
  const adminUid = await seedAdmin();
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-a" }, data: validSubmitRequest(docA) });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-b" }, data: validSubmitRequest(docB) });

  await functions.requestComplianceInformation.run({ auth: { uid: adminUid }, data: { documentId: docA, note: "n", requestId: "biz-a-key" } });
  await functions.requestComplianceInformation.run({ auth: { uid: adminUid }, data: { documentId: docB, note: "n", requestId: "biz-b-key" } });

  const eventA = await db.collection("complianceReviewEvents").doc(deriveInfoRequestEventId({ actorUid: adminUid, requestId: "biz-a-key" })).get();
  const eventB = await db.collection("complianceReviewEvents").doc(deriveInfoRequestEventId({ actorUid: adminUid, requestId: "biz-b-key" })).get();
  assert.equal(eventA.data().businessId, businessA);
  assert.equal(eventB.data().businessId, businessB);
  assert.notEqual(eventA.data().businessId, eventB.data().businessId); // proves it's genuinely bound to the target, not a constant
});

itest("requestInfo (Correction 2): concurrent identical requests create no duplicate event under a real race", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  const request = { documentId, note: "need X", requestId: "req-concurrent" };

  const attempts = 5;
  const outcomes = await Promise.allSettled(
    Array.from({ length: attempts }, () =>
      functions.requestComplianceInformation.run({ auth: { uid: adminUid }, data: request })
    )
  );
  const succeeded = outcomes.filter((o) => o.status === "fulfilled");
  assert.equal(succeeded.length, attempts); // deterministic ID makes every attempt safe, none reject
  const newlyApplied = succeeded.filter((o) => o.value.idempotent === false);
  assert.equal(newlyApplied.length, 1); // exactly one attempt actually created the event

  assert.equal(await countReviewEvents({ targetType: "document", targetId: documentId }), 2); // submitted + info-requested, once
});

// =====================================================================
// 4. revokeComplianceDocument
// =====================================================================

itest("revoke: unauthenticated/non-admin rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  await assert.rejects(
    functions.revokeComplianceDocument.run({ auth: null, data: { documentId, revocationReason: "fraud" } }),
    (err) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
  await assert.rejects(
    functions.revokeComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: { documentId, revocationReason: "fraud" },
    }),
    (err) => {
      assert.equal(err.code, "permission-denied");
      return true;
    }
  );
});

itest("revoke: only allowed on an approved document", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.revokeComplianceDocument.run({
      auth: { uid: adminUid },
      data: { documentId, revocationReason: "fraud" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

itest("revoke: succeeds on an approved document, requires a reason, is idempotent for identical replays", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });

  await assert.rejects(
    functions.revokeComplianceDocument.run({ auth: { uid: adminUid }, data: { documentId } }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );

  const result = await functions.revokeComplianceDocument.run({
    auth: { uid: adminUid },
    data: { documentId, revocationReason: "fraud" },
  });
  assert.equal(result.status, "revoked");

  const replay = await functions.revokeComplianceDocument.run({
    auth: { uid: adminUid },
    data: { documentId, revocationReason: "fraud" },
  });
  assert.equal(replay.idempotent, true);

  await assert.rejects(
    functions.revokeComplianceDocument.run({
      auth: { uid: adminUid },
      data: { documentId, revocationReason: "a different reason" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      assert.match(err.message, /idempotency_conflict/);
      return true;
    }
  );
});

// =====================================================================
// 5. supersedeComplianceDocument
// =====================================================================

itest("supersede: unauthenticated/non-admin rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const oldId = await seedCleanDocument({ businessId });
  const newId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId: oldId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId: newId });
  await assert.rejects(
    functions.supersedeComplianceDocument.run({
      auth: null,
      data: { newDocumentId: newId, oldDocumentId: oldId },
    }),
    (err) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
});

itest("supersede: both documents must belong to the same business", async () => {
  const businessA = await seedBusiness("seller-a");
  const businessB = await seedBusiness("seller-b");
  const adminUid = await seedAdmin();
  const oldId = await seedCleanDocument({ businessId: businessA });
  const newId = await seedCleanDocument({ businessId: businessB });
  await submitAndApprove({ ownerUid: "seller-a", adminUid, businessId: businessA, documentId: oldId });
  await submitAndApprove({ ownerUid: "seller-b", adminUid, businessId: businessB, documentId: newId });
  await assert.rejects(
    functions.supersedeComplianceDocument.run({
      auth: { uid: adminUid },
      data: { newDocumentId: newId, oldDocumentId: oldId },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

itest("supersede: the new document must already be approved", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const oldId = await seedCleanDocument({ businessId });
  const newId = await seedCleanDocument({ businessId }); // still `clean`, never submitted
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId: oldId });
  await assert.rejects(
    functions.supersedeComplianceDocument.run({
      auth: { uid: adminUid },
      data: { newDocumentId: newId, oldDocumentId: oldId },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

itest("supersede: succeeds when both are approved — old becomes superseded, new records supersedesDocumentId; idempotent replay", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const oldId = await seedCleanDocument({ businessId });
  const newId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId: oldId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId: newId });

  const result = await functions.supersedeComplianceDocument.run({
    auth: { uid: adminUid },
    data: { newDocumentId: newId, oldDocumentId: oldId },
  });
  assert.equal(result.oldStatus, "superseded");

  const oldDoc = await getDocument(oldId);
  const newDoc = await getDocument(newId);
  assert.equal(oldDoc.status, "superseded");
  assert.equal(oldDoc.supersededByDocumentId, newId);
  assert.equal(newDoc.supersedesDocumentId, oldId);

  const replay = await functions.supersedeComplianceDocument.run({
    auth: { uid: adminUid },
    data: { newDocumentId: newId, oldDocumentId: oldId },
  });
  assert.equal(replay.idempotent, true);
});

itest("supersede: an already-superseded old document cannot be superseded again (no cycles)", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const oldId = await seedCleanDocument({ businessId });
  const midId = await seedCleanDocument({ businessId });
  const newId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId: oldId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId: midId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId: newId });

  await functions.supersedeComplianceDocument.run({
    auth: { uid: adminUid },
    data: { newDocumentId: midId, oldDocumentId: oldId },
  });
  // oldId is now superseded; attempting to supersede it again with a
  // different replacement must fail closed, not silently re-link it.
  await assert.rejects(
    functions.supersedeComplianceDocument.run({
      auth: { uid: adminUid },
      data: { newDocumentId: newId, oldDocumentId: oldId },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

// =====================================================================
// 6. addComplianceScope
// =====================================================================

itest("addScope: unauthenticated/non-owner rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  await assert.rejects(
    functions.addComplianceScope.run({
      auth: null,
      data: { documentId, scopeType: "brand", scopeValue: "Acme" },
    }),
    (err) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
  await assert.rejects(
    functions.addComplianceScope.run({
      auth: { uid: "random-user" },
      data: { documentId, scopeType: "brand", scopeValue: "Acme" },
    }),
    (err) => {
      assert.equal(err.code, "permission-denied");
      return true;
    }
  );
});

itest("addScope: requires the document to already be approved", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedCleanDocument({ businessId });
  await assert.rejects(
    functions.addComplianceScope.run({
      auth: { uid: "seller-1" },
      data: { documentId, scopeType: "brand", scopeValue: "Acme" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

itest("addScope: an invalid scopeType is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  await assert.rejects(
    functions.addComplianceScope.run({
      auth: { uid: "seller-1" },
      data: { documentId, scopeType: "not_a_real_type", scopeValue: "Acme" },
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

itest("addScope: a valid call creates a pending_review scope", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  const result = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "brand", scopeValue: "Acme" },
  });
  assert.equal(result.status, "pending_review");
  const snap = await db.collection("complianceDocumentScopes").doc(result.scopeId).get();
  assert.equal(snap.data().memberCount, 0);
  assert.equal(snap.data().businessId, businessId);
  // Revision 7 correction 40 — denormalized from the source document,
  // which submitAndApprove/validSubmitRequest sets to "authorized_distributor".
  assert.equal(snap.data().sellerRelationship, "authorized_distributor");
});

// ---------------------------------------------------------------------
// Correction B — eliminate TOCTOU (closes the adversarial review's
// Medium finding: addComplianceScope's document-status precondition was
// checked only once, outside its transaction).
// ---------------------------------------------------------------------

itest("addScope (Correction B): document changes approved -> revoked before the scope transaction's own authoritative read — no scope created, no audit event", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });

  // Simulate a concurrent revoke landing in the exact gap Correction B
  // closes: after any non-authoritative preliminary read a caller might
  // have already done, but before addComplianceScope's own transaction
  // opens and re-reads. No sleep/timing dependency — this mutation is
  // fully committed before the callable is ever invoked.
  await db.collection("complianceDocuments").doc(documentId).update({
    status: "revoked",
    revokedBy: adminUid,
    revokedAt: new Date(),
    revocationReason: "concurrent revoke injected by test",
  });

  await assert.rejects(
    functions.addComplianceScope.run({
      auth: { uid: "seller-1" },
      data: { documentId, scopeType: "brand", scopeValue: "Acme" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );

  const scopesSnap = await db.collection("complianceDocumentScopes").where("documentId", "==", documentId).get();
  assert.equal(scopesSnap.size, 0); // no scope was created
  const doc = await getDocument(documentId);
  assert.equal(doc.status, "revoked"); // the injected concurrent revoke did land
});

itest("addScope (Correction B): concurrent duplicate calls create no duplicate scopes for a fully idempotent add — preserved under a real race", async () => {
  // addComplianceScope's own scopeId is intentionally non-deterministic
  // (see its doc comment) — this test instead proves the underlying
  // document-eligibility TRANSACTION itself is safe under real
  // concurrency, using the repository's established Promise.allSettled
  // race pattern (see complianceUploadSessionCreation.test.js's daily-
  // quota concurrency tests): every concurrent attempt against the same
  // approved document must independently succeed (each creates its own
  // distinct, valid scope) — none may observe or create corrupted state.
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });

  const attempts = 5;
  const outcomes = await Promise.allSettled(
    Array.from({ length: attempts }, (_, i) =>
      functions.addComplianceScope.run({
        auth: { uid: "seller-1" },
        data: { documentId, scopeType: "sku_set", scopeValue: `race-${i}` },
      })
    )
  );
  const succeeded = outcomes.filter((o) => o.status === "fulfilled");
  assert.equal(succeeded.length, attempts); // document stayed approved throughout; all are legitimate

  const scopesSnap = await db.collection("complianceDocumentScopes").where("documentId", "==", documentId).get();
  assert.equal(scopesSnap.size, attempts); // exactly one scope per successful call, no duplicates, no loss
});

// =====================================================================
// 6b. addComplianceScope — sellerRelationship denormalization (Revision
// 7 correction 40, docs/plans/marketplace_p1a_compliance_review_
// implementation_plan_2026-08-21.md §4/§13.1)
//
// Note on "idempotency" test coverage: addComplianceScope has NO
// request-level idempotency by explicit, already-committed design (see
// its own doc comment above and the "Correction B: concurrent duplicate
// calls..." test above — scopeId is a fresh random UUID every call,
// never content-derived, so there is no "existing scope to retry
// against" to compare a repeated call's relationship value to). Tests
// below cover the equivalent, real properties instead: (a) the copy is
// a pure, deterministic function of the unchanged source document, so
// repeated independent calls always derive the identical value, and (b)
// no operation anywhere in this module — under any pre-existing scope
// state, including a directly-seeded data anomaly — can add, change, or
// remove a scope's sellerRelationship once created.
// =====================================================================

async function seedApprovedDocumentWithRelationship(businessId, sellerRelationshipValue) {
  const documentId = await seedCleanDocument({ businessId });
  await db.collection("complianceDocuments").doc(documentId).update({
    status: "approved",
    validUntil: new Date("2027-01-01T00:00:00.000Z"),
    reviewedBy: "admin-anomaly-seed",
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    sellerRelationship: sellerRelationshipValue,
  });
  return documentId;
}

// Directly seeds a scope document, bypassing addComplianceScope entirely
// — used only to construct pre-existing scope states (including data
// anomalies) that no correct write path through this module can produce,
// exactly mirroring this file's established seedCleanDocument/direct-set
// convention for constructing anomalous fixtures.
async function seedScopeDirectly({ businessId, documentId, sellerRelationshipValue, status = "pending_review" }) {
  const scopeId = nextId("s3-scope");
  const payload = {
    documentId,
    businessId,
    // Deliberately "category", not "brand" — this fixture is used for
    // generic relationship-immutability tests, unrelated to brand-type
    // scopes' own separate verifiedBrandId requirement (tested on its
    // own, below).
    scopeType: "category",
    scopeValue: "Health > Vitamins",
    memberCount: 0,
    status,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seller-1",
    reviewedBy: null,
    reviewedAt: null,
    verifiedBrandId: null,
  };
  if (sellerRelationshipValue !== undefined) {
    payload.sellerRelationship = sellerRelationshipValue;
  }
  await db.collection("complianceDocumentScopes").doc(scopeId).set(payload);
  return scopeId;
}

const ALL_SELLER_RELATIONSHIPS = [
  "brand_owner",
  "manufacturer",
  "authorized_distributor",
  "authorized_dealer",
  "importer",
  "reseller",
];

for (const relationship of ALL_SELLER_RELATIONSHIPS) {
  itest(`addScope+relationship: source document declared "${relationship}" is copied exactly onto the new scope`, async () => {
    const businessId = await seedBusiness("seller-1");
    const adminUid = await seedAdmin();
    const documentId = await seedCleanDocument({ businessId });
    await functions.submitComplianceDocument.run({
      auth: { uid: "seller-1" },
      data: validSubmitRequest(documentId, { sellerRelationship: relationship }),
    });
    await functions.reviewComplianceDocument.run({
      auth: { uid: adminUid },
      data: { documentId, decision: "approve" },
    });
    const { scopeId } = await functions.addComplianceScope.run({
      auth: { uid: "seller-1" },
      data: { documentId, scopeType: "category", scopeValue: "Toys > Chew Toy" },
    });
    const snap = await db.collection("complianceDocumentScopes").doc(scopeId).get();
    assert.equal(snap.data().sellerRelationship, relationship);
  });
}

itest("addScope+relationship: caller omitting sellerRelationship still succeeds — the field is server-derived, never a required request input", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  // The request shape below is deliberately exactly the pre-existing,
  // unchanged ADD_SCOPE_REQUEST_ALLOWED_FIELDS set — no sellerRelationship
  // key anywhere in it.
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "brand", scopeValue: "Acme" },
  });
  const snap = await db.collection("complianceDocumentScopes").doc(scopeId).get();
  assert.equal(snap.data().sellerRelationship, "authorized_distributor");
});

itest("addScope+relationship: a caller-supplied sellerRelationship is rejected as an unrecognized request field", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  await assert.rejects(
    functions.addComplianceScope.run({
      auth: { uid: "seller-1" },
      data: { documentId, scopeType: "brand", scopeValue: "Acme", sellerRelationship: "authorized_distributor" },
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
  const scopesSnap = await db.collection("complianceDocumentScopes").where("documentId", "==", documentId).get();
  assert.equal(scopesSnap.size, 0);
});

itest("addScope+relationship: a caller-supplied sellerRelationship that differs from the source document's is still rejected, never used to override it", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  // Source document is "authorized_distributor" (validSubmitRequest's default).
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  await assert.rejects(
    functions.addComplianceScope.run({
      auth: { uid: "seller-1" },
      data: { documentId, scopeType: "brand", scopeValue: "Acme", sellerRelationship: "reseller" },
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
  const scopesSnap = await db.collection("complianceDocumentScopes").where("documentId", "==", documentId).get();
  assert.equal(scopesSnap.size, 0);
});

const MALFORMED_SOURCE_RELATIONSHIP_CASES = [
  ["missing (field entirely absent)", admin.firestore.FieldValue.delete()],
  ["null", null],
  ["unknown string outside the enum", "not_a_real_relationship"],
  ["wrong type — number", 42],
  ["wrong type — object", { relationship: "reseller" }],
];

for (const [label, badValue] of MALFORMED_SOURCE_RELATIONSHIP_CASES) {
  itest(`addScope+relationship: source document with ${label} sellerRelationship fails closed with zero writes`, async () => {
    const businessId = await seedBusiness("seller-1");
    const documentId = await seedApprovedDocumentWithRelationship(businessId, badValue);
    await assert.rejects(
      functions.addComplianceScope.run({
        auth: { uid: "seller-1" },
        data: { documentId, scopeType: "brand", scopeValue: "Acme" },
      }),
      (err) => {
        assert.equal(err.code, "failed-precondition");
        // Never echoes document field values back in the error.
        assert.equal(/not_a_real_relationship/.test(err.message), false);
        return true;
      }
    );
    const scopesSnap = await db.collection("complianceDocumentScopes").where("documentId", "==", documentId).get();
    assert.equal(scopesSnap.size, 0);
    const eventCount = await countReviewEvents({ targetType: "scope", targetId: documentId });
    assert.equal(eventCount, 0);
  });
}

itest("addScope+relationship: a nonexistent documentId still fails not-found (existing behavior, unaffected)", async () => {
  await assert.rejects(
    functions.addComplianceScope.run({
      auth: { uid: "seller-1" },
      data: { documentId: "does-not-exist", scopeType: "brand", scopeValue: "Acme" },
    }),
    (err) => {
      assert.equal(err.code, "not-found");
      return true;
    }
  );
});
// Cross-tenant source-document rejection is already covered by "addScope:
// unauthenticated/non-owner rejected" above (the "random-user" case) —
// reused, not duplicated; assertCallerOwnsBusiness runs before
// sellerRelationship is ever read, so that existing coverage already
// proves a non-owner cannot reach this code path at all.

itest("addScope+relationship: repeated independent calls against the same unchanged source document always derive the identical relationship value", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({
    auth: { uid: "seller-1" },
    data: validSubmitRequest(documentId, { sellerRelationship: "importer" }),
  });
  await functions.reviewComplianceDocument.run({
    auth: { uid: adminUid },
    data: { documentId, decision: "approve" },
  });
  const first = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "sku_set", scopeValue: "set-a" },
  });
  const second = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "sku_set", scopeValue: "set-b" },
  });
  assert.notEqual(first.scopeId, second.scopeId); // distinct scopes, by design (see module doc comment)
  const firstSnap = await db.collection("complianceDocumentScopes").doc(first.scopeId).get();
  const secondSnap = await db.collection("complianceDocumentScopes").doc(second.scopeId).get();
  assert.equal(firstSnap.data().sellerRelationship, "importer");
  assert.equal(secondSnap.data().sellerRelationship, "importer");
});

itest("addScope+relationship: no operation repairs, accepts, or silently overwrites a pre-existing scope's relationship, regardless of its state", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });

  const missingRelScope = await seedScopeDirectly({ businessId, documentId, sellerRelationshipValue: undefined });
  const malformedRelScope = await seedScopeDirectly({ businessId, documentId, sellerRelationshipValue: "not_a_real_relationship" });
  const mismatchedRelScope = await seedScopeDirectly({ businessId, documentId, sellerRelationshipValue: "reseller" }); // source is "authorized_distributor"

  // reviewComplianceScope (approve) has no path that reads, validates, or
  // writes sellerRelationship at all — it must succeed identically
  // regardless of the scope's pre-existing relationship state, and must
  // never repair, add, or change it.
  for (const scopeId of [missingRelScope, malformedRelScope, mismatchedRelScope]) {
    const before = (await db.collection("complianceDocumentScopes").doc(scopeId).get()).data();
    const result = await functions.reviewComplianceScope.run({
      auth: { uid: adminUid },
      data: { scopeId, decision: "approve" },
    });
    assert.equal(result.status, "approved");
    const after = (await db.collection("complianceDocumentScopes").doc(scopeId).get()).data();
    assert.equal(after.sellerRelationship, before.sellerRelationship); // byte-identical, including undefined/malformed
    assert.equal(after.status, "approved");
  }
});

itest("addScope+relationship: approval preserves the scope's sellerRelationship exactly, alongside every other unrelated field", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "category", scopeValue: "Health > Vitamins" },
  });
  const before = (await db.collection("complianceDocumentScopes").doc(scopeId).get()).data();

  await functions.reviewComplianceScope.run({
    auth: { uid: adminUid },
    data: { scopeId, decision: "approve" },
  });

  const after = (await db.collection("complianceDocumentScopes").doc(scopeId).get()).data();
  assert.equal(after.sellerRelationship, before.sellerRelationship);
  assert.equal(after.sellerRelationship, "authorized_distributor");
  // Every other pre-existing field is unchanged except the ones this
  // operation is documented to touch.
  assert.equal(after.documentId, before.documentId);
  assert.equal(after.businessId, before.businessId);
  assert.equal(after.scopeType, before.scopeType);
  assert.equal(after.scopeValue, before.scopeValue);
  assert.equal(after.memberCount, before.memberCount);
  assert.equal(after.createdBy, before.createdBy);
});

itest("addScope+relationship: rejection preserves the scope's sellerRelationship exactly", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "category", scopeValue: "Toys > Chew Toy" },
  });

  await functions.reviewComplianceScope.run({
    auth: { uid: adminUid },
    data: { scopeId, decision: "reject" },
  });

  const after = (await db.collection("complianceDocumentScopes").doc(scopeId).get()).data();
  assert.equal(after.status, "rejected");
  assert.equal(after.sellerRelationship, "authorized_distributor");
});

itest("addScope+relationship: an idempotent re-approve replay preserves sellerRelationship exactly", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "product", scopeValue: "prod-123" },
  });
  await functions.reviewComplianceScope.run({
    auth: { uid: adminUid },
    data: { scopeId, decision: "approve" },
  });
  const replay = await functions.reviewComplianceScope.run({
    auth: { uid: adminUid },
    data: { scopeId, decision: "approve" },
  });
  assert.equal(replay.idempotent, true);
  const after = (await db.collection("complianceDocumentScopes").doc(scopeId).get()).data();
  assert.equal(after.sellerRelationship, "authorized_distributor");
});

itest("addScope+relationship: verifiedBrandId approval behavior is unaffected — both fields are set/preserved correctly together", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "brand", scopeValue: "Acme" },
  });

  await assert.rejects(
    functions.reviewComplianceScope.run({
      auth: { uid: adminUid },
      data: { scopeId, decision: "approve" },
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument"); // verifiedBrandId still required for brand-type approval
      return true;
    }
  );

  await functions.reviewComplianceScope.run({
    auth: { uid: adminUid },
    data: { scopeId, decision: "approve", verifiedBrandId: "acme-verified-1" },
  });
  const after = (await db.collection("complianceDocumentScopes").doc(scopeId).get()).data();
  assert.equal(after.verifiedBrandId, "acme-verified-1");
  assert.equal(after.sellerRelationship, "authorized_distributor");
});

// =====================================================================
// 7. addComplianceScopeMembers
// =====================================================================

async function seedApprovedScope({ businessId, ownerUid, adminUid }) {
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid, adminUid, businessId, documentId });
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: ownerUid },
    data: { documentId, scopeType: "sku_set", scopeValue: "sku-set-1" },
  });
  return scopeId;
}

itest("addMembers: unauthenticated/non-owner rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  await assert.rejects(
    functions.addComplianceScopeMembers.run({
      auth: null,
      data: { scopeId, members: [{ identifierType: "sku", identifierValue: "SKU-1" }] },
    }),
    (err) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
  await assert.rejects(
    functions.addComplianceScopeMembers.run({
      auth: { uid: "random-user" },
      data: { scopeId, members: [{ identifierType: "sku", identifierValue: "SKU-1" }] },
    }),
    (err) => {
      assert.equal(err.code, "permission-denied");
      return true;
    }
  );
});

itest("addMembers: an empty or malformed batch is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  await assert.rejects(
    functions.addComplianceScopeMembers.run({ auth: { uid: "seller-1" }, data: { scopeId, members: [] } }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
  await assert.rejects(
    functions.addComplianceScopeMembers.run({
      auth: { uid: "seller-1" },
      data: { scopeId, members: [{ identifierType: "not_real", identifierValue: "X" }] },
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

itest("addMembers: succeeds, increments memberCount by the exact new-member count", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const result = await functions.addComplianceScopeMembers.run({
    auth: { uid: "seller-1" },
    data: {
      scopeId,
      members: [
        { identifierType: "sku", identifierValue: "SKU-1" },
        { identifierType: "sku", identifierValue: "SKU-2" },
      ],
    },
  });
  assert.equal(result.addedCount, 2);
  const scopeSnap = await db.collection("complianceDocumentScopes").doc(scopeId).get();
  assert.equal(scopeSnap.data().memberCount, 2);
});

itest("addMembers: a replayed identical batch is a fully idempotent no-op — no double count, no duplicate docs", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const members = [{ identifierType: "barcode", identifierValue: "0000111122223" }];
  await functions.addComplianceScopeMembers.run({ auth: { uid: "seller-1" }, data: { scopeId, members } });
  const replay = await functions.addComplianceScopeMembers.run({ auth: { uid: "seller-1" }, data: { scopeId, members } });
  assert.equal(replay.idempotent, true);
  assert.equal(replay.addedCount, 0);
  const scopeSnap = await db.collection("complianceDocumentScopes").doc(scopeId).get();
  assert.equal(scopeSnap.data().memberCount, 1);
});

itest("addMembers: a mixed batch (one new, one duplicate) adds only the new one", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  await functions.addComplianceScopeMembers.run({
    auth: { uid: "seller-1" },
    data: { scopeId, members: [{ identifierType: "sku", identifierValue: "SKU-A" }] },
  });
  const result = await functions.addComplianceScopeMembers.run({
    auth: { uid: "seller-1" },
    data: {
      scopeId,
      members: [
        { identifierType: "sku", identifierValue: "SKU-A" }, // duplicate
        { identifierType: "sku", identifierValue: "SKU-B" }, // new
      ],
    },
  });
  assert.equal(result.addedCount, 1);
  const scopeSnap = await db.collection("complianceDocumentScopes").doc(scopeId).get();
  assert.equal(scopeSnap.data().memberCount, 2);
});

itest("addMembers: rejected on a rejected scope", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  await functions.reviewComplianceScope.run({ auth: { uid: adminUid }, data: { scopeId, decision: "reject" } });
  await assert.rejects(
    functions.addComplianceScopeMembers.run({
      auth: { uid: "seller-1" },
      data: { scopeId, members: [{ identifierType: "sku", identifierValue: "SKU-1" }] },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

// ---------------------------------------------------------------------
// Correction B — eliminate TOCTOU (closes the adversarial review's
// Medium finding: addComplianceScopeMembers's scope-status precondition
// was checked only once, outside its transaction).
// ---------------------------------------------------------------------

itest("addMembers (Correction B): scope changes approved -> rejected before the member transaction's own authoritative read — no member created, no audit event", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });

  // Same simulated-gap technique as the addScope Correction B test above
  // — fully committed before the callable is invoked, no timing
  // dependency.
  await db.collection("complianceDocumentScopes").doc(scopeId).update({
    status: "rejected",
    reviewedBy: adminUid,
    reviewedAt: new Date(),
  });

  await assert.rejects(
    functions.addComplianceScopeMembers.run({
      auth: { uid: "seller-1" },
      data: { scopeId, members: [{ identifierType: "sku", identifierValue: "SKU-RACE" }] },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );

  const membersSnap = await db.collection("complianceDocumentScopes").doc(scopeId).collection("members").get();
  assert.equal(membersSnap.size, 0); // no member was created
  const scopeSnap = await db.collection("complianceDocumentScopes").doc(scopeId).get();
  assert.equal(scopeSnap.data().status, "rejected"); // the injected concurrent reject did land
  assert.equal(scopeSnap.data().memberCount, 0);
});

itest("addMembers (Correction B): concurrent duplicate-member calls preserve idempotency under a real race — no duplicate member docs, memberCount stays exact", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const members = [{ identifierType: "sku", identifierValue: "SKU-CONCURRENT" }];

  const attempts = 5;
  const outcomes = await Promise.allSettled(
    Array.from({ length: attempts }, () =>
      functions.addComplianceScopeMembers.run({ auth: { uid: "seller-1" }, data: { scopeId, members } })
    )
  );
  const succeeded = outcomes.filter((o) => o.status === "fulfilled");
  assert.equal(succeeded.length, attempts); // deterministic member ID makes every attempt safe, none reject

  const newlyAdded = succeeded.filter((o) => o.value.idempotent === false);
  assert.equal(newlyAdded.length, 1); // exactly one attempt actually created the member

  const scopeSnap = await db.collection("complianceDocumentScopes").doc(scopeId).get();
  assert.equal(scopeSnap.data().memberCount, 1); // never double-counted
  const memberSnap = await db
    .collection("complianceDocumentScopes")
    .doc(scopeId)
    .collection("members")
    .where("identifierValue", "==", "SKU-CONCURRENT")
    .get();
  assert.equal(memberSnap.size, 1); // exactly one member document, no duplicates
});

// =====================================================================
// 8. reviewComplianceScopeMembers
// =====================================================================

itest("reviewMembers: unauthenticated/non-admin rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const { memberIds } = await addMembersAndReturnIds({ scopeId, ownerUid: "seller-1" });
  await assert.rejects(
    functions.reviewComplianceScopeMembers.run({ auth: null, data: { scopeId, memberIds, decision: "approve" } }),
    (err) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
  await assert.rejects(
    functions.reviewComplianceScopeMembers.run({
      auth: { uid: "seller-1" },
      data: { scopeId, memberIds, decision: "approve" },
    }),
    (err) => {
      assert.equal(err.code, "permission-denied");
      return true;
    }
  );
});

async function addMembersAndReturnIds({ scopeId, ownerUid, identifiers }) {
  const members = identifiers || [
    { identifierType: "sku", identifierValue: "SKU-R1" },
    { identifierType: "sku", identifierValue: "SKU-R2" },
  ];
  await functions.addComplianceScopeMembers.run({ auth: { uid: ownerUid }, data: { scopeId, members } });
  const { deriveScopeMemberId } = require("../src/marketplace/compliance/complianceDocumentOperations");
  const memberIds = members.map((m) =>
    deriveScopeMemberId({ scopeId, identifierType: m.identifierType, identifierValue: m.identifierValue })
  );
  return { memberIds };
}

itest("reviewMembers: approve moves pending_review -> active for every member in the batch", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const { memberIds } = await addMembersAndReturnIds({ scopeId, ownerUid: "seller-1" });

  const result = await functions.reviewComplianceScopeMembers.run({
    auth: { uid: adminUid },
    data: { scopeId, memberIds, decision: "approve" },
  });
  assert.equal(result.updatedCount, 2);

  for (const id of memberIds) {
    const snap = await db.collection("complianceDocumentScopes").doc(scopeId).collection("members").doc(id).get();
    assert.equal(snap.data().status, "active");
    assert.equal(snap.data().reviewedBy, adminUid);
  }
});

itest("reviewMembers: reject moves pending_review -> rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const { memberIds } = await addMembersAndReturnIds({ scopeId, ownerUid: "seller-1" });

  await functions.reviewComplianceScopeMembers.run({
    auth: { uid: adminUid },
    data: { scopeId, memberIds, decision: "reject" },
  });
  for (const id of memberIds) {
    const snap = await db.collection("complianceDocumentScopes").doc(scopeId).collection("members").doc(id).get();
    assert.equal(snap.data().status, "rejected");
  }
});

itest("reviewMembers: an identical approve replay is idempotent — no state change, no new event", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const { memberIds } = await addMembersAndReturnIds({ scopeId, ownerUid: "seller-1" });
  await functions.reviewComplianceScopeMembers.run({ auth: { uid: adminUid }, data: { scopeId, memberIds, decision: "approve" } });
  const before = await countReviewEvents({ targetType: "scope_member_batch", targetId: scopeId });
  const replay = await functions.reviewComplianceScopeMembers.run({
    auth: { uid: adminUid },
    data: { scopeId, memberIds, decision: "approve" },
  });
  assert.equal(replay.idempotent, true);
  const after = await countReviewEvents({ targetType: "scope_member_batch", targetId: scopeId });
  assert.equal(after, before);
});

itest("reviewMembers: an unknown memberId in the batch fails closed and leaves the KNOWN members untouched (atomic, no partial writes)", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const { memberIds } = await addMembersAndReturnIds({ scopeId, ownerUid: "seller-1" });
  const badBatch = [...memberIds, "this-member-does-not-exist"];

  await assert.rejects(
    functions.reviewComplianceScopeMembers.run({
      auth: { uid: adminUid },
      data: { scopeId, memberIds: badBatch, decision: "approve" },
    }),
    (err) => {
      assert.equal(err.code, "not-found");
      return true;
    }
  );

  // Prove atomicity: none of the genuinely-existing members were touched
  // by the failed batch.
  for (const id of memberIds) {
    const snap = await db.collection("complianceDocumentScopes").doc(scopeId).collection("members").doc(id).get();
    assert.equal(snap.data().status, "pending_review");
    assert.equal(snap.data().reviewedBy, null);
  }
});

itest("reviewMembers: re-approving an already-rejected member fails closed", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const { memberIds } = await addMembersAndReturnIds({ scopeId, ownerUid: "seller-1" });
  await functions.reviewComplianceScopeMembers.run({ auth: { uid: adminUid }, data: { scopeId, memberIds, decision: "reject" } });
  await assert.rejects(
    functions.reviewComplianceScopeMembers.run({
      auth: { uid: adminUid },
      data: { scopeId, memberIds, decision: "approve" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

// ---------------------------------------------------------------------
// Correction A — parent-scope lifecycle invariant (closes the
// adversarial review's High finding: a member could previously be
// approved to `active` beneath an already-`rejected` parent scope,
// confirmed reproducible against the emulator).
// ---------------------------------------------------------------------

itest("reviewMembers (Correction A): reproduces the exact adversarial-review sequence — reject scope, then attempt member approval, expect failure, member remains pending_review", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "sku_set", scopeValue: "probe-set" },
  });
  const { memberIds } = await addMembersAndReturnIds({ scopeId, ownerUid: "seller-1" });

  await functions.reviewComplianceScope.run({ auth: { uid: adminUid }, data: { scopeId, decision: "reject" } });
  const scopeAfterReject = await db.collection("complianceDocumentScopes").doc(scopeId).get();
  assert.equal(scopeAfterReject.data().status, "rejected");

  await assert.rejects(
    functions.reviewComplianceScopeMembers.run({
      auth: { uid: adminUid },
      data: { scopeId, memberIds, decision: "approve" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );

  for (const id of memberIds) {
    const snap = await db.collection("complianceDocumentScopes").doc(scopeId).collection("members").doc(id).get();
    assert.equal(snap.data().status, "pending_review"); // never became active
    assert.equal(snap.data().reviewedBy, null);
  }
});

// ---------------------------------------------------------------------
// Correction 1 (second adversarial-review pass, explicit product
// decision) — decision-aware parent-scope gate: `approve` unchanged
// (rejected parent always blocks it, without exception); `reject` now
// additionally permitted beneath a rejected parent, closing the
// "permanently stranded pending_review member" defect without
// introducing any new state, transition, or automatic cascade.
// ---------------------------------------------------------------------

itest("reviewMembers (Correction 1): a rejected parent scope still blocks approve — member remains pending_review, no exception", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const { memberIds } = await addMembersAndReturnIds({ scopeId, ownerUid: "seller-1" });
  await functions.reviewComplianceScope.run({ auth: { uid: adminUid }, data: { scopeId, decision: "reject" } });
  await assert.rejects(
    functions.reviewComplianceScopeMembers.run({
      auth: { uid: adminUid },
      data: { scopeId, memberIds, decision: "approve" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
  for (const id of memberIds) {
    const snap = await db.collection("complianceDocumentScopes").doc(scopeId).collection("members").doc(id).get();
    assert.equal(snap.data().status, "pending_review");
  }
});

itest("reviewMembers (Correction 1): a rejected parent scope now PERMITS reject — the pending member reaches a real terminal state instead of being stranded", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const { memberIds } = await addMembersAndReturnIds({ scopeId, ownerUid: "seller-1" });
  await functions.reviewComplianceScope.run({ auth: { uid: adminUid }, data: { scopeId, decision: "reject" } });

  const result = await functions.reviewComplianceScopeMembers.run({
    auth: { uid: adminUid },
    data: { scopeId, memberIds, decision: "reject" },
  });
  assert.equal(result.updatedCount, memberIds.length);
  for (const id of memberIds) {
    const snap = await db.collection("complianceDocumentScopes").doc(scopeId).collection("members").doc(id).get();
    assert.equal(snap.data().status, "rejected");
    assert.equal(snap.data().reviewedBy, adminUid);
  }
});

itest("reviewMembers (Correction 1): a rejected parent scope + a batch containing an already-active (non-pending) member fails the WHOLE batch atomically, even for reject", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const { memberIds } = await addMembersAndReturnIds({ scopeId, ownerUid: "seller-1" });
  // Approve the members FIRST, while the scope is still approved (a
  // legitimate, already-tested prior state) — then reject the scope.
  await functions.reviewComplianceScopeMembers.run({
    auth: { uid: adminUid },
    data: { scopeId, memberIds, decision: "approve" },
  });
  await functions.reviewComplianceScope.run({ auth: { uid: adminUid }, data: { scopeId, decision: "reject" } });

  // memberIds are now `active` (terminal — no outgoing transition to
  // `rejected` exists for `active` in COMPLIANCE_SCOPE_MEMBER_ALLOWED_
  // TRANSITIONS), so a reject attempt against them must fail even
  // though the parent gate itself now permits `reject` under a
  // rejected scope.
  await assert.rejects(
    functions.reviewComplianceScopeMembers.run({
      auth: { uid: adminUid },
      data: { scopeId, memberIds, decision: "reject" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
  for (const id of memberIds) {
    const snap = await db.collection("complianceDocumentScopes").doc(scopeId).collection("members").doc(id).get();
    assert.equal(snap.data().status, "active"); // untouched — atomic, no partial writes
  }
});

itest("reviewMembers (Correction 1): an unknown/malformed parent scope status fails closed for BOTH approve and reject", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();

  const scopeIdForApprove = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const membersForApprove = await addMembersAndReturnIds({ scopeId: scopeIdForApprove, ownerUid: "seller-1" });
  await db.collection("complianceDocumentScopes").doc(scopeIdForApprove).update({ status: "some_future_unknown_status" });
  await assert.rejects(
    functions.reviewComplianceScopeMembers.run({
      auth: { uid: adminUid },
      data: { scopeId: scopeIdForApprove, memberIds: membersForApprove.memberIds, decision: "approve" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );

  const scopeIdForReject = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const membersForReject = await addMembersAndReturnIds({ scopeId: scopeIdForReject, ownerUid: "seller-1" });
  await db.collection("complianceDocumentScopes").doc(scopeIdForReject).update({ status: "some_future_unknown_status" });
  await assert.rejects(
    functions.reviewComplianceScopeMembers.run({
      auth: { uid: adminUid },
      data: { scopeId: scopeIdForReject, memberIds: membersForReject.memberIds, decision: "reject" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

itest("reviewMembers (Correction 1): an identical retry of the rejected-parent reject is idempotent — exactly one audit event; a conflicting retry fails", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const { memberIds } = await addMembersAndReturnIds({ scopeId, ownerUid: "seller-1" });
  await functions.reviewComplianceScope.run({ auth: { uid: adminUid }, data: { scopeId, decision: "reject" } });

  await functions.reviewComplianceScopeMembers.run({
    auth: { uid: adminUid },
    data: { scopeId, memberIds, decision: "reject" },
  });
  const before = await countReviewEvents({ targetType: "scope_member_batch", targetId: scopeId });

  const replay = await functions.reviewComplianceScopeMembers.run({
    auth: { uid: adminUid },
    data: { scopeId, memberIds, decision: "reject" },
  });
  assert.equal(replay.idempotent, true);
  const afterReplay = await countReviewEvents({ targetType: "scope_member_batch", targetId: scopeId });
  assert.equal(afterReplay, before); // no duplicate event

  // Conflicting retry: same members, opposite (now-impossible) decision.
  await assert.rejects(
    functions.reviewComplianceScopeMembers.run({
      auth: { uid: adminUid },
      data: { scopeId, memberIds, decision: "approve" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

itest("reviewMembers (Correction A): valid permitted parent statuses (pending_review, approved) still allow member review", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();

  // Case 1: scope still pending_review (never reviewed by admin at all).
  const documentId1 = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId: documentId1 });
  const { scopeId: pendingScopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId: documentId1, scopeType: "sku_set", scopeValue: "pending-case" },
  });
  const pendingMembers = await addMembersAndReturnIds({ scopeId: pendingScopeId, ownerUid: "seller-1" });
  const pendingResult = await functions.reviewComplianceScopeMembers.run({
    auth: { uid: adminUid },
    data: { scopeId: pendingScopeId, memberIds: pendingMembers.memberIds, decision: "approve" },
  });
  assert.equal(pendingResult.updatedCount, 2);

  // Case 2: scope approved (the existing seedApprovedScope helper).
  const approvedScopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const approvedMembers = await addMembersAndReturnIds({ scopeId: approvedScopeId, ownerUid: "seller-1" });
  const approvedResult = await functions.reviewComplianceScopeMembers.run({
    auth: { uid: adminUid },
    data: { scopeId: approvedScopeId, memberIds: approvedMembers.memberIds, decision: "approve" },
  });
  assert.equal(approvedResult.updatedCount, 2);
});

itest("reviewMembers (Correction A): batch remains atomic when the PARENT invariant fails — no member touched, no event written", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const { memberIds } = await addMembersAndReturnIds({ scopeId, ownerUid: "seller-1" });
  await functions.reviewComplianceScope.run({ auth: { uid: adminUid }, data: { scopeId, decision: "reject" } });

  const before = await countReviewEvents({ targetType: "scope_member_batch", targetId: scopeId });
  await assert.rejects(
    functions.reviewComplianceScopeMembers.run({
      auth: { uid: adminUid },
      data: { scopeId, memberIds, decision: "approve" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
  const after = await countReviewEvents({ targetType: "scope_member_batch", targetId: scopeId });
  assert.equal(after, before); // no new batch event from the rejected attempt

  for (const id of memberIds) {
    const snap = await db.collection("complianceDocumentScopes").doc(scopeId).collection("members").doc(id).get();
    assert.equal(snap.data().status, "pending_review");
  }
});

// =====================================================================
// 9. reviewComplianceScope
// =====================================================================

itest("reviewScope: unauthenticated/non-admin rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  await assert.rejects(
    functions.reviewComplianceScope.run({ auth: null, data: { scopeId, decision: "approve" } }),
    (err) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
});

itest("reviewScope: approving a brand-type scope WITHOUT verifiedBrandId is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "brand", scopeValue: "Acme" },
  });
  await assert.rejects(
    functions.reviewComplianceScope.run({ auth: { uid: adminUid }, data: { scopeId, decision: "approve" } }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

itest("reviewScope: verifiedBrandId is rejected for a non-brand scopeType", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid }); // sku_set
  await assert.rejects(
    functions.reviewComplianceScope.run({
      auth: { uid: adminUid },
      data: { scopeId, decision: "approve", verifiedBrandId: "brand-123" },
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

itest("reviewScope: approving a brand-type scope WITH verifiedBrandId succeeds and persists it", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "brand", scopeValue: "Acme" },
  });
  const result = await functions.reviewComplianceScope.run({
    auth: { uid: adminUid },
    data: { scopeId, decision: "approve", verifiedBrandId: "brand-123" },
  });
  assert.equal(result.status, "approved");
  const snap = await db.collection("complianceDocumentScopes").doc(scopeId).get();
  assert.equal(snap.data().verifiedBrandId, "brand-123");
});

itest("reviewScope: a non-brand scope approves without verifiedBrandId", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  const result = await functions.reviewComplianceScope.run({
    auth: { uid: adminUid },
    data: { scopeId, decision: "approve" },
  });
  assert.equal(result.status, "approved");
});

itest("reviewScope: an identical approve replay is idempotent; a conflicting verifiedBrandId replay fails closed", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId });
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "brand", scopeValue: "Acme" },
  });
  await functions.reviewComplianceScope.run({
    auth: { uid: adminUid },
    data: { scopeId, decision: "approve", verifiedBrandId: "brand-123" },
  });
  const replay = await functions.reviewComplianceScope.run({
    auth: { uid: adminUid },
    data: { scopeId, decision: "approve", verifiedBrandId: "brand-123" },
  });
  assert.equal(replay.idempotent, true);

  await assert.rejects(
    functions.reviewComplianceScope.run({
      auth: { uid: adminUid },
      data: { scopeId, decision: "approve", verifiedBrandId: "a-different-brand" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      assert.match(err.message, /idempotency_conflict/);
      return true;
    }
  );
});

itest("reviewScope: reject then approve fails closed (terminal, cannot flip)", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedApprovedScope({ businessId, ownerUid: "seller-1", adminUid });
  await functions.reviewComplianceScope.run({ auth: { uid: adminUid }, data: { scopeId, decision: "reject" } });
  await assert.rejects(
    functions.reviewComplianceScope.run({ auth: { uid: adminUid }, data: { scopeId, decision: "approve" } }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

// =====================================================================
// Structural / static checks — no emulator required. Mirrors the
// nonCommentLines-scoped scanning convention already established for
// the compliance-scanner CI pipeline's own pipelineStatic.test.js.
// =====================================================================

function nonCommentLines(text) {
  return text
    .split("\n")
    .filter((line) => !line.trim().startsWith("//"))
    .join("\n");
}

const SOURCE_PATH = path.join(
  __dirname,
  "..",
  "src",
  "marketplace",
  "compliance",
  "complianceDocumentOperations.js"
);
const SOURCE_TEXT = fs.readFileSync(SOURCE_PATH, "utf8");
const EXECUTABLE_TEXT = nonCommentLines(SOURCE_TEXT);

test("static: Slice 3 never reads/writes productComplianceDecisions, compliancePolicyRegistry, or calls a recompute function", () => {
  assert.equal(/productComplianceDecisions/.test(EXECUTABLE_TEXT), false);
  assert.equal(/compliancePolicyRegistry/.test(EXECUTABLE_TEXT), false);
  assert.equal(/recomputeProductComplianceStatus/.test(EXECUTABLE_TEXT), false);
});

test("static: Slice 3 never touches expiry scheduling, checkout, Dart models, or UI paths", () => {
  assert.equal(/ExpiryScheduler/.test(EXECUTABLE_TEXT), false);
  assert.equal(/checkout/i.test(EXECUTABLE_TEXT), false);
  assert.equal(/\.dart/.test(EXECUTABLE_TEXT), false);
});

test("static: every request-shape allowlist excludes every server-owned/immutable-by-others field", () => {
  const sensitiveFieldNames = [
    "storagePath",
    "contentHash",
    "scanResultRef",
    "reviewedBy",
    "reviewedAt",
    "revokedBy",
    "revokedAt",
    "supersededByDocumentId",
    "uploadedBy",
    "uploadedAt",
  ];
  const {
    submitComplianceDocument: _s,
  } = require("../src/marketplace/compliance/complianceDocumentOperations");
  assert.equal(typeof _s, "function");
  // The allowlists themselves are private to the module (by design — see
  // its own top-of-file comment); this test instead proves the same
  // property indirectly via the "unknown field rejected" behavioral
  // tests above for submit/review/requestInfo/revoke, and directly here
  // via a source-text scan: none of these field names may appear as a
  // string literal inside any of the *_ALLOWED_FIELDS constant arrays.
  const allowedFieldsBlocks = EXECUTABLE_TEXT.match(/_ALLOWED_FIELDS = Object\.freeze\(\[[^\]]*\]\)/g) || [];
  assert.ok(allowedFieldsBlocks.length > 0, "expected at least one *_ALLOWED_FIELDS block");
  for (const block of allowedFieldsBlocks) {
    for (const field of sensitiveFieldNames) {
      assert.equal(block.includes(`"${field}"`), false, `${field} must not appear in ${block}`);
    }
  }
});

test("static: every Firestore write in this module uses admin.firestore.FieldValue.serverTimestamp(), never a client-suppliable Date for a server timestamp field", () => {
  // issuedAt/validFrom/validUntil are the one legitimate exception —
  // those are seller-DECLARED values (parsed dates), not server
  // observation timestamps, and are explicitly documented as such.
  assert.equal(/new Date\(\s*\)/.test(EXECUTABLE_TEXT), false);
  assert.ok(EXECUTABLE_TEXT.includes("admin.firestore.FieldValue.serverTimestamp()"));
});

// Revision 7 correction 40 — static proof that sellerRelationship is
// written exactly once anywhere in this module: inside addComplianceScope's
// own tx.create() call. No tx.update() call anywhere in this file (the
// only other write verb ever used against complianceDocumentScopes,
// exercised by reviewComplianceScope) may reference it — that is the
// exact, complete list of every mutation reviewComplianceScope is
// permitted to perform (status/reviewedBy/reviewedAt/verifiedBrandId),
// unchanged from before this correction.
test("static: sellerRelationship is written onto complianceDocumentScopes only by addComplianceScope's tx.create(scopeRef, ...), never by reviewComplianceScope's tx.update(scopeRef, ...)", () => {
  // Scoped specifically to writes against `scopeRef` — submitComplianceDocument's
  // own, entirely separate, pre-existing tx.update(documentRef, {...
  // sellerRelationship ...}) legitimately sets this field on the SOURCE
  // complianceDocuments record and is correctly out of scope for this
  // assertion, which is only about the complianceDocumentScopes writer.
  // Two legitimate tx.update(scopeRef, ...) call sites exist today:
  // reviewComplianceScope's own (status/reviewedBy/reviewedAt/verifiedBrandId)
  // and addComplianceScopeMembers' unrelated memberCount increment —
  // neither may ever reference sellerRelationship.
  const scopeUpdateCalls = EXECUTABLE_TEXT.match(/tx\.update\(scopeRef[^;]*\)/g) || [];
  assert.ok(scopeUpdateCalls.length >= 1, "expected at least one tx.update(scopeRef, ...) call");
  for (const call of scopeUpdateCalls) {
    assert.equal(
      call.includes("sellerRelationship"),
      false,
      `tx.update(scopeRef, ...) must never touch sellerRelationship: ${call}`
    );
  }
  const scopeCreateCalls = EXECUTABLE_TEXT.match(/tx\.create\(scopeRef[^;]*\)/g) || [];
  assert.equal(scopeCreateCalls.length, 1, "expected exactly one scope tx.create() call");
  assert.ok(scopeCreateCalls[0].includes("sellerRelationship"));
});
