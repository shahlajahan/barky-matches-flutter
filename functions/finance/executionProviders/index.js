"use strict";

const manualEftProvider = Object.freeze({
  id: "manual_eft",
  displayName: "Manual EFT",
  requiresExport: true,
  supportsAutomaticDebit: false,
});

const EXECUTION_PROVIDERS = new Map([
  [manualEftProvider.id, manualEftProvider],
]);

function getExecutionProvider(providerId = "manual_eft") {
  const normalized = String(providerId || "").trim().toLowerCase();
  const provider = EXECUTION_PROVIDERS.get(normalized);
  if (!provider) {
    const error = new Error(`Unsupported payout execution provider: ${normalized}`);
    error.code = "invalid-argument";
    throw error;
  }
  return provider;
}

module.exports = {
  EXECUTION_PROVIDERS,
  getExecutionProvider,
};
