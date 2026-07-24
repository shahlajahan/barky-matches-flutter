"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  entitlementWindow,
  isApprovedCallback,
  resolveCatalog,
  resolvePlan,
} = require("../subscription/webSubscriptionCore");

test("rejects invalid plan IDs", () => {
  assert.throws(() => resolvePlan("business"), /unsupported-plan/);
  assert.equal(resolvePlan("premium"), "premium");
  assert.equal(resolvePlan("gold"), "gold");
});

test("uses only server-provided TRY catalog prices", () => {
  const catalog = resolveCatalog({
    premiumAmount: "199.00",
    goldAmount: "499.00",
    currency: "TRY",
  });
  assert.deepEqual(catalog.premium, {
    amount: 199,
    currency: "TRY",
    durationDays: 30,
  });
  assert.deepEqual(catalog.gold, {
    amount: 499,
    currency: "TRY",
    durationDays: 30,
  });
  assert.throws(
    () =>
      resolveCatalog({
        premiumAmount: "",
        goldAmount: "399",
        currency: "TRY",
      }),
    /missing-price:premium/
  );
  assert.throws(
    () =>
      resolveCatalog({
        premiumAmount: "199",
        goldAmount: "399",
        currency: "USD",
      }),
    /unsupported-currency/
  );
});

test("requires hash and every approved callback field", () => {
  const valid = {
    response: "Approved",
    procReturnCode: "00",
    mdStatus: "1",
    hashValid: true,
  };
  assert.equal(isApprovedCallback(valid), true);
  for (const change of [
    { hashValid: false },
    { response: "Declined" },
    { procReturnCode: "05" },
    { mdStatus: "0" },
  ]) {
    assert.equal(isApprovedCallback({ ...valid, ...change }), false);
  }
});

test("same active plan extends once from current expiration", () => {
  const result = entitlementWindow({
    now: "2026-07-24T00:00:00.000Z",
    currentPlan: "premium",
    currentStatus: "active",
    currentExpiresAt: "2026-08-01T00:00:00.000Z",
    purchasedPlan: "premium",
  });
  assert.equal(result.startsAt.toISOString(), "2026-08-01T00:00:00.000Z");
  assert.equal(result.expiresAt.toISOString(), "2026-08-31T00:00:00.000Z");
});

test("switching plan grants 30 days from verified time", () => {
  const result = entitlementWindow({
    now: "2026-07-24T00:00:00.000Z",
    currentPlan: "premium",
    currentStatus: "active",
    currentExpiresAt: "2026-08-01T00:00:00.000Z",
    purchasedPlan: "gold",
  });
  assert.equal(result.startsAt.toISOString(), "2026-07-24T00:00:00.000Z");
  assert.equal(result.expiresAt.toISOString(), "2026-08-23T00:00:00.000Z");
});
