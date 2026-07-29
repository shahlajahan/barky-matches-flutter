const { HttpsError } = require("firebase-functions/v2/https");

/**
 * Verifies the caller is authenticated AND has role "admin" on their user
 * doc. Every moderation-affecting callable (report review, restore,
 * reactivate, business suspend/restore) must go through this - never trust
 * request.auth alone.
 */
async function requireAdmin(db, request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login required");
  }

  const adminUid = request.auth.uid;
  const adminDoc = await db.collection("users").doc(adminUid).get();

  if (!adminDoc.exists || adminDoc.data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "Admin only");
  }

  return adminUid;
}

module.exports = { requireAdmin };
