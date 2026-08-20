/// Legal entity type for a business registering on Petsupo.
///
/// This is distinct from `businessType`/sector fields used elsewhere in the
/// codebase (e.g. `data['businessType']` on business documents, which means
/// the service category — vet/groomer/hotel/etc). `companyType` specifically
/// represents the Turkish legal structure of the business and controls
/// which legal documents are required during registration (see
/// `requiredBusinessDocuments` in `business_document_requirements.dart`).
///
/// Only Turkey-registered businesses currently have a legal structure
/// distinction in the product; Germany/USA registration flows are
/// unaffected by this field.
enum CompanyType {
  soleProprietorship,
  limitedCompany,
  jointStockCompany;

  /// Convert Firestore string -> enum. Returns null for missing/unknown
  /// values so legacy records (which have no companyType at all) and
  /// tampered/unsupported values can be distinguished from a valid choice
  /// by the caller, rather than silently defaulting to one legal type.
  static CompanyType? fromString(String? value) {
    switch (value?.trim()) {
      case 'sole_proprietorship':
        return CompanyType.soleProprietorship;
      case 'limited_company':
        return CompanyType.limitedCompany;
      case 'joint_stock_company':
        return CompanyType.jointStockCompany;
      default:
        return null;
    }
  }

  /// Convert enum -> Firestore string (stable, serialized value).
  String toFirestore() {
    switch (this) {
      case CompanyType.soleProprietorship:
        return 'sole_proprietorship';
      case CompanyType.limitedCompany:
        return 'limited_company';
      case CompanyType.jointStockCompany:
        return 'joint_stock_company';
    }
  }
}
