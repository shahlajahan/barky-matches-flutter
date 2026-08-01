const { HttpsError } = require("firebase-functions/v2/https");
const {
  normalizePetshopPayout,
} = require("../normalizers/petshopPayoutNormalizer");

// Local copies of tiny string-normalization helpers, matching the
// convention already used by sibling modules (e.g.
// functions/commission/paymentFinancialSnapshot.js's own `normalized()`)
// rather than importing from ../../index.js, which would create a
// circular require (index.js requires this module too).
function normalizeLower(value) {
  return String(value || "").trim().toLowerCase();
}

function normalizeReturnStatus(value) {
  const lower = normalizeLower(value);

  if (lower.includes("approved")) return "approved";
  if (lower.includes("rejected")) return "rejected";
  if (lower.includes("shipped")) return "shipped_back";
  if (lower.includes("received")) return "received_by_seller";
  if (lower.includes("refund_pending")) return "refund_pending";
  if (lower.includes("refund_failed")) return "refund_failed";
  if (lower.includes("refunded")) return "refunded";
  if (lower.includes("cancel")) return "cancelled";

  return "pending";
}

const PAYOUT_BLOCKING_RETURN_STATUSES = [
  "pending",
  "approved",
  "shipped_back",
  "received_by_seller",
  "refund_pending",
  "refund_failed",
];

// Pet Shop's payout-blocking check: an unresolved product return exists.
// This is the one genuinely marketplace-specific piece of the payout
// approval flow (physical-goods return logistics, e.g. "shipped_back" /
// "received_by_seller") — per the approved architecture, it stays a
// per-sector adapter hook rather than shared engine logic, since no
// other sector has an equivalent physical-return concept.
async function assertNoBlockingEvents({ transaction, db, payableId }) {
  const returnsQuery = db
    .collection("order_returns")
    .where("sellerOrderId", "==", payableId);
  const returnsSnap = transaction
    ? await transaction.get(returnsQuery)
    : await returnsQuery.get();

  const activeReturn = returnsSnap.docs.find((doc) =>
    PAYOUT_BLOCKING_RETURN_STATUSES.includes(
      normalizeReturnStatus(doc.data()?.status)
    )
  );

  if (activeReturn) {
    throw new HttpsError(
      "failed-precondition",
      `This seller order has an active return (${activeReturn.id}, status: ${activeReturn.data().status}) and cannot be approved for payout until it is resolved.`
    );
  }
}

function getBusinessId(record) {
  return record?.businessId || record?.shopId || null;
}

function getRecoverySellerUid(record) {
  return record?.sellerUid || record?.sellerSnapshot?.ownerUid || null;
}

const petshopPayoutAdapter = {
  sector: "petshop",
  collection: "sellerOrders",
  debtCollection: "sellerDebts",
  getBusinessId,
  normalizePayout: normalizePetshopPayout,
  getRecoveryOwnerId: getRecoverySellerUid,
  getRecoverySellerUid,
  assertNoBlockingEvents,
};

module.exports = {
  petshopPayoutAdapter,
};
