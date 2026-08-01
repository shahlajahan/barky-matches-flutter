const { petshopPayoutAdapter } = require("./adapters/petshopPayoutAdapter");
const { vetPayoutAdapter } = require("./adapters/vetPayoutAdapter");
const { groomyPayoutAdapter } = require("./adapters/groomyPayoutAdapter");
const { hotelPayoutAdapter } = require("./adapters/hotelPayoutAdapter");
const { taxiPayoutAdapter } = require("./adapters/taxiPayoutAdapter");

const PAYOUT_SECTOR_ADAPTERS = {
  petshop: petshopPayoutAdapter,
  vet: vetPayoutAdapter,
  groomy: groomyPayoutAdapter,
  hotel: hotelPayoutAdapter,
  taxi: taxiPayoutAdapter,
};

const PAYOUT_ADAPTERS_BY_COLLECTION = Object.fromEntries(
  Object.values(PAYOUT_SECTOR_ADAPTERS).map((adapter) => [
    adapter.collection,
    adapter,
  ])
);

function getPayoutSectorAdapter(sector) {
  const adapter = PAYOUT_SECTOR_ADAPTERS[sector];

  if (!adapter) {
    throw new Error(`No payout sector adapter registered for sector "${sector}".`);
  }

  return adapter;
}

function getPayoutSectorAdapterByCollection(collection) {
  const adapter = PAYOUT_ADAPTERS_BY_COLLECTION[collection];
  if (!adapter) {
    throw new Error(`No payout sector adapter registered for "${collection}".`);
  }
  return adapter;
}

module.exports = {
  PAYOUT_SECTOR_ADAPTERS,
  getPayoutSectorAdapter,
  getPayoutSectorAdapterByCollection,
};
