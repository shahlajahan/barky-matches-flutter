"use strict";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const test = require("node:test");

const {
  activatePromotionFromVerifiedPayment,
  createPromotionCheckoutCore,
  stableCampaignId,
} = require("../src/promotion/promotion_engine");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  test("Promotion M6 Product emulator coverage", {skip: "run with the Firestore emulator"}, () => {});
} else {
  if (!admin.apps.length) admin.initializeApp({projectId: process.env.FIREBASE_PROJECT_ID || "demo-petsupo"});
  const db = admin.firestore();

  const plan = (price, durationHours) => ({
    targetType: "PRODUCT",
    pricingModel: "FIXED_DURATION",
    durationHours,
    price,
    currency: "TRY",
    rankingLift: 10,
    enabled: true,
    pricingVersion: 1,
    displayOrder: durationHours,
    maxConcurrentPerOwner: 3,
    maxConcurrentPerBusiness: 5,
  });

  async function seed(suffix) {
    const businessId = `m6-business-${suffix}`;
    const productId = `m6-product-${suffix}`;
    await Promise.all([
      db.collection("promotion_plans").doc("product_24h_v1").set(plan(39, 24)),
      db.collection("promotion_plans").doc("product_3d_v1").set(plan(89, 72)),
      db.collection("promotion_plans").doc("product_7d_v1").set(plan(169, 168)),
      db.collection("businesses").doc(businessId).set({
        ownerUid: "m6-seller", status: "approved", published: true, isActive: true,
      }),
      db.collection("businesses").doc(businessId).collection("products").doc(productId).set({
        productId, businessId, isActive: true, stock: 5,
      }),
    ]);
    return {businessId, productId};
  }

  function checkout({businessId, productId, key, planId = "product_24h_v1", uid = "m6-seller"}) {
    return createPromotionCheckoutCore({
      db,
      uid,
      data: {
        targetType: "PRODUCT", targetId: productId, businessId, planId,
        price: 0, currency: "USD", idempotencyKey: key,
      },
      createProviderCheckout: async ({campaign}) => ({
        provider: "isbank", providerOrderId: campaign.campaignId, html: "provider-form",
      }),
    });
  }

  test("M6 uses canonical Product identity and server PRODUCT pricing", async () => {
    const target = await seed("pricing");
    const results = await Promise.all([
      checkout({...target, key: "m6-product-price-24"}),
      checkout({...target, key: "m6-product-price-3d", planId: "product_3d_v1"}),
      checkout({...target, key: "m6-product-price-7d", planId: "product_7d_v1"}),
    ]);
    assert.deepEqual(results.map((result) => result.campaignStatus), [
      "pending_payment", "pending_payment", "pending_payment",
    ]);
    const prices = await Promise.all(results.map(async (result) =>
      (await db.collection("promotion_campaigns").doc(result.campaignId).get()).data().price));
    assert.deepEqual(prices, [39, 89, 169]);
    const campaign = (await db.collection("promotion_campaigns").doc(results[0].campaignId).get()).data();
    assert.equal(campaign.targetType, "PRODUCT");
    assert.equal(campaign.targetId, target.productId);
    assert.equal(campaign.businessId, target.businessId);
  });

  test("M6 rejects non-owners and unavailable or ambiguous Products", async () => {
    const target = await seed("eligibility");
    await assert.rejects(checkout({...target, key: "m6-product-non-owner", uid: "other-user"}), /not owned/);
    await assert.rejects(checkout({...target, productId: "missing-product", key: "m6-product-missing"}), /not found/);
    await db.collection("businesses").doc(target.businessId).collection("products").doc(target.productId).update({stock: 0});
    await assert.rejects(checkout({...target, key: "m6-product-out-of-stock"}), /not available/);
  });

  test("M6 verified Product payment activates the matching projection", async () => {
    const target = await seed("activation");
    const result = await checkout({...target, key: "m6-product-activation"});
    const activated = await activatePromotionFromVerifiedPayment({
      db,
      campaignId: result.campaignId,
      evidence: {
        verified: true, provider: "isbank", providerOrderId: result.campaignId,
        providerTransactionId: "m6-product-tx", amount: 39, currency: "TRY", paymentStatus: "paid",
      },
      now: new Date("2026-08-08T10:00:00.000Z"),
    });
    assert.equal(activated.campaign.status, "active");
    const projection = (await db.collection("promotion_active").doc(result.campaignId).get()).data();
    assert.equal(projection.targetType, "PRODUCT");
    assert.equal(projection.targetId, target.productId);
    assert.equal("price" in projection, false);
    assert.equal("providerTransactionId" in projection, false);
    assert.equal(activated.campaign.price, 39);
  });

  test("M6 rejects overlapping Product promotion and remains idempotent", async () => {
    const target = await seed("overlap");
    const first = await checkout({...target, key: "m6-product-overlap-first"});
    await activatePromotionFromVerifiedPayment({
      db, campaignId: first.campaignId,
      evidence: {
        verified: true, provider: "isbank", providerOrderId: first.campaignId,
        providerTransactionId: "m6-overlap-tx", amount: 39, currency: "TRY", paymentStatus: "paid",
      },
    });
    await assert.rejects(checkout({...target, key: "m6-product-overlap-second"}), /already has an active promotion/);
    const retry = await checkout({...target, key: "m6-product-overlap-first"});
    assert.equal(retry.campaignId, stableCampaignId("m6-seller", "m6-product-overlap-first"));
    assert.equal(retry.campaignStatus, "active");
  });
}
