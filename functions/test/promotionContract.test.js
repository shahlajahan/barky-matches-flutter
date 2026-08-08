"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  ALLOWED_TRANSITIONS,
  assertCampaignTransition,
  isPromotionEligibleAt,
  validatePromotionPlan,
} = require("../src/promotion/promotion_contract");

function plan(overrides = {}) {
  return {
    targetType: "PRODUCT",
    pricingModel: "FIXED_DURATION",
    durationHours: 168,
    price: 169,
    currency: "TRY",
    rankingLift: 20,
    enabled: true,
    pricingVersion: 1,
    displayOrder: 3,
    maxConcurrentPerOwner: 3,
    maxConcurrentPerBusiness: 5,
    ...overrides,
  };
}

test("V1 promotion plan validation accepts a versioned fixed-duration plan", () => {
  assert.equal(validatePromotionPlan(plan(), "product_7d_v1"), true);
});

test("V1 rejects customer-enabled Business plans and future pricing models", () => {
  assert.throws(
    () => validatePromotionPlan(plan({targetType: "BUSINESS"}), "business_7d_v1"),
    /BUSINESS promotion plans are disabled/
  );
  assert.throws(
    () => validatePromotionPlan(plan({pricingModel: "CPC_BUDGET"}), "product_cpc"),
    /Only FIXED_DURATION/
  );
});

test("campaign transition contract is explicit and terminal states cannot reopen", () => {
  assert.equal(assertCampaignTransition("draft", "pending_payment"), true);
  assert.equal(assertCampaignTransition("payment_processing", "active"), true);
  assert.throws(() => assertCampaignTransition("active", "draft"), /Invalid promotion transition/);
  assert.deepEqual(ALLOWED_TRANSITIONS.expired, []);
});

test("promotion eligibility requires active status and a non-expired interval", () => {
  const startsAt = new Date("2026-08-08T10:00:00.000Z");
  const expiresAt = new Date("2026-08-08T11:00:00.000Z");
  assert.equal(isPromotionEligibleAt({
    status: "active", startsAt, expiresAt,
    now: new Date("2026-08-08T10:30:00.000Z"),
  }), true);
  assert.equal(isPromotionEligibleAt({
    status: "active", startsAt, expiresAt,
    now: new Date("2026-08-08T11:00:00.000Z"),
  }), false);
  assert.equal(isPromotionEligibleAt({
    status: "expired", startsAt, expiresAt,
    now: new Date("2026-08-08T10:30:00.000Z"),
  }), false);
});
