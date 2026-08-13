"use strict";

const PAID_PLANS = new Set(["premium", "gold"]);
const SOURCE_PRIORITY = Object.freeze({
  admin_grant: 50,
  app_store: 40,
  play_store: 30,
  web_isbank: 20,
  legacy: 10,
});

function asDate(value) {
  if (value && typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string" || typeof value === "number") {
    const date = new Date(value);
    return Number.isFinite(date.getTime()) ? date : null;
  }
  return null;
}

function planRank(plan) {
  return plan === "gold" ? 2 : plan === "premium" ? 1 : 0;
}

function sourceRank(source) {
  return SOURCE_PRIORITY[source] || 0;
}

function isValidPaidSource(record, now) {
  const plan = String(record?.plan || "normal").toLowerCase();
  const status = String(record?.status || "").toLowerCase();
  if (!PAID_PLANS.has(plan)) return false;
  if (!["active", "grace_period", "canceled"].includes(status)) return false;
  const expiresAt = asDate(record.expiresAt);
  // A paid entitlement without a server/store expiry is not launch-safe.
  return Boolean(expiresAt && expiresAt.getTime() > now.getTime());
}

function legacySources(current) {
  const sources = {};
  if (current?.sources && typeof current.sources === "object") {
    Object.assign(sources, current.sources);
  }
  if (current?.plan && PAID_PLANS.has(String(current.plan).toLowerCase())) {
    const source = current.source || "legacy";
    if (!sources[source]) sources[source] = {
      plan: String(current.plan).toLowerCase(),
      status: current.status,
      source,
      expiresAt: current.expiresAt,
      startedAt: current.startedAt,
      autoRenew: current.autoRenew,
      productId: current.productId,
    };
  }
  if (current?.mobile && typeof current.mobile === "object") {
    const mobileSource = current.mobile.source || current.mobile.store;
    if (mobileSource && current.mobile.plan) {
      sources[mobileSource] = {...current.mobile, source: mobileSource};
    }
  }
  return sources;
}

function buildEffectiveSubscription({current = {}, sourceUpdates = {}, now = new Date()}) {
  const sources = legacySources(current);
  for (const [source, value] of Object.entries(sourceUpdates)) {
    sources[source] = {...(sources[source] || {}), ...value, source};
  }

  const valid = Object.values(sources)
    .filter((record) => isValidPaidSource(record, now))
    .sort((a, b) => {
      const planDifference = planRank(String(b.plan).toLowerCase()) -
        planRank(String(a.plan).toLowerCase());
      if (planDifference) return planDifference;
      return sourceRank(b.source) - sourceRank(a.source);
    });
  const selected = valid[0];
  if (!selected) {
    return {
      plan: "normal",
      status: "active",
      source: "free",
      expiresAt: null,
      sources,
    };
  }
  return {
    ...selected,
    plan: String(selected.plan).toLowerCase(),
    status: "active",
    source: selected.source,
    sources,
  };
}

function userMirrorFromEffective(effective, now = new Date()) {
  const paid = PAID_PLANS.has(effective.plan) && effective.status === "active" &&
    Boolean(asDate(effective.expiresAt)?.getTime() > now.getTime());
  const plan = paid ? effective.plan : "normal";
  return {
    isPremium: paid,
    subscriptionPlan: plan,
    subscriptionStatus: "active",
    subscription: {
      ...effective,
      plan,
      status: "active",
    },
  };
}

module.exports = {
  asDate,
  buildEffectiveSubscription,
  isValidPaidSource,
  userMirrorFromEffective,
};
