"use strict";

const COLLECTIONS = Object.freeze({
  campaigns: "promotion_campaigns",
  plans: "promotion_plans",
  active: "promotion_active",
});

const TARGET_TYPES = Object.freeze(["PET", "PRODUCT", "SERVICE", "BUSINESS"]);
const PRICING_MODELS = Object.freeze({
  fixedDuration: "FIXED_DURATION",
  cpcBudget: "CPC_BUDGET",
  cpa: "CPA",
});
const V1_DURATION_HOURS = Object.freeze([24, 72, 168]);
const CAMPAIGN_STATUSES = Object.freeze([
  "draft",
  "pending_payment",
  "payment_processing",
  "active",
  "expired",
  "cancelled",
  "failed",
  "refunded",
]);

const ALLOWED_TRANSITIONS = Object.freeze({
  draft: Object.freeze(["pending_payment", "cancelled", "failed"]),
  pending_payment: Object.freeze([
    "payment_processing",
    "cancelled",
    "failed",
  ]),
  payment_processing: Object.freeze(["active", "cancelled", "failed"]),
  active: Object.freeze(["expired", "cancelled", "refunded"]),
  expired: Object.freeze([]),
  cancelled: Object.freeze([]),
  failed: Object.freeze([]),
  refunded: Object.freeze([]),
});

function assertString(data, field) {
  if (typeof data[field] !== "string" || data[field].trim() === "") {
    throw new Error(`Promotion plan ${field} must be a non-empty string`);
  }
}

function assertFiniteNumber(data, field, {integer = false, min = 0} = {}) {
  if (typeof data[field] !== "number" || !Number.isFinite(data[field])) {
    throw new Error(`Promotion plan ${field} must be numeric`);
  }
  if (data[field] < min || (integer && !Number.isInteger(data[field]))) {
    throw new Error(`Promotion plan ${field} has an invalid value`);
  }
}

function validatePromotionPlan(data, planId) {
  if (!data || typeof data !== "object") {
    throw new Error("Promotion plan data is required");
  }
  if (typeof planId !== "string" || planId.trim() === "") {
    throw new Error("Promotion plan ID is required");
  }
  assertString(data, "targetType");
  if (!TARGET_TYPES.includes(data.targetType)) {
    throw new Error(`Unsupported promotion target type: ${data.targetType}`);
  }
  assertString(data, "pricingModel");
  if (data.pricingModel !== PRICING_MODELS.fixedDuration) {
    throw new Error("Only FIXED_DURATION plans are enabled in V1");
  }
  assertFiniteNumber(data, "durationHours", {integer: true, min: 1});
  if (!V1_DURATION_HOURS.includes(data.durationHours)) {
    throw new Error("V1 promotion duration is not supported");
  }
  assertFiniteNumber(data, "price", {min: 0});
  assertString(data, "currency");
  assertFiniteNumber(data, "rankingLift", {min: 0});
  if (typeof data.enabled !== "boolean") {
    throw new Error("Promotion plan enabled must be boolean");
  }
  if (data.targetType === "BUSINESS" && data.enabled) {
    throw new Error("BUSINESS promotion plans are disabled in V1");
  }
  assertFiniteNumber(data, "pricingVersion", {integer: true, min: 1});
  assertFiniteNumber(data, "displayOrder", {integer: true, min: 0});
  assertFiniteNumber(data, "maxConcurrentPerOwner", {integer: true, min: 1});
  assertFiniteNumber(data, "maxConcurrentPerBusiness", {integer: true, min: 1});
  return true;
}

function assertCampaignTransition(fromStatus, toStatus) {
  if (!CAMPAIGN_STATUSES.includes(fromStatus) || !CAMPAIGN_STATUSES.includes(toStatus)) {
    throw new Error("Unknown promotion campaign status");
  }
  if (!(ALLOWED_TRANSITIONS[fromStatus] || []).includes(toStatus)) {
    throw new Error(`Invalid promotion transition: ${fromStatus} -> ${toStatus}`);
  }
  return true;
}

function isPromotionEligibleAt({status, startsAt, expiresAt, now}) {
  if (status !== "active" || !startsAt || !expiresAt || !now) return false;
  return now >= startsAt && now < expiresAt;
}

async function resolvePromotionPlan(db, planId, targetType) {
  const snapshot = await db.collection(COLLECTIONS.plans).doc(planId).get();
  if (!snapshot.exists) throw new Error("Promotion plan not found");
  const data = snapshot.data();
  validatePromotionPlan(data, planId);
  if (data.targetType !== targetType) {
    throw new Error("Promotion plan target type does not match target");
  }
  if (!data.enabled) throw new Error("Promotion plan is disabled");
  return {planId, ...data};
}

module.exports = {
  COLLECTIONS,
  TARGET_TYPES,
  PRICING_MODELS,
  V1_DURATION_HOURS,
  CAMPAIGN_STATUSES,
  ALLOWED_TRANSITIONS,
  validatePromotionPlan,
  assertCampaignTransition,
  isPromotionEligibleAt,
  resolvePromotionPlan,
};
