const assert = require("node:assert/strict");
const crypto = require("crypto");
const admin = require("firebase-admin");
const { before, test } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}

const db = admin.firestore();
const functions = require("../index");
const runId = `${Date.now()}-${process.pid}-${crypto.randomBytes(4).toString("hex")}`;
let sequence = 0;

before(async () => {
  assert.match(
    process.env.FIRESTORE_EMULATOR_HOST || "",
    /^(127\.0\.0\.1|localhost):\d+$/,
    "Pet Taxi integration tests require a local Firestore emulator"
  );
  await db.collection("users").doc(`pet-taxi-booking-customer-${runId}`).set({ role: "user" });
});

function fixture({ ownerUid = `pet-taxi-booking-owner-${runId}-${++sequence}`, token } = {}) {
  const businessId = `pet-taxi-booking-business-${runId}-${sequence}`;
  return {
    businessId,
    ownerUid,
    customerUid: `pet-taxi-booking-customer-${runId}-${sequence}`,
    business: {
      ownerUid,
      status: "approved",
      sectors: ["pet_taxi"],
      published: true,
      verification: { isVerified: true },
      ...(token ? { fcmToken: token } : {}),
      sectorData: {
        pet_taxi: {
          isAvailable: true,
          isActive: true,
          published: true,
          compliance: { status: "approved" },
        },
      },
    },
  };
}

async function seed(item) {
  await Promise.all([
    db.collection("businesses").doc(item.businessId).set(item.business),
    db.collection("users").doc(item.customerUid).set({ role: "user" }),
    db.collection("users").doc(item.ownerUid).set({ role: "user", ...(item.business.fcmToken ? { fcmToken: item.business.fcmToken } : {}) }),
  ]);
}

function payload(item, clientRequestId) {
  return {
    clientRequestId,
    businessId: item.businessId,
    businessName: "Test Pet Taxi",
    petId: "test-pet",
    petName: "Minnoş",
    petType: "dog",
    petBreed: "mixed",
    pickupAddress: "Pickup",
    pickupLocation: { lat: 41, lng: 29 },
    pickupLat: 41,
    pickupLng: 29,
    dropoffAddress: "Dropoff",
    dropoffLocation: { lat: 41.01, lng: 29.01 },
    dropoffLat: 41.01,
    dropoffLng: 29.01,
    scheduledAt: "2026-08-12T10:00:00.000Z",
    userPhone: "+905555555555",
    paymentMethod: "in_app",
    estimatedMinPrice: 100,
    estimatedMaxPrice: 150,
    estimateCurrency: "TRY",
    routeDistanceKm: 2,
    routeDurationMinutes: 10,
  };
}

async function call(item, uid, data) {
  return functions.createPetTaxiBooking.run({ auth: { uid }, data });
}

async function bookingsFor(item) {
  return db.collection("pet_taxi_bookings")
    .where("businessId", "==", item.businessId)
    .get();
}

async function notificationsFor(bookingId) {
  return db.collection("notifications")
    .where("bookingId", "==", bookingId)
    .get();
}

test("first request creates one booking and retry returns it without side effects", async () => {
  const item = fixture();
  await seed(item);
  const requestId = `request-${runId}-basic`;
  const first = await call(item, item.customerUid, payload(item, requestId));
  const retry = await call(item, item.customerUid, payload(item, requestId));

  assert.equal(first.ok, true);
  assert.equal(first.deduplicated, false);
  assert.equal(retry.ok, true);
  assert.equal(retry.deduplicated, true);
  assert.equal(retry.bookingId, first.bookingId);
  assert.equal((await bookingsFor(item)).size, 1);
  assert.equal((await notificationsFor(first.bookingId)).size, 1);

  const booking = (await db.collection("pet_taxi_bookings").doc(first.bookingId).get()).data();
  assert.equal(booking.businessId, item.businessId);
  assert.equal(booking.userId, item.customerUid);
  assert.equal(booking.status, "pending");
  assert.equal(booking.marketplace.transactionId, first.bookingId);
  assert.equal(booking.invoice.transactionId, first.bookingId);
});

test("distinct request IDs create independent bookings", async () => {
  const item = fixture();
  await seed(item);
  const first = await call(item, item.customerUid, payload(item, `request-${runId}-a`));
  const second = await call(item, item.customerUid, payload(item, `request-${runId}-b`));
  assert.notEqual(first.bookingId, second.bookingId);
  assert.equal((await bookingsFor(item)).size, 2);
});

test("request identity is scoped to the authenticated user", async () => {
  const item = fixture();
  await seed(item);
  const sameRequestId = `request-${runId}-scoped`;
  const first = await call(item, item.customerUid, payload(item, sameRequestId));
  const otherUid = `pet-taxi-booking-other-${runId}`;
  const other = await call(item, otherUid, payload(item, sameRequestId));
  assert.notEqual(first.bookingId, other.bookingId);
  assert.equal((await bookingsFor(item)).size, 2);
});

test("concurrent identical requests create exactly one booking and notification", async () => {
  const item = fixture();
  await seed(item);
  const requestId = `request-${runId}-concurrent`;
  const results = await Promise.all(
    Array.from({ length: 5 }, () => call(item, item.customerUid, payload(item, requestId)))
  );
  assert.equal(new Set(results.map((result) => result.bookingId)).size, 1);
  assert.equal((await bookingsFor(item)).size, 1);
  assert.equal((await notificationsFor(results[0].bookingId)).size, 1);
});

test("notification failure leaves booking and idempotency retry valid", async () => {
  const item = fixture({ token: "definitely-invalid-fcm-token" });
  await seed(item);
  const requestId = `request-${runId}-notification-failure`;
  const messaging = admin.messaging();
  const originalSend = messaging.send;
  let sendCount = 0;
  messaging.send = async () => {
    sendCount += 1;
    throw new Error("simulated FCM failure");
  };
  try {
    const first = await call(item, item.customerUid, payload(item, requestId));
    const retry = await call(item, item.customerUid, payload(item, requestId));
    assert.equal(first.ok, true);
    assert.equal(retry.ok, true);
    assert.equal(retry.bookingId, first.bookingId);
    assert.equal(retry.deduplicated, true);
    assert.equal((await bookingsFor(item)).size, 1);
    assert.equal((await notificationsFor(first.bookingId)).size, 1);
    assert.equal(sendCount, 1);
  } finally {
    messaging.send = originalSend;
  }
});

test("booking creation does not alter lifecycle or availability state", async () => {
  const item = fixture();
  await seed(item);
  const before = (await db.collection("businesses").doc(item.businessId).get()).data();
  await call(item, item.customerUid, payload(item, `request-${runId}-state`));
  const after = (await db.collection("businesses").doc(item.businessId).get()).data();
  assert.deepEqual(after.sectorData.pet_taxi, before.sectorData.pet_taxi);
  assert.equal(after.published, before.published);
});

test("missing client request ID is rejected before booking creation", async () => {
  const item = fixture();
  await seed(item);
  await assert.rejects(
    call(item, item.customerUid, payload(item, "")),
    (error) => error.code === "invalid-argument"
  );
  assert.equal((await bookingsFor(item)).size, 0);
});
