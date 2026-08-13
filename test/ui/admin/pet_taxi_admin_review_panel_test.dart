import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/admin/pet_taxi_admin_review_panel.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class _FakeApi implements PetTaxiAdminApprovalApi {
  @override
  Future<void> activatePublication(String businessId) async {}

  @override
  Future<void> approveCompliance(String businessId) async {}

  @override
  Future<void> reviewDocument({
    required String businessId,
    required String documentKey,
    required String action,
    String? reason,
  }) async {}
}

class _ExpiredTrafficInsuranceApi extends _FakeApi {
  @override
  Future<void> reviewDocument({
    required String businessId,
    required String documentKey,
    required String action,
    String? reason,
  }) async {
    throw FirebaseFunctionsException(
      code: 'failed-precondition',
      message: 'Pet Taxi trafficInsurance has expired',
    );
  }
}

Map<String, dynamic> _business({
  bool complete = false,
  bool complianceApproved = false,
  bool active = false,
  bool published = false,
}) {
  const docs = [
    'taxPlate',
    'vehicleRegistration',
    'driverLicense',
    'trafficInsurance',
  ];
  const flags = [
    'petSafetyEquipmentConfirmed',
    'hygieneSanitationConfirmed',
    'driverLicenseValidConfirmed',
    'vehicleRegistrationConfirmed',
    'trafficInsuranceConfirmed',
    'taxResponsibilityConfirmed',
    'transportRulesConfirmed',
  ];
  return {
    'status': 'approved',
    'published': published,
    'verification': {'isVerified': true},
    'sectors': ['pet_taxi'],
    'sectorData': {
      'pet_taxi': {
        'isActive': active,
        'published': published,
        'documents': {
          for (final key in docs)
            key: {
              'url': 'https://example.test/$key.pdf',
              'status': complete || complianceApproved
                  ? 'approved'
                  : 'pending_review',
              'verified': complete || complianceApproved,
            },
        },
        'compliance': {
          'status': complianceApproved || complete
              ? 'approved'
              : 'pending_review',
          for (final key in flags) key: true,
        },
      },
    },
  };
}

void main() {
  testWidgets('activation is disabled until compliance is approved', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PetTaxiAdminReviewPanel(
              businessId: 'business-ordering',
              businessData: _business(),
              api: _FakeApi(),
            ),
          ),
        ),
      ),
    );

    final activation = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Activate & publish'),
    );
    expect(activation.onPressed, isNull);
  });

  testWidgets('activation is available after compliance approval', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PetTaxiAdminReviewPanel(
              businessId: 'business-approved',
              businessData: _business(complete: true, complianceApproved: true),
              api: _FakeApi(),
            ),
          ),
        ),
      ),
    );

    final activation = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Activate & publish'),
    );
    expect(activation.onPressed, isNotNull);
  });

  testWidgets(
    'already activated state remains represented as active and published',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PetTaxiAdminReviewPanel(
                businessId: 'business-active',
                businessData: _business(
                  complete: true,
                  complianceApproved: true,
                  active: true,
                  published: true,
                ),
                api: _FakeApi(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Pet Taxi active: active'), findsOneWidget);
      expect(find.text('Publication: published'), findsOneWidget);
      final compliance = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Approve Pet Taxi compliance'),
      );
      expect(compliance.onPressed, isNull);
    },
  );

  testWidgets('admin panel shows document progress and blockers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PetTaxiAdminReviewPanel(
              businessId: 'business-1',
              businessData: _business(),
              api: _FakeApi(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Required documents: 0 / 4 approved'), findsOneWidget);
    expect(find.text('Publication blockers:'), findsOneWidget);
    expect(find.text('Tax plate'), findsOneWidget);
    expect(find.byTooltip('Approve'), findsNWidgets(4));
  });

  testWidgets('admin panel exposes active and published state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PetTaxiAdminReviewPanel(
              businessId: 'business-2',
              businessData: _business(
                complete: true,
                active: true,
                published: true,
              ),
              api: _FakeApi(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Required documents: 4 / 4 approved'), findsOneWidget);
    expect(find.text('Pet Taxi active: active'), findsOneWidget);
    expect(find.text('Publication: published'), findsOneWidget);
  });

  testWidgets(
    'closing the panel while rejection dialog is open is lifecycle-safe',
    (tester) async {
      var showPanel = true;
      StateSetter? togglePanel;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              // Keep the Navigator/dialog alive while disposing the panel below.
              // This reproduces a route/data refresh during the rejection dialog.
              body: Builder(
                builder: (context) {
                  togglePanel = setState;
                  return SingleChildScrollView(
                    child: showPanel
                        ? PetTaxiAdminReviewPanel(
                            businessId: 'business-3',
                            businessData: _business(),
                            api: _FakeApi(),
                          )
                        : const SizedBox.shrink(),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Reject').first);
      await tester.pumpAndSettle();
      expect(find.text('Reason'), findsOneWidget);

      togglePanel!(() => showPanel = false);
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Replace this document');
      await tester.tap(find.text('Reject').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expired traffic insurance approval stays local and uses friendly text',
    (tester) async {
      final data = _business();
      (data['sectorData']
              as Map)['pet_taxi']['documents']['trafficInsurance']['expiryDate'] =
          '2026-05-30';

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PetTaxiAdminReviewPanel(
                businessId: 'business-expired',
                businessData: data,
                api: _ExpiredTrafficInsuranceApi(),
              ),
            ),
          ),
        ),
      );

      final approveButtons = find.byTooltip('Approve');
      await tester.ensureVisible(approveButtons.last);
      await tester.tap(approveButtons.last);
      await tester.pump();

      expect(
        find.text(
          'This document has expired. Reject it and ask the business to upload a valid replacement.',
        ),
        findsOneWidget,
      );
      expect(find.byType(PetTaxiAdminReviewPanel), findsOneWidget);
      expect(find.text('trafficInsurance'), findsNothing);
      expect(find.text('Pending review'), findsNWidgets(4));
      expect(find.textContaining('firebase_functions'), findsNothing);
      expect(
        ((data['sectorData'] as Map)['pet_taxi']
            as Map)['documents']['trafficInsurance']['status'],
        'pending_review',
      );
      expect(find.text('Approve Pet Taxi compliance'), findsOneWidget);
      expect(find.text('Activate & publish'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('document cards stay usable at narrow mobile width', (
    tester,
  ) async {
    final data = _business();
    ((data['sectorData'] as Map)['pet_taxi']
            as Map)['documents']['trafficInsurance']['expiryDate'] =
        '2026-05-30';
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PetTaxiAdminReviewPanel(
              businessId: 'business-narrow',
              businessData: data,
              api: _FakeApi(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Traffic insurance'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Pending review'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin opens image documents in an image preview', (
    tester,
  ) async {
    final data = _business();
    ((data['sectorData'] as Map)['pet_taxi']
        as Map)['documents']['taxPlate'] = {
      'url': 'https://example.test/tax-plate.jpg',
      'fileName': 'tax-plate.jpg',
      'contentType': 'image/jpeg',
      'status': 'pending_review',
      'verified': false,
    };
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PetTaxiAdminReviewPanel(
              businessId: 'business-image',
              businessData: data,
              api: _FakeApi(),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open').first);
    await tester.pump();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
