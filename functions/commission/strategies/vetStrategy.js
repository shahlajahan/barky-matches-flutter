const {
    buildFinancial,
} = require("../financialObject");

const {
    COMMISSION_TYPES,
} = require("../commissionTypes");

const {
    calculatePercentageCommission,
    calculateFixedCommission,
    calculateBusinessNet,
} = require("../commissionCalculator");

function calculate({
    config,
    finalPrice,
    serviceCategory,
}) {
    if (
        typeof finalPrice !== "number" ||
        Number.isNaN(finalPrice) ||
        finalPrice <= 0
    ) {
        throw new Error("Invalid final price.");
    }

    if (!serviceCategory) {
        throw new Error("Service category is required.");
    }

    let rule = null;

    if (serviceCategory === "surgery") {
        rule = config.rules.surgery;
    } else {
        rule = config.rules.default;
    }

    if (!rule) {
        throw new Error(
            `No vet commission rule found for ${serviceCategory}`
        );
    }

    let commissionAmount = 0;

    switch (rule.type) {
        case COMMISSION_TYPES.PERCENTAGE:
            commissionAmount =
                calculatePercentageCommission(
                    finalPrice,
                    rule.commissionRate
                );
            break;

        case COMMISSION_TYPES.FIXED_PER_LEAD:
            commissionAmount =
                calculateFixedCommission(rule.amount);
            break;

        default:
            throw new Error(
                `Unsupported vet commission type: ${rule.type}`
            );
    }

    const businessNetAmount =
        calculateBusinessNet(
            finalPrice,
            commissionAmount
        );

    return buildFinancial({
        sector: config.sector,
        finalPrice,
        sellerPrice: finalPrice,
        commissionType: rule.type,
        commissionRate: rule.commissionRate ?? null,
        commissionAmount,
        businessNetAmount,
        ruleSnapshot: {
            configVersion: config.version,
            ruleId: serviceCategory === "surgery" ? "surgery" : "default",
            serviceCategory,
            commissionType: rule.type,
            commissionRate: rule.commissionRate ?? null,
            amount: rule.amount ?? null,
        },
    });
}

module.exports = {
    calculate,
};
