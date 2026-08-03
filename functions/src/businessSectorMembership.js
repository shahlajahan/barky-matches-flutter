const SECTOR_ALIASES = new Map([
  ["vet", "vet"],
  ["veterinary", "vet"],
  ["veterinarian", "vet"],
  ["clinic", "vet"],
  ["groomy", "groomy"],
  ["groomer", "groomy"],
  ["grooming", "groomy"],
  ["petgrooming", "groomy"],
  ["petshop", "pet_shop"],
  ["seller", "pet_shop"],
  ["petstore", "pet_shop"],
  ["store", "pet_shop"],
  ["pethotel", "pet_hotel"],
  ["hotel", "pet_hotel"],
  ["boarding", "pet_hotel"],
  ["petboarding", "pet_hotel"],
  ["pettaxi", "pet_taxi"],
  ["taxi", "pet_taxi"],
  ["adoptioncenter", "adoption_center"],
  ["adoption", "adoption_center"],
  ["training", "training"],
  ["trainer", "training"],
  ["dogtraining", "training"],
  ["pettraining", "training"],
]);

function normalizeSector(value) {
  if (value == null) return null;
  const normalized = String(value)
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, "_");
  if (!normalized) return null;
  return SECTOR_ALIASES.get(normalized.replace(/_/g, "")) || null;
}

function canonicalSectors(value) {
  const values = Array.isArray(value) ? value : [value];
  return new Set(values.map(normalizeSector).filter(Boolean));
}

function isPetTaxiSector(value) {
  return normalizeSector(value) === "pet_taxi";
}

function isPetTaxiBusiness(source = {}) {
  return canonicalSectors(source.sectors).has("pet_taxi");
}

function filterSectorDataByCanonicalSectors(sectorData, sectors) {
  if (!sectorData || typeof sectorData !== "object" || Array.isArray(sectorData)) {
    return {};
  }
  const allowed = canonicalSectors(sectors);
  return Object.fromEntries(
    Object.entries(sectorData).filter(([key]) => {
      const canonical = normalizeSector(key);
      return canonical != null && allowed.has(canonical);
    })
  );
}

function resolvePetTaxiCurrentLocationForMigration(businessData = {}) {
  if (!isPetTaxiBusiness(businessData)) {
    return { shouldBackfill: false, location: null, reason: "not_pet_taxi" };
  }

  const sectorData = businessData.sectorData || {};
  const taxi = sectorData.pet_taxi || sectorData.petTaxi || sectorData.taxi || {};
  const contact = businessData.contact || {};
  const currentLocation = taxi.currentLocation || {};
  const contactLocation = contact.location || {};
  const hasLatLng = (value) => (
    value &&
    typeof value.lat === "number" &&
    Number.isFinite(value.lat) &&
    typeof value.lng === "number" &&
    Number.isFinite(value.lng)
  );

  const currentHasCoordinates = hasLatLng(currentLocation);
  const contactHasCoordinates = hasLatLng(contactLocation);
  const source = String(currentLocation.source || "").trim().toLowerCase();
  const hasRuntimeTimestamp = Boolean(currentLocation.updatedAt);
  const currentLooksRuntime = currentHasCoordinates && (
    source === "gps_runtime" || hasRuntimeTimestamp
  );
  const currentLooksSeededAddress = currentHasCoordinates && (
    source === "registered_address_seed" ||
    source === "migrated_from_contact_location"
  );

  if (currentLooksRuntime || currentLooksSeededAddress) {
    return { shouldBackfill: false, location: currentLocation, reason: null };
  }
  if (contactHasCoordinates) {
    return {
      shouldBackfill: true,
      location: contactLocation,
      reason: currentHasCoordinates
        ? "legacy_current_location_without_runtime_timestamp"
        : "missing_current_location",
      previousCurrentLocation: currentHasCoordinates ? currentLocation : null,
    };
  }
  return {
    shouldBackfill: false,
    location: currentHasCoordinates ? currentLocation : null,
    reason: null,
  };
}

module.exports = {
  canonicalSectors,
  filterSectorDataByCanonicalSectors,
  isPetTaxiBusiness,
  isPetTaxiSector,
  normalizeSector,
  resolvePetTaxiCurrentLocationForMigration,
};
