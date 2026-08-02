"use strict";

const crypto = require("node:crypto");
const admin = require("firebase-admin");
const { error } = require("./inventoryErrors");

const COLLECTION = "paymentCallbackClaims";
const CONFLICT_COLLECTION = "paymentIdentityConflicts";
const LEASE_MS = 15 * 60 * 1000;

function claimDocumentId(provider, orderId) {
  return `${encodeURIComponent(String(provider).trim().toLowerCase())}__${encodeURIComponent(String(orderId).trim())}`;
}

function claimRef(db, provider, orderId) {
  return db.collection(COLLECTION).doc(claimDocumentId(provider, orderId));
}

function normalizeClaimAmount(value) {
  const amount = Number(value);
  return Number.isFinite(amount) && amount >= 0 ? Number(amount.toFixed(2)) : null;
}

function normalizeClaimCurrency(value) {
  const currency = String(value || "").trim().toUpperCase();
  return currency || null;
}

function conflictDocumentId({ provider, orderId, paymentId, providerEventId }) {
  const source = [provider, orderId, paymentId, providerEventId || "none"].join("__");
  return crypto.createHash("sha256").update(source).digest("hex");
}

async function recordPaymentIdentityConflict({
  db,
  provider,
  orderId,
  originalPaymentId,
  conflictingPaymentId,
  providerEventId,
  amount,
  currency,
}) {
  const conflictId = conflictDocumentId({
    provider,
    orderId,
    paymentId: conflictingPaymentId,
    providerEventId,
  });
  const ref = db.collection(CONFLICT_COLLECTION).doc(conflictId);
  const now = admin.firestore.Timestamp.now();
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (snapshot.exists) return;
    transaction.create(ref, {
      provider,
      orderId,
      originalPaymentId,
      conflictingPaymentId,
      providerEventId: providerEventId || null,
      amount,
      currency,
      detectedAt: now,
      status: "manual_review",
      operationId: conflictId,
      correlationId: conflictId,
      createdAt: now,
      updatedAt: now,
    });
  });
  return ref;
}

async function claimPaymentCallback({
  db,
  provider,
  orderId,
  paymentId,
  providerEventId = null,
  amount,
  currency,
}) {
  const normalizedProvider = String(provider || "").trim().toLowerCase();
  const normalizedOrderId = String(orderId || "").trim();
  const normalizedPaymentId = String(paymentId || "").trim();
  const normalizedEventId = String(providerEventId || "").trim() || null;
  const normalizedAmount = normalizeClaimAmount(amount);
  const normalizedCurrency = normalizeClaimCurrency(currency);
  if (!normalizedProvider || !normalizedOrderId || !normalizedPaymentId ||
      normalizedAmount == null || !normalizedCurrency) {
    throw error(
      "invalid_callback_claim",
      "Provider, order, payment, amount and currency are required"
    );
  }
  const ref = claimRef(db, normalizedProvider, normalizedOrderId);
  const now = admin.firestore.Timestamp.now();
  const leaseExpiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + LEASE_MS);
  const ownerToken = crypto.randomUUID();

  try {
    return await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) {
      transaction.create(ref, {
        provider: normalizedProvider,
        orderId: normalizedOrderId,
        paymentId: normalizedPaymentId,
        providerEventIds: normalizedEventId ? [normalizedEventId] : [],
        amount: normalizedAmount,
        currency: normalizedCurrency,
        status: "processing",
        ownerToken,
        attempt: 1,
        startedAt: now,
        leaseExpiresAt,
        createdAt: now,
        updatedAt: now,
        result: null,
        error: null,
      });
      return { status: "claimed", ref, ownerToken, attempt: 1 };
    }

    const existing = snapshot.data() || {};
    if (String(existing.paymentId || "") !== normalizedPaymentId) {
      throw error("payment_identity_conflict", "A second payment identity cannot finalize this order", {
        orderId: normalizedOrderId,
        provider: normalizedProvider,
        originalPaymentId: String(existing.paymentId || ""),
        conflictingPaymentId: normalizedPaymentId,
        providerEventId: normalizedEventId,
        amount: normalizedAmount,
        currency: normalizedCurrency,
      }, { manualReview: true });
    }
    if (Number(existing.amount) !== normalizedAmount ||
        String(existing.currency || "").toUpperCase() !== normalizedCurrency) {
      throw error(
        "payment_evidence_conflict",
        "Payment amount or currency does not match the original callback",
        { orderId: normalizedOrderId },
        { manualReview: true }
      );
    }
    const existingEventIds = Array.isArray(existing.providerEventIds)
      ? existing.providerEventIds.map(String)
      : [];
    const providerEventIds = normalizedEventId && !existingEventIds.includes(normalizedEventId)
      ? [...existingEventIds, normalizedEventId]
      : existingEventIds;
    if (existing.status === "completed") {
      if (providerEventIds.length !== existingEventIds.length) {
        transaction.set(ref, { providerEventIds, updatedAt: now }, { merge: true });
      }
      return { status: "already_processed", ref, result: existing.result || null };
    }
    const leaseUntil = existing.leaseExpiresAt?.toMillis?.() || 0;
    if (existing.status === "processing" && leaseUntil > now.toMillis()) {
      if (providerEventIds.length !== existingEventIds.length) {
        transaction.set(ref, { providerEventIds, updatedAt: now }, { merge: true });
      }
      return { status: "processing", ref, result: existing.result || null };
    }

    const attempt = Math.max(1, Number(existing.attempt || 0) + 1);
    transaction.set(ref, {
      status: "processing",
      ownerToken,
      attempt,
      startedAt: now,
      leaseExpiresAt,
      updatedAt: now,
      error: null,
      providerEventIds,
      amount: normalizedAmount,
      currency: normalizedCurrency,
    }, { merge: true });
    return { status: "reclaimed", ref, ownerToken, attempt };
    });
  } catch (claimError) {
    if (claimError?.code === "payment_identity_conflict") {
      await recordPaymentIdentityConflict({
        db,
        provider: normalizedProvider,
        orderId: normalizedOrderId,
        originalPaymentId: claimError.details?.originalPaymentId,
        conflictingPaymentId: normalizedPaymentId,
        providerEventId: normalizedEventId,
        amount: normalizedAmount,
        currency: normalizedCurrency,
      });
    }
    throw claimError;
  }
}

async function completePaymentCallback({ ref, ownerToken, result }) {
  await ref.firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() || {};
    if (!snapshot.exists || data.ownerToken !== ownerToken) return;
    transaction.set(ref, {
      status: "completed",
      result,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      leaseExpiresAt: null,
      ownerToken: null,
    }, { merge: true });
  });
}

async function markPaymentCallbackCommitPending({ ref, ownerToken, result, errorData }) {
  await ref.firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() || {};
    if (!snapshot.exists || data.ownerToken !== ownerToken) return;
    transaction.set(ref, {
      status: "commit_pending",
      result,
      error: errorData || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      leaseExpiresAt: null,
      ownerToken: null,
    }, { merge: true });
  });
}

async function markPaymentCallbackSettlementPending({ ref, ownerToken, result, errorData }) {
  await ref.firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() || {};
    if (!snapshot.exists || data.ownerToken !== ownerToken) return;
    transaction.set(ref, {
      status: "settlement_pending",
      result,
      error: errorData || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      leaseExpiresAt: null,
      ownerToken: null,
    }, { merge: true });
  });
}

async function markPaymentCallbackManualReview({ ref, ownerToken, result, errorData }) {
  await ref.firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() || {};
    if (!snapshot.exists || data.ownerToken !== ownerToken) return;
    transaction.set(ref, {
      status: "manual_review",
      result,
      error: errorData || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      leaseExpiresAt: null,
      ownerToken: null,
    }, { merge: true });
  });
}

module.exports = {
  COLLECTION,
  claimPaymentCallback,
  completePaymentCallback,
  markPaymentCallbackCommitPending,
  markPaymentCallbackSettlementPending,
  markPaymentCallbackManualReview,
  recordPaymentIdentityConflict,
};
