"use strict";

const INVENTORY_SCHEMA_VERSION = 1;
const INVENTORY_OPERATION_VERSION = 1;
const MOVEMENT_SCHEMA_VERSION = 1;
const RESERVATION_SCHEMA_VERSION = 1;
const EVENT_SCHEMA_VERSION = 1;
const EVENT_VERSION = 1;
const PRODUCER_VERSION = "inventory-m1-m2-v1";

const RESERVATION_STATUS = Object.freeze({
  RESERVING: "reserving",
  RESERVED: "reserved",
  RELEASING: "releasing",
  RELEASED: "released",
  EXPIRED: "expired",
  COMMITTED: "committed",
});

const INVENTORY_COMMIT_STATUS = Object.freeze({
  NOT_STARTED: "not_started",
  COMMITTING: "committing",
  COMMITTED: "committed",
  PENDING: "pending",
  CONFLICT: "conflict",
  MANUAL_REVIEW: "manual_review",
});

const RETURN_STATUS = Object.freeze({
  REQUESTED: "requested",
  APPROVED: "approved",
  RECEIVED: "received",
  RESTOCKABLE: "restockable",
  RESTORED: "restored",
  NON_RESTOCKABLE: "non_restockable",
  NOT_RESTORED: "not_restored",
  REJECTED: "rejected",
});

const PAYMENT_STATUS = Object.freeze({
  UNSTARTED: "unstarted",
  CREATED: "created",
  PENDING: "pending",
  UNKNOWN: "unknown",
  PENDING_VERIFICATION: "pending_verification",
  VERIFIED_SUCCESS: "verified_success",
  VERIFIED_FAILURE: "verified_failure",
  CANCELLED: "cancelled",
  EXPIRED: "expired",
  MANUAL_REVIEW: "manual_review",
});

const SELLER_ORDER_STATUS = Object.freeze({
  CREATED: "created",
  PAYMENT_PENDING: "payment_pending",
  READY_FOR_FULFILLMENT: "ready_for_fulfillment",
  PAYMENT_FAILED: "payment_failed",
  CANCELLED: "cancelled",
  PARTIALLY_RESOLVED: "partially_resolved",
  MANUAL_REVIEW: "manual_review",
  COMPLETED: "completed",
});

const FINANCE_ELIGIBILITY = Object.freeze({
  INELIGIBLE: "ineligible",
  BLOCKED: "blocked",
  ELIGIBLE: "eligible",
  SETTLED: "settled",
});

const INVENTORY_COLLECTIONS = Object.freeze({
  RESERVATIONS: "inventoryReservations",
  MOVEMENTS: "inventoryMovements",
  EVENTS: "inventoryEvents",
});

const EVENT_STATUS = Object.freeze({
  PENDING: "pending",
  PROCESSING: "processing",
  COMPLETED: "completed",
  FAILED: "failed",
  DEAD_LETTER: "dead_letter",
});

const EVENT_NAMES = Object.freeze({
  RESERVED: "InventoryReserved",
  RESERVATION_RELEASED: "InventoryReleased",
  RESERVATION_EXPIRED: "InventoryReservationExpired",
  COMMITTED: "InventoryCommitted",
  RESTORED: "InventoryRestored",
  RETURN_NOT_RESTORED: "InventoryReturnNotRestored",
  ADJUSTED: "InventoryAdjusted",
});

const DEFAULT_RESERVATION_LEASE_MS = 15 * 60 * 1000;

const SERVER_OWNED_INVENTORY_FIELDS = Object.freeze([
  "reservedStock",
  "inventorySchemaVersion",
  "inventoryOperationVersion",
  "inventoryUpdatedAt",
]);

module.exports = {
  DEFAULT_RESERVATION_LEASE_MS,
  EVENT_NAMES,
  EVENT_SCHEMA_VERSION,
  EVENT_STATUS,
  EVENT_VERSION,
  FINANCE_ELIGIBILITY,
  INVENTORY_COLLECTIONS,
  INVENTORY_COMMIT_STATUS,
  INVENTORY_OPERATION_VERSION,
  INVENTORY_SCHEMA_VERSION,
  MOVEMENT_SCHEMA_VERSION,
  PAYMENT_STATUS,
  PRODUCER_VERSION,
  RESERVATION_SCHEMA_VERSION,
  RESERVATION_STATUS,
  SERVER_OWNED_INVENTORY_FIELDS,
  RETURN_STATUS,
  SELLER_ORDER_STATUS,
};
