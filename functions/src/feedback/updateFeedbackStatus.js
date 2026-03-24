const functions = require("firebase-functions");
const admin = require("firebase-admin");

const db = admin.firestore();

exports.updateFeedbackStatus = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be logged in"
        );
    }

    const feedbackId = data.feedbackId;
    const status = data.status;

    if (!feedbackId || !status) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "feedbackId and status are required"
        );
    }

    const allowedStatuses = ["new", "reviewing", "resolved", "closed"];

    if (!allowedStatuses.includes(status)) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Invalid status"
        );
    }

    await db.collection("user_feedback").doc(feedbackId).update({
        status: status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
});