"use strict";

const admin = require("firebase-admin");
const {
  ACCOUNTING_PERIOD_STATUS,
  assertPeriodMutable,
} = require("./accountingPeriods");
const {
  appendLedgerEntry,
} = require("./financeLedger");

function requiredText(value, field) {
  const text = String(value || "").trim();
  if (!text) {
    const error = new Error(`${field} is required.`);
    error.code = "invalid-argument";
    throw error;
  }
  return text;
}

async function createAccountingPeriod({
  db,
  adminUid,
  type,
  periodStart,
  periodEnd,
  currency = "TRY",
}) {
  const normalizedType = requiredText(type, "type").toLowerCase();
  if (!["weekly", "monthly"].includes(normalizedType)) {
    const error = new Error("Accounting period type must be weekly or monthly.");
    error.code = "invalid-argument";
    throw error;
  }
  const start = new Date(periodStart);
  const end = new Date(periodEnd);
  if (
    Number.isNaN(start.getTime()) ||
    Number.isNaN(end.getTime()) ||
    end <= start
  ) {
    const error = new Error("A valid accounting period range is required.");
    error.code = "invalid-argument";
    throw error;
  }
  const periodId = [
    normalizedType,
    String(currency).toUpperCase(),
    start.toISOString().slice(0, 10),
    end.toISOString().slice(0, 10),
  ].join("_");
  const ref = db.collection("accountingPeriods").doc(periodId);
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(ref);
    if (existing.exists) return;
    transaction.create(ref, {
      type: normalizedType,
      periodStart: admin.firestore.Timestamp.fromDate(start),
      periodEnd: admin.firestore.Timestamp.fromDate(end),
      currency: String(currency).toUpperCase(),
      status: ACCOUNTING_PERIOD_STATUS.OPEN,
      createdAt: now,
      createdBy: adminUid,
      updatedAt: now,
    });
  });
  return { periodId, status: ACCOUNTING_PERIOD_STATUS.OPEN };
}

async function closeAccountingPeriod({ db, adminUid, periodId }) {
  const ref = db
    .collection("accountingPeriods")
    .doc(requiredText(periodId, "periodId"));
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) {
      const error = new Error("Accounting period not found.");
      error.code = "not-found";
      throw error;
    }
    const period = snapshot.data() || {};
    assertPeriodMutable(period);
    const now = admin.firestore.FieldValue.serverTimestamp();
    transaction.update(ref, {
      status: ACCOUNTING_PERIOD_STATUS.CLOSED,
      closedAt: now,
      closedBy: adminUid,
      updatedAt: now,
    });
    return { periodId, status: ACCOUNTING_PERIOD_STATUS.CLOSED };
  });
}

async function createManualAdjustment({
  db,
  adminUid,
  businessId,
  amount,
  currency = "TRY",
  reason,
  reference,
  accountingPeriodId = null,
}) {
  const normalizedBusinessId = requiredText(businessId, "businessId");
  const normalizedReason = requiredText(reason, "reason");
  const normalizedReference = requiredText(reference, "reference");
  const amountNumber = Number(amount);
  if (!Number.isFinite(amountNumber) || amountNumber === 0) {
    const error = new Error("Adjustment amount must be non-zero.");
    error.code = "invalid-argument";
    throw error;
  }
  const adjustmentRef = db.collection("financeAdjustments").doc();
  const periodRef = accountingPeriodId
    ? db.collection("accountingPeriods").doc(String(accountingPeriodId))
    : null;
  return db.runTransaction(async (transaction) => {
    const periodSnap = periodRef ? await transaction.get(periodRef) : null;
    if (periodRef && !periodSnap.exists) {
      const error = new Error("Accounting period not found.");
      error.code = "not-found";
      throw error;
    }
    if (periodSnap) assertPeriodMutable(periodSnap.data() || {});
    await appendLedgerEntry(transaction, db, {
      eventType: "manual_adjustment",
      sourceCollection: "financeAdjustments",
      sourceDocumentId: adjustmentRef.id,
      businessId: normalizedBusinessId,
      amount: Math.abs(amountNumber),
      currency,
      direction: amountNumber > 0 ? "credit" : "debit",
      actor: { type: "user", id: adminUid },
      reason: normalizedReason,
      reference: normalizedReference,
      idempotencyKey: adjustmentRef.id,
      metadata: { accountingPeriodId },
    });
    const now = admin.firestore.FieldValue.serverTimestamp();
    transaction.create(adjustmentRef, {
      businessId: normalizedBusinessId,
      amount: amountNumber,
      currency: String(currency).toUpperCase(),
      reason: normalizedReason,
      reference: normalizedReference,
      approvedBy: adminUid,
      approvedAt: now,
      accountingPeriodId,
      status: "approved",
      createdAt: now,
      createdBy: adminUid,
    });
    return {
      adjustmentId: adjustmentRef.id,
      status: "approved",
    };
  });
}

module.exports = {
  createAccountingPeriod,
  closeAccountingPeriod,
  createManualAdjustment,
};
