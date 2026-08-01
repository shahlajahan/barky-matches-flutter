"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  eligibilityDateMillis,
  evaluatePayoutEligibility,
  verifiedPaymentTimestamp,
} = require("../finance/financeEligibility");

const paidAt = new Date("2026-07-01T10:00:00.000Z");

function paidRecord(overrides = {}) {
  return {
    status: "paid",
    paymentStatus: "paid",
    paidAt,
    payment: {
      status: "paid",
      finalizationStatus: "completed",
      finalizationCompletedAt: paidAt,
    },
    settlement: { status: "completed" },
    payout: { status: "pending" },
    ...overrides,
  };
}

test("record remains waiting until the start of the 22nd Istanbul day", () => {
  const boundary = eligibilityDateMillis(paidAt.getTime());
  const result = evaluatePayoutEligibility({
    record: paidRecord(),
    nowMillis: boundary - 1,
  });
  assert.equal(result.status, "waiting_period");
});

test("record becomes eligible at Istanbul midnight on the 22nd day", () => {
  const boundary = eligibilityDateMillis(paidAt.getTime());
  assert.equal(new Date(boundary).toISOString(), "2026-07-21T21:00:00.000Z");
  const result = evaluatePayoutEligibility({
    record: paidRecord(),
    nowMillis: boundary,
  });
  assert.equal(result.status, "eligible");
});

test("creation and update dates are never payment-verification fallbacks", () => {
  const record = paidRecord({
    paidAt: null,
    createdAt: new Date("2026-01-01"),
    updatedAt: new Date("2026-07-01"),
    payment: { status: "paid" },
  });
  assert.equal(verifiedPaymentTimestamp(record), null);
  assert.equal(
    evaluatePayoutEligibility({ record, nowMillis: Date.now() }).status,
    "blocked"
  );
});

test("callback validation timestamp wins over later finalization timestamp", () => {
  const callbackAt = new Date("2026-07-01T09:59:00Z");
  const result = verifiedPaymentTimestamp(
    paidRecord({
      payment: {
        callbackValidated: true,
        callbackValidatedAt: callbackAt,
        finalizationStatus: "completed",
        finalizationCompletedAt: paidAt,
      },
    })
  );
  assert.equal(result.source, "payment.callbackValidatedAt");
  assert.equal(result.millis, callbackAt.getTime());
});

test("manual, fraud, compliance, and tax holds use ON_HOLD", () => {
  for (const patch of [
    { financeHold: { active: true, reason: "manual" } },
    { fraudReview: true },
    { complianceHold: true },
    { taxReview: true },
  ]) {
    assert.equal(
      evaluatePayoutEligibility({
        record: paidRecord(patch),
        nowMillis: eligibilityDateMillis(paidAt.getTime()),
      }).status,
      "on_hold"
    );
  }
  assert.equal(
    evaluatePayoutEligibility({
      record: paidRecord({ payout: { status: "hold" } }),
      nowMillis: Date.now(),
    }).status,
    "on_hold"
  );
});

test("refunds and cancellations never inflate waiting or eligible states", () => {
  for (const status of ["refunded", "cancelled", "reversed"]) {
    assert.ok(
      ["reversed", "cancelled"].includes(
        evaluatePayoutEligibility({
          record: paidRecord({ status }),
          nowMillis: eligibilityDateMillis(paidAt.getTime()),
        }).status
      )
    );
  }
});

test("batch and paid states override elapsed eligibility", () => {
  const record = paidRecord();
  assert.equal(
    evaluatePayoutEligibility({
      record,
      nowMillis: eligibilityDateMillis(paidAt.getTime()),
      batchId: "batch-1",
    }).status,
    "batched"
  );
  assert.equal(
    evaluatePayoutEligibility({
      record: paidRecord({ payout: { status: "paid" } }),
      nowMillis: eligibilityDateMillis(paidAt.getTime()),
    }).status,
    "paid"
  );
});
