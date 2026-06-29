const SETTLEMENT_STATUS = {
    AWAITING_INVOICE: "awaiting_invoice",

    INVOICE_UPLOADED: "invoice_uploaded",

    INVOICE_REJECTED: "invoice_rejected",

    INVOICE_APPROVED: "invoice_approved",

    WAITING_HOLD_PERIOD: "waiting_hold_period",

    READY_FOR_PAYOUT: "ready_for_payout",

    PAYMENT_PROCESSING: "payment_processing",

    PAID: "paid",

    DISPUTED: "disputed",
};

module.exports = {
    SETTLEMENT_STATUS,
};