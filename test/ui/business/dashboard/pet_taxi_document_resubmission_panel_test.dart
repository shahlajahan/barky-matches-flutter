import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/pet_taxi/pet_taxi_document_resubmission_panel.dart';

Map<String, dynamic> _businessFor(String documentKey) => {
  'sectorData': {
    'pet_taxi': {
      'documents': {
        documentKey: {
          'status': 'rejected',
          'verified': false,
          'rejectionReason': 'Replacement required',
        },
      },
    },
  },
};

Widget _host(Map<String, dynamic> business) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: PetTaxiDocumentResubmissionPanel(
      businessId: 'business-1',
      businessData: business,
    ),
  ),
);

void main() {
  testWidgets('driver license replacement displays an expiry input', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_businessFor('driverLicense')));
    expect(find.text('New driver license expiry date'), findsOneWidget);
  });

  testWidgets('traffic insurance replacement displays an expiry input', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_businessFor('trafficInsurance')));
    expect(find.text('New traffic insurance expiry date'), findsOneWidget);
  });

  testWidgets('non-expiring replacements do not display an expiry input', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_businessFor('taxPlate')));
    expect(find.text('New driver license expiry date'), findsNothing);
    expect(find.text('New traffic insurance expiry date'), findsNothing);
  });

  test('replacement payload uses canonical expiry fields only', () {
    final date = DateTime(2027, 5, 30);
    final driver = buildPetTaxiReplacementDocument(
      documentKey: 'driverLicense',
      url: 'https://example.test/driver.pdf',
      storagePath: 'business_sector_docs/owner/pet_taxi/driverLicense/new.pdf',
      fileName: 'driver.pdf',
      contentType: 'application/pdf',
      expiryDate: date,
    );
    expect(driver['driverLicenseExpiryDate'], date.toIso8601String());
    expect(driver.containsKey('expiryDate'), isFalse);

    final insurance = buildPetTaxiReplacementDocument(
      documentKey: 'trafficInsurance',
      url: 'https://example.test/insurance.pdf',
      storagePath:
          'business_sector_docs/owner/pet_taxi/trafficInsurance/new.pdf',
      fileName: 'insurance.pdf',
      contentType: 'application/pdf',
      expiryDate: date,
    );
    expect(insurance['trafficInsuranceExpiryDate'], date.toIso8601String());
    expect(insurance.containsKey('expiryDate'), isFalse);

    final taxPlate = buildPetTaxiReplacementDocument(
      documentKey: 'taxPlate',
      url: 'https://example.test/tax.pdf',
      storagePath: 'business_sector_docs/owner/pet_taxi/taxPlate/new.pdf',
      fileName: 'tax.pdf',
      contentType: 'application/pdf',
    );
    expect(taxPlate.containsKey('expiryDate'), isFalse);
  });

  test('expiring replacement payload requires an expiry', () {
    expect(
      () => buildPetTaxiReplacementDocument(
        documentKey: 'driverLicense',
        url: 'https://example.test/driver.pdf',
        storagePath:
            'business_sector_docs/owner/pet_taxi/driverLicense/new.pdf',
        fileName: 'driver.pdf',
        contentType: 'application/pdf',
      ),
      throwsArgumentError,
    );
  });
}
