const {
    INVOICE_STATUS,
} = require("./invoiceStatus");

function approveInvoice(invoice) {
    return {
        ...invoice,

        status: INVOICE_STATUS.APPROVED,

        approvedAt: new Date(),
    };
}

function rejectInvoice(invoice, reason) {
    return {
        ...invoice,

        status: INVOICE_STATUS.REJECTED,

        rejectionReason: reason,

        rejectedAt: new Date(),
    };
}

module.exports = {
    approveInvoice,
    rejectInvoice,
};