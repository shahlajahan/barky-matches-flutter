"use strict";

const {
  createSectorPayoutNormalizer,
} = require("./createSectorPayoutNormalizer");

const normalizeVetPayout = createSectorPayoutNormalizer({
  sector: "vet",
  getBusinessId: (record) => record?.businessId || record?.vetId || null,
  getCurrency: (record) => record?.paymentCurrency || record?.currency || "TRY",
});

module.exports = { normalizeVetPayout };
