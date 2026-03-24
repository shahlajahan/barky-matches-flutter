const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

if (!admin.apps.length) {
    admin.initializeApp();
}

exports.expireSubscriptions = onSchedule(
    {
        schedule: "every 60 minutes",
        region: "europe-west3",
    },
    async () => {
        const db = admin.firestore();
        const now = admin.firestore.Timestamp.now();

        const snapshot = await db
            .collection("users")
            .where("subscription.status", "==", "active")
            .where("subscription.expiresAt", "<", now)
            .get();

        if (snapshot.empty) {
            console.log("No expired subscriptions found");
            return;
        }

        const batch = db.batch();

        snapshot.docs.forEach((doc) => {
            batch.update(doc.ref, {
                "subscription.status": "expired",
            });
        });

        await batch.commit();

        console.log(`Expired subscriptions updated: ${snapshot.size}`);
    }
);