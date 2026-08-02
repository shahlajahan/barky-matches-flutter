"use strict";

const admin = require("firebase-admin");
const {
  DEFAULT_RESERVATION_LEASE_MS,
  EVENT_SCHEMA_VERSION,
  EVENT_NAMES,
  EVENT_VERSION,
  INVENTORY_COMMIT_STATUS,
  INVENTORY_OPERATION_VERSION,
  INVENTORY_SCHEMA_VERSION,
  MOVEMENT_SCHEMA_VERSION,
  PAYMENT_STATUS,
  PRODUCER_VERSION,
  RESERVATION_SCHEMA_VERSION,
  RESERVATION_STATUS,
  RETURN_STATUS,
} = require("./inventoryConstants");
const { error, InventoryError } = require("./inventoryErrors");
const {
  buildMovementId,
  buildOperationId,
  buildReservationId,
  buildEventId,
  assertDeterministicOperationId,
  canonicalLineIdentity,
} = require("./inventoryIdentity");
const { buildEventDocument } = require("./inventoryEvents");
const {
  eventRef,
  movementRef,
  orderRef,
  productRef,
  reservationRef,
  returnRef,
  resolveDb,
  sellerOrderRef,
} = require("./inventoryRepository");

const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

function asTimestamp(value, field) {
  if (value instanceof Timestamp) return value;
  if (value && typeof value.toMillis === "function") return value;
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return Timestamp.fromDate(value);
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return Timestamp.fromMillis(value);
  }
  throw error("invalid_timestamp", `${field} must be a timestamp`, { field });
}

function nowTimestamp(value) {
  return value == null ? Timestamp.now() : asTimestamp(value, "now");
}

function writeTimestamp(value) {
  return value == null ? FieldValue.serverTimestamp() : asTimestamp(value, "now");
}

function timestampMillis(value, field = "timestamp") {
  return asTimestamp(value, field).toMillis();
}

function leaseExpiry(value, now) {
  if (value != null) return asTimestamp(value, "leaseExpiresAt");
  return Timestamp.fromMillis(
    timestampMillis(now, "now") + DEFAULT_RESERVATION_LEASE_MS
  );
}

function requirePositiveInteger(value, field) {
  if (!Number.isInteger(value) || value <= 0) {
    throw error("invalid_quantity", `${field} must be a positive integer`, {
      field,
      value,
    });
  }
  return value;
}

function requireNumber(value, field, options = {}) {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw error("invalid_number", `${field} must be numeric`, { field, value });
  }
  if (options.nonNegative && value < 0) {
    throw error("negative_value", `${field} must be non-negative`, {
      field,
      value,
    });
  }
  return value;
}

function supportedVersion(value, current, field, defaultValue = current) {
  const version = value == null ? defaultValue : value;
  if (version !== current) {
    throw error(
      "unsupported_version",
      `${field} ${version} is not supported`,
      { field, version, supportedVersion: current },
      { manualReview: true }
    );
  }
  return version;
}

function durableVersion(value, current, field) {
  if (value == null) {
    throw error(
      "missing_version",
      `${field} is required on durable inventory evidence`,
      { field },
      { manualReview: true }
    );
  }
  return supportedVersion(value, current, field, undefined);
}

function productQuantities(data) {
  const stock = requireNumber(data.stock, "stock", { nonNegative: true });
  const reservedStock =
    data.reservedStock == null
      ? 0
      : requireNumber(data.reservedStock, "reservedStock", { nonNegative: true });
  if (stock < reservedStock) {
    throw error(
      "inventory_invariant_violation",
      "stock cannot be less than reservedStock",
      { stock, reservedStock },
      { manualReview: true }
    );
  }
  return { stock, reservedStock };
}

function validateProduct(data) {
  supportedVersion(
    data.inventorySchemaVersion,
    INVENTORY_SCHEMA_VERSION,
    "inventorySchemaVersion"
  );
  return productQuantities(data);
}

function validateIdentityOnReservation(data, identity) {
  for (const field of [
    "rootOrderId",
    "sellerOrderId",
    "lineId",
    "businessId",
    "productId",
  ]) {
    const stored = data[field] || (field === "rootOrderId" ? data.orderId : null);
    if (!stored || stored !== identity[field]) {
      throw error(
        "line_identity_conflict",
        `Reservation ${field} does not match the operation identity`,
        { field, stored, expected: identity[field] },
        { manualReview: true }
      );
    }
  }
}

function validateReservationVersion(data) {
  durableVersion(
    data.reservationSchemaVersion,
    RESERVATION_SCHEMA_VERSION,
    "reservationSchemaVersion"
  );
  durableVersion(data.operationVersion, INVENTORY_OPERATION_VERSION, "operationVersion");
}

function validateMovementEvidence(data, {
  identity,
  operationId,
  operationType,
  quantity,
  returnId = null,
}) {
  durableVersion(data.movementSchemaVersion, MOVEMENT_SCHEMA_VERSION, "movementSchemaVersion");
  if (
    data.operationId !== operationId ||
    data.operationType !== operationType ||
    data.orderId !== identity.rootOrderId ||
    data.sellerOrderId !== identity.sellerOrderId ||
    data.lineId !== identity.lineId ||
    data.businessId !== identity.businessId ||
    data.productId !== identity.productId ||
    data.quantity !== quantity ||
    (data.returnId || null) !== (returnId || null)
  ) {
    throw error(
      "operation_evidence_conflict",
      "Movement evidence does not match the canonical operation",
      { operationId, operationType, identity, returnId },
      { manualReview: true }
    );
  }
}

function validateEventEvidence(data, {
  eventId,
  eventName,
  operationId,
  identity,
  quantity,
  returnId = null,
}) {
  durableVersion(data.eventVersion, EVENT_VERSION, "eventVersion");
  durableVersion(data.schemaVersion, EVENT_SCHEMA_VERSION, "schemaVersion");
  durableVersion(data.producerVersion, PRODUCER_VERSION, "producerVersion");
  durableVersion(data.operationVersion, INVENTORY_OPERATION_VERSION, "operationVersion");
  const aggregate = data.aggregate || {};
  const payload = data.payload || {};
  if (
    data.eventId !== eventId ||
    data.eventName !== eventName ||
    data.operationId !== operationId ||
    aggregate.rootOrderId !== identity.rootOrderId ||
    aggregate.sellerOrderId !== identity.sellerOrderId ||
    aggregate.lineId !== identity.lineId ||
    aggregate.businessId !== identity.businessId ||
    aggregate.productId !== identity.productId ||
    payload.quantity !== quantity ||
    (payload.returnId || null) !== (returnId || null)
  ) {
    throw error(
      "operation_evidence_conflict",
      "Event evidence does not match the canonical operation",
      { eventId, eventName, operationId, identity, returnId },
      { manualReview: true }
    );
  }
}

function requireMatchingEvidence({
  movementSnap,
  eventSnap,
  eventId,
  eventName,
  operationId,
  operationType,
  identity,
  quantity,
  returnId = null,
}) {
  if (movementSnap.exists !== eventSnap.exists) {
    throw error(
      "operation_evidence_conflict",
      "Inventory operation has partial movement/event evidence",
      { operationId, movementExists: movementSnap.exists, eventExists: eventSnap.exists },
      { manualReview: true }
    );
  }
  if (!movementSnap.exists) return false;
  validateMovementEvidence(movementSnap.data() || {}, {
    identity,
    operationId,
    operationType,
    quantity,
    returnId,
  });
  validateEventEvidence(eventSnap.data() || {}, {
    eventId,
    eventName,
    operationId,
    identity,
    quantity,
    returnId,
  });
  return true;
}

function canonicalSellerLine(sellerOrderData, identity) {
  const candidateArrays = [
    sellerOrderData.inventoryLines,
    sellerOrderData.lines,
    sellerOrderData.items,
  ].filter(Array.isArray);
  const line = candidateArrays
    .flat()
    .find((candidate) =>
      candidate &&
      String(candidate.lineId || candidate.sellerOrderLineId || "") === identity.lineId
    );
  if (!line) {
    throw error(
      "seller_order_line_not_found",
      "Canonical seller-order line does not exist",
      { identity },
      { manualReview: true }
    );
  }
  if (
    String(line.productId || "") !== identity.productId ||
    String(line.businessId || line.shopId || "") !== identity.businessId
  ) {
    throw error(
      "line_identity_conflict",
      "Seller-order line does not match the canonical identity",
      { identity, line },
      { manualReview: true }
    );
  }
  return line;
}

function validateCanonicalOrder(orderSnap, sellerOrderSnap, identity, quantity = null) {
  if (!orderSnap.exists) {
    throw error("order_not_found", "Canonical root order does not exist", {
      orderId: identity.rootOrderId,
    }, { manualReview: true });
  }
  if (!sellerOrderSnap.exists) {
    throw error("seller_order_not_found", "Canonical seller order does not exist", {
      sellerOrderId: identity.sellerOrderId,
    }, { manualReview: true });
  }
  const rootOrderData = orderSnap.data() || {};
  const sellerOrderData = sellerOrderSnap.data() || {};
  if (sellerOrderData.rootOrderId !== identity.rootOrderId) {
    throw error("line_identity_conflict", "Seller order root order mismatch", {
      identity,
      rootOrderId: sellerOrderData.rootOrderId,
    }, { manualReview: true });
  }
  const line = canonicalSellerLine(sellerOrderData, identity);
  if (quantity != null && requirePositiveInteger(line.quantity, "line.quantity") !== quantity) {
    throw error("line_quantity_conflict", "Canonical line quantity does not match operation", {
      identity,
      expected: quantity,
      actual: line.quantity,
    }, { manualReview: true });
  }
  if (
    !Array.isArray(rootOrderData.sellerOrderIds) ||
    !rootOrderData.sellerOrderIds.map(String).includes(identity.sellerOrderId)
  ) {
    throw error("line_identity_conflict", "Seller order is not attached to root order", {
      identity,
    }, { manualReview: true });
  }
  return line;
}

function validateCanonicalReturn(returnData, identity, returnId, quantity) {
  if (
    String(returnData.returnId || "") !== returnId ||
    String(returnData.rootOrderId || returnData.orderId || "") !== identity.rootOrderId ||
    String(returnData.sellerOrderId || "") !== identity.sellerOrderId ||
    String(returnData.businessId || "") !== identity.businessId
  ) {
    throw error("return_identity_conflict", "Return does not match canonical line", {
      identity,
      returnId,
    }, { manualReview: true });
  }
  const line = (Array.isArray(returnData.returnItems) ? returnData.returnItems : [])
    .find((candidate) =>
      candidate &&
      String(candidate.lineId || candidate.sellerOrderLineId || "") === identity.lineId
    );
  if (!line || String(line.productId || "") !== identity.productId) {
    throw error("return_line_not_found", "Return line does not match canonical line", {
      identity,
      returnId,
    }, { manualReview: true });
  }
  if (line.physicallyReceived !== true || typeof line.restockable !== "boolean") {
    throw error("return_not_received", "Return line is not physically received and classified", {
      returnId,
      lineId: identity.lineId,
    });
  }
  const approvedQuantity = requirePositiveInteger(line.quantity, "return.quantity");
  if (approvedQuantity !== quantity) {
    throw error("return_quantity_conflict", "Return quantity does not match authoritative return line", {
      expected: approvedQuantity,
      actual: quantity,
    }, { manualReview: true });
  }
  return line;
}

function movementDocument({
  identity,
  operationId,
  operationType,
  quantity,
  beforeStock,
  afterStock,
  beforeReservedStock,
  afterReservedStock,
  provider = null,
  reason = null,
  actor = "system",
  returnId = null,
  sourceEvidence = null,
  timestamp,
}) {
  return {
    movementSchemaVersion: MOVEMENT_SCHEMA_VERSION,
    operationId,
    operationType,
    orderId: identity.rootOrderId,
    sellerOrderId: identity.sellerOrderId,
    lineId: identity.lineId,
    businessId: identity.businessId,
    productId: identity.productId,
    returnId,
    quantity,
    beforeStock,
    afterStock,
    beforeReservedStock,
    afterReservedStock,
    provider,
    reason,
    actor,
    sourceEvidence,
    createdAt: timestamp,
  };
}

function operationResult(status, identity, operationId, extra = {}) {
  return {
    status,
    operationId,
    reservationId: buildReservationId(identity),
    ...identity,
    ...extra,
  };
}

function isLeaseExpired(leaseExpiresAt, now = Timestamp.now()) {
  return timestampMillis(leaseExpiresAt, "leaseExpiresAt") <=
    timestampMillis(now, "now");
}

function validateTransientLease({
  status,
  startedAt,
  leaseExpiresAt,
  now = Timestamp.now(),
  operationId,
  currentOperationId,
  attempt = 1,
}) {
  if (!["reserving", "releasing", "committing"].includes(status)) {
    throw error("invalid_transient_state", `${status} is not transient`, {
      status,
    });
  }
  if (operationId && currentOperationId && operationId !== currentOperationId) {
    throw error(
      "operation_identity_conflict",
      "A different operation owns the transient state",
      { operationId, currentOperationId },
      { manualReview: true }
    );
  }
  if (startedAt == null || leaseExpiresAt == null) {
    throw error(
      "invalid_transient_state",
      "Transient inventory state requires startedAt and leaseExpiresAt",
      { status },
      { manualReview: true }
    );
  }
  asTimestamp(startedAt, "startedAt");
  const currentAttempt = requirePositiveInteger(attempt, "attempt");
  if (!isLeaseExpired(leaseExpiresAt, now)) {
    throw error("lease_active", "The transient operation lease is still active", {
      status,
      leaseExpiresAt,
    });
  }
  return {
    reclaimable: true,
    status,
    operationId: operationId || currentOperationId,
    nextAttempt: currentAttempt + 1,
  };
}

function readPaymentIdentity(orderData = {}) {
  const payment = orderData.payment || {};
  return {
    state: String(
      orderData.paymentState ||
        orderData.providerPaymentState ||
        payment.state ||
        orderData.paymentStatus ||
        payment.status ||
        ""
    ).toLowerCase(),
    provider: String(
      orderData.paymentProvider || payment.provider || payment.paymentProvider || ""
    ).toLowerCase(),
    paymentId: String(
      orderData.paymentId ||
        payment.paymentId ||
        payment.paymentTransactionId ||
        ""
    ).trim(),
  };
}

function paymentInput(payment = {}) {
  return {
    state: String(payment.state || payment.paymentState || "").toLowerCase(),
    provider: String(payment.provider || "").trim().toLowerCase(),
    paymentId: String(payment.paymentId || "").trim(),
  };
}

function assertVerifiedPayment(orderSnap, sellerOrderSnap, payment) {
  const expected = paymentInput(payment);
  if (
    expected.state !== PAYMENT_STATUS.VERIFIED_SUCCESS ||
    !expected.provider ||
    !expected.paymentId
  ) {
    throw error(
      "payment_not_verified",
      "Inventory commit requires verified_success and a payment identity",
      { paymentState: expected.state },
      { manualReview: true }
    );
  }

  const orderPayment = readPaymentIdentity(orderSnap.data() || {});
  if (
    orderPayment.state !== PAYMENT_STATUS.VERIFIED_SUCCESS ||
    orderPayment.provider !== expected.provider ||
    orderPayment.paymentId !== expected.paymentId
  ) {
    throw error(
      "payment_identity_mismatch",
      "Verified payment identity does not match the canonical order",
      { expected, orderPayment },
      { manualReview: true }
    );
  }

  if (!sellerOrderSnap.exists) {
    throw error("seller_order_not_found", "Canonical seller order does not exist", {}, {
      manualReview: true,
    });
  }
  const sellerPayment = readPaymentIdentity(sellerOrderSnap.data() || {});
  if (
    sellerPayment.provider !== expected.provider ||
    sellerPayment.paymentId !== expected.paymentId
  ) {
    throw error(
      "payment_identity_mismatch",
      "Verified payment identity does not match the seller order",
      { expected, sellerPayment },
      { manualReview: true }
    );
  }
  return expected;
}

function writeMutationEvidence({
  transaction,
  db,
  identity,
  operationId,
  operationType,
  eventName,
  movement,
  eventPayload,
  timestamp,
}) {
  const movementId = buildMovementId(identity, operationId);
  const eventDocument = buildEventDocument({
    eventName,
    operationId,
    identity,
    payload: eventPayload,
    timestamp,
  });
  transaction.create(movementRef(db, movementId), movement);
  transaction.create(eventRef(db, eventDocument.eventId), eventDocument);
  return { movementId, eventId: eventDocument.eventId, operationType };
}

async function reserveInventory({
  db,
  identity: identityInput,
  quantity,
  operationId,
  leaseExpiresAt,
  attempt = 1,
  now,
}) {
  const firestore = resolveDb(db);
  const identity = canonicalLineIdentity(identityInput);
  requirePositiveInteger(quantity, "quantity");
  requirePositiveInteger(attempt, "attempt");
  const effectiveNow = nowTimestamp(now);
  const effectiveLease = leaseExpiry(leaseExpiresAt, effectiveNow);
  const operation = assertDeterministicOperationId(identity, "reserve", operationId);

  if (timestampMillis(effectiveLease, "leaseExpiresAt") <= timestampMillis(effectiveNow, "now")) {
    throw error("invalid_lease", "Reservation lease must be in the future", {
      leaseExpiresAt: effectiveLease,
    });
  }

  return firestore.runTransaction(async (transaction) => {
    const product = productRef(firestore, identity);
    const reservation = reservationRef(firestore, identity);
    const movement = movementRef(firestore, buildMovementId(identity, operation));
    const eventId = buildEventId(operation, EVENT_NAMES.RESERVED);
    const event = eventRef(firestore, eventId);
    const order = orderRef(firestore, identity);
    const sellerOrder = sellerOrderRef(firestore, identity);
    const [productSnap, reservationSnap, movementSnap, eventSnap, orderSnap, sellerOrderSnap] =
      await transaction.getAll(product, reservation, movement, event, order, sellerOrder);

    if (!productSnap.exists) {
      throw error("product_not_found", "Product does not exist", { identity });
    }
    validateCanonicalOrder(orderSnap, sellerOrderSnap, identity, quantity);

    const evidenceExists = requireMatchingEvidence({
      movementSnap,
      eventSnap,
      eventId,
      eventName: EVENT_NAMES.RESERVED,
      operationId: operation,
      operationType: "reserve",
      identity,
      quantity,
    });
    if (evidenceExists) {
      return operationResult("already_reserved", identity, operation, {
        movementId: buildMovementId(identity, operation),
        eventId,
      });
    }
    const productData = productSnap.data() || {};
    const { stock, reservedStock } = validateProduct(productData);
    if (reservationSnap.exists) {
      const existing = reservationSnap.data() || {};
      validateReservationVersion(existing);
      validateIdentityOnReservation(existing, identity);
      if (
        existing.status === RESERVATION_STATUS.RESERVED &&
        existing.lastOperationId === operation
      ) {
        throw error(
          "operation_evidence_conflict",
          "Reserved state exists without matching movement/event evidence",
          { operationId: operation },
          { manualReview: true }
        );
      }
      if (
        existing.status === RESERVATION_STATUS.RESERVING &&
        existing.lastOperationId === operation
      ) {
        validateTransientLease({
          status: existing.status,
          startedAt: existing.startedAt,
          leaseExpiresAt: existing.leaseExpiresAt,
          now: effectiveNow,
          operationId: operation,
          currentOperationId: existing.lastOperationId,
        });
      } else {
        throw error(
          "reservation_conflict",
          "A reservation already exists for this canonical line",
          { status: existing.status, operationId: existing.lastOperationId },
          { manualReview: true }
        );
      }
    }

    if (stock - reservedStock < quantity) {
      throw error(
        "insufficient_stock",
        "Requested quantity is not available",
        { stock, reservedStock, quantity }
      );
    }
    const afterReservedStock = reservedStock + quantity;
    if (stock < afterReservedStock) {
      throw error(
        "inventory_invariant_violation",
        "Reservation would exceed physical stock",
        { stock, reservedStock, afterReservedStock },
        { manualReview: true }
      );
    }

    const recoveredAttempt = reservationSnap.exists
      ? Number(reservationSnap.data()?.attempt || 0) + 1
      : attempt;
    const effectiveAttempt = reservationSnap.exists
      ? Math.max(attempt, recoveredAttempt)
      : attempt;
    const timestamp = writeTimestamp(now);
    transaction.set(
      product,
      {
        reservedStock: afterReservedStock,
        inventorySchemaVersion: INVENTORY_SCHEMA_VERSION,
        inventoryUpdatedAt: timestamp,
        inventoryOperationVersion: INVENTORY_OPERATION_VERSION,
      },
      { merge: true }
    );
    transaction.set(
      reservation,
      {
        rootOrderId: identity.rootOrderId,
        orderId: identity.rootOrderId,
        sellerOrderId: identity.sellerOrderId,
        lineId: identity.lineId,
        businessId: identity.businessId,
        productId: identity.productId,
        quantity,
        committedQuantity: 0,
        restoredQuantity: 0,
        status: RESERVATION_STATUS.RESERVED,
        inventoryCommitState: INVENTORY_COMMIT_STATUS.NOT_STARTED,
        reservationSchemaVersion: RESERVATION_SCHEMA_VERSION,
        operationVersion: INVENTORY_OPERATION_VERSION,
        lastOperationId: operation,
        startedAt: timestamp,
        leaseExpiresAt: effectiveLease,
        expiresAt: effectiveLease,
        attempt: effectiveAttempt,
        createdAt: timestamp,
        updatedAt: timestamp,
      },
      { merge: true }
    );
    const movementId = buildMovementId(identity, operation);
    writeMutationEvidence({
      transaction,
      db: firestore,
      identity,
      operationId: operation,
      operationType: "reserve",
      eventName: EVENT_NAMES.RESERVED,
      movement: movementDocument({
        identity,
        operationId: operation,
        operationType: "reserve",
        quantity,
        beforeStock: stock,
        afterStock: stock,
        beforeReservedStock: reservedStock,
        afterReservedStock,
        timestamp,
      }),
      eventPayload: {
        quantity,
        stock,
        reservedStock: afterReservedStock,
      },
      timestamp,
    });
    return operationResult("reserved", identity, operation, {
      movementId,
      eventId,
      stock,
      reservedStock: afterReservedStock,
    });
  });
}

async function commitInventory({
  db,
  identity: identityInput,
  payment,
  operationId,
  now,
}) {
  const firestore = resolveDb(db);
  const identity = canonicalLineIdentity(identityInput);
  const operation = assertDeterministicOperationId(identity, "commit", operationId);
  const effectiveNow = nowTimestamp(now);

  return firestore.runTransaction(async (transaction) => {
    const product = productRef(firestore, identity);
    const reservation = reservationRef(firestore, identity);
    const movement = movementRef(firestore, buildMovementId(identity, operation));
    const eventId = buildEventId(operation, EVENT_NAMES.COMMITTED);
    const event = eventRef(firestore, eventId);
    const order = orderRef(firestore, identity);
    const sellerOrder = sellerOrderRef(firestore, identity);
    const [productSnap, reservationSnap, movementSnap, eventSnap, orderSnap, sellerOrderSnap] =
      await transaction.getAll(product, reservation, movement, event, order, sellerOrder);

    if (!orderSnap.exists || !sellerOrderSnap.exists || !reservationSnap.exists) {
      throw error("canonical_document_missing", "Canonical commit documents are incomplete", {
        identity,
      }, { manualReview: true });
    }
    const reservationData = reservationSnap.data() || {};
    validateReservationVersion(reservationData);
    validateIdentityOnReservation(reservationData, identity);
    const quantity = requirePositiveInteger(reservationData.quantity, "quantity");
    validateCanonicalOrder(orderSnap, sellerOrderSnap, identity, quantity);
    const verifiedPayment = assertVerifiedPayment(orderSnap, sellerOrderSnap, payment);
    const evidenceExists = requireMatchingEvidence({
      movementSnap,
      eventSnap,
      eventId,
      eventName: EVENT_NAMES.COMMITTED,
      operationId: operation,
      operationType: "commit",
      identity,
      quantity,
    });
    if (evidenceExists) {
      return operationResult("already_committed", identity, operation, {
        movementId: buildMovementId(identity, operation),
        eventId,
      });
    }
    if (!productSnap.exists) {
      throw error(
        "reservation_not_found",
        "Product or reservation does not exist",
        { identity },
        { manualReview: true }
      );
    }
    const productData = productSnap.data() || {};
    const { stock, reservedStock } = validateProduct(productData);
    let effectiveAttempt = Number(reservationData.attempt || 0);
    if (reservationData.status === RESERVATION_STATUS.COMMITTED) {
      throw error(
        "commit_evidence_missing",
        "Reservation is committed but commit movement is missing",
        { identity },
        { manualReview: true }
      );
    }
    if (reservationData.inventoryCommitState === INVENTORY_COMMIT_STATUS.COMMITTING) {
      if (reservationData.lastOperationId !== operation) {
        throw error("operation_identity_conflict", "A different commit owns the lease", {
          operationId: operation,
          currentOperationId: reservationData.lastOperationId,
        }, { manualReview: true });
      }
      validateTransientLease({
        status: "committing",
        startedAt: reservationData.startedAt,
        leaseExpiresAt: reservationData.leaseExpiresAt,
        now: effectiveNow,
        operationId: operation,
        currentOperationId: reservationData.lastOperationId,
        attempt: reservationData.attempt,
      });
      effectiveAttempt += 1;
    } else if (![RESERVATION_STATUS.RESERVED, RESERVATION_STATUS.COMMITTING].includes(reservationData.status)) {
      throw error(
        "reservation_not_committable",
        "Reservation is not reserved",
        { status: reservationData.status },
        { manualReview: true }
      );
    }
    if (reservedStock < quantity || stock < quantity) {
      throw error(
        "commit_inventory_conflict",
        "Committed quantity is not available in the product evidence",
        { stock, reservedStock, quantity },
        { manualReview: true }
      );
    }
    const afterStock = stock - quantity;
    const afterReservedStock = reservedStock - quantity;
    if (afterStock < 0 || afterReservedStock < 0 || afterStock < afterReservedStock) {
      throw error(
        "inventory_invariant_violation",
        "Commit would violate stock invariants",
        { stock, reservedStock, quantity, afterStock, afterReservedStock },
        { manualReview: true }
      );
    }

    const timestamp = writeTimestamp(now);
    transaction.set(
      product,
      {
        stock: afterStock,
        reservedStock: afterReservedStock,
        inventorySchemaVersion: INVENTORY_SCHEMA_VERSION,
        inventoryUpdatedAt: timestamp,
        inventoryOperationVersion: INVENTORY_OPERATION_VERSION,
      },
      { merge: true }
    );
    transaction.set(
      reservation,
      {
        status: RESERVATION_STATUS.COMMITTED,
        inventoryCommitState: INVENTORY_COMMIT_STATUS.COMMITTED,
        committedQuantity: quantity,
        provider: verifiedPayment.provider,
        providerPaymentId: verifiedPayment.paymentId,
        providerPaymentState: PAYMENT_STATUS.VERIFIED_SUCCESS,
        committedAt: timestamp,
        updatedAt: timestamp,
        lastOperationId: operation,
        attempt: effectiveAttempt,
      },
      { merge: true }
    );
    const movementId = buildMovementId(identity, operation);
    writeMutationEvidence({
      transaction,
      db: firestore,
      identity,
      operationId: operation,
      operationType: "commit",
      eventName: EVENT_NAMES.COMMITTED,
      movement: movementDocument({
        identity,
        operationId: operation,
        operationType: "commit",
        quantity,
        beforeStock: stock,
        afterStock,
        beforeReservedStock: reservedStock,
        afterReservedStock,
        provider: verifiedPayment.provider,
        timestamp,
      }),
      eventPayload: {
        quantity,
        provider: verifiedPayment.provider,
        paymentId: verifiedPayment.paymentId,
      },
      timestamp,
    });
    return operationResult("committed", identity, operation, {
      movementId,
      eventId,
      stock: afterStock,
      reservedStock: afterReservedStock,
    });
  });
}

async function releaseInventory({
  db,
  identity: identityInput,
  operationId,
  reason = "released",
  expiry = false,
  now,
}) {
  const firestore = resolveDb(db);
  const identity = canonicalLineIdentity(identityInput);
  const operation = assertDeterministicOperationId(
    identity,
    expiry ? "expire" : "release",
    operationId
  );
  const effectiveNow = nowTimestamp(now);
  const eventName = expiry ? EVENT_NAMES.RESERVATION_EXPIRED : EVENT_NAMES.RESERVATION_RELEASED;
  const operationType = expiry ? "expiry_release" : "release";

  return firestore.runTransaction(async (transaction) => {
    const product = productRef(firestore, identity);
    const reservation = reservationRef(firestore, identity);
    const movement = movementRef(firestore, buildMovementId(identity, operation));
    const eventId = buildEventId(operation, eventName);
    const event = eventRef(firestore, eventId);
    const [productSnap, reservationSnap, movementSnap, eventSnap] =
      await transaction.getAll(product, reservation, movement, event);

    if (!productSnap.exists || !reservationSnap.exists) {
      throw error("reservation_not_found", "Product or reservation does not exist", {
        identity,
      }, { manualReview: true });
    }
    const reservationData = reservationSnap.data() || {};
    validateReservationVersion(reservationData);
    validateIdentityOnReservation(reservationData, identity);
    const quantity = requirePositiveInteger(reservationData.quantity, "quantity");
    const evidenceExists = requireMatchingEvidence({
      movementSnap,
      eventSnap,
      eventId,
      eventName,
      operationId: operation,
      operationType,
      identity,
      quantity,
    });
    if (evidenceExists) {
      return operationResult(expiry ? "already_expired" : "already_released", identity, operation, {
        movementId: buildMovementId(identity, operation),
        eventId,
      });
    }
    if ([
      RESERVATION_STATUS.RELEASED,
      RESERVATION_STATUS.EXPIRED,
      RESERVATION_STATUS.COMMITTED,
    ].includes(reservationData.status)) {
      throw error(
        "operation_evidence_conflict",
        "Terminal reservation is missing matching release evidence",
        { status: reservationData.status, operationId: operation },
        { manualReview: true }
      );
    }
    let effectiveAttempt = Number(reservationData.attempt || 0);
    if (reservationData.status === RESERVATION_STATUS.RELEASING) {
      if (reservationData.lastOperationId !== operation) {
        throw error("operation_identity_conflict", "A different release owns the lease", {
          operationId: operation,
          currentOperationId: reservationData.lastOperationId,
        }, { manualReview: true });
      }
      validateTransientLease({
        status: reservationData.status,
        startedAt: reservationData.startedAt,
        leaseExpiresAt: reservationData.leaseExpiresAt,
        now: effectiveNow,
        operationId: operation,
        currentOperationId: reservationData.lastOperationId,
        attempt: reservationData.attempt,
      });
      effectiveAttempt += 1;
    } else if (reservationData.status !== RESERVATION_STATUS.RESERVED) {
      throw error(
        "reservation_not_releasable",
        "Only reserved inventory can be released",
        { status: reservationData.status },
        { manualReview: true }
      );
    }
    if (expiry && !reservationData.expiresAt) {
      throw error("missing_expiry", "Reservation has no expiry timestamp", {}, {
        manualReview: true,
      });
    }
    if (expiry && !isLeaseExpired(reservationData.expiresAt, effectiveNow)) {
      throw error("reservation_not_expired", "Reservation has not expired", {
        expiresAt: reservationData.expiresAt,
      });
    }

    const productData = productSnap.data() || {};
    const { stock, reservedStock } = validateProduct(productData);
    if (reservedStock < quantity) {
      throw error(
        "inventory_evidence_conflict",
        "reservedStock is less than the reservation quantity",
        { reservedStock, quantity },
        { manualReview: true }
      );
    }
    const afterReservedStock = reservedStock - quantity;
    const timestamp = writeTimestamp(now);
    transaction.set(
      product,
      {
        reservedStock: afterReservedStock,
        inventorySchemaVersion: INVENTORY_SCHEMA_VERSION,
        inventoryUpdatedAt: timestamp,
        inventoryOperationVersion: INVENTORY_OPERATION_VERSION,
      },
      { merge: true }
    );
    transaction.set(
      reservation,
      {
        status: expiry ? RESERVATION_STATUS.EXPIRED : RESERVATION_STATUS.RELEASED,
        releasedReason: reason,
        releasedAt: timestamp,
        updatedAt: timestamp,
        lastOperationId: operation,
        attempt: effectiveAttempt,
      },
      { merge: true }
    );
    const movementId = buildMovementId(identity, operation);
    writeMutationEvidence({
      transaction,
      db: firestore,
      identity,
      operationId: operation,
      operationType,
      eventName,
      movement: movementDocument({
        identity,
        operationId: operation,
        operationType,
        quantity,
        beforeStock: stock,
        afterStock: stock,
        beforeReservedStock: reservedStock,
        afterReservedStock,
        reason,
        timestamp,
      }),
      eventPayload: { quantity, reason },
      timestamp,
    });
    return operationResult(expiry ? "expired" : "released", identity, operation, {
      movementId,
      eventId,
      stock,
      reservedStock: afterReservedStock,
    });
  });
}

async function expireAndReleaseInventory(options) {
  return releaseInventory({ ...options, expiry: true });
}

async function restoreReturnedInventory({
  db,
  identity: identityInput,
  returnId,
  quantity,
  operationId,
  actor = "system",
  now,
}) {
  const firestore = resolveDb(db);
  const identity = canonicalLineIdentity(identityInput);
  const normalizedReturnId = String(returnId || "").trim();
  if (!normalizedReturnId) throw error("invalid_return", "returnId is required");
  requirePositiveInteger(quantity, "quantity");
  const operation = assertDeterministicOperationId(
    identity,
    "restore",
    operationId,
    normalizedReturnId
  );

  return firestore.runTransaction(async (transaction) => {
    const product = productRef(firestore, identity);
    const reservation = reservationRef(firestore, identity);
    const movement = movementRef(firestore, buildMovementId(identity, operation));
    const returnDocument = returnRef(firestore, normalizedReturnId);
    const [productSnap, reservationSnap, movementSnap, returnSnap] =
      await transaction.getAll(product, reservation, movement, returnDocument);

    if (!productSnap.exists || !reservationSnap.exists || !returnSnap.exists) {
      throw error("return_line_not_found", "Product or committed line does not exist", {
        identity,
      }, { manualReview: true });
    }
    const reservationData = reservationSnap.data() || {};
    validateReservationVersion(reservationData);
    validateIdentityOnReservation(reservationData, identity);
    const returnLine = validateCanonicalReturn(
      returnSnap.data() || {},
      identity,
      normalizedReturnId,
      quantity
    );
    const restockable = returnLine.restockable === true;
    const eventName = restockable ? EVENT_NAMES.RESTORED : EVENT_NAMES.RETURN_NOT_RESTORED;
    const operationType = restockable ? "restore" : "return_non_restockable";
    const eventId = buildEventId(operation, eventName);
    const eventSnap = await transaction.get(eventRef(firestore, eventId));
    const evidenceExists = requireMatchingEvidence({
      movementSnap,
      eventSnap,
      eventId,
      eventName,
      operationId: operation,
      operationType,
      identity,
      quantity,
      returnId: normalizedReturnId,
    });
    if (evidenceExists) {
      return operationResult(
        restockable ? "already_restored" : "already_not_restored",
        identity,
        operation,
        { returnId: normalizedReturnId, movementId: buildMovementId(identity, operation), eventId }
      );
    }
    if (reservationData.status !== RESERVATION_STATUS.COMMITTED) {
      throw error(
        "return_line_not_committed",
        "Only a committed line can be returned",
        { status: reservationData.status },
        { manualReview: true }
      );
    }
    const committedQuantity = requirePositiveInteger(
      reservationData.committedQuantity || reservationData.quantity,
      "committedQuantity"
    );
    const processedReturnQuantity =
      reservationData.restoredQuantity == null
        ? 0
        : requireNumber(reservationData.processedReturnQuantity ?? reservationData.restoredQuantity, "processedReturnQuantity", {
            nonNegative: true,
          });
    const restoredQuantity = reservationData.restoredQuantity == null
      ? 0
      : requireNumber(reservationData.restoredQuantity, "restoredQuantity", { nonNegative: true });
    const remaining = committedQuantity - processedReturnQuantity;
    if (quantity > remaining) {
      throw error(
        "return_quantity_exceeded",
        "Return quantity exceeds the remaining committed quantity",
        { committedQuantity, processedReturnQuantity, remaining, quantity },
        { manualReview: true }
      );
    }

    const productData = productSnap.data() || {};
    const { stock, reservedStock } = validateProduct(productData);
    const afterStock = restockable ? stock + quantity : stock;
    const afterProcessedReturnQuantity = processedReturnQuantity + quantity;
    const afterRestoredQuantity = restockable
      ? restoredQuantity + quantity
      : restoredQuantity;
    const timestamp = writeTimestamp(now);
    transaction.set(
      product,
      {
        stock: afterStock,
        inventorySchemaVersion: INVENTORY_SCHEMA_VERSION,
        inventoryUpdatedAt: timestamp,
        inventoryOperationVersion: INVENTORY_OPERATION_VERSION,
      },
      { merge: true }
    );
    transaction.set(
      reservation,
      {
        processedReturnQuantity: afterProcessedReturnQuantity,
        restoredQuantity: afterRestoredQuantity,
        returnState: restockable ? RETURN_STATUS.RESTORED : RETURN_STATUS.NOT_RESTORED,
        lastReturnId: normalizedReturnId,
        updatedAt: timestamp,
      },
      { merge: true }
    );
    const movementId = buildMovementId(identity, operation);
    writeMutationEvidence({
      transaction,
      db: firestore,
      identity,
      operationId: operation,
      operationType,
      eventName,
      movement: movementDocument({
        identity,
        operationId: operation,
        operationType,
        quantity,
        beforeStock: stock,
        afterStock,
        beforeReservedStock: reservedStock,
        afterReservedStock: reservedStock,
        reason: restockable ? "restockable_return" : "non_restockable_return",
        actor,
        returnId: normalizedReturnId,
        timestamp,
      }),
      eventPayload: {
        returnId: normalizedReturnId,
        quantity,
        restockable,
        committedQuantity,
        processedReturnQuantity: afterProcessedReturnQuantity,
        restoredQuantity: afterRestoredQuantity,
      },
      timestamp,
    });
    return operationResult(restockable ? "restored" : "not_restored", identity, operation, {
      movementId,
      eventId,
      returnId: normalizedReturnId,
      stock: afterStock,
      reservedStock,
      processedReturnQuantity: afterProcessedReturnQuantity,
      restoredQuantity: afterRestoredQuantity,
    });
  });
}

async function applyStockAdjustment({
  db,
  identity: identityInput,
  adjustmentId,
  delta,
  actor,
  reason,
  sourceEvidence,
  now,
}) {
  const firestore = resolveDb(db);
  const identity = canonicalLineIdentity(identityInput);
  const normalizedAdjustmentId = String(adjustmentId || "").trim();
  if (!normalizedAdjustmentId) {
    throw error("invalid_adjustment", "adjustmentId is required");
  }
  if (!actor || !reason || !sourceEvidence) {
    throw error("adjustment_evidence_required", "actor, reason and sourceEvidence are required");
  }
  if (typeof delta !== "number" || !Number.isFinite(delta) || delta === 0) {
    throw error("invalid_adjustment", "delta must be a non-zero number");
  }
  const operation = buildOperationId(identity, "adjustment", normalizedAdjustmentId);
  const effectiveNow = nowTimestamp(now);

  return firestore.runTransaction(async (transaction) => {
    const product = productRef(firestore, identity);
    const movement = movementRef(firestore, buildMovementId(identity, operation));
    const eventId = buildEventId(operation, EVENT_NAMES.ADJUSTED);
    const event = eventRef(firestore, eventId);
    const [productSnap, movementSnap, eventSnap] =
      await transaction.getAll(product, movement, event);
    const evidenceExists = requireMatchingEvidence({
      movementSnap,
      eventSnap,
      eventId,
      eventName: EVENT_NAMES.ADJUSTED,
      operationId: operation,
      operationType: "adjustment",
      identity,
      quantity: Math.abs(delta),
    });
    if (evidenceExists) {
      return operationResult("already_adjusted", identity, operation, {
        adjustmentId: normalizedAdjustmentId,
        movementId: buildMovementId(identity, operation),
        eventId,
      });
    }
    if (!productSnap.exists) {
      throw error("product_not_found", "Product does not exist", { identity });
    }
    const productData = productSnap.data() || {};
    const { stock, reservedStock } = validateProduct(productData);
    const afterStock = stock + delta;
    if (afterStock < reservedStock || afterStock < 0) {
      throw error(
        "inventory_invariant_violation",
        "Stock adjustment would violate stock >= reservedStock",
        { stock, reservedStock, delta, afterStock },
        { manualReview: true }
      );
    }
    const timestamp = writeTimestamp(now);
    transaction.set(
      product,
      {
        stock: afterStock,
        inventorySchemaVersion: INVENTORY_SCHEMA_VERSION,
        inventoryUpdatedAt: timestamp,
        inventoryOperationVersion: INVENTORY_OPERATION_VERSION,
      },
      { merge: true }
    );
    const movementId = buildMovementId(identity, operation);
    writeMutationEvidence({
      transaction,
      db: firestore,
      identity,
      operationId: operation,
      operationType: "adjustment",
      eventName: EVENT_NAMES.ADJUSTED,
      movement: movementDocument({
        identity,
        operationId: operation,
        operationType: "adjustment",
        quantity: Math.abs(delta),
        beforeStock: stock,
        afterStock,
        beforeReservedStock: reservedStock,
        afterReservedStock: reservedStock,
        reason,
        actor,
        sourceEvidence,
        timestamp,
      }),
      eventPayload: {
        adjustmentId: normalizedAdjustmentId,
        delta,
        quantity: Math.abs(delta),
        reason,
        sourceEvidence,
      },
      timestamp,
    });
    return operationResult("adjusted", identity, operation, {
      adjustmentId: normalizedAdjustmentId,
      stock: afterStock,
      reservedStock,
      movementId,
      eventId,
      effectiveAt: effectiveNow,
    });
  });
}

module.exports = {
  applyStockAdjustment,
  commitInventory,
  expireAndReleaseInventory,
  isLeaseExpired,
  releaseInventory,
  reserveInventory,
  restoreReturnedInventory,
  validateTransientLease,
};
