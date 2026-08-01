"use strict";

const admin = require("firebase-admin");

const ALLOWED_FILTER_FIELDS = new Set([
  "datePreset",
  "periodStart",
  "periodEnd",
  "sector",
  "seller",
  "bank",
  "payoutStatus",
  "eligibilityStatus",
  "settlementStatus",
  "bankValidationStatus",
  "minimumAmount",
  "maximumAmount",
  "minimumWaitingDays",
  "maximumWaitingDays",
  "includedInBatch",
  "currency",
]);

function sanitizeFilters(value) {
  const input = value && typeof value === "object" ? value : {};
  return Object.fromEntries(
    Object.entries(input).filter(
      ([key, item]) =>
        ALLOWED_FILTER_FIELDS.has(key) &&
        (item === null ||
          typeof item === "string" ||
          typeof item === "number" ||
          typeof item === "boolean")
    )
  );
}

async function saveFinanceFilter({ db, userId, filterId, name, filters }) {
  const normalizedName = String(name || "").trim().slice(0, 80);
  if (!normalizedName) {
    const error = new Error("Filter name is required.");
    error.code = "invalid-argument";
    throw error;
  }
  const collection = db
    .collection("financeSavedFilters")
    .doc(userId)
    .collection("filters");
  const ref = filterId ? collection.doc(String(filterId)) : collection.doc();
  const now = admin.firestore.FieldValue.serverTimestamp();
  await ref.set(
    {
      name: normalizedName,
      filters: sanitizeFilters(filters),
      ownerUid: userId,
      updatedAt: now,
      createdAt: now,
    },
    { merge: true }
  );
  return { filterId: ref.id };
}

async function deleteFinanceFilter({ db, userId, filterId }) {
  const normalizedId = String(filterId || "").trim();
  if (!normalizedId) {
    const error = new Error("filterId is required.");
    error.code = "invalid-argument";
    throw error;
  }
  await db
    .collection("financeSavedFilters")
    .doc(userId)
    .collection("filters")
    .doc(normalizedId)
    .delete();
  return { filterId: normalizedId, deleted: true };
}

module.exports = {
  ALLOWED_FILTER_FIELDS,
  sanitizeFilters,
  saveFinanceFilter,
  deleteFinanceFilter,
};
