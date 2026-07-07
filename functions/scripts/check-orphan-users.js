const admin = require("firebase-admin");

admin.initializeApp({
    projectId: "barkymatches-new",
});

const db = admin.firestore();

const ORPHANS = [
    "TudTGv7yozcH0nKDB9LeyhAmbBI2",
    "sMiYKbRghwQDNSG2TnwvkJmpcUa2",
];

const collections = [
    "dogs",
    "businesses",
    "business_requests",
    "vet_appointments",
    "groomy_appointments",
    "hotel_bookings",
    "pet_taxi_bookings",
    "playDateRequests",
    "playDates",
    "adoption_requests",
    "reviews",
    "notifications",
    "social_posts",
    "sellerOrders",
    "orders",
];

(async () => {
    for (const uid of ORPHANS) {
        console.log("\n================================");
        console.log("Checking:", uid);

        for (const col of collections) {
            const snap = await db.collection(col).get();

            for (const doc of snap.docs) {
                const data = JSON.stringify(doc.data());

                if (data.includes(uid)) {
                    console.log(`📌 ${col}/${doc.id}`);
                }
            }
        }
    }

    console.log("\nDone.");
})();