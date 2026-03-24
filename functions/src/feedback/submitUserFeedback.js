const functions = require("firebase-functions");
const admin = require("firebase-admin");

const db = admin.firestore();

exports.submitUserFeedback = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be logged in"
        );
    }

    const uid = context.auth.uid;

    const rating = data.rating;
    const category = data.category;
    const message = data.message;
    const contextPage = data.context;
    const platform = data.platform;
    const appVersion = data.appVersion;

    if (rating < 1 || rating > 5) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Rating must be between 1 and 5"
        );
    }

    if (!message || message.length < 3) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Message is required"
        );
    }

    const today = new Date().toISOString().slice(0, 10);
    const rateLimitId = `${uid}_${today}`;

    const rateRef = db.collection("feedback_rate_limits").doc(rateLimitId);
    const rateDoc = await rateRef.get();

    if (rateDoc.exists) {
        const count = rateDoc.data()?.count ?? 0;

        if (count >= 5) {
            throw new functions.https.HttpsError(
                "resource-exhausted",
                "Daily feedback limit reached"
            );
        }

        await rateRef.update({
            count: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    } else {
        await rateRef.set({
            userId: uid,
            date: today,
            count: 1,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }

    const feedbackRef = db.collection("user_feedback").doc();

    await feedbackRef.set({
        userId: uid,
        rating: rating,
        category: category,
        message: message,
        context: contextPage,
        platform: platform,
        appVersion: appVersion,
        status: "new",
        priority: "normal",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const statsRef = db.collection("admin_stats").doc("user_satisfaction");

    await statsRef.set(
        {
            totalFeedback: admin.firestore.FieldValue.increment(1),
            feedbackToday: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
    );

    return { success: true };
});