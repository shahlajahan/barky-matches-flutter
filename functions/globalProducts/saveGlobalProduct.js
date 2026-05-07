// functions/globalProducts/saveGlobalProduct.js

const functions = require("firebase-functions");
const admin = require("firebase-admin");

const {
    normalizeProduct,
    smartMerge,
    computeQualityScore,
} = require("./helpers");

exports.saveGlobalProduct = functions.https.onCall(async (req, context) => {
    const { code, data } = req.data;

    if (!code) {
        throw new functions.https.HttpsError("invalid-argument", "barcode required");
    }

    const ref = admin.firestore()
        .collection("global_products")
        .doc(code);

    const snap = await ref.get();

    const now = admin.firestore.FieldValue.serverTimestamp();

    const clean = normalizeProduct(data);

    if (!snap.exists) {
        await ref.set({
            ...clean,
            createdAt: now,
            updatedAt: now,
            source: "auto",
            qualityScore: computeQualityScore(clean),
            contributors: [context.auth?.uid || "unknown"],
        });

        return { created: true };
    }

    const existing = snap.data();
    const merged = smartMerge(existing, clean);

    await ref.update({
        ...merged,
        updatedAt: now,
        qualityScore: computeQualityScore(merged),
        contributors: admin.firestore.FieldValue.arrayUnion(
            context.auth?.uid || "unknown"
        ),
    });

    return { updated: true };
});