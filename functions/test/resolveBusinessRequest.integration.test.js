const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test, before } = require("node:test");

if (!admin.apps.length) admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
const db = admin.firestore();
const functions = require("../index");

const adminUid = "publication-test-admin";
let sequence = 0;

before(async () => {
  await db.collection("users").doc(adminUid).set({ role: "admin" });
});

async function resolve({ sectors, published, action = "approved" }) {
  sequence += 1;
  const ownerUid = `publication-test-owner-${sequence}`;
  const businessId = `publication-test-business-${sequence}`;
  const requestId = `publication-test-request-${sequence}`;
  const business = {
    ownerUid,
    status: "pending",
    sectors,
  };
  if (published !== undefined) business.published = published;

  await db.collection("users").doc(ownerUid).set({ role: "user" });
  await db.collection("businesses").doc(businessId).set(business);
  await db.collection("business_requests").doc(requestId).set({
    uid: ownerUid,
    businessId,
  });

  await functions.resolveBusinessRequest.run({
    auth: { uid: adminUid },
    data: { requestId, action },
  });

  return {
    businessRef: db.collection("businesses").doc(businessId),
    requestRef: db.collection("business_requests").doc(requestId),
  };
}

test("resolveBusinessRequest approves legacy public sectors with published true", async () => {
  for (const sectors of [
    ["veterinary"],
    ["groomer"],
    ["pet_hotel"],
    ["pet_shop"],
    ["adoption_center"],
  ]) {
    const { businessRef } = await resolve({ sectors });
    const data = (await businessRef.get()).data();
    assert.equal(data.status, "approved");
    assert.equal(data.published, true);
  }
});

test("resolveBusinessRequest defaults legacy Pet Taxi publication to false", async () => {
  const { businessRef } = await resolve({ sectors: ["pet_taxi"] });
  assert.equal((await businessRef.get()).data().published, false);
});

test("resolveBusinessRequest preserves explicit unpublishing and rejection", async () => {
  const unpublished = await resolve({ sectors: ["veterinary"], published: false });
  assert.equal((await unpublished.businessRef.get()).data().published, false);

  const rejected = await resolve({ sectors: ["veterinary"], action: "rejected" });
  const rejectedData = (await rejected.businessRef.get()).data();
  assert.equal(rejectedData.status, "pending");
  assert.equal(Object.prototype.hasOwnProperty.call(rejectedData, "published"), false);
  assert.equal((await rejected.requestRef.get()).data().status, "rejected");
});

test("repeated approval is idempotent", async () => {
  const first = await resolve({ sectors: ["veterinary"] });
  const requestData = (await first.requestRef.get()).data();
  await functions.resolveBusinessRequest.run({
    auth: { uid: adminUid },
    data: { requestId: first.requestRef.id, action: "approved" },
  });

  const businessData = (await first.businessRef.get()).data();
  assert.equal(businessData.status, "approved");
  assert.equal(businessData.published, true);
  assert.equal(requestData.status, "approved");
});
