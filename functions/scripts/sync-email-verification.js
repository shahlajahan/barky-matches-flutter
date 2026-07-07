const admin = require("firebase-admin");

admin.initializeApp({
    projectId: "barkymatches-new",
});

const db = admin.firestore();

(async () => {
    const snapshot = await db.collection("users").get();

    let scanned = 0;
    let updated = 0;
    let alreadyVerified = 0;
    let skipped = 0;
    let notFound = 0;

    for (const doc of snapshot.docs) {
        scanned++;

        const uid = doc.id;
        const data = doc.data();

        if (data.emailVerified !== true) {
            skipped++;
            continue;
        }

        try {
            const user = await admin.auth().getUser(uid);

            if (user.emailVerified) {
                alreadyVerified++;
                console.log(`✅ Already verified: ${user.email}`);
                continue;
            }

            await admin.auth().updateUser(uid, {
                emailVerified: true,
            });

            updated++;

            console.log(`🔥 Fixed: ${user.email}`);

        } catch (e) {
            if (e.code === "auth/user-not-found") {
                notFound++;
                console.log(`❌ Auth user not found: ${uid}`);
            } else {
                console.error(uid, e);
            }
        }
    }

    console.log("");
    console.log("========== DONE ==========");
    console.log("Scanned:", scanned);
    console.log("Updated:", updated);
    console.log("Already verified:", alreadyVerified);
    console.log("Skipped:", skipped);
    console.log("Not found:", notFound);
})();