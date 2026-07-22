const {
    buildFinancial,
} = require("../financialObject");

const {
    COMMISSION_TYPES,
} = require("../commissionTypes");

const {
    calculateDiscountPercent,
    calculatePercentageCommission,
    calculateBusinessNet,
} = require("../commissionCalculator");

function calculate({
    config,
    referencePrice,
    sellerPrice,
}) {
    if (
        typeof referencePrice !== "number" ||
        Number.isNaN(referencePrice) ||
        referencePrice <= 0
    ) {
        throw new Error("Invalid reference price.");
    }

    if (
        typeof sellerPrice !== "number" ||
        Number.isNaN(sellerPrice) ||
        sellerPrice <= 0
    ) {
        throw new Error("Invalid seller price.");
    }

    const discountPercent =
        calculateDiscountPercent(
            referencePrice,
            sellerPrice
        );

    const ruleEntry = Object.entries(config.rules).find(([, r]) => {
        const c = r.conditions;

        return (
            discountPercent >= c.discountFrom &&
            discountPercent <= c.discountTo
        );
    });

    if (!ruleEntry) {
        throw new Error(
            "No matching discount commission rule found."
        );
    }

    const [ruleId, rule] = ruleEntry;

    if (rule.type !== COMMISSION_TYPES.PERCENTAGE) {
        throw new Error(
            `Unsupported discount strategy type: ${rule.type}`
        );
    }

    const commissionAmount =
        calculatePercentageCommission(
            sellerPrice,
            rule.commissionRate
        );

    const businessNetAmount =
        calculateBusinessNet(
            sellerPrice,
            commissionAmount
        );

    return buildFinancial({
        sector: config.sector,

        referencePrice,

        sellerPrice,

        finalPrice: sellerPrice,

        discountPercent,

        commissionType: rule.type,

        commissionRate: rule.commissionRate,

        commissionAmount,

        businessNetAmount,

        ruleSnapshot: {
            configVersion: config.version,
            ruleId,
            commissionType: rule.type,
            commissionRate: rule.commissionRate,
            discountFrom: rule.conditions.discountFrom,
            discountTo: rule.conditions.discountTo,
        },
    });
}

module.exports = {
    calculate,
};
