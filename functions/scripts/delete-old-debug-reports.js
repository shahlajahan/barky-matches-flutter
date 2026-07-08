const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

async function deleteOldDebugReports() {
    const now = new Date();

    // YYYY-MM-DD
    const today =
        now.getFullYear() +
        "-" +
        String(now.getMonth() + 1).padStart(2, "0") +
        "-" +
        String(now.getDate()).padStart(2, "0");

    console.log(`Keeping reports from: ${today}`);
    console.log("Loading documents...");

    const snapshot = await db.collection("debug_reports").get();

    let deleted = 0;
    let kept = 0;

    let batch = db.batch();
    let batchCount = 0;

    for (const doc of snapshot.docs) {
        const createdAt = doc.get("clientReport.createdAt");

        const keep =
            typeof createdAt === "string" &&
            createdAt.startsWith(today);

        if (keep) {
            kept++;
            continue;
        }

        batch.delete(doc.ref);
        deleted++;
        batchCount++;

        if (batchCount === 500) {
            await batch.commit();

            console.log(`Deleted ${deleted}...`);

            batch = db.batch();
            batchCount = 0;
        }
    }

    if (batchCount > 0) {
        await batch.commit();
    }

    console.log("--------------------------------");
    console.log(`Deleted : ${deleted}`);
    console.log(`Kept    : ${kept}`);
    console.log("Finished.");
}

deleteOldDebugReports()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });