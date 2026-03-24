const admin = require("firebase-admin");
const axios = require("axios");

const serviceAccount = require("./serviceAccount.json");

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const GOOGLE_API_KEY = "AIzaSyCN_Y8FNV_XI7Ru4S4UKKckrBi7HkI-GcY";

const COLLECTIONS = [
    "businesses",
    "adoption_centers",
    "lost_dogs",
    "found_dogs",
];

const BATCH_SIZE = 5;
const DELAY = 200;

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function geocode(address) {
    try {
        const url =
            "https://maps.googleapis.com/maps/api/geocode/json?address=" +
            encodeURIComponent(address) +
            "&key=" +
            GOOGLE_API_KEY;

        const res = await axios.get(url);

        if (!res.data.results.length) {
            console.log("❌ No result for:", address);
            return null;
        }

        const loc = res.data.results[0].geometry.location;

        return {
            lat: loc.lat,
            lng: loc.lng,
        };
    } catch (e) {
        console.log("⚠️ Geocode error:", e.message);
        return null;
    }
}

function extractAddress(data) {
    return (
        data?.contact?.addressLine ||
        data?.contact?.address ||
        data?.address ||
        null
    );
}

async function processCollection(name) {
    console.log("\n📡 Processing:", name);

    const snap = await db.collection(name).get();

    let processed = 0;

    for (const doc of snap.docs) {
        const data = doc.data();

        if (data.location?.lat) continue;

        const address = extractAddress(data);

        if (!address) {
            console.log("⚠️ No address:", doc.id);
            continue;
        }

        const coords = await geocode(address);

        if (!coords) continue;

        await doc.ref.update({
            location: coords,
            locationMigratedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(
            "✅ Updated:",
            name,
            doc.id,
            coords.lat,
            coords.lng
        );

        processed++;

        await sleep(DELAY);

        if (processed % BATCH_SIZE === 0) {
            console.log("⏳ Batch pause...");
            await sleep(1000);
        }
    }

    console.log("🎯 Finished", name);
}

async function run() {
    for (const col of COLLECTIONS) {
        await processCollection(col);
    }

    console.log("\n🚀 Migration completed");
}

run();