"use strict";

const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const { computeRevenueMetrics } = require("./computeRevenueMetrics");
const { writeRevenueMetrics } = require("./writeRevenueMetrics");

function relevantOrderData(snapshot) {
  if (!snapshot) return null;
  const data = snapshot.data() || {};
  if (data.orderType !== "web_subscription") return null;
  return {
    orderType: data.orderType || null,
    status: data.status || null,
    paymentStatus: data.paymentStatus || null,
    planId: data.planId || null,
    buyerUid: data.buyerUid || null,
    userId: data.userId || null,
    pricing: data.pricing || null,
    payment: data.payment || null,
    paidAt: data.paidAt || null,
    refundStatus: data.refundStatus || null,
    refundAmount: data.refundAmount || null,
    refundedAmount: data.refundedAmount || null,
  };
}

function stable(value) {
  return JSON.stringify(value || null);
}

function shouldRecomputeForOrderChange(beforeSnapshot, afterSnapshot) {
  const before = relevantOrderData(beforeSnapshot);
  const after = relevantOrderData(afterSnapshot);
  if (!before && !after) return false;
  return stable(before) !== stable(after);
}

exports.onRevenueOrderChanged = onDocumentWritten(
  {
    document: "orders/{id}",
    region: "europe-west3",
  },
  async (event) => {
    if (!shouldRecomputeForOrderChange(event.data?.before, event.data?.after)) {
      return null;
    }

    const db = admin.firestore();
    try {
      console.log("💳 Revenue order changed → recomputing revenue v2 metrics");
      const metrics = await computeRevenueMetrics(db);
      await writeRevenueMetrics(db, metrics);
      console.log("✅ Revenue v2 metrics updated from order change");
    } catch (e) {
      console.error("❌ onRevenueOrderChanged failed", e);
    }
    return null;
  }
);

module.exports.shouldRecomputeForOrderChange = shouldRecomputeForOrderChange;
