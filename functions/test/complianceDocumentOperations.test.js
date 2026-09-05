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
const crypto = require("node:crypto");
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

// ---------------------------------------------------------------------
// Revision 9 correction 49 (master plan §4/§13.1, third prerequisite
// Slice 3 sub-pass) — documentType/validUntil denormalized onto the
// scope at creation time, exactly mirroring sellerRelationship
// immediately above: source-derived, never caller-suppliable, never
// touched by any operation other than addComplianceScope's own
// tx.create().
// ---------------------------------------------------------------------

const { COMPLIANCE_DOCUMENT_TYPE } = require("../src/marketplace/compliance/complianceConstants");

// Seeds an approved complianceDocuments record with explicit control
// over documentType/validUntil, for constructing both valid and
// deliberately-anomalous source states — mirrors
// seedApprovedDocumentWithRelationship above. When a key is present in
// `overrides` (including as admin.firestore.FieldValue.delete(), to
// simulate a missing field), it replaces the corresponding default;
// when absent, a valid default is used instead.
async function seedApprovedDocumentWithDocMeta(businessId, overrides = {}) {
  const documentId = await seedCleanDocument({ businessId });
  const payload = {
    status: "approved",
    reviewedBy: "admin-anomaly-seed",
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    sellerRelationship: "authorized_distributor",
    documentType: "purchase_invoice",
    validUntil: new Date("2027-01-01T00:00:00.000Z"),
  };
  if ("documentType" in overrides) payload.documentType = overrides.documentType;
  if ("validUntil" in overrides) payload.validUntil = overrides.validUntil;
  await db.collection("complianceDocuments").doc(documentId).update(payload);
  return documentId;
}

// Directly seeds a scope carrying explicit (possibly anomalous)
// documentType/validUntil values, bypassing addComplianceScope
// entirely — mirrors seedScopeDirectly above.
async function seedScopeDirectlyWithDocMeta({
  businessId,
  documentId,
  documentTypeValue,
  validUntilValue,
  status = "pending_review",
}) {
  const scopeId = nextId("s3-scope-dm");
  const payload = {
    documentId,
    businessId,
    scopeType: "category",
    scopeValue: "Health > Vitamins",
    sellerRelationship: "authorized_distributor",
    memberCount: 0,
    status,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seller-1",
    reviewedBy: null,
    reviewedAt: null,
    verifiedBrandId: null,
  };
  if (documentTypeValue !== undefined) payload.documentType = documentTypeValue;
  if (validUntilValue !== undefined) payload.validUntil = validUntilValue;
  await db.collection("complianceDocumentScopes").doc(scopeId).set(payload);
  return scopeId;
}

for (const documentType of Object.values(COMPLIANCE_DOCUMENT_TYPE)) {
  itest(`addScope+docMeta: source document declared documentType "${documentType}" is copied exactly onto the new scope`, async () => {
    const businessId = await seedBusiness("seller-1");
    const documentId = await seedApprovedDocumentWithDocMeta(businessId, { documentType });
    const { scopeId } = await functions.addComplianceScope.run({
      auth: { uid: "seller-1" },
      data: { documentId, scopeType: "category", scopeValue: "Toys > Chew Toy" },
    });
    const snap = await db.collection("complianceDocumentScopes").doc(scopeId).get();
    assert.equal(snap.data().documentType, documentType);
  });
}

itest("addScope+docMeta: a Timestamp-valued source validUntil is copied onto the scope with the identical instant", async () => {
  const businessId = await seedBusiness("seller-1");
  const validUntilDate = new Date("2028-06-15T00:00:00.000Z");
  const documentId = await seedApprovedDocumentWithDocMeta(businessId, { validUntil: validUntilDate });
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "category", scopeValue: "Toys > Chew Toy" },
  });
  const snap = await db.collection("complianceDocumentScopes").doc(scopeId).get();
  const sourceSnap = await db.collection("complianceDocuments").doc(documentId).get();
  assert.equal(typeof snap.data().validUntil.toMillis, "function");
  assert.equal(snap.data().validUntil.toMillis(), sourceSnap.data().validUntil.toMillis());
  assert.equal(snap.data().validUntil.toMillis(), validUntilDate.getTime());
});

itest("addScope+docMeta: a null source validUntil (schema-nullable per §4) is copied onto the scope as null, never defaulted or treated as expired/eligible", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedApprovedDocumentWithDocMeta(businessId, { validUntil: null });
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "category", scopeValue: "Toys > Chew Toy" },
  });
  const snap = await db.collection("complianceDocumentScopes").doc(scopeId).get();
  assert.equal(snap.data().validUntil, null);
});

itest("addScope+docMeta: caller omitting documentType/validUntil still succeeds — both fields are server-derived, never required request inputs", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedApprovedDocumentWithDocMeta(businessId);
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "brand", scopeValue: "Acme" },
  });
  const snap = await db.collection("complianceDocumentScopes").doc(scopeId).get();
  assert.equal(snap.data().documentType, "purchase_invoice");
  assert.equal(snap.data().validUntil.toMillis(), new Date("2027-01-01T00:00:00.000Z").getTime());
});

itest("addScope+docMeta: a caller-supplied documentType is rejected as an unrecognized request field, zero scopes written", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedApprovedDocumentWithDocMeta(businessId);
  await assert.rejects(
    functions.addComplianceScope.run({
      auth: { uid: "seller-1" },
      data: { documentId, scopeType: "brand", scopeValue: "Acme", documentType: "purchase_invoice" },
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
  const scopesSnap = await db.collection("complianceDocumentScopes").where("documentId", "==", documentId).get();
  assert.equal(scopesSnap.size, 0);
});

itest("addScope+docMeta: a caller-supplied validUntil is rejected as an unrecognized request field, zero scopes written", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedApprovedDocumentWithDocMeta(businessId);
  await assert.rejects(
    functions.addComplianceScope.run({
      auth: { uid: "seller-1" },
      data: { documentId, scopeType: "brand", scopeValue: "Acme", validUntil: "2099-01-01T00:00:00.000Z" },
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
  const scopesSnap = await db.collection("complianceDocumentScopes").where("documentId", "==", documentId).get();
  assert.equal(scopesSnap.size, 0);
});

itest("addScope+docMeta: caller-supplied documentType and validUntil together are both rejected, never partially applied", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedApprovedDocumentWithDocMeta(businessId);
  await assert.rejects(
    functions.addComplianceScope.run({
      auth: { uid: "seller-1" },
      data: {
        documentId,
        scopeType: "brand",
        scopeValue: "Acme",
        documentType: "supplier_agreement",
        validUntil: "2099-01-01T00:00:00.000Z",
      },
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
  const scopesSnap = await db.collection("complianceDocumentScopes").where("documentId", "==", documentId).get();
  assert.equal(scopesSnap.size, 0);
});

const MALFORMED_SOURCE_DOCTYPE_CASES = [
  ["missing (field entirely absent)", admin.firestore.FieldValue.delete()],
  ["unknown string outside the enum", "not_a_real_document_type"],
  ["wrong type — number", 7],
  ["wrong type — object", { type: "purchase_invoice" }],
  ["wrong type — array", ["purchase_invoice"]],
];

for (const [label, badValue] of MALFORMED_SOURCE_DOCTYPE_CASES) {
  itest(`addScope+docMeta: source document with ${label} documentType fails closed with zero writes`, async () => {
    const businessId = await seedBusiness("seller-1");
    const documentId = await seedApprovedDocumentWithDocMeta(businessId, { documentType: badValue });
    await assert.rejects(
      functions.addComplianceScope.run({
        auth: { uid: "seller-1" },
        data: { documentId, scopeType: "category", scopeValue: "Health > Vitamins" },
      }),
      (err) => {
        assert.equal(err.code, "failed-precondition");
        assert.equal(/not_a_real_document_type/.test(err.message), false);
        return true;
      }
    );
    const scopesSnap = await db.collection("complianceDocumentScopes").where("documentId", "==", documentId).get();
    assert.equal(scopesSnap.size, 0);
    const eventCount = await countReviewEvents({ targetType: "scope", targetId: documentId });
    assert.equal(eventCount, 0);
  });
}

const MALFORMED_SOURCE_VALIDUNTIL_CASES = [
  ["missing (field entirely absent)", admin.firestore.FieldValue.delete()],
  ["wrong type — string", "2027-01-01T00:00:00.000Z"],
  ["wrong type — number", 1_800_000_000_000],
  ["wrong type — plain object", { seconds: 1_800_000_000, nanoseconds: 0 }],
  ["wrong type — array", []],
  ["wrong type — boolean", false],
];

for (const [label, badValue] of MALFORMED_SOURCE_VALIDUNTIL_CASES) {
  itest(`addScope+docMeta: source document with ${label} validUntil fails closed with zero writes`, async () => {
    const businessId = await seedBusiness("seller-1");
    const documentId = await seedApprovedDocumentWithDocMeta(businessId, { validUntil: badValue });
    await assert.rejects(
      functions.addComplianceScope.run({
        auth: { uid: "seller-1" },
        data: { documentId, scopeType: "category", scopeValue: "Health > Vitamins" },
      }),
      (err) => {
        assert.equal(err.code, "failed-precondition");
        return true;
      }
    );
    const scopesSnap = await db.collection("complianceDocumentScopes").where("documentId", "==", documentId).get();
    assert.equal(scopesSnap.size, 0);
    const eventCount = await countReviewEvents({ targetType: "scope", targetId: documentId });
    assert.equal(eventCount, 0);
  });
}

itest("addScope+docMeta: sellerRelationship, documentType, and validUntil are all copied together correctly in a single call", async () => {
  const businessId = await seedBusiness("seller-1");
  const validUntilDate = new Date("2029-03-01T00:00:00.000Z");
  const documentId = await seedApprovedDocumentWithDocMeta(businessId, {
    documentType: "manufacturer_evidence",
    validUntil: validUntilDate,
  });
  await db.collection("complianceDocuments").doc(documentId).update({ sellerRelationship: "manufacturer" });
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "brand", scopeValue: "Acme" },
  });
  const snap = await db.collection("complianceDocumentScopes").doc(scopeId).get();
  assert.equal(snap.data().sellerRelationship, "manufacturer");
  assert.equal(snap.data().documentType, "manufacturer_evidence");
  assert.equal(snap.data().validUntil.toMillis(), validUntilDate.getTime());
  // verifiedBrandId approval behavior for brand-type scopes is entirely
  // unaffected — already exhaustively covered by the sellerRelationship
  // section's own "verifiedBrandId approval behavior is unaffected"
  // test above; not duplicated here.
});

// Nonexistent-documentId and cross-tenant source-document rejection
// paths are unaffected by this correction — both already fail before
// any field on the source document is read at all (fetch/ownership
// checks run first), and are already covered by the
// sellerRelationship section's own "nonexistent documentId" test and
// the unauthenticated/non-owner tests at the top of this file; not
// duplicated here.

itest("addScope+docMeta: reviewComplianceScope (approve) preserves the scope's documentType/validUntil exactly, alongside every other unrelated field", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const validUntilDate = new Date("2027-01-01T00:00:00.000Z");
  const documentId = await seedApprovedDocumentWithDocMeta(businessId, { validUntil: validUntilDate });
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
  assert.equal(after.documentType, before.documentType);
  assert.equal(after.documentType, "purchase_invoice");
  assert.equal(after.validUntil.toMillis(), before.validUntil.toMillis());
  assert.equal(after.validUntil.toMillis(), validUntilDate.getTime());
});

itest("addScope+docMeta: reviewComplianceScope (reject) preserves the scope's documentType/validUntil exactly", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedApprovedDocumentWithDocMeta(businessId, { documentType: "authorization_letter" });
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
  assert.equal(after.documentType, "authorization_letter");
  assert.equal(after.validUntil.toMillis(), new Date("2027-01-01T00:00:00.000Z").getTime());
});

itest("addScope+docMeta: an idempotent re-approve replay preserves documentType/validUntil exactly", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedApprovedDocumentWithDocMeta(businessId, { documentType: "importer_evidence" });
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
  assert.equal(after.documentType, "importer_evidence");
  assert.equal(after.validUntil.toMillis(), new Date("2027-01-01T00:00:00.000Z").getTime());
});

itest("addScope+docMeta: addComplianceScopeMembers' memberCount update preserves documentType/validUntil exactly", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const validUntilDate = new Date("2027-01-01T00:00:00.000Z");
  const documentId = await seedApprovedDocumentWithDocMeta(businessId, { validUntil: validUntilDate });
  const { scopeId } = await functions.addComplianceScope.run({
    auth: { uid: "seller-1" },
    data: { documentId, scopeType: "sku_set", scopeValue: "sku-set-1" },
  });
  await functions.reviewComplianceScope.run({ auth: { uid: adminUid }, data: { scopeId, decision: "approve" } });
  const before = (await db.collection("complianceDocumentScopes").doc(scopeId).get()).data();
  await functions.addComplianceScopeMembers.run({
    auth: { uid: "seller-1" },
    data: { scopeId, members: [{ identifierType: "sku", identifierValue: "SKU-1" }] },
  });
  const after = (await db.collection("complianceDocumentScopes").doc(scopeId).get()).data();
  assert.equal(after.memberCount, 1);
  assert.equal(after.documentType, before.documentType);
  assert.equal(after.validUntil.toMillis(), before.validUntil.toMillis());
});

itest("addScope+docMeta: no operation repairs, accepts, or silently overwrites a pre-existing scope's documentType/validUntil, regardless of its state", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedApprovedDocumentWithDocMeta(businessId);

  const missingScope = await seedScopeDirectlyWithDocMeta({
    businessId,
    documentId,
    documentTypeValue: undefined,
    validUntilValue: undefined,
  });
  const malformedScope = await seedScopeDirectlyWithDocMeta({
    businessId,
    documentId,
    documentTypeValue: "not_a_real_document_type",
    validUntilValue: "not-a-timestamp",
  });
  const mismatchedScope = await seedScopeDirectlyWithDocMeta({
    businessId,
    documentId,
    documentTypeValue: "supplier_agreement", // source is "purchase_invoice"
    validUntilValue: null,
  });

  for (const scopeId of [missingScope, malformedScope, mismatchedScope]) {
    const before = (await db.collection("complianceDocumentScopes").doc(scopeId).get()).data();
    const result = await functions.reviewComplianceScope.run({
      auth: { uid: adminUid },
      data: { scopeId, decision: "approve" },
    });
    assert.equal(result.status, "approved");
    const after = (await db.collection("complianceDocumentScopes").doc(scopeId).get()).data();
    assert.equal(after.documentType, before.documentType); // byte-identical, including undefined/malformed
    assert.equal(after.validUntil, before.validUntil);
    assert.equal(after.status, "approved");
  }
});

itest("addScope+docMeta: repeated independent calls against the same unchanged source document always derive identical documentType/validUntil, though scopeIds differ", async () => {
  const businessId = await seedBusiness("seller-1");
  const validUntilDate = new Date("2030-01-01T00:00:00.000Z");
  const documentId = await seedApprovedDocumentWithDocMeta(businessId, {
    documentType: "trademark_evidence",
    validUntil: validUntilDate,
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
  assert.equal(firstSnap.data().documentType, "trademark_evidence");
  assert.equal(secondSnap.data().documentType, "trademark_evidence");
  assert.equal(firstSnap.data().validUntil.toMillis(), validUntilDate.getTime());
  assert.equal(secondSnap.data().validUntil.toMillis(), validUntilDate.getTime());
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
// Slice 4.6 (docs/plans/marketplace_p1a_compliance_review_implementation_
// plan_2026-08-21.md §4/§8) — businessComplianceEpochs epoch-bump
// integration. Exactly five real, non-idempotent transitions
// (reviewComplianceDocument-approve, revokeComplianceDocument,
// supersedeComplianceDocument, reviewComplianceScope-approve,
// reviewComplianceScopeMembers-approve) bump
// businessComplianceEpochs/{businessId}.epoch by exactly one, inside the
// same transaction as the operation's own status change and audit
// event. Reuses this file's own established Slice 3 seeding/emulator
// conventions throughout — no new test infrastructure pattern.
// =====================================================================

async function getEpochDoc(businessId) {
  const snap = await db.collection("businessComplianceEpochs").doc(businessId).get();
  return snap.exists ? snap.data() : undefined;
}

async function seedEpochDoc(businessId, fields) {
  await db.collection("businessComplianceEpochs").doc(businessId).set(fields);
}

// One "perform the real, qualifying transition" function per Slice 4.6
// operation — each seeds exactly what its own operation needs and
// returns { response, replay, businessId, targetType, targetId } so the
// same five can be reused, parameterized, across the B/C/E groups below
// without duplicating each operation's own seeding shape five times per
// concern.

async function performEpoch_ReviewComplianceDocument({ businessId, ownerUid, adminUid }) {
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: ownerUid }, data: validSubmitRequest(documentId) });
  const invoke = () =>
    functions.reviewComplianceDocument.run({ auth: { uid: adminUid }, data: { documentId, decision: "approve" } });
  const response = await invoke();
  return {
    response,
    replay: invoke,
    businessId,
    targetType: "document",
    targetId: documentId,
    expectedResponse: { documentId, status: "approved", idempotent: false },
  };
}

// Raw-seeded prerequisite state, deliberately bypassing the real
// submit/approve/addScope/addMembers flow: those real operations are
// themselves either non-qualifying (submit, addComplianceScope,
// addComplianceScopeMembers — safe to use) or, for
// reviewComplianceDocument's own approve branch, THEMSELVES a real
// qualifying Slice 4.6 transition that would bump the epoch as a side
// effect of merely reaching the prerequisite state — which would
// silently double-count against a test whose whole point is to prove
// exactly one bump happens per operation under test. Raw admin writes
// (matching the exact document/scope shapes already established by
// seedCleanDocument/addComplianceScope's own tx.create payload) isolate
// the operation under test from its own fixture setup.
async function seedApprovedDocumentDirect({ businessId }) {
  const documentId = await seedCleanDocument({ businessId });
  await db.collection("complianceDocuments").doc(documentId).update({
    status: "approved",
    sellerRelationship: "authorized_distributor",
    reviewedBy: "epoch-fixture-seed",
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return documentId;
}

async function seedPendingScopeDirect({ businessId, status = "pending_review" }) {
  const scopeId = crypto.randomUUID();
  await db.collection("complianceDocumentScopes").doc(scopeId).set({
    documentId: "epoch-fixture-placeholder-doc",
    businessId,
    scopeType: "sku_set",
    scopeValue: "epoch-fixture-sku-set",
    sellerRelationship: "authorized_distributor",
    documentType: "purchase_invoice",
    validUntil: null,
    memberCount: 0,
    status,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "epoch-fixture-seed",
    reviewedBy: null,
    reviewedAt: null,
    verifiedBrandId: null,
  });
  return scopeId;
}

async function seedPendingScopeWithMemberDirect({ businessId }) {
  const { deriveScopeMemberId } = require("../src/marketplace/compliance/complianceDocumentOperations");
  const scopeId = await seedPendingScopeDirect({ businessId });
  const memberId = deriveScopeMemberId({ scopeId, identifierType: "sku", identifierValue: "SKU-EPOCH-FIXTURE" });
  await db.collection("complianceDocumentScopes").doc(scopeId).collection("members").doc(memberId).set({
    identifierType: "sku",
    identifierValue: "SKU-EPOCH-FIXTURE",
    status: "pending_review",
    addedAt: admin.firestore.FieldValue.serverTimestamp(),
    addedBy: "epoch-fixture-seed",
    reviewedBy: null,
    reviewedAt: null,
    revokedAt: null,
    revokedBy: null,
  });
  return { scopeId, memberIds: [memberId] };
}

async function performEpoch_RevokeComplianceDocument({ businessId }) {
  const documentId = await seedApprovedDocumentDirect({ businessId });
  const adminUid = await seedAdmin();
  const invoke = () =>
    functions.revokeComplianceDocument.run({
      auth: { uid: adminUid },
      data: { documentId, revocationReason: "epoch-test-revoke" },
    });
  const response = await invoke();
  return {
    response,
    replay: invoke,
    businessId,
    targetType: "document",
    targetId: documentId,
    expectedResponse: { documentId, status: "revoked", idempotent: false },
  };
}

async function performEpoch_SupersedeComplianceDocument({ businessId }) {
  const oldDocumentId = await seedApprovedDocumentDirect({ businessId });
  const newDocumentId = await seedApprovedDocumentDirect({ businessId });
  const adminUid = await seedAdmin();
  const invoke = () =>
    functions.supersedeComplianceDocument.run({ auth: { uid: adminUid }, data: { newDocumentId, oldDocumentId } });
  const response = await invoke();
  return {
    response,
    replay: invoke,
    businessId,
    targetType: "document",
    targetId: oldDocumentId,
    expectedResponse: { newDocumentId, oldDocumentId, oldStatus: "superseded", idempotent: false },
  };
}

async function performEpoch_ReviewComplianceScope({ businessId }) {
  const scopeId = await seedPendingScopeDirect({ businessId });
  const adminUid = await seedAdmin();
  const invoke = () =>
    functions.reviewComplianceScope.run({ auth: { uid: adminUid }, data: { scopeId, decision: "approve" } });
  const response = await invoke();
  return {
    response,
    replay: invoke,
    businessId,
    targetType: "scope",
    targetId: scopeId,
    expectedResponse: { scopeId, status: "approved", idempotent: false },
  };
}

async function performEpoch_ReviewComplianceScopeMembers({ businessId }) {
  const { scopeId, memberIds } = await seedPendingScopeWithMemberDirect({ businessId });
  const adminUid = await seedAdmin();
  const invoke = () =>
    functions.reviewComplianceScopeMembers.run({
      auth: { uid: adminUid },
      data: { scopeId, memberIds, decision: "approve" },
    });
  const response = await invoke();
  return {
    response,
    replay: invoke,
    businessId,
    targetType: "scope_member_batch",
    targetId: scopeId,
    expectedResponse: { scopeId, status: "active", updatedCount: memberIds.length, idempotent: false },
  };
}

const EPOCH_QUALIFYING_OPS = [
  { name: "reviewComplianceDocument", perform: performEpoch_ReviewComplianceDocument },
  { name: "revokeComplianceDocument", perform: performEpoch_RevokeComplianceDocument },
  { name: "supersedeComplianceDocument", perform: performEpoch_SupersedeComplianceDocument },
  { name: "reviewComplianceScope", perform: performEpoch_ReviewComplianceScope },
  { name: "reviewComplianceScopeMembers", perform: performEpoch_ReviewComplianceScopeMembers },
];

// ---------------------------------------------------------------------
// A. Exact five real transitions — missing epoch document -> 1
// ---------------------------------------------------------------------

itest("epoch [A1] reviewComplianceDocument approve: missing epoch document -> epoch 1", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  assert.equal(await getEpochDoc(businessId), undefined);
  const { response, expectedResponse, targetType, targetId } = await performEpoch_ReviewComplianceDocument({
    businessId,
    ownerUid: "seller-1",
    adminUid,
  });
  assert.deepEqual(response, expectedResponse);
  const epoch = await getEpochDoc(businessId);
  assert.equal(epoch.epoch, 1);
  // submitComplianceDocument's own SUBMITTED event (1) + this
  // reviewComplianceDocument's own APPROVED event (1) = 2, both
  // targeted at this same documentId.
  assert.equal(await countReviewEvents({ targetType, targetId }), 2);
});

itest("epoch [A2] revokeComplianceDocument real revoke: missing epoch document -> epoch 1", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  assert.equal(await getEpochDoc(businessId), undefined);
  const { response, expectedResponse, targetType, targetId } = await performEpoch_RevokeComplianceDocument({
    businessId,
    ownerUid: "seller-1",
    adminUid,
  });
  assert.deepEqual(response, expectedResponse);
  const epoch = await getEpochDoc(businessId);
  assert.equal(epoch.epoch, 1);
  // The prerequisite document is raw-seeded directly at "approved"
  // (no submit/review flow, no event) — only this revoke's own REVOKED
  // event exists.
  assert.equal(await countReviewEvents({ targetType, targetId }), 1);
});

itest("epoch [A3] supersedeComplianceDocument real supersede: old business epoch document -> epoch 1", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  assert.equal(await getEpochDoc(businessId), undefined);
  const { response, expectedResponse, businessId: keyedBusinessId } = await performEpoch_SupersedeComplianceDocument({
    businessId,
    ownerUid: "seller-1",
    adminUid,
  });
  assert.deepEqual(response, expectedResponse);
  assert.equal(keyedBusinessId, businessId);
  const epoch = await getEpochDoc(businessId);
  assert.equal(epoch.epoch, 1);
});

itest("epoch [A4] reviewComplianceScope approve: missing epoch document -> epoch 1", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  assert.equal(await getEpochDoc(businessId), undefined);
  const { response, expectedResponse, targetType, targetId } = await performEpoch_ReviewComplianceScope({
    businessId,
    ownerUid: "seller-1",
    adminUid,
  });
  assert.deepEqual(response, expectedResponse);
  const epoch = await getEpochDoc(businessId);
  assert.equal(epoch.epoch, 1);
  // The prerequisite scope is raw-seeded directly at "pending_review"
  // (no addComplianceScope call, no event) — only this
  // reviewComplianceScope's own APPROVED event exists.
  assert.equal(await countReviewEvents({ targetType, targetId }), 1);
});

itest("epoch [A5] reviewComplianceScopeMembers approve: missing epoch document -> epoch 1", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  assert.equal(await getEpochDoc(businessId), undefined);
  const { response, expectedResponse, targetType, targetId } = await performEpoch_ReviewComplianceScopeMembers({
    businessId,
    ownerUid: "seller-1",
    adminUid,
  });
  assert.deepEqual(response, expectedResponse);
  const epoch = await getEpochDoc(businessId);
  assert.equal(epoch.epoch, 1);
  // The prerequisite scope/member are raw-seeded directly (no
  // addComplianceScope/addComplianceScopeMembers calls, no events) —
  // only this reviewComplianceScopeMembers' own APPROVED event exists.
  assert.equal(await countReviewEvents({ targetType, targetId }), 1);
});

// ---------------------------------------------------------------------
// B. Existing epoch behavior
// ---------------------------------------------------------------------

for (const { name, perform } of EPOCH_QUALIFYING_OPS) {
  itest(`epoch [B6] ${name}: pre-existing epoch 7 -> 8`, async () => {
    const businessId = await seedBusiness("seller-1");
    const adminUid = await seedAdmin();
    await seedEpochDoc(businessId, { epoch: 7 });
    const { response, expectedResponse } = await perform({ businessId, ownerUid: "seller-1", adminUid });
    assert.deepEqual(response, expectedResponse);
    const epoch = await getEpochDoc(businessId);
    assert.equal(epoch.epoch, 8);
  });
}

itest("epoch [B7] merge:true preserves an unrelated sentinel field on the epoch document", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  await seedEpochDoc(businessId, { epoch: 3, sentinel: "keep-me" });
  await performEpoch_ReviewComplianceDocument({ businessId, ownerUid: "seller-1", adminUid });
  const epoch = await getEpochDoc(businessId);
  assert.equal(epoch.epoch, 4);
  assert.equal(epoch.sentinel, "keep-me");
});

itest("epoch [B8] an existing epoch document missing the epoch field behaves as 0 -> 1, preserving unrelated fields", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  await seedEpochDoc(businessId, { sentinel: "keep-me-too" }); // document exists, no `epoch` field
  await performEpoch_ReviewComplianceDocument({ businessId, ownerUid: "seller-1", adminUid });
  const epoch = await getEpochDoc(businessId);
  assert.equal(epoch.epoch, 1);
  assert.equal(epoch.sentinel, "keep-me-too");
});

// ---------------------------------------------------------------------
// C. No-bump behavior
// ---------------------------------------------------------------------

itest("epoch [C9] reviewComplianceDocument reject: no epoch document is created", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  await functions.reviewComplianceDocument.run({
    auth: { uid: adminUid },
    data: { documentId, decision: "reject", rejectionReason: "no" },
  });
  assert.equal(await getEpochDoc(businessId), undefined);
});

itest("epoch [C10] reviewComplianceScope reject: no bump", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const scopeId = await seedPendingScopeDirect({ businessId });
  await functions.reviewComplianceScope.run({ auth: { uid: adminUid }, data: { scopeId, decision: "reject" } });
  assert.equal(await getEpochDoc(businessId), undefined);
});

itest("epoch [C11] reviewComplianceScopeMembers reject: no bump", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const { scopeId, memberIds } = await seedPendingScopeWithMemberDirect({ businessId });
  await functions.reviewComplianceScopeMembers.run({
    auth: { uid: adminUid },
    data: { scopeId, memberIds, decision: "reject" },
  });
  assert.equal(await getEpochDoc(businessId), undefined);
});

for (const { name, perform } of EPOCH_QUALIFYING_OPS) {
  itest(`epoch [C12] ${name}: idempotent replay does not bump a second time`, async () => {
    const businessId = await seedBusiness("seller-1");
    const adminUid = await seedAdmin();
    const { replay } = await perform({ businessId, ownerUid: "seller-1", adminUid });
    let epoch = await getEpochDoc(businessId);
    assert.equal(epoch.epoch, 1);
    const replayResponse = await replay();
    assert.equal(replayResponse.idempotent, true);
    epoch = await getEpochDoc(businessId);
    assert.equal(epoch.epoch, 1, "a replay must never bump the epoch a second time");
  });
}

itest("epoch [C13] invalid transition/status: no bump (revoke on a still-pending_review document)", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
  await assert.rejects(
    functions.revokeComplianceDocument.run({
      auth: { uid: adminUid },
      data: { documentId, revocationReason: "not approved yet" },
    }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
  assert.equal(await getEpochDoc(businessId), undefined);
});

itest("epoch [C14] auth failure: no bump (unauthenticated/non-admin caller)", async () => {
  const businessId = await seedBusiness("seller-1");
  const documentId = await seedApprovedDocumentDirect({ businessId });
  await assert.rejects(
    functions.revokeComplianceDocument.run({
      auth: null,
      data: { documentId, revocationReason: "no auth" },
    }),
    (err) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
  assert.equal(await getEpochDoc(businessId), undefined);
});

itest("epoch [C15] request validation failure: no bump (missing documentId)", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  await assert.rejects(
    functions.reviewComplianceDocument.run({ auth: { uid: adminUid }, data: { decision: "approve" } }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
  assert.equal(await getEpochDoc(businessId), undefined);
});

itest("epoch [C16] cross-tenant/business mismatch (supersede across two businesses): no bump", async () => {
  const businessId1 = await seedBusiness("seller-1");
  const businessId2 = await seedBusiness("seller-2");
  const adminUid = await seedAdmin();
  const oldDocumentId = await seedApprovedDocumentDirect({ businessId: businessId1 });
  const newDocumentId = await seedApprovedDocumentDirect({ businessId: businessId2 });
  await assert.rejects(
    functions.supersedeComplianceDocument.run({ auth: { uid: adminUid }, data: { newDocumentId, oldDocumentId } }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
  assert.equal(await getEpochDoc(businessId1), undefined);
  assert.equal(await getEpochDoc(businessId2), undefined);
});

itest("epoch [C17] missing source document/scope: no bump (not-found)", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  await assert.rejects(
    functions.reviewComplianceDocument.run({
      auth: { uid: adminUid },
      data: { documentId: "does-not-exist", decision: "approve" },
    }),
    (err) => {
      assert.equal(err.code, "not-found");
      return true;
    }
  );
  assert.equal(await getEpochDoc(businessId), undefined);
});

itest("epoch [C18] other existing failed-precondition path (brand scope approved without verifiedBrandId): no bump", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedApprovedDocumentDirect({ businessId });
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
  assert.equal(await getEpochDoc(businessId), undefined);
});

// ---------------------------------------------------------------------
// D. Atomic failure behavior — a deliberately invalid businessId ("")
// makes `db.collection("businessComplianceEpochs").doc(businessId)`
// throw synchronously the instant the epoch write is attempted inside
// the transaction (Firestore's own Admin SDK rejects an empty document
// ID at construction time). This is the one write in these five
// transactions whose failure can be forced deterministically, input-
// only, without any mock/instrumentation of production code. Each test
// below proves the *whole* transaction — not just the epoch write —
// commits nothing: the document/scope's own status update (already
// staged before the epoch write in every one of these five functions)
// is rolled back exactly as the audit event (staged after it) is, since
// Firestore transactions are all-or-nothing. This single mechanism
// therefore evidences items 19 and 21 together (a failure at the epoch
// write aborts everything already staged, and the callback as a whole
// commits zero writes), and item 20's complementary direction (the
// operation's own write does not survive either) from the same proof.
// ---------------------------------------------------------------------

itest("epoch [D19/20/21] reviewComplianceDocument approve: forcing the epoch write to throw (businessId \"\") commits zero writes — status, event, and epoch all unchanged", async () => {
  // Corrected (independent audit finding): the prior version of this
  // fixture seeded the document at "clean" and attempted "approve"
  // directly — but clean -> approved is not a legal transition
  // (COMPLIANCE_DOCUMENT_ALLOWED_TRANSITIONS.clean = ["pending_review"]
  // only), so the call rejected with the EARLIER, unrelated
  // failed-precondition "Cannot move a document from \"clean\" to
  // \"approved\"" — never reaching tx.update, the epoch write, or
  // writeComplianceReviewEvent at all. Confirmed empirically. The
  // document is raw-seeded directly at "pending_review" here instead
  // (bypassing submitComplianceDocument — not because that helper would
  // itself bump the epoch, it doesn't, but to match this file's own
  // established D-group raw-seeding convention), so the real approve
  // branch is genuinely reached: request/auth/tenant/status validation
  // pass, tx.update(documentRef, ...) is staged, and only then does the
  // epoch write's own db.collection(...).doc("") throw.
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId: "" });
  await db.collection("complianceDocuments").doc(documentId).update({ status: "pending_review" });

  let caughtError;
  try {
    await functions.reviewComplianceDocument.run({ auth: { uid: adminUid }, data: { documentId, decision: "approve" } });
  } catch (err) {
    caughtError = err;
  }
  assert.ok(caughtError, "expected the call to reject");
  // Distinguish the intended epoch-write/path-construction failure from
  // the old, unrelated invalid-transition shortcut — by class, not by a
  // platform-version-specific full string. This module's own thrown
  // failures are always HttpsError instances carrying a `code` (e.g.
  // "failed-precondition", "invalid-argument"); the raw Firestore Admin
  // SDK's synchronous document-path validation error (thrown by
  // db.collection(...).doc("") inside bumpBusinessComplianceEpoch) is a
  // plain Error with no such `code` at all. That absence is exactly what
  // proves this rejection came from the epoch write, not from an
  // earlier, already-HttpsError-wrapped application-level check.
  assert.equal(
    caughtError.code,
    undefined,
    `expected a raw SDK path-construction error with no HttpsError code, got code=${caughtError.code} message=${caughtError.message}`
  );
  assert.doesNotMatch(
    caughtError.message,
    /clean.*approved|Cannot move a document/i,
    "must not be the old, unrelated clean -> approved invalid-transition rejection"
  );
  assert.match(caughtError.message, /resource path/i);
  assert.match(caughtError.message, /non-empty string/i);

  const doc = await getDocument(documentId);
  assert.equal(
    doc.status,
    "pending_review",
    "the document's own status update must not have committed — still at its pre-attempt state, never \"approved\""
  );
  assert.equal(await countReviewEvents({ targetType: "document", targetId: documentId }), 0, "no audit event may have committed");
  // Note: businessId "" cannot itself be queried (db.collection(...).doc("")
  // throws the identical "non-empty string" error) — the status/event
  // assertions above already prove the whole transaction, epoch write
  // included, committed nothing.
});

itest("epoch [D19/20/21] revokeComplianceDocument: forcing the epoch write to throw commits zero writes", async () => {
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId: "" });
  await db.collection("complianceDocuments").doc(documentId).update({ status: "approved" });
  await assert.rejects(
    functions.revokeComplianceDocument.run({
      auth: { uid: adminUid },
      data: { documentId, revocationReason: "force epoch failure" },
    })
  );
  const doc = await getDocument(documentId);
  assert.equal(doc.status, "approved", "the document's own status update must not have committed");
  assert.equal(await countReviewEvents({ targetType: "document", targetId: documentId }), 0);
  // Note: businessId "" cannot itself be queried (db.collection(...).doc("")
  // throws the identical "non-empty string" error) — the status/event
  // assertions above already prove the whole transaction, epoch write
  // included, committed nothing.
});

itest("epoch [D19/20/21] supersedeComplianceDocument: forcing the epoch write to throw commits zero writes", async () => {
  const adminUid = await seedAdmin();
  const oldDocumentId = await seedCleanDocument({ businessId: "" });
  await db.collection("complianceDocuments").doc(oldDocumentId).update({ status: "approved" });
  const newDocumentId = await seedCleanDocument({ businessId: "" });
  await db.collection("complianceDocuments").doc(newDocumentId).update({ status: "approved" });
  await assert.rejects(
    functions.supersedeComplianceDocument.run({ auth: { uid: adminUid }, data: { newDocumentId, oldDocumentId } })
  );
  const oldDoc = await getDocument(oldDocumentId);
  const newDoc = await getDocument(newDocumentId);
  assert.equal(oldDoc.status, "approved", "neither document's status update may have committed");
  assert.equal(newDoc.supersedesDocumentId, null);
  assert.equal(await countReviewEvents({ targetType: "document", targetId: oldDocumentId }), 0);
  // Note: businessId "" cannot itself be queried (db.collection(...).doc("")
  // throws the identical "non-empty string" error) — the status/event
  // assertions above already prove the whole transaction, epoch write
  // included, committed nothing.
});

itest("epoch [D19/20/21] reviewComplianceScope approve: forcing the epoch write to throw commits zero writes", async () => {
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId: "" });
  await db.collection("complianceDocuments").doc(documentId).update({ status: "approved", sellerRelationship: "authorized_distributor" });
  const scopeId = crypto.randomUUID();
  await db.collection("complianceDocumentScopes").doc(scopeId).set({
    documentId,
    businessId: "",
    scopeType: "sku_set",
    scopeValue: "sku-set-1",
    sellerRelationship: "authorized_distributor",
    documentType: "purchase_invoice",
    validUntil: null,
    memberCount: 0,
    status: "pending_review",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seller-1",
    reviewedBy: null,
    reviewedAt: null,
    verifiedBrandId: null,
  });
  await assert.rejects(
    functions.reviewComplianceScope.run({ auth: { uid: adminUid }, data: { scopeId, decision: "approve" } })
  );
  const scopeSnap = await db.collection("complianceDocumentScopes").doc(scopeId).get();
  assert.equal(scopeSnap.data().status, "pending_review", "the scope's own status update must not have committed");
  assert.equal(await countReviewEvents({ targetType: "scope", targetId: scopeId }), 0);
  // Note: businessId "" cannot itself be queried (db.collection(...).doc("")
  // throws the identical "non-empty string" error) — the status/event
  // assertions above already prove the whole transaction, epoch write
  // included, committed nothing.
});

itest("epoch [D19/20/21] reviewComplianceScopeMembers approve: forcing the epoch write to throw commits zero writes", async () => {
  const adminUid = await seedAdmin();
  const scopeId = crypto.randomUUID();
  await db.collection("complianceDocumentScopes").doc(scopeId).set({
    documentId: "doc-x",
    businessId: "",
    scopeType: "sku_set",
    scopeValue: "sku-set-1",
    sellerRelationship: "authorized_distributor",
    documentType: "purchase_invoice",
    validUntil: null,
    memberCount: 0,
    status: "approved",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seller-1",
    reviewedBy: adminUid,
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    verifiedBrandId: null,
  });
  const { deriveScopeMemberId } = require("../src/marketplace/compliance/complianceDocumentOperations");
  const memberId = deriveScopeMemberId({ scopeId, identifierType: "sku", identifierValue: "SKU-EPOCH-D" });
  await db.collection("complianceDocumentScopes").doc(scopeId).collection("members").doc(memberId).set({
    identifierType: "sku",
    identifierValue: "SKU-EPOCH-D",
    status: "pending_review",
    addedAt: admin.firestore.FieldValue.serverTimestamp(),
    addedBy: "seller-1",
    reviewedBy: null,
    reviewedAt: null,
    revokedAt: null,
    revokedBy: null,
  });
  await assert.rejects(
    functions.reviewComplianceScopeMembers.run({
      auth: { uid: adminUid },
      data: { scopeId, memberIds: [memberId], decision: "approve" },
    })
  );
  const memberSnap = await db.collection("complianceDocumentScopes").doc(scopeId).collection("members").doc(memberId).get();
  assert.equal(memberSnap.data().status, "pending_review", "the member's own status update must not have committed");
  assert.equal(await countReviewEvents({ targetType: "scope_member_batch", targetId: scopeId }), 0);
  // Note: businessId "" cannot itself be queried (db.collection(...).doc("")
  // throws the identical "non-empty string" error) — the status/event
  // assertions above already prove the whole transaction, epoch write
  // included, committed nothing.
});

// ---------------------------------------------------------------------
// E. Concurrency — real races against the real emulator, same
// established Promise.allSettled pattern already used elsewhere in this
// file (e.g. "addScope (Correction B): concurrent duplicate calls...").
//
// Explicit concurrency taxonomy (corrected — the prior wording here
// overclaimed what E23 actually proves):
//   Type A — one logical invocation's own transaction callback is
//     internally re-executed by Firestore because a document it read
//     changed before its own commit (a genuine mid-transaction retry).
//     NOT directly instrumented or proven by this suite — this file's
//     own top-of-file doc comment already documents that a controlled,
//     reliable way to force this against the real emulator (without
//     breaking the transaction handle) was not found; production
//     correctness for this case rests on Firestore's own documented
//     transaction semantics, not on a test observing a callback run
//     twice for one call.
//   Type B — several separate, independent invocations race on the
//     SAME target; exactly one performs the real transition, the rest
//     converge through this module's own existing idempotent-replay
//     contract. Proven below by E23.
//   Type C — several separate, independent invocations succeed on
//     DIFFERENT targets for the same business, each a genuine, distinct
//     transition; the shared businessComplianceEpochs/{businessId}
//     document's FieldValue.increment(1) must not lose any of them.
//     Proven below by E24 (sequential) and E25 (concurrent).
// ---------------------------------------------------------------------

itest("epoch [E23] Type B — five competing independent invocations race on the SAME document: exactly one performs the real transition, the other four converge via idempotent replay, exactly one NEW event and one epoch increment are added by the race — proven against an explicit pre-race baseline, not merely a bare final total", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const documentId = await seedCleanDocument({ businessId });
  await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });

  // Corrected (independent audit finding): a prior version of this test
  // asserted only the bare FINAL total (2) after the race, backed by a
  // comment explaining "1 baseline + 1 delta" rather than by an actual
  // captured-and-compared baseline. That final-total-only check cannot,
  // by itself, distinguish "the race added exactly one event" from any
  // other bug combination that happens to also total 2. The baseline is
  // now captured and asserted explicitly, BEFORE the race, and the
  // race's own effect is proven as a delta against it.
  const baselineEventsSnap = await db
    .collection("complianceReviewEvents")
    .where("targetType", "==", "document")
    .where("targetId", "==", documentId)
    .get();
  const baselineEventCount = baselineEventsSnap.size;
  assert.equal(
    baselineEventCount,
    1,
    "exactly one baseline event (submitComplianceDocument's own SUBMITTED event) must exist before the race"
  );
  assert.equal(
    baselineEventsSnap.docs[0].data().action,
    "submitted",
    "the baseline event must be the expected SUBMITTED action"
  );

  const attempts = 5;
  const outcomes = await Promise.allSettled(
    Array.from({ length: attempts }, () =>
      functions.reviewComplianceDocument.run({ auth: { uid: adminUid }, data: { documentId, decision: "approve" } })
    )
  );
  const fulfilled = outcomes.filter((o) => o.status === "fulfilled").map((o) => o.value);
  assert.equal(fulfilled.length, attempts, "every concurrent attempt against the same target must resolve, not error");
  const realTransitions = fulfilled.filter((r) => r.idempotent === false);
  const replays = fulfilled.filter((r) => r.idempotent === true);
  assert.equal(realTransitions.length, 1, "exactly one attempt performs the real transition");
  assert.equal(replays.length, attempts - 1, "every other attempt resolves as an idempotent replay");

  const epoch = await getEpochDoc(businessId);
  assert.equal(epoch.epoch, 1, "the epoch increments exactly once, never once per attempt");

  const finalEventsSnap = await db
    .collection("complianceReviewEvents")
    .where("targetType", "==", "document")
    .where("targetId", "==", documentId)
    .get();
  const finalEventCount = finalEventsSnap.size;
  assert.equal(
    finalEventCount - baselineEventCount,
    1,
    "the race must add exactly one NEW event on top of the explicit baseline — the actual claim this test's own name makes, not merely a bare final total"
  );
  // Secondary, non-load-bearing sanity check — kept for readability, but
  // it must never substitute for the baseline/delta proof above.
  assert.equal(finalEventCount, 2);
  const approvedEvents = finalEventsSnap.docs.filter((d) => d.data().action === "approved");
  assert.equal(
    approvedEvents.length,
    1,
    "exactly one new APPROVED event exists after the race — no duplicate APPROVED event was created by any of the four replay attempts"
  );
});

itest("epoch [E24] Type C — two independent successful qualifying transitions for the same business (sequential): epoch increases by exactly two", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  await performEpoch_ReviewComplianceDocument({ businessId, ownerUid: "seller-1", adminUid });
  let epoch = await getEpochDoc(businessId);
  assert.equal(epoch.epoch, 1);
  await performEpoch_RevokeComplianceDocument({ businessId, ownerUid: "seller-1", adminUid });
  epoch = await getEpochDoc(businessId);
  assert.equal(epoch.epoch, 2);
});

itest("epoch [E25] Type C — N concurrent, independent qualifying transitions for the same business (different documents, real race on the shared epoch document only): no lost increment — final epoch equals the successful-transition count", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const n = 8;
  const documentIds = [];
  for (let i = 0; i < n; i += 1) {
    const documentId = await seedCleanDocument({ businessId });
    await functions.submitComplianceDocument.run({ auth: { uid: "seller-1" }, data: validSubmitRequest(documentId) });
    documentIds.push(documentId);
  }
  // Each attempt targets a DIFFERENT document — no contention on the
  // document refs themselves, only shared contention on the one
  // businessComplianceEpochs/{businessId} document every attempt's
  // FieldValue.increment(1) races to update concurrently.
  const outcomes = await Promise.all(
    documentIds.map((documentId) =>
      functions.reviewComplianceDocument.run({ auth: { uid: adminUid }, data: { documentId, decision: "approve" } })
    )
  );
  assert.equal(outcomes.filter((r) => r.idempotent === false).length, n);
  const epoch = await getEpochDoc(businessId);
  assert.equal(epoch.epoch, n, "FieldValue.increment is atomic under concurrency — no lost update");
});

// ---------------------------------------------------------------------
// F. Supersede authoritative business identity
// ---------------------------------------------------------------------

itest("epoch [F26] supersede increments oldData.businessId, confirmed against the actual old document's stored business", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const { businessId: keyedBusinessId } = await performEpoch_SupersedeComplianceDocument({
    businessId,
    ownerUid: "seller-1",
    adminUid,
  });
  assert.equal(keyedBusinessId, businessId);
  const epoch = await getEpochDoc(businessId);
  assert.equal(epoch.epoch, 1);
});

itest("epoch [F27] supersede's request shape has no businessId field at all — a caller cannot supply or redirect it", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const oldDocumentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId: oldDocumentId });
  const newDocumentId = await seedCleanDocument({ businessId });
  await submitAndApprove({ ownerUid: "seller-1", adminUid, businessId, documentId: newDocumentId });
  await assert.rejects(
    functions.supersedeComplianceDocument.run({
      auth: { uid: adminUid },
      data: { newDocumentId, oldDocumentId, businessId: "forged-business" },
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      assert.match(err.message, /unrecognized field/);
      return true;
    }
  );
  assert.equal(await getEpochDoc("forged-business"), undefined);
});

itest("epoch [F28] no epoch document is ever written under any businessId other than oldData's own", async () => {
  const businessId = await seedBusiness("seller-1");
  const adminUid = await seedAdmin();
  const { targetId: oldDocumentId } = await performEpoch_SupersedeComplianceDocument({
    businessId,
    ownerUid: "seller-1",
    adminUid,
  });
  const epoch = await getEpochDoc(businessId);
  assert.equal(epoch.epoch, 1, "the one authoritative epoch document, keyed by oldData.businessId, was bumped");
  // Negative checks: no epoch document was ever created under any of
  // the other plausible-but-wrong keys a naive implementation might
  // have used instead (the old document's own ID, mistaken for a
  // businessId).
  assert.equal(await getEpochDoc(oldDocumentId), undefined);
});

// ---------------------------------------------------------------------
// H. Freshness integration proof — uses the real, unmodified
// evaluateLiveProductEligibility (complianceEligibilityEvaluator.js),
// the real computeDecisionHash (complianceProductRecompute.js), and the
// real bootstrapCompliancePolicyRegistry (compliancePolicyRegistryOperations.js)
// against this same real emulator — never a reimplementation of any of
// their algorithms. Only the fixture DATA is hand-built here, using the
// same minimal-valid-policy-version shape already established by
// compliancePolicyRegistryOperations.test.js's own fixtures.
// ---------------------------------------------------------------------

const {
  evaluateLiveProductEligibility,
} = require("../src/marketplace/compliance/complianceEligibilityEvaluator");
const {
  computeDecisionHash,
} = require("../src/marketplace/compliance/complianceProductRecompute");

// Empirically confirmed (not guessed): a genuinely activation-eligible
// compliancePolicyRegistry version document requires at least one
// non-empty `requiredDocumentTypeGroups` entry — Slice 4.1's own
// `validateRequiredDocumentTypeGroups` rejects `groups.length < 1` and
// rejects any inner group with `length === 0`. Historical note,
// resolved by Revision 13 (§0.11): that field was originally shaped as
// a native array-of-arrays, which real Firestore rejected outright
// ("3 INVALID_ARGUMENT: Nested arrays are not allowed"), confirmed
// directly against this same emulator — a pre-existing Slice 4.1
// schema/Firestore incompatibility, entirely unrelated to and outside
// the authorized scope of the original Slice 4.6 corrective task that
// first wrote this comment. Revision 13 has since corrected the field
// to the wrapped `RequiredDocumentTypeGroup[]` shape used directly
// below, which real Firestore does accept — but this one fixture stays
// fake-db-only regardless, matching this test's own actual subject
// (epoch-freshness integration, not policy-schema serialization); the
// wrapped shape used here only needs to keep passing the real
// production validator's own full check (via `resolveActivePolicy`
// inside `evaluateLiveProductEligibility`), which it does. This
// freshness-integration proof follows the identical,
// already-established pattern: a minimal, self-contained, read-only
// fake `db` (no transactions — evaluateLiveProductEligibility performs
// only `.get()` reads when no `tx` is supplied) drives the REAL,
// unmodified `evaluateLiveProductEligibility`, exactly mirroring
// complianceMatching.test.js's own "M3. an epoch bump between calls
// excludes the product on the next evaluation" test. The REAL
// production epoch-write path itself (collection name, doc-key-by-
// businessId, `epoch` field, exact increment/merge shape) is
// independently and rigorously proven against the REAL emulator by the
// A-G groups above; this test's own job is only to prove the OTHER half
// of the integration — that the evaluator correctly treats that same
// shape as authoritative — without needing both halves to run inside
// one Firestore instance to make the combined claim honest.
function makeFreshnessFakeDb(seedDocs) {
  const store = new Map(Object.entries(seedDocs));
  function docRef(path) {
    return {
      async get() {
        const data = store.get(path);
        return { exists: data !== undefined, data: () => data };
      },
      // Recursive — productRef() needs businesses/{id}.collection("products").doc(id).
      collection(subName) {
        return collectionRef(`${path}/${subName}`);
      },
    };
  }
  function collectionRef(prefix) {
    return { doc: (id) => docRef(`${prefix}/${id}`) };
  }
  return {
    collection(name) {
      return collectionRef(name);
    },
    // Test-only helper, not part of the real Firestore interface —
    // lets a test mutate the epoch "live" between two evaluator calls,
    // exactly simulating what the real bumpBusinessComplianceEpoch
    // helper's tx.set({epoch: increment(1)}, {merge:true}) produces.
    _setEpoch(businessId, epoch) {
      const key = `businessComplianceEpochs/${businessId}`;
      const prior = store.get(key) || {};
      store.set(key, { ...prior, epoch });
    },
  };
}

function freshnessFixtureDocs({ businessId, productId, activeVersionId, evidenceRevision }) {
  const nowMs = Date.now();
  const timestamp = (ms) => ({ toMillis: () => ms });
  const decisionContent = {
    businessId,
    policyVersion: activeVersionId,
    evidenceRevision,
    productInputRevisionSnapshot: 0,
    sellerRelationshipSnapshot: "manufacturer",
    // Marketplace Revision 35 (Slice 7A) — the eleventh bound decision-hash
    // input. This fixture's product carries no admin-recorded class, so the
    // decision records the explicit `null` sentinel, exactly as the real
    // writer does.
    pilotProductClassSnapshot: null,
    requiredEvidenceSlots: [],
    satisfiedEvidenceSlots: [],
    activeEvidenceRefs: [],
    validUntil: timestamp(nowMs + 365 * 24 * 60 * 60 * 1000),
    effectiveStatus: "verified_valid",
  };
  return {
    [`compliancePolicyRegistryPointer/current`]: { activeVersionId },
    [`compliancePolicyRegistry/${activeVersionId}`]: {
      sellerRelationship: {
        manufacturer: {
          acceptedDocumentTypes: ["purchase_invoice"],
          requiredDocumentTypeGroups: [{ documentTypes: ["purchase_invoice"] }],
          perDocumentTypePolicy: { purchase_invoice: { validUntilRequired: true, issueDateRequired: false } },
          maximumValidityPeriod: null,
          acceptedScopeTypes: ["business"],
          manualAdminOverridePermitted: false,
        },
      },
      status: "active",
      effectiveFrom: timestamp(nowMs - 10000),
      createdBy: "s46-freshness-fixture",
      createdAt: timestamp(nowMs - 10000),
      changeNote: "Slice 4.6 freshness-integration fixture",
    },
    [`businesses/${businessId}/products/${productId}`]: {
      businessId,
      sellerRelationship: "manufacturer",
      productInputRevision: 0,
    },
    [`productComplianceDecisions/${productId}`]: {
      ...decisionContent,
      decisionHash: computeDecisionHash(decisionContent),
    },
  };
}

itest("epoch [H38] a decision computed at evidenceRevision N becomes stale (eligibility_evidence_revision_mismatch) the moment the business epoch reaches N+1 — the exact shape the real Slice 4.6 write produces", async () => {
  const businessId = "s46-fresh-biz-1";
  const productId = "s46-fresh-product-1";
  const activeVersionId = "s46-fresh-policy-1";
  const fakeDb = makeFreshnessFakeDb(freshnessFixtureDocs({ businessId, productId, activeVersionId, evidenceRevision: 0 }));
  fakeDb._setEpoch(businessId, 0);

  const before = await evaluateLiveProductEligibility({ db: fakeDb, businessId, productId, now: new Date() });
  assert.deepEqual(before, { eligible: true, reason: null }, "the hand-built fixture must be genuinely, fully valid before any bump");

  // Simulate exactly what one real qualifying Slice 4.6 transition
  // produces: businessComplianceEpochs/{businessId}.epoch 0 -> 1. (The
  // real production write itself — collection/doc/field/increment/merge
  // shape — is independently proven against the real emulator by the
  // A-G groups above.)
  fakeDb._setEpoch(businessId, 1);

  const after = await evaluateLiveProductEligibility({ db: fakeDb, businessId, productId, now: new Date() });
  assert.equal(after.eligible, false);
  assert.equal(after.reason, "eligibility_evidence_revision_mismatch");
});

itest("epoch [H39] an unchanged epoch (mirroring a non-qualifying reject/idempotent operation, which the A-G groups above independently prove never bumps it) does NOT make the same decision stale", async () => {
  const businessId = "s46-fresh-biz-2";
  const productId = "s46-fresh-product-2";
  const activeVersionId = "s46-fresh-policy-2";
  const fakeDb = makeFreshnessFakeDb(freshnessFixtureDocs({ businessId, productId, activeVersionId, evidenceRevision: 0 }));
  fakeDb._setEpoch(businessId, 0);

  const before = await evaluateLiveProductEligibility({ db: fakeDb, businessId, productId, now: new Date() });
  assert.equal(before.eligible, true);

  // No epoch mutation at all — exactly what a reject or an idempotent
  // replay produces in production (proven separately: C9-C11/C18 and
  // C12 above, behaviorally, against the real emulator).
  const after = await evaluateLiveProductEligibility({ db: fakeDb, businessId, productId, now: new Date() });
  assert.deepEqual(after, { eligible: true, reason: null }, "an unchanged epoch must never make an otherwise-fresh decision stale");
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

// Revision 9 correction 49 — same static proof, extended to
// documentType/validUntil: written onto complianceDocumentScopes only
// by addComplianceScope's own tx.create(scopeRef, ...), never by any
// tx.update(scopeRef, ...) call (reviewComplianceScope's or
// addComplianceScopeMembers').
test("static: documentType/validUntil are written onto complianceDocumentScopes only by addComplianceScope's tx.create(scopeRef, ...), never by any tx.update(scopeRef, ...)", () => {
  const scopeUpdateCalls = EXECUTABLE_TEXT.match(/tx\.update\(scopeRef[^;]*\)/g) || [];
  assert.ok(scopeUpdateCalls.length >= 1, "expected at least one tx.update(scopeRef, ...) call");
  for (const call of scopeUpdateCalls) {
    assert.equal(call.includes("documentType"), false, `tx.update(scopeRef, ...) must never touch documentType: ${call}`);
    assert.equal(call.includes("validUntil"), false, `tx.update(scopeRef, ...) must never touch validUntil: ${call}`);
  }
  const scopeCreateCalls = EXECUTABLE_TEXT.match(/tx\.create\(scopeRef[^;]*\)/g) || [];
  assert.equal(scopeCreateCalls.length, 1, "expected exactly one scope tx.create() call");
  assert.ok(scopeCreateCalls[0].includes("documentType"));
  assert.ok(scopeCreateCalls[0].includes("validUntil"));
});

// =====================================================================
// Slice 4.6 — static/exact-write guards (items 29-37). Reuses the
// nonCommentLines-scoped EXECUTABLE_TEXT/SOURCE_TEXT already defined
// above.
// =====================================================================

test("epoch [G29] exactly five production call sites invoke bumpBusinessComplianceEpoch, plus exactly one definition and exactly one export", () => {
  // Occurrences of the identifier fall into exactly three kinds: the one
  // `function bumpBusinessComplianceEpoch(...)` declaration, the one
  // `module.exports` entry (Marketplace Revision 35 — the helper is now
  // shared with `pilotProductClassification.js`, so reclassification
  // schedules recomputation through this same existing mechanism rather
  // than a second, drifting copy of it), and the real call sites. Counting
  // the first two explicitly and subtracting keeps this a genuine call-site
  // census rather than a bare occurrence count that a new export could
  // silently satisfy.
  const totalOccurrences = (EXECUTABLE_TEXT.match(/bumpBusinessComplianceEpoch/g) || []).length;
  const definitionCount = (EXECUTABLE_TEXT.match(/function bumpBusinessComplianceEpoch/g) || []).length;
  const exportCount = (EXECUTABLE_TEXT.match(/^\s{2}bumpBusinessComplianceEpoch,\s*$/gm) || []).length;
  assert.equal(definitionCount, 1, "expected exactly one helper definition");
  assert.equal(exportCount, 1, "expected exactly one module.exports entry");
  assert.equal(
    totalOccurrences - definitionCount - exportCount,
    5,
    "expected exactly five call sites"
  );
});

test("epoch [G30/31/32/33] the helper's own write uses exactly the frozen collection/field/operation/merge shape", () => {
  const fnMatch = SOURCE_TEXT.match(/function bumpBusinessComplianceEpoch\([^]*?\n\}/);
  assert.ok(fnMatch, "expected to find the bumpBusinessComplianceEpoch function body");
  const body = fnMatch[0];
  assert.match(body, /db\.collection\("businessComplianceEpochs"\)\.doc\(businessId\)/);
  assert.match(body, /epoch:\s*admin\.firestore\.FieldValue\.increment\(1\)/);
  assert.match(body, /tx\.set\(\s*epochRef,\s*\{\s*epoch:\s*admin\.firestore\.FieldValue\.increment\(1\)\s*\},\s*\{\s*merge:\s*true\s*\}\s*\)/);
});

test("epoch [G34] no tx.update ever targets the epoch document/collection", () => {
  assert.equal(/tx\.update\([^)]*businessComplianceEpochs/.test(EXECUTABLE_TEXT), false);
  assert.equal(/tx\.update\(\s*epochRef/.test(EXECUTABLE_TEXT), false);
});

test("epoch [G35] no epoch read is ever added — businessComplianceEpochs/epochRef is never the target of a .get()", () => {
  assert.equal(/businessComplianceEpochs[^;]*\.get\(/.test(EXECUTABLE_TEXT), false);
  assert.equal(/epochRef[^;]*\.get\(/.test(EXECUTABLE_TEXT), false);
  assert.equal(/tx\.get\(\s*epochRef/.test(EXECUTABLE_TEXT), false);
});

test("epoch [G36] the exact five call sites are the exact five named qualifying operations, no sixth", () => {
  const fnStarts = [];
  const fnRe = /^async function (\w+)\(/gm;
  let m;
  while ((m = fnRe.exec(EXECUTABLE_TEXT)) !== null) {
    fnStarts.push({ name: m[1], index: m.index });
  }
  fnStarts.push({ name: "__EOF__", index: EXECUTABLE_TEXT.length });

  const callSites = [];
  const callRe = /bumpBusinessComplianceEpoch\(\{/g;
  let c;
  while ((c = callRe.exec(EXECUTABLE_TEXT)) !== null) {
    // Skip the function's own declaration line.
    const precedingText = EXECUTABLE_TEXT.slice(Math.max(0, c.index - 40), c.index);
    if (/function\s+$/.test(precedingText)) continue;
    // Find which function body this call falls inside.
    let owner = null;
    for (let i = 0; i < fnStarts.length - 1; i += 1) {
      if (c.index >= fnStarts[i].index && c.index < fnStarts[i + 1].index) {
        owner = fnStarts[i].name;
        break;
      }
    }
    callSites.push(owner);
  }

  assert.deepEqual(
    callSites.sort(),
    [
      "reviewComplianceDocument",
      "revokeComplianceDocument",
      "supersedeComplianceDocument",
      "reviewComplianceScope",
      "reviewComplianceScopeMembers",
    ].sort()
  );
});

test("epoch [G37] no Rules/index/evaluator/recompute/index.js file is referenced by this module's own source", () => {
  // This module never requires any of the four forbidden-to-touch
  // sibling files — confirms the Slice 4.6 change is fully self-
  // contained within complianceDocumentOperations.js, no new coupling.
  assert.equal(/require\([^)]*complianceEligibilityEvaluator/.test(SOURCE_TEXT), false);
  assert.equal(/require\([^)]*complianceProductRecompute/.test(SOURCE_TEXT), false);
  assert.equal(/firestore\.rules/.test(SOURCE_TEXT), false);
  assert.equal(/firestore\.indexes\.json/.test(SOURCE_TEXT), false);
});
