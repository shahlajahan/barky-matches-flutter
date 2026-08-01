"use strict";

const PAYABLE_CONTRACT_VERSION = 1;

function finiteMoney(value) {
  const number = typeof value === "string" ? Number(value.trim()) : Number(value);
  return Number.isFinite(number) ? number : null;
}

function canonicalPayoutContract({
  sector,
  businessId,
  financial,
  amount,
  currency,
  currencyRaw,
  status,
  timestamp,
  requestedAt,
  reference,
  note,
  existingPayout,
}) {
  const existing =
    existingPayout && typeof existingPayout === "object" ? existingPayout : {};
  const normalizedAmount = finiteMoney(
    amount ??
      existing.amount ??
      financial?.businessNetAmount ??
      financial?.businessReceivable
  );

  if (!sector) throw new Error("Payable contract sector is required.");
  if (!businessId) throw new Error("Payable contract businessId is required.");
  if (normalizedAmount === null || normalizedAmount < 0) {
    throw new Error("Payable contract amount must be a non-negative number.");
  }

  const normalizedStatus = status || existing.status || "pending";

  return {
    version: PAYABLE_CONTRACT_VERSION,
    sector,
    businessId: String(businessId),
    status: normalizedStatus,
    amount: normalizedAmount,
    currency: String(currency || existing.currency || "TRY").trim().toUpperCase(),
    currencyRaw: currencyRaw ?? existing.currencyRaw ?? null,
    requestedAt:
      existing.requestedAt ||
      requestedAt ||
      (normalizedStatus === "pending" ? timestamp || null : null),
    readyAt: existing.readyAt || null,
    paidAt: existing.paidAt || null,
    reference: existing.reference || reference || null,
    note: existing.note || note || null,
    previousStatus: existing.previousStatus || null,
    holdAt: existing.holdAt || null,
    holdReason: existing.holdReason || null,
    recoveryRequiredAt: existing.recoveryRequiredAt || null,
    recoveryReason: existing.recoveryReason || null,
    outstandingDebt: finiteMoney(existing.outstandingDebt) || 0,
    relatedReturnIds: Array.isArray(existing.relatedReturnIds)
      ? existing.relatedReturnIds
      : [],
    updatedAt: timestamp || existing.updatedAt || null,
  };
}

function payableFromRecord({ adapter, record }) {
  const payout = adapter.normalizePayout({
    record,
    financial: record?.financial,
    existingPayout: record?.payout,
  });

  return {
    sector: adapter.sector,
    businessId: payout.businessId,
    payout,
    recoveryOwnerId: adapter.getRecoveryOwnerId
      ? adapter.getRecoveryOwnerId(record)
      : null,
  };
}

module.exports = {
  PAYABLE_CONTRACT_VERSION,
  canonicalPayoutContract,
  payableFromRecord,
};
