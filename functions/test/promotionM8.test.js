"use strict";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const test = require("node:test");

const {
  ingestPromotionEvent,
  readPromotionCampaignStats,
} = require("../src/promotion/promotion_analytics");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  test("Promotion M8 analytics emulator coverage", {skip: "run with the Firestore emulator"}, () => {});
} else {
  if (!admin.apps.length) admin.initializeApp({projectId: process.env.FIREBASE_PROJECT_ID || "demo-petsupo"});
  const db = admin.firestore();
  const now = new Date("2026-08-08T10:00:00.000Z");

  async function seed(targetType, targetId, sector = null, ownerUid = "m8-owner") {
    const campaignId = `m8-${targetType.toLowerCase()}-${targetId.replace(/[^a-z0-9]/gi, "-")}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
    await Promise.all([
      db.collection("promotion_campaigns").doc(campaignId).set({
        campaignId, ownerUid, targetType, targetId, sector, price: targetType === "PET" ? 29 : 39,
        currency: "TRY", pricingVersion: 1, status: "active",
      }),
      db.collection("promotion_active").doc(campaignId).set({
        campaignId, ownerUid, targetType, targetId, sector,
        startsAt: admin.firestore.Timestamp.fromDate(new Date("2026-08-08T09:00:00.000Z")),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date("2026-08-09T09:00:00.000Z")),
        rankingWeight: 10,
      }),
    ]);
    return campaignId;
  }

  test("M8 accepts enabled PET, PRODUCT, VET, and GROOMER exposure events", async () => {
    const cases = [
      ["PET", "pet-m8", null, "playmate_discovery"],
      ["PRODUCT", "product-m8", "pet_shop", "marketplace_product_list"],
      ["SERVICE", "service/VET/business-m8/vet-m8", "VET", "vet_service_list"],
      ["SERVICE", "service/GROOMER/business-m8/groomy-m8", "GROOMER", "groomy_service_list"],
    ];
    for (const [targetType, targetId, sector, placement] of cases) {
      const campaignId = await seed(targetType, targetId, sector);
      const result = await ingestPromotionEvent({
        db, authUid: "viewer", now,
        data: {
          eventId: `event-${targetType}-${targetId}`,
          eventType: "IMPRESSION", campaignId, targetType, targetId, placement,
          sessionId: "m8-session",
        },
      });
      assert.equal(result.accepted, true);
      const stats = await readPromotionCampaignStats({db, uid: "m8-owner", campaignId});
      assert.equal(stats.impressions, 1);
      assert.equal(stats.spend, targetType === "PET" ? 29 : 39);
    }
  });

  test("M7 SERVICE campaigns accept the bounded Home Featured Deal placement", async () => {
    const targetId = "service/VET/business-featured/service-featured";
    const campaignId = await seed("SERVICE", targetId, "VET");
    const result = await ingestPromotionEvent({
      db, authUid: "viewer", now,
      data: {
        eventId: "featured-service-impression",
        eventType: "IMPRESSION", campaignId, targetType: "SERVICE", targetId,
        placement: "home_featured_deal", sessionId: "featured-session",
      },
    });
    assert.equal(result.accepted, true);
    const stats = await readPromotionCampaignStats({db, uid: "m8-owner", campaignId});
    assert.equal(stats.impressions, 1);
  });

  test("M8 deduplicates retries and aggregates distinct events transactionally", async () => {
    const targetId = "product-m8-dedupe";
    const campaignId = await seed("PRODUCT", targetId, "pet_shop");
    const input = {
      db, authUid: "viewer", now,
      data: {eventId: "same-impression", eventType: "IMPRESSION", campaignId,
        targetType: "PRODUCT", targetId, placement: "marketplace_product_list", sessionId: "s"},
    };
    const first = await ingestPromotionEvent(input);
    const retry = await ingestPromotionEvent(input);
    assert.equal(first.accepted, true);
    assert.equal(retry.duplicate, true);
    await Promise.all(["a", "b", "c"].map((eventId) => ingestPromotionEvent({
      ...input,
      data: {...input.data, eventId, eventType: "CLICK"},
    })));
    const stats = await readPromotionCampaignStats({db, uid: "m8-owner", campaignId});
    assert.equal(stats.impressions, 1);
    assert.equal(stats.clicks, 3);
    assert.equal(stats.ctr, 3);
  });

  test("M8 rejects organic, wrong, expired, future, and deferred targets", async () => {
    const campaignId = await seed("PRODUCT", "product-m8-reject", "pet_shop");
    await assert.rejects(ingestPromotionEvent({db, authUid: "viewer", now, data: {
      eventId: "wrong-target", eventType: "CLICK", campaignId, targetType: "PET",
      targetId: "product-m8-reject", placement: "playmate_discovery", sessionId: "s",
    }}), /target mismatch/);
    await assert.rejects(ingestPromotionEvent({db, authUid: "viewer", now, data: {
      eventId: "bad-money", eventType: "CLICK", campaignId, targetType: "PRODUCT",
      targetId: "product-m8-reject", placement: "marketplace_product_list", sessionId: "s", revenue: 999,
    }}), /Financial/);
    await assert.rejects(ingestPromotionEvent({db, authUid: "viewer", now, data: {
      eventId: "not-active", eventType: "CLICK", campaignId: "missing-campaign", targetType: "PRODUCT",
      targetId: "product-m8-reject", placement: "marketplace_product_list", sessionId: "s",
    }}), /projection/);
    const expired = await seed("PRODUCT", "product-m8-expired", "pet_shop");
    await db.collection("promotion_active").doc(expired).update({
      expiresAt: admin.firestore.Timestamp.fromDate(new Date("2026-08-08T09:00:00.000Z")),
    });
    await assert.rejects(ingestPromotionEvent({db, authUid: "viewer", now, data: {
      eventId: "expired", eventType: "IMPRESSION", campaignId: expired, targetType: "PRODUCT",
      targetId: "product-m8-expired", placement: "marketplace_product_list", sessionId: "s",
    }}), /not active/);
    const future = await seed("PRODUCT", "product-m8-future", "pet_shop");
    await db.collection("promotion_active").doc(future).update({
      startsAt: admin.firestore.Timestamp.fromDate(new Date("2026-08-09T09:00:00.000Z")),
    });
    await assert.rejects(ingestPromotionEvent({db, authUid: "viewer", now, data: {
      eventId: "future", eventType: "IMPRESSION", campaignId: future, targetType: "PRODUCT",
      targetId: "product-m8-future", placement: "marketplace_product_list", sessionId: "s",
    }}), /not active/);
    const hotel = await seed("SERVICE", "service/PET_HOTEL/business/hotel", "PET_HOTEL");
    await assert.rejects(ingestPromotionEvent({db, authUid: "viewer", now, data: {
      eventId: "hotel", eventType: "IMPRESSION", campaignId: hotel, targetType: "SERVICE",
      targetId: "service/PET_HOTEL/business/hotel", placement: "hotel_service_list", sessionId: "s",
    }}), /not analytics-enabled/);
  });

  test("M8 campaign stats are owner-isolated and spend stays on snapshot", async () => {
    const campaignId = await seed("PET", "pet-m8-owner", null, "owner-a");
    await assert.rejects(readPromotionCampaignStats({db, uid: "owner-b", campaignId}), /authorized/);
    await db.collection("promotion_plans").doc("pet_24h_v1").set({price: 999});
    const stats = await readPromotionCampaignStats({db, uid: "owner-a", campaignId});
    assert.equal(stats.spend, 29);
    assert.equal(stats.roas, null);
  });
}
