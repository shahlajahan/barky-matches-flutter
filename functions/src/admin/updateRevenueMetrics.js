const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

const db = admin.firestore();

exports.updateRevenueMetrics = onSchedule(
    {
        region: "europe-west3",
        schedule: "every 5 minutes",
        timeZone: "Europe/Istanbul",
    },
    async () => {

        console.log("💰 Updating revenue metrics...");

        try {

            const now = new Date();

            const monthStart = new Date(
                now.getFullYear(),
                now.getMonth(),
                1
            );

            const todayStart = new Date();
            todayStart.setHours(0, 0, 0, 0);

            let premiumUsers = 0;
            let activeSubscriptions = 0;
            let monthlyRevenue = 0;
            let totalRevenue = 0;

            // PREMIUM SUBSCRIPTIONS
            const subsSnap = await db
                .collection("subscriptions")
                .where("status", "==", "active")
                .get();

            subsSnap.forEach(doc => {

                const s = doc.data();
                const price = s.price || 0;

                if (s.plan === "premium") {

                    premiumUsers++;
                    activeSubscriptions++;

                    totalRevenue += price;

                    if (s.startedAt) {

                        const started =
                            s.startedAt.toDate
                                ? s.startedAt.toDate()
                                : new Date(s.startedAt);

                        if (started >= monthStart) {
                            monthlyRevenue += price;
                        }

                    }

                }

            });

            // BUSINESS SUBSCRIPTIONS
            const businessSnap = await db
                .collection("businesses")
                .where("status", "==", "approved")
                .get();

            const businessSubs = businessSnap.size;

            // NEW SUBSCRIPTIONS TODAY
            const todaySubs = await db
                .collection("subscriptions")
                .where(
                    "startedAt",
                    ">",
                    admin.firestore.Timestamp.fromDate(todayStart)
                )
                .get();

            const metrics = {

                premiumUsers,
                businessSubscriptions: businessSubs,
                activeSubscriptions,

                monthlyRevenue,
                totalRevenue,

                newSubscriptionsToday: todaySubs.size,

                updatedAt:
                    admin.firestore.FieldValue.serverTimestamp()

            };

            await db.collection("admin_stats")
                .doc("revenue")
                .set(metrics, { merge: true });

            console.log("✅ Revenue metrics updated:", metrics);

        }
        catch (e) {

            console.error("❌ Revenue metrics failed", e);

        }

        return null;

    });