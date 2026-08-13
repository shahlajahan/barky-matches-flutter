"use strict";

const assert = require("node:assert/strict");
const {test} = require("node:test");
const functions = require("../index");

test("mobile activation rejects the old client-controlled entitlement contract", async () => {
  await assert.rejects(
    functions.activateSubscription.run({
      auth: {uid: "mobile-iap-test-user"},
      data: {plan: "gold", productId: "fake-client-product"},
    }),
    (error) => {
      assert.equal(error.code, "failed-precondition");
      return true;
    }
  );
});

test("mobile activation fails closed without authentication as well", async () => {
  await assert.rejects(
    functions.activateSubscription.run({
      auth: null,
      data: {plan: "gold", productId: "fake-client-product"},
    }),
    (error) => {
      assert.equal(error.code, "unauthenticated");
      return true;
    }
  );
});
