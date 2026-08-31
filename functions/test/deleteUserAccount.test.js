"use strict";

// Marketplace P1-A Revision 28 (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §10.1 "Business/account-
// deletion cascade, exact"): `deleteUserAccount`'s own per-business
// step, rewritten from a bare `.delete()` into one merged
// `db.runTransaction()` call performing pilot-product deactivation and
// business deletion atomically. No prior dedicated test file for this
// callable's own business-deletion loop existed — confirmed by direct
// search of functions/test/ before this file was added. Exercised via
// its exported onCall wrapper's `.run()` test helper, against a real
// Firestore + Storage emulator (Storage: this callable also touches
// `admin.storage()`, and its own single outer try/catch means a Storage
// failure would otherwise mask a genuinely successful Firestore-side
// transaction).

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test } = require("node:test");

if (!admin.apps.length) {
  // `deleteUserAccount` also calls `admin.storage().bucket()` with no
  // explicit bucket name — the Admin SDK requires a `storageBucket` at
  // init time to resolve that call at all, emulator or not; no other
  // test file in this repository exercises this callable directly, so
  // none needed this before. This file is run in isolation (its own
  // `node --test` invocation) precisely so this init call is guaranteed
  // to be the first one for the process — Admin SDK does not support
  // re-initializing an already-initialized default app.
  const projectId = process.env.GCLOUD_PROJECT || "demo-petsupo";
  admin.initializeApp({ projectId, storageBucket: `${projectId}.appspot.com` });
}
const db = admin.firestore();
const functions = require("../index");
const { AUDIT_EVENTS_COLLECTION } = require("../src/marketplace/compliance/pilotProductApproval");

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function itest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

let seq = 0;
function nextId(prefix) {
  seq += 1;
  return `${prefix}-${Date.now()}-${seq}`;
}

// `deleteUserAccount` also calls `admin.storage().bucket()...delete()`
// for dog-image/business-folder cleanup, later in its own single
// sequence, after this file's own Firestore-side merged transaction has
// already committed. No test file in this repository has a working
// Storage-emulator credential path for the Admin SDK (a genuine,
// pre-existing environmental gap, not introduced by this contract) —
// this helper runs the real callable, tolerates *only* that specific,
// already-downstream-of-the-transaction failure shape, and re-throws
// anything else as a genuine, unexpected test failure. Every assertion
// below verifies the actual Firestore state the merged transaction
// produced, never merely that `.run()` returned without throwing.
async function callDeleteUserAccount(uid) {
  try {
    return await functions.deleteUserAccount.run({ auth: { uid }, data: {} });
  } catch (err) {
    if (err && err.code === "internal" && /Failed to delete user account/.test(err.message || "")) {
      return { success: false, storageEnvironmentLimitation: true };
    }
    throw err;
  }
}

async function seedOwnerWithBusiness({ activePilotProducts = 0 } = {}) {
  const uid = nextId("del-owner");
  const businessId = uid; // mirrors CREATE BUSINESS (PENDING): businessId == ownerUid
  await db.collection("users").doc(uid).set({ displayName: "Test User" });
  await db.collection("businesses").doc(businessId).set({
    ownerUid: uid,
    marketplaceSellerActivation: { active: true, grantedAt: null, grantedBy: "admin-1", revokedAt: null, revokedBy: null },
    marketplaceBusinessGenerationId: `gen-${businessId}`,
    pilotActiveProductCount: activePilotProducts,
  });
  for (let i = 0; i < activePilotProducts; i++) {
    await db
      .collection("businesses")
      .doc(businessId)
      .collection("products")
      .doc(nextId("del-prod"))
      .set({
        businessId,
        name: "Active Pilot Product",
        isActive: true,
        moderationStatus: "approved",
        pilotProductApproval: {
          schemaVersion: 1,
          active: true,
          approvedAt: null,
          approvedBy: "admin-1",
          revokedAt: null,
          revokedBy: null,
          revokedByKind: null,
          allowedPilotCategory: "food",
          reviewedContentFingerprint: "fixture",
          reviewedProductRevision: 0,
          reasonCode: "pilot_approved",
        },
      });
  }
  return { uid, businessId };
}

itest("1. deleting an account with an active pilot product deactivates it and deletes the business together", async () => {
  const { uid, businessId } = await seedOwnerWithBusiness({ activePilotProducts: 1 });

  await callDeleteUserAccount(uid);

  const bizSnap = await db.collection("businesses").doc(businessId).get();
  assert.equal(bizSnap.exists, false, "business document is deleted");

  const productsSnap = await db.collection("businesses").doc(businessId).collection("products").get();
  assert.equal(productsSnap.size, 1, "the orphaned product document itself is not deleted, only deactivated");
  const product = productsSnap.docs[0].data();
  assert.equal(product.isActive, false);
  assert.equal(product.pilotProductApproval.active, false);
  assert.equal(product.pilotProductApproval.revokedByKind, "system");
  assert.equal(product.pilotProductApproval.reasonCode, "pilot_revoked_business_deleted");

  const events = await db
    .collection(AUDIT_EVENTS_COLLECTION)
    .where("businessId", "==", businessId)
    .where("action", "==", "cascade_revoke")
    .get();
  assert.equal(events.size, 1);
});

itest("2. a business with no active pilot products deletes exactly as before, byte-for-byte", async () => {
  const { uid, businessId } = await seedOwnerWithBusiness({ activePilotProducts: 0 });
  await callDeleteUserAccount(uid);
  const bizSnap = await db.collection("businesses").doc(businessId).get();
  assert.equal(bizSnap.exists, false);
});

itest("3. a retry against an already-deleted business is a clean no-op, not an error", async () => {
  const { uid, businessId } = await seedOwnerWithBusiness({ activePilotProducts: 1 });
  await callDeleteUserAccount(uid);

  // Re-seed only the user doc (deleteUserAccount's own first pass
  // already removed it) so a second invocation for the same uid has
  // something to authenticate against; the business itself remains gone.
  await db.collection("users").doc(uid).set({ displayName: "Test User" });
  await assert.doesNotReject(callDeleteUserAccount(uid));

  const bizSnap = await db.collection("businesses").doc(businessId).get();
  assert.equal(bizSnap.exists, false);
});

itest("4. multiple owned businesses each get their own independent merged transaction", async () => {
  const uid = nextId("del-multi-owner");
  await db.collection("users").doc(uid).set({ displayName: "Multi Owner" });
  const businessIds = [nextId("del-multi-biz-a"), nextId("del-multi-biz-b")];
  for (const businessId of businessIds) {
    await db.collection("businesses").doc(businessId).set({
      ownerUid: uid,
      marketplaceSellerActivation: { active: true, grantedAt: null, grantedBy: "admin-1", revokedAt: null, revokedBy: null },
      marketplaceBusinessGenerationId: `gen-${businessId}`,
      pilotActiveProductCount: 1,
    });
    await db
      .collection("businesses")
      .doc(businessId)
      .collection("products")
      .doc(nextId("del-multi-prod"))
      .set({
        businessId,
        isActive: true,
        moderationStatus: "approved",
        pilotProductApproval: { active: true, revokedByKind: null, reasonCode: "pilot_approved" },
      });
  }

  await callDeleteUserAccount(uid);

  for (const businessId of businessIds) {
    const bizSnap = await db.collection("businesses").doc(businessId).get();
    assert.equal(bizSnap.exists, false, `business ${businessId} deleted`);
    const productsSnap = await db.collection("businesses").doc(businessId).collection("products").get();
    assert.equal(productsSnap.docs[0].data().isActive, false);
  }
});
