"use strict";

const {buildEffectiveSubscription} = require("./entitlementCore");

function asDate(value) {
  if (value && typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string" || typeof value === "number") {
    const date = new Date(value);
    return Number.isFinite(date.getTime()) ? date : null;
  }
  return null;
}

function hasValidGoldEntitlement(subscription, now = new Date()) {
  const effective = buildEffectiveSubscription({
    current: subscription || {},
    now,
  });
  const expiresAt = asDate(effective.expiresAt);
  return effective.plan === "gold" &&
    effective.status === "active" &&
    Boolean(expiresAt && expiresAt.getTime() > now.getTime());
}

async function loadValidGoldEntitlement({db, uid, now = new Date()}) {
  if (!db || !uid) return false;
  const snapshot = await db.collection("subscriptions").doc(uid).get();
  return snapshot.exists && hasValidGoldEntitlement(snapshot.data(), now);
}

module.exports = {hasValidGoldEntitlement, loadValidGoldEntitlement};
