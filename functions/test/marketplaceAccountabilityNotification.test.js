"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const source = fs.readFileSync(
  path.resolve(__dirname, "../index.js"),
  "utf8"
);

function accountabilitySource() {
  const match = source.match(
    /exports\.checkMarketplaceAccountability = onSchedule\([\s\S]*?\n\);\n\n/
  );
  assert.ok(match, "accountability scheduler must exist");
  return match[0];
}

test("delayed notification identity includes collection and document", () => {
  assert.match(
    source,
    /function marketplaceBusinessDelayedNotificationId\(collectionName, documentId\)/
  );
  assert.match(source, /createHash\("sha256"\)\.update\(identity\)/);
  assert.match(source, /marketplace_business_delayed_\$\{digest\}/);
});

test("accountability uses the four canonical source collections", () => {
  for (const collection of [
    "vet_appointments",
    "groomy_appointments",
    "hotel_bookings",
    "pet_taxi_bookings",
  ]) {
    assert.match(source, new RegExp(`"${collection}"`));
  }
});

test("claim and notification creation occur in one transaction", () => {
  const callable = accountabilitySource();
  assert.match(callable, /db\.runTransaction\(async \(transaction\)/);
  assert.match(callable, /transaction\.get\(doc\.ref\)/);
  assert.match(callable, /transaction\.get\(notificationRef\)/);
  assert.match(callable, /transaction\.update\(doc\.ref, \{/);
  assert.match(callable, /transaction\.create\(notificationRef, \{/);
  assert.match(callable, /normalizeLower\(data\.status\) !== "pending"/);
  assert.match(callable, /deadlineMillis >= Date\.now\(\)/);
  assert.match(callable, /data\.marketplace\?\.delayedAction === true/);
  assert.match(callable, /notificationSnap\.exists/);
});

test("notification payload preserves all four collection contracts", () => {
  const callable = accountabilitySource();
  assert.match(callable, /appointmentCollection: collectionName/);
  assert.match(
    callable,
    /collectionName === "hotel_bookings" \|\|\s*collectionName === "pet_taxi_bookings"/
  );
  assert.match(callable, /appointmentId: doc\.id/);
  assert.match(callable, /recipientUserId: buyerUid/);
  assert.doesNotMatch(
    callable,
    /marketplace_business_delayed[\s\S]{0,500}recipientUserId:\s*businessId/
  );
});

test("FCM occurs only after a successful transaction-created notification", () => {
  const callable = accountabilitySource();
  assert.match(callable, /if \(result\.status !== "claimed"\) continue/);
  assert.match(callable, /notificationCreated/);
  assert.match(callable, /sendMarketplaceBusinessDelayedPush\(result\.notificationPayload\)/);
  assert.match(callable, /logger\.warn\("MARKETPLACE_DELAYED_NOTIFICATION_SKIPPED"/);
});

test("existing delay and penalty semantics remain unchanged", () => {
  const callable = accountabilitySource();
  for (const field of [
    '"marketplace.delayedAction": true',
    '"marketplace.warningState": "response_delayed"',
    '"marketplace.punishmentState": "warning"',
    '"marketplace.visibleStatus": "Business response delayed"',
    '"compliance.delayedResponse": true',
    '"compliance.delayedCount": admin.firestore.FieldValue.increment(1)',
    '"compliance.warningCount": admin.firestore.FieldValue.increment(1)',
    '"compliance.penaltyPoints": admin.firestore.FieldValue.increment(10)',
  ]) {
    assert.match(callable, new RegExp(field.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  }
});
