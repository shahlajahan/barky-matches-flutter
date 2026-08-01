"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  SETTLEMENT_STATUS,
  settlePayable,
} = require("../settlement/settlementFinalizer");

function fakeDb(record) {
  let eventId = 0;
  const data = new Map([["sellerOrders/order-1", record]]);
  const writes = [];

  function collection(name) {
    return {
      doc(id) {
        const actualId = id || `event-${++eventId}`;
        return { id: actualId, path: `${name}/${actualId}` };
      },
    };
  }

  return {
    collection,
    writes,
    async runTransaction(callback) {
      const staged = [];
      const transaction = {
        async get(ref) {
          const value = data.get(ref.path);
          return { exists: value !== undefined, data: () => value };
        },
        set(ref, value, options) {
          staged.push({ operation: "set", ref, value, options });
        },
        create(ref, value) {
          staged.push({ operation: "create", ref, value });
        },
      };
      const result = await callback(transaction);
      for (const write of staged) {
        writes.push(write);
        if (write.operation === "set") {
          const current = data.get(write.ref.path) || {};
          data.set(write.ref.path, {
            ...current,
            ...write.value,
            ...(write.value.settlement
              ? { settlement: { ...(current.settlement || {}), ...write.value.settlement } }
              : {}),
            ...(write.value.payout
              ? { payout: { ...(current.payout || {}), ...write.value.payout } }
              : {}),
          });
        }
      }
      return result;
    },
  };
}

const baseRecord = {
  businessId: "business-1",
  financialStatus: "verified",
  financial: {
    finalPrice: 100,
    commissionAmount: 20,
    businessNetAmount: 80,
    currency: "TRY",
  },
  payout: { status: "payment_pending" },
};

test("negative payable blocks settlement without creating a payout contract", async () => {
  const db = fakeDb({
    ...baseRecord,
    financial: { ...baseRecord.financial, businessNetAmount: -70 },
  });

  const result = await settlePayable({
    db,
    sector: "petshop",
    recordRef: db.collection("sellerOrders").doc("order-1"),
  });

  assert.equal(result.status, SETTLEMENT_STATUS.BLOCKED);
  const sourceWrites = db.writes.filter((write) => write.ref.path === "sellerOrders/order-1");
  const finalWrite = sourceWrites[sourceWrites.length - 1];
  assert.equal(finalWrite.value.settlement.status, SETTLEMENT_STATUS.BLOCKED);
  assert.equal(finalWrite.value.settlement.reason, "NEGATIVE_PAYABLE");
  assert.equal(finalWrite.value.payout, undefined);
  assert.equal(db.writes.filter((write) => write.operation === "create").length, 1);
});

test("valid frozen snapshot completes settlement and creates the payout contract", async () => {
  const db = fakeDb(baseRecord);

  const result = await settlePayable({
    db,
    sector: "petshop",
    recordRef: db.collection("sellerOrders").doc("order-1"),
  });

  assert.equal(result.status, SETTLEMENT_STATUS.COMPLETED);
  const finalWrite = db.writes
    .filter((write) => write.ref.path === "sellerOrders/order-1")
    .at(-1);
  assert.equal(finalWrite.value.settlement.status, SETTLEMENT_STATUS.COMPLETED);
  assert.equal(finalWrite.value.payout.amount, 80);
  assert.equal(finalWrite.value.payout.status, "pending");
});

test("payment-success records with repair-required finance are blocked before payout", async () => {
  const db = fakeDb({
    ...baseRecord,
    financialStatus: "requires_repair",
  });

  const result = await settlePayable({
    db,
    sector: "petshop",
    recordRef: db.collection("sellerOrders").doc("order-1"),
  });

  assert.equal(result.status, SETTLEMENT_STATUS.BLOCKED);
  assert.equal(result.reason, "FINANCIAL_REPAIR_REQUIRED");
  const finalWrite = db.writes
    .filter((write) => write.ref.path === "sellerOrders/order-1")
    .at(-1);
  assert.equal(finalWrite.value.settlement.status, SETTLEMENT_STATUS.BLOCKED);
  assert.equal(finalWrite.value.settlement.failureCode, "FINANCIAL_REPAIR_REQUIRED");
  assert.equal(finalWrite.value.payout, undefined);
});

test("payment finalizer persists payment before settlement and does not construct payout inline", () => {
  const source = fs.readFileSync(
    path.resolve(__dirname, "../index.js"),
    "utf8"
  );
  const appointmentFinalizer = source.match(
    /async function finalizeAppointmentAfterPaid\([\s\S]*?\n}\n\nasync function finalizeIsbankPaidOrder/
  )?.[0];
  assert.ok(appointmentFinalizer);
  assert.match(appointmentFinalizer, /paymentStatus: "paid"/);
  assert.match(appointmentFinalizer, /payment\.finalizationStatus.*completed/);
  assert.match(appointmentFinalizer, /await appointmentRef\.update\(\{ financial \}\)/);
  assert.doesNotMatch(appointmentFinalizer, /normalizePaidPayout/);
  assert.match(source, /await settlePayable\(/);
});

test("settlement retry endpoint is admin-only and settlement-only", () => {
  const source = fs.readFileSync(
    path.resolve(__dirname, "../index.js"),
    "utf8"
  );
  const retry = source.match(
    /exports\.retrySettlement = onCall\([\s\S]*?\n\);/
  )?.[0];
  assert.ok(retry);
  assert.match(retry, /role !== "admin"/);
  assert.match(retry, /settlePayable\(/);
  assert.doesNotMatch(retry, /createIsbank|Iyzipay|checkoutForm|paymentProvider/);
});
