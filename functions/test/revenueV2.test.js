"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  aggregateRevenueFacts,
  classifyEntitlement,
  classifyOrderPayment,
  computeRevenueMetrics,
  startOfIstanbulMonth,
} = require("../revenue/computeRevenueMetrics");
const {
  shouldRecomputeForOrderChange,
} = require("../revenue/onOrderChanged");
const { writeRevenueMetrics } = require("../revenue/writeRevenueMetrics");

const now = new Date("2026-08-20T11:00:00.000Z");

function order(id, overrides = {}) {
  return {
    id,
    data: {
      orderType: "web_subscription",
      buyerUid: "user-a",
      planId: "gold",
      status: "paid",
      paymentStatus: "paid",
      paidAt: new Date("2026-08-20T09:00:00.000Z"),
      pricing: { grandTotal: 10, currency: "TRY" },
      payment: {
        provider: "isbank",
        paymentId: id,
        status: "paid",
        finalizationStatus: "completed",
        callbackValidated: true,
        amount: 10,
        currency: "TRY",
      },
      ...overrides,
    },
  };
}

function sub(id, overrides = {}) {
  return {
    id,
    data: {
      userId: id,
      plan: "gold",
      status: "active",
      source: "web_isbank",
      expiresAt: new Date("2026-09-20T09:00:00.000Z"),
      ...overrides,
    },
  };
}

function business(id, overrides = {}) {
  return {
    id,
    data: {
      status: "approved",
      ownerUid: `owner-${id}`,
      subscription: { plan: "free", status: "active" },
      ...overrides,
    },
  };
}

function metrics(input) {
  return aggregateRevenueFacts({ now, ...input });
}

function snapshot(items) {
  return {
    forEach(callback) {
      for (const item of items) {
        callback({
          id: item.id,
          data: () => item.data,
        });
      }
    },
  };
}

function fakeDb({ subscriptions = [], businesses = [], orders = [] }) {
  return {
    collection(name) {
      return {
        where(field, op, value) {
          assert.equal(name, "orders");
          assert.equal(field, "orderType");
          assert.equal(op, "==");
          assert.equal(value, "web_subscription");
          return {
            async get() {
              return snapshot(orders.filter((entry) => entry.data.orderType === "web_subscription"));
            },
          };
        },
        async get() {
          if (name === "subscriptions") return snapshot(subscriptions);
          if (name === "businesses") return snapshot(businesses);
          throw new Error(`Unexpected collection ${name}`);
        },
      };
    },
  };
}

function fakeWriteDb(calls) {
  return {
    collection(name) {
      assert.equal(name, "admin_stats");
      return {
        doc(id) {
          assert.equal(id, "revenue_v2");
          return {
            async set(data, options) {
              calls.push({ data, options });
            },
          };
        },
      };
    },
  };
}

test("successful TRY web payment is recognized", () => {
  const result = metrics({ orders: [order("paid-1")] });
  assert.equal(result.financial.byCurrency.TRY.grossMinor, 1000);
  assert.equal(result.financial.byCurrency.TRY.netMinor, 1000);
  assert.equal(result.payments.successfulCount, 1);
  assert.equal(result.customers.payingCount, 1);
});

test("pending payment is excluded and tracked separately", () => {
  const result = metrics({
    orders: [
      order("pending-1", {
        status: "pending",
        paymentStatus: "pending",
        payment: { status: "pending", provider: "isbank", paymentId: "pending-1" },
      }),
    ],
  });
  assert.equal(result.payments.pendingCount, 1);
  assert.equal(result.payments.successfulCount, 0);
  assert.equal(result.financial.byCurrency.TRY.pendingMinor, 1000);
});

test("failed payment is excluded", () => {
  const result = metrics({
    orders: [
      order("failed-1", {
        status: "failed",
        paymentStatus: "failed",
        payment: { status: "failed", provider: "isbank", paymentId: "failed-1" },
      }),
    ],
  });
  assert.equal(result.payments.failedCount, 1);
  assert.equal(result.payments.successfulCount, 0);
  assert.deepEqual(result.financial.byCurrency, {});
});

test("admin grant with list price is excluded from revenue", () => {
  const result = metrics({
    subscriptions: [
      sub("grant-1", {
        source: "admin_grant",
        price: 9.99,
        listPrice: 9.99,
        paidAmount: 0,
        currency: "USD",
      }),
    ],
  });
  assert.equal(result.entitlements.adminGrantActive, 1);
  assert.equal(result.entitlements.paidActive, 0);
  assert.deepEqual(result.financial.byCurrency, {});
});

test("free active subscription is not paid", () => {
  const result = metrics({
    subscriptions: [sub("free-1", { plan: "normal", source: "free", expiresAt: null })],
  });
  assert.equal(result.entitlements.freeActive, 1);
  assert.equal(result.entitlements.paidActive, 0);
});

test("active paid-plan entitlement without payment evidence is unverified, not paid", () => {
  const result = metrics({ subscriptions: [sub("paid-1")] });
  assert.equal(result.entitlements.goldActive, 1);
  assert.equal(result.entitlements.paidActive, 0);
  assert.equal(result.entitlements.unverifiedPaidPlanActive, 1);
});

test("expired entitlement is excluded from paid active", () => {
  const result = metrics({
    subscriptions: [sub("expired-1", { expiresAt: new Date("2026-08-01T00:00:00.000Z") })],
  });
  assert.equal(result.entitlements.goldActive, 1);
  assert.equal(result.entitlements.paidActive, 0);
});

test("full refund nets to zero", () => {
  const result = metrics({
    orders: [
      order("refund-1", {
        refundStatus: "refunded",
        refundAmount: 10,
      }),
    ],
  });
  assert.equal(result.financial.byCurrency.TRY.grossMinor, 1000);
  assert.equal(result.financial.byCurrency.TRY.refundMinor, 1000);
  assert.equal(result.financial.byCurrency.TRY.netMinor, 0);
  assert.equal(result.payments.successfulCount, 1);
});

test("partial refund reduces net revenue", () => {
  const result = metrics({
    orders: [
      order("refund-2", {
        refundStatus: "partially_refunded",
        refundAmount: 4,
      }),
    ],
  });
  assert.equal(result.financial.byCurrency.TRY.grossMinor, 1000);
  assert.equal(result.financial.byCurrency.TRY.refundMinor, 400);
  assert.equal(result.financial.byCurrency.TRY.netMinor, 600);
  assert.equal(result.payments.successfulCount, 1);
});

test("mixed TRY and USD are kept separate", () => {
  const result = metrics({
    orders: [
      order("try-1"),
      order("usd-1", {
        buyerUid: "user-b",
        pricing: { grandTotal: 5, currency: "USD" },
        payment: {
          provider: "isbank",
          paymentId: "usd-1",
          status: "paid",
          finalizationStatus: "completed",
          callbackValidated: true,
          amount: 5,
          currency: "USD",
        },
      }),
    ],
  });
  assert.equal(result.financial.byCurrency.TRY.netMinor, 1000);
  assert.equal(result.financial.byCurrency.USD.netMinor, 500);
});

test("İş Bank numeric ISO currency code is normalized to TRY", () => {
  const result = metrics({
    orders: [
      order("numeric-currency", {
        payment: {
          provider: "isbank",
          transId: "numeric-currency-trans",
          status: "paid",
          finalizationStatus: "completed",
          callbackValidated: true,
          amount: "10.00",
          currency: "949",
        },
      }),
    ],
  });
  assert.equal(result.financial.byCurrency.TRY.netMinor, 1000);
  assert.equal(result.payments.successfulCount, 1);
});

test("unsupported numeric currency is incomplete and excluded", () => {
  const result = metrics({
    orders: [
      order("unsupported-currency", {
        payment: {
          provider: "isbank",
          transId: "unsupported-currency-trans",
          status: "paid",
          finalizationStatus: "completed",
          callbackValidated: true,
          amount: "10.00",
          currency: "999",
        },
      }),
    ],
  });
  assert.equal(result.payments.excludedCount, 1);
  assert.equal(
    result.coverage.incompleteSources.some((entry) => entry.reason === "missing_currency"),
    true
  );
});

test("duplicate payment identity is deduplicated", () => {
  const duplicate = order("duplicate-order", {
    buyerUid: "user-b",
    payment: {
      provider: "isbank",
      paymentId: "shared-payment",
      status: "paid",
      finalizationStatus: "completed",
      callbackValidated: true,
      amount: 10,
      currency: "TRY",
    },
  });
  const result = metrics({ orders: [order("first", {
    payment: {
      provider: "isbank",
      paymentId: "shared-payment",
      status: "paid",
      finalizationStatus: "completed",
      callbackValidated: true,
      amount: 10,
      currency: "TRY",
    },
  }), duplicate] });
  assert.equal(result.payments.successfulCount, 1);
  assert.equal(result.payments.duplicateCount, 1);
  assert.equal(result.financial.byCurrency.TRY.netMinor, 1000);
});

test("same transaction ID from different providers is not deduplicated", () => {
  const result = metrics({
    orders: [
      order("provider-a", {
        payment: {
          provider: "isbank",
          paymentId: "same-provider-id",
          status: "paid",
          finalizationStatus: "completed",
          callbackValidated: true,
          amount: 10,
          currency: "TRY",
        },
      }),
      order("provider-b", {
        buyerUid: "user-b",
        payment: {
          provider: "iyzico",
          paymentId: "same-provider-id",
          status: "paid",
          finalizationStatus: "completed",
          callbackValidated: true,
          amount: 10,
          currency: "TRY",
        },
      }),
    ],
  });
  assert.equal(result.payments.successfulCount, 2);
  assert.equal(result.payments.duplicateCount, 0);
  assert.equal(result.financial.byCurrency.TRY.netMinor, 2000);
});

test("missing currency is incomplete and excluded", () => {
  const result = metrics({
    orders: [
      order("missing-currency", {
        pricing: { grandTotal: 10 },
        payment: {
          provider: "isbank",
          paymentId: "missing-currency",
          status: "paid",
          finalizationStatus: "completed",
          callbackValidated: true,
          amount: 10,
        },
      }),
    ],
  });
  assert.equal(result.payments.excludedCount, 1);
  assert.equal(
    result.coverage.incompleteSources.some((entry) => entry.reason === "missing_currency"),
    true
  );
});

test("missing paid amount is incomplete and excluded", () => {
  const result = metrics({
    orders: [
      order("missing-amount", {
        pricing: { currency: "TRY" },
        payment: {
          provider: "isbank",
          paymentId: "missing-amount",
          status: "paid",
          finalizationStatus: "completed",
          callbackValidated: true,
          currency: "TRY",
        },
      }),
    ],
  });
  assert.equal(result.payments.excludedCount, 1);
  assert.equal(
    result.coverage.incompleteSources.some((entry) => entry.reason === "missing_positive_paid_amount"),
    true
  );
});

test("legacy subscription fields do not imply revenue", () => {
  const entitlement = classifyEntitlement({
    plan: "premium",
    status: "active",
    source: "legacy",
    price: 2.99,
    expiresAt: new Date("2026-09-01T00:00:00.000Z"),
  }, { now });
  assert.equal(entitlement.activePaidEntitlement, true);
  const result = metrics({
    subscriptions: [
      sub("legacy-1", {
        plan: "premium",
        source: "legacy",
        price: 2.99,
      }),
    ],
  });
  assert.equal(result.entitlements.premiumActive, 1);
  assert.equal(result.entitlements.paidActive, 0);
  assert.equal(result.entitlements.unverifiedPaidPlanActive, 1);
  assert.deepEqual(result.financial.byCurrency, {});
});

test("App Store entitlement without authoritative amount reports unavailable revenue", () => {
  const result = metrics({ subscriptions: [sub("app-1", { source: "app_store" })] });
  assert.equal(result.entitlements.goldActive, 1);
  assert.equal(result.entitlements.paidActive, 0);
  assert.equal(result.entitlements.unverifiedPaidPlanActive, 1);
  assert.equal(result.entitlements.storeRevenueUnavailable, 1);
  assert.equal(
    result.coverage.incompleteSources.some((entry) =>
      entry.source === "mobile_store_subscriptions" &&
      entry.reason === "authoritative_revenue_unavailable"
    ),
    true
  );
});

test("Google Play entitlement without authoritative amount reports unavailable revenue", () => {
  const result = metrics({ subscriptions: [sub("play-1", { source: "play_store" })] });
  assert.equal(result.entitlements.goldActive, 1);
  assert.equal(result.entitlements.paidActive, 0);
  assert.equal(result.entitlements.unverifiedPaidPlanActive, 1);
  assert.equal(result.entitlements.storeRevenueUnavailable, 1);
});

test("Istanbul month boundary includes local month only", () => {
  const monthNow = new Date("2026-08-20T11:00:00.000Z");
  assert.equal(startOfIstanbulMonth(monthNow).toISOString(), "2026-07-31T21:00:00.000Z");
  const result = aggregateRevenueFacts({
    now: monthNow,
    orders: [
      order("prev-local-month", { paidAt: new Date("2026-07-31T20:59:00.000Z") }),
      order("this-local-month", {
        buyerUid: "user-b",
        paidAt: new Date("2026-07-31T21:01:00.000Z"),
        payment: {
          provider: "isbank",
          paymentId: "this-local-month",
          status: "paid",
          finalizationStatus: "completed",
          callbackValidated: true,
          amount: 10,
          currency: "TRY",
        },
      }),
    ],
  });
  assert.equal(result.financial.byCurrency.TRY.grossMinor, 2000);
  assert.equal(result.financial.byCurrency.TRY.monthlyNetMinor, 1000);
});

test("Istanbul daylight boundary remains explicit UTC+03 for current production period", () => {
  assert.equal(
    startOfIstanbulMonth(new Date("2026-03-29T12:00:00.000Z")).toISOString(),
    "2026-02-28T21:00:00.000Z"
  );
});

test("ARPPU uses net revenue divided by paying customers", () => {
  const result = metrics({
    orders: [
      order("arppu-1", { buyerUid: "one" }),
      order("arppu-2", {
        buyerUid: "two",
        payment: {
          provider: "isbank",
          paymentId: "arppu-2",
          status: "paid",
          finalizationStatus: "completed",
          callbackValidated: true,
          amount: 10,
          currency: "TRY",
        },
      }),
    ],
  });
  assert.equal(result.financial.byCurrency.TRY.arppuMinor, 1000);
});

test("zero paying customers produces zero ARPPU", () => {
  const result = metrics({ orders: [] });
  assert.deepEqual(result.financial.byCurrency, {});
  assert.equal(result.customers.payingCount, 0);
});

test("approved business is separate from paid business subscription", () => {
  const result = metrics({ businesses: [business("b1")] });
  assert.equal(result.businesses.approvedCount, 1);
  assert.equal(result.businesses.paidSubscriptionCount, 0);
});

test("paid business subscription requires verified payment evidence", () => {
  const result = metrics({
    orders: [order("business-payment", { buyerUid: "owner-b1" })],
    businesses: [
      business("b1", {
        ownerUid: "owner-b1",
        subscription: {
          plan: "gold",
          status: "active",
          source: "web_isbank",
          expiresAt: new Date("2026-09-20T00:00:00.000Z"),
        },
      }),
    ],
  });
  assert.equal(result.businesses.approvedCount, 1);
  assert.equal(result.businesses.paidSubscriptionCount, 1);
});

test("active Gold linked to successful verified web payment is paid active", () => {
  const result = metrics({
    orders: [order("gold-paid-active", { buyerUid: "user-a", planId: "gold" })],
    subscriptions: [sub("user-a", { plan: "gold", source: "web_isbank" })],
  });
  assert.equal(result.entitlements.goldActive, 1);
  assert.equal(result.entitlements.paidActive, 1);
  assert.equal(result.entitlements.unverifiedPaidPlanActive, 0);
});

test("active Gold linked only to pending payment is not paid active", () => {
  const result = metrics({
    orders: [
      order("gold-pending-active", {
        buyerUid: "user-a",
        planId: "gold",
        status: "pending",
        paymentStatus: "pending",
        payment: {
          provider: "isbank",
          paymentId: "gold-pending-active",
          status: "pending",
        },
      }),
    ],
    subscriptions: [sub("user-a", { plan: "gold", source: "web_isbank" })],
  });
  assert.equal(result.entitlements.goldActive, 1);
  assert.equal(result.entitlements.paidActive, 0);
  assert.equal(result.entitlements.unverifiedPaidPlanActive, 1);
});

test("active Gold linked only to failed payment is not paid active", () => {
  const result = metrics({
    orders: [
      order("gold-failed-active", {
        buyerUid: "user-a",
        planId: "gold",
        status: "failed",
        paymentStatus: "failed",
        payment: {
          provider: "isbank",
          paymentId: "gold-failed-active",
          status: "failed",
        },
      }),
    ],
    subscriptions: [sub("user-a", { plan: "gold", source: "web_isbank" })],
  });
  assert.equal(result.entitlements.goldActive, 1);
  assert.equal(result.entitlements.paidActive, 0);
  assert.equal(result.entitlements.unverifiedPaidPlanActive, 1);
});

test("admin grant is never classified as paid", () => {
  const result = metrics({
    subscriptions: [sub("grant-2", { source: "admin_grant" })],
    businesses: [
      business("b1", {
        ownerUid: "grant-2",
        subscription: {
          plan: "gold",
          status: "active",
          source: "admin_grant",
          expiresAt: new Date("2026-09-20T00:00:00.000Z"),
        },
      }),
    ],
  });
  assert.equal(result.entitlements.adminGrantActive, 1);
  assert.equal(result.entitlements.goldActive, 1);
  assert.equal(result.entitlements.paidActive, 0);
  assert.equal(result.businesses.paidSubscriptionCount, 0);
});

test("production-like admin grants with USD list price recognize zero revenue", () => {
  const subscriptions = Array.from({ length: 5 }, (_, index) =>
    sub(`grant-${index}`, {
      source: "admin_grant",
      price: 9.99,
      listPrice: 9.99,
      paidAmount: 0,
      currency: "USD",
    })
  );
  const result = metrics({ subscriptions });
  assert.equal(result.entitlements.adminGrantActive, 5);
  assert.deepEqual(result.financial.byCurrency, {});
});

test("production-like web payments total TRY 20 and exclude failed and pending orders", () => {
  const result = metrics({
    orders: [
      order("gold-paid-1"),
      order("gold-paid-2", {
        buyerUid: "user-b",
        payment: {
          provider: "isbank",
          paymentId: "gold-paid-2",
          status: "paid",
          finalizationStatus: "completed",
          callbackValidated: true,
          amount: 10,
          currency: "TRY",
        },
      }),
      order("gold-failed", {
        status: "failed",
        paymentStatus: "failed",
        payment: { status: "failed", provider: "isbank", paymentId: "gold-failed" },
      }),
      order("premium-pending", {
        planId: "premium",
        status: "pending",
        paymentStatus: "pending",
        pricing: { grandTotal: 199, currency: "TRY" },
        payment: { status: "pending", provider: "isbank", paymentId: "premium-pending" },
      }),
    ],
  });
  assert.equal(result.financial.byCurrency.TRY.grossMinor, 2000);
  assert.equal(result.payments.successfulCount, 2);
  assert.equal(result.payments.failedCount, 1);
  assert.equal(result.payments.pendingCount, 1);
});

test("unvalidated paid-looking order is not recognized", () => {
  const result = metrics({
    orders: [
      order("unvalidated", {
        payment: {
          provider: "isbank",
          paymentId: "unvalidated",
          status: "paid",
          finalizationStatus: "completed",
          amount: 10,
          currency: "TRY",
        },
      }),
    ],
  });
  assert.equal(result.payments.excludedCount, 1);
  assert.equal(result.payments.successfulCount, 0);
});

test("order payment transition pending to paid produces recognized v2 result", () => {
  const pending = metrics({
    orders: [
      order("transition", {
        status: "pending",
        paymentStatus: "pending",
        payment: { status: "pending", provider: "isbank", paymentId: "transition" },
      }),
    ],
  });
  assert.equal(pending.payments.pendingCount, 1);
  assert.equal(pending.payments.successfulCount, 0);

  const paid = metrics({ orders: [order("transition")] });
  assert.equal(paid.payments.pendingCount, 0);
  assert.equal(paid.payments.successfulCount, 1);
  assert.equal(paid.financial.byCurrency.TRY.netMinor, 1000);
});

test("paid to refunded preserves gross and records refund", () => {
  const paid = metrics({ orders: [order("paid-refund-transition")] });
  assert.equal(paid.financial.byCurrency.TRY.grossMinor, 1000);
  assert.equal(paid.financial.byCurrency.TRY.refundMinor, 0);
  assert.equal(paid.financial.byCurrency.TRY.netMinor, 1000);

  const refunded = metrics({
    orders: [
      order("paid-refund-transition", {
        refundStatus: "refunded",
        refundAmount: 10,
      }),
    ],
  });
  assert.equal(refunded.financial.byCurrency.TRY.grossMinor, 1000);
  assert.equal(refunded.financial.byCurrency.TRY.refundMinor, 1000);
  assert.equal(refunded.financial.byCurrency.TRY.netMinor, 0);
});

test("missing input is reported incomplete and not treated as complete revenue", () => {
  const result = metrics({
    orders: [
      order("incomplete", {
        pricing: { currency: "TRY" },
        payment: {
          provider: "isbank",
          paymentId: "incomplete",
          status: "paid",
          finalizationStatus: "completed",
          callbackValidated: true,
          currency: "TRY",
        },
      }),
    ],
  });
  assert.equal(result.payments.successfulCount, 0);
  assert.equal(result.payments.excludedCount, 1);
  assert.equal(result.coverage.incompleteSources.length > 0, true);
});

test("writer replaces only revenue_v2 and rejects non-v2 metrics", async () => {
  const calls = [];
  const result = metrics({ orders: [order("paid-1")] });

  await writeRevenueMetrics(fakeWriteDb(calls), result);

  assert.equal(calls.length, 1);
  assert.equal(calls[0].data.schemaVersion, 2);
  assert.equal(calls[0].options, undefined);
  await assert.rejects(
    writeRevenueMetrics(fakeWriteDb([]), { schemaVersion: 1 }),
    /Refusing to write non-v2 revenue metrics/,
  );
});

test("refund record without provable capture is incomplete and does not fabricate gross", () => {
  const result = metrics({
    orders: [
      order("refund-without-capture", {
        status: "refunded",
        paymentStatus: "refunded",
        refundStatus: "refunded",
        refundAmount: 10,
        payment: {
          provider: "isbank",
          paymentId: "refund-without-capture",
          status: "refunded",
          currency: "TRY",
        },
      }),
    ],
  });
  assert.equal(result.payments.unverifiedCount, 1);
  assert.equal(result.financial.byCurrency.TRY, undefined);
});

test("scheduled source loader and shadow calculator receive equivalent inputs", async () => {
  const input = {
    subscriptions: [sub("user-a")],
    businesses: [business("b1")],
    orders: [order("loader-paid")],
  };
  const fromLoader = await computeRevenueMetrics(fakeDb(input), { now });
  const fromShadow = metrics(input);
  assert.deepEqual(fromLoader.financial, fromShadow.financial);
  assert.deepEqual(fromLoader.payments, fromShadow.payments);
  assert.deepEqual(fromLoader.entitlements, fromShadow.entitlements);
  assert.deepEqual(fromLoader.businesses, fromShadow.businesses);
});

test("order change trigger ignores irrelevant orders and catches payment transitions", () => {
  const snap = (data) => ({ data: () => data });
  assert.equal(
    shouldRecomputeForOrderChange(
      snap({ orderType: "marketplace", status: "paid" }),
      snap({ orderType: "marketplace", status: "paid", note: "changed" })
    ),
    false
  );
  assert.equal(
    shouldRecomputeForOrderChange(
      snap({ orderType: "web_subscription", status: "pending", paymentStatus: "pending" }),
      snap({ orderType: "web_subscription", status: "paid", paymentStatus: "paid" })
    ),
    true
  );
});

test("classification maps payment status categories", () => {
  assert.equal(classifyOrderPayment("paid", order("paid").data, { now }).status, "successful");
  assert.equal(classifyOrderPayment("pending", order("pending", { status: "pending", paymentStatus: "processing" }).data, { now }).status, "pending");
  assert.equal(classifyOrderPayment("failed", order("failed", { status: "failed", paymentStatus: "declined" }).data, { now }).status, "failed");
  const refund = classifyOrderPayment("refund", order("refund", { refundStatus: "chargeback" }).data, { now });
  assert.equal(refund.status, "successful");
  assert.equal(refund.hasRefundOrReversal, true);
});
