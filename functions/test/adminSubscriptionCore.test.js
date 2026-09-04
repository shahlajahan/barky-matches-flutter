"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  ADMIN_SUBSCRIPTION_CATALOG,
  applyAdminAction,
  buildAdminGrant,
  entitlementFields,
  normalizeKnownAdminGrant,
  normalizeStatus,
} = require("../subscription/adminSubscriptionCore");
const {
  buildEffectiveSubscription,
} = require("../subscription/entitlementCore");

test("admin Gold grant uses USD 9.99 and records no payment", () => {
  const grant = buildAdminGrant({uid: "u1", plan: "gold", now: new Date("2026-08-01T00:00:00Z")});
  assert.equal(ADMIN_SUBSCRIPTION_CATALOG.premium.amount, 2.99);
  assert.equal(ADMIN_SUBSCRIPTION_CATALOG.gold.amount, 9.99);
  assert.equal(grant.currency, "USD");
  assert.equal(grant.price, 9.99);
  assert.equal(grant.paidAmount, null);
  assert.equal(grant.source, "admin_grant");
  assert.equal(entitlementFields({uid: "u1", subscription: grant}).isPremium, true);
});

test("Gold unlocks business entitlement while Premium does not", () => {
  assert.equal(entitlementFields({uid: "u1", subscription: {plan: "gold", status: "active"}}).isPremium, true);
  assert.equal(entitlementFields({uid: "u1", subscription: {plan: "premium", status: "active"}}).isPremium, true);
  assert.equal(entitlementFields({uid: "u1", subscription: {plan: "gold", status: "expired"}}).isPremium, false);
});

test("legacy cancelled status is read as canonical canceled", () => {
  assert.equal(normalizeStatus("cancelled"), "canceled");
  assert.equal(normalizeStatus("canceled"), "canceled");
});

test("repeated active admin grant preserves its existing window", () => {
  const first = buildAdminGrant({uid: "u1", plan: "gold", now: new Date("2026-08-01T00:00:00Z")});
  const second = {...first, plan: "gold", status: "active", source: "admin_grant"};
  assert.equal(second.expiresAt.toISOString(), first.expiresAt.toISOString());
});

test("downgrade, cancel, expire, and extend keep entitlement state consistent", () => {
  const now = new Date("2026-08-01T00:00:00Z");
  const gold = applyAdminAction({uid: "u1", action: "grant_gold", now});
  const premium = applyAdminAction({uid: "u1", action: "downgrade_to_premium", current: gold, now});
  assert.equal(premium.plan, "premium");
  assert.equal(premium.currency, "USD");
  assert.equal(applyAdminAction({uid: "u1", action: "cancel", current: gold, now}).status, "canceled");
  assert.equal(applyAdminAction({uid: "u1", action: "expire", current: gold, now}).status, "expired");
  const extended = applyAdminAction({uid: "u1", action: "extend", current: gold, now});
  assert.equal(extended.expiresAt.toISOString(), "2026-09-30T00:00:00.000Z");
});

test("free users remain unchanged by entitlement repair", () => {
  const free = {plan: "normal", status: "active", source: "free"};
  const repaired = entitlementFields({uid: "free-user", subscription: free});
  assert.equal(repaired.isPremium, false);
  assert.equal(repaired.subscriptionPlan, "normal");
  assert.equal(repaired.subscriptionStatus, "active");
});

test("known admin Gold repair normalizes list pricing without payment", () => {
  const repaired = normalizeKnownAdminGrant({
    uid: "u1",
    current: {plan: "gold", status: "active", price: 19.99},
  });
  assert.equal(repaired.source, "admin_grant");
  assert.equal(repaired.price, 9.99);
  assert.equal(repaired.currency, "USD");
  assert.equal(repaired.listPrice, 9.99);
  assert.equal(repaired.listPriceCurrency, "USD");
  assert.equal(repaired.paidAmount, null);
});

test("admin grants preserve legitimate store metadata without fabricating receipts", () => {
  const now = new Date("2026-09-01T00:00:00Z");
  const appStore = {
    source: "app_store",
    plan: "gold",
    status: "active",
    expiresAt: new Date("2026-12-01T00:00:00Z"),
    transactionId: "real-transaction",
    originalTransactionId: "real-original",
    verifiedAt: new Date("2026-08-31T00:00:00Z"),
  };
  const current = {sources: {app_store: appStore}};
  const adminGrant = applyAdminAction({uid: "u1", action: "grant_gold", now});
  const effective = buildEffectiveSubscription({
    current,
    sourceUpdates: {admin_grant: adminGrant},
    now,
  });

  assert.equal(effective.sources.app_store.transactionId, "real-transaction");
  assert.equal(effective.sources.app_store.originalTransactionId, "real-original");
  assert.ok(effective.sources.app_store.verifiedAt);
  assert.equal(effective.sources.admin_grant.source, "admin_grant");
  assert.equal(effective.sources.admin_grant.autoRenew, false);
  assert.equal("transactionId" in effective.sources.admin_grant, false);
  assert.equal("originalTransactionId" in effective.sources.admin_grant, false);
  assert.equal("verifiedAt" in effective.sources.admin_grant, false);
});
