"use strict";

const ELIGIBILITY_HOLD_DAYS = 21;
const ELIGIBILITY_HOLD_MILLIS =
  ELIGIBILITY_HOLD_DAYS * 24 * 60 * 60 * 1000;
const PLATFORM_TIMEZONE_OFFSET_MILLIS = 3 * 60 * 60 * 1000;

const ELIGIBILITY_STATUS = Object.freeze({
  WAITING_PERIOD: "waiting_period",
  ELIGIBLE: "eligible",
  BLOCKED: "blocked",
  ON_HOLD: "on_hold",
  BATCHED: "batched",
  PAID: "paid",
  REVERSED: "reversed",
  CANCELLED: "cancelled",
});

const TERMINAL_SOURCE_STATUSES = new Set([
  "cancelled",
  "cancelled_by_user",
  "cancelled_by_business",
  "cancelled_by_vet",
  "cancelled_by_groomy",
  "cancelled_by_hotel",
  "refunded",
  "reversed",
  "voided",
]);

const ACTIVE_DISPUTE_STATUSES = new Set([
  "open",
  "pending",
  "under_review",
  "escalated",
  "chargeback",
]);

function timestampMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function normalized(value) {
  return String(value || "").trim().toLowerCase();
}

// Turkey has remained UTC+03:00 year-round since 2016. Finance eligibility
// starts at 00:00 Europe/Istanbul on the 22nd calendar day, never at the
// original payment clock time.
function eligibilityDateMillis(successfulPaymentMillis) {
  const local = new Date(
    successfulPaymentMillis + PLATFORM_TIMEZONE_OFFSET_MILLIS
  );
  return (
    Date.UTC(
      local.getUTCFullYear(),
      local.getUTCMonth(),
      local.getUTCDate() + ELIGIBILITY_HOLD_DAYS
    ) - PLATFORM_TIMEZONE_OFFSET_MILLIS
  );
}

function verifiedPaymentTimestamp(record) {
  const payment = record?.payment || {};
  const candidates = [];
  if (payment.callbackValidated === true) {
    candidates.push([
      "payment.callbackValidatedAt",
      payment.callbackValidatedAt,
    ]);
  }
  if (normalized(payment.finalizationStatus) === "completed") {
    candidates.push([
      "payment.finalizationCompletedAt",
      payment.finalizationCompletedAt,
    ]);
  }
  if (
    normalized(record?.paymentStatus || payment.status) === "paid" ||
    normalized(record?.status) === "paid" ||
    normalized(record?.status) === "confirmed_paid"
  ) {
    candidates.push(
      ["payment.paidAt", payment.paidAt],
      ["paidAt", record?.paidAt]
    );
  }
  for (const [source, value] of candidates) {
    const millis = timestampMillis(value);
    if (millis !== null) return { millis, source };
  }
  return null;
}

function refundOrReversalStatus(record) {
  const sourceStatus = normalized(record?.status);
  const refundStatus = normalized(
    record?.refundStatus ||
      record?.refund?.status ||
      record?.financial?.refundReconciliation?.status
  );
  const payoutStatus = normalized(record?.payout?.status);
  if (TERMINAL_SOURCE_STATUSES.has(sourceStatus)) return sourceStatus;
  if (
    refundStatus === "refunded" ||
    refundStatus === "completed" ||
    ["reversed", "voided", "cancelled"].includes(payoutStatus)
  ) {
    return refundStatus || payoutStatus;
  }
  return null;
}

function activeBlockingReasons(record) {
  const reasons = [];
  const settlement = normalized(record?.settlement?.status);
  const refundStatus = normalized(
    record?.refundStatus || record?.refund?.status
  );
  const disputeStatus = normalized(
    record?.disputeStatus || record?.dispute?.status
  );
  if (["failed", "blocked", "awaiting_invoice"].includes(settlement)) {
    reasons.push(`settlement_${settlement}`);
  }
  if (
    refundStatus &&
    !["none", "rejected", "cancelled", "refunded", "completed"].includes(
      refundStatus
    )
  ) {
    reasons.push(`refund_${refundStatus}`);
  }
  if (ACTIVE_DISPUTE_STATUSES.has(disputeStatus)) {
    reasons.push(`dispute_${disputeStatus}`);
  }
  return reasons;
}

function activeHoldReasons(record) {
  const hold = record?.financeHold || record?.payout?.hold || {};
  const reasons = [];
  if (hold.active === true) reasons.push(normalized(hold.reason) || "manual");
  if (record?.complianceHold === true) reasons.push("compliance");
  if (record?.fraudReview === true) reasons.push("fraud_review");
  if (record?.taxReview === true) reasons.push("tax_review");
  const payoutStatus = normalized(record?.payout?.status);
  if (payoutStatus === "hold") reasons.push("refund_reconciliation");
  if (payoutStatus === "recovery_required") reasons.push("seller_recovery");
  return Array.from(new Set(reasons));
}

function evaluatePayoutEligibility({
  record,
  nowMillis = Date.now(),
  batchId = null,
}) {
  const payoutStatus = normalized(record?.payout?.status);
  const sourceTerminal = refundOrReversalStatus(record);
  const verified = verifiedPaymentTimestamp(record);
  const blockingReasons = activeBlockingReasons(record);
  const holdReasons = activeHoldReasons(record);

  if (payoutStatus === "paid") {
    return {
      status: ELIGIBILITY_STATUS.PAID,
      successfulPaymentAtMillis: verified?.millis || null,
      successfulPaymentSource: verified?.source || null,
      eligibilityDateMillis: verified
        ? eligibilityDateMillis(verified.millis)
        : null,
      reasonCodes: [],
    };
  }
  if (sourceTerminal) {
    return {
      status: sourceTerminal.includes("cancel")
        ? ELIGIBILITY_STATUS.CANCELLED
        : ELIGIBILITY_STATUS.REVERSED,
      successfulPaymentAtMillis: verified?.millis || null,
      successfulPaymentSource: verified?.source || null,
      eligibilityDateMillis: verified
        ? eligibilityDateMillis(verified.millis)
        : null,
      reasonCodes: [sourceTerminal],
    };
  }
  if (holdReasons.length > 0) {
    return {
      status: ELIGIBILITY_STATUS.ON_HOLD,
      successfulPaymentAtMillis: verified?.millis || null,
      successfulPaymentSource: verified?.source || null,
      eligibilityDateMillis: verified
        ? eligibilityDateMillis(verified.millis)
        : null,
      reasonCodes: holdReasons,
    };
  }
  if (blockingReasons.length > 0) {
    return {
      status: ELIGIBILITY_STATUS.BLOCKED,
      successfulPaymentAtMillis: verified?.millis || null,
      successfulPaymentSource: verified?.source || null,
      eligibilityDateMillis: verified
        ? eligibilityDateMillis(verified.millis)
        : null,
      reasonCodes: blockingReasons,
    };
  }
  if (!verified) {
    return {
      status: ELIGIBILITY_STATUS.BLOCKED,
      successfulPaymentAtMillis: null,
      successfulPaymentSource: null,
      eligibilityDateMillis: null,
      reasonCodes: ["missing_verified_payment_timestamp"],
    };
  }
  const eligibleAtMillis = eligibilityDateMillis(verified.millis);
  if (batchId) {
    return {
      status: ELIGIBILITY_STATUS.BATCHED,
      successfulPaymentAtMillis: verified.millis,
      successfulPaymentSource: verified.source,
      eligibilityDateMillis: eligibleAtMillis,
      reasonCodes: [],
    };
  }
  return {
    status:
      nowMillis >= eligibleAtMillis
        ? ELIGIBILITY_STATUS.ELIGIBLE
        : ELIGIBILITY_STATUS.WAITING_PERIOD,
    successfulPaymentAtMillis: verified.millis,
    successfulPaymentSource: verified.source,
    eligibilityDateMillis: eligibleAtMillis,
    reasonCodes: [],
  };
}

module.exports = {
  ELIGIBILITY_HOLD_DAYS,
  ELIGIBILITY_HOLD_MILLIS,
  ELIGIBILITY_STATUS,
  timestampMillis,
  eligibilityDateMillis,
  verifiedPaymentTimestamp,
  evaluatePayoutEligibility,
};
