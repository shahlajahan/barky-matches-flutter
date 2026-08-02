"use strict";

const admin = require("firebase-admin");
const {
  RESERVATION_STATUS,
  INVENTORY_COMMIT_STATUS,
  INVENTORY_SCHEMA_VERSION,
  INVENTORY_OPERATION_VERSION,
} = require("./inventoryConstants");
const { releaseInventory, reserveInventory } = require("./inventoryTransactions");
const { reservationRef } = require("./inventoryRepository");
const {
  validateCanonicalLineSet,
  classifyInventoryManagedOrder,
  markInventoryManualReview,
  commitVerifiedMarketplaceInventory,
} = require("./inventoryPaymentCoordinator");
const { canonicalLineIdentity } = require("./inventoryIdentity");
const { error } = require("./inventoryErrors");

const M5_MAX_ATTEMPTS = 5;

const M5_FLAG_ENV = Object.freeze({
  failure_release: "INVENTORY_FAILURE_RELEASE_ENABLED",
  cancellation_release: "INVENTORY_CANCELLATION_RELEASE_ENABLED",
  expiry_scheduler: "INVENTORY_EXPIRY_SCHEDULER_ENABLED",
  lease_recovery: "INVENTORY_LEASE_RECOVERY_ENABLED",
  late_payment_recovery: "LATE_PAYMENT_RECOVERY_ENABLED",
});

function m5FeatureEnabled(name, { buyerUid = null, businessIds = [], scheduler = false } = {}) {
  const normalized = String(name || "").trim().toLowerCase();
  const key = M5_FLAG_ENV[normalized] || `M5_${normalized.toUpperCase()}_ENABLED`;
  const legacyKey = `M5_${normalized.toUpperCase()}_ENABLED`;
  if (String(process.env[key] || process.env[legacyKey] || "").toLowerCase() !== "true") return false;
  if (scheduler && String(process.env.INVENTORY_M5_SCHEDULER_CANARY || "").toLowerCase() === "true") return true;
  const buyers = String(process.env.M5_CANARY_BUYERS || "").split(",").map((v) => v.trim()).filter(Boolean);
  const businesses = String(process.env.M5_CANARY_BUSINESSES || "").split(",").map((v) => v.trim()).filter(Boolean);
  if (buyers.length === 0 && businesses.length === 0) return false;
  return buyers.includes(String(buyerUid || "")) || businessIds.some((id) => businesses.includes(String(id)));
}

function managedOrderData(rootSnap, sellerSnaps) {
  const rootData = { ...(rootSnap.data() || {}), __id: rootSnap.id };
  const sellerData = sellerSnaps.map((snap) => snap.data() || {});
  const classification = classifyInventoryManagedOrder(rootData, sellerData);
  if (classification.kind !== "managed") {
    return { rootData, sellerData, classification };
  }
  const sellerOrderIds = Array.isArray(rootData.sellerOrderIds)
    ? rootData.sellerOrderIds.map(String)
    : sellerSnaps.map((snap) => snap.id);
  const lines = validateCanonicalLineSet(rootData, sellerOrderIds, sellerData)
    .map((line) => ({ ...line, buyerUid: rootData.buyerUid || rootData.userId || null }));
  return { rootData, sellerData, sellerOrderIds, lines, classification };
}

async function updateReleaseAggregate(db, { rootOrderId, sellerOrderIds }, status, details = {}) {
  const batch = db.batch();
  const fields = {
    inventoryStatus: status,
    inventorySchemaVersion: INVENTORY_SCHEMA_VERSION,
    inventoryOperationVersion: INVENTORY_OPERATION_VERSION,
    financeEligibility: "ineligible",
    inventoryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    inventoryRecovery: {
      ...details,
      status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };
  batch.set(db.collection("orders").doc(rootOrderId), fields, { merge: true });
  for (const sellerOrderId of sellerOrderIds || []) {
    batch.set(db.collection("sellerOrders").doc(sellerOrderId), fields, { merge: true });
  }
  await batch.commit();
}

async function updateAttemptForRelease(attemptRef, status, result, errorData = null) {
  if (!attemptRef) return;
  await attemptRef.set({
    status,
    result,
    error: errorData,
    leaseExpiresAt: null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function releaseMarketplaceInventory({
  db,
  orderId,
  reason = "payment_failure",
  attemptRef = null,
  buyerUid = null,
  paymentState = "pending",
  targetSellerOrderIds = null,
}) {
  const rootRef = db.collection("orders").doc(String(orderId));
  const rootSnap = await rootRef.get();
  if (!rootSnap.exists) return { status: "missing", orderId };
  const rootData = rootSnap.data() || {};
  const sellerOrderIds = Array.isArray(rootData.sellerOrderIds) ? rootData.sellerOrderIds.map(String) : [];
  const sellerSnaps = await Promise.all(sellerOrderIds.map((id) => db.collection("sellerOrders").doc(id).get()));
  let loaded;
  try {
    loaded = managedOrderData(rootSnap, sellerSnaps);
  } catch (loadError) {
    await markInventoryManualReview({
      db,
      rootRef,
      sellerRefs: sellerSnaps.filter((snap) => snap.exists).map((snap) => snap.ref),
      reason: loadError.code || "canonical_line_set_conflict",
      details: loadError.details || {},
    });
    return { status: "manual_review", orderId, reason: loadError.code || "canonical_line_set_conflict" };
  }
  if (loaded.classification.kind === "legacy") return { status: "not_applicable", orderId };
  if (loaded.classification.kind !== "managed" || sellerSnaps.some((snap) => !snap.exists)) {
    await updateReleaseAggregate(db, { rootOrderId: orderId, sellerOrderIds }, "manual_review", {
      reason: loaded.classification.reason || "canonical_order_tree_incomplete",
    });
    return { status: "manual_review", orderId };
  }
  if (["verified_success", "committed", "paid"].includes(String(paymentState).toLowerCase()) ||
      String(rootData.providerPaymentState || rootData.providerPaymentStatus || "").toLowerCase() === "verified_success") {
    await updateReleaseAggregate(db, { rootOrderId: orderId, sellerOrderIds }, "manual_review", {
      reason: "verified_payment_cannot_release_inventory",
    });
    return { status: "manual_review", orderId, reason: "verified_payment_cannot_release_inventory" };
  }

  const selectedSellerIds = targetSellerOrderIds == null
    ? sellerOrderIds
    : sellerOrderIds.filter((id) => targetSellerOrderIds.map(String).includes(id));
  const selectedLines = loaded.lines.filter((line) => selectedSellerIds.includes(String(line.sellerOrderId)));
  if (selectedLines.length === 0) {
    return { status: "manual_review", orderId, reason: "target_seller_order_not_found" };
  }
  const outcomes = [];
  for (const line of [...selectedLines].sort((a, b) => `${a.businessId}:${a.productId}:${a.lineId}`.localeCompare(`${b.businessId}:${b.productId}:${b.lineId}`))) {
    const identity = canonicalLineIdentity(line);
    try {
      const reservationSnap = await reservationRef(db, identity).get();
      if (!reservationSnap.exists) throw error("reservation_not_found", "Reservation is missing", { identity }, { manualReview: true });
      const reservation = reservationSnap.data() || {};
      if (reservation.status === RESERVATION_STATUS.COMMITTED) {
        outcomes.push({ lineId: line.lineId, status: "already_committed" });
        continue;
      }
      if ([RESERVATION_STATUS.RELEASED, RESERVATION_STATUS.EXPIRED].includes(reservation.status)) {
        outcomes.push({ lineId: line.lineId, status: "already_released" });
        continue;
      }
      const result = await releaseInventory({ db, identity, reason });
      outcomes.push({ lineId: line.lineId, ...result });
    } catch (releaseError) {
      outcomes.push({
        lineId: line.lineId,
        status: releaseError.manualReview ? "manual_review" : "release_pending",
        error: releaseError.code || "internal_retryable",
      });
    }
  }

  const hasCommitted = outcomes.some((item) => item.status === "already_committed");
  const hasManual = outcomes.some((item) => item.status === "manual_review");
  const pending = outcomes.some((item) => item.status === "release_pending");
  const status = hasCommitted || hasManual ? "manual_review" : pending ? "release_pending" : "released";
  const result = { status, orderId, outcomes, reason };
  if (selectedSellerIds.length === sellerOrderIds.length) {
    await updateReleaseAggregate(db, { rootOrderId: orderId, sellerOrderIds }, status, { reason, outcomes });
  } else {
    const batch = db.batch();
    for (const sellerOrderId of selectedSellerIds) {
      batch.set(db.collection("sellerOrders").doc(sellerOrderId), {
        inventoryStatus: status,
        inventorySchemaVersion: INVENTORY_SCHEMA_VERSION,
        inventoryOperationVersion: INVENTORY_OPERATION_VERSION,
        financeEligibility: "ineligible",
        inventoryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        inventoryRecovery: { reason, outcomes, status, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      }, { merge: true });
    }
    batch.set(rootRef, {
      inventoryStatus: status === "released" ? "partially_released" : status,
      inventoryRecovery: { reason, outcomes, status, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      inventoryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();
  }
  await updateAttemptForRelease(attemptRef, status, result, pending ? { code: "release_pending" } : null);
  return result;
}

async function recoverStaleReservation({ db, reservationSnap, now = admin.firestore.Timestamp.now() }) {
  const reservation = reservationSnap.data() || {};
  const identity = canonicalLineIdentity(reservation);
  const attempt = Number(reservation.attempt || 0);
  if (attempt >= M5_MAX_ATTEMPTS) {
    return { status: "manual_review", reason: "max_recovery_attempts", identity };
  }
  const rootSnap = await db.collection("orders").doc(identity.rootOrderId).get();
  const sellerSnap = await db.collection("sellerOrders").doc(identity.sellerOrderId).get();
  const rootData = rootSnap.data() || {};
  const payment = rootData.providerPaymentState || rootData.providerPaymentStatus || "pending";
  const paymentId = rootData.payment?.paymentId || rootData.payment?.paymentTransactionId || rootData.paymentId || null;
  const paymentAmount = rootData.payment?.paidPrice ?? rootData.pricing?.grandTotal ?? null;
  const paymentCurrency = rootData.payment?.currency || rootData.pricing?.currency || null;
  const resumeCommit = async () => {
    if (String(payment).toLowerCase() !== "verified_success") {
      return { status: "release_pending", reason: "payment_not_verified", identity };
    }
    if (!paymentId || paymentAmount == null || !paymentCurrency) {
      return { status: "manual_review", reason: "verified_payment_evidence_missing", identity };
    }
    return commitVerifiedMarketplaceInventory({
      db,
      orderId: identity.rootOrderId,
      provider: rootData.payment?.provider || rootData.paymentProvider || "unknown",
      paymentId,
      amount: paymentAmount,
      currency: paymentCurrency,
    });
  };
  if (reservation.status === RESERVATION_STATUS.RESERVING) {
    try {
      const result = await reserveInventory({
        db,
        identity,
        quantity: reservation.quantity,
        now,
      });
      if (String(payment).toLowerCase() === "verified_success") {
        const commitResult = await resumeCommit();
        return { ...commitResult, identity, reservation: result };
      }
      return result;
    } catch (recoveryError) {
      return { status: recoveryError.manualReview ? "manual_review" : "release_pending", reason: recoveryError.code, identity };
    }
  }
  if (reservation.status === RESERVATION_STATUS.RELEASING) {
    try {
      return await releaseInventory({ db, identity, now });
    } catch (recoveryError) {
      return { status: recoveryError.manualReview ? "manual_review" : "release_pending", reason: recoveryError.code, identity };
    }
  }
  if (reservation.inventoryCommitState === INVENTORY_COMMIT_STATUS.COMMITTING) {
    const result = await resumeCommit();
    return { ...result, identity, rootExists: rootSnap.exists, sellerExists: sellerSnap.exists };
  }
  return { status: "ignored", identity };
}

async function recordLatePaymentAfterExpiry({
  db,
  orderId,
  provider,
  paymentId,
  amount,
  currency,
}) {
  const rootRef = db.collection("orders").doc(String(orderId));
  const rootSnap = await rootRef.get();
  if (!rootSnap.exists) return { status: "missing", orderId };
  const rootData = { ...(rootSnap.data() || {}), __id: rootSnap.id };
  const sellerOrderIds = Array.isArray(rootData.sellerOrderIds)
    ? rootData.sellerOrderIds.map(String)
    : [];
  const sellerSnaps = await Promise.all(
    sellerOrderIds.map((id) => db.collection("sellerOrders").doc(id).get())
  );
  const classification = classifyInventoryManagedOrder(
    rootData,
    sellerSnaps.map((snap) => snap.data() || {})
  );
  if (classification.kind !== "managed") return { status: "not_applicable", orderId };
  const lines = validateCanonicalLineSet(
    rootData,
    sellerOrderIds,
    sellerSnaps.map((snap) => snap.data() || {})
  );
  const terminalReservations = [];
  let stockAvailable = true;
  for (const line of lines) {
    const identity = canonicalLineIdentity(line);
    const reservationSnap = await reservationRef(db, identity).get();
    if (!reservationSnap.exists) {
      stockAvailable = false;
      terminalReservations.push({ lineId: line.lineId, status: "missing" });
      continue;
    }
    const reservation = reservationSnap.data() || {};
    terminalReservations.push({ lineId: line.lineId, status: reservation.status });
    if (![RESERVATION_STATUS.EXPIRED, RESERVATION_STATUS.RELEASED].includes(reservation.status)) {
      stockAvailable = false;
    }
    const productSnap = await db
      .collection("businesses")
      .doc(identity.businessId)
      .collection("products")
      .doc(identity.productId)
      .get();
    const product = productSnap.data() || {};
    const stock = Number(product.stock);
    const reservedStock = Number(product.reservedStock || 0);
    if (!Number.isFinite(stock) || !Number.isFinite(reservedStock) || stock - reservedStock < Number(line.quantity)) {
      stockAvailable = false;
    }
  }
  const hasTerminalReservation = terminalReservations.some((item) =>
    [RESERVATION_STATUS.EXPIRED, RESERVATION_STATUS.RELEASED].includes(item.status)
  );
  if (!hasTerminalReservation) {
    return { status: "not_applicable", orderId, reason: "reservation_not_expired" };
  }
  const operationId = `late-payment:${encodeURIComponent(String(orderId))}:${encodeURIComponent(String(paymentId || "unknown"))}`;
  const recoveryRef = db.collection("inventoryLatePaymentRecoveries").doc(operationId);
  const recovery = {
    operationId,
    orderId: String(orderId),
    provider: String(provider || "unknown"),
    paymentId: String(paymentId || "unknown"),
    amount: Number(amount),
    currency: String(currency || "").toUpperCase(),
    status: "manual_review",
    stockAvailable,
    reservationStates: terminalReservations,
    reason: stockAvailable
      ? "expired_reservation_requires_new_reacquisition_flow"
      : "expired_reservation_stock_conflict",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await recoveryRef.set({ ...recovery, createdAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  await markInventoryManualReview({
    db,
    rootRef,
    sellerRefs: sellerSnaps.filter((snap) => snap.exists).map((snap) => snap.ref),
    reason: recovery.reason,
    details: { operationId, stockAvailable },
  });
  return { status: "manual_review", orderId, operationId, stockAvailable };
}

module.exports = {
  M5_MAX_ATTEMPTS,
  M5_FLAG_ENV,
  m5FeatureEnabled,
  releaseMarketplaceInventory,
  recoverStaleReservation,
  recordLatePaymentAfterExpiry,
  updateReleaseAggregate,
};
