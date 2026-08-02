"use strict";

const {
  INVENTORY_OPERATION_VERSION,
  MOVEMENT_SCHEMA_VERSION,
} = require("./inventoryConstants");
const { error } = require("./inventoryErrors");

function requiredPart(value, field) {
  const normalized = String(value ?? "").trim();
  if (!normalized) {
    throw error("invalid_line_identity", `${field} is required`, { field });
  }
  if (normalized.includes("\0")) {
    throw error("invalid_line_identity", `${field} contains an invalid character`, {
      field,
    });
  }
  return normalized;
}

function canonicalLineIdentity(input = {}) {
  const rootOrderId = requiredPart(input.rootOrderId || input.orderId, "rootOrderId");
  const sellerOrderId = requiredPart(input.sellerOrderId, "sellerOrderId");
  const lineId = requiredPart(input.lineId || input.sellerOrderLineId, "lineId");
  const businessId = requiredPart(input.businessId, "businessId");
  const productId = requiredPart(input.productId, "productId");

  return Object.freeze({
    rootOrderId,
    orderId: rootOrderId,
    sellerOrderId,
    lineId,
    businessId,
    productId,
  });
}

function segment(value) {
  return encodeURIComponent(String(value));
}

function identityPrefix(identityInput) {
  const identity = canonicalLineIdentity(identityInput);
  return [
    identity.rootOrderId,
    identity.sellerOrderId,
    identity.lineId,
    identity.businessId,
    identity.productId,
  ].map(segment).join(":");
}

function buildReservationId(identityInput) {
  const identity = canonicalLineIdentity(identityInput);
  return [
    identity.rootOrderId,
    identity.sellerOrderId,
    identity.lineId,
    identity.businessId,
    identity.productId,
  ].map(segment).join("__");
}

function buildOperationId(identityInput, operationType, suffix = "") {
  const type = requiredPart(operationType, "operationType");
  const extra = suffix ? `:${segment(suffix)}` : "";
  return `${identityPrefix(identityInput)}:${type}:v${INVENTORY_OPERATION_VERSION}${extra}`;
}

function assertDeterministicOperationId(identityInput, operationType, operationId, suffix = "") {
  const expected = buildOperationId(identityInput, operationType, suffix);
  if (operationId != null && String(operationId) !== expected) {
    throw error(
      "operation_identity_conflict",
      "Operation ID must match the canonical line identity",
      { operationId, expected },
      { manualReview: true }
    );
  }
  return expected;
}

function buildMovementId(identityInput, operationId) {
  const id = requiredPart(operationId, "operationId");
  return `${id}__movement-v${MOVEMENT_SCHEMA_VERSION}`;
}

function buildEventId(operationId, eventName) {
  return `${requiredPart(operationId, "operationId")}__event__${segment(
    requiredPart(eventName, "eventName")
  )}`;
}

module.exports = {
  buildEventId,
  buildMovementId,
  buildOperationId,
  assertDeterministicOperationId,
  buildReservationId,
  canonicalLineIdentity,
  identityPrefix,
};
