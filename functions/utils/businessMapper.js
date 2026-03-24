// functions/utils/businessMapper.js

/**
 * Maps an adoption_centers document
 * to the new unified businesses structure
 */

function normalizeStatus(status) {
    if (!status) return "pending";
    const s = String(status).toLowerCase();
    if (["approved", "rejected", "pending"].includes(s)) {
        return s;
    }
    return "pending";
}

function mapAdoptionCenterToBusiness(oldDoc = {}) {
    const status = normalizeStatus(oldDoc.status);

    return {
        type: "adoption_center",

        ownerUid: oldDoc.ownerUid || null,

        status: status,
        isVerified:
            typeof oldDoc.isVerified === "boolean"
                ? oldDoc.isVerified
                : status === "approved",

        profile: {
            displayName: oldDoc.name || "",
            description: oldDoc.description || "",
            logoUrl: oldDoc.logoUrl || null,
            coverImageUrl: oldDoc.coverImageUrl || null,
            rating:
                typeof oldDoc.rating === "number"
                    ? oldDoc.rating
                    : 0,
            reviewCount:
                typeof oldDoc.reviewsCount === "number"
                    ? oldDoc.reviewsCount
                    : 0,
        },

        contact: {
            phone: oldDoc.phone || null,
            whatsapp: oldDoc.whatsapp || null,
            instagram: oldDoc.instagram || null,
            website: oldDoc.website || null,
            city: oldDoc.city || "",
            district: oldDoc.district || "",
            address: oldDoc.address || "",
        },

        legal: {
            taxNumber: oldDoc.taxNumber || null,
            mersisNumber: oldDoc.mersisNumber || null,
            taxDocumentUrl: oldDoc.taxDocumentUrl || null,
            signatureCircularUrl: oldDoc.signatureCircularUrl || null,
        },

        // 🔐 Audit fields
        createdAt: oldDoc.createdAt || null,
        updatedAt: null, // ⚠️ در migration خود Function با serverTimestamp ست کن
        approvedAt: oldDoc.approvedAt || null,
        rejectedAt: oldDoc.rejectedAt || null,
        rejectionReason: oldDoc.rejectionReason || null,
        resolvedBy: oldDoc.resolvedBy || null,
    };
}

module.exports = {
    mapAdoptionCenterToBusiness,
};