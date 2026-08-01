"use strict";

const { buildPayoutBatchWorkbook } = require("../../payout/payoutWorkbook");

const xlsxFinanceExporter = Object.freeze({
  format: "xlsx",
  contentType:
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  extension: "xlsx",
  async build(payload) {
    return buildPayoutBatchWorkbook(payload);
  },
});

module.exports = { xlsxFinanceExporter };
