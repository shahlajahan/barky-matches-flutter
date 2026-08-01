"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const service = fs.readFileSync(
  path.resolve(__dirname, "../payout/payoutBatchService.js"),
  "utf8"
);
const index = fs.readFileSync(path.resolve(__dirname, "../index.js"), "utf8");
const payoutEngine = fs.readFileSync(
  path.resolve(__dirname, "../payout/payoutEngine.js"),
  "utf8"
);

test("batch creation reserves every payout in the same transaction", () => {
  assert.match(service, /db\.runTransaction\(async \(transaction\)/);
  assert.match(service, /transaction\.getAll\(\.\.\.indexRefs\)/);
  assert.match(service, /reasons\.includes|reasons\.length > 0/);
  assert.match(service, /transaction\.update\(snapshot\.ref,\s*\{/);
  assert.match(service, /batchId: batchRef\.id/);
  assert.match(service, /payoutValidationReasons\(record\)/);
});

test("export validates reservations and does not mark payouts paid", () => {
  const exportBlock = service.match(
    /async function exportPayoutBatch[\s\S]*?async function markPayoutBatchItemPaid/
  );
  assert.ok(exportBlock);
  assert.match(exportBlock[0], /allowReservedBatchId: batchId/);
  assert.match(exportBlock[0], /status: "exported"/);
  assert.doesNotMatch(exportBlock[0], /payoutStatus:\s*"paid"/);
  assert.match(exportBlock[0], /getSignedUrl/);
  assert.doesNotMatch(exportBlock[0], /bytesBase64/);
});

test("download returns a signed Storage URL instead of Base64 content", () => {
  const downloadBlock = service.match(
    /async function downloadPayoutBatchExport[\s\S]*?async function markPayoutBatchProcessing/
  );
  assert.ok(downloadBlock);
  assert.match(downloadBlock[0], /getMetadata/);
  assert.match(downloadBlock[0], /getSignedUrl/);
  assert.doesNotMatch(downloadBlock[0], /bytesBase64/);
});

test("seller-item payment is idempotent and updates only included records", () => {
  const paidBlock = service.match(
    /async function markPayoutBatchItemPaid[\s\S]*?module\.exports/
  );
  assert.ok(paidBlock);
  assert.match(paidBlock[0], /if \(item\.status === "paid"\)/);
  assert.match(paidBlock[0], /idempotent: true/);
  assert.match(paidBlock[0], /item\.payoutIndexIds/);
  assert.match(paidBlock[0], /payoutStatus: "paid"/);
  assert.match(paidBlock[0], /payout_batch_item_paid/);
});

test("every payout batch mutation is server-authorized", () => {
  for (const callable of [
    "createPayoutBatch",
    "exportPayoutBatch",
    "markPayoutBatchItemPaid",
  ]) {
    const block = index.match(
      new RegExp(`exports\\.${callable} = onCall\\([\\s\\S]*?\\n\\);`)
    );
    assert.ok(block, `${callable} must exist`);
    assert.match(block[0], /requireFinancePermission\(/);
  }
});

test("only unfrozen drafts recalculate; frozen/exported batches invalidate", () => {
  assert.match(
    payoutEngine,
    /batch\.status === "draft" && !batch\.frozenAt/
  );
  assert.match(payoutEngine, /recalculationReason: "refund_or_reversal"/);
  assert.match(payoutEngine, /payoutRecordCount:[\s\S]*- 1/);
  assert.match(payoutEngine, /batchId: admin\.firestore\.FieldValue\.delete\(\)/);
  assert.match(payoutEngine, /status: "invalidated"/);
  assert.match(payoutEngine, /invalidationReason: "refund_or_reversal"/);
});
