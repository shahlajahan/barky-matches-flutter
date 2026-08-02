"use strict";

const {
  EVENT_SCHEMA_VERSION,
  EVENT_STATUS,
  EVENT_VERSION,
  INVENTORY_OPERATION_VERSION,
  PRODUCER_VERSION,
} = require("./inventoryConstants");
const { buildEventId } = require("./inventoryIdentity");

function buildEventDocument({
  eventName,
  operationId,
  identity,
  payload = {},
  status = EVENT_STATUS.PENDING,
  retryCount = 0,
  timestamp,
}) {
  const now = timestamp;
  const eventId = buildEventId(operationId, eventName);
  return {
    eventId,
    eventName,
    eventVersion: EVENT_VERSION,
    schemaVersion: EVENT_SCHEMA_VERSION,
    producerVersion: PRODUCER_VERSION,
    operationVersion: INVENTORY_OPERATION_VERSION,
    aggregate: {
      rootOrderId: identity.rootOrderId,
      sellerOrderId: identity.sellerOrderId,
      lineId: identity.lineId,
      businessId: identity.businessId,
      productId: identity.productId,
    },
    operationId,
    status,
    retryCount,
    createdAt: now,
    updatedAt: now,
    payload,
  };
}

module.exports = { buildEventDocument };
