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
    productCategory,
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

    if (!productCategory) {
        throw new Error("Product category is required.");
    }

    const category = config.categories[productCategory];

    if (!category) {
        throw new Error(
            `Unknown product category: ${productCategory}`
        );
    }

    const discountPercent =
        calculateDiscountPercent(
            referencePrice,
            sellerPrice
        );

    const ruleEntry = Object.entries(category.rules).find(([, r]) => {
        const c = r.conditions;

        return (
            discountPercent >= c.discountFrom &&
            discountPercent <= c.discountTo
        );
    });

    if (!ruleEntry) {
        throw new Error(
            `No commission rule found for ${productCategory}`
        );
    }

    const [ruleId, rule] = ruleEntry;

    if (rule.type !== COMMISSION_TYPES.PERCENTAGE) {
        throw new Error(
            `Unsupported petshop commission type: ${rule.type}`
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
        sector: "petshop",

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
            productCategory,
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
