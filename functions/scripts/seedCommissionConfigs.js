const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

// Firebase Admin
admin.initializeApp();

const db = admin.firestore();

const CONFIG_DIR = path.join(
    __dirname,
    "../commission/configs"
);

async function seed() {
    const files = fs
        .readdirSync(CONFIG_DIR)
        .filter((file) => file.endsWith(".json"));

    console.log(
        `Found ${files.length} commission config(s)...`
    );

    for (const file of files) {
        const sector = path.basename(file, ".json");

        const config = JSON.parse(
            fs.readFileSync(
                path.join(CONFIG_DIR, file),
                "utf8"
            )
        );

        if (config.sector !== sector) {
            throw new Error(
                `Sector mismatch in ${file}. Expected "${sector}" but found "${config.sector}".`
            );
        }

        if (config.version !== 1) {
            throw new Error(
                `Unsupported config version in ${file}.`
            );
        }

        console.log(
            `Writing ${sector}:`,
            JSON.stringify(config, null, 2)
        );
        await db
            .collection("commission_configs")
            .doc(sector)
            .set(config);

        console.log(`✓ ${sector}`);
    }

    console.log("");
    console.log("Commission configs seeded successfully.");
}

seed()
    .then(() => process.exit())
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });