"use strict";

const admin = require("firebase-admin");
const { commitInventory } = require("./inventoryTransactions");
const {
  INVENTORY_OPERATION_VERSION,
  INVENTORY_SCHEMA_VERSION,
} = require("./inventoryConstants");
const { error } = require("./inventoryErrors");

const INVENTORY_MARKER_FIELDS = Object.freeze([
  "inventorySchemaVersion",
  "inventoryOperationVersion",
  "inventoryStatus",
  "financeEligibility",
  "providerPaymentStatus",
]);

function hasInventoryMarker(data = {}) {
  return INVENTORY_MARKER_FIELDS.some((field) =>
    Object.prototype.hasOwnProperty.call(data, field)
  );
}

function hasExpectedInventoryMarker(data = {}) {
  return Number(data.inventorySchemaVersion) === INVENTORY_SCHEMA_VERSION &&
    Number(data.inventoryOperationVersion) === INVENTORY_OPERATION_VERSION;
}

function classifyInventoryManagedOrder(rootData, sellerOrders) {
  const rootMarked = hasInventoryMarker(rootData);
  const sellerMarked = sellerOrders.map(hasInventoryMarker);
  const anyMarked = rootMarked || sellerMarked.some(Boolean);
  const completeMarker = hasExpectedInventoryMarker(rootData) &&
    sellerOrders.length > 0 && sellerOrders.every(hasExpectedInventoryMarker);
  if (completeMarker) return { kind: "managed" };
  if (anyMarked) {
    return { kind: "ambiguous", reason: "inventory_schema_marker_incomplete" };
  }
  return { kind: "legacy" };
}

function isInventoryManagedOrder(rootData, sellerOrders) {
  return classifyInventoryManagedOrder(rootData, sellerOrders).kind !== "legacy";
}

function normalizeMoney(value) {
  const number = Number(value);
  return Number.isFinite(number) ? Number(number.toFixed(2)) : null;
}

function normalizeCurrency(value) {
  const currency = String(value || "").trim().toUpperCase();
  return currency || null;
}

function validateVerifiedPaymentAmount({ rootData, amount, currency }) {
  const expectedAmount = normalizeMoney(
    rootData.pricing?.grandTotal ?? rootData.grandTotal
  );
  const actualAmount = normalizeMoney(amount);
  const expectedCurrency = normalizeCurrency(
    rootData.pricing?.currency || rootData.currency
  );
  const actualCurrency = normalizeCurrency(currency);
  if (expectedAmount == null || actualAmount == null ||
      !expectedCurrency || !actualCurrency ||
      expectedAmount !== actualAmount || expectedCurrency !== actualCurrency) {
    throw error(
      "payment_evidence_conflict",
      "Verified payment does not match the canonical order",
      { expectedAmount, actualAmount, expectedCurrency, actualCurrency },
      { manualReview: true }
    );
  }
  return { amount: actualAmount, currency: actualCurrency };
}

function lineKey(line = {}) {
  return [
    line.rootOrderId,
    line.sellerOrderId,
    line.lineId || line.sellerOrderLineId,
    line.businessId,
    line.productId,
  ].map((value) => String(value || "")).join("|");
}

function sameLineValues(expected, actual) {
  return expected && actual &&
    lineKey(expected) === lineKey(actual) &&
    Number(expected.quantity) === Number(actual.quantity) &&
    Number(expected.unitPrice) === Number(actual.unitPrice) &&
    Number(expected.totalPrice) === Number(actual.totalPrice) &&
    normalizeCurrency(expected.currency) === normalizeCurrency(actual.currency);
}

function validateCanonicalLineSet(rootData, sellerOrderIds, sellerData) {
  const expected = Array.isArray(rootData.inventoryLineSet)
    ? rootData.inventoryLineSet
    : null;
  if (!expected || expected.length === 0) {
    throw error(
      "canonical_line_set_incomplete",
      "Immutable canonical inventory line set is missing",
      {},
      { manualReview: true }
    );
  }

  const expectedKeys = new Set();
  for (const line of expected) {
    const key = lineKey(line);
    if (!key || expectedKeys.has(key)) {
      throw error(
        "canonical_line_set_conflict",
        "Canonical inventory line set contains a duplicate",
        { line },
        { manualReview: true }
      );
    }
    expectedKeys.add(key);
  }

  const actual = [];
  for (let index = 0; index < sellerData.length; index += 1) {
    const seller = sellerData[index] || {};
    if (String(seller.sellerOrderId || seller.id || sellerOrderIds[index] || "") !==
        String(sellerOrderIds[index] || "")) {
      // sellerOrderId is optional in older seller documents; the document path
      // remains authoritative and is checked by the line identities below.
    }
    const lines = Array.isArray(seller.inventoryLines) ? seller.inventoryLines : [];
    const seen = new Set();
    for (const line of lines) {
      const key = lineKey(line);
      if (!key || seen.has(key)) {
        throw error(
          "canonical_line_set_conflict",
          "Seller order contains a duplicate inventory line",
          { sellerOrderId: sellerOrderIds[index] },
          { manualReview: true }
        );
      }
      seen.add(key);
      if (String(line.sellerOrderId || "") !== String(sellerOrderIds[index]) ||
          String(line.rootOrderId || "") !== String(rootData.__id || "")) {
        throw error(
          "canonical_line_set_conflict",
          "Canonical line seller or root identity does not match",
          { sellerOrderId: sellerOrderIds[index], lineId: line.lineId || null },
          { manualReview: true }
        );
      }
      actual.push(line);
    }
  }

  if (actual.length !== expected.length) {
    throw error(
      "canonical_line_set_conflict",
      "Canonical inventory line count does not match",
      { expectedCount: expected.length, actualCount: actual.length },
      { manualReview: true }
    );
  }
  const actualKeys = new Set(actual.map(lineKey));
  if (actualKeys.size !== expectedKeys.size ||
      [...expectedKeys].some((key) => !actualKeys.has(key))) {
    throw error(
      "canonical_line_set_conflict",
      "Canonical inventory line identities do not match",
      {},
      { manualReview: true }
    );
  }
  for (const expectedLine of expected) {
    const actualLine = actual.find((line) => lineKey(line) === lineKey(expectedLine));
    if (!sameLineValues(expectedLine, actualLine)) {
      throw error(
        "canonical_line_set_conflict",
        "Canonical inventory line values do not match",
        { lineId: expectedLine.lineId || null },
        { manualReview: true }
      );
    }
  }
  return actual;
}

function paymentPatch(data, provider, paymentId) {
  return {
    providerPaymentStatus: "verified_success",
    providerPaymentState: "verified_success",
    paymentState: "verified_success",
    financeEligibility: "blocked",
    payment: {
      ...(data.payment || {}),
      provider,
      paymentProvider: provider,
      paymentId,
      status: "paid",
      providerPaymentStatus: "verified_success",
      verifiedPaymentState: "verified_success",
    },
  };
}

async function markAggregate(db, rootRef, sellerRefs, rootData, sellerData, status, provider, paymentId) {
  const batch = db.batch();
  const shared = {
    inventoryStatus: status,
    providerPaymentStatus: "verified_success",
    providerPaymentState: "verified_success",
    paymentState: "verified_success",
    financeEligibility: status === "committed" ? "eligible" : "blocked",
    inventoryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  batch.set(rootRef, {
    ...shared,
    payment: {
      ...paymentPatch(rootData, provider, paymentId).payment,
      status: status === "committed" ? "paid" : "pending",
    },
  }, { merge: true });
  for (let index = 0; index < sellerRefs.length; index += 1) {
    const seller = sellerData[index] || {};
    batch.set(sellerRefs[index], {
      ...shared,
      sellerOrderState: status === "committed"
        ? "paid_ready"
        : seller.sellerOrderState || "payment_pending",
      payment: {
        ...paymentPatch(seller, provider, paymentId).payment,
        status: status === "committed" ? "paid" : "pending",
      },
    }, { merge: true });
  }
  await batch.commit();
}

async function markInventoryManualReview({ db, rootRef, sellerRefs, reason, details = {} }) {
  const batch = db.batch();
  const fields = {
    inventoryStatus: "manual_review",
    financeEligibility: "blocked",
    inventoryReview: {
      reason,
      details,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    inventoryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  batch.set(rootRef, fields, { merge: true });
  for (const ref of sellerRefs) batch.set(ref, fields, { merge: true });
  await batch.commit();
}

async function commitVerifiedMarketplaceInventory({
  db,
  orderId,
  provider,
  paymentId,
  amount,
  currency,
}) {
  const rootRef = db.collection("orders").doc(orderId);
  const rootSnap = await rootRef.get();
  if (!rootSnap.exists) return { status: "missing", orderId };
  const rootData = { ...(rootSnap.data() || {}), __id: rootSnap.id };
  const sellerOrderIds = Array.isArray(rootData.sellerOrderIds)
    ? rootData.sellerOrderIds.map(String)
    : [];
  const sellerSnaps = await Promise.all(
    sellerOrderIds.map((id) => db.collection("sellerOrders").doc(id).get())
  );
  const sellerData = sellerSnaps.map((snap) => snap.data() || {});
  const classification = classifyInventoryManagedOrder(rootData, sellerData);
  if (classification.kind === "legacy") {
    return { status: "not_applicable", orderId };
  }
  if (classification.kind === "ambiguous") {
    await markInventoryManualReview({
      db,
      rootRef,
      sellerRefs: sellerSnaps.filter((snap) => snap.exists).map((snap) => snap.ref),
      reason: classification.reason,
    });
    return { status: "manual_review", orderId, reason: classification.reason };
  }
  if (sellerSnaps.some((snap) => !snap.exists)) {
    await markInventoryManualReview({
      db,
      rootRef,
      sellerRefs: sellerSnaps.filter((snap) => snap.exists).map((snap) => snap.ref),
      reason: "seller_order_missing",
    });
    return { status: "manual_review", orderId, reason: "seller_order_missing" };
  }
  try {
    validateVerifiedPaymentAmount({ rootData, amount, currency });
  } catch (paymentError) {
    await markInventoryManualReview({
      db,
      rootRef,
      sellerRefs: sellerSnaps.map((snap) => snap.ref),
      reason: paymentError.code || "payment_evidence_conflict",
      details: paymentError.details || {},
    });
    return {
      status: "manual_review",
      orderId,
      reason: paymentError.code || "payment_evidence_conflict",
    };
  }

  let lines;
  try {
    lines = validateCanonicalLineSet(rootData, sellerOrderIds, sellerData)
      .map((line) => ({
        ...line,
        buyerUid: rootData.buyerUid || rootData.userId || null,
      }))
      .sort((a, b) => `${a.businessId}:${a.productId}:${a.lineId}`.localeCompare(
        `${b.businessId}:${b.productId}:${b.lineId}`
      ));
  } catch (lineError) {
    await markInventoryManualReview({
      db,
      rootRef,
      sellerRefs: sellerSnaps.map((snap) => snap.ref),
      reason: lineError.code || "canonical_line_set_conflict",
      details: lineError.details || {},
    });
    return {
      status: "manual_review",
      orderId,
      reason: lineError.code || "canonical_line_set_conflict",
    };
  }

  await markAggregate(
    db,
    rootRef,
    sellerSnaps.map((snap) => snap.ref),
    rootData,
    sellerData,
    "committing",
    provider,
    paymentId
  );
  const outcomes = [];
  try {
    for (const line of lines) {
      outcomes.push(await commitInventory({
        db,
        identity: line,
        payment: { state: "verified_success", provider, paymentId },
      }));
    }
  } catch (commitError) {
    if (commitError?.manualReview === true) {
      await markInventoryManualReview({
        db,
        rootRef,
        sellerRefs: sellerSnaps.map((snap) => snap.ref),
        reason: commitError.code || "inventory_commit_manual_review",
        details: commitError.details || {},
      });
      return {
        status: "manual_review",
        orderId,
        failedLineId: commitError.details?.identity?.lineId || null,
        error: commitError.code || "inventory_commit_manual_review",
        outcomes,
      };
    }
    await markAggregate(
      db,
      rootRef,
      sellerSnaps.map((snap) => snap.ref),
      rootData,
      sellerData,
      "commit_pending",
      provider,
      paymentId
    );
    return {
      status: "commit_pending",
      orderId,
      failedLineId: commitError.details?.identity?.lineId || null,
      error: commitError.code || "commit_failed",
      outcomes,
    };
  }

  const batch = db.batch();
  for (const snap of sellerSnaps) {
    const data = snap.data() || {};
    const inventoryLines = data.inventoryLines.map((line) => ({
      ...line,
      inventoryStatus: "committed",
    }));
    batch.set(snap.ref, {
      status: "paid",
      paymentStatus: "paid",
      inventoryLines,
      inventoryStatus: "committed",
      providerPaymentStatus: "verified_success",
      providerPaymentState: "verified_success",
      paymentState: "verified_success",
      financeEligibility: "eligible",
      sellerOrderState: "paid_ready",
      payment: {
        ...(data.payment || {}),
        status: "paid",
        providerPaymentStatus: "verified_success",
        verifiedPaymentState: "verified_success",
      },
      inventoryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  batch.set(rootRef, {
    status: "paid",
    paymentStatus: "paid",
    inventoryStatus: "committed",
    providerPaymentStatus: "verified_success",
    providerPaymentState: "verified_success",
    paymentState: "verified_success",
    financeEligibility: "eligible",
    payment: {
      ...(rootData.payment || {}),
      status: "paid",
      providerPaymentStatus: "verified_success",
      verifiedPaymentState: "verified_success",
    },
    inventoryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  await batch.commit();
  return { status: "committed", orderId, outcomes };
}

module.exports = {
  commitVerifiedMarketplaceInventory,
  isInventoryManagedOrder,
  classifyInventoryManagedOrder,
  validateVerifiedPaymentAmount,
  validateCanonicalLineSet,
  markInventoryManualReview,
};
