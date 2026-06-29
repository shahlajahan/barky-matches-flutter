function validateInvoice(invoice) {
    if (!invoice) {
        throw new Error("Invoice is required.");
    }

    if (!invoice.invoiceNumber) {
        throw new Error("Invoice number is required.");
    }

    if (!invoice.invoiceUrl) {
        throw new Error("Invoice file is required.");
    }

    return true;
}

module.exports = {
    validateInvoice,
};