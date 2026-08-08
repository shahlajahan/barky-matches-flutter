"use strict";

function isPromotionEmulatorEnvironment({
  functionsEmulator = process.env.FUNCTIONS_EMULATOR,
  firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST,
} = {}) {
  return functionsEmulator === "true" || Boolean(firestoreEmulatorHost);
}

function assertPromotionIyzicoEndpoint({uri, isEmulator = false} = {}) {
  const normalized = String(uri || "").trim().replace(/\/$/, "");
  if (!/^https:\/\//i.test(normalized)) {
    throw new Error("Promotion iyzico endpoint must use HTTPS");
  }
  if (!isEmulator && /sandbox-api\.iyzipay\.com/i.test(normalized)) {
    throw new Error("Promotion iyzico sandbox endpoint is not allowed outside the emulator");
  }
  return normalized;
}

module.exports = {
  assertPromotionIyzicoEndpoint,
  isPromotionEmulatorEnvironment,
};
