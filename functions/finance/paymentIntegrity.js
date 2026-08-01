"use strict";

const FINANCIAL_STATUS = Object.freeze({
  PENDING: "pending",
  VERIFIED: "verified",
  REQUIRES_REPAIR: "requires_repair",
});

function normalizedFinancialStatus(value) {
  const status = String(value || "").trim().toLowerCase();
  return Object.values(FINANCIAL_STATUS).includes(status) ? status : null;
}

function isVerifiedFinancial({ financialStatus, financial } = {}) {
  const status = normalizedFinancialStatus(financialStatus);
  if (status) return status === FINANCIAL_STATUS.VERIFIED;
  return financial?.commissionDataQuality === "verified_snapshot";
}

function financialStatusFor(financial) {
  return financial?.commissionDataQuality === "verified_snapshot"
    ? FINANCIAL_STATUS.VERIFIED
    : FINANCIAL_STATUS.REQUIRES_REPAIR;
}

module.exports = {
  FINANCIAL_STATUS,
  normalizedFinancialStatus,
  isVerifiedFinancial,
  financialStatusFor,
};
