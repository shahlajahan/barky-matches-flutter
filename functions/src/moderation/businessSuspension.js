const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");

/**
 * Core suspend/restore transaction logic for businesses, extracted from the
 * original exports.suspendBusiness/restoreBusiness so the same, already-
 * correct behavior can be reused by the report-review "disable business"
 * moderation action instead of being duplicated.
 */

async function suspendBusinessCore(db, businessId, adminUid, reason) {
  const bizRef = db.collection("businesses").doc(String(businessId));

  await db.runTransaction(async (tx) => {
    const bizSnap = await tx.get(bizRef);
    if (!bizSnap.exists) throw new HttpsError("not-found", "Business not found");

    const bizData = bizSnap.data() || {};
    const prevStatus = bizData.status || "approved"; // fallback

    tx.set(
      bizRef,
      {
        status: "suspended",
        statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedBy: adminUid,
        suspension: {
          isActive: true,
          reason: reason || "Suspended by admin",
          suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
          suspendedBy: adminUid,
          prevStatus,
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(db.collection("admin_logs").doc(), {
      type: "business_suspend",
      businessId: String(businessId),
      by: adminUid,
      reason: reason || null,
      prevStatus,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(db.collection("business_suspensions").doc(), {
      businessId: String(businessId),
      reason: reason || "Suspended by admin",
      suspendedBy: adminUid,
      suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
      restoredAt: null,
      restoredBy: null,
      prevStatus,
      isActive: true,
    });
  });
}

async function restoreBusinessCore(db, businessId, adminUid) {
  const bizRef = db.collection("businesses").doc(String(businessId));

  await db.runTransaction(async (tx) => {
    const bizSnap = await tx.get(bizRef);
    if (!bizSnap.exists) throw new HttpsError("not-found", "Business not found");

    const bizData = bizSnap.data() || {};
    const prevStatus = bizData.suspension?.prevStatus || "approved";

    tx.set(
      bizRef,
      {
        status: prevStatus,
        statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedBy: adminUid,
        suspension: {
          ...(bizData.suspension || {}),
          isActive: false,
          restoredAt: admin.firestore.FieldValue.serverTimestamp(),
          restoredBy: adminUid,
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(db.collection("admin_logs").doc(), {
      type: "business_restore",
      businessId: String(businessId),
      by: adminUid,
      restoredTo: prevStatus,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

module.exports = { suspendBusinessCore, restoreBusinessCore };
