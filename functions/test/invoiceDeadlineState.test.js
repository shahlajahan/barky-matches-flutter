"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const test = require("node:test");
const {
  INVOICE_INACTIVE_STATUS,
  deadlineFromActivation,
  invoiceDiagnosticReason,
} = require("../invoice/invoiceDeadlineState");
const { classify } = require("../scripts/backfillInvoiceDeadlineState");

const indexSource = fs.readFileSync(require.resolve("../index.js"), "utf8");
const stateSource = fs.readFileSync(require.resolve("../invoice/invoiceDeadlineState.js"), "utf8");

test("new unpaid orders use inactive invoice state", () => {
  assert.equal(INVOICE_INACTIVE_STATUS, "not_required_yet");
  assert.equal(
    invoiceDiagnosticReason({
      status: "pending_payment",
      paymentStatus: "pending",
      invoice: { status: INVOICE_INACTIVE_STATUS },
    }),
    "invoice_inactive_unpaid",
  );
  assert.match(indexSource, /status: INVOICE_INACTIVE_STATUS/);
});

test("deadline is derived from activation timestamp and threshold", () => {
  const activation = new Date("2026-01-01T00:00:00.000Z");
  assert.equal(
    deadlineFromActivation(activation, 72).toISOString(),
    "2026-01-04T00:00:00.000Z",
  );
  assert.match(indexSource, /MARKETPLACE_INVOICE_UPLOAD_THRESHOLD_HOURS \* 60 \* 60 \* 1000/);
  assert.match(indexSource, /invoice\.activatedAt/);
  assert.match(indexSource, /invoice\.activationReason/);
});

test("scheduler requires paid actionable status and valid deadline", () => {
  assert.equal(
    invoiceDiagnosticReason({
      status: "shipped",
      paymentStatus: "paid",
      invoice: { status: "pending_upload", uploadDeadlineAt: activationDate() },
    }),
    null,
  );
  assert.equal(
    invoiceDiagnosticReason({
      status: "shipped",
      paymentStatus: "pending",
      invoice: { status: "pending_upload" },
    }),
    "invoice_inactive_unpaid",
  );
  assert.equal(
    invoiceDiagnosticReason({
      status: "shipped",
      paymentStatus: "paid",
      invoice: { status: "pending_upload" },
    }),
    "invoice_deadline_missing",
  );
  assert.equal(
    invoiceDiagnosticReason({
      status: "paid",
      paymentStatus: "paid",
      invoice: { status: "pending_upload", uploadDeadlineAt: activationDate() },
    }),
    "invoice_state_mismatch",
  );
  assert.match(indexSource, /invoiceDiagnosticReason\(data\)/);
  assert.match(stateSource, /invoice_inactive_unpaid/);
  assert.match(stateSource, /invoice_deadline_missing/);
});

test("dry-run classification repairs only deterministic historical cases", () => {
  assert.equal(
    classify({ status: "pending_payment", paymentStatus: "pending", invoice: { status: "pending_upload" } }).category,
    "unpaid_inactive",
  );
  assert.equal(
    classify({ status: "shipped", paymentStatus: "paid", invoice: { status: "pending_upload" }, shipping: { shippedAt: new Date("2026-01-01") } }).category,
    "paid_missing_deadline",
  );
  assert.equal(
    classify({ status: "shipped", paymentStatus: "paid", invoice: { status: "pending_upload", uploadDeadlineAt: "not-a-date" } }).category,
    "invalid_deadline",
  );
});

test("activation is idempotent and does not move an existing deadline", () => {
  const activationBlock = indexSource.slice(
    indexSource.indexOf("if (INVOICE_ACTIONABLE_ORDER_STATUSES.has(newStatus))"),
    indexSource.indexOf("} catch (error)", indexSource.indexOf("if (INVOICE_ACTIONABLE_ORDER_STATUSES.has(newStatus))")),
  );
  assert.match(activationBlock, /if \(!currentInvoice\.uploadDeadlineAt\)/);
  assert.match(activationBlock, /INVOICE DEADLINE ALREADY EXISTS/);
});

function activationDate() {
  return new Date("2026-01-01T00:00:00.000Z");
}
