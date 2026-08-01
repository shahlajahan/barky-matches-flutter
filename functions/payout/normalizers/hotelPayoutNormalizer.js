"use strict";

const {
  createSectorPayoutNormalizer,
} = require("./createSectorPayoutNormalizer");

const normalizeHotelPayout = createSectorPayoutNormalizer({
  sector: "hotel",
  getBusinessId: (record) => record?.businessId || record?.hotelId || null,
  getCurrency: (record) => record?.paymentCurrency || record?.currency || "TRY",
});

module.exports = { normalizeHotelPayout };
