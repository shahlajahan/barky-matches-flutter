/*
 * Safe, dry-run-by-default financial snapshot backfill.
 *
 * Examples:
 *   node scripts/backfillFinancialSnapshots.js --sector=vet --record-id=abc
 *   node scripts/backfillFinancialSnapshots.js --sector=groomy --business-id=xyz --apply
 *
 * This tool never overwrites an existing financial object and never processes
 * refunded records. Veterinary records require an explicit persisted category
 * (or a category on the referenced service document), so surgery is never
 * inferred from a title.
 */
const admin = require("firebase-admin");
const {
    calculateAppointmentFinancial,
    hasCompleteFinancial,
    positiveNumber,
} = require("../commission/paymentFinancialSnapshot");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const args = Object.fromEntries(
    process.argv.slice(2).map((arg) => {
        const [key, ...rest] = arg.replace(/^--/, "").split("=");
        return [key, rest.length ? rest.join("=") : true];
    }),
);
const sector = String(args.sector || "").trim().toLowerCase();
const apply = args.apply === true;
const recordId = typeof args["record-id"] === "string" ? args["record-id"].trim() : "";
const businessId = typeof args["business-id"] === "string" ? args["business-id"].trim() : "";

const collections = {
    vet: "vet_appointments",
    groomy: "groomy_appointments",
    hotel: "hotel_bookings",
    taxi: "pet_taxi_bookings",
    petshop: "sellerOrders",
};

function normalized(value) {
    return String(value || "").trim().toLowerCase();
}

async function loadCandidates(collectionName) {
    if (recordId) {
        const doc = await db.collection(collectionName).doc(recordId).get();
        return doc.exists ? [doc] : [];
    }
    if (!businessId) {
        throw new Error("Provide --record-id or --business-id; broad collection backfills are refused.");
    }
    const field = sector === "petshop" ? "shopId" : "businessId";
    return (await db.collection(collectionName).where(field, "==", businessId).get()).docs;
}

async function resolveVetCategory(data) {
    const persisted = normalized(data.serviceCategory || data.category);
    if (persisted) return persisted === "surgery" ? "surgery" : "default";
    if (!data.businessId || !data.serviceId) return null;
    const service = await db.collection("businesses").doc(String(data.businessId))
        .collection("services").doc(String(data.serviceId)).get();
    if (!service.exists) return null;
    const category = normalized(service.data()?.serviceCategory || service.data()?.category);
    return category ? (category === "surgery" ? "surgery" : "default") : null;
}

function normalizePetshopLegacyFinancial(data) {
    const legacy = data.financial;
    if (!legacy || typeof legacy !== "object") return null;
    const finalPrice = positiveNumber(legacy.grossAmount);
    const commissionAmount = Number(legacy.commissionAmount);
    const businessNetAmount = Number(legacy.sellerNetAmount);
    if (!finalPrice || !Number.isFinite(commissionAmount) || !Number.isFinite(businessNetAmount)) {
        return null;
    }
    return {
        version: 1,
        sector: "petshop",
        finalPrice,
        commissionType: "legacy_verified_snapshot",
        commissionRate: null,
        commissionAmount,
        businessNetAmount,
        platformRevenue: commissionAmount,
        businessReceivable: businessNetAmount,
        ruleSnapshot: { source: "persisted_legacy_financial", recalculated: false },
        payoutStatus: data.payout?.status || "pending",
        calculatedAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        settlement: {
            status: data.payout?.status || "pending",
            eligibleAt: data.payout?.readyAt || null,
            scheduledPayoutDate: null,
            processingAt: null,
            paidAt: data.payout?.paidAt || null,
            bankReference: data.payout?.reference || null,
            attempts: 0,
            lastError: null,
        },
    };
}

async function main() {
    const collectionName = collections[sector];
    if (!collectionName) throw new Error(`Unsupported --sector. Use: ${Object.keys(collections).join(", ")}`);
    const docs = await loadCandidates(collectionName);
    const result = { scanned: docs.length, eligible: 0, written: 0, skipped: [] };

    for (const doc of docs) {
        const data = doc.data() || {};
        const paymentStatus = normalized(data.paymentStatus || data.payment?.status);
        const refundStatus = normalized(data.refundStatus);
        if (paymentStatus !== "paid" || refundStatus === "refunded" || paymentStatus === "refunded") {
            result.skipped.push({ id: doc.id, reason: "not_eligible_payment_state" });
            continue;
        }
        if (!data.paidAt) {
            result.skipped.push({ id: doc.id, reason: "missing_paid_at" });
            continue;
        }
        if (hasCompleteFinancial(data.financial)) {
            result.skipped.push({ id: doc.id, reason: "financial_already_complete" });
            continue;
        }

        let financial;
        if (sector === "petshop") {
            // A legacy Petshop financial object is already an immutable persisted
            // calculation. This tool reports it but will not replace it in place.
            financial = normalizePetshopLegacyFinancial(data);
            result.skipped.push({
                id: doc.id,
                reason: financial
                    ? "legacy_financial_present_not_overwritten"
                    : "insufficient_verified_financial_inputs",
            });
            continue;
        } else {
            const paidAmount = positiveNumber(
                data.paymentAmount,
                data.finalPrice,
                data.price,
                data.servicePrice,
            );
            const vetCategory = sector === "vet" ? await resolveVetCategory(data) : null;
            if (sector === "vet" && !vetCategory) {
                result.skipped.push({ id: doc.id, reason: "ambiguous_vet_service_category" });
                continue;
            }
            financial = paidAmount
                ? await calculateAppointmentFinancial({
                    collectionName,
                    record: data,
                    paidAmount,
                    resolvedVetServiceCategory: vetCategory,
                })
                : null;
        }
        if (!financial || !hasCompleteFinancial(financial)) {
            result.skipped.push({ id: doc.id, reason: "insufficient_verified_financial_inputs" });
            continue;
        }
        result.eligible++;
        if (apply) {
            await db.runTransaction(async (transaction) => {
                const fresh = await transaction.get(doc.ref);
                const freshData = fresh.data() || {};
                if (freshData.financial && Object.keys(freshData.financial).length > 0) {
                    throw new Error(`Refusing to overwrite financial snapshot on ${doc.id}`);
                }
                transaction.update(doc.ref, {
                    financial,
                    financialBackfill: {
                        version: 1,
                        appliedAt: admin.firestore.FieldValue.serverTimestamp(),
                        tool: "backfillFinancialSnapshots",
                    },
                });
            });
            result.written++;
        }
    }
    console.log(JSON.stringify({ mode: apply ? "apply" : "dry-run", sector, ...result }, null, 2));
}

main().then(() => process.exit(0)).catch((error) => {
    console.error(error);
    process.exit(1);
});
