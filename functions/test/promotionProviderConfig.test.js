"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  assertPromotionIyzicoEndpoint,
  isPromotionEmulatorEnvironment,
} = require("../src/promotion/promotion_provider_config");

test("Promotion iyzico accepts the sandbox endpoint only for emulator execution", () => {
  assert.equal(
    assertPromotionIyzicoEndpoint({
      uri: "https://sandbox-api.iyzipay.com/",
      isEmulator: true,
    }),
    "https://sandbox-api.iyzipay.com",
  );
  assert.throws(
    () => assertPromotionIyzicoEndpoint({
      uri: "https://sandbox-api.iyzipay.com",
      isEmulator: false,
    }),
    /sandbox endpoint is not allowed/,
  );
});

test("Promotion iyzico requires HTTPS outside the emulator", () => {
  assert.throws(
    () => assertPromotionIyzicoEndpoint({uri: "http://payment.example", isEmulator: false}),
    /must use HTTPS/,
  );
});

test("emulator detection is explicit and does not infer production from a project name", () => {
  assert.equal(isPromotionEmulatorEnvironment({functionsEmulator: "true"}), true);
  assert.equal(isPromotionEmulatorEnvironment({firestoreEmulatorHost: "127.0.0.1:8080"}), true);
  assert.equal(isPromotionEmulatorEnvironment({functionsEmulator: "false", firestoreEmulatorHost: ""}), false);
});
