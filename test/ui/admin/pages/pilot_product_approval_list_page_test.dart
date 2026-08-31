import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/admin/pages/pilot_product_approval_detail_page.dart';
import 'package:barky_matches_fixed/ui/admin/pages/pilot_product_approval_list_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// Revision 28 pilot product approval contract — no prior test file
// exists for this page. Firebase core mocks are initialized only so
// tapping through to PilotProductApprovalDetailPage (which does not
// itself accept a firestoreOverride from this page — see that page's
// own doc comment on why the seam is not threaded through navigation)
// does not throw during widget construction; the pushed detail page's
// own real Firestore stream is never awaited to completion here, only
// the navigation itself is proven.

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

Future<FakeFirebaseFirestore> seededFirestore(
  List<MapEntry<String, Map<String, dynamic>>> products,
) async {
  final db = FakeFirebaseFirestore();
  await db.collection('businesses').doc('business-1').set({'name': 'Biz 1'});
  for (final entry in products) {
    await db
        .collection('businesses')
        .doc('business-1')
        .collection('products')
        .doc(entry.key)
        .set(entry.value);
  }
  return db;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('shows the empty state when no product is pending review', (
    tester,
  ) async {
    final db = await seededFirestore(const []);
    await tester.pumpWidget(
      _testApp(PilotProductApprovalListPage(firestoreOverride: db)),
    );
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PilotProductApprovalListPage)),
    )!;
    expect(find.text(l10n.pilotAdminListEmpty), findsOneWidget);
  });

  testWidgets(
    'lists a product with isActive:false, moderationStatus:pending_review',
    (tester) async {
      final db = await seededFirestore([
        MapEntry('product-1', {
          'businessId': 'business-1',
          'name': 'Premium dog food',
          'price': 149,
          'currency': 'TRY',
          'isActive': false,
          'moderationStatus': 'pending_review',
        }),
      ]);
      await tester.pumpWidget(
        _testApp(PilotProductApprovalListPage(firestoreOverride: db)),
      );
      await tester.pump();
      expect(find.text('Premium dog food'), findsOneWidget);
    },
  );

  testWidgets(
    'excludes an already-approved product (isActive:true, '
    'moderationStatus:approved)',
    (tester) async {
      final db = await seededFirestore([
        MapEntry('product-approved', {
          'businessId': 'business-1',
          'name': 'Already approved food',
          'price': 99,
          'currency': 'TRY',
          'isActive': true,
          'moderationStatus': 'approved',
        }),
      ]);
      await tester.pumpWidget(
        _testApp(PilotProductApprovalListPage(firestoreOverride: db)),
      );
      await tester.pump();
      expect(find.text('Already approved food'), findsNothing);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalListPage)),
      )!;
      expect(find.text(l10n.pilotAdminListEmpty), findsOneWidget);
    },
  );

  testWidgets(
    'a revoked product (back to pending_review) shows the revoked status '
    'label',
    (tester) async {
      final db = await seededFirestore([
        MapEntry('product-revoked', {
          'businessId': 'business-1',
          'name': 'Revoked food',
          'price': 50,
          'currency': 'TRY',
          'isActive': false,
          'moderationStatus': 'pending_review',
          'pilotProductApproval': {
            'active': false,
            'revokedAt': Timestamp.now(),
          },
        }),
      ]);
      await tester.pumpWidget(
        _testApp(PilotProductApprovalListPage(firestoreOverride: db)),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PilotProductApprovalListPage)),
      )!;
      // The revoked label is joined with the price into a single
      // subtitle Text ("50 TRY • Revoked — needs re-approval"), so
      // find.text (exact match) would never match — textContaining is
      // the correct finder here.
      expect(find.textContaining(l10n.pilotStatusRevoked), findsOneWidget);
    },
  );

  testWidgets('tapping a pending product navigates to the detail page', (
    tester,
  ) async {
    final db = await seededFirestore([
      MapEntry('product-1', {
        'businessId': 'business-1',
        'name': 'Premium dog food',
        'price': 149,
        'currency': 'TRY',
        'isActive': false,
        'moderationStatus': 'pending_review',
      }),
    ]);
    await tester.pumpWidget(
      _testApp(PilotProductApprovalListPage(firestoreOverride: db)),
    );
    await tester.pump();
    await tester.tap(find.text('Premium dog food'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PilotProductApprovalDetailPage), findsOneWidget);
  });
}
