const APPOINTMENT_NOTIFICATION_TYPES = Object.freeze({
  vet_appointments: new Set([
    "vet_appointment_request",
    "vet_appointment_response",
    "appointment_cancelled_confirmation",
    "vet_appointment_refunded",
    "appointment_reminder",
    "appointment_paid",
    "vet_appointment_payment_expired",
  ]),
  groomy_appointments: new Set([
    "groomy_appointment_request",
    "groomy_appointment_response",
    "groomy_appointment_cancelled_by_user",
    "appointment_paid",
    "groomy_appointment_payment_expired",
  ]),
  hotel_bookings: new Set([
    "hotel_booking_request",
    "hotel_booking_response",
    "hotel_booking_cancelled_by_user",
    "hotel_booking_payment_expired",
  ]),
  pet_taxi_bookings: new Set([
    "pet_taxi_booking_request",
    "pet_taxi_price_proposed",
    "pet_taxi_payment_success",
    "pet_taxi_payment_completed",
    "pet_taxi_driver_on_the_way",
    "pet_taxi_driver_arrived",
    "pet_taxi_pet_picked_up",
    "pet_taxi_trip_started",
    "pet_taxi_trip_completed",
    "pet_taxi_booking_cancelled",
    "pet_taxi_status_update",
    "pet_taxi_booking_cancelled_by_user",
    "pet_taxi_booking_payment_expired",
  ]),
});

const APPOINTMENT_DELETION_CONTRACTS = Object.freeze([
  {
    family: "vet",
    collection: "vet_appointments",
    accountFields: ["userId", "requesterUserId", "ownerId", "petOwnerUid"],
    businessFields: ["businessId", "vetId", "businessOwnerUid"],
    referenceFields: ["appointmentId"],
  },
  {
    family: "groomy",
    collection: "groomy_appointments",
    accountFields: ["userId", "buyerUid"],
    businessFields: ["businessId", "groomyId"],
    referenceFields: ["appointmentId"],
  },
  {
    family: "hotel",
    collection: "hotel_bookings",
    accountFields: ["userId", "buyerUid"],
    businessFields: ["businessId", "hotelId"],
    referenceFields: ["appointmentId", "bookingId"],
  },
  {
    family: "pet_taxi",
    collection: "pet_taxi_bookings",
    accountFields: ["userId"],
    businessFields: ["businessId"],
    referenceFields: ["appointmentId", "bookingId"],
  },
]);

const ACCOUNT_NOTIFICATION_FIELDS = Object.freeze([
  "userId",
  "targetUserId",
  "fromUserId",
  "recipientUserId",
  "senderUserId",
]);

function uniqueNonEmpty(values) {
  return [...new Set(
    values
      .map((value) => String(value || "").trim())
      .filter(Boolean)
  )];
}

function isAppointmentNotificationForCollection(type, collection) {
  const normalizedType = String(type || "").trim();
  const allowed = APPOINTMENT_NOTIFICATION_TYPES[collection];
  return Boolean(allowed && allowed.has(normalizedType));
}

async function collectIdsForQuery(query) {
  const snap = await query.get();
  return snap.docs.map((doc) => doc.id);
}

async function deleteDocumentsByIds(db, collection, ids) {
  const uniqueIds = uniqueNonEmpty(ids);
  let deleted = 0;

  for (let index = 0; index < uniqueIds.length; index += 450) {
    const batch = db.batch();
    const chunk = uniqueIds.slice(index, index + 450);
    for (const id of chunk) {
      batch.delete(db.collection(collection).doc(id));
    }
    if (chunk.length > 0) {
      await batch.commit();
      deleted += chunk.length;
    }
  }

  return deleted;
}

async function collectAppointmentIdsForAccount({
  db,
  uid,
  businessIds = [],
}) {
  const businessIdSet = new Set(uniqueNonEmpty(businessIds));
  const result = {};

  for (const contract of APPOINTMENT_DELETION_CONTRACTS) {
    const ids = [];
    for (const field of contract.accountFields) {
      ids.push(
        ...await collectIdsForQuery(
          db.collection(contract.collection).where(field, "==", uid)
        )
      );
    }

    for (const businessId of businessIdSet) {
      for (const field of contract.businessFields) {
        ids.push(
          ...await collectIdsForQuery(
            db.collection(contract.collection).where(field, "==", businessId)
          )
        );
      }
    }

    result[contract.collection] = uniqueNonEmpty(ids);
  }

  return result;
}

async function deleteNotificationsForAccount({ db, uid }) {
  const ids = [];
  for (const field of ACCOUNT_NOTIFICATION_FIELDS) {
    ids.push(
      ...await collectIdsForQuery(
        db.collection("notifications").where(field, "==", uid)
      )
    );
  }
  return deleteDocumentsByIds(db, "notifications", ids);
}

async function deleteNotificationsForAppointments({ db, appointmentIdsByCollection }) {
  const ids = [];

  for (const contract of APPOINTMENT_DELETION_CONTRACTS) {
    const appointmentIds = uniqueNonEmpty(
      appointmentIdsByCollection[contract.collection] || []
    );

    for (const appointmentId of appointmentIds) {
      for (const field of contract.referenceFields) {
        const snap = await db
          .collection("notifications")
          .where(field, "==", appointmentId)
          .get();

        for (const doc of snap.docs) {
          const data = doc.data() || {};
          if (isAppointmentNotificationForCollection(data.type, contract.collection)) {
            ids.push(doc.id);
          }
        }
      }
    }
  }

  return deleteDocumentsByIds(db, "notifications", ids);
}

async function cleanupAppointmentDataForDeletedAccount({
  db,
  uid,
  businessIds = [],
  logger = console,
  reason = "account_deletion",
}) {
  const appointmentIdsByCollection = await collectAppointmentIdsForAccount({
    db,
    uid,
    businessIds,
  });

  const appointmentDeleteCounts = {};
  for (const contract of APPOINTMENT_DELETION_CONTRACTS) {
    appointmentDeleteCounts[contract.collection] = await deleteDocumentsByIds(
      db,
      contract.collection,
      appointmentIdsByCollection[contract.collection] || []
    );
  }

  const accountNotificationDeletes = await deleteNotificationsForAccount({
    db,
    uid,
  });
  const appointmentNotificationDeletes =
    await deleteNotificationsForAppointments({
      db,
      appointmentIdsByCollection,
    });

  logger.info("appointment_account_deletion_cleanup", {
    operationType: "account_deletion",
    callerCategory: "authenticated_self",
    reason,
    appointmentDeleteCounts,
    notificationDeleteCounts: {
      accountReferences: accountNotificationDeletes,
      appointmentReferences: appointmentNotificationDeletes,
    },
    businessCount: uniqueNonEmpty(businessIds).length,
  });

  return {
    appointmentIdsByCollection,
    appointmentDeleteCounts,
    notificationDeleteCounts: {
      accountReferences: accountNotificationDeletes,
      appointmentReferences: appointmentNotificationDeletes,
    },
  };
}

module.exports = {
  ACCOUNT_NOTIFICATION_FIELDS,
  APPOINTMENT_DELETION_CONTRACTS,
  APPOINTMENT_NOTIFICATION_TYPES,
  cleanupAppointmentDataForDeletedAccount,
  collectAppointmentIdsForAccount,
  isAppointmentNotificationForCollection,
  uniqueNonEmpty,
};
