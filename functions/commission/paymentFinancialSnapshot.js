const { calculateCommission } = require("./commissionEngine");
const {
    getPayoutSectorAdapterByCollection,
} = require("../payout/sectorAdapters");

const COMMISSION_CALCULATION_VERSION = "1";

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
    return getPayoutSectorAdapterByCollection(collectionName).sector;
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
        return buildCanonicalFinancialSnapshot({
            financial: await calculateCommission({ sector, finalPrice, serviceCategory }),
            currency: record.currency || "TRY",
            calculationInputs: {
                sector,
                category: serviceCategory,
                serviceType: record.serviceType || null,
                quantity: 1,
                unitPrice: finalPrice,
                discountAmount: 0,
                shippingAmount: 0,
                taxAmount: Number(record.taxAmount || 0),
            },
        });
    }

    if (sector === "taxi") {
        return buildCanonicalFinancialSnapshot({
            financial: await calculateCommission({ sector, finalPrice }),
            currency: record.finalPriceCurrency ||
                record.paymentCurrency ||
                record.currency ||
                "TRY",
            calculationInputs: {
                sector,
                serviceType: record.serviceType || null,
                quantity: 1,
                unitPrice: finalPrice,
                discountAmount: 0,
                shippingAmount: Number(record.shippingAmount || 0),
                taxAmount: Number(record.taxAmount || 0),
            },
        });
    }

    const referencePrice = positiveNumber(
        record.referencePrice,
        record.serviceReferencePrice,
        record.originalPrice,
        record.servicePrice,
        record.price,
        finalPrice,
    );
    return buildCanonicalFinancialSnapshot({
        financial: await calculateCommission({
            sector,
            referencePrice,
            sellerPrice: finalPrice,
        }),
        currency: record.currency || "TRY",
        calculationInputs: {
            sector,
            category: record.category || null,
            subcategory: record.subcategory || null,
            serviceType: record.serviceType || null,
            quantity: 1,
            unitPrice: finalPrice,
            discountAmount: Math.max(0, referencePrice - finalPrice),
            shippingAmount: Number(record.shippingAmount || 0),
            taxAmount: Number(record.taxAmount || 0),
        },
    });
}

function hasCompleteFinancial(financial) {
    if (!financial || typeof financial !== "object") return false;
    const hasFiniteValue = (key) =>
        Object.prototype.hasOwnProperty.call(financial, key) &&
        financial[key] !== null &&
        financial[key] !== undefined &&
        financial[key] !== "" &&
        Number.isFinite(Number(financial[key]));
    const hasCommissionBasis =
        (financial.commissionRate !== null &&
            financial.commissionRate !== undefined &&
            financial.commissionRate !== "" &&
            Number.isFinite(Number(financial.commissionRate)) &&
            Number(financial.commissionRate) >= 0) ||
        (financial.commissionFixedAmount !== null &&
            financial.commissionFixedAmount !== undefined &&
            financial.commissionFixedAmount !== "" &&
            Number.isFinite(Number(financial.commissionFixedAmount)) &&
            Number(financial.commissionFixedAmount) >= 0) ||
        financial.commissionModel === "zero" ||
        financial.commissionModel === "aggregate";
    return ["finalPrice", "commissionAmount", "businessNetAmount", "sellerNetAmount"].every(
        hasFiniteValue,
    ) && hasCommissionBasis && Boolean(
        financial.commissionRuleId &&
        financial.commissionRuleVersion &&
        financial.pricingRuleVersion &&
        financial.commissionCalculationVersion &&
        financial.currency
    );
}

function buildCanonicalFinancialSnapshot({
    financial,
    currency = "TRY",
    calculationInputs = {},
}) {
    const source = financial || {};
    const rule = source.ruleSnapshot || {};
    const commissionModel = source.commissionModel ||
        source.commissionType || rule.commissionType || null;
    const commissionRate = source.commissionRate ?? rule.commissionRate ?? null;
    const commissionFixedAmount = source.commissionFixedAmount ??
        rule.amount ?? null;
    const ruleId = source.commissionRuleId || rule.ruleId || null;
    const ruleVersion = source.commissionRuleVersion ||
        rule.configVersion || null;
    const pricingRuleVersion = source.pricingRuleVersion ||
        rule.pricingRuleVersion || rule.configVersion || null;
    const completeMetadata = Boolean(
        commissionModel && ruleId && ruleVersion && pricingRuleVersion &&
        (commissionRate !== null || commissionFixedAmount !== null ||
            commissionModel === "zero" || commissionModel === "aggregate")
    );
    const hasAmount = (value) =>
        value !== null && value !== undefined && value !== "" &&
        Number.isFinite(Number(value));
    const grossAmount = Number(source.grossAmount ?? source.finalPrice);
    const commissionAmount = Number(source.commissionAmount);
    const sellerNetAmount = Number(
        source.sellerNetAmount ?? source.businessNetAmount
    );
    const complete = completeMetadata &&
        hasAmount(source.grossAmount ?? source.finalPrice) &&
        hasAmount(source.commissionAmount) &&
        hasAmount(source.sellerNetAmount ?? source.businessNetAmount) &&
        Math.round(grossAmount * 100) ===
            Math.round((commissionAmount + sellerNetAmount) * 100);
    return {
        ...source,
        grossAmount,
        finalPrice: Number(source.finalPrice ?? grossAmount),
        commissionAmount,
        sellerNetAmount,
        businessNetAmount: sellerNetAmount,
        businessReceivable: sellerNetAmount,
        platformRevenue: commissionAmount,
        platformNet: commissionAmount,
        commissionModel,
        commissionRate,
        commissionFixedAmount,
        commissionRuleId: ruleId,
        commissionRuleVersion: String(ruleVersion),
        pricingRuleVersion: String(pricingRuleVersion),
        commissionSource: source.commissionSource || "server_commission_engine",
        commissionCalculationVersion: String(
            source.commissionCalculationVersion || COMMISSION_CALCULATION_VERSION
        ),
        commissionCalculatedAt: source.commissionCalculatedAt ||
            source.calculatedAt || new Date(),
        currency: String(source.currency || currency).toUpperCase(),
        calculationInputs: {
            ...calculationInputs,
            ...(source.calculationInputs || {}),
        },
        commissionDataQuality: complete ? "verified_snapshot" : "commission_unknown",
    };
}

function assertVerifiedCanonicalFinancial(financial) {
    if (!financial || financial.commissionDataQuality !== "verified_snapshot") {
        throw new Error("Canonical commission snapshot metadata is incomplete.");
    }
    return financial;
}

module.exports = {
    appointmentSector,
    calculateAppointmentFinancial,
    buildCanonicalFinancialSnapshot,
    assertVerifiedCanonicalFinancial,
    COMMISSION_CALCULATION_VERSION,
    hasCompleteFinancial,
    positiveNumber,
};
