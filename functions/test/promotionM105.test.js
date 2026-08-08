"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  buildPromotionPlans,
  validatePromotionPlans,
} = require("../scripts/provisionPromotionPlans");

test("M10.5 provisioning defines deterministic V1 prices and keeps BUSINESS disabled", () => {
  const plans = buildPromotionPlans();
  validatePromotionPlans(plans);
  const enabled = plans.filter((plan) => plan.enabled);
  assert.deepEqual(enabled.map((plan) => plan.price), [29, 69, 129, 39, 89, 169, 49, 119, 219]);
  assert.equal(plans.filter((plan) => plan.targetType === "BUSINESS" && plan.enabled).length, 0);
  assert.equal(new Set(plans.map((plan) => plan.planId)).size, plans.length);
  assert.ok(plans.every((plan) => plan.currency === "TRY" && plan.pricingVersion === 1));
});

test("M10.5 provisioning rejects accidental BUSINESS enablement", () => {
  assert.throws(() => validatePromotionPlans([
    {...buildPromotionPlans()[0], planId: "business_bad", targetType: "BUSINESS", enabled: true},
  ]), /BUSINESS/);
});
