import 'company_type.dart';

/// Canonical client-side matrix for which Turkey legal documents/fields are
/// required, given the selected company type. This is the single source of
/// truth the registration form's UI and validation both read from — it must
/// stay behaviorally consistent with the server-side matrix in
/// functions/business/businessDocumentRequirements.js, which is the
/// authoritative enforcement point (the client matrix only controls what is
/// shown/blocked in the UI; the server never trusts it).
///
/// Scope: this only applies to Turkey, non-pet-taxi-only registrations.
/// Pet taxi already has its own independent, simpler document set
/// (unaffected by company type). Germany/USA document sets are unaffected.
class TurkeyBusinessDocumentRequirements {
  const TurkeyBusinessDocumentRequirements({
    required this.requiresTaxPlate,
    required this.requiresTradeRegistryGazette,
    required this.requiresSignatureDocument,
    required this.requiresMersisNumber,
  });

  final bool requiresTaxPlate;
  final bool requiresTradeRegistryGazette;
  final bool requiresSignatureDocument;
  final bool requiresMersisNumber;

  /// Sole proprietorships (Şahıs İşletmesi) are not required to register
  /// with the Turkish Trade Registry (Ticaret Sicili), so they may not have
  /// a Ticaret Sicil Gazetesi. MERSİS numbers are issued specifically
  /// through Ticaret Sicili registration, so a sole proprietorship that has
  /// no trade registry document also has no MERSİS number to submit — this
  /// is a direct, mechanical consequence of the confirmed product
  /// requirement (not an independently-assumed legal rule): this
  /// codebase's OCR verification can only ever populate a MERSIS number by
  /// extracting it from an uploaded document, and the trade registry
  /// gazette is the only document type in this flow that would contain one.
  ///
  /// Tax plate (Vergi Levhası) and the authorized signature document remain
  /// required for every company type: no evidence was found in this
  /// codebase distinguishing an individual-specific vs. company-specific
  /// signature document (only one generic "Yetkili İmza Belgesi" field
  /// exists), so its current behavior is preserved unchanged, per the
  /// instruction to avoid guessing at document applicability beyond the
  /// confirmed Ticaret Sicil Gazetesi rule.
  static TurkeyBusinessDocumentRequirements forCompanyType(
    CompanyType? companyType,
  ) {
    final isSoleProprietorship = companyType == CompanyType.soleProprietorship;
    return TurkeyBusinessDocumentRequirements(
      requiresTaxPlate: true,
      requiresTradeRegistryGazette: !isSoleProprietorship,
      requiresSignatureDocument: true,
      requiresMersisNumber: !isSoleProprietorship,
    );
  }
}

/// Pure functions mirroring the exact Step 3 card-visibility conditions used
/// in business_register_page.dart's `_stepLegal()`, extracted so the
/// production widget logic and its regression tests share one
/// implementation rather than two parallel copies that could silently
/// drift apart.
///
/// Pet taxi's existing (pre-existing, unrelated to this feature) behavior
/// of always showing these cards — just not requiring them — is preserved:
/// visibility is `isPetTaxi || <matrix requirement>`.
bool shouldShowTradeRegistryCard({
  required bool isPetTaxiRegistration,
  required CompanyType? companyType,
}) {
  return isPetTaxiRegistration ||
      TurkeyBusinessDocumentRequirements.forCompanyType(
        companyType,
      ).requiresTradeRegistryGazette;
}

bool shouldShowMersisSection({
  required bool isPetTaxiRegistration,
  required CompanyType? companyType,
}) {
  return isPetTaxiRegistration ||
      TurkeyBusinessDocumentRequirements.forCompanyType(
        companyType,
      ).requiresMersisNumber;
}
