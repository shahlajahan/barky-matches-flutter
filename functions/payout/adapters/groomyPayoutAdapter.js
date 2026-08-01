"use strict";

const {
  createAppointmentPayoutAdapter,
} = require("./createAppointmentPayoutAdapter");
const {
  normalizeGroomyPayout,
} = require("../normalizers/groomyPayoutNormalizer");

const getBusinessId = (record) => record?.businessId || record?.groomyId || null;
const groomyPayoutAdapter = createAppointmentPayoutAdapter({
  sector: "groomy",
  collection: "groomy_appointments",
  normalizePayout: normalizeGroomyPayout,
  getBusinessId,
});

module.exports = { groomyPayoutAdapter };
