import 'package:flutter_test/flutter_test.dart';
import 'package:barky_matches_fixed/models/company_type.dart';
import 'package:barky_matches_fixed/models/business_document_requirements.dart';

void main() {
  group('CompanyType', () {
    test('fromString parses the canonical serialized values', () {
      expect(
        CompanyType.fromString('sole_proprietorship'),
        CompanyType.soleProprietorship,
      );
      expect(
        CompanyType.fromString('limited_company'),
        CompanyType.limitedCompany,
      );
      expect(
        CompanyType.fromString('joint_stock_company'),
        CompanyType.jointStockCompany,
      );
    });

    test('fromString returns null for missing/unknown/tampered values', () {
      expect(CompanyType.fromString(null), isNull);
      expect(CompanyType.fromString(''), isNull);
      expect(CompanyType.fromString('anonim'), isNull);
      expect(CompanyType.fromString('SOLE_PROPRIETORSHIP'), isNull);
      expect(CompanyType.fromString('<script>'), isNull);
    });

    test('toFirestore round-trips through fromString', () {
      for (final type in CompanyType.values) {
        expect(CompanyType.fromString(type.toFirestore()), type);
      }
    });
  });

  group('TurkeyBusinessDocumentRequirements', () {
    test('sole proprietorship does not require trade registry or MERSIS', () {
      final req = TurkeyBusinessDocumentRequirements.forCompanyType(
        CompanyType.soleProprietorship,
      );
      expect(req.requiresTradeRegistryGazette, isFalse);
      expect(req.requiresMersisNumber, isFalse);
      expect(req.requiresTaxPlate, isTrue);
      expect(req.requiresSignatureDocument, isTrue);
    });

    test('limited company requires trade registry and MERSIS', () {
      final req = TurkeyBusinessDocumentRequirements.forCompanyType(
        CompanyType.limitedCompany,
      );
      expect(req.requiresTradeRegistryGazette, isTrue);
      expect(req.requiresMersisNumber, isTrue);
      expect(req.requiresTaxPlate, isTrue);
      expect(req.requiresSignatureDocument, isTrue);
    });

    test(
      'joint stock company uses the same corporate requirements as limited',
      () {
        final limited = TurkeyBusinessDocumentRequirements.forCompanyType(
          CompanyType.limitedCompany,
        );
        final anonim = TurkeyBusinessDocumentRequirements.forCompanyType(
          CompanyType.jointStockCompany,
        );
        expect(
          anonim.requiresTradeRegistryGazette,
          limited.requiresTradeRegistryGazette,
        );
        expect(anonim.requiresMersisNumber, limited.requiresMersisNumber);
        expect(anonim.requiresTaxPlate, limited.requiresTaxPlate);
        expect(
          anonim.requiresSignatureDocument,
          limited.requiresSignatureDocument,
        );
      },
    );

    test(
      'unset/null company type defaults to requiring corporate documents (fail-safe)',
      () {
        final req = TurkeyBusinessDocumentRequirements.forCompanyType(null);
        expect(req.requiresTradeRegistryGazette, isTrue);
        expect(req.requiresMersisNumber, isTrue);
      },
    );
  });

  // Regression coverage for the exact Step 3 card-visibility conditions used
  // in business_register_page.dart's `_stepLegal()` — these call the same
  // shouldShowTradeRegistryCard()/shouldShowMersisSection() functions the
  // widget calls, so this is not a parallel reimplementation that could
  // drift from production behavior.
  group('Step 3 card visibility (business_register_page._stepLegal)', () {
    test('sole_proprietorship: Trade Registry card is hidden', () {
      expect(
        shouldShowTradeRegistryCard(
          isPetTaxiRegistration: false,
          companyType: CompanyType.soleProprietorship,
        ),
        isFalse,
      );
    });

    test('sole_proprietorship: MERSIS section is hidden', () {
      expect(
        shouldShowMersisSection(
          isPetTaxiRegistration: false,
          companyType: CompanyType.soleProprietorship,
        ),
        isFalse,
      );
    });

    test('limited_company: Trade Registry card is visible', () {
      expect(
        shouldShowTradeRegistryCard(
          isPetTaxiRegistration: false,
          companyType: CompanyType.limitedCompany,
        ),
        isTrue,
      );
    });

    test('limited_company: MERSIS section is visible', () {
      expect(
        shouldShowMersisSection(
          isPetTaxiRegistration: false,
          companyType: CompanyType.limitedCompany,
        ),
        isTrue,
      );
    });

    test(
      'joint_stock_company: uses the same (corporate) matrix as limited_company',
      () {
        expect(
          shouldShowTradeRegistryCard(
            isPetTaxiRegistration: false,
            companyType: CompanyType.jointStockCompany,
          ),
          isTrue,
        );
        expect(
          shouldShowMersisSection(
            isPetTaxiRegistration: false,
            companyType: CompanyType.jointStockCompany,
          ),
          isTrue,
        );
      },
    );

    test(
      'pet taxi keeps its existing always-visible behavior regardless of company type',
      () {
        expect(
          shouldShowTradeRegistryCard(
            isPetTaxiRegistration: true,
            companyType: CompanyType.soleProprietorship,
          ),
          isTrue,
        );
        expect(
          shouldShowMersisSection(
            isPetTaxiRegistration: true,
            companyType: CompanyType.soleProprietorship,
          ),
          isTrue,
        );
      },
    );

    test(
      'switching company type recalculates card visibility immediately (Limited -> Şahıs)',
      () {
        const isPetTaxi = false;
        var companyType = CompanyType.limitedCompany;
        expect(
          shouldShowTradeRegistryCard(
            isPetTaxiRegistration: isPetTaxi,
            companyType: companyType,
          ),
          isTrue,
        );

        // Simulate the user switching the selection — no cached/stale
        // state is involved, this is the same live re-evaluation the
        // widget does.
        companyType = CompanyType.soleProprietorship;
        expect(
          shouldShowTradeRegistryCard(
            isPetTaxiRegistration: isPetTaxi,
            companyType: companyType,
          ),
          isFalse,
        );
        expect(
          shouldShowMersisSection(
            isPetTaxiRegistration: isPetTaxi,
            companyType: companyType,
          ),
          isFalse,
        );
      },
    );

    test(
      'switching company type recalculates card visibility immediately (Şahıs -> Limited)',
      () {
        const isPetTaxi = false;
        var companyType = CompanyType.soleProprietorship;
        expect(
          shouldShowTradeRegistryCard(
            isPetTaxiRegistration: isPetTaxi,
            companyType: companyType,
          ),
          isFalse,
        );

        companyType = CompanyType.limitedCompany;
        expect(
          shouldShowTradeRegistryCard(
            isPetTaxiRegistration: isPetTaxi,
            companyType: companyType,
          ),
          isTrue,
        );
        expect(
          shouldShowMersisSection(
            isPetTaxiRegistration: isPetTaxi,
            companyType: companyType,
          ),
          isTrue,
        );
      },
    );
  });
}
