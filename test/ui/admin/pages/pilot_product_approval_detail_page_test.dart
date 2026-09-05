import 'dart:async';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/admin/pages/pilot_product_approval_detail_page.dart';
import 'package:barky_matches_fixed/services/marketplace_catalog_service.dart'
    show MarketplaceFunctionCaller;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// Revision 28 pilot product approval contract — no prior test file
// exists for this page. Both Firestore and the Firebase Functions
// callable are exercised through this page's own injectable
// `firestoreOverride`/`callableInvoker` seams (mirroring
// `AddProductPage.firestoreOverride` and `MarketplaceCatalogService`'s
// `MarketplaceFunctionCaller`), never a real backend.

Widget _testApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

Future<FakeFirebaseFirestore> firestoreWithProduct(
  Map<String, dynamic> productData,
) async {
  final db = FakeFirebaseFirestore();
  await db
      .collection('businesses')
      .doc('business-1')
      .collection('products')
      .doc('product-1')
      .set(productData);
  return db;
}

// Marketplace Revision 36 — the page asks the server for approval readiness as
// soon as it mounts, so every test must answer
// `getPilotProductApprovalReadiness`. This wrapper answers it with a canned
// response and forwards only the calls a test actually cares about, so no test
// has to special-case a call it never asked about.
const Map<String, dynamic> _readyReadiness = {
  'ready': true,
  'reasonCode': null,
  'approvalFingerprint': 'server-computed-fingerprint-abc123',
  'pilotProductClass': 'sealed_dry_food',
  'decisionStatus': 'verified_valid',
  'decisionValidUntilMillis': null,
  'activeEvidenceCount': 1,
};

const Map<String, dynamic> _blockedReadiness = {
  'ready': false,
  'reasonCode': 'readiness-decision-missing',
  'approvalFingerprint': null,
  'pilotProductClass': 'sealed_dry_food',
  'decisionStatus': null,
  'decisionValidUntilMillis': null,
  'activeEvidenceCount': 0,
};

MarketplaceFunctionCaller _withReadiness(
  Map<String, dynamic> readiness, [
  Future<Object?> Function(String name, Map<String, dynamic> data)? onOther,
]) {
  return (name, data) async {
    if (name == 'getPilotProductApprovalReadiness') return readiness;
    if (onOther != null) return onOther(name, data);
    return const <String, dynamic>{};
  };
}

const _pendingProduct = {
  'businessId': 'business-1',
  'name': 'Premium dog food',
  'description': 'A great food',
  'price': 149,
  'currency': 'TRY',
  'category': 'Food > Dry Food',
  'isActive': false,
  'moderationStatus': 'pending_review',
};

/// Revision 35 (Slice 7A) added the classification card above the approve and
/// revoke controls. In the default 800px-high test viewport those controls now
/// fall below the fold, and a lazy `ListView` never builds what is off-screen —
/// so these tests give themselves a viewport tall enough to hold the whole page
/// rather than scrolling at each interaction point.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('a not-found product shows the not-found message', (
    tester,
  ) async {
    _useTallViewport(tester);
    final db = FakeFirebaseFirestore();
    await tester.pumpWidget(
      _testApp(
        PilotProductApprovalDetailPage(
          businessId: 'business-1',
          productId: 'missing-product',
          firestoreOverride: db,
          callableInvoker: _withReadiness(_blockedReadiness),
        ),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PilotProductApprovalDetailPage)),
    )!;
    expect(find.text(l10n.pilotAdminErrorNotFound), findsOneWidget);
  });

  testWidgets('a pending product renders the approve section with the '
      'approve button disabled until a category is chosen and attested', (
    tester,
  ) async {
    _useTallViewport(tester);
    final db = await firestoreWithProduct(_pendingProduct);
    await tester.pumpWidget(
      _testApp(
        PilotProductApprovalDetailPage(
          businessId: 'business-1',
          productId: 'product-1',
          firestoreOverride: db,
          // Readiness is `ready`, so this test isolates the category and
          // attestation gates rather than the readiness gate.
          callableInvoker: _withReadiness(_readyReadiness),
        ),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PilotProductApprovalDetailPage)),
    )!;
    expect(find.text(l10n.pilotAdminApproveButton), findsOneWidget);
    final approveButtonFinder = find.widgetWithText(
      ElevatedButton,
      l10n.pilotAdminApproveButton,
    );
    ElevatedButton approveButton = tester.widget(approveButtonFinder);
    expect(approveButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('pilotApprovalCategoryDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.pilotAdminCategoryFood).last);
    await tester.pumpAndSettle();
    approveButton = tester.widget(approveButtonFinder);
    expect(approveButton.onPressed, isNull); // still not attested

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    approveButton = tester.widget(approveButtonFinder);
    expect(approveButton.onPressed, isNotNull);
  });

  testWidgets(
    'confirming approval invokes approvePilotProduct with the correct '
    'businessId/productId/category/attestation and the exact fingerprint the '
    'server returned from readiness',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct(_pendingProduct);
      String? capturedName;
      Map<String, dynamic>? capturedData;
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: _withReadiness(_readyReadiness, (
              name,
              data,
            ) async {
              capturedName = name;
              capturedData = data;
              return {'businessId': 'business-1', 'productId': 'product-1'};
            }),
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;

      await tester.tap(find.byKey(const Key('pilotApprovalCategoryDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminCategoryFood).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      await tester.tap(
        find.widgetWithText(ElevatedButton, l10n.pilotAdminApproveButton),
      );
      await tester.pumpAndSettle();
      // Confirmation dialog now showing — confirm it.
      await tester.tap(
        find.widgetWithText(TextButton, l10n.pilotAdminApproveButton),
      );
      await tester.pumpAndSettle();

      expect(capturedName, 'approvePilotProduct');
      expect(capturedData!['businessId'], 'business-1');
      expect(capturedData!['productId'], 'product-1');
      expect(capturedData!['allowedPilotCategory'], 'food');
      expect(capturedData!['attestNoProhibitedClaim'], true);
      // Revision 36: the value forwarded is the server's own, verbatim. The
      // client no longer computes an approval fingerprint at all.
      expect(
        capturedData!['reviewedContentFingerprint'],
        _readyReadiness['approvalFingerprint'],
      );
    },
  );

  testWidgets('declining the approval confirmation dialog never invokes the '
      'callable', (tester) async {
    _useTallViewport(tester);
    final db = await firestoreWithProduct(_pendingProduct);
    var invoked = false;
    await tester.pumpWidget(
      _testApp(
        PilotProductApprovalDetailPage(
          businessId: 'business-1',
          productId: 'product-1',
          firestoreOverride: db,
          callableInvoker: _withReadiness(_readyReadiness, (name, data) async {
            invoked = true;
            return null;
          }),
        ),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PilotProductApprovalDetailPage)),
    )!;
    await tester.tap(find.byKey(const Key('pilotApprovalCategoryDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.pilotAdminCategoryFood).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(ElevatedButton, l10n.pilotAdminApproveButton),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
    await tester.pumpAndSettle();
    expect(invoked, isFalse);
  });

  testWidgets(
    'an already-active-approved product renders the revoke section, and '
    'confirming revoke with "content changed" invokes '
    'revokePilotProductApproval with that reasonCode',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct({
        ..._pendingProduct,
        'isActive': true,
        'moderationStatus': 'approved',
        'pilotProductApproval': {'active': true},
      });
      String? capturedName;
      Map<String, dynamic>? capturedData;
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: _withReadiness(_blockedReadiness, (
              name,
              data,
            ) async {
              capturedName = name;
              capturedData = data;
              return {'businessId': 'business-1', 'productId': 'product-1'};
            }),
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;
      expect(find.text(l10n.pilotAdminRevokeButton), findsOneWidget);

      await tester.tap(
        find.widgetWithText(OutlinedButton, l10n.pilotAdminRevokeButton),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminRevokeReasonContentChanged));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(TextButton, l10n.pilotAdminRevokeButton),
      );
      await tester.pumpAndSettle();

      expect(capturedName, 'revokePilotProductApproval');
      expect(capturedData!['businessId'], 'business-1');
      expect(capturedData!['productId'], 'product-1');
      expect(capturedData!['reasonCode'], 'pilot_revoked_content_changed');
    },
  );

  testWidgets(
    'a limit-exceeded FirebaseFunctionsException maps to the localized '
    'limit-exceeded message',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct(_pendingProduct);
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: _withReadiness(_readyReadiness, (
              name,
              data,
            ) async {
              throw FirebaseFunctionsException(
                code: 'resource-exhausted',
                message: 'Active pilot product limit reached',
                details: {'reasonCode': 'limit-exceeded'},
              );
            }),
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;
      await tester.tap(find.byKey(const Key('pilotApprovalCategoryDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminCategoryFood).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ElevatedButton, l10n.pilotAdminApproveButton),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, l10n.pilotAdminApproveButton),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.pilotAdminErrorLimitExceeded), findsOneWidget);
    },
  );

  // =====================================================================
  // Marketplace Revision 35 / Slice 7A — the admin classification control.
  //
  // The section is a PRECONDITION step, not part of approval: it must show
  // canonical server state, require an explicit class and an explicit
  // reason, warn before unpublishing, and send exactly one callable
  // invocation carrying nothing the admin did not choose.
  // =====================================================================

  testWidgets(
    'REV35-UI-1. an unclassified product shows "not classified" and keeps '
    'the save button disabled until both a class and a reason are given',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct(_pendingProduct);
      var invoked = false;
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: _withReadiness(_blockedReadiness, (
              name,
              data,
            ) async {
              invoked = true;
              return const {};
            }),
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;

      expect(
        find.text(
          '${l10n.pilotAdminClassificationCurrentLabel}: '
          '${l10n.pilotAdminClassificationNotClassified}',
        ),
        findsOneWidget,
      );

      final saveFinder = find.byKey(const Key('pilotClassificationSaveButton'));
      ElevatedButton save() => tester.widget(saveFinder);
      expect(save().onPressed, isNull, reason: 'nothing chosen yet');

      // A class alone is not enough — the reason is mandatory.
      await tester.tap(find.byKey(const Key('pilotClassificationDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminClassSealedDryFood).last);
      await tester.pumpAndSettle();
      expect(save().onPressed, isNull, reason: 'no reason recorded yet');

      // Whitespace is not a reason.
      await tester.enterText(
        find.byKey(const Key('pilotClassificationReasonField')),
        '   ',
      );
      await tester.pump();
      expect(save().onPressed, isNull);
      expect(
        find.text(l10n.pilotAdminClassificationReasonRequired),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('pilotClassificationReasonField')),
        'Sealed retail bag, no medicinal claim.',
      );
      await tester.pump();
      expect(save().onPressed, isNotNull);
      expect(invoked, isFalse, reason: 'nothing is sent before the tap');
    },
  );

  testWidgets(
    'REV35-UI-2. saving sends exactly one setPilotProductClassification call '
    'carrying only the four frozen request fields',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct(_pendingProduct);
      final calls = <List<Object?>>[];
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: _withReadiness(_blockedReadiness, (
              name,
              data,
            ) async {
              calls.add([name, data]);
              return {
                'changed': true,
                'idempotent': false,
                'unpublished': false,
                'pilotProductClass': 'non_biocidal_litter',
              };
            }),
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;

      await tester.tap(find.byKey(const Key('pilotClassificationDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminClassNonBiocidalLitter).last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('pilotClassificationReasonField')),
        '  Clay litter, no biocidal additive.  ',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('pilotClassificationSaveButton')));
      await tester.pumpAndSettle();

      expect(calls.length, 1);
      expect(calls.single[0], 'setPilotProductClassification');
      final data = calls.single[1] as Map<String, dynamic>;
      expect(data.keys.toSet(), {
        'businessId',
        'productId',
        'pilotProductClass',
        'reason',
      });
      expect(data['businessId'], 'business-1');
      expect(data['productId'], 'product-1');
      expect(data['pilotProductClass'], 'non_biocidal_litter');
      expect(data['reason'], 'Clay litter, no biocidal additive.');
      expect(find.text(l10n.pilotAdminClassificationSaved), findsOneWidget);
    },
  );

  testWidgets('REV35-UI-3. exactly the four frozen classes are offered, and an '
      'unrecognized stored value renders as "not classified"', (tester) async {
    _useTallViewport(tester);
    final db = await firestoreWithProduct({
      ..._pendingProduct,
      'pilotProductClass': 'legacy_value_from_an_older_vocabulary',
    });
    await tester.pumpWidget(
      _testApp(
        PilotProductApprovalDetailPage(
          businessId: 'business-1',
          productId: 'product-1',
          firestoreOverride: db,
        ),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PilotProductApprovalDetailPage)),
    )!;

    // An unrecognized value is never displayed as if it were a class.
    expect(
      find.text(
        '${l10n.pilotAdminClassificationCurrentLabel}: '
        '${l10n.pilotAdminClassificationNotClassified}',
      ),
      findsOneWidget,
    );
    expect(find.text('legacy_value_from_an_older_vocabulary'), findsNothing);

    await tester.tap(find.byKey(const Key('pilotClassificationDropdown')));
    await tester.pumpAndSettle();
    for (final label in [
      l10n.pilotAdminClassSealedDryFood,
      l10n.pilotAdminClassSealedWetFood,
      l10n.pilotAdminClassNonMedicinalTreats,
      l10n.pilotAdminClassNonBiocidalLitter,
    ]) {
      expect(find.text(label), findsWidgets, reason: 'missing $label');
    }
    // No approval category ever leaks into the classification menu.
    expect(find.text(l10n.pilotAdminCategoryToys), findsNothing);
    expect(find.text(l10n.pilotAdminCategoryGroomingTools), findsNothing);
  });

  testWidgets(
    'REV35-UI-4. a published product warns before reclassification, and '
    'declining the confirmation sends nothing',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct({
        ..._pendingProduct,
        'isActive': true,
        'moderationStatus': 'approved',
        'pilotProductClass': 'sealed_dry_food',
        'pilotProductApproval': {'active': true},
      });
      var invoked = false;
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: _withReadiness(_blockedReadiness, (
              name,
              data,
            ) async {
              invoked = true;
              return const {};
            }),
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;

      expect(
        find.text(l10n.pilotAdminClassificationUnpublishWarning),
        findsOneWidget,
      );
      // The stored class is shown, and pre-selected.
      expect(
        find.text(
          '${l10n.pilotAdminClassificationCurrentLabel}: '
          '${l10n.pilotAdminClassSealedDryFood}',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('pilotClassificationDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminClassSealedWetFood).last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('pilotClassificationReasonField')),
        'Wet food after re-review.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('pilotClassificationSaveButton')));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.pilotAdminClassificationConfirmMessage),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
      await tester.pumpAndSettle();
      expect(invoked, isFalse);
    },
  );

  testWidgets(
    'REV35-UI-5. confirming a reclassification of a published product '
    'reports the server-stated unpublish outcome, never a local guess',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct({
        ..._pendingProduct,
        'isActive': true,
        'moderationStatus': 'approved',
        'pilotProductClass': 'sealed_dry_food',
        'pilotProductApproval': {'active': true},
      });
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: _withReadiness(
              _blockedReadiness,
              (name, data) async => {
                'changed': true,
                'idempotent': false,
                'unpublished': true,
              },
            ),
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;

      await tester.tap(find.byKey(const Key('pilotClassificationDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminClassNonMedicinalTreats).last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('pilotClassificationReasonField')),
        'Treats, non-medicinal.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('pilotClassificationSaveButton')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          TextButton,
          l10n.pilotAdminClassificationSaveButton,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.pilotAdminClassificationUnpublished),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'REV35-UI-6. a server-reported idempotent replay says nothing changed',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct({
        ..._pendingProduct,
        'pilotProductClass': 'sealed_dry_food',
      });
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: _withReadiness(
              _blockedReadiness,
              (name, data) async => {
                'changed': false,
                'idempotent': true,
                'unpublished': false,
              },
            ),
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;

      await tester.enterText(
        find.byKey(const Key('pilotClassificationReasonField')),
        'Reconfirmed.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('pilotClassificationSaveButton')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.pilotAdminClassificationUnchanged), findsOneWidget);
      // An unpublished product is never warned about unpublishing.
      expect(
        find.text(l10n.pilotAdminClassificationUnpublishWarning),
        findsNothing,
      );
    },
  );

  testWidgets('REV35-UI-7. the classification callable errors map to their own '
      'localized messages, not a generic failure', (tester) async {
    _useTallViewport(tester);
    final cases = <String, String Function(AppLocalizations)>{
      'classification-unsupported-class': (l) =>
          l.pilotAdminErrorClassUnsupported,
      'classification-invalid-transition': (l) =>
          l.pilotAdminErrorClassNotClassifiable,
      'classification-stale-generation': (l) =>
          l.pilotAdminErrorStaleGeneration,
      'classification-product-not-found': (l) => l.pilotAdminErrorNotFound,
    };
    for (final entry in cases.entries) {
      final db = await firestoreWithProduct(_pendingProduct);
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            // A distinct key per case forces a fresh State, so one case's
            // selection, typed reason and snackbar can never leak into the
            // next and make a later assertion pass for the wrong reason.
            key: ValueKey(entry.key),
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: _withReadiness(_blockedReadiness, (
              name,
              data,
            ) async {
              throw FirebaseFunctionsException(
                code: 'failed-precondition',
                message: 'rejected',
                details: {'reasonCode': entry.key},
              );
            }),
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;

      await tester.tap(find.byKey(const Key('pilotClassificationDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminClassSealedDryFood).last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('pilotClassificationReasonField')),
        'Reason ${entry.key}',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('pilotClassificationSaveButton')));
      await tester.pumpAndSettle();

      expect(
        find.text(entry.value(l10n)),
        findsOneWidget,
        reason: 'unmapped reasonCode ${entry.key}',
      );
      // ScaffoldMessenger queues snackbars and survives the rebuild, so this
      // one must be allowed to expire — otherwise the next case's message
      // would sit behind it and its assertion would read an empty screen.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('REV35-UI-8. an approval refused for a missing class shows the '
      'classification-specific message, not the generic one', (tester) async {
    _useTallViewport(tester);
    final db = await firestoreWithProduct(_pendingProduct);
    await tester.pumpWidget(
      _testApp(
        PilotProductApprovalDetailPage(
          businessId: 'business-1',
          productId: 'product-1',
          firestoreOverride: db,
          callableInvoker: _withReadiness(_readyReadiness, (name, data) async {
            throw FirebaseFunctionsException(
              code: 'failed-precondition',
              message: 'Product is not eligible for pilot approval',
              details: {'reasonCode': 'pilot-class-missing-or-invalid'},
            );
          }),
        ),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PilotProductApprovalDetailPage)),
    )!;

    await tester.tap(find.byKey(const Key('pilotApprovalCategoryDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.pilotAdminCategoryFood).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(ElevatedButton, l10n.pilotAdminApproveButton),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(TextButton, l10n.pilotAdminApproveButton),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.pilotAdminErrorClassMissing), findsOneWidget);
    expect(find.text(l10n.pilotAdminErrorGeneric), findsNothing);
  });

  // =====================================================================
  // Marketplace Revision 36 — the server-authoritative approval handshake.
  //
  // The screen must never decide for itself that a product is approvable,
  // never compute a fingerprint, and never re-submit on the admin's behalf.
  // =====================================================================

  testWidgets(
    'REV36-UI-1. Approve stays disabled while readiness is loading, and the '
    'loading state is shown',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct(_pendingProduct);
      final gate = Completer<Object?>();
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: (name, data) async {
              if (name == 'getPilotProductApprovalReadiness') {
                return gate.future;
              }
              return const <String, dynamic>{};
            },
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;

      expect(find.byKey(const Key('pilotReadinessLoading')), findsOneWidget);
      expect(find.text(l10n.pilotAdminReadinessLoading), findsOneWidget);

      // The readiness spinner animates for as long as the call is unanswered,
      // so `pumpAndSettle` would never return here — explicit frames are what
      // let this test observe the in-flight state at all.
      Future<void> pumpFrames() async {
        for (var i = 0; i < 6; i += 1) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      // Even with the category chosen and the attestation ticked, an
      // unanswered readiness call keeps Approve disabled.
      await tester.tap(find.byKey(const Key('pilotApprovalCategoryDropdown')));
      await pumpFrames();
      await tester.tap(find.text(l10n.pilotAdminCategoryFood).last);
      await pumpFrames();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      final ElevatedButton approve = tester.widget(
        find.byKey(const Key('pilotApproveButton')),
      );
      expect(approve.onPressed, isNull);

      gate.complete(_readyReadiness);
      await tester.pumpAndSettle();
      // Once the server answers `ready`, the same button becomes enabled —
      // proving the disabled state above was the readiness gate and not some
      // other unmet precondition.
      final ElevatedButton afterReady = tester.widget(
        find.byKey(const Key('pilotApproveButton')),
      );
      expect(afterReady.onPressed, isNotNull);
    },
  );

  testWidgets(
    'REV36-UI-2. a blocked readiness disables Approve and shows the reason '
    'that matches the server code, never a generic failure',
    (tester) async {
      _useTallViewport(tester);
      final cases = <String, String Function(AppLocalizations)>{
        'readiness-decision-missing': (l) =>
            l.pilotAdminReadinessDecisionMissing,
        'readiness-decision-expired': (l) =>
            l.pilotAdminReadinessDecisionExpired,
        'readiness-evidence-stale': (l) => l.pilotAdminReadinessEvidenceStale,
        'readiness-policy-mismatch': (l) => l.pilotAdminReadinessPolicyMismatch,
        'readiness-class-missing': (l) => l.pilotAdminErrorClassMissing,
        'readiness-generation-mismatch': (l) =>
            l.pilotAdminErrorStaleGeneration,
      };
      for (final entry in cases.entries) {
        final db = await firestoreWithProduct(_pendingProduct);
        await tester.pumpWidget(
          _testApp(
            PilotProductApprovalDetailPage(
              key: ValueKey(entry.key),
              businessId: 'business-1',
              productId: 'product-1',
              firestoreOverride: db,
              callableInvoker: _withReadiness({
                ..._blockedReadiness,
                'reasonCode': entry.key,
              }),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(PilotProductApprovalDetailPage)),
        )!;

        expect(
          find.text(entry.value(l10n)),
          findsOneWidget,
          reason: 'unmapped readiness reason ${entry.key}',
        );
        expect(find.text(l10n.pilotAdminErrorGeneric), findsNothing);

        await tester.tap(
          find.byKey(const Key('pilotApprovalCategoryDropdown')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.pilotAdminCategoryFood).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        final ElevatedButton approve = tester.widget(
          find.byKey(const Key('pilotApproveButton')),
        );
        expect(
          approve.onPressed,
          isNull,
          reason: 'Approve must stay disabled for ${entry.key}',
        );
      }
    },
  );

  testWidgets(
    'REV36-UI-3. a ready state submits the exact server fingerprint and '
    'nothing the client derived',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct(_pendingProduct);
      final approveCalls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: (name, data) async {
              if (name == 'getPilotProductApprovalReadiness') {
                return _readyReadiness;
              }
              approveCalls.add(data);
              return const <String, dynamic>{'active': true};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;
      expect(find.byKey(const Key('pilotReadinessReady')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pilotApprovalCategoryDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminCategoryFood).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pilotApproveButton')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, l10n.pilotAdminApproveButton),
      );
      await tester.pumpAndSettle();

      expect(approveCalls.length, 1);
      expect(
        approveCalls.single['reviewedContentFingerprint'],
        _readyReadiness['approvalFingerprint'],
      );
      expect(find.text(l10n.pilotAdminApproveSucceeded), findsOneWidget);
    },
  );

  testWidgets(
    'REV36-UI-4. a stale approval reloads readiness and requires a new '
    'explicit tap — never an automatic retry',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct(_pendingProduct);
      var readinessCalls = 0;
      var approveCalls = 0;
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: (name, data) async {
              if (name == 'getPilotProductApprovalReadiness') {
                readinessCalls += 1;
                return _readyReadiness;
              }
              approveCalls += 1;
              throw FirebaseFunctionsException(
                code: 'failed-precondition',
                message: 'Reviewed content is stale',
                details: {'reasonCode': 'stale-content'},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;
      expect(readinessCalls, 1);

      await tester.tap(find.byKey(const Key('pilotApprovalCategoryDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminCategoryFood).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pilotApproveButton')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, l10n.pilotAdminApproveButton),
      );
      await tester.pumpAndSettle();

      // Exactly one approval attempt, and readiness was reloaded once.
      expect(approveCalls, 1, reason: 'the client must never auto-retry');
      expect(readinessCalls, 2, reason: 'readiness must be reloaded');
      expect(find.text(l10n.pilotAdminReadinessStale), findsOneWidget);
    },
  );

  testWidgets(
    'REV36-UI-5. a double tap on Approve produces exactly one invocation',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct(_pendingProduct);
      var approveCalls = 0;
      final gate = Completer<Object?>();
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: (name, data) async {
              if (name == 'getPilotProductApprovalReadiness') {
                return _readyReadiness;
              }
              approveCalls += 1;
              return gate.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;

      await tester.tap(find.byKey(const Key('pilotApprovalCategoryDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminCategoryFood).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      await tester.tap(find.byKey(const Key('pilotApproveButton')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, l10n.pilotAdminApproveButton),
      );
      await tester.pump();

      // A FULL second attempt while the first call is still in flight: tap
      // Approve again AND try to confirm it. Only completing the second cycle
      // proves the in-flight guard rather than the confirmation dialog — a
      // second Approve tap alone merely opens a dialog and would never invoke
      // anything even with the guard removed.
      await tester.tap(
        find.byKey(const Key('pilotApproveButton')),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.tap(
        find.widgetWithText(TextButton, l10n.pilotAdminApproveButton),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(
        approveCalls,
        1,
        reason: 'the in-flight guard must refuse a second submission',
      );

      gate.complete(const <String, dynamic>{'active': true});
      await tester.pumpAndSettle();
      expect(approveCalls, 1);
    },
  );

  testWidgets(
    'REV36-UI-6. a successful approval re-reads authoritative state, and a '
    'classification change invalidates readiness',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct(_pendingProduct);
      var readinessCalls = 0;
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: (name, data) async {
              if (name == 'getPilotProductApprovalReadiness') {
                readinessCalls += 1;
                return _readyReadiness;
              }
              if (name == 'setPilotProductClassification') {
                return const <String, dynamic>{
                  'changed': true,
                  'idempotent': false,
                  'unpublished': false,
                };
              }
              return const <String, dynamic>{'active': true};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;
      expect(readinessCalls, 1);

      // A classification change moves a readiness-bound input.
      await tester.tap(find.byKey(const Key('pilotClassificationDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminClassSealedWetFood).last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('pilotClassificationReasonField')),
        'Reclassified.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('pilotClassificationSaveButton')));
      await tester.pumpAndSettle();
      expect(
        readinessCalls,
        greaterThan(1),
        reason: 'a classification change must invalidate readiness',
      );

      final afterClassify = readinessCalls;
      await tester.tap(find.byKey(const Key('pilotApprovalCategoryDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminCategoryFood).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pilotApproveButton')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, l10n.pilotAdminApproveButton),
      );
      await tester.pumpAndSettle();
      expect(
        readinessCalls,
        greaterThan(afterClassify),
        reason: 'a successful approval must refresh authoritative state',
      );
    },
  );

  testWidgets(
    'REV36-UI-7. the explicit re-check control reloads readiness on demand',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct(_pendingProduct);
      var readinessCalls = 0;
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: (name, data) async {
              if (name == 'getPilotProductApprovalReadiness') {
                readinessCalls += 1;
                return _blockedReadiness;
              }
              return const <String, dynamic>{};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(readinessCalls, 1);
      await tester.tap(find.byKey(const Key('pilotReadinessRefreshButton')));
      await tester.pumpAndSettle();
      expect(readinessCalls, 2);
    },
  );

  testWidgets(
    'REV36-UI-8. a readiness call that itself fails leaves Approve disabled',
    (tester) async {
      _useTallViewport(tester);
      final db = await firestoreWithProduct(_pendingProduct);
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: (name, data) async {
              if (name == 'getPilotProductApprovalReadiness') {
                throw FirebaseFunctionsException(
                  code: 'permission-denied',
                  message: 'Admin only',
                );
              }
              return const <String, dynamic>{};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;
      await tester.tap(find.byKey(const Key('pilotApprovalCategoryDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminCategoryFood).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      final ElevatedButton approve = tester.widget(
        find.byKey(const Key('pilotApproveButton')),
      );
      expect(approve.onPressed, isNull);
    },
  );
}
