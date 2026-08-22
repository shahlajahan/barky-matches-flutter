const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");

const {
  cleanupAppointmentDataForDeletedAccount,
} = require("../business/appointmentDeletionCleanup");

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || "";
const hasLocalFirestoreEmulator =
  /^(127\.0\.0\.1|localhost):\d+$/.test(emulatorHost);

class FakeDoc {
  constructor(id, value, ref) {
    this.id = id;
    this._value = value;
    this.ref = ref;
  }

  data() {
    return this._value;
  }
}

class FakeDocRef {
  constructor(store, collection, id) {
    this._store = store;
    this.collection = collection;
    this.id = id;
  }
}

class FakeQuery {
  constructor(store, collection, field, value, options) {
    this._store = store;
    this._collection = collection;
    this._field = field;
    this._value = value;
    this._options = options;
  }

  async get() {
    const failingQuery = this._options.failQueries?.find((failure) =>
      failure.collection === this._collection &&
      failure.field === this._field &&
      failure.value === this._value
    );
    if (failingQuery) {
      throw new Error(failingQuery.message || "Injected query failure");
    }

    const entries = Object.entries(this._store[this._collection] || {});
    const docs = entries
      .filter(([, value]) => value[this._field] === this._value)
      .map(([id, value]) => new FakeDoc(
        id,
        value,
        new FakeDocRef(this._store, this._collection, id),
      ));
    return {docs};
  }
}

class FakeCollection {
  constructor(store, collection, options) {
    this._store = store;
    this._collection = collection;
    this._options = options;
  }

  where(field, op, value) {
    assert.equal(op, "==");
    return new FakeQuery(
      this._store,
      this._collection,
      field,
      value,
      this._options,
    );
  }

  doc(id) {
    return new FakeDocRef(this._store, this._collection, id);
  }
}

class FakeBatch {
  constructor(store, stats, options) {
    this._store = store;
    this._stats = stats;
    this._options = options;
    this._deletes = [];
  }

  delete(ref) {
    this._deletes.push(ref);
  }

  async commit() {
    this._stats.batchCommits += 1;
    if (this._options.failCommitNumber === this._stats.batchCommits) {
      throw new Error("Injected batch failure");
    }
    this._stats.largestBatch = Math.max(
      this._stats.largestBatch,
      this._deletes.length,
    );
    for (const ref of this._deletes) {
      delete this._store[ref.collection][ref.id];
    }
  }
}

function fakeDb(seed, options = {}) {
  const stats = {batchCommits: 0, largestBatch: 0};
  return {
    stats,
    store: structuredClone(seed),
    collection(name) {
      this.store[name] ||= {};
      return new FakeCollection(this.store, name, options);
    },
    batch() {
      return new FakeBatch(this.store, stats, options);
    },
  };
}

function baseSeed() {
  return {
    vet_appointments: {
      vet_user: {userId: "delete-me"},
      vet_duplicate: {userId: "delete-me", requesterUserId: "delete-me"},
      vet_requester: {requesterUserId: "delete-me"},
      vet_owner: {ownerId: "delete-me"},
      vet_pet_owner: {petOwnerUid: "delete-me"},
      vet_business: {businessId: "business-owned"},
      vet_business_owner: {businessOwnerUid: "business-owned"},
      vet_other: {userId: "keep-me"},
    },
    groomy_appointments: {
      groomy_user: {userId: "delete-me"},
      groomy_buyer: {buyerUid: "delete-me"},
      groomy_business: {businessId: "business-owned"},
      groomy_named_business: {groomyId: "business-owned"},
      groomy_other: {userId: "keep-me"},
    },
    hotel_bookings: {
      hotel_user: {userId: "delete-me"},
      hotel_buyer: {buyerUid: "delete-me"},
      hotel_business: {businessId: "business-owned"},
      hotel_named_business: {hotelId: "business-owned"},
      hotel_other: {userId: "keep-me"},
    },
    pet_taxi_bookings: {
      taxi_user: {userId: "delete-me"},
      taxi_business: {businessId: "business-owned"},
      taxi_other: {userId: "keep-me"},
    },
    notifications: {
      n_user: {type: "other", userId: "delete-me"},
      n_target: {type: "other", targetUserId: "delete-me"},
      n_from: {type: "other", fromUserId: "delete-me"},
      n_recipient: {type: "other", recipientUserId: "delete-me"},
      n_sender: {type: "other", senderUserId: "delete-me"},
      n_vet: {type: "vet_appointment_response", appointmentId: "vet_user"},
      n_groomy: {
        type: "groomy_appointment_response",
        appointmentId: "groomy_buyer",
      },
      n_hotel_appointment: {
        type: "hotel_booking_response",
        appointmentId: "hotel_user",
      },
      n_hotel_booking: {
        type: "hotel_booking_response",
        bookingId: "hotel_buyer",
      },
      n_taxi: {
        type: "pet_taxi_status_update",
        bookingId: "taxi_user",
      },
      n_taxi_legacy_appointment: {
        type: "pet_taxi_status_update",
        appointmentId: "taxi_business",
      },
      n_paid_by_explicit_collection: {
        type: "appointment_paid",
        appointmentId: "groomy_user",
        appointmentCollection: "groomy_appointments",
      },
      n_unrelated_ref: {
        type: "other",
        appointmentId: "vet_user",
      },
      n_other_user: {
        type: "vet_appointment_response",
        appointmentId: "vet_other",
      },
    },
  };
}

test("deleteUserAccount appointment cleanup removes four-family owned records and dependent notifications", async () => {
  const db = fakeDb(baseSeed());
  const logs = [];

  const result = await cleanupAppointmentDataForDeletedAccount({
    db,
    uid: "delete-me",
    businessIds: ["business-owned"],
    logger: {info: (message, data) => logs.push({message, data})},
  });

  assert.deepEqual(Object.keys(db.store.vet_appointments), ["vet_other"]);
  assert.deepEqual(Object.keys(db.store.groomy_appointments), ["groomy_other"]);
  assert.deepEqual(Object.keys(db.store.hotel_bookings), ["hotel_other"]);
  assert.deepEqual(Object.keys(db.store.pet_taxi_bookings), ["taxi_other"]);
  assert.ok(db.store.notifications.n_unrelated_ref);
  assert.ok(db.store.notifications.n_other_user);
  assert.equal(db.store.notifications.n_vet, undefined);
  assert.equal(db.store.notifications.n_taxi, undefined);
  assert.equal(db.store.notifications.n_taxi_legacy_appointment, undefined);
  assert.equal(db.store.notifications.n_paid_by_explicit_collection, undefined);
  assert.equal(result.appointmentDeleteCounts.vet_appointments, 7);
  assert.equal(result.appointmentDeleteCounts.groomy_appointments, 4);
  assert.equal(result.appointmentDeleteCounts.hotel_bookings, 4);
  assert.equal(result.appointmentDeleteCounts.pet_taxi_bookings, 2);
  assert.equal(logs[0].message, "appointment_account_deletion_cleanup");
  assert.match(JSON.stringify(logs[0]), /appointmentDeleteCounts/);
  assert.doesNotMatch(JSON.stringify(logs[0]), /delete-me|vet_user|n_vet/);
});

test("deleteUserAccount appointment cleanup is idempotent", async () => {
  const db = fakeDb(baseSeed());

  await cleanupAppointmentDataForDeletedAccount({db, uid: "delete-me"});
  const second = await cleanupAppointmentDataForDeletedAccount({
    db,
    uid: "delete-me",
  });

  assert.equal(second.appointmentDeleteCounts.vet_appointments, 0);
  assert.equal(second.notificationDeleteCounts.accountReferences, 0);
  assert.equal(second.notificationDeleteCounts.appointmentReferences, 0);
});

test("deleteUserAccount appointment cleanup handles exact batch boundaries", async () => {
  const seed = {
    vet_appointments: {},
    groomy_appointments: {},
    hotel_bookings: {},
    pet_taxi_bookings: {},
    notifications: {},
  };
  for (let index = 0; index < 450; index += 1) {
    seed.notifications[`n_${index}`] = {recipientUserId: "delete-me"};
  }
  const db = fakeDb(seed);

  const result = await cleanupAppointmentDataForDeletedAccount({
    db,
    uid: "delete-me",
  });

  assert.equal(result.notificationDeleteCounts.accountReferences, 450);
  assert.equal(Object.keys(db.store.notifications).length, 0);
  assert.equal(db.stats.batchCommits, 1);
  assert.ok(db.stats.largestBatch <= 450);
});

test("deleteUserAccount appointment cleanup supports more than 500 matched records", async () => {
  const seed = {
    vet_appointments: {},
    groomy_appointments: {},
    hotel_bookings: {},
    pet_taxi_bookings: {},
    notifications: {},
  };
  for (let index = 0; index < 901; index += 1) {
    seed.notifications[`n_${index}`] = {recipientUserId: "delete-me"};
  }
  const db = fakeDb(seed);

  const result = await cleanupAppointmentDataForDeletedAccount({
    db,
    uid: "delete-me",
  });

  assert.equal(result.notificationDeleteCounts.accountReferences, 901);
  assert.equal(Object.keys(db.store.notifications).length, 0);
  assert.equal(db.stats.batchCommits, 3);
  assert.ok(db.stats.largestBatch <= 450);
});

test("deleteUserAccount appointment cleanup surfaces query failures", async () => {
  const db = fakeDb(baseSeed(), {
    failQueries: [
      {
        collection: "vet_appointments",
        field: "userId",
        value: "delete-me",
        message: "local query failed",
      },
    ],
  });

  await assert.rejects(
    cleanupAppointmentDataForDeletedAccount({db, uid: "delete-me"}),
    /local query failed/,
  );
  assert.ok(db.store.vet_appointments.vet_user);
});

test("deleteUserAccount appointment cleanup surfaces partial write failures", async () => {
  const seed = {
    vet_appointments: {},
    groomy_appointments: {},
    hotel_bookings: {},
    pet_taxi_bookings: {},
    notifications: {},
  };
  for (let index = 0; index < 451; index += 1) {
    seed.notifications[`n_${index}`] = {recipientUserId: "delete-me"};
  }
  const db = fakeDb(seed, {failCommitNumber: 1});

  await assert.rejects(
    cleanupAppointmentDataForDeletedAccount({db, uid: "delete-me"}),
    /Injected batch failure/,
  );
  assert.equal(Object.keys(db.store.notifications).length, 451);
});

test(
  "deleteUserAccount appointment cleanup works against local Firestore emulator",
  {skip: !hasLocalFirestoreEmulator},
  async () => {
    assert.match(
      emulatorHost,
      /^(127\.0\.0\.1|localhost):\d+$/,
      "appointment cleanup integration requires a loopback Firestore emulator",
    );

    const admin = require("firebase-admin");
    if (!admin.apps.length) {
      admin.initializeApp({
        projectId: process.env.GCLOUD_PROJECT || "demo-petsupo",
      });
    }
    const realDb = admin.firestore();
    const runId = `appointment-cleanup-${Date.now()}-${process.pid}-${crypto
      .randomBytes(4)
      .toString("hex")}`;
    const uid = `${runId}-user`;
    const businessId = `${runId}-business`;
    const documents = [
      ["vet_appointments", `${runId}-vet`, {userId: uid}],
      ["groomy_appointments", `${runId}-groomy`, {buyerUid: uid}],
      ["hotel_bookings", `${runId}-hotel`, {hotelId: businessId}],
      ["pet_taxi_bookings", `${runId}-taxi`, {businessId}],
      ["notifications", `${runId}-n-account`, {recipientUserId: uid}],
      [
        "notifications",
        `${runId}-n-vet`,
        {type: "vet_appointment_response", appointmentId: `${runId}-vet`},
      ],
      [
        "notifications",
        `${runId}-n-hotel`,
        {
          type: "hotel_booking_response",
          appointmentId: `${runId}-hotel`,
          bookingId: `${runId}-hotel`,
        },
      ],
      [
        "notifications",
        `${runId}-n-keep`,
        {type: "vet_appointment_response", appointmentId: `${runId}-other`},
      ],
    ];

    await Promise.all(
      documents.map(([collection, id, data]) =>
        realDb.collection(collection).doc(id).set(data),
      ),
    );

    const result = await cleanupAppointmentDataForDeletedAccount({
      db: realDb,
      uid,
      businessIds: [businessId],
      logger: {info: () => {}},
    });

    assert.equal(result.appointmentDeleteCounts.vet_appointments, 1);
    assert.equal(result.appointmentDeleteCounts.groomy_appointments, 1);
    assert.equal(result.appointmentDeleteCounts.hotel_bookings, 1);
    assert.equal(result.appointmentDeleteCounts.pet_taxi_bookings, 1);
    assert.equal(result.notificationDeleteCounts.accountReferences, 1);
    assert.equal(result.notificationDeleteCounts.appointmentReferences, 2);

    for (const [collection, id] of documents.slice(0, 7)) {
      const snap = await realDb.collection(collection).doc(id).get();
      assert.equal(snap.exists, false, `${collection}/${id} should be deleted`);
    }
    const keepSnap = await realDb
      .collection("notifications")
      .doc(`${runId}-n-keep`)
      .get();
    assert.equal(keepSnap.exists, true);
  },
);
