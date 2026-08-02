"use strict";

const admin = require("firebase-admin");
const {
  financialEventData,
  newFinancialEventRef,
  createFinancialEvent,
} = require("../payout/financialEvents");
const { getPayoutSectorAdapter } = require("../payout/sectorAdapters");
const {
  FINANCIAL_STATUS,
  isVerifiedFinancial,
} = require("../finance/paymentIntegrity");

const SETTLEMENT_STATUS = Object.freeze({
  NOT_STARTED: "not_started",
  PROCESSING: "processing",
  COMPLETED: "completed",
  FAILED: "failed",
  BLOCKED: "blocked",
});

function now() {
  return admin.firestore.FieldValue.serverTimestamp();
}

function settlementPatch(status, attempts, extra = {}) {
  return {
    status,
    attempts,
    lastAttemptAt: now(),
    ...extra,
  };
}

async function recordSettlementResult({
  db,
  adapter,
  recordRef,
  record,
  status,
  attempts,
  operationId,
  failureCode = null,
  failureMessage = null,
  reason = null,
  payout = null,
  actor = { type: "system", id: "settlement" },
}) {
  const eventRef = newFinancialEventRef(db);
  await db.runTransaction(async (transaction) => {
    const fresh = await transaction.get(recordRef);
    const freshRecord = fresh.exists ? fresh.data() || {} : record;
    const businessId = adapter.getBusinessId(freshRecord);
    const financial = freshRecord.financial || record.financial || {};
    const amount = Number(financial.businessNetAmount);

    transaction.set(
      recordRef,
      {
        settlement: settlementPatch(status, attempts, {
          operationId: operationId || null,
          failureCode,
          failureMessage,
          reason,
          completedAt: status === SETTLEMENT_STATUS.COMPLETED ? now() : null,
        }),
        ...(payout ? { payout } : {}),
        updatedAt: now(),
      },
      { merge: true }
    );

    createFinancialEvent(
      transaction,
      eventRef,
      financialEventData({
        eventType:
          status === SETTLEMENT_STATUS.COMPLETED
            ? "settlement_completed"
            : status === SETTLEMENT_STATUS.BLOCKED
              ? "settlement_blocked"
              : "settlement_failed",
        sourceCollection: adapter.collection,
        sourceDocument: recordRef.id,
        sector: adapter.sector,
        businessId,
        actor,
        previousState: freshRecord.settlement?.status || SETTLEMENT_STATUS.PROCESSING,
        newState: status,
        amount: Number.isFinite(amount) ? amount : null,
        currency: financial.currency || freshRecord.payout?.currency || null,
        reason: reason || failureCode || null,
        metadata: {
          failureMessage,
          attempts,
          operationId: operationId || null,
        },
      })
    );
  });
}

async function settlePayable({ db, sector, recordRef, actor, operationId = null }) {
  const adapter = getPayoutSectorAdapter(sector);
  const settlementOperationId = operationId || `settlement-${sector}-${recordRef.id}`;
  let record;
  let attempts;

  try {
    const claim = await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(recordRef);
      if (!snap.exists) {
        return { missing: true };
      }

      const current = snap.data() || {};
      const paymentStatus = current.paymentStatus || current.payment?.status || null;
      const paymentFinalizationStatus = current.payment?.finalizationStatus || null;
      if (
        (paymentStatus && paymentStatus !== "paid") ||
        (paymentFinalizationStatus && paymentFinalizationStatus !== "completed")
      ) {
        return { paymentNotFinalized: true };
      }
      if (
        !isVerifiedFinancial({
          financialStatus: current.financialStatus,
          financial: current.financial,
        })
      ) {
        return {
          financialRepairRequired: true,
          record: current,
          attempts: Number(current.settlement?.attempts || 0),
        };
      }
      const settlement = current.settlement || {};
      if (settlement.status === SETTLEMENT_STATUS.COMPLETED) {
        return { completed: true };
      }

      const nextAttempts = Number(settlement.attempts || 0) + 1;
      transaction.set(
        recordRef,
        {
          settlement: settlementPatch(SETTLEMENT_STATUS.PROCESSING, nextAttempts, {
            operationId: settlementOperationId,
            failureCode: null,
            failureMessage: null,
            reason: null,
          }),
          updatedAt: now(),
        },
        { merge: true }
      );
      return { record: current, attempts: nextAttempts };
    });

    if (claim.missing) return { status: "missing" };
    if (claim.paymentNotFinalized) return { status: "payment_not_finalized" };
    if (claim.completed) return { status: SETTLEMENT_STATUS.COMPLETED };
    if (claim.financialRepairRequired) {
      await recordSettlementResult({
        db,
        adapter,
        recordRef,
        record: claim.record,
        status: SETTLEMENT_STATUS.BLOCKED,
        attempts: claim.attempts,
        operationId: settlementOperationId,
        failureCode: "FINANCIAL_REPAIR_REQUIRED",
        reason: FINANCIAL_STATUS.REQUIRES_REPAIR,
        failureMessage:
          "Settlement is paused until the financial snapshot is repaired and verified.",
        actor,
      });
      return {
        status: SETTLEMENT_STATUS.BLOCKED,
        reason: "FINANCIAL_REPAIR_REQUIRED",
      };
    }

    record = claim.record;
    attempts = claim.attempts;
    const financial = record.financial || {};
    const amount = Number(financial.businessNetAmount);

    if (!Number.isFinite(amount)) {
      await recordSettlementResult({
        db,
        adapter,
        recordRef,
        record,
        status: SETTLEMENT_STATUS.FAILED,
        attempts,
        operationId: settlementOperationId,
        failureCode: "MISSING_FINANCIAL_SNAPSHOT",
        failureMessage: "A frozen financial snapshot is required for settlement.",
        actor,
      });
      return { status: SETTLEMENT_STATUS.FAILED };
    }

    if (amount < 0) {
      await recordSettlementResult({
        db,
        adapter,
        recordRef,
        record,
        status: SETTLEMENT_STATUS.BLOCKED,
        attempts,
        operationId: settlementOperationId,
        failureCode: "NEGATIVE_PAYABLE",
        reason: "NEGATIVE_PAYABLE",
        failureMessage: "The financial snapshot has a negative business payable.",
        actor,
      });
      return { status: SETTLEMENT_STATUS.BLOCKED };
    }

    const payout = adapter.normalizePayout({
      record,
      financial,
      existingPayout: record.payout,
      amount,
      currency: financial.currency || record.payout?.currency || "TRY",
      status: "pending",
      timestamp: now(),
    });
    await recordSettlementResult({
      db,
      adapter,
      recordRef,
      record,
      status: SETTLEMENT_STATUS.COMPLETED,
      attempts,
      operationId: settlementOperationId,
      payout,
      actor,
    });
    return { status: SETTLEMENT_STATUS.COMPLETED };
  } catch (error) {
    if (!record) throw error;
    await recordSettlementResult({
      db,
      adapter,
      recordRef,
      record,
      status: SETTLEMENT_STATUS.FAILED,
      attempts,
      operationId: settlementOperationId,
      failureCode: "SETTLEMENT_ERROR",
      failureMessage: error?.message || String(error),
      actor,
    });
    return { status: SETTLEMENT_STATUS.FAILED };
  }
}

module.exports = {
  SETTLEMENT_STATUS,
  settlePayable,
};
