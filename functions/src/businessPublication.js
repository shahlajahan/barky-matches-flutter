const { isPetTaxiBusiness } = require("./businessSectorMembership");

function hasOwn(value, key) {
  return Object.prototype.hasOwnProperty.call(value || {}, key);
}

function approvalPublicationPatch(businessData = {}) {
  const published = businessData.published;

  if (isPetTaxiBusiness(businessData)) {
    return {
      published: published == null ? false : published,
    };
  }

  return {
    published: published == null ? true : published,
  };
}

function needsPublishedBackfill(businessData = {}) {
  return businessData.status === "approved" && businessData.published == null;
}

function plannedPublishedValue(businessData = {}) {
  if (!needsPublishedBackfill(businessData)) return null;
  return isPetTaxiBusiness(businessData) ? false : true;
}

function hasInvalidPetTaxiContamination(businessData = {}) {
  return Boolean(!isPetTaxiBusiness(businessData) &&
    businessData.sectorData &&
    typeof businessData.sectorData === "object" &&
    hasOwn(businessData.sectorData, "pet_taxi"));
}

module.exports = {
  approvalPublicationPatch,
  hasInvalidPetTaxiContamination,
  needsPublishedBackfill,
  plannedPublishedValue,
};
