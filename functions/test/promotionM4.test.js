"use strict";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const test = require("node:test");

const {
  activatePromotionFromVerifiedPayment,
  createPromotionCheckoutCore,
  stableCampaignId,
} = require("../src/promotion/promotion_engine");

const projectId = process.env.FIREBASE_PROJECT_ID || "demo-petsupo";

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  test("Promotion M4 emulator coverage", {skip: "run with the Firestore emulator"}, () => {});
} else {
  if (!admin.apps.length) admin.initializeApp({projectId});
  const db = admin.firestore();

  const petPlan = {
    targetType: "PET",
    pricingModel: "FIXED_DURATION",
    durationHours: 24,
    price: 29,
    currency: "TRY",
    rankingLift: 10,
    enabled: true,
    pricingVersion: 1,
    displayOrder: 1,
    maxConcurrentPerOwner: 3,
    maxConcurrentPerBusiness: 5,
  };

  async function seedPet() {
    await Promise.all([
      db.collection("promotion_plans").doc("m4_pet_24h_v1").set(petPlan),
      db.collection("dogs").doc("m4-dog").set({ownerId: "m4-owner", isHidden: false}),
    ]);
  }

  test("M4 PET checkout is server-priced and verified activation projects PET", async () => {
    await seedPet();
    const checkout = await createPromotionCheckoutCore({
      db,
      uid: "m4-owner",
      data: {
        targetType: "PET",
        targetId: "m4-dog",
        planId: "m4_pet_24h_v1",
        price: 0,
        idempotencyKey: "m4-pet-attempt",
      },
      createProviderCheckout: async ({campaign}) => ({
        provider: "isbank",
        providerOrderId: campaign.campaignId,
      }),
    });
    assert.equal(checkout.campaignStatus, "pending_payment");
    const campaign = (await db.collection("promotion_campaigns").doc(checkout.campaignId).get()).data();
    assert.equal(campaign.price, 29);
    assert.equal(campaign.targetType, "PET");

    const activated = await activatePromotionFromVerifiedPayment({
      db,
      campaignId: checkout.campaignId,
      now: new Date("2026-08-08T12:00:00Z"),
      evidence: {
        verified: true,
        provider: "isbank",
        providerOrderId: checkout.campaignId,
        providerTransactionId: "m4-provider-tx",
        amount: 29,
        currency: "TRY",
      },
    });
    const projection = (await db.collection("promotion_active").doc(checkout.campaignId).get()).data();
    assert.equal(activated.campaign.status, "active");
    assert.equal(projection.targetType, "PET");
    assert.equal(projection.targetId, "m4-dog");
    assert.equal(projection.expiresAt.toMillis() - projection.startsAt.toMillis(), 24 * 60 * 60 * 1000);
  });

  test("M4 rejects non-owner and wrong target type before checkout", async () => {
    await seedPet();
    const provider = async () => ({provider: "isbank", providerOrderId: "unused"});
    await assert.rejects(
      createPromotionCheckoutCore({
        db,
        uid: "m4-other",
        data: {targetType: "PET", targetId: "m4-dog", planId: "m4_pet_24h_v1", idempotencyKey: "m4-other"},
        createProviderCheckout: provider,
      }),
      /not owned/
    );
    await assert.rejects(
      createPromotionCheckoutCore({
        db,
        uid: "m4-owner",
        data: {targetType: "PRODUCT", targetId: "m4-dog", planId: "m4_pet_24h_v1", idempotencyKey: "m4-wrong-type"},
        createProviderCheckout: provider,
      }),
      /businessId is required/
    );
  });

  test("M4 duplicate provider callback remains idempotent", async () => {
    await seedPet();
    const campaignId = stableCampaignId("m4-owner", "m4-duplicate");
    await db.collection("promotion_campaigns").doc(campaignId).set({
      campaignId,
      ownerUid: "m4-owner",
      targetType: "PET",
      targetId: "m4-dog",
      planId: "m4_pet_24h_v1",
      price: 29,
      currency: "TRY",
      durationHours: 24,
      pricingVersion: 1,
      rankingWeight: 10,
      status: "pending_payment",
      paymentStatus: "pending",
      paymentProvider: "isbank",
      providerOrderId: campaignId,
      version: 1,
    });
    const evidence = {
      verified: true,
      provider: "isbank",
      providerOrderId: campaignId,
      providerTransactionId: "m4-same-tx",
      amount: 29,
      currency: "TRY",
    };
    await activatePromotionFromVerifiedPayment({db, campaignId, evidence});
    const retry = await activatePromotionFromVerifiedPayment({db, campaignId, evidence});
    assert.equal(retry.status, "already_processed");
    assert.equal((await db.collection("promotion_active").doc(campaignId).get()).exists, true);
  });
}
