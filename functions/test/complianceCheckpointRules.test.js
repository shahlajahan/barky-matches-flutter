"use strict";

// Pre-Slice-7 correction — explicit client isolation of the two server-owned
// scheduler checkpoints:
//
//   complianceApprovalInvalidationCheckpoint/{documentId}   (Slice 6 sweep)
//   complianceRecomputeSweepCheckpoint/{documentId}         (Slice 4.7 sweep)
//
// Both hold a sweep continuation cursor. Whoever can write one controls which
// products get re-checked for revoked or expired evidence, and whoever can
// read one learns the shape of the review pipeline. Neither is any client's
// business — admin included.
//
// These documents were already unreachable via Firestore's default deny, so
// the behavioural assertions below would pass even with the blocks removed.
// That is exactly why this file also asserts the blocks EXIST in the Rules
// source: the behaviour proves the collections are closed, and the source
// assertions prove they are closed ON PURPOSE rather than by the accident of
// no rule matching them. The non-vacuity check removes the blocks and
// confirms the source assertions fail.

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const {
  assertFails,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, deleteDoc } = require("firebase/firestore");

const rules = fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8");

// Comment-stripped view: an assertion that a BLOCK exists must read only
// what the Rules engine evaluates, never prose that mentions the name.
const rulesCode = rules
  .replace(/\/\*[\s\S]*?\*\//g, "")
  .replace(/^[ \t]*\/\/.*$/gm, "");

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
let testEnv;
function rulesTest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

async function env() {
  if (testEnv) return testEnv;
  testEnv = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || `checkpoint-rules-${Date.now()}`,
    firestore: { rules },
  });
  return testEnv;
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

const CHECKPOINT_COLLECTIONS = [
  "complianceApprovalInvalidationCheckpoint",
  "complianceRecomputeSweepCheckpoint",
];

// Deliberately similar names that must NOT be covered by the new blocks —
// a decoy proves the match paths are exact rather than prefix-like.
const DECOY_COLLECTIONS = [
  "complianceApprovalInvalidationCheckpointArchive",
  "complianceRecomputeSweepCheckpoints",
];

const ADMIN_UID = "checkpoint-admin-1";
const SELLER_UID = "checkpoint-seller-1";
const CUSTOMER_UID = "checkpoint-customer-1";
const BUSINESS_ID = "checkpoint-biz-1";

async function resetSeed() {
  const rulesEnv = await env();
  await rulesEnv.clearFirestore();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", ADMIN_UID), { role: "admin" });
    await setDoc(doc(db, "users", SELLER_UID), { role: "user" });
    await setDoc(doc(db, "users", CUSTOMER_UID), { role: "user" });
    await setDoc(doc(db, "businesses", BUSINESS_ID), { ownerUid: SELLER_UID });
    // Both checkpoints exist, exactly as the sweeps write them, so a denial
    // is a real authorization denial and not "the document is absent".
    for (const collection of CHECKPOINT_COLLECTIONS) {
      await setDoc(doc(db, collection, "current"), {
        lastExaminedPath: null,
        updatedAt: new Date(),
      });
    }
    for (const collection of DECOY_COLLECTIONS) {
      await setDoc(doc(db, collection, "current"), { x: 1 });
    }
  });
}

function clientFor(uid) {
  return uid === null
    ? testEnv.unauthenticatedContext().firestore()
    : testEnv.authenticatedContext(uid).firestore();
}

const ACTORS = [
  ["unauthenticated", null],
  ["customer", CUSTOMER_UID],
  ["seller/business owner", SELLER_UID],
  ["admin", ADMIN_UID],
];

// --- behaviour: every actor is denied every operation -------------------

for (const collection of CHECKPOINT_COLLECTIONS) {
  rulesTest(`${collection}: every client actor is denied read`, async () => {
    await resetSeed();
    for (const [label, uid] of ACTORS) {
      await assertFails(
        getDoc(doc(clientFor(uid), collection, "current")),
        `${label} must not read ${collection}`
      );
    }
  });

  rulesTest(`${collection}: every client actor is denied create/update/delete`, async () => {
    await resetSeed();
    for (const [label, uid] of ACTORS) {
      const db = clientFor(uid);
      await assertFails(
        setDoc(doc(db, collection, "forged"), { lastExaminedPath: "businesses/b/products/p" }),
        `${label} must not create in ${collection}`
      );
      await assertFails(
        updateDoc(doc(db, collection, "current"), { lastExaminedPath: null }),
        `${label} must not update ${collection}`
      );
      await assertFails(
        deleteDoc(doc(db, collection, "current")),
        `${label} must not delete ${collection}`
      );
    }
  });
}

rulesTest("an admin is denied exactly as a stranger is — no admin read exemption", async () => {
  await resetSeed();
  for (const collection of CHECKPOINT_COLLECTIONS) {
    const adminDb = clientFor(ADMIN_UID);
    const anonDb = clientFor(null);
    await assertFails(getDoc(doc(adminDb, collection, "current")));
    await assertFails(getDoc(doc(anonDb, collection, "current")));
  }
});

// --- source: the blocks exist, are exact, and are unconditional ---------

test("both checkpoint blocks exist exactly once and deny unconditionally", () => {
  for (const collection of CHECKPOINT_COLLECTIONS) {
    const matches =
      rulesCode.match(new RegExp(`match /${collection}/\\{[A-Za-z]+\\} \\{`, "g")) || [];
    assert.equal(matches.length, 1, `exactly one ${collection} block expected`);

    // The match header itself contains `{documentId}`, so the brace scan
    // must begin AFTER the header or it closes on the placeholder.
    const start = rulesCode.indexOf(`match /${collection}/`);
    const headerEnd = rulesCode.indexOf("{", rulesCode.indexOf("}", start));
    const block = rulesCode.slice(start, rulesCode.indexOf("}", headerEnd) + 1);
    // Unconditional: literal false, no OR, no admin branch, no predicate.
    assert.match(block, /allow read, write: if false;/);
    assert.doesNotMatch(block, /isAdmin\(\)/);
    assert.doesNotMatch(block, /isSignedIn\(\)/);
    assert.doesNotMatch(block, /\|\|/);
  }
});

test("the decoy collections are NOT matched by the new blocks", () => {
  for (const decoy of DECOY_COLLECTIONS) {
    assert.equal(
      rulesCode.includes(`match /${decoy}/`),
      false,
      `${decoy} must not have gained a block`
    );
  }
  // And the real blocks are not written as prefix-like wildcards that would
  // swallow a similarly named collection.
  for (const collection of CHECKPOINT_COLLECTIONS) {
    assert.equal(rulesCode.includes(`match /${collection}/{allPaths=**}`), false);
  }
});

test("no other collection's authorization changed shape", () => {
  // The server-only contracts these checkpoints sit beside must still read
  // exactly as they did: this correction adds blocks, it does not edit any.
  for (const [collection, expected] of [
    ["complianceUploadQuotaScopes", "allow read, create, update, delete: if false;"],
    ["complianceUploadQuotaDaily", "allow read, create, update, delete: if false;"],
    ["compliancePolicyRegistry", "allow read, create, update, delete: if false;"],
  ]) {
    const start = rulesCode.indexOf(`match /${collection}/`);
    assert.ok(start > 0, `${collection} block missing`);
    const block = rulesCode.slice(start, start + 220);
    assert.ok(block.includes(expected), `${collection} must be unchanged`);
  }
  // Client writes remain denied across every compliance collection.
  for (const collection of [
    "complianceUploadSessions",
    "complianceDocuments",
    "complianceDocumentScopes",
    "productEvidenceLinks",
    "complianceReviewEvents",
    "productComplianceDecisions",
  ]) {
    const start = rulesCode.indexOf(`match /${collection}/`);
    const block = rulesCode.slice(start, start + 400);
    assert.match(block, /allow create, update, delete: if false;/);
  }
});
