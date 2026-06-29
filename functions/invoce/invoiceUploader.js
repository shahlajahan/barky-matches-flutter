const {
    INVOICE_STATUS,
} = require("./invoiceStatus");

function markUploaded(invoice) {
    return {
        ...invoice,

        status: INVOICE_STATUS.UPLOADED,

        uploadedAt: new Date(),
    };
}

module.exports = {
    markUploaded,
};