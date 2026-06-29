const { SECTORS } = require("./commissionTypes");

function validateCommissionInput({
    sector,
    referencePrice,
    sellerPrice,
    serviceCategory = null,
    productCategory = null,
}) {
    if (!sector) {
        throw new Error("Sector is required.");
    }

    if (!Object.values(SECTORS).includes(sector)) {
        throw new Error(`Invalid sector: ${sector}`);
    }

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

    if (
        serviceCategory !== null &&
        typeof serviceCategory !== "string"
    ) {
        throw new Error("Invalid service category.");
    }

    if (
        productCategory !== null &&
        typeof productCategory !== "string"
    ) {
        throw new Error("Invalid product category.");
    }
}

module.exports = {
    validateCommissionInput,
};