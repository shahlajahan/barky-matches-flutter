"use strict";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const test = require("node:test");

const {
  activatePromotionFromVerifiedPayment,
  createPromotionCheckoutCore,
  failPromotionPayment,
  readPromotionPaymentStatus,
  stableCampaignId,
} = require("../src/promotion/promotion_engine");

const projectId = process.env.FIREBASE_PROJECT_ID || "demo-petsupo";

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  test("Promotion M3 emulator coverage", {skip: "run with the Firestore emulator"}, () => {});
} else {
  if (!admin.apps.length) admin.initializeApp({projectId});
  const db = admin.firestore();

  function plan(targetType, price, durationHours, enabled = true) {
    return {
      targetType,
      pricingModel: "FIXED_DURATION",
      durationHours,
      price,
      currency: "TRY",
      rankingLift: 10,
      enabled,
      pricingVersion: 1,
      displayOrder: 1,
      maxConcurrentPerOwner: 3,
      maxConcurrentPerBusiness: 5,
    };
  }

  async function seed() {
    await Promise.all([
      db.collection("promotion_plans").doc("m3_pet_24h_v1").set(plan("PET", 29, 24)),
      db.collection("promotion_plans").doc("m3_product_3d_v1").set(plan("PRODUCT", 89, 72)),
      db.collection("promotion_plans").doc("m3_service_7d_v1").set(plan("SERVICE", 219, 168)),
      db.collection("promotion_plans").doc("m3_business_24h_v1").set(plan("BUSINESS", 99, 24, false)),
      db.collection("users").doc("pet-owner").set({email: "owner@example.test"}),
      db.collection("users").doc("seller-owner").set({email: "seller@example.test"}),
      db.collection("users").doc("service-owner").set({email: "service@example.test"}),
      db.collection("dogs").doc("dog-1").set({ownerId: "pet-owner", isHidden: false}),
      db.collection("businesses").doc("business-1").set({
        ownerUid: "seller-owner", status: "approved", published: true, isActive: true,
      }),
      db.collection("businesses").doc("service-business-1").set({
        ownerUid: "service-owner", sectors: ["vet"], status: "approved", published: true, isActive: true,
      }),
      db.collection("businesses").doc("business-1").collection("products").doc("product-1").set({
        businessId: "business-1", productId: "product-1", isActive: true, stock: 5,
      }),
      db.collection("businesses").doc("service-business-1").collection("services").doc("service-1").set({
        businessId: "service-business-1", isActive: true,
      }),
    ]);
  }

  test("M3 resolves PET, PRODUCT, and SERVICE ownership and server pricing", async () => {
    await seed();
    const calls = [];
    const provider = async ({campaign, plan: resolvedPlan}) => {
      calls.push({campaignId: campaign.campaignId, price: resolvedPlan.price});
      return {provider: "isbank", providerOrderId: campaign.campaignId, html: "<form>safe-provider-form</form>"};
    };

    const pet = await createPromotionCheckoutCore({
      db, uid: "pet-owner",
      data: {targetType: "PET", targetId: "dog-1", planId: "m3_pet_24h_v1", price: 0, idempotencyKey: "pet-attempt"},
      createProviderCheckout: provider,
    });
    const product = await createPromotionCheckoutCore({
      db, uid: "seller-owner",
      data: {targetType: "PRODUCT", targetId: "product-1", businessId: "business-1", planId: "m3_product_3d_v1", price: 1, idempotencyKey: "product-attempt"},
      createProviderCheckout: provider,
    });
    const service = await createPromotionCheckoutCore({
      db, uid: "service-owner",
      data: {targetType: "SERVICE", targetId: "service/VET/service-business-1/service-1", businessId: "service-business-1", sector: "VET", planId: "m3_service_7d_v1", idempotencyKey: "service-attempt"},
      createProviderCheckout: provider,
    });

    assert.equal(pet.campaignStatus, "pending_payment");
    assert.equal(product.campaignStatus, "pending_payment");
    assert.equal(service.campaignStatus, "pending_payment");
    assert.deepEqual(calls.map((entry) => entry.price), [29, 89, 219]);
    assert.equal((await db.collection("promotion_campaigns").doc(pet.campaignId).get()).data().price, 29);
    assert.equal((await db.collection("promotion_campaigns").doc(product.campaignId).get()).data().price, 89);
    assert.equal((await db.collection("promotion_campaigns").doc(service.campaignId).get()).data().price, 219);
  });

  test("M3 rejects unknown, disabled, missing, ambiguous, and non-owned targets", async () => {
    await seed();
    const provider = async () => ({provider: "isbank", providerOrderId: "unused"});
    const request = (overrides = {}, callerUid = "pet-owner") => createPromotionCheckoutCore({
      db,
      uid: callerUid,
      data: {
        targetType: "PET", targetId: "dog-1", planId: "m3_pet_24h_v1", idempotencyKey: `reject-${Math.random()}`,
        ...overrides,
      },
      createProviderCheckout: provider,
    });

    await assert.rejects(request({targetId: "missing-dog"}), /not found/);
    await assert.rejects(request({targetId: "dog-1"}, "not-owner"), /not owned/);
    await assert.rejects(request({targetType: "BUSINESS", targetId: "business-1", planId: "business_24h_v1"}), /disabled/);
    await assert.rejects(request({planId: "missing-plan"}), /not found/);
    await assert.rejects(
      createPromotionCheckoutCore({
        db, uid: "seller-owner",
        data: {targetType: "PRODUCT", targetId: "product-1", planId: "m3_product_3d_v1", idempotencyKey: "ambiguous-product"},
        createProviderCheckout: provider,
      }),
      /businessId is required/
    );
    await assert.rejects(
      createPromotionCheckoutCore({
        db, uid: "pet-owner",
        data: {targetType: "PRODUCT", targetId: "product-1", businessId: "business-1", planId: "m3_product_3d_v1", idempotencyKey: "wrong-owner"},
        createProviderCheckout: provider,
      }),
      /not owned/
    );
  });

  test("M3 activation verifies evidence, is atomic, and is idempotent", async () => {
    await seed();
    let providerCalls = 0;
    const result = () => createPromotionCheckoutCore({
      db, uid: "pet-owner",
      data: {targetType: "PET", targetId: "dog-1", planId: "m3_pet_24h_v1", idempotencyKey: "activation-attempt"},
      createProviderCheckout: async ({campaign}) => {
        providerCalls += 1;
        return {provider: "isbank", providerOrderId: campaign.campaignId, html: "provider-form"};
      },
    });
    const checkout = await result();
    const duplicate = await result();
    assert.equal(duplicate.campaignId, checkout.campaignId);
    assert.equal(providerCalls, 1);

    const commonEvidence = {
      verified: true,
      provider: "isbank",
      providerOrderId: checkout.campaignId,
      providerTransactionId: "isbank-tx-1",
      amount: 29,
      currency: "TRY",
      paymentStatus: "paid",
    };
    await assert.rejects(
      activatePromotionFromVerifiedPayment({db, campaignId: checkout.campaignId, evidence: {...commonEvidence, verified: false}}),
      /not verified/
    );
    await assert.rejects(
      activatePromotionFromVerifiedPayment({db, campaignId: checkout.campaignId, evidence: {...commonEvidence, amount: 1}}),
      /amount mismatch/
    );
    await assert.rejects(
      activatePromotionFromVerifiedPayment({db, campaignId: checkout.campaignId, evidence: {...commonEvidence, currency: "USD"}}),
      /currency mismatch/
    );

    const activated = await activatePromotionFromVerifiedPayment({
      db, campaignId: checkout.campaignId, evidence: commonEvidence,
      now: new Date("2026-08-08T10:00:00.000Z"),
    });
    assert.equal(activated.status, "activated");
    assert.equal(activated.campaign.status, "active");
    assert.equal(activated.campaign.price, 29);
    assert.equal(activated.campaign.pricingVersion, 1);
    assert.equal(activated.campaign.expiresAt.toMillis() - activated.campaign.startsAt.toMillis(), 24 * 60 * 60 * 1000);

    const projection = await db.collection("promotion_active").doc(checkout.campaignId).get();
    assert.equal(projection.exists, true);
    const projectionData = projection.data();
    assert.equal(projectionData.targetId, "dog-1");
    assert.equal(projectionData.expiresAt.toMillis(), activated.campaign.expiresAt.toMillis());
    assert.equal("price" in projectionData, false);
    assert.equal("providerTransactionId" in projectionData, false);
    assert.equal("checkoutToken" in projectionData, false);

    const retry = await activatePromotionFromVerifiedPayment({db, campaignId: checkout.campaignId, evidence: commonEvidence});
    assert.equal(retry.status, "already_processed");
    await assert.rejects(
      activatePromotionFromVerifiedPayment({db, campaignId: checkout.campaignId, evidence: {...commonEvidence, providerTransactionId: "other-tx"}}),
      /conflicting/
    );
  });

  test("M3 failure and status reader preserve safe state and owner isolation", async () => {
    await seed();
    const campaignId = stableCampaignId("pet-owner", "failure-attempt");
    await db.collection("promotion_campaigns").doc(campaignId).set({
      campaignId, ownerUid: "pet-owner", targetType: "PET", targetId: "dog-1",
      status: "pending_payment", paymentStatus: "pending", version: 1,
    });
    await failPromotionPayment({db, campaignId, failureCode: "provider raw secret should not be stored"});
    const status = await readPromotionPaymentStatus({db, uid: "pet-owner", campaignId});
    assert.equal(status.campaignStatus, "failed");
    assert.equal(status.paymentStatus, "failed");
    await assert.rejects(readPromotionPaymentStatus({db, uid: "other-user", campaignId}), /Not authorized/);
    const failed = (await db.collection("promotion_campaigns").doc(campaignId).get()).data();
    assert.equal(failed.failureCode, "provider_raw_secret_should_not_be_stored");
    assert.equal("raw" in failed, false);
  });
}
