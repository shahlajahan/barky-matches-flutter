"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  PAYABLE_CONTRACT_VERSION,
  canonicalPayoutContract,
} = require("../payout/payableContract");
const {
  PAYOUT_SECTOR_ADAPTERS,
  getPayoutSectorAdapterByCollection,
} = require("../payout/sectorAdapters");

const EXPECTED_FIELDS = [
  "amount",
  "businessId",
  "currency",
  "currencyRaw",
  "holdAt",
  "holdReason",
  "note",
  "outstandingDebt",
  "paidAt",
  "previousStatus",
  "readyAt",
  "recoveryReason",
  "recoveryRequiredAt",
  "reference",
  "relatedReturnIds",
  "requestedAt",
  "sector",
  "status",
  "updatedAt",
  "version",
].sort();

const FIXTURES = {
  petshop: { businessId: "business-1" },
  vet: { businessId: "business-1" },
  groomy: { businessId: "business-1" },
  hotel: { businessId: "business-1" },
  taxi: { businessId: "business-1", finalPriceCurrency: "TRY" },
};

test("all supported sectors produce the identical canonical payout shape", () => {
  for (const [sector, adapter] of Object.entries(PAYOUT_SECTOR_ADAPTERS)) {
    const payout = adapter.normalizePayout({
      record: FIXTURES[sector],
      financial: { businessNetAmount: 80 },
      currency: "TRY",
      status: "pending",
      timestamp: "timestamp",
    });

    assert.deepEqual(Object.keys(payout).sort(), EXPECTED_FIELDS, sector);
    assert.equal(payout.version, PAYABLE_CONTRACT_VERSION);
    assert.equal(payout.sector, sector);
    assert.equal(payout.businessId, "business-1");
    assert.equal(payout.amount, 80);
  }
});

test("collection lookup is entirely adapter-driven", () => {
  assert.equal(
    getPayoutSectorAdapterByCollection("sellerOrders").sector,
    "petshop"
  );
  assert.equal(
    getPayoutSectorAdapterByCollection("vet_appointments").sector,
    "vet"
  );
  assert.equal(
    getPayoutSectorAdapterByCollection("groomy_appointments").sector,
    "groomy"
  );
  assert.equal(
    getPayoutSectorAdapterByCollection("hotel_bookings").sector,
    "hotel"
  );
  assert.equal(
    getPayoutSectorAdapterByCollection("pet_taxi_bookings").sector,
    "taxi"
  );
});

test("legacy Pet Shop payout values are preserved and normalized additively", () => {
  const payout = PAYOUT_SECTOR_ADAPTERS.petshop.normalizePayout({
    record: { shopId: "shop-1" },
    financial: { businessNetAmount: 90 },
    existingPayout: {
      status: "ready",
      amount: 90,
      currency: "TRY",
      readyAt: "ready-at",
      reference: "legacy-reference",
    },
  });

  assert.equal(payout.status, "ready");
  assert.equal(payout.readyAt, "ready-at");
  assert.equal(payout.reference, "legacy-reference");
  assert.equal(payout.businessId, "shop-1");
  assert.deepEqual(Object.keys(payout).sort(), EXPECTED_FIELDS);
});

test("explicit payment transition status overrides a legacy pending status", () => {
  const payout = canonicalPayoutContract({
    sector: "petshop",
    businessId: "business-1",
    amount: 50,
    currency: "TRY",
    status: "pending",
    timestamp: "now",
    existingPayout: { status: "payment_pending", amount: 50 },
  });
  assert.equal(payout.status, "pending");
  assert.equal(payout.requestedAt, "now");
});

test("production payment finalizers persist payment and financial state before settlement", () => {
  const source = fs.readFileSync(
    path.resolve(__dirname, "../index.js"),
    "utf8"
  );

  assert.doesNotMatch(source, /function normalizePaidPayout\(/);
  assert.match(source, /paymentStatus: "paid",[\s\S]*?financial,/);
  assert.match(source, /await settlePayable\(/);
  assert.doesNotMatch(source, /paymentStatus: "paid",[\s\S]*?payout:\s*normalize/);
  assert.match(source, /canonicalPayoutContract\(\{\s*sector: "petshop"/);
});
