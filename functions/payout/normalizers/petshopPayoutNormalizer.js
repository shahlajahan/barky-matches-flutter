"use strict";

const {
  createSectorPayoutNormalizer,
} = require("./createSectorPayoutNormalizer");

const normalizePetshopPayout = createSectorPayoutNormalizer({
  sector: "petshop",
  getBusinessId: (record) => record?.businessId || record?.shopId || null,
  getCurrency: (record) =>
    record?.payout?.currency ||
    record?.financial?.currency ||
    record?.payment?.currency ||
    record?.currency ||
    "TRY",
});

module.exports = { normalizePetshopPayout };
