"use strict";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const test = require("node:test");

const {
  activatePromotionFromVerifiedPayment,
  canonicalServiceTargetId,
  createPromotionCheckoutCore,
} = require("../src/promotion/promotion_engine");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  test("Promotion M11 activation revalidation emulator coverage", {skip: "run with the Firestore emulator"}, () => {});
} else {
  if (!admin.apps.length) admin.initializeApp({projectId: process.env.FIREBASE_PROJECT_ID || "demo-petsupo"});
  const db = admin.firestore();
  let sequence = 0;

  const plan = (targetType, price) => ({
    targetType, pricingModel: "FIXED_DURATION", durationHours: 24,
    price, currency: "TRY", rankingLift: 40, enabled: true,
    pricingVersion: 1, displayOrder: 1, maxConcurrentPerOwner: 1,
    maxConcurrentPerBusiness: 1,
  });

  async function checkout({targetType, targetId, businessId = null, sector = null, price, ownerUid = "m11-owner"}) {
    const suffix = `${Date.now()}-${sequence++}`;
    const planId = `m11-${targetType.toLowerCase()}-${suffix}`;
    await db.collection("promotion_plans").doc(planId).set(plan(targetType, price));
    const result = await createPromotionCheckoutCore({
      db, uid: ownerUid,
      data: {
        targetType, targetId, businessId, sector, planId,
        idempotencyKey: `m11-${suffix}`,
      },
      createProviderCheckout: async ({campaign}) => ({
        provider: "isbank", providerOrderId: campaign.campaignId, html: "provider-form",
      }),
    });
    return {campaignId: result.campaignId, amount: price, providerOrderId: result.campaignId};
  }

  async function productTarget(suffix) {
    const businessId = `m11-product-business-${suffix}`;
    const productId = `m11-product-${suffix}`;
    await db.collection("businesses").doc(businessId).set({
      ownerUid: "m11-owner", status: "approved", published: true, isActive: true,
    });
    await db.collection("businesses").doc(businessId).collection("products").doc(productId).set({
      productId, businessId, isActive: true, stock: 4,
    });
    return {businessId, productId};
  }

  async function serviceTarget(sector, suffix) {
    const businessId = `m11-${sector.toLowerCase()}-business-${suffix}`;
    const serviceId = `m11-${sector.toLowerCase()}-service-${suffix}`;
    await db.collection("businesses").doc(businessId).set({
      ownerUid: "m11-owner", status: "approved", published: true, isActive: true,
      businessType: sector === "VET" ? "vet" : "groomer",
    });
    await db.collection("businesses").doc(businessId).collection("services").doc(serviceId).set({
      serviceId, businessId, isActive: true, isHidden: false,
    });
    return {
      businessId, serviceId,
      targetId: canonicalServiceTargetId(sector, businessId, serviceId),
    };
  }

  async function activate(checkoutResult) {
    return activatePromotionFromVerifiedPayment({
      db, campaignId: checkoutResult.campaignId,
      evidence: {
        verified: true, provider: "isbank",
        providerOrderId: checkoutResult.providerOrderId,
        providerTransactionId: `m11-tx-${checkoutResult.campaignId}`,
        amount: checkoutResult.amount, currency: "TRY", paymentStatus: "paid",
      },
      now: new Date("2026-08-08T10:00:00.000Z"),
    });
  }

  test("eligible Product activates and remains idempotent after revalidation", async () => {
    const target = await productTarget("eligible");
    const pending = await checkout({targetType: "PRODUCT", targetId: target.productId, businessId: target.businessId, price: 39});
    const activated = await activate(pending);
    assert.equal(activated.campaign.status, "active");
    const retry = await activate(pending);
    assert.equal(retry.status, "already_processed");
  });

  test("deleted or disabled Product fails closed after checkout", async () => {
    const deleted = await productTarget("deleted");
    const deletedCheckout = await checkout({targetType: "PRODUCT", targetId: deleted.productId, businessId: deleted.businessId, price: 39});
    await db.collection("businesses").doc(deleted.businessId).collection("products").doc(deleted.productId).delete();
    await assert.rejects(() => activate(deletedCheckout), /became ineligible/);
    const deletedCampaign = (await db.collection("promotion_campaigns").doc(deletedCheckout.campaignId).get()).data();
    assert.equal(deletedCampaign.failureCode, "target_ineligible_after_payment");

    const disabled = await productTarget("disabled");
    const disabledCheckout = await checkout({targetType: "PRODUCT", targetId: disabled.productId, businessId: disabled.businessId, price: 39});
    await db.collection("businesses").doc(disabled.businessId).collection("products").doc(disabled.productId).update({isActive: false});
    await assert.rejects(() => activate(disabledCheckout), /became ineligible/);
  });

  test("suspended or transferred Product business fails closed after checkout", async () => {
    const suspended = await productTarget("suspended");
    const suspendedCheckout = await checkout({targetType: "PRODUCT", targetId: suspended.productId, businessId: suspended.businessId, price: 39});
    await db.collection("businesses").doc(suspended.businessId).update({isSuspended: true});
    await assert.rejects(() => activate(suspendedCheckout), /became ineligible/);

    const transferred = await productTarget("transferred");
    const transferredCheckout = await checkout({targetType: "PRODUCT", targetId: transferred.productId, businessId: transferred.businessId, price: 39});
    await db.collection("businesses").doc(transferred.businessId).update({ownerUid: "another-owner"});
    await assert.rejects(() => activate(transferredCheckout), /became ineligible/);
  });

  test("disabled Vet and Groomy services fail closed after checkout", async () => {
    const vet = await serviceTarget("VET", "disabled");
    const vetCheckout = await checkout({targetType: "SERVICE", targetId: vet.targetId, businessId: vet.businessId, sector: "VET", price: 49});
    await db.collection("businesses").doc(vet.businessId).collection("services").doc(vet.serviceId).update({isActive: false});
    await assert.rejects(() => activate(vetCheckout), /became ineligible/);

    const groomy = await serviceTarget("GROOMER", "disabled");
    const groomyCheckout = await checkout({targetType: "SERVICE", targetId: groomy.targetId, businessId: groomy.businessId, sector: "GROOMER", price: 49});
    await db.collection("businesses").doc(groomy.businessId).collection("services").doc(groomy.serviceId).update({isActive: false});
    await assert.rejects(() => activate(groomyCheckout), /became ineligible/);
  });

  test("deleted Pet fails closed and deferred service sectors cannot activate", async () => {
    const petId = "m11-pet-deleted";
    await db.collection("dogs").doc(petId).set({ownerId: "m11-owner", isActive: true});
    const petCheckout = await checkout({targetType: "PET", targetId: petId, price: 29});
    await db.collection("dogs").doc(petId).delete();
    await assert.rejects(() => activate(petCheckout), /became ineligible/);
    const petCampaign = (await db.collection("promotion_campaigns").doc(petCheckout.campaignId).get()).data();
    assert.equal(petCampaign.failureCode, "target_ineligible_after_payment");
    assert.equal((await db.collection("promotion_active").doc(petCheckout.campaignId).get()).exists, false);

    await assert.rejects(() => checkout({
      targetType: "SERVICE",
      targetId: "service/HOTEL/business/service",
      businessId: "business",
      sector: "HOTEL",
      price: 49,
    }), /sector is not enabled|Business target owner not found/);
    await assert.rejects(() => checkout({
      targetType: "BUSINESS",
      targetId: "business",
      price: 49,
    }), /BUSINESS promotions are disabled/);
  });
}
