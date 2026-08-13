"use strict";

const ALLOWED_PLANS = new Set(["premium", "gold"]);
const TERM_DAYS = 30;
const {buildSubscriptionCatalog} = require("./subscriptionCatalog");

function normalizePlan(planId) {
  return String(planId || "").trim().toLowerCase();
}

function resolvePlan(planId) {
  const plan = normalizePlan(planId);
  if (!ALLOWED_PLANS.has(plan)) {
    throw new Error("unsupported-plan");
  }
  return plan;
}

function resolveCatalog({ premiumAmount, goldAmount, currency }) {
  const normalizedCurrency = String(currency || "").trim().toUpperCase();
  if (normalizedCurrency !== "TRY") throw new Error("unsupported-currency");
  for (const [planId, rawAmount] of Object.entries({premium: premiumAmount, gold: goldAmount})) {
    if (!Number.isFinite(Number(rawAmount)) || Number(rawAmount) <= 0) {
      throw new Error(`missing-price:${planId}`);
    }
  }
  return buildSubscriptionCatalog({premiumAmount, goldAmount, currency: normalizedCurrency});
}

function isApprovedCallback({ response, procReturnCode, mdStatus, hashValid }) {
  return (
    hashValid === true &&
    String(response || "").trim().toLowerCase() === "approved" &&
    String(procReturnCode || "").trim() === "00" &&
    String(mdStatus || "").trim() === "1"
  );
}

function entitlementWindow({
  now,
  currentPlan,
  currentStatus,
  currentExpiresAt,
  purchasedPlan,
}) {
  const verifiedAt = new Date(now);
  const currentExpiry = currentExpiresAt
    ? new Date(currentExpiresAt)
    : null;
  const extendsCurrent =
    currentPlan === purchasedPlan &&
    currentStatus === "active" &&
    currentExpiry instanceof Date &&
    !Number.isNaN(currentExpiry.getTime()) &&
    currentExpiry.getTime() > verifiedAt.getTime();
  const startsAt = extendsCurrent ? currentExpiry : verifiedAt;
  return {
    startsAt,
    expiresAt: new Date(
      startsAt.getTime() + TERM_DAYS * 24 * 60 * 60 * 1000
    ),
  };
}

module.exports = {
  ALLOWED_PLANS,
  TERM_DAYS,
  entitlementWindow,
  isApprovedCallback,
  resolveCatalog,
  resolvePlan,
};
