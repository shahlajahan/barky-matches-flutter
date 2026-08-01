"use strict";

const admin = require("firebase-admin");
const crypto = require("node:crypto");

const FINANCE_LEDGER_COLLECTION = "financeLedger";
const LEDGER_VERSION = 1;

function cents(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new Error("Ledger amount must be a finite number.");
  }
  return Math.round(parsed * 100);
}

function ledgerEntryId({
  eventType,
  sourceCollection,
  sourceDocumentId,
  idempotencyKey,
}) {
  const identity = [
    LEDGER_VERSION,
    eventType,
    sourceCollection,
    sourceDocumentId,
    idempotencyKey,
  ].join("|");
  return crypto.createHash("sha256").update(identity).digest("hex");
}

function ledgerEntry({
  eventType,
  sourceCollection,
  sourceDocumentId,
  businessId,
  rootOrderId = null,
  batchId = null,
  amount,
  currency,
  direction,
  actor,
  reason,
  reference = null,
  idempotencyKey,
  metadata = {},
  occurredAt = admin.firestore.FieldValue.serverTimestamp(),
}) {
  const amountCents = cents(amount);
  if (!["debit", "credit", "memo"].includes(direction)) {
    throw new Error("Invalid ledger direction.");
  }
  return {
    version: LEDGER_VERSION,
    eventType,
    sourceCollection,
    sourceDocumentId: String(sourceDocumentId),
    businessId: businessId ? String(businessId) : null,
    rootOrderId: rootOrderId ? String(rootOrderId) : null,
    batchId: batchId ? String(batchId) : null,
    amount: amountCents / 100,
    amountCents,
    currency: String(currency || "TRY").toUpperCase(),
    direction,
    actor: actor || { type: "system", id: null },
    reason: reason || null,
    reference,
    idempotencyKey: String(idempotencyKey),
    metadata,
    occurredAt,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function appendLedgerEntry(transaction, db, data) {
  const id = ledgerEntryId(data);
  const ref = db.collection(FINANCE_LEDGER_COLLECTION).doc(id);
  const existing = await transaction.get(ref);
  if (existing.exists) return { id, created: false };
  transaction.create(ref, ledgerEntry(data));
  return { id, created: true };
}

async function appendLedgerEntries(transaction, db, entries) {
  const prepared = entries.map((data) => {
    const id = ledgerEntryId(data);
    return {
      id,
      data,
      ref: db.collection(FINANCE_LEDGER_COLLECTION).doc(id),
    };
  });
  const snapshots = await transaction.getAll(
    ...prepared.map((entry) => entry.ref)
  );
  const results = [];
  prepared.forEach((entry, index) => {
    if (snapshots[index].exists) {
      results.push({ id: entry.id, created: false });
    } else {
      transaction.create(entry.ref, ledgerEntry(entry.data));
      results.push({ id: entry.id, created: true });
    }
  });
  return results;
}

module.exports = {
  FINANCE_LEDGER_COLLECTION,
  LEDGER_VERSION,
  cents,
  ledgerEntryId,
  ledgerEntry,
  appendLedgerEntry,
  appendLedgerEntries,
};
