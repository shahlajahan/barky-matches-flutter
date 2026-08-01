"use strict";

const {
  createSectorPayoutNormalizer,
} = require("./createSectorPayoutNormalizer");

const normalizeTaxiPayout = createSectorPayoutNormalizer({
  sector: "taxi",
  getBusinessId: (record) => record?.businessId || record?.taxiBusinessId || null,
  getCurrency: (record) =>
    record?.paymentCurrency || record?.finalPriceCurrency || record?.currency || "TRY",
});

module.exports = { normalizeTaxiPayout };
