const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const { computeRevenueMetrics } = require("./computeRevenueMetrics");
const { writeRevenueMetrics } = require("./writeRevenueMetrics");

exports.onBusinessChanged = onDocumentWritten(
    {
        document: "businesses/{id}",
        region: "europe-west3",
    },
    async (event) => {
        const db = admin.firestore();

        try {
            console.log("🏢 Business changed → recomputing revenue metrics");

            const metrics = await computeRevenueMetrics(db);
            await writeRevenueMetrics(db, metrics);

            console.log("✅ Revenue metrics updated from business change");
        } catch (e) {
            console.error("❌ onBusinessChanged failed", e);
        }
    }
);