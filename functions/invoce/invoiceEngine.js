const {
    validateInvoice,
} = require("./invoiceValidator");

const {
    approveInvoice,
    rejectInvoice,
} = require("./invoiceApproval");

const {
    markUploaded,
} = require("./invoiceUploader");

module.exports = {
    validateInvoice,
    approveInvoice,
    rejectInvoice,
    markUploaded,
};