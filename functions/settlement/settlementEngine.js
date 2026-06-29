function isEligibleForSettlement({
    paymentStatus,
    serviceCompleted,
    invoiceStatus,
    settlementStatus,
    serviceCompletedAt,
}) {
    if (paymentStatus !== "paid") {
        return false;
    }

    if (!serviceCompleted) {
        return false;
    }

    if (invoiceStatus !== "approved") {
        return false;
    }

    if (
        settlementStatus === "paid" ||
        settlementStatus === "payment_processing" ||
        settlementStatus === "disputed"
    ) {
        return false;
    }

    if (!serviceCompletedAt) {
        return false;
    }

    const holdEnd = new Date(serviceCompletedAt);

    holdEnd.setDate(holdEnd.getDate() + 28);

    return holdEnd <= new Date();
}

module.exports = {
    isEligibleForSettlement,
};