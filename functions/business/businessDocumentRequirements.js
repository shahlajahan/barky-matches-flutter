"use strict";

/**
 * Authoritative company-type enum and Turkey document-requirement matrix
 * for business registration. This is the single canonical representation
 * the server (registerBusiness) validates against — the client's mirrored
 * copy (lib/models/business_document_requirements.dart) only controls UI
 * display/blocking and must never be trusted as authoritative here.
 *
 * `companyType` is distinct from the existing `businessType` field used
 * elsewhere in this codebase (business/service category — vet/groomer/
 * hotel/etc). This field represents Turkish legal entity structure only.
 */

const VALID_COMPANY_TYPES = Object.freeze([
  "sole_proprietorship",
  "limited_company",
  "joint_stock_company",
]);

function isValidCompanyType(value) {
  return VALID_COMPANY_TYPES.includes(value);
}

/**
 * See lib/models/business_document_requirements.dart for the full
 * reasoning: sole proprietorships are not required to register with the
 * Turkish Trade Registry, so a Ticaret Sicil Gazetesi (and, as a direct
 * mechanical consequence, a MERSIS number extractable only from that
 * document) cannot be required for them. Tax plate and the authorized
 * signature document remain required for every company type — no evidence
 * in this codebase distinguishes their applicability by company type.
 */
function requiredTurkeyDocuments(companyType) {
  const isSoleProprietorship = companyType === "sole_proprietorship";
  return Object.freeze({
    requiresTaxPlate: true,
    requiresTradeRegistryGazette: !isSoleProprietorship,
    requiresSignatureDocument: true,
    requiresMersisNumber: !isSoleProprietorship,
  });
}

module.exports = {
  VALID_COMPANY_TYPES,
  isValidCompanyType,
  requiredTurkeyDocuments,
};
