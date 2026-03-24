const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

if (!admin.apps.length) {
    admin.initializeApp();
}

const db = admin.firestore();

/* =========================================
   PLATFORM METRICS UPDATE
========================================= */

exports.updatePlatformMetrics = onSchedule(
    {
        region: "europe-west3",
        schedule: "every 5 minutes",
        timeZone: "Europe/Istanbul"
    },
    async () => {

        console.log("📊 Updating BarkyMatches platform metrics...");

        const now = new Date();

        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);

        const last24h = new Date(
            now.getTime() - 24 * 60 * 60 * 1000
        );

        try {

            // USERS
            const usersSnap =
                await db.collection("users").get();

            const activeUsersSnap =
                await db.collection("users")
                    .where("lastActiveAt", ">", last24h)
                    .get();

            // DOGS
            const dogsSnap =
                await db.collection("dogs").get();

            // BUSINESSES
            const businessesSnap =
                await db.collection("businesses")
                    .where("status", "==", "approved")
                    .get();

            // REPORTS TODAY
            const reportsTodaySnap =
                await db.collection("reports")
            admin.firestore.Timestamp.fromDate(todayStart)


            // OPEN REPORTS
            const reportsOpenSnap =
                await db.collection("reports")
                    .where("status", "==", "open")
                    .get();

            // COMPLAINTS OPEN
            const complaintsSnap =
                await db.collection("complaints")
                    .where("status", "==", "open")
                    .get();

            // PLAYDATES TODAY
            const playdatesSnap =
                await db.collection("playDates")
                    .where("scheduledAt", ">", todayStart)
                    .get();

            const metrics = {

                totalUsers: usersSnap?.size ?? 0,

                activeUsers24h: activeUsersSnap?.size ?? 0,

                dogsRegistered: dogsSnap?.size ?? 0,

                businessesApproved: businessesSnap?.size ?? 0,

                reportsToday: reportsTodaySnap?.size ?? 0,

                reportsOpen: reportsOpenSnap?.size ?? 0,

                complaintsOpen: complaintsSnap?.size ?? 0,

                playDatesToday: playdatesSnap?.size ?? 0,

                updatedAt:
                    admin.firestore.FieldValue.serverTimestamp()
            };

            await db.collection("admin_stats")
                .doc("metrics")
                .set(metrics, { merge: true });

            console.log("✅ Metrics updated:", metrics);

        } catch (error) {

            console.error("❌ Metrics update failed", error);

        }

    }
);