"use strict";

const crypto = require("node:crypto");
const admin = require("firebase-admin");
const { InventoryError, error } = require("./inventoryErrors");
const {
  FINANCE_ELIGIBILITY,
  INVENTORY_OPERATION_VERSION,
  INVENTORY_SCHEMA_VERSION,
  RESERVATION_STATUS,
} = require("./inventoryConstants");
const { canonicalLineIdentity } = require("./inventoryIdentity");
const { releaseInventory, reserveInventory } = require("./inventoryTransactions");

const CHECKOUT_ATTEMPT_COLLECTION = "marketplaceCheckoutAttempts";
const CHECKOUT_ATTEMPT_LEASE_MS = 15 * 60 * 1000;

const CHECKOUT_ATTEMPT_STATUS = Object.freeze({
  PROCESSING: "processing",
  ORDER_CREATED: "order_created",
  RESERVING: "reserving",
  RESERVED: "reserved",
  COMPENSATION_PENDING: "compensation_pending",
  RELEASED: "released",
  FAILED: "failed",
  MANUAL_REVIEW: "manual_review",
});

function normalizedId(value, field) {
  const result = String(value ?? "").trim();
  if (!result || result.includes("\0")) {
    throw error("invalid_argument", `${field} is required`);
  }
  return result;
}

function stableJson(value) {
  if (Array.isArray(value)) return value.map(stableJson);
  if (value && typeof value === "object") {
    return Object.keys(value)
      .sort()
      .reduce((result, key) => {
        result[key] = stableJson(value[key]);
        return result;
      }, {});
  }
  return value;
}

function checkoutFingerprint({ items, currency, amount }) {
  const canonicalItems = items.map((item) => ({
    businessId: String(item.businessId || item.shopId || ""),
    productId: String(item.productId || ""),
    quantity: Number(item.quantity),
    unitPrice: Number(item.unitPrice ?? item.price ?? 0),
    carrier: String(item.selectedCarrier || item.carrier || ""),
  }));
  return crypto
    .createHash("sha256")
    .update(JSON.stringify(stableJson({ canonicalItems, currency, amount })))
    .digest("hex");
}

function attemptDocumentId(buyerUid, checkoutAttemptId) {
  return `${encodeURIComponent(buyerUid)}__${encodeURIComponent(checkoutAttemptId)}`;
}

function deterministicDocumentId(prefix, ...parts) {
  const digest = crypto
    .createHash("sha256")
    .update(parts.map((part) => String(part)).join("\0"))
    .digest("hex")
    .slice(0, 40);
  return `${prefix}_${digest}`;
}

function buildM3OrderIds({ buyerUid, checkoutAttemptId, businessIds }) {
  const rootOrderId = deterministicDocumentId(
    "m3_order",
    buyerUid,
    checkoutAttemptId
  );
  const sellerOrderIds = new Map();
  for (const businessId of [...new Set(businessIds.map(String))].sort()) {
    sellerOrderIds.set(
      businessId,
      deterministicDocumentId("m3_seller", rootOrderId, businessId)
    );
  }
  return { rootOrderId, sellerOrderIds };
}

function buildLineId({ rootOrderId, sellerOrderId, item, duplicateIndex }) {
  const sourceKey = [
    rootOrderId,
    sellerOrderId,
    item.businessId || item.shopId,
    item.productId,
    item.unitPrice ?? item.price,
    item.name || "",
    item.imageUrl || "",
    item.selectedCarrier || item.carrier || "",
    duplicateIndex,
  ];
  return deterministicDocumentId("line", ...sourceKey);
}

function buildCanonicalLines({ rootOrderId, sellerOrderIds, items }) {
  const duplicateCounts = new Map();
  return items.map((item) => {
    const businessId = String(item.businessId || item.shopId || "");
    const productId = String(item.productId || "");
    const key = `${businessId}\0${productId}`;
    const duplicateIndex = duplicateCounts.get(key) || 0;
    duplicateCounts.set(key, duplicateIndex + 1);
    const sellerOrderId = sellerOrderIds.get(businessId);
    const lineId = item.lineId
      ? normalizedId(item.lineId, "lineId")
      : buildLineId({
          rootOrderId,
          sellerOrderId,
          item,
          duplicateIndex,
        });
    return {
      rootOrderId,
      sellerOrderId,
      lineId,
      buyerUid: null,
      businessId,
      productId,
      quantity: Number(item.quantity),
      unitPrice: Number(item.unitPrice ?? item.price ?? 0),
      totalPrice: Number(
        (
          item.lineGrandTotal ??
          Number(item.unitPrice ?? item.price ?? 0) * Number(item.quantity)
        ).toFixed(2)
      ),
      currency: item.currency || "TRY",
      title: item.name || null,
      imageUrl: item.imageUrl || null,
      inventoryStatus: "not_started",
      inventoryOperationVersion: INVENTORY_OPERATION_VERSION,
    };
  });
}

function buildCheckoutResponse({
  rootOrderId,
  orderNumber,
  sellerOrderIds,
  inventoryStatus = "reserved",
}) {
  const ids = [...sellerOrderIds];
  return {
    ok: true,
    orderId: rootOrderId,
    orderNumber: orderNumber || null,
    sellerOrderIds: ids,
    sellerCount: ids.length,
    inventoryStatus,
  };
}

function initialM3LegacyPaymentState({ m3Enabled, paymentStatus }) {
  return {
    orderStatus: m3Enabled
      ? "pending_payment"
      : paymentStatus === "paid"
        ? "paid"
        : "pending_payment",
    paymentStatus: m3Enabled ? "pending" : paymentStatus || "pending",
  };
}

function validateExistingCheckoutTree({
  rootSnapshot,
  sellerOrderSnapshots,
  expectedSellerOrderIds,
  expectedLines,
  buyerUid,
}) {
  if (!rootSnapshot?.exists) {
    throw error("canonical_order_tree_incomplete", "Checkout order tree is incomplete", {}, {
      manualReview: true,
    });
  }
  const root = rootSnapshot.data() || {};
  if (buyerUid && String(root.buyerUid || "") !== String(buyerUid)) {
    throw error("canonical_order_tree_incomplete", "Checkout buyer identity does not match", {}, {
      manualReview: true,
    });
  }
  if (!Array.isArray(root.sellerOrderIds)) {
    throw error("canonical_order_tree_incomplete", "Checkout seller orders are missing", {}, {
      manualReview: true,
    });
  }
  const expectedSellerIds = [...expectedSellerOrderIds].map(String).sort();
  const storedSellerIds = root.sellerOrderIds.map(String).sort();
  if (JSON.stringify(expectedSellerIds) !== JSON.stringify(storedSellerIds)) {
    throw error("canonical_order_tree_incomplete", "Checkout seller orders do not match", {}, {
      manualReview: true,
    });
  }

  const expectedBySeller = new Map();
  for (const line of expectedLines) {
    const sellerLines = expectedBySeller.get(line.sellerOrderId) || [];
    sellerLines.push(line);
    expectedBySeller.set(line.sellerOrderId, sellerLines);
  }
  for (const sellerId of expectedSellerIds) {
    const snapshot = sellerOrderSnapshots.get(sellerId);
    if (!snapshot?.exists) {
      throw error("canonical_order_tree_incomplete", "Checkout seller order is missing", {
        sellerOrderId: sellerId,
      }, { manualReview: true });
    }
    const seller = snapshot.data() || {};
    if (String(seller.rootOrderId || "") !== String(rootSnapshot.id)) {
      throw error("canonical_order_tree_incomplete", "Checkout seller order root mismatch", {
        sellerOrderId: sellerId,
      }, { manualReview: true });
    }
    const storedLines = Array.isArray(seller.inventoryLines) ? seller.inventoryLines : [];
    const storedById = new Map(storedLines.map((line) => [String(line.lineId || ""), line]));
    const expectedSellerLines = expectedBySeller.get(sellerId) || [];
    if (storedById.size !== expectedSellerLines.length) {
      throw error("canonical_order_tree_incomplete", "Checkout seller-order lines do not match", {
        sellerOrderId: sellerId,
      }, { manualReview: true });
    }
    for (const expected of expectedSellerLines) {
      const actual = storedById.get(expected.lineId);
      if (!actual ||
        String(actual.rootOrderId || "") !== expected.rootOrderId ||
        String(actual.sellerOrderId || "") !== expected.sellerOrderId ||
        String(actual.lineId || "") !== expected.lineId ||
        String(actual.businessId || actual.shopId || "") !== expected.businessId ||
        String(actual.productId || "") !== expected.productId ||
        (buyerUid && String(actual.buyerUid || "") !== String(buyerUid)) ||
        Number(actual.quantity) !== Number(expected.quantity)) {
        throw error("canonical_order_tree_incomplete", "Checkout seller-order line is incomplete", {
          sellerOrderId: sellerId,
          lineId: expected.lineId,
        }, { manualReview: true });
      }
    }
  }
}

function asTimestamp(value) {
  if (value instanceof admin.firestore.Timestamp) return value;
  if (value && typeof value.toMillis === "function") return value;
  return admin.firestore.Timestamp.fromDate(new Date(value));
}

function claimRef(db, buyerUid, checkoutAttemptId) {
  return db
    .collection(CHECKOUT_ATTEMPT_COLLECTION)
    .doc(attemptDocumentId(buyerUid, checkoutAttemptId));
}

async function claimCheckoutAttempt({
  db,
  buyerUid,
  checkoutAttemptId,
  cartFingerprint,
  amount,
  currency,
  rootOrderId,
}) {
  const buyer = normalizedId(buyerUid, "buyerUid");
  const attemptId = normalizedId(checkoutAttemptId, "checkoutAttemptId");
  const ref = claimRef(db, buyer, attemptId);
  const now = admin.firestore.Timestamp.now();
  const leaseExpiresAt = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + CHECKOUT_ATTEMPT_LEASE_MS
  );

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) {
      transaction.create(ref, {
        checkoutAttemptId: attemptId,
        buyerUid: buyer,
        rootOrderId,
        status: CHECKOUT_ATTEMPT_STATUS.PROCESSING,
        cartFingerprint,
        amount,
        currency,
        createdAt: now,
        updatedAt: now,
        startedAt: now,
        leaseExpiresAt,
        attempt: 1,
        error: null,
        result: null,
      });
      return {
        status: "claimed",
        ref,
        attempt: 1,
        rootOrderId,
        checkoutAttemptId: attemptId,
      };
    }

    const existing = snapshot.data() || {};
    if (
      existing.buyerUid !== buyer ||
      existing.checkoutAttemptId !== attemptId ||
      existing.cartFingerprint !== cartFingerprint ||
      Number(existing.amount) !== Number(amount) ||
      existing.currency !== currency
    ) {
      throw error(
        "checkout_attempt_conflict",
        "Checkout attempt does not match its original cart",
        { checkoutAttemptId: attemptId },
        { manualReview: true }
      );
    }

    if (existing.rootOrderId !== rootOrderId) {
      throw error(
        "checkout_attempt_conflict",
        "Checkout attempt has a different canonical order",
        { checkoutAttemptId: attemptId },
        { manualReview: true }
      );
    }

    if (existing.status === CHECKOUT_ATTEMPT_STATUS.RESERVED) {
      return {
        status: "already_reserved",
        ref,
        rootOrderId,
        checkoutAttemptId: attemptId,
        result: existing.result || null,
        orderNumber: existing.orderNumber || null,
      };
    }
    if (existing.status === CHECKOUT_ATTEMPT_STATUS.COMPENSATION_PENDING) {
      return {
        status: existing.status,
        ref,
        rootOrderId,
        checkoutAttemptId: attemptId,
        result: existing.result || null,
        error: existing.error || null,
        orderNumber: existing.orderNumber || null,
      };
    }
    if (
      [
        CHECKOUT_ATTEMPT_STATUS.RELEASED,
        CHECKOUT_ATTEMPT_STATUS.FAILED,
        CHECKOUT_ATTEMPT_STATUS.MANUAL_REVIEW,
      ].includes(existing.status)
    ) {
      return {
        status: existing.status,
        ref,
        rootOrderId,
        checkoutAttemptId: attemptId,
        result: existing.result || null,
        error: existing.error || null,
        orderNumber: existing.orderNumber || null,
      };
    }

    const existingLease = existing.leaseExpiresAt
      ? asTimestamp(existing.leaseExpiresAt)
      : null;
    if (existingLease && existingLease.toMillis() > now.toMillis()) {
      return {
        status: "in_progress",
        ref,
        rootOrderId,
        checkoutAttemptId: attemptId,
      };
    }

    const nextAttempt = Math.max(1, Number(existing.attempt || 0) + 1);
    transaction.set(
      ref,
      {
        status: CHECKOUT_ATTEMPT_STATUS.PROCESSING,
        updatedAt: now,
        startedAt: now,
        leaseExpiresAt,
        attempt: nextAttempt,
        error: null,
      },
      { merge: true }
    );
    return {
      status: "reclaimed",
      ref,
      attempt: nextAttempt,
      rootOrderId,
      checkoutAttemptId: attemptId,
    };
  });
}

async function updateAttempt(ref, data) {
  await ref.set(
    {
      ...data,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function updateSellerLineState(db, line, inventoryStatus) {
  await db.runTransaction(async (transaction) => {
    const ref = db.collection("sellerOrders").doc(line.sellerOrderId);
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) throw error("seller_order_not_found", "Seller order not found");
    const data = snapshot.data() || {};
    const lines = Array.isArray(data.inventoryLines) ? data.inventoryLines : [];
    const index = lines.findIndex((candidate) => candidate.lineId === line.lineId);
    if (index < 0) throw error("seller_order_line_not_found", "Seller-order line not found");
    const nextLines = lines.map((candidate, candidateIndex) =>
      candidateIndex === index ? { ...candidate, inventoryStatus } : candidate
    );
    transaction.set(ref, { inventoryLines: nextLines }, { merge: true });
  });
}

async function updateAggregateState(db, { rootOrderId, sellerOrderIds }, inventoryStatus) {
  const batch = db.batch();
  batch.set(
    db.collection("orders").doc(rootOrderId),
    {
      inventoryStatus,
      inventorySchemaVersion: INVENTORY_SCHEMA_VERSION,
      inventoryOperationVersion: INVENTORY_OPERATION_VERSION,
      inventoryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  for (const sellerOrderId of sellerOrderIds) {
    batch.set(
      db.collection("sellerOrders").doc(sellerOrderId),
      {
        inventoryStatus,
        inventorySchemaVersion: INVENTORY_SCHEMA_VERSION,
        inventoryOperationVersion: INVENTORY_OPERATION_VERSION,
        inventoryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  await batch.commit();
}

function publicCheckoutError(errorValue) {
  if (errorValue instanceof InventoryError) return errorValue;
  return error("internal_retryable", "Checkout reservation could not be completed", {}, {
    manualReview: true,
  });
}

async function coordinateCheckoutReservations({
  db,
  attemptRef,
  rootOrderId,
  sellerOrderIds,
  lines,
}) {
  const orderedLines = [...lines].sort((a, b) =>
    `${a.businessId}:${a.productId}:${a.lineId}`.localeCompare(
      `${b.businessId}:${b.productId}:${b.lineId}`
    )
  );
  await updateAttempt(attemptRef, { status: CHECKOUT_ATTEMPT_STATUS.RESERVING });
  await updateAggregateState(db, { rootOrderId, sellerOrderIds }, "reserving");

  const reserved = [];
  const outcomes = [];
  try {
    for (const line of orderedLines) {
      const identity = canonicalLineIdentity(line);
      const result = await reserveInventory({
        db,
        identity,
        quantity: line.quantity,
      });
      outcomes.push({ ...result, lineId: line.lineId });
      if (!["reserved", "already_reserved"].includes(result.status)) {
        throw error("inventory_conflict", "Inventory reservation did not complete", {
          lineId: line.lineId,
        });
      }
      reserved.push(line);
      await updateSellerLineState(db, line, RESERVATION_STATUS.RESERVED);
    }

    await updateAggregateState(db, { rootOrderId, sellerOrderIds }, "reserved");
    const result = {
      status: "reserved",
      rootOrderId,
      sellerOrderIds,
      outcomes,
      reservedLineIds: reserved.map((line) => line.lineId),
    };
    await updateAttempt(attemptRef, {
      status: CHECKOUT_ATTEMPT_STATUS.RESERVED,
      result,
      error: null,
      leaseExpiresAt: null,
    });
    return result;
  } catch (reservationError) {
    const safeError = publicCheckoutError(reservationError);
    const compensation = [];
    for (const line of [...reserved].reverse()) {
      try {
        const result = await releaseInventory({
          db,
          identity: canonicalLineIdentity(line),
          reason: "m3_reservation_compensation",
        });
        compensation.push({ lineId: line.lineId, ...result });
        await updateSellerLineState(db, line, "released");
      } catch (releaseError) {
        compensation.push({
          lineId: line.lineId,
          status: "compensation_pending",
          error: releaseError.code || "internal_retryable",
        });
      }
    }
    const compensationPending = compensation.some(
      (item) => item.status === "compensation_pending"
    );
    const status = compensationPending
      ? CHECKOUT_ATTEMPT_STATUS.COMPENSATION_PENDING
      : CHECKOUT_ATTEMPT_STATUS.RELEASED;
    await updateAttempt(attemptRef, {
      status,
      error: {
        code: compensationPending ? "compensation_pending" : safeError.code,
        message: safeError.message,
        lineId: safeError.details?.lineId || null,
      },
      result: {
        status,
        outcomes,
        compensation,
        reservedLineIds: reserved.map((line) => line.lineId),
      },
      leaseExpiresAt: null,
    });
    await updateAggregateState(
      db,
      { rootOrderId, sellerOrderIds },
      compensationPending ? "compensation_pending" : "released"
    );
    throw error(
      compensationPending ? "compensation_pending" : safeError.code,
      compensationPending
        ? "Inventory compensation is still pending"
        : "Items are no longer available",
      { lineId: safeError.details?.lineId || null },
      { manualReview: compensationPending || safeError.manualReview }
    );
  }
}

async function resumeCheckoutCompensation({ db, claim, lines, sellerOrderIds }) {
  const reservedLineIds = new Set(claim.result?.reservedLineIds || []);
  const reservedLines = lines.filter((line) => reservedLineIds.has(line.lineId));
  const compensation = [];
  for (const line of [...reservedLines].reverse()) {
    try {
      const result = await releaseInventory({
        db,
        identity: canonicalLineIdentity(line),
        reason: "m3_reservation_compensation",
      });
      compensation.push({ lineId: line.lineId, ...result });
      await updateSellerLineState(db, line, "released");
    } catch (releaseError) {
      compensation.push({
        lineId: line.lineId,
        status: "compensation_pending",
        error: releaseError.code || "internal_retryable",
      });
    }
  }
  const pending = compensation.some((item) => item.status === "compensation_pending");
  const result = {
    ...(claim.result || {}),
    status: pending ? CHECKOUT_ATTEMPT_STATUS.COMPENSATION_PENDING : CHECKOUT_ATTEMPT_STATUS.RELEASED,
    compensation,
    reservedLineIds: pending
      ? reservedLines.map((line) => line.lineId)
      : [],
  };
  await updateAttempt(claim.ref, {
    status: result.status,
    result,
    error: pending ? { code: "compensation_pending", message: "Inventory compensation is still pending" } : null,
    leaseExpiresAt: null,
  });
  await updateAggregateState(db, { rootOrderId: claim.rootOrderId, sellerOrderIds }, pending ? "compensation_pending" : "released");
  if (pending) {
    throw error("compensation_pending", "Inventory compensation is still pending", {}, { manualReview: true });
  }
  throw error("item_unavailable", "Items are no longer available");
}

async function resumeCheckoutAttempt({ db, claim, lines, sellerOrderIds, orderNumber }) {
  if (claim.status === "already_reserved") {
    if (claim.result?.ok === true && claim.result.orderId) return claim.result;
    return buildCheckoutResponse({
      rootOrderId: claim.rootOrderId,
      orderNumber: claim.orderNumber || orderNumber,
      sellerOrderIds,
      inventoryStatus: "reserved",
    });
  }
  if (claim.status === "in_progress") {
    throw error("reservation_in_progress", "Checkout reservation is already processing");
  }
  if (claim.status === CHECKOUT_ATTEMPT_STATUS.COMPENSATION_PENDING) {
    return resumeCheckoutCompensation({ db, claim, lines, sellerOrderIds });
  }
  if (claim.status !== "reclaimed" && claim.status !== "claimed") {
    throw error(
      claim.status === CHECKOUT_ATTEMPT_STATUS.COMPENSATION_PENDING
        ? "compensation_pending"
        : claim.status === CHECKOUT_ATTEMPT_STATUS.MANUAL_REVIEW
          ? "manual_review"
          : "item_unavailable",
      "Checkout attempt is not available for a new reservation"
    );
  }
  const result = await coordinateCheckoutReservations({
    db,
    attemptRef: claim.ref,
    rootOrderId: claim.rootOrderId,
    sellerOrderIds,
    lines,
  });
  const response = buildCheckoutResponse({
    rootOrderId: claim.rootOrderId,
    orderNumber,
    sellerOrderIds,
    inventoryStatus: result.status,
  });
  await updateAttempt(claim.ref, { result: response, orderNumber });
  return response;
}

function m3FeatureEnabled({ buyerUid, businessIds }) {
  if (String(process.env.M3_INVENTORY_RESERVATION_ENABLED).toLowerCase() !== "true") {
    return false;
  }
  const buyers = String(process.env.M3_INVENTORY_CANARY_BUYERS || "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  const businesses = String(process.env.M3_INVENTORY_CANARY_BUSINESSES || "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  if (buyers.length === 0 && businesses.length === 0) return false;
  return buyers.includes(buyerUid) || businessIds.some((id) => businesses.includes(id));
}

module.exports = {
  CHECKOUT_ATTEMPT_COLLECTION,
  CHECKOUT_ATTEMPT_STATUS,
  buildCanonicalLines,
  buildCheckoutResponse,
  buildM3OrderIds,
  checkoutFingerprint,
  claimCheckoutAttempt,
  coordinateCheckoutReservations,
  m3FeatureEnabled,
  initialM3LegacyPaymentState,
  resumeCheckoutAttempt,
  resumeCheckoutCompensation,
  validateExistingCheckoutTree,
  updateAttempt,
};
