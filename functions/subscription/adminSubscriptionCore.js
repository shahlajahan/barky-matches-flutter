"use strict";

const {ADMIN_SUBSCRIPTION_CATALOG} = require("./subscriptionCatalog");

function normalizeStatus(status) {
  return String(status || "active").toLowerCase() === "cancelled"
    ? "canceled"
    : String(status || "active").toLowerCase();
}

function catalogEntry(plan) {
  const entry = ADMIN_SUBSCRIPTION_CATALOG[String(plan || "").toLowerCase()];
  if (!entry) throw new Error("unsupported-plan");
  return entry;
}

function isActivePaid(plan, status) {
  return normalizeStatus(status) === "active" &&
    (plan === "premium" || plan === "gold");
}

function entitlementFields({uid, subscription}) {
  const plan = String(subscription.plan || "normal").toLowerCase();
  const status = normalizeStatus(subscription.status);
  const normalizedSubscription = {...subscription, plan, status, userId: uid};
  return {
    isPremium: isActivePaid(plan, status),
    subscriptionPlan: plan,
    subscriptionStatus: status,
    subscription: normalizedSubscription,
  };
}

function buildAdminGrant({uid, plan, current, now, expiresAt}) {
  const pricing = catalogEntry(plan);
  const currentData = current || {};
  const timestamp = now || new Date();
  const historicalPayment = currentData.source && currentData.source !== "admin_grant" &&
    currentData.source !== "free" &&
    (currentData.paidAmount != null || currentData.lastPaymentOrderId != null)
    ? {
      amount: currentData.paidAmount ?? currentData.price ?? null,
      currency: currentData.currency ?? null,
      source: currentData.source,
      orderId: currentData.lastPaymentOrderId ?? null,
    }
    : null;
  const end = expiresAt || new Date(
    timestamp.getTime() + pricing.durationDays * 24 * 60 * 60 * 1000
  );
  return {
    ...currentData,
    userId: uid,
    plan,
    status: "active",
    source: "admin_grant",
    price: pricing.amount,
    currency: pricing.currency,
    listPrice: pricing.amount,
    listPriceCurrency: pricing.currency,
    paidAmount: null,
    ...(historicalPayment ? {previousPayment: historicalPayment} : {}),
    startedAt: timestamp,
    expiresAt: end,
    autoRenew: false,
  };
}

function applyAdminAction({uid, action, current = {}, now = new Date()}) {
  const normalizedAction = String(action || "").toLowerCase();
  const currentPlan = String(current.plan || "normal").toLowerCase();
  const currentStatus = normalizeStatus(current.status);
  if (normalizedAction === "grant_gold" || normalizedAction === "grant_premium") {
    const plan = normalizedAction === "grant_gold" ? "gold" : "premium";
    if (currentPlan === plan && currentStatus === "active" && current.source === "admin_grant") {
      return {...current, userId: uid, plan, status: "active"};
    }
    return buildAdminGrant({uid, plan, current, now});
  }
  if (normalizedAction === "downgrade_to_premium") {
    return buildAdminGrant({uid, plan: "premium", current, now});
  }
  if (normalizedAction === "cancel" || normalizedAction === "expire") {
    return {
      ...current,
      userId: uid,
      plan: currentPlan,
      status: normalizedAction === "cancel" ? "canceled" : "expired",
    };
  }
  if (normalizedAction === "extend") {
    if (currentPlan === "normal") return {...current, userId: uid, plan: "normal", status: "active"};
    const pricing = catalogEntry(currentPlan);
    const existingExpiry = current.expiresAt?.toDate?.() ||
      (current.expiresAt instanceof Date ? current.expiresAt : null);
    const startsAt = existingExpiry && existingExpiry > now ? existingExpiry : now;
    return {
      ...current,
      userId: uid,
      plan: currentPlan,
      status: currentStatus,
      expiresAt: new Date(startsAt.getTime() + pricing.durationDays * 24 * 60 * 60 * 1000),
    };
  }
  throw new Error("unsupported-action");
}

function normalizeKnownAdminGrant({uid, current = {}}) {
  const pricing = catalogEntry("gold");
  return {
    ...current,
    userId: uid,
    source: "admin_grant",
    price: pricing.amount,
    currency: pricing.currency,
    listPrice: pricing.amount,
    listPriceCurrency: pricing.currency,
    paidAmount: null,
  };
}

module.exports = {
  ADMIN_SUBSCRIPTION_CATALOG,
  applyAdminAction,
  buildAdminGrant,
  catalogEntry,
  entitlementFields,
  normalizeKnownAdminGrant,
  normalizeStatus,
};
