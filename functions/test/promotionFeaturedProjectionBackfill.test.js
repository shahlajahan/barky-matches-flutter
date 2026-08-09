"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  backfillPromotionFeaturedProjections,
  hasCompleteProjection,
} = require("../scripts/backfillPromotionFeaturedProjections");

function makeDb(projectionEntries, businesses) {
  const writes = [];
  const docs = projectionEntries.map(([id, data]) => ({
    id,
    ref: {id},
    data: () => data,
  }));
  const query = {
    where() { return this; },
    orderBy() { return this; },
    limit() { return this; },
    startAfter() { return this; },
    async get() { return {docs, size: docs.length}; },
  };
  return {
    writes,
    collection(name) {
      if (name === "promotion_active") return query;
      if (name !== "businesses" && name !== "businesses_public") {
        throw new Error(`Unexpected collection ${name}`);
      }
      return {
        doc(businessId) {
          const business = businesses[businessId];
          return {
            async get() {
              return {
                exists: Boolean(business),
                data: () => business?.data || {},
              };
            },
            ...(name === "businesses_public" ? {} : {
            collection(child) {
              assert.equal(child, "services");
              return {
                async get() {
                  return {docs: Object.entries(business?.services || {}).map(([id, data]) => ({id, data: () => data}))};
                },
              };
            },
            }),
          };
        },
      };
    },
    batch() {
      return {
        update(ref, fields) { writes.push({ref, fields}); },
        async commit() {},
      };
    },
  };
}

const baseProjection = {
  targetType: "SERVICE",
  targetId: "service/VET/business-1/service-1",
  businessId: "business-1",
  sector: "VET",
  startsAt: new Date("2026-08-08T09:00:00.000Z"),
  expiresAt: new Date("2026-08-09T09:00:00.000Z"),
};

const businessData = {
  data: {
    status: "approved",
    published: true,
    isActive: true,
    profile: {displayName: "Vet A", logoUrl: "logo"},
    contact: {city: "Istanbul", district: "Kadikoy"},
  },
  services: {
    "service-1": {title: "Check-up", isActive: true, price: null},
  },
};

test("backfill is dry-run by behavior and repairs only legacy SERVICE projections", async () => {
  const db = makeDb([
    ["legacy", baseProjection],
    ["expired", {...baseProjection, expiresAt: new Date("2026-08-08T09:00:00.000Z")}],
  ], {"business-1": businessData});
  const result = await backfillPromotionFeaturedProjections({
    db,
    projectId: "demo-petsupo",
    apply: false,
    now: new Date("2026-08-08T10:00:00.000Z"),
  });
  assert.equal(result.scanned, 2);
  assert.equal(result.eligible, 1);
  assert.equal(result.expired, 1);
  assert.equal(result.updated, 0);
  assert.equal(db.writes.length, 0);
});

test("apply is idempotent for complete projections and invalidates ineligible targets", async () => {
  const complete = {
    ...baseProjection,
    featuredDealEligible: true,
    businessName: "Vet A",
    serviceTitle: "Check-up",
    serviceId: "service-1",
    location: "Kadikoy, Istanbul",
    price: null,
    currency: "TRY",
    logoUrl: "logo",
    projectionUpdatedAt: new Date(),
  };
  assert.equal(hasCompleteProjection(complete), true);
  const db = makeDb([
    ["complete", complete],
    ["missing-business", {
      ...baseProjection,
      businessId: "missing",
      targetId: "service/VET/missing/service-1",
    }],
  ], {"business-1": businessData});
  const result = await backfillPromotionFeaturedProjections({
    db,
    projectId: "demo-petsupo",
    apply: true,
    now: new Date("2026-08-08T10:00:00.000Z"),
  });
  assert.equal(result.unchanged, 1);
  assert.equal(result.invalidated, 1);
  assert.equal(result.updated, 1);
  assert.equal(db.writes.length, 1);
  assert.equal(db.writes[0].fields.featuredDealEligible, false);
});
