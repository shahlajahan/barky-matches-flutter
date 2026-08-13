"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {repairOne} = require("../scripts/repairSubscriptionEntitlements");

test("apply mode persists normalized subscription and user entitlements", async () => {
  const uid = "repair-user";
  const subscription = {
    userId: uid,
    plan: "gold",
    status: "active",
    price: 19.99,
    expiresAt: new Date(Date.now() + 86400000),
  };
  const user = {isPremium: false, email: "repair@example.com"};
  const writes = [];
  const refs = new Map();
  const refFor = (path) => {
    if (!refs.has(path)) refs.set(path, {
      async get() {
        return {exists: true, data: () => path.includes("subscriptions") ? subscription : user};
      },
    });
    return refs.get(path);
  };
  const db = {
    collection(name) {
      return {doc: (id) => refFor(`${name}/${id}`)};
    },
    async runTransaction(callback) {
      await callback({
        set(ref, data, options) {
          writes.push({ref, data, options});
        },
      });
    },
  };

  await repairOne(db, uid, true, true);

  const subscriptionWrite = writes.find(({ref}) => ref === refs.get(`subscriptions/${uid}`));
  const userWrite = writes.find(({ref}) => ref === refs.get(`users/${uid}`));
  assert.equal(subscriptionWrite.data.plan, "gold");
  assert.equal(subscriptionWrite.data.status, "active");
  assert.equal(subscriptionWrite.data.price, 9.99);
  assert.equal(subscriptionWrite.data.currency, "USD");
  assert.equal(subscriptionWrite.data.source, "admin_grant");
  assert.equal(subscriptionWrite.data.paidAmount, null);
  assert.equal(userWrite.data.isPremium, true);
  assert.equal(userWrite.data.subscriptionPlan, "gold");
  assert.equal(userWrite.data.subscriptionStatus, "active");
  assert.equal(userWrite.data.subscription.plan, "gold");
  assert.equal(userWrite.data.subscription.status, "active");
  assert.equal(userWrite.data.email, undefined);
});
