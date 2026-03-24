const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const { computeRevenueMetrics } = require("./computeRevenueMetrics");
const { writeRevenueMetrics } = require("./writeRevenueMetrics");

exports.onSubscriptionChanged = onDocumentWritten(
    {
        document: "subscriptions/{id}",
        region: "europe-west3",
    },
    async (event) => {
        const db = admin.firestore();

        try {
            console.log("💳 Subscription changed → recomputing revenue metrics");

            const metrics = await computeRevenueMetrics(db);
            await writeRevenueMetrics(db, metrics);

            console.log("✅ Revenue metrics updated from subscription change");
        } catch (e) {
            console.error("❌ onSubscriptionChanged failed", e);
        }
    }
);