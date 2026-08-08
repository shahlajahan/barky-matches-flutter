"use strict";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const test = require("node:test");

const {
  COMMERCIAL_ATTRIBUTION_POLICY_VERSION,
  TECHNICAL_CORRELATION_POLICY_VERSION,
  readPromotionReconciliationHealth,
  reconcilePromotionConversion,
} = require("../src/promotion/promotion_attribution");
const {readPromotionCampaignStats} = require("../src/promotion/promotion_analytics");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  test("Promotion M9.6 policy emulator coverage", {skip: "run with the Firestore emulator"}, () => {});
} else {
  if (!admin.apps.length) admin.initializeApp({projectId: process.env.FIREBASE_PROJECT_ID || "demo-petsupo"});
  const db = admin.firestore();
  const interactionAt = new Date("2026-08-08T09:30:00.000Z");
  const paidAt = new Date("2026-08-08T09:40:00.000Z");

  async function campaign(campaignId, targetId, price = 39) {
    await db.collection("promotion_campaigns").doc(campaignId).set({
      campaignId, ownerUid: "m96-owner", businessId: "m96-business",
      targetType: "PRODUCT", targetId, currency: "TRY", price,
      status: "active", startsAt: admin.firestore.Timestamp.fromDate(new Date("2026-08-08T09:00:00Z")),
      expiresAt: admin.firestore.Timestamp.fromDate(new Date("2026-08-08T10:00:00Z")),
    });
    await db.collection("promotion_events").doc(`${campaignId}-click`).set({
      eventId: `${campaignId}-click`, eventType: "CLICK", campaignId,
      targetType: "PRODUCT", targetId, ownerUid: "m96-owner", businessId: "m96-business",
      actorUid: "m96-buyer", placement: "marketplace_product_list",
      occurredAt: admin.firestore.Timestamp.fromDate(interactionAt),
    });
  }

  function source(targetId, overrides = {}) {
    return {
      sourceType: "PRODUCT_ORDER_ITEM", sourceId: `m96-order-${targetId}`,
      targetType: "PRODUCT", targetId, ownerUid: "m96-owner", businessId: "m96-business",
      actorUid: "m96-buyer", occurredAt: paidAt, valid: true, paid: true,
      status: "financial", grossAmount: 100, refundedAmount: 0,
      netAttributedRevenue: 100, currency: "TRY", ...overrides,
    };
  }

  test("M9.6 same-flow policy is explicit and historical attribution preserves both versions", async () => {
    await campaign("m96-converged", "m96-product");
    const result = await reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "m96-order-m96-product",
      sourceResolver: async () => [source("m96-product")], now: paidAt,
    });
    assert.equal(result.results[0].reconciliationStatus, "CONVERGED");
    const attribution = (await db.collection("promotion_attributions")
      .where("campaignId", "==", "m96-converged").limit(1).get()).docs[0].data();
    assert.equal(attribution.commercialAttributionPolicyVersion, COMMERCIAL_ATTRIBUTION_POLICY_VERSION);
    assert.equal(attribution.technicalCorrelationPolicyVersion, TECHNICAL_CORRELATION_POLICY_VERSION);
    assert.equal(attribution.technicalCorrelationTtlMinutes, 30);
    const stats = await readPromotionCampaignStats({db, uid: "m96-owner", campaignId: "m96-converged"});
    assert.equal(stats.financialMetricsStatus, "AVAILABLE");
    assert.equal(stats.roas, 100 / 39);
  });

  test("M9.6 pending and ambiguous health remain provisional", async () => {
    await campaign("m96-pending", "m96-pending-product");
    await reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "m96-pending-order",
      sourceResolver: async () => [source("m96-pending-product", {
        sourceId: "m96-pending-order", status: "qualified", paid: false,
      })], now: paidAt,
    });
    await campaign("m96-ambiguous", "m96-ambiguous-product");
    await reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "m96-ambiguous-order",
      sourceResolver: async () => [source("m96-ambiguous-product", {
        sourceId: "m96-ambiguous-order", refundReconciliationPending: true,
      })], now: paidAt,
    });
    const pending = await readPromotionCampaignStats({db, uid: "m96-owner", campaignId: "m96-pending"});
    assert.equal(pending.financialMetricsStatus, "PROVISIONAL");
    assert.equal(pending.roas, null);
    const ambiguous = await readPromotionCampaignStats({db, uid: "m96-owner", campaignId: "m96-ambiguous"});
    assert.equal(ambiguous.financialMetricsStatus, "PROVISIONAL");
    assert.equal(ambiguous.roas, null);
    const health = await readPromotionReconciliationHealth({db, limit: 100});
    assert.ok(health.pendingCount >= 1);
    assert.ok(health.ambiguousCount >= 1);
    assert.ok(health.affectedCampaigns.includes("m96-ambiguous"));
  });

  test("M9.6 zero spend remains unavailable for ROAS", async () => {
    await campaign("m96-zero-spend", "m96-zero-spend-product", 0);
    await reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "m96-zero-spend-order",
      sourceResolver: async () => [source("m96-zero-spend-product", {sourceId: "m96-zero-spend-order", grossAmount: 0, netAttributedRevenue: 0})], now: paidAt,
    });
    const stats = await readPromotionCampaignStats({db, uid: "m96-owner", campaignId: "m96-zero-spend"});
    assert.equal(stats.roas, null);
  });

  test("M9.6 failed and currency-mismatched cases remain unavailable", async () => {
    await campaign("m96-currency", "m96-currency-product");
    await reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "m96-currency-order",
      sourceResolver: async () => [source("m96-currency-product", {
        sourceId: "m96-currency-order", currency: "USD",
      })], now: paidAt,
    });
    const currencyStats = await readPromotionCampaignStats({db, uid: "m96-owner", campaignId: "m96-currency"});
    assert.equal(currencyStats.financialMetricsStatus, "UNAVAILABLE");
    assert.equal(currencyStats.roas, null);

    await campaign("m96-failed", "m96-failed-product");
    await reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "m96-failed-order",
      sourceResolver: async () => [source("m96-failed-product", {
        sourceId: "m96-failed-order", valid: false, status: "invalid",
      })], now: paidAt,
    });
    const health = await readPromotionReconciliationHealth({db, limit: 100});
    assert.ok(health.failedCount >= 1);
  });
}
