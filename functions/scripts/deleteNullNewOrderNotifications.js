const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function main() {
  const snap = await db
    .collection("notifications")
    .where("type", "==", "new_order")
    .where("orderId", "==", null)
    .get();

  console.log("🧹 NULL new_order notifications found:", snap.size);

  let batch = db.batch();
  let pending = 0;
  let deleted = 0;

  for (const doc of snap.docs) {
    console.log("🧹 DELETE notification", doc.id, doc.data());
    batch.delete(doc.ref);
    pending += 1;
    deleted += 1;

    if (pending === 450) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }

  if (pending > 0) {
    await batch.commit();
  }

  console.log("🧹 NULL new_order notifications deleted:", deleted);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("🧹 Cleanup failed", error);
    process.exit(1);
  });
