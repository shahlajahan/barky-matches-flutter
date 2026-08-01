"use strict";

const {
  createAppointmentPayoutAdapter,
} = require("./createAppointmentPayoutAdapter");
const { normalizeHotelPayout } = require("../normalizers/hotelPayoutNormalizer");

const getBusinessId = (record) => record?.businessId || record?.hotelId || null;
const hotelPayoutAdapter = createAppointmentPayoutAdapter({
  sector: "hotel",
  collection: "hotel_bookings",
  normalizePayout: normalizeHotelPayout,
  getBusinessId,
});

module.exports = { hotelPayoutAdapter };
