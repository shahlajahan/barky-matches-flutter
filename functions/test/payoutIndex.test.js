"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildPayoutIndexId,
  normalizePayoutIndexRecord,
  validateIndexablePayoutContract,
  isStaleProjection,
} = require("../payout/payoutIndex");

const sectors = [
  ["sellerOrders", "petshop", "shop-1"],
  ["vet_appointments", "vet", "vet-1"],
  ["groomy_appointments", "groomy", "groomy-1"],
  ["hotel_bookings", "hotel", "hotel-1"],
  ["pet_taxi_bookings", "taxi", "taxi-1"],
];

function record(sector, businessId, status = "pending") {
  return {
    businessId,
    payout: {
      version: 1,
      sector,
      businessId,
      status,
      amount: 10,
      currency: "TRY",
    },
    settlement: { status: "not_started" },
    updatedAt: new Date("2026-01-01T00:00:00Z"),
  };
}

test("payout index IDs are deterministic", () => {
  assert.equal(buildPayoutIndexId("sellerOrders", "abc"), "sellerOrders__abc");
  assert.equal(buildPayoutIndexId("sellerOrders", "abc"), buildPayoutIndexId("sellerOrders", "abc"));
  assert.notEqual(buildPayoutIndexId("sellerOrders", "abc"), buildPayoutIndexId("sellerOrders", "def"));
});

test("all five sector contracts normalize to the same projection shape", () => {
  for (const [collection, sector, id] of sectors) {
    const projection = normalizePayoutIndexRecord({
      sourceCollection: collection,
      sourceDocumentId: id,
      record: record(sector, `${sector}-business`),
      projectedAt: "projection-time",
      sourceUpdatedAt: "source-time",
    });
    assert.equal(projection.sourceCollection, collection);
    assert.equal(projection.sector, sector);
    assert.equal(projection.payoutStatus, "pending");
    assert.equal(projection.settlementStatus, "not_started");
    assert.equal(projection.projectionVersion, 7);
  }
});

test("projection normalization is idempotent", () => {
  const input = {
    sourceCollection: "sellerOrders",
    sourceDocumentId: "order-1",
    record: record("petshop", "shop-1"),
    projectedAt: "same",
    sourceUpdatedAt: "same-source",
  };
  assert.deepEqual(normalizePayoutIndexRecord(input), normalizePayoutIndexRecord(input));
});

test("appointment finalPrice is projected as gross and preserves the cent invariant", () => {
  const projection = normalizePayoutIndexRecord({
    sourceCollection: "vet_appointments",
    sourceDocumentId: "vet-paid",
    record: {
      ...record("vet", "vet-1"),
      financial: {
        finalPrice: 90,
        commissionAmount: 80,
        businessNetAmount: 10,
      },
    },
  });
  assert.equal(projection.grossAmount, 90);
  assert.equal(projection.commissionAmount, 80);
  assert.equal(projection.grossAmount, projection.commissionAmount + projection.amount);
});

test("stale source events cannot overwrite a newer projection", () => {
  const newer = { sourceUpdatedAt: new Date("2026-02-01"), payoutContractVersion: 1, projectionVersion: 1, projectedAt: new Date("2026-02-01") };
  const older = { sourceUpdatedAt: new Date("2026-01-01"), payoutContractVersion: 1, projectionVersion: 1, projectedAt: new Date("2026-02-02") };
  assert.equal(isStaleProjection(newer, older), true);
  assert.equal(isStaleProjection(null, older), false);
});

test("a newer projection schema refreshes unchanged source records", () => {
  const existing = {
    sourceUpdatedAt: new Date("2026-02-01"),
    payoutContractVersion: 1,
    projectionVersion: 1,
    projectedAt: new Date("2026-07-01"),
  };
  const enriched = {
    sourceUpdatedAt: new Date("2026-02-01"),
    payoutContractVersion: 1,
    projectionVersion: 3,
    projectedAt: new Date("2026-07-30"),
  };
  assert.equal(isStaleProjection(existing, enriched), false);
});

test("unsupported collections and invalid payouts are rejected", () => {
  assert.equal(validateIndexablePayoutContract({
    sourceCollection: "orders",
    sourceDocumentId: "x",
    record: record("petshop", "shop-1"),
  }).valid, false);
  assert.equal(validateIndexablePayoutContract({
    sourceCollection: "sellerOrders",
    sourceDocumentId: "x",
    record: { ...record("petshop", "shop-1"), payout: { ...record("petshop", "shop-1").payout, amount: -1 } },
  }).reason, "INVALID_PAYOUT_AMOUNT");
});

test("blocked and awaiting-invoice settlements remain indexable", () => {
  for (const settlementStatus of ["blocked", "awaiting_invoice"]) {
    const projection = normalizePayoutIndexRecord({
      sourceCollection: "sellerOrders",
      sourceDocumentId: settlementStatus,
      record: { ...record("petshop", "shop-1"), settlement: { status: settlementStatus } },
    });
    assert.equal(projection.settlementStatus, settlementStatus);
  }
});
