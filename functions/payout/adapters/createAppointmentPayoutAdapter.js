"use strict";

function createAppointmentPayoutAdapter({
  sector,
  collection,
  normalizePayout,
  getBusinessId,
}) {
  return {
    sector,
    collection,
    normalizePayout,
    getBusinessId,
    getRecoveryOwnerId: (record) =>
      record?.businessOwnerUid || record?.providerUid || null,
  };
}

module.exports = { createAppointmentPayoutAdapter };
