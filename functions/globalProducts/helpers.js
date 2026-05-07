// functions/globalProducts/helpers.js

function normalizeProduct(data) {
    return {
        name: (data.name || "").trim(),
        brand: (data.brand || "").trim(),
        category: normalizeCategory(data.category),
        imageUrl: data.imageUrl || null,
        attributes: data.attributes || {},
    };
}

function normalizeCategory(cat) {
    if (!cat) return "Other > General";

    const c = cat.toLowerCase();

    if (c.includes("food")) return "Food > Dry Food";
    if (c.includes("toy")) return "Toys > General";
    if (c.includes("collar")) return "Accessories > Collar";

    return "Other > General";
}

function smartMerge(oldData, newData) {
    return {
        name: pickBetter(oldData.name, newData.name),
        brand: pickBetter(oldData.brand, newData.brand),
        category: pickBetter(oldData.category, newData.category),
        imageUrl: oldData.imageUrl || newData.imageUrl,
        attributes: {
            ...oldData.attributes,
            ...newData.attributes,
        },
    };
}

function pickBetter(oldVal, newVal) {
    if (!oldVal) return newVal;
    if (!newVal) return oldVal;

    return newVal.length > oldVal.length ? newVal : oldVal;
}

function computeQualityScore(p) {
    let score = 0;

    if (p.name) score += 30;
    if (p.brand) score += 20;
    if (p.category) score += 20;
    if (p.imageUrl) score += 20;
    if (p.attributes && Object.keys(p.attributes).length > 0) score += 10;

    return score;
}

module.exports = {
    normalizeProduct,
    smartMerge,
    computeQualityScore,
};