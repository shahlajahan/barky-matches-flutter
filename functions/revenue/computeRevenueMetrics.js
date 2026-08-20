"use strict";

const admin = require("firebase-admin");

const TIMEZONE = "Europe/Istanbul";
const SCHEMA_VERSION = 2;
const PAID_PLANS = new Set(["premium", "gold", "business"]);
const PAID_STATUSES = new Set(["active", "grace_period", "canceled"]);
const SUCCESS_PAYMENT_STATUSES = new Set(["paid", "completed", "verified_success", "success", "succeeded"]);
const PENDING_PAYMENT_STATUSES = new Set([
  "pending",
  "created",
  "initiated",
  "processing",
  "awaiting_payment",
  "awaiting_user_payment",
  "payment_processing",
  "authorization_pending",
]);
const FAILED_PAYMENT_STATUSES = new Set([
  "failed",
  "declined",
  "cancelled",
  "canceled",
  "payment_failed",
  "verification_failed",
  "invalid",
  "expired",
  "payment_expired",
]);
const REFUND_STATUSES = new Set([
  "refunded",
  "partially_refunded",
  "partial_refund",
  "reversed",
  "chargeback",
  "voided",
]);
const ISO4217_NUMERIC = Object.freeze({
  "949": "TRY",
  "840": "USD",
  "978": "EUR",
});

function normalizeStatus(value) {
  const status = String(value || "").trim().toLowerCase();
  return status === "cancelled" ? "canceled" : status;
}

function normalizeCurrency(value) {
  const raw = String(value || "").trim().toUpperCase();
  const currency = ISO4217_NUMERIC[raw] || raw;
  return /^[A-Z]{3}$/.test(currency) ? currency : null;
}

function toDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return Number.isFinite(value.getTime()) ? value : null;
  if (typeof value === "number" || typeof value === "string") {
    const date = new Date(value);
    return Number.isFinite(date.getTime()) ? date : null;
  }
  return null;
}

function toMinorUnits(value) {
  if (value == null || value === "") return null;
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) return null;
  return Math.round(number * 100);
}

function startOfIstanbulMonth(now = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: TIMEZONE,
    year: "numeric",
    month: "2-digit",
  }).formatToParts(now);
  const year = Number(parts.find((part) => part.type === "year")?.value);
  const month = Number(parts.find((part) => part.type === "month")?.value);
  // Türkiye has been UTC+03 year-round for the supported production period.
  return new Date(Date.UTC(year, month - 1, 1, 0, 0, 0) - 3 * 60 * 60 * 1000);
}

function emptyCurrencyBucket(currency) {
  return {
    currency,
    grossMinor: 0,
    refundMinor: 0,
    netMinor: 0,
    monthlyNetMinor: 0,
    pendingMinor: 0,
    arppuMinor: 0,
  };
}

function ensureCurrency(byCurrency, currency) {
  if (!byCurrency[currency]) byCurrency[currency] = emptyCurrencyBucket(currency);
  return byCurrency[currency];
}

function paymentIdentityForOrder(orderId, order = {}) {
  const provider = String(
    order.payment?.provider ||
      order.payment?.paymentProvider ||
      order.paymentProvider ||
      "unknown"
  ).trim().toLowerCase();
  const paymentId = String(
    order.payment?.paymentId ||
      order.payment?.providerPaymentId ||
      order.payment?.transactionId ||
      order.payment?.TransId ||
      order.payment?.transId ||
      order.providerPaymentId ||
      order.paymentId ||
      ""
  ).trim();
  if (provider && paymentId) return `${provider}:${paymentId}`;
  if (orderId) return `order:${orderId}`;
  return null;
}

function classifyPaymentStatus(order = {}) {
  const paymentStatus = normalizeStatus(order.paymentStatus || order.payment?.status);
  const orderStatus = normalizeStatus(order.status);
  const providerState = normalizeStatus(
    order.providerPaymentState || order.providerPaymentStatus || order.payment?.finalizationStatus
  );

  if (
    SUCCESS_PAYMENT_STATUSES.has(paymentStatus) ||
    (SUCCESS_PAYMENT_STATUSES.has(orderStatus) && order.payment?.callbackValidated === true) ||
    (paymentStatus === "paid" && order.payment?.finalizationStatus === "completed") ||
    (providerState === "completed" && paymentStatus === "paid")
  ) {
    return "successful";
  }
  if (PENDING_PAYMENT_STATUSES.has(paymentStatus) || PENDING_PAYMENT_STATUSES.has(orderStatus)) {
    return "pending";
  }
  if (FAILED_PAYMENT_STATUSES.has(paymentStatus) || FAILED_PAYMENT_STATUSES.has(orderStatus)) {
    return "failed";
  }
  return "unverified";
}

function amountAndCurrencyForOrder(order = {}) {
  const amount =
    order.payment?.amount ??
    order.payment?.paidPrice ??
    order.pricing?.paidAmount ??
    order.pricing?.grandTotal ??
    order.paidAmount ??
    order.grandTotal;
  const currency = normalizeCurrency(
    order.payment?.currency || order.pricing?.currency || order.paymentCurrency || order.currency
  );
  return { amountMinor: toMinorUnits(amount), currency };
}

function refundMinorForOrder(order = {}) {
  return (
    toMinorUnits(order.refundAmount) ||
    toMinorUnits(order.refundedAmount) ||
    toMinorUnits(order.payment?.refundAmount) ||
    0
  );
}

function ownerKeyForOrder(order = {}) {
  return String(
    order.buyerUid ||
      order.userId ||
      order.uid ||
      order.businessId ||
      order.sellerId ||
      ""
  ).trim();
}

function classifyOrderPayment(orderId, order = {}, { now = new Date() } = {}) {
  const source = order.orderType === "web_subscription" ? "web_subscription" : "unsupported_order";
  const status = classifyPaymentStatus(order);
  const { amountMinor, currency } = amountAndCurrencyForOrder(order);
  const identity = paymentIdentityForOrder(orderId, order);
  const occurredAt = toDate(order.paidAt || order.payment?.finalizedAt || order.payment?.paidAt || order.createdAt);
  const monthStart = startOfIstanbulMonth(now);
  const refundMinor = refundMinorForOrder(order);
  const ownerKey = ownerKeyForOrder(order);
  const plan = String(order.planId || order.payment?.planId || "").trim().toLowerCase();
  const refundStatus = normalizeStatus(order.refundStatus || order.payment?.refundStatus || order.status);
  const hasRefundOrReversal = REFUND_STATUSES.has(refundStatus);
  const issues = [];

  if (source !== "web_subscription") issues.push("unsupported_order_type");
  if (!identity) issues.push("missing_payment_identity");
  if (!currency) issues.push("missing_currency");
  if (amountMinor == null && status !== "failed") issues.push("missing_positive_paid_amount");
  if (status === "successful" && order.payment?.callbackValidated !== true) {
    issues.push("missing_provider_validation_flag");
  }

  return {
    source,
    status,
    identity,
    amountMinor,
    refundMinor,
    hasRefundOrReversal,
    currency,
    occurredAt,
    inCurrentMonth: Boolean(occurredAt && occurredAt >= monthStart),
    ownerKey,
    plan,
    recognized:
      source === "web_subscription" &&
      status === "successful" &&
      identity &&
      currency &&
      amountMinor != null &&
      order.payment?.callbackValidated === true,
    issues,
  };
}

function classifyEntitlement(subscription = {}, { now = new Date() } = {}) {
  const plan = String(subscription.plan || "normal").trim().toLowerCase();
  const status = normalizeStatus(subscription.status || "active");
  const source = String(subscription.source || "free").trim().toLowerCase();
  const expiresAt = toDate(subscription.expiresAt);
  const active = status === "active" || status === "grace_period" || status === "canceled";
  const unexpired = Boolean(expiresAt && expiresAt.getTime() > now.getTime());
  const paidPlan = PAID_PLANS.has(plan);
  const adminGrant = source === "admin_grant";
  const free = plan === "normal" || source === "free" || source === "trial";
  return {
    plan,
    status,
    source,
    expiresAt,
    active,
    paidPlan,
    adminGrant,
    free,
    activePaidEntitlement: paidPlan && PAID_STATUSES.has(status) && unexpired,
    paidBusinessCandidate: plan === "gold" || plan === "business",
  };
}

function paymentEvidenceKey(ownerKey, plan) {
  const owner = String(ownerKey || "").trim();
  const normalizedPlan = String(plan || "").trim().toLowerCase();
  return owner && normalizedPlan ? `${owner}|${normalizedPlan}` : null;
}

function aggregateRevenueFacts({
  subscriptions = [],
  businesses = [],
  orders = [],
  now = new Date(),
  calculatedAt = null,
} = {}) {
  const byCurrency = {};
  const successfulIdentities = new Set();
  const payingCustomers = new Set();
  const warnings = [];
  const incompleteSources = [];
  const successfulBusinessOwners = new Set();
  const successfulOrderOwners = new Set();
  const successfulEntitlementEvidence = new Set();
  const payments = {
    successfulCount: 0,
    pendingCount: 0,
    failedCount: 0,
    unverifiedCount: 0,
    duplicateCount: 0,
    excludedCount: 0,
  };

  for (const { id, data } of orders) {
    const classification = classifyOrderPayment(id, data, { now });
    if (classification.source !== "web_subscription") continue;
    if (classification.issues.length) {
      for (const issue of classification.issues) {
        incompleteSources.push({ source: "orders", reason: issue, count: 1 });
      }
    }

    if (classification.status === "pending") {
      payments.pendingCount += 1;
      if (classification.currency && classification.amountMinor != null) {
        ensureCurrency(byCurrency, classification.currency).pendingMinor += classification.amountMinor;
      }
      continue;
    }
    if (classification.status === "failed") {
      payments.failedCount += 1;
      continue;
    }
    if (classification.status === "unverified") {
      payments.unverifiedCount += 1;
      continue;
    }
    if (!classification.recognized) {
      payments.excludedCount += 1;
      continue;
    }
    if (successfulIdentities.has(classification.identity)) {
      payments.duplicateCount += 1;
      warnings.push({
        code: "duplicate_payment_identity_excluded",
        source: "orders",
      });
      continue;
    }
    successfulIdentities.add(classification.identity);
    payments.successfulCount += 1;
    const bucket = ensureCurrency(byCurrency, classification.currency);
    const effectiveRefundMinor = classification.hasRefundOrReversal
      ? classification.refundMinor || classification.amountMinor
      : classification.refundMinor;
    bucket.grossMinor += classification.amountMinor;
    bucket.refundMinor += effectiveRefundMinor;
    bucket.netMinor = bucket.grossMinor - bucket.refundMinor;
    if (classification.inCurrentMonth) {
      bucket.monthlyNetMinor += classification.amountMinor - effectiveRefundMinor;
    }
    if (classification.ownerKey) {
      payingCustomers.add(classification.ownerKey);
      successfulOrderOwners.add(classification.ownerKey);
      if (data.businessId) successfulBusinessOwners.add(String(data.businessId));
      if (classification.plan && classification.amountMinor > effectiveRefundMinor) {
        const evidenceKey = paymentEvidenceKey(classification.ownerKey, classification.plan);
        if (evidenceKey) successfulEntitlementEvidence.add(evidenceKey);
      }
    }
  }

  const entitlements = {
    premiumActive: 0,
    goldActive: 0,
    paidActive: 0,
    freeActive: 0,
    adminGrantActive: 0,
    expiringSoon: 0,
    storeRevenueUnavailable: 0,
    unverifiedPaidPlanActive: 0,
  };
  const expiringThreshold = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

  for (const { data } of subscriptions) {
    const entitlement = classifyEntitlement(data, { now });
    if (!entitlement.active) continue;
    if (entitlement.plan === "premium") entitlements.premiumActive += 1;
    if (entitlement.plan === "gold") entitlements.goldActive += 1;
    const ownerKey = data.userId || data.uid || data.ownerUid || data.ownerId || "";
    const evidenceKey = paymentEvidenceKey(ownerKey, entitlement.plan);
    const hasPaymentEvidence = evidenceKey && successfulEntitlementEvidence.has(evidenceKey);
    if (entitlement.activePaidEntitlement && !entitlement.adminGrant && hasPaymentEvidence) {
      entitlements.paidActive += 1;
    } else if (entitlement.activePaidEntitlement && !entitlement.adminGrant) {
      entitlements.unverifiedPaidPlanActive += 1;
    }
    if (entitlement.free) entitlements.freeActive += 1;
    if (entitlement.adminGrant) entitlements.adminGrantActive += 1;
    if (
      entitlement.expiresAt &&
      entitlement.expiresAt >= now &&
      entitlement.expiresAt <= expiringThreshold
    ) {
      entitlements.expiringSoon += 1;
    }
    if (["app_store", "play_store", "google_play"].includes(entitlement.source)) {
      entitlements.storeRevenueUnavailable += 1;
    }
  }

  if (entitlements.storeRevenueUnavailable > 0) {
    incompleteSources.push({
      source: "mobile_store_subscriptions",
      reason: "authoritative_revenue_unavailable",
      count: entitlements.storeRevenueUnavailable,
    });
  }
  incompleteSources.push(
    { source: "marketplace_orders", reason: "v1_excluded_pending_commission_contract", count: 0 },
    { source: "vet_appointments", reason: "v1_excluded_pending_commission_contract", count: 0 },
    { source: "groomy_appointments", reason: "v1_excluded_pending_commission_contract", count: 0 },
    { source: "hotel_bookings", reason: "v1_excluded_pending_commission_contract", count: 0 },
    { source: "pet_taxi_bookings", reason: "v1_excluded_pending_commission_contract", count: 0 }
  );

  const businessesOverview = {
    approvedCount: businesses.filter(({ data }) => normalizeStatus(data.status) === "approved").length,
    paidSubscriptionCount: 0,
  };
  for (const { id, data } of businesses) {
    const subscription = data.subscription && typeof data.subscription === "object"
      ? data.subscription
      : {};
    const entitlement = classifyEntitlement(subscription, { now });
    const ownerId = String(data.ownerUid || data.ownerId || id || "").trim();
    if (
      normalizeStatus(data.status) === "approved" &&
      entitlement.activePaidEntitlement &&
      !entitlement.adminGrant &&
      entitlement.paidBusinessCandidate &&
      (
        successfulBusinessOwners.has(id) ||
        successfulEntitlementEvidence.has(paymentEvidenceKey(ownerId, entitlement.plan))
      )
    ) {
      businessesOverview.paidSubscriptionCount += 1;
    }
  }

  for (const bucket of Object.values(byCurrency)) {
    bucket.netMinor = bucket.grossMinor - bucket.refundMinor;
    bucket.arppuMinor = payingCustomers.size > 0
      ? Math.round(bucket.netMinor / payingCustomers.size)
      : 0;
  }

  return {
    schemaVersion: SCHEMA_VERSION,
    calculatedAt: calculatedAt || admin.firestore.FieldValue.serverTimestamp(),
    timezone: TIMEZONE,
    period: {
      currentMonthStart: startOfIstanbulMonth(now).toISOString(),
      currentMonthTimezone: TIMEZONE,
    },
    financial: {
      byCurrency,
    },
    payments,
    customers: {
      payingCount: payingCustomers.size,
    },
    entitlements,
    businesses: businessesOverview,
    coverage: {
      includedSources: ["orders:web_subscription"],
      incompleteSources,
    },
    warnings,
  };
}

function docsFromSnapshot(snapshot) {
  const docs = [];
  snapshot.forEach((doc) => docs.push({ id: doc.id, data: doc.data() || {} }));
  return docs;
}

async function computeRevenueMetrics(db, { now = new Date() } = {}) {
  const [subscriptionsSnap, businessesSnap, webSubscriptionOrdersSnap] = await Promise.all([
    db.collection("subscriptions").get(),
    db.collection("businesses").get(),
    db.collection("orders").where("orderType", "==", "web_subscription").get(),
  ]);

  return aggregateRevenueFacts({
    subscriptions: docsFromSnapshot(subscriptionsSnap),
    businesses: docsFromSnapshot(businessesSnap),
    orders: docsFromSnapshot(webSubscriptionOrdersSnap),
    now,
  });
}

module.exports = {
  SCHEMA_VERSION,
  TIMEZONE,
  aggregateRevenueFacts,
  amountAndCurrencyForOrder,
  classifyEntitlement,
  classifyOrderPayment,
  classifyPaymentStatus,
  computeRevenueMetrics,
  normalizeCurrency,
  normalizeStatus,
  startOfIstanbulMonth,
  toMinorUnits,
};
