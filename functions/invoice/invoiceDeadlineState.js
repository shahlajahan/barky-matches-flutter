"use strict";

const INVOICE_INACTIVE_STATUS = "not_required_yet";
const INVOICE_UPLOAD_THRESHOLD_HOURS = 72;
const INVOICE_PENDING_STATUS = "pending_upload";
const INVOICE_ACTIONABLE_ORDER_STATUSES = new Set([
  "preparing",
  "shipped",
  "delivered",
]);
const INVOICE_CONFIRMED_PAYMENT_STATUSES = new Set(["paid", "confirmed"]);

function normalize(value) {
  return String(value || "").trim().toLowerCase();
}

function toMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = new Date(value).getTime();
  return Number.isFinite(parsed) ? parsed : 0;
}

function paymentIsConfirmed(data = {}) {
  return INVOICE_CONFIRMED_PAYMENT_STATUSES.has(
    normalize(data.paymentStatus || data.payment?.status)
  );
}

function invoiceDiagnosticReason(data = {}) {
  const invoice = data.invoice || {};
  if (!paymentIsConfirmed(data)) return "invoice_inactive_unpaid";
  if (!INVOICE_ACTIONABLE_ORDER_STATUSES.has(normalize(data.status))) {
    return "invoice_state_mismatch";
  }
  if (!invoice.uploadDeadlineAt) return "invoice_deadline_missing";
  if (!toMillis(invoice.uploadDeadlineAt)) return "invoice_deadline_invalid";
  return null;
}

function deadlineFromActivation(activationAt, thresholdHours) {
  const activationMillis = toMillis(activationAt);
  const hours = Number(thresholdHours);
  if (!activationMillis || !Number.isFinite(hours) || hours <= 0) return null;
  return new Date(activationMillis + hours * 60 * 60 * 1000);
}

module.exports = {
  INVOICE_INACTIVE_STATUS,
  INVOICE_UPLOAD_THRESHOLD_HOURS,
  INVOICE_PENDING_STATUS,
  INVOICE_ACTIONABLE_ORDER_STATUSES,
  INVOICE_CONFIRMED_PAYMENT_STATUSES,
  normalize,
  toMillis,
  paymentIsConfirmed,
  invoiceDiagnosticReason,
  deadlineFromActivation,
};
