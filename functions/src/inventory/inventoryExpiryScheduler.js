"use strict";

const admin = require("firebase-admin");
const { FieldPath } = admin.firestore;
const { RESERVATION_STATUS } = require("./inventoryConstants");
const { expireAndReleaseInventory } = require("./inventoryTransactions");
const { canonicalLineIdentity } = require("./inventoryIdentity");
const { m5FeatureEnabled, recoverStaleReservation } = require("./inventoryReleaseCoordinator");

const DEFAULT_BATCH_SIZE = 100;
const CHECKPOINT_ID = "m5-expiry-reservations";

async function processExpiredInventoryReservations({ db = admin.firestore(), limit = DEFAULT_BATCH_SIZE, now = admin.firestore.Timestamp.now(), logger = console } = {}) {
  if (!m5FeatureEnabled("expiry_scheduler", { scheduler: true })) {
    return { status: "disabled", scanned: 0, released: 0, failed: 0 };
  }
  const checkpointRef = db.collection("inventoryRecoveryCheckpoints").doc(CHECKPOINT_ID);
  const checkpointSnap = await checkpointRef.get();
  const checkpoint = checkpointSnap.exists ? checkpointSnap.data() || {} : {};
  let query = db.collection("inventoryReservations")
    .where("status", "==", RESERVATION_STATUS.RESERVED)
    .where("expiresAt", "<=", now)
    .orderBy("expiresAt")
    .orderBy(FieldPath.documentId())
    .limit(Math.max(1, Math.min(Number(limit) || DEFAULT_BATCH_SIZE, DEFAULT_BATCH_SIZE)));
  if (checkpoint.lastExpiresAt && checkpoint.lastReservationId) {
    query = query.startAfter(checkpoint.lastExpiresAt, checkpoint.lastReservationId);
  }
  const snapshot = await query.get();
  let released = 0;
  let failed = 0;
  let last = null;
  for (const reservationSnap of snapshot.docs) {
    const data = reservationSnap.data() || {};
    last = { lastExpiresAt: data.expiresAt || null, lastReservationId: reservationSnap.id };
    try {
      const result = await expireAndReleaseInventory({
        db,
        identity: canonicalLineIdentity(data),
        reason: "reservation_expired",
        now,
      });
      if (["expired", "already_expired"].includes(result.status)) released += 1;
      logger.info?.("inventory_expiry_processed", {
        orderId: data.rootOrderId,
        sellerOrderId: data.sellerOrderId,
        lineId: data.lineId,
        productId: data.productId,
        operationId: result.operationId || null,
        previousState: data.status,
        nextState: result.status,
        reason: "reservation_expired",
      });
    } catch (error) {
      failed += 1;
      logger.error?.("inventory_expiry_failed", {
        orderId: data.rootOrderId,
        sellerOrderId: data.sellerOrderId,
        lineId: data.lineId,
        productId: data.productId,
        operationId: null,
        attempt: data.attempt || 0,
        reason: error.code || "internal_retryable",
      });
    }
  }
  if (last && snapshot.size >= Math.max(1, Math.min(Number(limit) || DEFAULT_BATCH_SIZE, DEFAULT_BATCH_SIZE))) {
    await checkpointRef.set({ ...last, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  } else {
    await checkpointRef.delete().catch(() => {});
  }
  return { status: "completed", scanned: snapshot.size, released, failed, checkpoint: last };
}

async function processStaleInventoryLeases({ db = admin.firestore(), limit = DEFAULT_BATCH_SIZE, now = admin.firestore.Timestamp.now(), logger = console } = {}) {
  if (!m5FeatureEnabled("lease_recovery", { scheduler: true })) {
    return { status: "disabled", scanned: 0, recovered: 0, failed: 0 };
  }
  const cappedLimit = Math.max(1, Math.min(Number(limit) || DEFAULT_BATCH_SIZE, DEFAULT_BATCH_SIZE));
  const [reservationSnapshot, commitSnapshot] = await Promise.all([
    db.collection("inventoryReservations")
      .where("status", "in", ["reserving", "releasing"])
      .where("leaseExpiresAt", "<=", now)
      .orderBy("leaseExpiresAt")
      .limit(cappedLimit)
      .get(),
    db.collection("inventoryReservations")
      .where("inventoryCommitState", "==", "committing")
      .where("leaseExpiresAt", "<=", now)
      .orderBy("leaseExpiresAt")
      .limit(cappedLimit)
      .get(),
  ]);
  const byId = new Map();
  for (const snap of [...reservationSnapshot.docs, ...commitSnapshot.docs]) byId.set(snap.id, snap);
  let recovered = 0;
  let failed = 0;
  for (const reservationSnap of byId.values()) {
    const data = reservationSnap.data() || {};
    try {
      const result = await recoverStaleReservation({ db, reservationSnap, now });
      if (!["ignored", "release_pending", "manual_review"].includes(result.status)) recovered += 1;
      logger.info?.("inventory_stale_lease_recovered", {
        orderId: data.rootOrderId || null,
        sellerOrderId: data.sellerOrderId || null,
        lineId: data.lineId || null,
        productId: data.productId || null,
        operationId: data.lastOperationId || null,
        attempt: data.attempt || 0,
        previousState: data.status || data.inventoryCommitState || null,
        nextState: result.status,
        reason: result.reason || null,
      });
    } catch (recoveryError) {
      failed += 1;
      logger.error?.("inventory_stale_lease_recovery_failed", {
        orderId: data.rootOrderId || null,
        sellerOrderId: data.sellerOrderId || null,
        lineId: data.lineId || null,
        productId: data.productId || null,
        operationId: data.lastOperationId || null,
        attempt: data.attempt || 0,
        reason: recoveryError.code || "internal_retryable",
      });
    }
  }
  return { status: "completed", scanned: byId.size, recovered, failed };
}

module.exports = {
  CHECKPOINT_ID,
  DEFAULT_BATCH_SIZE,
  processExpiredInventoryReservations,
  processStaleInventoryLeases,
};
