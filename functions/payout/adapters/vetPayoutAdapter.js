"use strict";

const {
  createAppointmentPayoutAdapter,
} = require("./createAppointmentPayoutAdapter");
const { normalizeVetPayout } = require("../normalizers/vetPayoutNormalizer");

const getBusinessId = (record) => record?.businessId || record?.vetId || null;
const vetPayoutAdapter = createAppointmentPayoutAdapter({
  sector: "vet",
  collection: "vet_appointments",
  normalizePayout: normalizeVetPayout,
  getBusinessId,
});

module.exports = { vetPayoutAdapter };
