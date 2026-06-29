function calculateDiscountPercent(
    referencePrice,
    sellerPrice
) {
    if (
        !referencePrice ||
        referencePrice <= 0
    ) {
        return 0;
    }

    return Number(
        (
            ((referencePrice - sellerPrice) / referencePrice) *
            100
        ).toFixed(2)
    );
}

function calculatePercentageCommission(
    sellerPrice,
    commissionRate
) {
    return Number(
        (
            (sellerPrice * commissionRate) / 100
        ).toFixed(2)
    );
}

function calculateFixedCommission(amount) {
    return Number(amount);
}

function calculateBusinessNet(
    sellerPrice,
    commissionAmount
) {
    return Number(
        (
            sellerPrice - commissionAmount
        ).toFixed(2)
    );
}

function normalizeMoney(value) {
    return Number(
        Number(value || 0).toFixed(2)
    );
}
module.exports = {
    calculateDiscountPercent,
    calculatePercentageCommission,
    calculateFixedCommission,
    calculateBusinessNet,
    normalizeMoney,
};

