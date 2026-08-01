"use strict";

const admin = require("firebase-admin");
const {
  INVOICE_INACTIVE_STATUS,
  INVOICE_UPLOAD_THRESHOLD_HOURS,
  INVOICE_ACTIONABLE_ORDER_STATUSES,
  deadlineFromActivation,
  normalize,
  paymentIsConfirmed,
  toMillis,
} = require("../invoice/invoiceDeadlineState");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

function parseArgs(argv) {
  const options = { write: false, sampleLimit: 20 };
  for (let index = 2; index < argv.length; index += 1) {
    if (argv[index] === "--write") options.write = true;
    if (argv[index] === "--sample-limit") {
      options.sampleLimit = Math.max(1, Number(argv[index + 1] || 20));
      index += 1;
    }
  }
  return options;
}

function activationCandidate(data) {
  const invoice = data.invoice || {};
  return invoice.activatedAt ||
    data.preparingAt ||
    data.shipping?.shippedAt ||
    data.shippedAt ||
    data.deliveredAt ||
    data.shipping?.deliveredAt ||
    null;
}

function classify(data) {
  const invoice = data.invoice || {};
  const status = normalize(data.status);
  const paid = paymentIsConfirmed(data);
  const deadline = toMillis(invoice.uploadDeadlineAt);
  if (!paid) return { category: "unpaid_inactive", reason: "invoice_inactive_unpaid" };
  if (!INVOICE_ACTIONABLE_ORDER_STATUSES.has(status)) {
    return { category: "ambiguous", reason: "invoice_state_mismatch" };
  }
  if (deadline) return { category: "valid_actionable", reason: null };
  const activationAt = activationCandidate(data);
  const reconstructed = deadlineFromActivation(activationAt, INVOICE_UPLOAD_THRESHOLD_HOURS);
  if (reconstructed) {
    return {
      category: "paid_missing_deadline",
      reason: "invoice_deadline_missing",
      activationAt,
      deadline: reconstructed,
      activationReason: invoice.activationReason || status,
    };
  }
  if (invoice.uploadDeadlineAt) {
    return { category: "invalid_deadline", reason: "invoice_deadline_invalid" };
  }
  return { category: "ambiguous", reason: "invoice_deadline_missing" };
}

async function run(options = parseArgs(process.argv)) {
  const snapshot = await db
    .collection("sellerOrders")
    .where("invoice.status", "==", "pending_upload")
    .get();
  const report = {
    dryRun: !options.write,
    scanned: snapshot.size,
    counts: {
      valid_actionable: 0,
      unpaid_inactive: 0,
      paid_missing_deadline: 0,
      invalid_deadline: 0,
      ambiguous: 0,
      repaired: 0,
    },
    samples: [],
  };
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const result = classify(data);
    report.counts[result.category] += 1;
    const sample = {
      sellerOrderId: doc.id,
      category: result.category,
      reason: result.reason,
      status: data.status || null,
      paymentStatus: data.paymentStatus || data.payment?.status || null,
      deadline: data.invoice?.uploadDeadlineAt || null,
      reconstructedDeadline: result.deadline || null,
    };
    if (report.samples.length < options.sampleLimit) report.samples.push(sample);

    if (!options.write) continue;
    if (result.category === "unpaid_inactive") {
      await doc.ref.set({
        "invoice.status": INVOICE_INACTIVE_STATUS,
        "invoice.diagnosticClassification": result.reason,
        "invoice.diagnosticLoggedAt": admin.firestore.FieldValue.serverTimestamp(),
        invoiceStatus: INVOICE_INACTIVE_STATUS,
        "documents.invoiceStatus": INVOICE_INACTIVE_STATUS,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      report.counts.repaired += 1;
    } else if (result.category === "paid_missing_deadline") {
      const activationAt = admin.firestore.Timestamp.fromMillis(toMillis(result.activationAt));
      const deadline = admin.firestore.Timestamp.fromDate(result.deadline);
      await doc.ref.set({
        "invoice.status": "pending_upload",
        "invoice.uploadDeadlineAt": deadline,
        "invoice.activatedAt": activationAt,
        "invoice.activationReason": result.activationReason,
        "deadlines.invoiceUploadDeadlineAt": deadline,
        invoiceStatus: "pending_upload",
        invoiceDeadline: deadline,
        "documents.invoiceStatus": "pending_upload",
        "documents.invoiceRequired": true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      report.counts.repaired += 1;
    }
  }
  return report;
}

if (require.main === module) {
  run().then((report) => console.log(JSON.stringify(report, null, 2))).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = { classify, run, parseArgs };
