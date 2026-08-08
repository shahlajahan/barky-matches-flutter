"use strict";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const test = require("node:test");

const {readPromotionCampaignStats} = require("../src/promotion/promotion_analytics");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  test("Promotion M10 performance reader emulator coverage", {skip: "run with the Firestore emulator"}, () => {});
} else {
  if (!admin.apps.length) admin.initializeApp({projectId: process.env.FIREBASE_PROJECT_ID || "demo-petsupo"});
  const db = admin.firestore();

  async function seed(campaignId, overrides = {}, stats = {}) {
    await db.collection("promotion_campaigns").doc(campaignId).set({
      campaignId, ownerUid: "m10-owner", targetType: "PRODUCT", targetId: "m10-product",
      currency: "TRY", price: 39, pricingVersion: 1, planId: "product-24h",
      durationHours: 24, status: "active", startsAt: admin.firestore.Timestamp.now(),
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 3600000)),
      ...overrides,
    });
    if (stats !== null) await db.collection("promotion_campaign_stats").doc(campaignId).set(stats);
  }

  test("owner receives normalized performance and campaign summary only", async () => {
    await seed("m10-available", {}, {
      impressions: 10, clicks: 2, detailViews: 1, financialConversions: 1,
      qualifiedConversions: 1, attributedRevenue: 100, refundedRevenue: 0,
      financialMetricsStatus: "AVAILABLE", revenueAttributionStatus: "server_attributed",
      reconciliationStatus: "CONVERGED", currency: "TRY",
    });
    const result = await readPromotionCampaignStats({db, uid: "m10-owner", campaignId: "m10-available"});
    assert.equal(result.spend, 39);
    assert.equal(result.planId, "product-24h");
    assert.equal(result.durationHours, 24);
    assert.equal(result.roas, 100 / 39);
    assert.equal(result.startsAt != null, true);
    assert.equal(Object.hasOwn(result, "providerTransactionId"), false);
    assert.equal(Object.hasOwn(result, "buyerUid"), false);
  });

  test("owner scope, PET, provisional, zero spend, and missing stats are safe", async () => {
    await seed("m10-pet", {targetType: "PET"}, {financialMetricsStatus: "AVAILABLE", attributedRevenue: 500});
    await seed("m10-provisional", {}, {financialMetricsStatus: "PROVISIONAL", attributedRevenue: 100});
    await seed("m10-zero-spend", {price: 0}, {financialMetricsStatus: "AVAILABLE", revenueAttributionStatus: "server_attributed"});
    await seed("m10-missing", {}, null);
    assert.equal((await readPromotionCampaignStats({db, uid: "m10-owner", campaignId: "m10-pet"})).financialMetricsStatus, "UNAVAILABLE");
    assert.equal((await readPromotionCampaignStats({db, uid: "m10-owner", campaignId: "m10-provisional"})).roas, null);
    assert.equal((await readPromotionCampaignStats({db, uid: "m10-owner", campaignId: "m10-zero-spend"})).roas, null);
    const missing = await readPromotionCampaignStats({db, uid: "m10-owner", campaignId: "m10-missing"});
    assert.equal(missing.impressions, 0);
    assert.equal(missing.financialMetricsStatus, "PROVISIONAL");
    await assert.rejects(readPromotionCampaignStats({db, uid: null, campaignId: "m10-missing"}), /uid is required/);
    await assert.rejects(readPromotionCampaignStats({db, uid: "other-owner", campaignId: "m10-missing"}), /authorized/);
  });
}
