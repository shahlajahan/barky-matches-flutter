"use strict";

// P1-A Slice 1 — Firestore Rules foundation tests (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §16 Slice 1; docs/audits/marketplace_p1_bulk_compliance_inventory_
// architecture_2026-08-21.md). Every collection introduced in this slice
// is deny-by-default / server-write-only. These tests prove that posture
// directly against the deployed Rules text, not by inspecting the Rules
// source — no seller, admin, or unauthenticated client can write any of
// these collections at all in Slice 1 (every write path is introduced by
// a later slice's Admin-SDK server operation, which bypasses these Rules
// entirely and needs no `allow` clause here).

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, deleteDoc } = require("firebase/firestore");

const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8"
);

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
let testEnv;

function rulesTest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

async function env() {
  if (testEnv) return testEnv;
  testEnv = await initializeTestEnvironment({
    projectId: `p1a-slice1-rules-${Date.now()}`,
    firestore: { rules },
  });
  return testEnv;
}

async function resetSeed() {
  const rulesEnv = await env();
  await rulesEnv.clearFirestore();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "businesses", "biz-1"), { ownerUid: "seller-1" });
    await setDoc(doc(db, "businesses", "biz-2"), { ownerUid: "seller-2" });
    await setDoc(doc(db, "users", "admin-1"), { role: "admin" });
  });
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

async function seedDoc(docPath, data) {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), docPath), data);
  });
}

// One fixture per top-level P1-A Slice 1 collection. `ownerReadable`/
// `adminReadable` encode the deliberately conservative matrix explained
// in firestore.rules' own comment: complianceUploadSessions,
// complianceDocuments, and complianceReviewEvents defer owner read to a
// later, server-mediated slice; compliancePolicyRegistry is fully closed
// via Rules for everyone, admin included.
const COLLECTIONS = [
  {
    name: "businessInventoryPolicies",
    docId: "biz-1",
    docPath: "businessInventoryPolicies/biz-1",
    newDocPath: "businessInventoryPolicies/biz-1",
    seed: {
      businessId: "biz-1",
      stockAuthorityType: "manual",
      status: "active",
      defaultSafetyStock: 0,
    },
    ownerReadable: true,
    adminReadable: true,
  },
  {
    name: "complianceUploadSessions",
    docId: "session-1",
    docPath: "complianceUploadSessions/session-1",
    newDocPath: "complianceUploadSessions/session-new",
    seed: { businessId: "biz-1", documentId: "compdoc-1", status: "issued" },
    ownerReadable: false,
    adminReadable: true,
  },
  {
    name: "complianceDocuments",
    docId: "compdoc-1",
    docPath: "complianceDocuments/compdoc-1",
    newDocPath: "complianceDocuments/compdoc-new",
    seed: { businessId: "biz-1", sessionId: "session-1", status: "clean" },
    ownerReadable: false,
    adminReadable: true,
  },
  {
    name: "complianceDocumentScopes",
    docId: "scope-1",
    docPath: "complianceDocumentScopes/scope-1",
    newDocPath: "complianceDocumentScopes/scope-new",
    seed: {
      businessId: "biz-1",
      documentId: "compdoc-1",
      scopeType: "business",
      status: "pending_review",
    },
    ownerReadable: true,
    adminReadable: true,
  },
  {
    name: "productEvidenceLinks",
    docId: "link-1",
    docPath: "productEvidenceLinks/link-1",
    newDocPath: "productEvidenceLinks/link-new",
    seed: {
      businessId: "biz-1",
      productId: "p1",
      documentId: "compdoc-1",
      scopeId: "scope-1",
    },
    ownerReadable: true,
    adminReadable: true,
  },
  {
    name: "complianceReviewEvents",
    docId: "event-1",
    docPath: "complianceReviewEvents/event-1",
    newDocPath: "complianceReviewEvents/event-new",
    seed: {
      businessId: "biz-1",
      targetType: "document",
      targetId: "compdoc-1",
      action: "submitted",
    },
    ownerReadable: false,
    adminReadable: true,
  },
  {
    name: "compliancePolicyRegistry",
    docId: "v1",
    docPath: "compliancePolicyRegistry/v1",
    newDocPath: "compliancePolicyRegistry/v2",
    seed: { status: "inactive" },
    ownerReadable: false,
    adminReadable: false,
  },
  {
    name: "productComplianceDecisions",
    docId: "p1",
    docPath: "productComplianceDecisions/p1",
    newDocPath: "productComplianceDecisions/p2",
    seed: {
      businessId: "biz-1",
      effectiveStatus: "evidence_missing",
      activeEvidenceRefs: [],
    },
    ownerReadable: true,
    adminReadable: true,
  },
];

for (const c of COLLECTIONS) {
  // ---- 1/6. unauthenticated read denied ----
  rulesTest(`${c.name}: unauthenticated read denied`, async () => {
    await resetSeed();
    await seedDoc(c.docPath, c.seed);
    const db = (await env()).unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, c.docPath)));
  });

  // ---- 2. unauthenticated write denied ----
  rulesTest(`${c.name}: unauthenticated write denied`, async () => {
    await resetSeed();
    const db = (await env()).unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(db, c.newDocPath), c.seed));
  });

  // ---- 3. owner direct write denied (create/update/delete) ----
  rulesTest(`${c.name}: owner direct create/update/delete all denied`, async () => {
    await resetSeed();
    await seedDoc(c.docPath, c.seed);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(setDoc(doc(db, c.newDocPath), c.seed));
    await assertFails(updateDoc(doc(db, c.docPath), { injectedField: true }));
    await assertFails(deleteDoc(doc(db, c.docPath)));
  });

  // ---- admin write denied via Rules (Admin SDK bypasses Rules
  // entirely and needs no allow clause; this proves the RAW CLIENT SDK
  // path stays closed even for an admin account) ----
  rulesTest(`${c.name}: admin direct write denied via Rules`, async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(setDoc(doc(db, c.newDocPath), c.seed));
  });

  // ---- 4/10. cross-business read denied ----
  rulesTest(`${c.name}: cross-business (seller-2) read denied`, async () => {
    await resetSeed();
    await seedDoc(c.docPath, c.seed); // owned by biz-1
    const db = (await env()).authenticatedContext("seller-2").firestore();
    await assertFails(getDoc(doc(db, c.docPath)));
  });

  // ---- 5. cross-business write denied ----
  rulesTest(`${c.name}: cross-business (seller-2) write denied`, async () => {
    await resetSeed();
    await seedDoc(c.docPath, c.seed);
    const db = (await env()).authenticatedContext("seller-2").firestore();
    await assertFails(updateDoc(doc(db, c.docPath), { injectedField: true }));
  });

  // ---- 7. admin read allowed only where intended ----
  if (c.adminReadable) {
    rulesTest(`${c.name}: admin read allowed`, async () => {
      await resetSeed();
      await seedDoc(c.docPath, c.seed);
      const db = (await env()).authenticatedContext("admin-1").firestore();
      await assertSucceeds(getDoc(doc(db, c.docPath)));
    });
  } else {
    rulesTest(`${c.name}: admin read denied (fully closed collection)`, async () => {
      await resetSeed();
      await seedDoc(c.docPath, c.seed);
      const db = (await env()).authenticatedContext("admin-1").firestore();
      await assertFails(getDoc(doc(db, c.docPath)));
    });
  }

  // ---- 8/9. owner read allowed only where intended; owner cannot read
  // admin-private documents ----
  if (c.ownerReadable) {
    rulesTest(`${c.name}: owner read allowed for own business`, async () => {
      await resetSeed();
      await seedDoc(c.docPath, c.seed);
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertSucceeds(getDoc(doc(db, c.docPath)));
    });
  } else {
    rulesTest(
      `${c.name}: owner read denied even for own business (admin-private in Slice 1)`,
      async () => {
        await resetSeed();
        await seedDoc(c.docPath, c.seed);
        const db = (await env()).authenticatedContext("seller-1").firestore();
        await assertFails(getDoc(doc(db, c.docPath)));
      }
    );
  }
}

// ---------------------------------------------------------------------
// complianceDocumentScopes/{scopeId}/members/{memberId} — subcollection
// isolation. Member documents carry no businessId of their own; the Rule
// re-checks the PARENT scope's businessId independently on every read,
// never assumes inherited access.
// ---------------------------------------------------------------------

async function seedScopeWithMember() {
  await seedDoc("complianceDocumentScopes/scope-1", {
    businessId: "biz-1",
    documentId: "compdoc-1",
    scopeType: "sku_set",
    status: "pending_review",
  });
  await seedDoc("complianceDocumentScopes/scope-1/members/member-1", {
    identifierType: "barcode",
    identifierValue: "1234567890123",
    status: "pending_review",
  });
}

rulesTest("scope member: unauthenticated read denied", async () => {
  await resetSeed();
  await seedScopeWithMember();
  const db = (await env()).unauthenticatedContext().firestore();
  await assertFails(
    getDoc(doc(db, "complianceDocumentScopes/scope-1/members/member-1"))
  );
});

rulesTest("scope member: owner read allowed via independent parent-scope lookup", async () => {
  await resetSeed();
  await seedScopeWithMember();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertSucceeds(
    getDoc(doc(db, "complianceDocumentScopes/scope-1/members/member-1"))
  );
});

rulesTest("scope member: cross-business (seller-2) read denied", async () => {
  await resetSeed();
  await seedScopeWithMember();
  const db = (await env()).authenticatedContext("seller-2").firestore();
  await assertFails(
    getDoc(doc(db, "complianceDocumentScopes/scope-1/members/member-1"))
  );
});

rulesTest("scope member: admin read allowed", async () => {
  await resetSeed();
  await seedScopeWithMember();
  const db = (await env()).authenticatedContext("admin-1").firestore();
  await assertSucceeds(
    getDoc(doc(db, "complianceDocumentScopes/scope-1/members/member-1"))
  );
});

rulesTest("scope member: owner write denied (create/update/delete)", async () => {
  await resetSeed();
  await seedScopeWithMember();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(doc(db, "complianceDocumentScopes/scope-1/members/member-2"), {
      identifierType: "sku",
      identifierValue: "SKU-1",
      status: "pending_review",
    })
  );
  await assertFails(
    updateDoc(doc(db, "complianceDocumentScopes/scope-1/members/member-1"), {
      status: "active",
    })
  );
  await assertFails(
    deleteDoc(doc(db, "complianceDocumentScopes/scope-1/members/member-1"))
  );
});

rulesTest("scope member: admin write denied via Rules", async () => {
  await resetSeed();
  await seedScopeWithMember();
  const db = (await env()).authenticatedContext("admin-1").firestore();
  await assertFails(
    updateDoc(doc(db, "complianceDocumentScopes/scope-1/members/member-1"), {
      status: "active",
    })
  );
});

// ---------------------------------------------------------------------
// Explicit "seller cannot inject server-owned state" tests (item 11) —
// distinct from the generic write-denied tests above in that these use
// realistic server-owned field names/values, proving intent is not just
// "every write happens to fail" but specifically that impersonating a
// server-set field is denied.
// ---------------------------------------------------------------------

rulesTest(
  "seller cannot inject an approved complianceDocuments status via a raw write",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(doc(db, "complianceDocuments/forged-1"), {
        businessId: "biz-1",
        status: "approved",
        reviewedBy: "seller-1",
        reviewedAt: Date.now(),
      })
    );
  }
);

rulesTest(
  "seller cannot activate a compliancePolicyRegistry version",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(doc(db, "compliancePolicyRegistry/v1"), { status: "active" })
    );
  }
);

rulesTest(
  "seller cannot create a self-favorable productComplianceDecisions record",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(doc(db, "productComplianceDecisions/p1"), {
        businessId: "biz-1",
        effectiveStatus: "verified_valid",
        activeEvidenceRefs: [],
      })
    );
  }
);

rulesTest(
  "seller cannot create or alter a complianceReviewEvents entry",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(doc(db, "complianceReviewEvents/forged-1"), {
        businessId: "biz-1",
        targetType: "document",
        targetId: "compdoc-1",
        action: "approved",
        actorUid: "seller-1",
        actorRole: "admin",
      })
    );
  }
);

rulesTest("seller cannot create an upload session directly", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(doc(db, "complianceUploadSessions/forged-1"), {
      businessId: "biz-1",
      documentId: "compdoc-forged",
      status: "clean",
    })
  );
});
