"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
  path.resolve(__dirname, "../index.js"),
  "utf8"
);
const createBlock = source.match(
  /exports\.createPetTaxiOrder = onCall\([\s\S]*?\n\);\n\nexports\.verifyPetTaxiPayment/
)?.[0] || "";

test("Pet Taxi checkout uses the shared İşbank 3D Pay Hosting helper", () => {
  assert.ok(createBlock);
  assert.match(createBlock, /secrets: \[ISBANK_CLIENT_ID, ISBANK_STORE_KEY\]/);
  assert.match(createBlock, /createIsbank3DPayHostingCheckoutResult/);
  assert.match(createBlock, /provider: "isbank"/);
  assert.match(createBlock, /storeType: "3D_PAY_HOSTING"/);
  assert.doesNotMatch(createBlock, /Iyzipay|iyzico|iyzipay\.com/);
});

test("Pet Taxi order amount comes only from the authoritative finalPrice", () => {
  assert.match(createBlock, /const price = Number\(data\.finalPrice\);/);
  assert.doesNotMatch(createBlock, /data\.paymentAmount/);
  assert.match(createBlock, /normalizeIsbankAmount\(price\)/);
  assert.match(createBlock, /pricing: \{\s*grandTotal: price,/);
  assert.match(createBlock, /paymentAmount: price/);
});

test("Pet Taxi final price cannot change after a payment order exists", () => {
  const statusBlock = source.match(
    /exports\.updatePetTaxiBookingStatus = onCall\([\s\S]*?\n\);\n\nexports\.createPetTaxiOrder/
  )?.[0] || "";
  assert.match(statusBlock, /data\.paymentOrderId \|\| data\.orderId/);
  assert.match(statusBlock, /Final price cannot change after payment order creation/);
});

test("Pet Taxi orders are explicitly classified and persisted as İşbank orders", () => {
  assert.match(createBlock, /type: "pet_taxi"/);
  assert.match(createBlock, /appointmentCollection: "pet_taxi_bookings"/);
  assert.match(createBlock, /appointmentType: "pet_taxi"/);
  assert.match(createBlock, /paymentProvider: "isbank"/);
  assert.match(createBlock, /db\.runTransaction\(async \(transaction\)/);
  assert.match(createBlock, /data\.paymentOrderId \|\| data\.orderId/);
  assert.match(createBlock, /Existing Pet Taxi payment order does not match this booking/);
});

test("verified callback finalization has a Pet Taxi-specific branch", () => {
  assert.match(source, /async function finalizePetTaxiAfterPaid\(/);
  assert.match(source, /effectiveOrderData\.type === "pet_taxi"\s*\?/);
  assert.match(source, /bookingData\.finalPrice/);
  assert.match(source, /booking_amount_or_currency_mismatch/);
  assert.match(source, /booking_already_paid_different_order/);
  assert.match(source, /pet_taxi_finalization_target_missing/);
  assert.match(source, /paymentProvider: "isbank"/);
});

test("Pet Taxi payment notifications are deterministic and callback retries are idempotent", () => {
  const finalizer = source.match(
    /async function finalizePetTaxiAfterPaid\([\s\S]*?\n}\n\nasync function finalizeIsbankPaidOrder/
  )?.[0] || "";
  assert.match(source, /createPetTaxiPaymentNotificationOnce\(/);
  assert.match(source, /pet_taxi_payment_completed_\$\{orderId\}/);
  assert.match(source, /pet_taxi_payment_success_\$\{orderId\}/);
  assert.match(source, /pet_taxi_payment_notification_failed/);
  assert.doesNotMatch(finalizer, /recipientUserId = businessId;/);
  assert.match(source, /finalizationStatus === "completed"/);
});

test("Pet Taxi financial currency follows the accepted final-price currency", () => {
  const financialSource = fs.readFileSync(
    path.resolve(__dirname, "../commission/paymentFinancialSnapshot.js"),
    "utf8"
  );
  assert.match(
    financialSource,
    /record\.finalPriceCurrency\s*\|\|\s*record\.paymentCurrency/
  );
});

test("direct client Pet Taxi orders cannot self-declare paid state", () => {
  const rules = fs.readFileSync(
    path.resolve(__dirname, "../../firestore.rules"),
    "utf8"
  );
  const orders = rules.match(/match \/orders\/\{orderId\}[\s\S]*?\n    \}/)?.[0] || "";
  assert.match(orders, /request\.resource\.data\.type != 'pet_taxi'/);
  assert.match(orders, /request\.resource\.data\.status == 'pending'/);
  assert.match(orders, /request\.resource\.data\.paymentStatus == 'pending'/);
});

test("stale Pet Taxi finalization recovery has a deployable composite index", () => {
  const indexes = JSON.parse(fs.readFileSync(
    path.resolve(__dirname, "../../firestore.indexes.json"),
    "utf8"
  ));
  const index = indexes.indexes.find((candidate) =>
    candidate.collectionGroup === "orders" &&
    candidate.fields.some((field) => field.fieldPath === "payment.finalizationLeaseUntil")
  );
  assert.ok(index);
  assert.deepEqual(
    index.fields.map((field) => field.fieldPath),
    [
      "type",
      "payment.provider",
      "payment.callbackValidated",
      "payment.finalizationStatus",
      "payment.finalizationLeaseUntil",
    ]
  );
});

test("the shared İşbank callback validates the payment proof before finalization", () => {
  const callback = source.match(
    /exports\.isbank3DPayHostingCallback = onRequest\([\s\S]*?\n\);\n\nexports\.readPaymentStatusByOrderId/
  )?.[0] || "";
  assert.match(callback, /validateIsbankGenericVer3CallbackHash/);
  assert.match(callback, /callbackAmount !== expectedAmount/);
  assert.match(callback, /callbackCurrency !== expectedCurrency/);
  assert.match(callback, /callbackProcReturnCode !== "00"/);
  assert.match(callback, /callbackMdStatus !== "1"/);
  assert.match(callback, /callbackResponse !== "approved"/);
});

test("Flutter Pet Taxi payment no longer calls the legacy iyzico verifier", () => {
  const dart = fs.readFileSync(
    path.resolve(__dirname, "../../lib/ui/pet_taxi/pet_taxi_booking_detail_page.dart"),
    "utf8"
  );
  assert.match(dart, /httpsCallable\('createPetTaxiOrder'\)/);
  assert.match(dart, /presentCheckoutSession/);
  assert.match(dart, /isbank_success_redirect/);
  assert.doesNotMatch(dart, /verifyPetTaxiPayment/);
});
