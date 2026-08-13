"use strict";

const assert = require("node:assert/strict");
const crypto = require("crypto");
const admin = require("firebase-admin");
const {before, test} = require("node:test");
const {expireSubscriptionCandidate} = require("../src/expireSubscriptions");

if (!admin.apps.length) {
  admin.initializeApp({projectId: process.env.GCLOUD_PROJECT || "demo-petsupo"});
}

const db = admin.firestore();
const runId = `${Date.now()}-${process.pid}-${crypto.randomBytes(4).toString("hex")}`;
let sequence = 0;

before(() => {
  assert.match(
    process.env.FIRESTORE_EMULATOR_HOST || "",
    /^(127\.0\.0\.1|localhost):\d+$/,
    "expiry integration tests require a local Firestore emulator"
  );
});

function item() {
  sequence += 1;
  const uid = `expire-subscription-${runId}-${sequence}`;
  return {
    uid,
    subscriptionRef: db.collection("subscriptions").doc(uid),
    userRef: db.collection("users").doc(uid),
  };
}

async function seed({subscriptionRef, userRef, subscription, user = {}}) {
  await Promise.all([
    subscriptionRef.set(subscription),
    userRef.set(user),
  ]);
}

function activeSubscription(expiresAt) {
  return {
    userId: "placeholder",
    plan: "gold",
    status: "active",
    source: "admin_grant",
    price: 9.99,
    currency: "USD",
    expiresAt,
  };
}

test("normally expired active subscriptions expire and update entitlement projection", async () => {
  const target = item();
  const now = new Date("2026-08-12T12:00:00.000Z");
  await seed({
    ...target,
    subscription: activeSubscription(admin.firestore.Timestamp.fromDate(new Date("2026-08-12T11:59:00.000Z"))),
    user: {isPremium: true, subscriptionStatus: "active"},
  });

  assert.equal(await expireSubscriptionCandidate({db, subscriptionRef: target.subscriptionRef, now}), true);
  const subscription = (await target.subscriptionRef.get()).data();
  const user = (await target.userRef.get()).data();
  assert.equal(subscription.status, "expired");
  assert.equal(user.isPremium, false);
  assert.equal(user.subscriptionStatus, "expired");
  assert.equal(user.subscription.status, "expired");
});

test("fresh renewal after the stale candidate query is preserved", async () => {
  const target = item();
  const now = new Date("2026-08-12T12:00:00.000Z");
  await seed({
    ...target,
    subscription: activeSubscription(admin.firestore.Timestamp.fromDate(new Date("2026-08-12T11:00:00.000Z"))),
    user: {isPremium: true, subscriptionStatus: "active"},
  });

  await target.subscriptionRef.update({
    status: "active",
    expiresAt: admin.firestore.Timestamp.fromDate(new Date("2026-08-20T12:00:00.000Z")),
  });
  assert.equal(await expireSubscriptionCandidate({db, subscriptionRef: target.subscriptionRef, now}), false);

  const subscription = (await target.subscriptionRef.get()).data();
  const user = (await target.userRef.get()).data();
  assert.equal(subscription.status, "active");
  assert.equal(subscription.expiresAt.toDate().toISOString(), "2026-08-20T12:00:00.000Z");
  assert.equal(user.isPremium, true);
  assert.equal(user.subscriptionStatus, "active");
});

test("fresh status changes are not overwritten by expiration", async () => {
  const target = item();
  const now = new Date("2026-08-12T12:00:00.000Z");
  await seed({
    ...target,
    subscription: activeSubscription(admin.firestore.Timestamp.fromDate(new Date("2026-08-12T11:00:00.000Z"))),
    user: {isPremium: true, subscriptionStatus: "active"},
  });

  await target.subscriptionRef.update({status: "canceled"});
  assert.equal(await expireSubscriptionCandidate({db, subscriptionRef: target.subscriptionRef, now}), false);
  assert.equal((await target.subscriptionRef.get()).data().status, "canceled");
  assert.equal((await target.userRef.get()).data().subscriptionStatus, "active");
});

test("newer valid entitlement remains intact when an expired candidate is skipped", async () => {
  const target = item();
  const now = new Date("2026-08-12T12:00:00.000Z");
  await seed({
    ...target,
    subscription: {
      ...activeSubscription(admin.firestore.Timestamp.fromDate(new Date("2026-08-20T12:00:00.000Z"))),
      plan: "premium",
    },
    user: {
      isPremium: true,
      subscriptionPlan: "premium",
      subscriptionStatus: "active",
      subscription: {plan: "premium", status: "active", expiresAt: "2026-08-20T12:00:00.000Z"},
    },
  });

  assert.equal(await expireSubscriptionCandidate({db, subscriptionRef: target.subscriptionRef, now}), false);
  const user = (await target.userRef.get()).data();
  assert.equal(user.isPremium, true);
  assert.equal(user.subscriptionPlan, "premium");
  assert.equal(user.subscriptionStatus, "active");
});

test("expiration is strictly before now; an equal boundary remains active", async () => {
  const target = item();
  const now = new Date("2026-08-12T12:00:00.000Z");
  await seed({
    ...target,
    subscription: activeSubscription(admin.firestore.Timestamp.fromDate(now)),
    user: {isPremium: true, subscriptionStatus: "active"},
  });

  assert.equal(await expireSubscriptionCandidate({db, subscriptionRef: target.subscriptionRef, now}), false);
  assert.equal((await target.subscriptionRef.get()).data().status, "active");
});
