const { calculateCommission } = require("./commissionEngine");

function positiveNumber(...values) {
    for (const value of values) {
        const parsed = typeof value === "string" ? Number(value.trim()) : Number(value);
        if (Number.isFinite(parsed) && parsed > 0) return parsed;
    }
    return null;
}

function normalized(value) {
    return String(value || "").trim().toLowerCase();
}

function appointmentSector(collectionName) {
    if (collectionName === "vet_appointments") return "vet";
    if (collectionName === "groomy_appointments") return "groomy";
    if (collectionName === "hotel_bookings") return "hotel";
    if (collectionName === "pet_taxi_bookings") return "taxi";
    throw new Error(`Unsupported paid-record collection: ${collectionName}`);
}

async function calculateAppointmentFinancial({
    collectionName,
    record,
    paidAmount,
    resolvedVetServiceCategory = null,
}) {
    const sector = appointmentSector(collectionName);
    const finalPrice = positiveNumber(paidAmount);
    if (!finalPrice) throw new Error("A verified positive paid amount is required.");

    if (sector === "vet") {
        const rawCategory = resolvedVetServiceCategory ?? record.serviceCategory ?? record.category;
        const serviceCategory = normalized(rawCategory) === "surgery" ? "surgery" : "default";
        return calculateCommission({ sector, finalPrice, serviceCategory });
    }

    if (sector === "taxi") {
        return calculateCommission({ sector, finalPrice });
    }

    const referencePrice = positiveNumber(
        record.referencePrice,
        record.serviceReferencePrice,
        record.originalPrice,
        record.servicePrice,
        record.price,
        finalPrice,
    );
    return calculateCommission({
        sector,
        referencePrice,
        sellerPrice: finalPrice,
    });
}

function hasCompleteFinancial(financial) {
    if (!financial || typeof financial !== "object") return false;
    return ["finalPrice", "commissionAmount", "businessNetAmount"].every(
        (key) => Number.isFinite(Number(financial[key])),
    );
}

module.exports = {
    appointmentSector,
    calculateAppointmentFinancial,
    hasCompleteFinancial,
    positiveNumber,
};
