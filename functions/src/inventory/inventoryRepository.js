"use strict";

const admin = require("firebase-admin");
const { INVENTORY_COLLECTIONS } = require("./inventoryConstants");
const { buildReservationId } = require("./inventoryIdentity");

function resolveDb(db) {
  return db || admin.firestore();
}

function productRef(db, identity) {
  const resolved = resolveDb(db);
  return resolved
    .collection("businesses")
    .doc(identity.businessId)
    .collection("products")
    .doc(identity.productId);
}

function reservationRef(db, identity) {
  return resolveDb(db)
    .collection(INVENTORY_COLLECTIONS.RESERVATIONS)
    .doc(buildReservationId(identity));
}

function movementRef(db, movementId) {
  return resolveDb(db)
    .collection(INVENTORY_COLLECTIONS.MOVEMENTS)
    .doc(movementId);
}

function eventRef(db, eventId) {
  return resolveDb(db).collection(INVENTORY_COLLECTIONS.EVENTS).doc(eventId);
}

function orderRef(db, identity) {
  return resolveDb(db).collection("orders").doc(identity.rootOrderId);
}

function sellerOrderRef(db, identity) {
  return resolveDb(db).collection("sellerOrders").doc(identity.sellerOrderId);
}

function returnRef(db, returnId) {
  return resolveDb(db).collection("order_returns").doc(String(returnId));
}

module.exports = {
  eventRef,
  movementRef,
  orderRef,
  productRef,
  reservationRef,
  returnRef,
  resolveDb,
  sellerOrderRef,
};
