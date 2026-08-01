"use strict";

const { canonicalPayoutContract } = require("../payableContract");

function createSectorPayoutNormalizer({ sector, getBusinessId, getCurrency }) {
  return function normalizePayout({
    record,
    financial,
    existingPayout,
    amount,
    currency,
    currencyRaw,
    status,
    timestamp,
    requestedAt,
    reference,
    note,
  }) {
    return canonicalPayoutContract({
      sector,
      businessId: getBusinessId(record),
      financial,
      amount,
      currency: currency || getCurrency(record),
      currencyRaw,
      status,
      timestamp,
      requestedAt,
      reference,
      note,
      existingPayout,
    });
  };
}

module.exports = { createSectorPayoutNormalizer };
