const assert = require("node:assert/strict");
const { test } = require("node:test");
const {
  approvalPublicationPatch,
  hasInvalidPetTaxiContamination,
  plannedPublishedValue,
} = require("../src/businessPublication");

test("approval publishes legacy non-Pet-Taxi businesses", () => {
  for (const sectors of [
    ["veterinary"],
    ["groomer"],
    ["pet_hotel"],
    ["pet_shop"],
    ["adoption_center"],
  ]) {
    assert.deepEqual(approvalPublicationPatch({ sectors }), { published: true });
    assert.equal(plannedPublishedValue({ status: "approved", sectors }), true);
  }
});

test("approval defaults missing Pet Taxi publication to false", () => {
  assert.deepEqual(
    approvalPublicationPatch({ sectors: ["pet_taxi"] }),
    { published: false }
  );
  assert.equal(
    plannedPublishedValue({ status: "approved", sectors: ["pet_taxi"] }),
    false
  );
});

test("approval preserves explicit publication choices and rejection has no patch", () => {
  assert.deepEqual(
    approvalPublicationPatch({ sectors: ["veterinary"], published: false }),
    { published: false }
  );
  assert.deepEqual(
    approvalPublicationPatch({ sectors: ["pet_taxi"], published: true }),
    { published: true }
  );
  assert.equal(plannedPublishedValue({ status: "rejected", sectors: ["veterinary"] }), null);
});

test("approval publication logic is idempotent", () => {
  const business = { status: "approved", sectors: ["veterinary"], published: true };
  assert.deepEqual(approvalPublicationPatch(business), { published: true });
  assert.deepEqual(approvalPublicationPatch({
    ...business,
    published: approvalPublicationPatch(business).published,
  }), { published: true });
});

test("legacy non-Pet-Taxi contamination blocks publication migration", () => {
  assert.equal(hasInvalidPetTaxiContamination({
    sectors: ["veterinary"],
    sectorData: { pet_taxi: { currentLocation: { lat: 41, lng: 29 } } },
  }), true);
  assert.equal(hasInvalidPetTaxiContamination({
    sectors: ["pet_taxi"],
    sectorData: { pet_taxi: {} },
  }), false);
});
