async function writeRevenueMetrics(db, metrics) {
  if (!metrics || metrics.schemaVersion !== 2) {
    throw new Error("Refusing to write non-v2 revenue metrics");
  }

  await db
    .collection("admin_stats")
    .doc("revenue_v2")
    .set(metrics);
}

module.exports = { writeRevenueMetrics };
