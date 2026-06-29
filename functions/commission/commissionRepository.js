const admin = require("firebase-admin");



async function getCommissionConfig(sector) {

    const db = admin.firestore();

    const doc = await db
        .collection("commission_configs")
        .doc(sector)
        .get();

    if (!doc.exists) {
        throw new Error(
            `Commission config not found for sector: ${sector}`
        );
    }

    const config = doc.data();

    if (config.sector !== sector) {
        throw new Error(
            `Commission config sector mismatch: expected "${sector}", found "${config.sector}".`
        );
    }

    if (config.version !== 1) {
        throw new Error(
            `Unsupported commission config version: ${config.version}`
        );
    }

    return config;
}

module.exports = {
    getCommissionConfig,
};