"use strict";

const { xlsxFinanceExporter } = require("./xlsxFinanceExporter");

const EXPORTERS = new Map([
  [xlsxFinanceExporter.format, xlsxFinanceExporter],
]);

function getFinanceExporter(format) {
  const normalized = String(format || "xlsx").trim().toLowerCase();
  const exporter = EXPORTERS.get(normalized);
  if (!exporter) {
    const error = new Error(`Unsupported finance export format: ${normalized}`);
    error.code = "invalid-argument";
    throw error;
  }
  return exporter;
}

module.exports = { getFinanceExporter, EXPORTERS };
