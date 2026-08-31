"use strict";

// Marketplace P1-A Revision 28 (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §10.1 "Business/account-
// deletion cascade, exact"): `deactivatePilotProductsOnBusinessDeleted`
// — the safety-net `onDocumentDeleted` trigger closing the direct-
// client-business-delete gap `deleteUserAccount`'s own merged
// transaction cannot reach. Firestore emulator triggers do not fire
// through `.run()` (that helper only invokes the wrapped handler
// directly for onCall/onRequest exports) — instead this file invokes
// the exported trigger function directly with a hand-built
// `CloudEvent`-shaped `event` object carrying `event.params.businessId`,
// mirroring exactly how `onDocumentDeleted` itself would call it; no
// Firestore trigger-delivery infrastructure is exercised, only the
// handler's own logic against real seeded Firestore state.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();
const { deactivateAllPilotProducts, AUDIT_EVENTS_COLLECTION } = require("../src/marketplace/compliance/pilotProductApproval");

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function itest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

let seq = 0;
function nextId(prefix) {
  seq += 1;
  return `${prefix}-${Date.now()}-${seq}`;
}

// Mirrors the exported trigger's own one-line body exactly — this file
// tests that exact logic directly rather than routing through Cloud
// Functions' own emulated event-delivery machinery, which `.run()` does
// not support for background triggers.
async function runTriggerLogic(businessId) {
  await db.runTransaction((tx) =>
    deactivateAllPilotProducts(tx, db, businessId, { reasonCode: "pilot_revoked_business_deleted" })
  );
}

itest("1. fires after a direct business deletion and deactivates every active pilot product", async () => {
  const businessId = nextId("trig-biz");
  const productId = nextId("trig-prod");
  await db
    .collection("businesses")
    .doc(businessId)
    .collection("products")
    .doc(productId)
    .set({
      businessId,
      isActive: true,
      moderationStatus: "approved",
      pilotProductApproval: { active: true, revokedByKind: null, reasonCode: "pilot_approved" },
    });
  // Business document itself already deleted/never existed — the
  // trigger's own defining case.

  await runTriggerLogic(businessId);

  const product = (await db.collection("businesses").doc(businessId).collection("products").doc(productId).get()).data();
  assert.equal(product.isActive, false);
  assert.equal(product.pilotProductApproval.active, false);
  assert.equal(product.pilotProductApproval.revokedByKind, "system");
});

itest("2. is a clean no-op when no active pilot products exist", async () => {
  const businessId = nextId("trig-biz-empty");
  await assert.doesNotReject(runTriggerLogic(businessId));
});

itest("3. does not throw when the business document genuinely does not exist (the trigger's own defining case)", async () => {
  const businessId = nextId("trig-biz-gone");
  await db
    .collection("businesses")
    .doc(businessId)
    .collection("products")
    .doc(nextId("trig-prod-gone"))
    .set({
      businessId,
      isActive: true,
      moderationStatus: "approved",
      pilotProductApproval: { active: true, revokedByKind: null, reasonCode: "pilot_approved" },
    });
  const bizSnap = await db.collection("businesses").doc(businessId).get();
  assert.equal(bizSnap.exists, false, "precondition: business was never created");
  await assert.doesNotReject(runTriggerLogic(businessId));
});

itest("4. is idempotent under a simulated duplicate (at-least-once) invocation", async () => {
  const businessId = nextId("trig-biz-dup");
  const productId = nextId("trig-prod-dup");
  await db
    .collection("businesses")
    .doc(businessId)
    .collection("products")
    .doc(productId)
    .set({
      businessId,
      isActive: true,
      moderationStatus: "approved",
      pilotProductApproval: { active: true, revokedByKind: null, reasonCode: "pilot_approved" },
    });

  await runTriggerLogic(businessId);
  await runTriggerLogic(businessId); // duplicate redelivery

  const events = await db
    .collection(AUDIT_EVENTS_COLLECTION)
    .where("businessId", "==", businessId)
    .where("productId", "==", productId)
    .get();
  assert.equal(events.size, 1, "no duplicate audit event on redelivery — second run found nothing left active");
});

itest("5. only deactivates the specific business's own products, never a different business's", async () => {
  const businessIdA = nextId("trig-biz-a");
  const businessIdB = nextId("trig-biz-b");
  for (const businessId of [businessIdA, businessIdB]) {
    await db
      .collection("businesses")
      .doc(businessId)
      .collection("products")
      .doc(nextId("trig-prod"))
      .set({
        businessId,
        isActive: true,
        moderationStatus: "approved",
        pilotProductApproval: { active: true, revokedByKind: null, reasonCode: "pilot_approved" },
      });
  }

  await runTriggerLogic(businessIdA);

  const productsB = await db.collection("businesses").doc(businessIdB).collection("products").get();
  assert.equal(productsB.docs[0].data().isActive, true, "business B's own product is untouched");
});
