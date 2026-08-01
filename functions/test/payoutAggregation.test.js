"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  aggregatePayoutRecords,
  payoutValidationReasons,
} = require("../payout/payoutAggregation");

function record(overrides = {}) {
  return {
    indexId: "idx-1",
    businessId: "business-1",
    businessName: "Petsüpo Shop",
    legalBusinessName: "Petsüpo Ltd.",
    accountHolderName: "Petsüpo Ltd.",
    iban: "TR123456789012345678901234",
    bankName: "Türkiye İş Bankası",
    taxNumber: "1234567890",
    contactEmail: "finance@example.com",
    contactPhone: "+905001112233",
    currency: "TRY",
    payoutStatus: "pending",
    eligibilityStatus: "eligible",
    settlementStatus: "completed",
    sourceStatus: "paid",
    amount: 4.45,
    grossAmount: 5.05,
    commissionAmount: 0.6,
    sourceDocumentId: "seller-order-1",
    sourceCreatedMillis: 1000,
    batchId: null,
    ...overrides,
  };
}

test("multiple seller orders aggregate into one deterministic seller payment", () => {
  const groups = aggregatePayoutRecords([
    record(),
    record({
      indexId: "idx-2",
      sourceDocumentId: "seller-order-2",
      amount: 10.1,
      grossAmount: 10.1,
      commissionAmount: 0,
      sourceCreatedMillis: 2000,
    }),
  ]);
  assert.equal(groups.length, 1);
  assert.equal(groups[0].payoutCount, 2);
  assert.equal(groups[0].grossTotal, 15.15);
  assert.equal(groups[0].commissionTotal, 0.6);
  assert.equal(groups[0].netTotal, 14.55);
  assert.deepEqual(groups[0].sourceDocumentIds, [
    "seller-order-1",
    "seller-order-2",
  ]);
});

test("different sellers, currencies, and bank recipients remain separate", () => {
  const groups = aggregatePayoutRecords([
    record(),
    record({ businessId: "business-2", indexId: "idx-2" }),
    record({ currency: "USD", indexId: "idx-3" }),
    record({
      accountHolderName: "Different Recipient",
      indexId: "idx-4",
    }),
  ]);
  assert.equal(groups.length, 4);
});

test("refunded, reversed, invalid-bank, and batched records are blocked", () => {
  assert.ok(
    payoutValidationReasons(record({ sourceStatus: "refunded" })).includes(
      "refunded_or_cancelled"
    )
  );
  assert.ok(
    payoutValidationReasons(record({ sourceStatus: "reversed" })).includes(
      "refunded_or_cancelled"
    )
  );
  assert.ok(
    payoutValidationReasons(record({ iban: "TR123" })).includes("invalid_iban")
  );
  assert.ok(
    payoutValidationReasons(record({ batchId: "batch-1" })).includes(
      "already_batched"
    )
  );
});

test("commission-unknown records are exceptions and never become payable totals", () => {
  const [group] = aggregatePayoutRecords([
    {
      businessId: "seller-1",
      currency: "TRY",
      payoutStatus: "pending",
      settlementStatus: "completed",
      eligibilityStatus: "eligible",
      commissionDataQuality: "ambiguous_legacy",
      amount: 88,
      grossAmount: 100,
      commissionAmount: 12,
    },
  ]);
  assert.equal(group.grossTotal, 0);
  assert.equal(group.netTotal, 0);
  assert.ok(group.validationReasons.includes("commission_unknown"));
});

test("reserved records are valid only for their own batch revalidation", () => {
  const value = record({
    batchId: "batch-1",
    eligibilityStatus: "batched",
  });
  assert.deepEqual(
    payoutValidationReasons(value, { allowReservedBatchId: "batch-1" }),
    []
  );
  assert.ok(
    payoutValidationReasons(value, {
      allowReservedBatchId: "batch-2",
    }).includes("already_batched")
  );
});
