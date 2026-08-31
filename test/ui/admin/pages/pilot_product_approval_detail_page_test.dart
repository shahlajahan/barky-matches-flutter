import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/admin/pages/pilot_product_approval_detail_page.dart';
import 'package:barky_matches_fixed/ui/admin/pilot_product_fingerprint.dart';
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

void main() {
  testWidgets('a not-found product shows the not-found message', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await tester.pumpWidget(
      _testApp(
        PilotProductApprovalDetailPage(
          businessId: 'business-1',
          productId: 'missing-product',
          firestoreOverride: db,
        ),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PilotProductApprovalDetailPage)),
    )!;
    expect(find.text(l10n.pilotAdminErrorNotFound), findsOneWidget);
  });

  testWidgets(
    'a pending product renders the approve section with the '
    'approve button disabled until a category is chosen and attested',
    (tester) async {
      final db = await firestoreWithProduct(_pendingProduct);
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
      expect(find.text(l10n.pilotAdminApproveButton), findsOneWidget);
      final approveButtonFinder = find.widgetWithText(
        ElevatedButton,
        l10n.pilotAdminApproveButton,
      );
      ElevatedButton approveButton = tester.widget(approveButtonFinder);
      expect(approveButton.onPressed, isNull);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pilotAdminCategoryFood).last);
      await tester.pumpAndSettle();
      approveButton = tester.widget(approveButtonFinder);
      expect(approveButton.onPressed, isNull); // still not attested

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      approveButton = tester.widget(approveButtonFinder);
      expect(approveButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'confirming approval invokes approvePilotProduct with the correct '
    'businessId/productId/category/attestation and a fingerprint matching '
    'computePilotProductContentFingerprint',
    (tester) async {
      final db = await firestoreWithProduct(_pendingProduct);
      String? capturedName;
      Map<String, dynamic>? capturedData;
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: (name, data) async {
              capturedName = name;
              capturedData = data;
              return {'businessId': 'business-1', 'productId': 'product-1'};
            },
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;

      await tester.tap(find.byType(DropdownButtonFormField<String>));
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
      expect(
        capturedData!['reviewedContentFingerprint'],
        computePilotProductContentFingerprint(_pendingProduct),
      );
    },
  );

  testWidgets(
    'declining the approval confirmation dialog never invokes the '
    'callable',
    (tester) async {
      final db = await firestoreWithProduct(_pendingProduct);
      var invoked = false;
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: (name, data) async {
              invoked = true;
              return null;
            },
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;
      await tester.tap(find.byType(DropdownButtonFormField<String>));
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
    },
  );

  testWidgets(
    'an already-active-approved product renders the revoke section, and '
    'confirming revoke with "content changed" invokes '
    'revokePilotProductApproval with that reasonCode',
    (tester) async {
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
            callableInvoker: (name, data) async {
              capturedName = name;
              capturedData = data;
              return {'businessId': 'business-1', 'productId': 'product-1'};
            },
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
      final db = await firestoreWithProduct(_pendingProduct);
      await tester.pumpWidget(
        _testApp(
          PilotProductApprovalDetailPage(
            businessId: 'business-1',
            productId: 'product-1',
            firestoreOverride: db,
            callableInvoker: (name, data) async {
              throw FirebaseFunctionsException(
                code: 'resource-exhausted',
                message: 'Active pilot product limit reached',
                details: {'reasonCode': 'limit-exceeded'},
              );
            },
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalDetailPage)),
      )!;
      await tester.tap(find.byType(DropdownButtonFormField<String>));
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
}
