const admin = require("firebase-admin");

exports.updatePlatformMetrics = async () => {

  const db = admin.firestore();

  console.log("📊 Updating platform metrics");

  const usersSnap = await db.collection("users").get();
  const dogsSnap = await db.collection("dogs").get();

  const today = new Date();
  today.setHours(0,0,0,0);

  const reportsSnap = await db.collection("reports")
      .where("createdAt", ">", today)
      .get();

  const complaintsSnap = await db.collection("complaints")
      .where("status", "==", "open")
      .get();

  const metrics = {

    totalUsers: usersSnap.size,

    dogsRegistered: dogsSnap.size,

    reportsToday: reportsSnap.size,

    complaintsOpen: complaintsSnap.size,

    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection("admin_stats")
      .doc("metrics")
      .set(metrics, { merge: true });

  console.log("✅ Metrics updated", metrics);
};