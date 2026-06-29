const {
    normalizeMoney,
} = require("./commissionCalculator");

function buildFinancial({
    sector,

    referencePrice = null,

    sellerPrice = null,

    finalPrice = null,

    discountPercent = null,

    commissionType,

    commissionRate = null,

    commissionAmount,

    businessNetAmount,

    ruleSnapshot = null,
}) {
    return {
        // Metadata
        // Metadata
        version: 1,
        sector,

        // Pricing
        referencePrice,
        sellerPrice,
        finalPrice,
        discountPercent,

        // Commission
        commissionType,
        commissionRate,

        commissionAmount:
            normalizeMoney(commissionAmount),

        // Financial Summary
        businessNetAmount:
            normalizeMoney(businessNetAmount),

        // Settlement aliases
        platformRevenue:
            normalizeMoney(commissionAmount),

        businessReceivable:
            normalizeMoney(businessNetAmount),

        // Rule used for this calculation
        ruleSnapshot,

        // Future settlement fields
        payoutStatus: "awaiting_invoice",
        payoutId: null,
        payoutAt: null,

        // Audit
        calculatedAt: new Date(),

        settlement: {
            status: "awaiting_invoice",
            eligibleAt: null,
            scheduledPayoutDate: null,
            processingAt: null,
            paidAt: null,
            bankReference: null,
            attempts: 0,
            lastError: null,
        },
    };
}

module.exports = {
    buildFinancial,
};