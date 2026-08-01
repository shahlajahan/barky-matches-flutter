"use strict";

const TURKISH_IBAN_REGEX = /^TR\d{24}$/;
const REFUNDED_SOURCE_STATUSES = new Set([
  "cancelled",
  "refunded",
  "reversed",
  "voided",
  "refund_pending",
  "cancellation_refund_pending",
]);

function text(value) {
  return String(value || "").trim();
}

function lower(value) {
  return text(value).toLowerCase();
}

function cents(value) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.round(number * 100) : 0;
}

function money(value) {
  return cents(value) / 100;
}

function payoutValidationReasons(
  record,
  { allowReservedBatchId = null, useFrozenBankSnapshot = false } = {}
) {
  const reasons = [];
  const payoutStatus = lower(record?.payoutStatus);
  const settlementStatus = lower(record?.settlementStatus);
  const sourceStatus = lower(record?.sourceStatus);
  const iban = text(record?.iban).replace(/\s+/g, "").toUpperCase();
  const batchId = text(record?.batchId);
  const eligibilityStatus = lower(record?.eligibilityStatus);
  if (["missing_snapshot", "ambiguous_legacy", "commission_unknown"].includes(lower(record?.commissionDataQuality))) {
    reasons.push("commission_unknown");
  }

  if (!text(record?.businessId)) reasons.push("missing_business");
  if (!useFrozenBankSnapshot) {
    if (!text(record?.accountHolderName)) reasons.push("missing_account_holder");
    if (!iban) {
      reasons.push("missing_iban");
    } else if (!TURKISH_IBAN_REGEX.test(iban)) {
      reasons.push("invalid_iban");
    }
    if (!text(record?.bankName)) reasons.push("missing_bank_name");
  }
  if (cents(record?.amount) <= 0) reasons.push("non_positive_amount");
  if (settlementStatus !== "completed") reasons.push("settlement_incomplete");
  if (!["pending", "ready"].includes(payoutStatus)) {
    reasons.push(
      ["hold", "recovery_required"].includes(payoutStatus)
        ? "payout_blocked"
        : payoutStatus === "paid"
          ? "already_paid"
          : "payout_ineligible"
    );
  }
  if (
    REFUNDED_SOURCE_STATUSES.has(sourceStatus) ||
    sourceStatus.includes("refund") ||
    sourceStatus.includes("cancel")
  ) {
    reasons.push("refunded_or_cancelled");
  }
  if (batchId && batchId !== allowReservedBatchId) {
    reasons.push("already_batched");
  }
  const requiredEligibility = allowReservedBatchId ? "batched" : "eligible";
  if (eligibilityStatus !== requiredEligibility) {
    reasons.push(
      eligibilityStatus === "waiting_period"
        ? "waiting_period"
        : eligibilityStatus === "on_hold"
          ? "on_hold"
          : eligibilityStatus === "blocked"
            ? "eligibility_blocked"
            : eligibilityStatus === "reversed" ||
                eligibilityStatus === "cancelled"
              ? "refunded_or_cancelled"
              : "not_eligible"
    );
  }

  return Array.from(new Set(reasons));
}

function aggregationKey(record) {
  return [
    text(record.businessId),
    text(record.currency).toUpperCase(),
    lower(record.payoutStatus),
    text(record.accountHolderName).toLocaleLowerCase("tr"),
    text(record.iban).replace(/\s+/g, "").toUpperCase(),
    text(record.taxNumber),
  ].join("|");
}

function aggregatePayoutRecords(records, options = {}) {
  const groups = new Map();

  records.forEach((record, stableIndex) => {
    const validationReasons = payoutValidationReasons(record, options);
    const key = aggregationKey(record);
    const existing = groups.get(key) || {
      key,
      businessId: text(record.businessId),
      sector: text(record.sector),
      businessName: text(record.businessName),
      legalBusinessName: text(record.legalBusinessName),
      accountHolderName: text(record.accountHolderName),
      iban: text(record.iban).replace(/\s+/g, "").toUpperCase(),
      bankName: text(record.bankName),
      taxNumber: text(record.taxNumber),
      contactEmail: text(record.contactEmail),
      contactPhone: text(record.contactPhone),
      currency: text(record.currency).toUpperCase(),
      payoutStatus: lower(record.payoutStatus),
      settlementStatus: lower(record.settlementStatus),
      payoutCount: 0,
      grossCents: 0,
      commissionCents: 0,
      netCents: 0,
      earliestSourceMillis: null,
      latestSourceMillis: null,
      payoutIndexIds: [],
      sourceDocumentIds: [],
      records: [],
      validationReasons: [],
      stableIndex,
    };

    const sourceMillis = Number(record.sourceCreatedMillis || 0);
    existing.payoutCount += 1;
    const financeValid = !validationReasons.includes("commission_unknown");
    if (financeValid) {
      existing.grossCents += cents(record.grossAmount);
      existing.commissionCents += cents(record.commissionAmount);
      existing.netCents += cents(record.amount);
    }
    existing.payoutIndexIds.push(text(record.indexId || record.id));
    existing.sourceDocumentIds.push(text(record.sourceDocumentId));
    existing.records.push(record);
    existing.validationReasons.push(...validationReasons);
    if (sourceMillis > 0) {
      existing.earliestSourceMillis =
        existing.earliestSourceMillis === null
          ? sourceMillis
          : Math.min(existing.earliestSourceMillis, sourceMillis);
      existing.latestSourceMillis =
        existing.latestSourceMillis === null
          ? sourceMillis
          : Math.max(existing.latestSourceMillis, sourceMillis);
    }
    groups.set(key, existing);
  });

  return Array.from(groups.values())
    .map((group) => ({
      ...group,
      grossTotal: group.grossCents / 100,
      commissionTotal: group.commissionCents / 100,
      netTotal: group.netCents / 100,
      validationReasons: Array.from(new Set(group.validationReasons)),
      isValid: group.validationReasons.length === 0,
    }))
    .sort((a, b) => a.stableIndex - b.stableIndex);
}

module.exports = {
  TURKISH_IBAN_REGEX,
  REFUNDED_SOURCE_STATUSES,
  cents,
  money,
  payoutValidationReasons,
  aggregationKey,
  aggregatePayoutRecords,
};
