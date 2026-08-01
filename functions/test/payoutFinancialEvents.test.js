"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  financialEventData,
  FINANCIAL_EVENTS_COLLECTION,
} = require("../payout/financialEvents");
const {
  markPayoutReady,
  markPayoutPaid,
  applyRefundToPayout,
} = require("../payout/payoutEngine");

function fakeDb({
  payoutStatus = "pending",
  payoutFields = {},
  financial = {
    grossAmount: 150,
    commissionAmount: 24.5,
    businessNetAmount: 125.5,
  },
  pricing = { subtotal: 150, grandTotal: 150 },
  failEventCreate = false,
} = {}) {
  let generatedId = 0;
  const data = new Map([
    [
      "sellerOrders/order-1",
      {
        businessId: "business-1",
        payout: {
          status: payoutStatus,
          amount: 125.5,
          currency: "TRY",
          ...payoutFields,
        },
        financial,
        pricing,
        rootOrderId: "root-order-1",
        settlement: { status: "completed" },
      },
    ],
    [
      "businesses/business-1",
      { payment: { accountHolder: "Pet Shop", iban: "TR123456789012345678901234" } },
    ],
  ]);
  const commits = [];

  function collection(name) {
    return {
      doc(id) {
        const documentId = id || `generated-${++generatedId}`;
        return { id: documentId, path: `${name}/${documentId}` };
      },
      where() {
        return {
          kind: "query",
          where() {
            return this;
          },
        };
      },
    };
  }

  return {
    collection,
    commits,
    async runTransaction(callback) {
      const staged = [];
      const transaction = {
        async get(target) {
          if (target.kind === "query") return { docs: [] };
          const value = data.get(target.path);
          return {
            exists: value !== undefined,
            data: () => value,
          };
        },
        set(ref, value, options) {
          staged.push({ operation: "set", ref, value, options });
        },
        create(ref, value) {
          if (
            failEventCreate &&
            ref.path.startsWith(`${FINANCIAL_EVENTS_COLLECTION}/`)
          ) {
            throw new Error("ledger unavailable");
          }
          staged.push({ operation: "create", ref, value });
        },
      };
      const result = await callback(transaction);
      commits.push(...staged);
      return result;
    },
  };
}

test("financial event schema contains every architecture field", () => {
  const event = financialEventData({
    eventType: "payout_ready",
    sourceCollection: "sellerOrders",
    sourceDocument: "order-1",
    sector: "petshop",
    businessId: "business-1",
    actor: { type: "user", id: "admin-1" },
    previousState: "pending",
    newState: "ready",
    amount: 125.5,
    currency: "TRY",
    reason: "payout_marked_ready",
    metadata: {},
    timestamp: "timestamp",
  });

  assert.deepEqual(event, {
    eventType: "payout_ready",
    sourceCollection: "sellerOrders",
    sourceDocument: "order-1",
    sector: "petshop",
    business: "business-1",
    actor: { type: "user", id: "admin-1" },
    previousState: "pending",
    newState: "ready",
    amount: 125.5,
    currency: "TRY",
    occurredAt: "timestamp",
    createdAt: "timestamp",
    reason: "payout_marked_ready",
    metadata: {},
  });
});

test("markPayoutReady is idempotent and emits no duplicate event", async () => {
  const db = fakeDb({ payoutStatus: "ready" });

  const result = await markPayoutReady({
    db,
    sector: "petshop",
    payableId: "order-1",
    actor: { type: "user", id: "admin-1" },
  });

  assert.equal(result.transitioned, false);
  assert.equal(db.commits.length, 0);
});

test("ready transition and financial event commit together", async () => {
  const db = fakeDb();

  const result = await markPayoutReady({
    db,
    sector: "petshop",
    payableId: "order-1",
    actor: { type: "user", id: "admin-1" },
  });

  assert.equal(result.transitioned, true);
  assert.equal(db.commits.filter((write) => write.operation === "set").length, 2);
  const events = db.commits.filter(
    (write) =>
      write.operation === "create" &&
      write.ref.path.startsWith(`${FINANCIAL_EVENTS_COLLECTION}/`)
  );
  assert.equal(events.length, 1);
  assert.equal(events[0].value.previousState, "pending");
  assert.equal(events[0].value.newState, "ready");
});

test("payout transition fails when financial event cannot be created", async () => {
  const db = fakeDb({ failEventCreate: true });

  await assert.rejects(
    markPayoutReady({
      db,
      sector: "petshop",
      payableId: "order-1",
      actor: { type: "user", id: "admin-1" },
    }),
    /ledger unavailable/
  );
  assert.equal(db.commits.length, 0);
});

test("paid transition emits exactly one immutable event", async () => {
  const db = fakeDb({ payoutStatus: "ready" });

  await markPayoutPaid({
    db,
    sector: "petshop",
    payableId: "order-1",
    reference: "BANK-123",
    note: "July payout",
    actor: { type: "user", id: "admin-1" },
  });

  const events = db.commits.filter((write) => write.operation === "create");
  assert.equal(events.length, 1);
  assert.equal(events[0].value.eventType, "payout_paid");
  assert.equal(events[0].value.previousState, "ready");
  assert.equal(events[0].value.newState, "paid");
  assert.deepEqual(events[0].value.metadata, {
    reference: "BANK-123",
    note: "July payout",
  });
});

for (const status of [
  "pending",
  "payment_pending",
  "payment_failed",
  "hold",
  "recovery_required",
  "paid",
]) {
  test(`${status} → paid is rejected`, async () => {
    const db = fakeDb({ payoutStatus: status });

    await assert.rejects(
      markPayoutPaid({
        db,
        sector: "petshop",
        payableId: "order-1",
        reference: "BANK-123",
      }),
      (error) =>
        error.code === "failed-precondition" &&
        error.message.includes(`currently "${status}"`) &&
        error.message.includes("Only Ready payouts can be marked as Paid")
    );
    assert.equal(db.commits.length, 0);
  });
}

test("refund transition emits one event and duplicate refund is a no-op", async () => {
  const db = fakeDb();

  await applyRefundToPayout({
    db,
    sector: "petshop",
    payableId: "order-1",
    refundEventId: "return-1",
    refundAmount: 25,
    reason: "order_return_refund",
    actor: { type: "user", id: "admin-1" },
  });

  const events = db.commits.filter((write) => write.operation === "create");
  assert.equal(events.length, 4);
  const financialEvent = events.find(
    (write) => write.value.eventType === "payout_refund_applied"
  );
  assert.ok(financialEvent);
  assert.equal(financialEvent.value.previousState, "pending");
  assert.equal(financialEvent.value.newState, "hold");
  assert.deepEqual(
    events
      .filter((write) => write.ref.path.startsWith("financeLedger/"))
      .map((write) => write.value.eventType)
      .sort(),
    [
      "commission_reversed",
      "customer_refund",
      "seller_liability_reversed",
    ]
  );

  const duplicateDb = fakeDb({
    payoutStatus: "hold",
    payoutFields: { relatedReturnIds: ["return-1"] },
  });
  const duplicate = await applyRefundToPayout({
    db: duplicateDb,
    sector: "petshop",
    payableId: "order-1",
    refundEventId: "return-1",
    refundAmount: 25,
    reason: "order_return_refund",
  });
  assert.deepEqual(duplicate, {
    applied: false,
    reason: "refund_already_applied",
  });
  assert.equal(duplicateDb.commits.length, 0);
});

test("full refund reverses customer charge, commission, and pending payout", async () => {
  const db = fakeDb({
    payoutFields: { amount: 4.45 },
    financial: {
      grossAmount: 5.05,
      commissionAmount: 0.6,
      businessNetAmount: 4.45,
    },
    pricing: { subtotal: 5, grandTotal: 5.05 },
  });

  const result = await applyRefundToPayout({
    db,
    sector: "petshop",
    payableId: "order-1",
    refundEventId: "cancel_order-1",
    refundAmount: 5.05,
    refundedCommissionBase: 5,
    isFullRefund: true,
    rootOrderId: "root-order-1",
    reason: "pre_shipment_cancellation_refund",
    actor: { type: "user", id: "buyer-1" },
  });

  assert.equal(result.reversal.customerRefundAmount, 5.05);
  assert.equal(result.reversal.commissionReversalAmount, 0.6);
  assert.equal(result.reversal.sellerPayoutReversalAmount, 4.45);
  assert.equal(result.reversal.remainingCustomerBalance, 0);
  assert.equal(result.reversal.remainingPlatformRevenue, 0);
  assert.equal(result.reversal.remainingBusinessReceivable, 0);

  const sellerWrite = db.commits.find(
    (write) =>
      write.operation === "set" &&
      write.ref.path === "sellerOrders/order-1"
  );
  assert.equal(sellerWrite.value.payout.status, "hold");
  assert.equal(sellerWrite.value.payout.amount, 0);
  assert.equal(
    sellerWrite.value.financial.refundReconciliation
      .remainingPlatformRevenue,
    0
  );
  assert.equal(sellerWrite.value.financial.grossAmount, 5.05);
  assert.equal(sellerWrite.value.financial.commissionAmount, 0.6);
  assert.equal(sellerWrite.value.financial.businessNetAmount, 4.45);
  assert.equal(
    sellerWrite.value.settlement.refundReconciliation
      .remainingBusinessReceivable,
    0
  );

  const indexWrite = db.commits.find(
    (write) =>
      write.operation === "set" &&
      write.ref.path === "payoutIndex/sellerOrders__order-1"
  );
  assert.equal(indexWrite.value.payoutStatus, "hold");
  assert.equal(indexWrite.value.amount, 0);
  assert.notEqual(indexWrite.value.payoutStatus, "pending");
  assert.notEqual(indexWrite.value.payoutStatus, "ready");

  const event = db.commits.find(
    (write) =>
      write.operation === "create" &&
      write.value.eventType === "payout_refund_applied"
  );
  assert.equal(event.value.amount, 5.05);
  assert.equal(event.value.metadata.originalCustomerCharge, 5.05);
  assert.equal(event.value.metadata.originalCommission, 0.6);
  assert.equal(event.value.metadata.originalSellerReceivable, 4.45);
  assert.equal(event.value.metadata.commissionReversalAmount, 0.6);
  assert.equal(event.value.metadata.sellerPayoutReversalAmount, 4.45);
  assert.equal(event.value.metadata.remainingPlatformRevenue, 0);
  assert.equal(event.value.metadata.remainingBusinessReceivable, 0);
  assert.equal(event.value.metadata.rootOrderId, "root-order-1");
  assert.equal(event.value.metadata.refundEventId, "cancel_order-1");
});

test("refund after a paid payout creates seller recovery for net only", async () => {
  const db = fakeDb({
    payoutStatus: "paid",
    payoutFields: { amount: 4.45 },
    financial: {
      grossAmount: 5.05,
      commissionAmount: 0.6,
      businessNetAmount: 4.45,
    },
    pricing: { subtotal: 5, grandTotal: 5.05 },
  });

  await applyRefundToPayout({
    db,
    sector: "petshop",
    payableId: "order-1",
    refundEventId: "return-paid-1",
    refundAmount: 5.05,
    refundedCommissionBase: 5,
    isFullRefund: true,
    reason: "order_return_refund",
  });

  const debtWrite = db.commits.find(
    (write) =>
      write.operation === "set" &&
      write.ref.path === "sellerDebts/return-paid-1"
  );
  assert.equal(debtWrite.value.refundAmount, 5.05);
  assert.equal(debtWrite.value.commissionReversalAmount, 0.6);
  assert.equal(debtWrite.value.sellerDebt, 4.45);

  const sellerWrite = db.commits.find(
    (write) =>
      write.operation === "set" &&
      write.ref.path === "sellerOrders/order-1"
  );
  assert.equal(sellerWrite.value.payout.status, "recovery_required");
  assert.equal(sellerWrite.value.payout.amount, 4.45);
});

test("partial refund reverses only its proportional commission and payout", async () => {
  const db = fakeDb({
    payoutFields: { amount: 88 },
    financial: {
      grossAmount: 100,
      commissionAmount: 12,
      businessNetAmount: 88,
    },
    pricing: { subtotal: 100, grandTotal: 100 },
  });

  const result = await applyRefundToPayout({
    db,
    sector: "petshop",
    payableId: "order-1",
    refundEventId: "return-partial-1",
    refundAmount: 25,
    refundedCommissionBase: 25,
    isFullRefund: false,
    reason: "order_return_refund",
  });

  assert.equal(result.reversal.customerRefundAmount, 25);
  assert.equal(result.reversal.commissionReversalAmount, 3);
  assert.equal(result.reversal.sellerPayoutReversalAmount, 22);
  assert.equal(result.reversal.remainingPlatformRevenue, 9);
  assert.equal(result.reversal.remainingBusinessReceivable, 66);
});
