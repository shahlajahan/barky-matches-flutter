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

    const rules = Object.values(category.rules);

    const rule = rules.find((r) => {
        const c = r.conditions;

        return (
            discountPercent >= c.discountFrom &&
            discountPercent <= c.discountTo
        );
    });

    if (!rule) {
        throw new Error(
            `No commission rule found for ${productCategory}`
        );
    }

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
    });
}

module.exports = {
    calculate,
};