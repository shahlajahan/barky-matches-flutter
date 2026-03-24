async function writeRevenueMetrics(db, metrics) {
    await db
        .collection("admin_stats")
        .doc("revenue")
        .set(metrics, { merge: true });
}

module.exports = { writeRevenueMetrics };