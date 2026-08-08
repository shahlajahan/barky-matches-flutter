"use strict";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const test = require("node:test");

const {
  ATTRIBUTION_POLICY_VERSION,
  reconcilePromotionConversion,
  repairPromotionCampaignStats,
  resolvePromotionSources,
} = require("../src/promotion/promotion_attribution");
const {readPromotionCampaignStats} = require("../src/promotion/promotion_analytics");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  test("Promotion M9 attribution emulator coverage", {skip: "run with the Firestore emulator"}, () => {});
} else {
  if (!admin.apps.length) admin.initializeApp({projectId: process.env.FIREBASE_PROJECT_ID || "demo-petsupo"});
  const db = admin.firestore();
  const interactionAt = new Date("2026-08-08T09:30:00.000Z");
  const finalizationAt = new Date("2026-08-08T09:40:00.000Z");

  async function seedCampaign({campaignId, targetType, targetId, ownerUid = "m9-owner", businessId = "m9-business", sector = null, currency = "TRY"}) {
    await Promise.all([
      db.collection("promotion_campaigns").doc(campaignId).set({
        campaignId, ownerUid, targetType, targetId, businessId, sector,
        currency, price: 39, pricingVersion: 1, status: "active",
        startsAt: admin.firestore.Timestamp.fromDate(new Date("2026-08-08T09:00:00.000Z")),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date("2026-08-08T10:00:00.000Z")),
      }),
      db.collection("promotion_active").doc(campaignId).set({
        campaignId, ownerUid, targetType, targetId, businessId, sector,
        startsAt: admin.firestore.Timestamp.fromDate(new Date("2026-08-08T09:00:00.000Z")),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date("2026-08-08T10:00:00.000Z")),
        rankingWeight: 10,
      }),
      db.collection("promotion_events").doc(`${campaignId}-click`).set({
        eventId: `${campaignId}-click`, eventType: "CLICK", campaignId,
        targetType, targetId, ownerUid, businessId, sector,
        actorUid: "m9-buyer", placement: targetType === "PRODUCT" ? "marketplace_product_list" : "vet_service_list",
        occurredAt: admin.firestore.Timestamp.fromDate(interactionAt),
      }),
    ]);
  }

  function source(overrides = {}) {
    return {
      sourceType: "PRODUCT_ORDER_ITEM", sourceId: "seller-m9::line-1",
      targetType: "PRODUCT", targetId: "m9-product", ownerUid: "m9-owner",
      businessId: "m9-business", actorUid: "m9-buyer", occurredAt: finalizationAt,
      sourceState: "paid", valid: true, paid: true, status: "financial",
      grossAmount: 100, refundedAmount: 0, netAttributedRevenue: 100, currency: "TRY",
      ...overrides,
    };
  }

  test("M9 attributes a Product item amount and converges after full refund", async () => {
    await seedCampaign({campaignId: "m9-product-campaign", targetType: "PRODUCT", targetId: "m9-product"});
    let current = source();
    const resolver = async () => [current];
    const firstResults = await Promise.all([1, 2].map(() => reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "seller-m9", sourceResolver: resolver, now: finalizationAt,
    })));
    assert.equal(firstResults[0].results[0].status, "financial");
    const duplicate = await reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "seller-m9", sourceResolver: resolver, now: finalizationAt,
    });
    assert.equal(duplicate.results[0].status, "financial");
    let stats = await readPromotionCampaignStats({db, uid: "m9-owner", campaignId: "m9-product-campaign"});
    assert.equal(stats.financialConversions, 1);
    assert.equal(stats.qualifiedConversions, 1);
    assert.equal(stats.attributedRevenue, 100);
    assert.equal(stats.revenueCapability, "server_attributed");
    assert.equal(stats.financialMetricsStatus, "AVAILABLE");
    assert.equal(stats.reconciliationStatus, "CONVERGED");
    assert.equal(stats.roas, 100 / 39);

    current = source({status: "reversed", sourceState: "refunded", refundedAmount: 100, netAttributedRevenue: 0});
    await reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "seller-m9", sourceResolver: resolver, now: new Date("2026-08-08T10:00:00.000Z"),
    });
    await reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "seller-m9", sourceResolver: resolver, now: new Date("2026-08-08T10:01:00.000Z"),
    });
    stats = await readPromotionCampaignStats({db, uid: "m9-owner", campaignId: "m9-product-campaign"});
    assert.equal(stats.financialConversions, 0);
    assert.equal(stats.qualifiedConversions, 1);
    assert.equal(stats.attributedRevenue, 0);
    assert.equal(stats.refundedRevenue, 100);
    assert.equal(stats.roas, 0);
    const repaired = await repairPromotionCampaignStats({db, campaignId: "m9-product-campaign", now: finalizationAt});
    assert.equal(repaired.attributedRevenue, 0);
    assert.equal(repaired.financialMetricsStatus, "AVAILABLE");
  });

  test("M9 keeps Vet and Groomy service identities exact and rejects wrong currency", async () => {
    const vetTarget = "service/VET/m9-business/vet-service";
    const groomyTarget = "service/GROOMER/m9-business/groomy-service";
    await seedCampaign({campaignId: "m9-vet-campaign", targetType: "SERVICE", targetId: vetTarget, sector: "VET"});
    await seedCampaign({campaignId: "m9-groomy-campaign", targetType: "SERVICE", targetId: groomyTarget, sector: "GROOMER"});
    const vet = source({
      sourceType: "VET_APPOINTMENT", sourceId: "vet-appointment", targetType: "SERVICE",
      targetId: vetTarget, businessId: "m9-business", grossAmount: 120, netAttributedRevenue: 120,
    });
    const groomy = source({
      sourceType: "GROOMY_APPOINTMENT", sourceId: "groomy-appointment", targetType: "SERVICE",
      targetId: groomyTarget, businessId: "m9-business", grossAmount: 80, netAttributedRevenue: 80,
    });
    await reconcilePromotionConversion({db, sourceType: "VET_APPOINTMENT", sourceId: "vet-appointment", sourceResolver: async () => [vet], now: finalizationAt});
    await reconcilePromotionConversion({db, sourceType: "GROOMY_APPOINTMENT", sourceId: "groomy-appointment", sourceResolver: async () => [groomy], now: finalizationAt});
    const vetStats = await readPromotionCampaignStats({db, uid: "m9-owner", campaignId: "m9-vet-campaign"});
    const groomyStats = await readPromotionCampaignStats({db, uid: "m9-owner", campaignId: "m9-groomy-campaign"});
    assert.equal(vetStats.attributedRevenue, 120);
    assert.equal(groomyStats.attributedRevenue, 80);
    assert.equal(vetStats.currency, "TRY");
    assert.equal(groomyStats.currency, "TRY");

    const wrongCurrency = source({currency: "USD"});
    const rejected = await reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "seller-wrong-currency",
      sourceResolver: async () => [wrongCurrency], now: finalizationAt,
    });
    // The interaction and target/business identity are valid; currency is the
    // first failing commercial invariant, so the server must report the
    // specific currency rejection rather than campaign mismatch.
    assert.equal(rejected.results[0].status, "currency_mismatch");
  });

  test("M9 rejects missing, old, and ambiguous interactions", async () => {
    await seedCampaign({campaignId: "m9-old-campaign", targetType: "PRODUCT", targetId: "m9-old-product"});
    const old = source({targetId: "m9-old-product"});
    await db.collection("promotion_events").doc("m9-old-campaign-click").update({
      occurredAt: admin.firestore.Timestamp.fromDate(new Date("2026-08-08T08:00:00.000Z")),
    });
    const noInteraction = await reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "old", sourceResolver: async () => [old], now: finalizationAt,
    });
    assert.equal(noInteraction.results[0].status, "no_interaction");

    await seedCampaign({campaignId: "m9-ambiguous-a", targetType: "PRODUCT", targetId: "m9-ambiguous"});
    await seedCampaign({campaignId: "m9-ambiguous-b", targetType: "PRODUCT", targetId: "m9-ambiguous"});
    await db.collection("promotion_events").doc("m9-ambiguous-a-click").update({targetId: "m9-ambiguous"});
    await db.collection("promotion_events").doc("m9-ambiguous-b-click").update({targetId: "m9-ambiguous"});
    const ambiguous = await reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "ambiguous", sourceResolver: async () => [source({targetId: "m9-ambiguous"})], now: finalizationAt,
    });
    assert.equal(ambiguous.results[0].status, "ambiguous");
  });

  test("M9 qualified-but-unpaid source does not create financial revenue", async () => {
    await seedCampaign({campaignId: "m9-unpaid-campaign", targetType: "PRODUCT", targetId: "m9-unpaid-product"});
    const unpaid = source({
      sourceId: "seller-unpaid::line-1",
      targetId: "m9-unpaid-product",
      paid: false,
      status: "qualified",
      sourceState: "pending_payment",
      netAttributedRevenue: 100,
    });
    const result = await reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "seller-unpaid",
      sourceResolver: async () => [unpaid], now: finalizationAt,
    });
    assert.equal(result.results[0].status, "qualified");
    const stats = await readPromotionCampaignStats({db, uid: "m9-owner", campaignId: "m9-unpaid-campaign"});
    assert.equal(stats.qualifiedConversions, 1);
    assert.equal(stats.financialConversions, 0);
    assert.equal(stats.attributedRevenue, 0);
  });

  test("M9 default adapters read authoritative Product, Vet, and Groomy records", async () => {
    await db.collection("businesses").doc("m9-adapter-business").set({ownerUid: "m9-adapter-owner"});
    await db.collection("orders").doc("m9-root-order").set({
      buyerUid: "m9-buyer", status: "paid", paymentStatus: "paid", pricing: {currency: "TRY"},
    });
    await db.collection("sellerOrders").doc("m9-seller-order").set({
      rootOrderId: "m9-root-order", businessId: "m9-adapter-business", status: "paid", paymentStatus: "paid",
      buyerUid: "m9-buyer", items: [{lineId: "line", productId: "adapter-product", quantity: 1, totalPrice: 100, currency: "TRY"}],
    });
    const productSources = await resolvePromotionSources({db, sourceType: "PRODUCT_ORDER", sourceId: "m9-seller-order"});
    assert.equal(productSources[0].grossAmount, 100);
    assert.equal(productSources[0].ownerUid, "m9-adapter-owner");

    for (const [collection, id, serviceId] of [["vet_appointments", "m9-vet-adapter", "vet-service"], ["groomy_appointments", "m9-groomy-adapter", "groomy-service"]]) {
      await db.collection(collection).doc(id).set({
        businessId: "m9-adapter-business", serviceId, userId: "m9-buyer", status: "confirmed_paid",
        paymentStatus: "paid", payment: {finalizationStatus: "completed", currency: "TRY"},
        financialStatus: "verified", financial: {grossAmount: 75, finalPrice: 75, currency: "TRY"},
        paidAt: admin.firestore.Timestamp.fromDate(finalizationAt),
      });
      const sources = await resolvePromotionSources({db, sourceType: collection === "vet_appointments" ? "VET_APPOINTMENT" : "GROOMY_APPOINTMENT", sourceId: id});
      assert.equal(sources[0].grossAmount, 75);
      assert.match(sources[0].targetId, /^service\/(VET|GROOMER)\/m9-adapter-business\//);
    }
    assert.equal(ATTRIBUTION_POLICY_VERSION, "m9_same_flow_v1");
  });

  test("M9 unpaid Vet and Groomy sources remain qualified but never financial", async () => {
    const vetTarget = "service/VET/m9-business/m9-unpaid-vet";
    const groomyTarget = "service/GROOMER/m9-business/m9-unpaid-groomy";
    await seedCampaign({campaignId: "m9-unpaid-vet-campaign", targetType: "SERVICE", targetId: vetTarget, sector: "VET"});
    await seedCampaign({campaignId: "m9-unpaid-groomy-campaign", targetType: "SERVICE", targetId: groomyTarget, sector: "GROOMER"});
    const vet = source({
      sourceType: "VET_APPOINTMENT", sourceId: "m9-unpaid-vet", targetType: "SERVICE",
      targetId: vetTarget, status: "qualified", paid: false, netAttributedRevenue: 500,
    });
    const groomy = source({
      sourceType: "GROOMY_APPOINTMENT", sourceId: "m9-unpaid-groomy", targetType: "SERVICE",
      targetId: groomyTarget, status: "qualified", paid: false, netAttributedRevenue: 500,
    });
    await reconcilePromotionConversion({db, sourceType: "VET_APPOINTMENT", sourceId: vet.sourceId, sourceResolver: async () => [vet], now: finalizationAt});
    await reconcilePromotionConversion({db, sourceType: "GROOMY_APPOINTMENT", sourceId: groomy.sourceId, sourceResolver: async () => [groomy], now: finalizationAt});
    for (const campaignId of ["m9-unpaid-vet-campaign", "m9-unpaid-groomy-campaign"]) {
      const stats = await readPromotionCampaignStats({db, uid: "m9-owner", campaignId});
      assert.equal(stats.qualifiedConversions, 1);
      assert.equal(stats.financialConversions, 0);
      assert.equal(stats.attributedRevenue, 0);
      assert.equal(stats.financialMetricsStatus, "PROVISIONAL");
      assert.equal(stats.roas, null);
    }
  });

  test("M9 ambiguous refund remains pending and cannot become financial truth", async () => {
    const targetId = "m9-ambiguous-refund-product";
    await seedCampaign({campaignId: "m9-ambiguous-refund-campaign", targetType: "PRODUCT", targetId});
    const result = await reconcilePromotionConversion({
      db, sourceType: "PRODUCT_ORDER", sourceId: "m9-ambiguous-refund-order",
      sourceResolver: async () => [source({
        sourceId: "m9-ambiguous-refund-order::line-1",
        targetId, refundReconciliationPending: true,
      })], now: finalizationAt,
    });
    assert.equal(result.results[0].status, "reconciliation_pending");
    const stats = await readPromotionCampaignStats({db, uid: "m9-owner", campaignId: "m9-ambiguous-refund-campaign"});
    assert.equal(stats.financialMetricsStatus, "PROVISIONAL");
    assert.equal(stats.roas, null);
  });
}
