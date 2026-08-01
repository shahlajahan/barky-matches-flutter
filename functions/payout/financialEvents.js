"use strict";

const admin = require("firebase-admin");

const FINANCIAL_EVENTS_COLLECTION = "financialEvents";

function financialEventData({
  eventType,
  sourceCollection,
  sourceDocument,
  sector,
  businessId,
  actor,
  previousState,
  newState,
  amount,
  currency,
  reason,
  metadata,
  timestamp,
}) {
  const eventTimestamp =
    timestamp || admin.firestore.FieldValue.serverTimestamp();

  return {
    eventType,
    sourceCollection,
    sourceDocument,
    sector,
    business: businessId || null,
    actor: actor || { type: "system", id: null },
    previousState: previousState || null,
    newState,
    amount: typeof amount === "number" ? amount : null,
    currency: currency || null,
    occurredAt: eventTimestamp,
    createdAt: eventTimestamp,
    reason: reason || null,
    metadata: metadata || {},
  };
}

function newFinancialEventRef(db) {
  // Allocate once, before entering runTransaction. Firestore may retry the
  // callback, but every retry then targets the same event document.
  return db.collection(FINANCIAL_EVENTS_COLLECTION).doc();
}

function createFinancialEvent(transaction, eventRef, data) {
  // create(), rather than set()/merge(), enforces append-only behavior. A
  // collision or unavailable ledger aborts the transaction and therefore
  // also aborts the payout state transition.
  transaction.create(eventRef, data);
}

module.exports = {
  FINANCIAL_EVENTS_COLLECTION,
  financialEventData,
  newFinancialEventRef,
  createFinancialEvent,
};
