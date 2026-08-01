"use strict";

const {
  createAppointmentPayoutAdapter,
} = require("./createAppointmentPayoutAdapter");
const { normalizeTaxiPayout } = require("../normalizers/taxiPayoutNormalizer");

const getBusinessId = (record) =>
  record?.businessId || record?.taxiBusinessId || null;
const taxiPayoutAdapter = createAppointmentPayoutAdapter({
  sector: "taxi",
  collection: "pet_taxi_bookings",
  normalizePayout: normalizeTaxiPayout,
  getBusinessId,
});

module.exports = { taxiPayoutAdapter };
