const admin = require("firebase-admin");

async function computeRevenueMetrics(db) {
  const now = new Date();

  const monthStart = new Date(
    now.getFullYear(),
    now.getMonth(),
    1
  );

  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  const expiringThreshold = new Date();
  expiringThreshold.setDate(expiringThreshold.getDate() + 7);

  let premiumUsers = 0;
  let businessSubscriptions = 0;
  let activeSubscriptions = 0;

  let monthlyRevenue = 0;
  let totalRevenue = 0;

  let newSubscriptionsToday = 0;
  let expiringSoon = 0;

  let canceledSubscriptions = 0;
  let expiredSubscriptions = 0;

  const subsSnap = await db.collection("subscriptions").get();

  subsSnap.forEach((doc) => {
    const s = doc.data();

    const plan = s.plan || "";
    const status = s.status || "";
    const price = Number(s.price || 0);

    const startedAt = s.startedAt?.toDate
      ? s.startedAt.toDate()
      : s.startedAt
        ? new Date(s.startedAt)
        : null;

    const expiresAt = s.expiresAt?.toDate
      ? s.expiresAt.toDate()
      : s.expiresAt
        ? new Date(s.expiresAt)
        : null;

    if (status === "active") {
      activeSubscriptions += 1;

      if (plan === "premium") {
        premiumUsers += 1;
      }

      totalRevenue += price;

      if (startedAt && startedAt >= monthStart) {
        monthlyRevenue += price;
      }

      if (startedAt && startedAt >= todayStart) {
        newSubscriptionsToday += 1;
      }

      if (
        expiresAt &&
        expiresAt >= now &&
        expiresAt <= expiringThreshold
      ) {
        expiringSoon += 1;
      }
    }

    if (status === "canceled") {
      canceledSubscriptions += 1;
    }

    if (status === "expired") {
      expiredSubscriptions += 1;
    }
  });

  const businessesSnap = await db
    .collection("businesses")
    .where("status", "==", "approved")
    .get();

  businessSubscriptions = businessesSnap.size;

  const arpu = activeSubscriptions > 0
    ? Number((totalRevenue / activeSubscriptions).toFixed(2))
    : 0;

  return {
    premiumUsers,
    businessSubscriptions,
    activeSubscriptions,

    monthlyRevenue: Number(monthlyRevenue.toFixed(2)),
    totalRevenue: Number(totalRevenue.toFixed(2)),
    newSubscriptionsToday,
    expiringSoon,
    arpu,

    canceledSubscriptions,
    expiredSubscriptions,

    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastReconciledAt: admin.firestore.FieldValue.serverTimestamp(),
    version: 1,
  };
}

module.exports = { computeRevenueMetrics };