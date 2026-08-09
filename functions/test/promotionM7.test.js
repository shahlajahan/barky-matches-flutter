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
  test("Promotion M7 Service emulator coverage", {skip: "run with the Firestore emulator"}, () => {});
} else {
  if (!admin.apps.length) admin.initializeApp({projectId: process.env.FIREBASE_PROJECT_ID || "demo-petsupo"});
  const db = admin.firestore();

  const plan = (price, durationHours) => ({
    targetType: "SERVICE", pricingModel: "FIXED_DURATION", durationHours,
    price, currency: "TRY", rankingLift: 10, enabled: true, pricingVersion: 1,
    displayOrder: durationHours, maxConcurrentPerOwner: 3, maxConcurrentPerBusiness: 5,
  });

  async function seed(suffix, sector = "VET") {
    const businessId = `m7-business-${suffix}`;
    const serviceId = "same-service-id";
    await Promise.all([
      db.collection("promotion_plans").doc("service_24h_v1").set(plan(49, 24)),
      db.collection("promotion_plans").doc("service_3d_v1").set(plan(119, 72)),
      db.collection("promotion_plans").doc("service_7d_v1").set(plan(219, 168)),
      db.collection("businesses").doc(businessId).set({
        ownerUid: "m7-owner", sectors: [sector.toLowerCase()],
        status: "approved", published: true, isActive: true,
      }),
      db.collection("businesses").doc(businessId).collection("services").doc(serviceId).set({
        serviceId, businessId, isActive: true, isBookable: true,
      }),
    ]);
    return {
      businessId,
      serviceId,
      targetId: canonicalServiceTargetId(sector, businessId, serviceId),
      sector,
    };
  }

  function checkout(target, key, uid = "m7-owner", planId = "service_24h_v1") {
    return createPromotionCheckoutCore({
      db, uid,
      data: {
        targetType: "SERVICE", targetId: target.targetId,
        businessId: target.businessId, sector: target.sector,
        planId, price: 1, currency: "USD", idempotencyKey: key,
      },
      createProviderCheckout: async ({campaign}) => ({
        provider: "isbank", providerOrderId: campaign.campaignId, html: "provider-form",
      }),
    });
  }

  test("M7 uses one canonical Service contract and server pricing", async () => {
    const vet = await seed("pricing", "VET");
    const groomer = await seed("collision", "GROOMER");
    assert.notEqual(vet.targetId, groomer.targetId);
    assert.match(vet.targetId, /^service\/VET\//);
    assert.match(groomer.targetId, /^service\/GROOMER\//);

    const results = await Promise.all([
      checkout(vet, "m7-service-24"),
      checkout(vet, "m7-service-3d", "m7-owner", "service_3d_v1"),
      checkout(vet, "m7-service-7d", "m7-owner", "service_7d_v1"),
    ]);
    const prices = await Promise.all(results.map(async ({campaignId}) =>
      (await db.collection("promotion_campaigns").doc(campaignId).get()).data().price));
    assert.deepEqual(prices, [49, 119, 219]);
    const campaign = (await db.collection("promotion_campaigns").doc(results[0].campaignId).get()).data();
    assert.equal(campaign.targetType, "SERVICE");
    assert.equal(campaign.targetId, vet.targetId);
    assert.equal(campaign.sector, "VET");
  });

  test("M7 enforces Service ownership, canonical identity, sector, and eligibility", async () => {
    const target = await seed("eligibility", "VET");
    await assert.rejects(checkout(target, "m7-service-other-owner", "other-user"), /not owned/);
    await assert.rejects(checkout({...target, targetId: `service/VET/${target.businessId}/missing`}, "m7-service-missing"), /not found/);
    await assert.rejects(
      checkout({...target, targetId: canonicalServiceTargetId("GROOMER", target.businessId, target.serviceId), sector: "GROOMER"}, "m7-service-wrong-sector"),
      /does not match business/,
    );
    await db.collection("businesses").doc(target.businessId).collection("services").doc(target.serviceId).update({isActive: false});
    await assert.rejects(checkout(target, "m7-service-inactive"), /not eligible/);
  });

  test("M7 verified Service activation is atomic and overlap-safe", async () => {
    const target = await seed("activation", "VET");
    const first = await checkout(target, "m7-service-activation");
    const evidence = {
      verified: true, provider: "isbank", providerOrderId: first.campaignId,
      providerTransactionId: "m7-service-tx", amount: 49, currency: "TRY", paymentStatus: "paid",
    };
    await assert.rejects(
      activatePromotionFromVerifiedPayment({
        db, campaignId: first.campaignId, evidence: {...evidence, amount: 1},
      }),
      /amount mismatch/,
    );
    await assert.rejects(
      activatePromotionFromVerifiedPayment({
        db, campaignId: first.campaignId, evidence: {...evidence, currency: "USD"},
      }),
      /currency mismatch/,
    );
    const activated = await activatePromotionFromVerifiedPayment({
      db, campaignId: first.campaignId, evidence,
      now: new Date("2026-08-08T10:00:00.000Z"),
    });
    assert.equal(activated.campaign.status, "active");
    const projection = (await db.collection("promotion_active").doc(first.campaignId).get()).data();
    assert.deepEqual(
      {targetType: projection.targetType, targetId: projection.targetId, sector: projection.sector},
      {targetType: "SERVICE", targetId: target.targetId, sector: "VET"},
    );
    assert.equal("price" in projection, false);
    assert.equal(projection.featuredDealEligible, true);
    assert.equal(projection.serviceId, target.serviceId);
    assert.equal(projection.businessName, "Business");
    assert.equal(projection.serviceTitle, "Service");
    assert.equal(projection.startsAt.toMillis(), activated.campaign.startsAt.toMillis());
    assert.equal(projection.expiresAt.toMillis(), activated.campaign.expiresAt.toMillis());

    await db.collection("businesses").doc(target.businessId).collection("services").doc(target.serviceId)
      .update({title: "Laboratory"});
    await activatePromotionFromVerifiedPayment({db, campaignId: first.campaignId, evidence});
    const repaired = (await db.collection("promotion_active").doc(first.campaignId).get()).data();
    assert.equal(repaired.serviceTitle, "Laboratory");
    await assert.rejects(checkout(target, "m7-service-overlap"), /SERVICE target already has an active promotion/);

    await db.collection("promotion_active").doc(first.campaignId).update({
      expiresAt: admin.firestore.Timestamp.fromDate(new Date("2026-08-07T10:00:00.000Z")),
    });
    const next = await checkout(target, "m7-service-after-expiry");
    assert.equal(next.campaignStatus, "pending_payment");
  });

  test("M7 keeps SERVICE distinct from BUSINESS", async () => {
    const target = await seed("distinct", "GROOMER");
    await assert.rejects(createPromotionCheckoutCore({
      db, uid: "m7-owner",
      data: {
        targetType: "BUSINESS", targetId: target.businessId,
        planId: "service_24h_v1", idempotencyKey: "m7-business-disabled",
      },
      createProviderCheckout: async () => ({provider: "isbank", providerOrderId: "unused"}),
    }), /disabled|target type does not match/);
  });
}
