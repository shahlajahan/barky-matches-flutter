const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { computeRevenueMetrics } = require("./computeRevenueMetrics");
const { writeRevenueMetrics } = require("./writeRevenueMetrics");

exports.reconcileRevenueScheduled = onSchedule(
    {
        region: "europe-west3",
        schedule: "every 15 minutes",
        timeZone: "Europe/Istanbul",
    },
    async () => {
        const db = admin.firestore();

        try {
            console.log("🛠 Scheduled revenue reconciliation started");

            const metrics = await computeRevenueMetrics(db);
            await writeRevenueMetrics(db, metrics);

            console.log("✅ Scheduled revenue reconciliation finished");
        } catch (e) {
            console.error("❌ reconcileRevenueScheduled failed", e);
        }

        return null;
    }
);