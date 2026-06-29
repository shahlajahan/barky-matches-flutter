const {
    buildFinancial,
} = require("../financialObject");

const {
    COMMISSION_TYPES,
} = require("../commissionTypes");

const {
    calculatePercentageCommission,
    calculateBusinessNet,
} = require("../commissionCalculator");

function calculate({
    config,
    finalPrice,
}) {
    if (
        typeof finalPrice !== "number" ||
        Number.isNaN(finalPrice) ||
        finalPrice <= 0
    ) {
        throw new Error("Invalid final price.");
    }

    const entries = Object.entries(config.rules);

    if (entries.length === 0) {
        throw new Error("No taxi commission rules found.");
    }

    const [ruleId, rule] = entries[0];

    if (rule.type !== COMMISSION_TYPES.PERCENTAGE) {
        throw new Error(
            `Unsupported taxi commission type: ${rule.type}`
        );
    }

    const commissionAmount =
        calculatePercentageCommission(
            finalPrice,
            rule.commissionRate
        );

    const businessNetAmount =
        calculateBusinessNet(
            finalPrice,
            commissionAmount
        );

    return buildFinancial({
        sector: "taxi",

        finalPrice,
        sellerPrice: finalPrice,

        commissionType: rule.type,
        commissionRate: rule.commissionRate,

        commissionAmount,
        businessNetAmount,

        ruleSnapshot: {
            configVersion: config.version,
            ruleId,
            commissionType: rule.type,
            commissionRate: rule.commissionRate,
        },
    });
}

module.exports = {
    calculate,
};