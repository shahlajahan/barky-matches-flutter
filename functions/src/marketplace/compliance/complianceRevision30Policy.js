"use strict";

// Marketplace Revision 30 §J Slice 5 — the frozen §D evidence matrix,
// transcribed into the policy registry's own already-frozen schema.
//
// WHAT THIS IS. Revision 30 §D fixes, per `sellerRelationship`, the minimum
// acceptable `COMPLIANCE_DOCUMENT_TYPE`, its acceptable alternatives, and the
// natural scope. The decision engine reads that policy from
// `compliancePolicyRegistry` at runtime, not from code — so without a
// canonical encoding, §D's table and the registry data could silently
// diverge. This module is that encoding: a pure transcription, using only
// existing frozen identifiers, introducing no new relationship, document
// type, scope type or alternative.
//
// WHAT THIS IS NOT. It creates nothing and activates nothing. It writes no
// Firestore document, is imported by no production code path, and is not
// wired into functions/index.js. Activating a registry version is a separate,
// deliberately unauthorized operation. Its purpose here is (a) to make the
// §D contract executable and testable against the real engine, and (b) to
// give a future activation one reviewed source rather than hand-written data.
//
// THE IMPORTER CONJUNCTION, and how it survives the registry's shape.
// §D's importer row reads: minimum `importer_evidence`; alternative
// "`purchase_invoice` from the foreign supplier plus `supplier_agreement`".
// That is a disjunction whose second arm is a CONJUNCTION:
//
//     importer_evidence  OR  (purchase_invoice AND supplier_agreement)
//
// The engine's model is `requiredDocumentTypeGroups`: every group must be
// satisfied (conjunction ACROSS groups), by any one of its listed types
// (disjunction WITHIN a group) — conjunctive normal form. The formula above
// distributes exactly:
//
//     (importer_evidence OR purchase_invoice)
//       AND (importer_evidence OR supplier_agreement)
//
// which is the two-group encoding below, and it is equivalent, not
// approximate:
//   * `importer_evidence` alone satisfies both groups            -> accepted
//   * `purchase_invoice` + `supplier_agreement` satisfies both    -> accepted
//   * `purchase_invoice` alone leaves group 2 unsatisfied         -> REFUSED
//   * `supplier_agreement` alone leaves group 1 unsatisfied       -> REFUSED
//
// One member of the conjunction can never satisfy the requirement on its
// own, which is the property §D depends on and the tests assert directly.
//
// `category_compliance_evidence` appears in NO row of §D and is therefore
// absent from every branch here. Revision 30 §D's own provisional rule —
// unresolved policy resolves to `policy_unresolved`, outside
// PRODUCT_COMPLIANCE_ELIGIBLE_STATUSES — governs it, and it must not be
// invented into a branch.

const {
  SELLER_RELATIONSHIP,
  COMPLIANCE_DOCUMENT_TYPE,
  COMPLIANCE_SCOPE_TYPE,
} = require("./complianceConstants");

const T = COMPLIANCE_DOCUMENT_TYPE;
const S = COMPLIANCE_SCOPE_TYPE;

/// One group = one required slot, satisfiable by any listed type.
const group = (...documentTypes) => Object.freeze({ documentTypes: Object.freeze(documentTypes) });

/// Builds one relationship branch in the registry's CLOSED entry schema
/// (`RELATIONSHIP_ENTRY_ALLOWED_FIELDS` — exactly six keys, all required).
///
/// `acceptedDocumentTypes` is the flat union of every type this row's groups
/// mention, derived here rather than restated so the two can never drift.
///
/// `perDocumentTypePolicy` requires `validUntil` on every accepted type:
/// Revision 30 §D's provisional rule is uniform and fail-closed ("no grace
/// period is honoured"), and §G already makes `validUntil` mandatory at
/// submission. `issueDateRequired` is left false — §D marks the statutory
/// issue-date requirement COUNSEL REQUIRED, and asserting it here would be
/// inventing policy rather than transcribing it.
///
/// `maximumValidityPeriod` is null for the same reason: §D lists "the legal
/// validity period of each document type" as COUNSEL REQUIRED, so no ceiling
/// is asserted. `manualAdminOverridePermitted` is false everywhere — nothing
/// in Revision 30 grants an admin the power to override missing evidence, and
/// §C forbids treating admin acknowledgement as a substitute for it.
function branch(requiredDocumentTypeGroups, acceptedScopeTypes) {
  const accepted = [];
  for (const g of requiredDocumentTypeGroups) {
    for (const t of g.documentTypes) {
      if (!accepted.includes(t)) accepted.push(t);
    }
  }
  const perDocumentTypePolicy = {};
  for (const t of accepted) {
    perDocumentTypePolicy[t] = { validUntilRequired: true, issueDateRequired: false };
  }
  return Object.freeze({
    acceptedDocumentTypes: Object.freeze(accepted),
    requiredDocumentTypeGroups: Object.freeze(requiredDocumentTypeGroups),
    perDocumentTypePolicy: Object.freeze(perDocumentTypePolicy),
    maximumValidityPeriod: null,
    acceptedScopeTypes: Object.freeze(acceptedScopeTypes),
    manualAdminOverridePermitted: false,
  });
}

// §D's "Natural scope" column, verbatim. `supplier` and `product_family`
// remain in ALWAYS_UNAVAILABLE_SCOPE_TYPES and satisfy nothing, so neither
// appears here.
const REVISION_30_POLICY_BRANCHES = Object.freeze({
  // brand_owner — minimum trademark_evidence; alternative
  // manufacturer_evidence where the seller also manufactures. One slot.
  [SELLER_RELATIONSHIP.BRAND_OWNER]: branch([
      group(T.TRADEMARK_EVIDENCE, T.MANUFACTURER_EVIDENCE),
    ], [S.BRAND]),

  // manufacturer — minimum manufacturer_evidence; alternative
  // trademark_evidence where the seller also owns the brand.
  [SELLER_RELATIONSHIP.MANUFACTURER]: branch([
      group(T.MANUFACTURER_EVIDENCE, T.TRADEMARK_EVIDENCE),
    ], [S.BRAND, S.SKU_SET]),

  // authorized_distributor — minimum dealership_distribution_agreement;
  // alternative authorization_letter naming the exact brand and territory.
  [SELLER_RELATIONSHIP.AUTHORIZED_DISTRIBUTOR]: branch([
      group(T.DEALERSHIP_DISTRIBUTION_AGREEMENT, T.AUTHORIZATION_LETTER),
    ], [S.BRAND, S.SKU_SET]),

  // authorized_dealer — minimum authorization_letter; alternative
  // dealership_distribution_agreement.
  [SELLER_RELATIONSHIP.AUTHORIZED_DEALER]: branch([
      group(T.AUTHORIZATION_LETTER, T.DEALERSHIP_DISTRIBUTION_AGREEMENT),
    ], [S.BRAND, S.SKU_SET]),

  // importer — the CNF encoding of "importer_evidence OR (purchase_invoice
  // AND supplier_agreement)". See the module comment for the derivation.
  [SELLER_RELATIONSHIP.IMPORTER]: branch([
      group(T.IMPORTER_EVIDENCE, T.PURCHASE_INVOICE),
      group(T.IMPORTER_EVIDENCE, T.SUPPLIER_AGREEMENT),
    ], [S.SKU_SET, S.PRODUCT]),

  // reseller — minimum purchase_invoice; alternative supplier_agreement
  // where invoices are periodic.
  [SELLER_RELATIONSHIP.RESELLER]: branch([
      group(T.PURCHASE_INVOICE, T.SUPPLIER_AGREEMENT),
    ], [S.PRODUCT, S.SKU_SET]),
});

/// Builds a policy-version document body in the registry's frozen schema.
/// Returns a plain object; it is the CALLER's job to decide whether to write
/// it, and no caller in production does.
/// The registry schema is a CLOSED key set — `hasExactKeys` rejects both an
/// unknown field and a missing one — so every field is supplied explicitly
/// rather than left to a caller to remember.
function buildRevision30PolicyVersion({
  createdBy,
  effectiveFrom,
  createdAt,
  changeNote,
  status,
}) {
  return {
    sellerRelationship: JSON.parse(JSON.stringify(REVISION_30_POLICY_BRANCHES)),
    status,
    effectiveFrom,
    createdBy,
    createdAt,
    changeNote,
  };
}

module.exports = {
  REVISION_30_POLICY_BRANCHES,
  buildRevision30PolicyVersion,
};
