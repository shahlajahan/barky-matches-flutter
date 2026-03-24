// tools/seed/seed_locations_tr.js
/* eslint-disable no-console */
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

const MODE = process.env.MODE || "merge"; // "merge" | "overwrite"
const COUNTRY_CODE = "TR";

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!serviceAccountPath) {
    console.error("❌ Set GOOGLE_APPLICATION_CREDENTIALS to your service account json path");
    process.exit(1);
}

admin.initializeApp({
    credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

function readJson(relPath) {
    const p = path.join(__dirname, relPath);
    return JSON.parse(fs.readFileSync(p, "utf8"));
}

async function upsertDoc(ref, data) {
    if (MODE === "overwrite") {
        await ref.set(data, { merge: false });
    } else {
        await ref.set(data, { merge: true });
    }
}

async function seedCountries() {
    const countries = readJson("./data/countries.json"); // [{code,name,name_local,dial_code,enabled,sort}]
    console.log(`🌍 Seeding countries: ${countries.length}`);

    const batchSize = 400;
    let batch = db.batch();
    let count = 0;

    for (const c of countries) {
        const ref = db.collection("countries").doc(c.code);
        batch.set(
            ref,
            {
                ...c,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: MODE !== "overwrite" }
        );

        count++;
        if (count % batchSize === 0) {
            await batch.commit();
            batch = db.batch();
            console.log(`✅ countries committed: ${count}`);
        }
    }

    if (count % batchSize !== 0) {
        await batch.commit();
        console.log(`✅ countries committed final: ${count}`);
    }
}

async function seedTurkeyAdmin() {
    const data = readJson("./data/tr_provinces_districts.json");
    // expected:
    // {
    //   "admin1": [
    //     {"id":"IST","name":"Istanbul","name_local":"İstanbul","sort":34, "districts":[{"id":"BES","name":"Beşiktaş","name_local":"Beşiktaş","sort":1}, ...]}
    //   ]
    // }

    const countryRef = db.collection("countries").doc(COUNTRY_CODE);

    console.log(`🇹🇷 Seeding admin1/admin2 for ${COUNTRY_CODE} ...`);

    for (const p of data.admin1) {
        const admin1Ref = countryRef.collection("admin1").doc(p.id);

        await upsertDoc(admin1Ref, {
            id: p.id,
            name: p.name,
            name_local: p.name_local || p.name,
            country: COUNTRY_CODE,
            enabled: true,
            sort: p.sort ?? 9999,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        if (Array.isArray(p.districts) && p.districts.length) {
            // districts batch
            const chunks = [];
            const chunkSize = 400;
            for (let i = 0; i < p.districts.length; i += chunkSize) {
                chunks.push(p.districts.slice(i, i + chunkSize));
            }

            for (const ch of chunks) {
                const batch = db.batch();
                for (const d of ch) {
                    const admin2Ref = admin1Ref.collection("admin2").doc(d.id);
                    batch.set(
                        admin2Ref,
                        {
                            id: d.id,
                            name: d.name,
                            name_local: d.name_local || d.name,
                            enabled: true,
                            sort: d.sort ?? 9999,
                            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        },
                        { merge: MODE !== "overwrite" }
                    );
                }
                await batch.commit();
            }
            console.log(`✅ ${p.name} districts: ${p.districts.length}`);
        }
    }

    console.log("✅ TR admin seeded");
}

async function main() {
    try {
        await seedCountries();
        await seedTurkeyAdmin();
        console.log("🎉 DONE");
        process.exit(0);
    } catch (e) {
        console.error("❌ ERROR", e);
        process.exit(1);
    }
}

main();