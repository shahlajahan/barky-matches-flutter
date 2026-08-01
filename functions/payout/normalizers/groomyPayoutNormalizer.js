"use strict";

const {
  createSectorPayoutNormalizer,
} = require("./createSectorPayoutNormalizer");

const normalizeGroomyPayout = createSectorPayoutNormalizer({
  sector: "groomy",
  getBusinessId: (record) => record?.businessId || record?.groomyId || null,
  getCurrency: (record) => record?.paymentCurrency || record?.currency || "TRY",
});

module.exports = { normalizeGroomyPayout };
