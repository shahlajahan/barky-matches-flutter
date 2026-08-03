const assert = require("node:assert/strict");
const { test } = require("node:test");
const {
  filterSectorDataByCanonicalSectors,
  isPetTaxiBusiness,
  resolvePetTaxiCurrentLocationForMigration,
} = require("../src/businessSectorMembership");
const { buildBusinessPublicProjection } = require("../src/publicProjections");

const contaminated = {
  sectors: ["veterinary"],
  sectorData: {
    veterinary: { services: [{ title: "Vaccination" }] },
    pet_taxi: { currentLocation: { lat: 41, lng: 29 } },
  },
};

test("only canonical Pet Taxi sectors establish membership", () => {
  for (const sectors of [["veterinary"], ["pet_shop"], ["adoption_center"]]) {
    assert.equal(isPetTaxiBusiness({ sectors, sectorData: contaminated.sectorData }), false);
  }
  assert.equal(isPetTaxiBusiness({ sectors: ["pet_taxi"], sectorData: {} }), true);
  assert.equal(isPetTaxiBusiness({ sectors: ["taxi"], sectorData: {} }), true);
});

test("repair decision is non-mutating for contaminated non-Pet-Taxi data", () => {
  const before = structuredClone(contaminated);
  const result = resolvePetTaxiCurrentLocationForMigration(contaminated);

  assert.deepEqual(result, {
    shouldBackfill: false,
    location: null,
    reason: "not_pet_taxi",
  });
  assert.deepEqual(contaminated, before);
});

test("registration filtering removes unrelated sectorData without converting sectors", () => {
  const filtered = filterSectorDataByCanonicalSectors(
    {
      veterinary: { profileContent: { bio: "clinic" } },
      pet_taxi: { currentLocation: { lat: 41, lng: 29 } },
    },
    ["veterinary"]
  );

  assert.deepEqual(Object.keys(filtered), ["veterinary"]);
  assert.equal(filtered.veterinary.profileContent.bio, "clinic");
  assert.equal(filtered.pet_taxi, undefined);
});

test("booking membership rejects contaminated non-Pet-Taxi data", () => {
  assert.equal(isPetTaxiBusiness(contaminated), false);
  assert.equal(isPetTaxiBusiness({
    sectors: ["pet_taxi"],
    sectorData: { pet_taxi: { isAvailable: true } },
  }), true);
});

test("public projection excludes sectorData not represented by canonical sectors", () => {
  const projection = buildBusinessPublicProjection("vet-1", {
    status: "approved",
    published: true,
    sectors: ["veterinary"],
    sectorData: contaminated.sectorData,
  });

  assert.ok(projection.publicSectorData.veterinary);
  assert.equal(projection.publicSectorData.pet_taxi, undefined);
});
