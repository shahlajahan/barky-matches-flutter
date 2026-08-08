"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");

const {
  isEligibleServiceProjection,
  readRotationWindow,
  readFeaturedServiceDeals,
  rotationCursor,
  rotationSlot,
  selectFeaturedServiceDeals,
  synchronizeServicePromotionProjections,
} = require("../src/promotion/promotion_featured_deals");

const active = (campaignId, overrides = {}) => ({
  campaignId,
  targetType: "SERVICE",
  featuredDealEligible: true,
  targetId: `service/VET/business-${campaignId}/service-${campaignId}`,
  sector: "VET",
  startsAt: new Date("2026-08-08T09:00:00.000Z"),
  expiresAt: new Date("2026-08-09T09:00:00.000Z"),
  ...overrides,
});

test("only active supported canonical service projections are eligible", () => {
  const now = new Date("2026-08-08T10:00:00.000Z").getTime();
  assert.equal(isEligibleServiceProjection(active("eligible"), now), true);
  assert.equal(isEligibleServiceProjection(active("expired", {
    expiresAt: new Date("2026-08-08T09:00:00.000Z"),
  }), now), false);
  assert.equal(isEligibleServiceProjection(active("future", {
    startsAt: new Date("2026-08-08T11:00:00.000Z"),
  }), now), false);
  assert.equal(isEligibleServiceProjection(active("hotel", {
    sector: "PET_HOTEL",
    targetId: "service/PET_HOTEL/business-hotel/service-hotel",
  }), now), false);
  assert.equal(isEligibleServiceProjection(active("product", {
    targetType: "PRODUCT",
    targetId: "product-1",
    sector: "pet_shop",
  }), now), false);
  assert.equal(isEligibleServiceProjection(active("bad" , {
    targetId: "service/VET/business-only",
  }), now), false);
});

test("Featured Deal inventory is bounded and deterministic", () => {
  const projections = Array.from({length: 1000}, (_, index) => active(`campaign-${index}`));
  const first = selectFeaturedServiceDeals(projections, {slot: 12});
  const retry = selectFeaturedServiceDeals(projections, {slot: 12});
  assert.equal(first.length, 6);
  assert.deepEqual(first, retry);
  assert.equal(new Set(first.map((item) => item.campaignId)).size, 6);
});

test("equivalent campaigns rotate as the server slot changes", () => {
  const projections = Array.from({length: 10}, (_, index) => active(`campaign-${index}`));
  const seen = new Set();
  for (let slot = 0; slot < 100; slot += 1) {
    for (const deal of selectFeaturedServiceDeals(projections, {slot, limit: 1})) {
      seen.add(deal.campaignId);
    }
  }
  assert.equal(seen.size, 10);
});

function fakeOrderedQuery(ids, state = {}, dataById = {}) {
  return {
    where() {
      return fakeOrderedQuery(ids, state, dataById);
    },
    orderBy() {
      return fakeOrderedQuery(ids, state, dataById);
    },
    startAt(value) {
      return fakeOrderedQuery(ids, {...state, startAt: value}, dataById);
    },
    endBefore(value) {
      return fakeOrderedQuery(ids, {...state, endBefore: value}, dataById);
    },
    limit(value) {
      return fakeOrderedQuery(ids, {...state, limit: value}, dataById);
    },
    async get() {
      const start = state.startAt === undefined
        ? 0
        : ids.findIndex((id) => id >= state.startAt);
      const first = start < 0 ? ids.length : start;
      const end = state.endBefore === undefined
        ? ids.length
        : ids.findIndex((id) => id >= state.endBefore);
      const docs = ids.slice(first, end < 0 ? ids.length : end);
      return {
        docs: docs.slice(0, state.limit || ids.length).map((id) => ({
          id,
          data: () => dataById[id] || {},
        })),
      };
    },
  };
}

function campaignIds(count) {
  return Array.from({length: count}, (_, index) => {
    const digest = crypto.createHash("sha256").update(`campaign-${index}`).digest("hex");
    return `promotion_${digest.slice(0, 40)}`;
  }).sort();
}

test("circular bounded query reaches campaigns beyond the first 100", async () => {
  const ids = campaignIds(1000);
  const seen = new Set();
  for (let slot = 0; slot < 2000; slot += 1) {
    const docs = await readRotationWindow(
      fakeOrderedQuery(ids),
      rotationCursor(slot),
      100,
    );
    assert.ok(docs.length <= 100);
    docs.forEach((doc) => seen.add(doc.id));
  }
  assert.equal(seen.size, 1000);
});

test("1000 equivalent campaigns are not permanently starved from display", async () => {
  const ids = campaignIds(1000);
  const displayed = new Set();
  for (let slot = 0; slot < 5000; slot += 1) {
    const docs = await readRotationWindow(
      fakeOrderedQuery(ids),
      rotationCursor(slot),
      100,
    );
    const selected = selectFeaturedServiceDeals(
      docs.map((doc) => ({campaignId: doc.id})),
      {slot},
    );
    selected.forEach((deal) => displayed.add(deal.campaignId));
  }
  assert.equal(displayed.size, 1000);
});

test("bounded query remains circular at 101 and 10000 campaigns", async () => {
  for (const count of [1, 100, 101, 10000]) {
    const ids = campaignIds(count);
    const first = await readRotationWindow(
      fakeOrderedQuery(ids),
      ids[Math.floor(ids.length / 2)],
      100,
    );
    assert.equal(first.length, Math.min(count, 100));
    assert.ok(first.every((doc) => ids.includes(doc.id)));
  }
});

test("same slot is deterministic and different slots rotate the window", async () => {
  const ids = campaignIds(1000);
  const first = await readRotationWindow(fakeOrderedQuery(ids), rotationCursor(7), 100);
  const retry = await readRotationWindow(fakeOrderedQuery(ids), rotationCursor(7), 100);
  const next = await readRotationWindow(fakeOrderedQuery(ids), rotationCursor(8), 100);
  assert.deepEqual(first.map((doc) => doc.id), retry.map((doc) => doc.id));
  assert.notDeepEqual(first.map((doc) => doc.id), next.map((doc) => doc.id));
  assert.equal(rotationSlot(20_000), rotationSlot(20_001));
  assert.notEqual(rotationSlot(20_000), rotationSlot(40_000));
});

test("Featured Deal delivery reads projections only, not business or service documents", async () => {
  const now = new Date("2026-08-08T10:00:00.000Z");
  const projections = Object.fromEntries(
    Array.from({length: 100}, (_, index) => {
      const id = `promotion-read-${index}`;
      return [id, {
        ...active(id),
        businessId: `business-${index}`,
        serviceId: `service-${index}`,
        serviceTitle: `Service ${index}`,
        businessName: `Business ${index}`,
        location: "Istanbul",
        price: null,
        currency: "TRY",
      }];
    }),
  );
  const ids = Object.keys(projections).sort();
  const promotionQuery = fakeOrderedQuery(ids, {}, projections);
  const db = {
    collection(name) {
      if (name === "promotion_active") return promotionQuery;
      throw new Error(`Unexpected delivery read: ${name}`);
    },
  };
  const result = await readFeaturedServiceDeals({db, now});
  assert.equal(result.deals.length, 6);
  assert.equal(result.candidateLimit, 100);
});

test("business and service mutations invalidate the denormalized eligibility flag", async () => {
  let updated;
  const projectionDoc = {
    ref: {id: "promotion-invalidation"},
    id: "promotion-invalidation",
    data: () => ({
      targetType: "SERVICE",
      targetId: "service/VET/business-1/service-1",
      businessId: "business-1",
    }),
  };
  const db = {
    collection(name) {
      assert.equal(name, "promotion_active");
      return {
        where() {
          return {
            async get() {
              return {empty: false, docs: [projectionDoc]};
            },
          };
        },
      };
    },
    batch() {
      return {
        update(_ref, fields) {
          updated = fields;
        },
        async commit() {},
      };
    },
  };
  await synchronizeServicePromotionProjections({
    db,
    businessId: "business-1",
    business: {status: "approved", published: true, isActive: true},
    services: [],
  });
  assert.equal(updated.featuredDealEligible, false);

  await synchronizeServicePromotionProjections({
    db,
    businessId: "business-1",
    business: {status: "approved", published: true, isActive: true, profile: {displayName: "Vet"}},
    services: [{id: "service-1", title: "Check-up", isActive: true}],
  });
  assert.equal(updated.featuredDealEligible, true);
  assert.equal(updated.serviceTitle, "Check-up");
  await synchronizeServicePromotionProjections({
    db,
    businessId: "business-1",
    business: {status: "approved", published: true, isActive: true, profile: {displayName: "Vet"}},
    services: [{id: "service-1", title: "Check-up", isActive: true}],
  });
  assert.equal(updated.featuredDealEligible, true);
  assert.equal(updated.serviceTitle, "Check-up");

  await synchronizeServicePromotionProjections({
    db,
    businessId: "business-1",
    business: {status: "approved", published: true, isActive: false},
    services: [{id: "service-1", title: "Check-up", isActive: true}],
  });
  assert.equal(updated.featuredDealEligible, false);
});
