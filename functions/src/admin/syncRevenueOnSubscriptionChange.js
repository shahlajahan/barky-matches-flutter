const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

exports.syncRevenueOnSubscriptionChange = onDocumentWritten(
    "subscriptions/{id}",
    async () => {

        const db = admin.firestore();

        const now = new Date();
        const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

        const snapshot = await db.collection("subscriptions").get();

        let premiumUsers = 0;
        let activeSubscriptions = 0;
        let monthlyRevenue = 0;
        let totalRevenue = 0;

        snapshot.forEach(doc => {

            const data = doc.data();
            const price = data.price || 0;

            if (data.plan === "premium") {

                totalRevenue += price;

                if (data.status === "active") {

                    premiumUsers++;
                    activeSubscriptions++;

                    monthlyRevenue += price;

                }

            }

        });

        // BUSINESS SUBSCRIPTIONS
        const businessSnap = await db
            .collection("businesses")
            .where("status", "==", "approved")
            .get();

        const businessSubs = businessSnap.size;

        const metrics = {

            premiumUsers,
            businessSubscriptions: businessSubs,
            activeSubscriptions,

            monthlyRevenue,
            totalRevenue,

            updatedAt: admin.firestore.FieldValue.serverTimestamp()

        };

        await db.collection("admin_stats")
            .doc("revenue")
            .set(metrics, { merge: true });

    }
);