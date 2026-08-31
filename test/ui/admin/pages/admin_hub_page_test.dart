import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/admin/pages/admin_hub_page.dart';
import 'package:barky_matches_fixed/ui/admin/pages/pilot_product_approval_list_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// Revision 28 pilot product approval contract — no prior test file
// exists for admin_hub_page.dart (confirmed by direct search of test/).
// Firebase is initialized via the platform-interface test mocks only so
// PilotProductApprovalListPage's own `FirebaseFirestore.instance` field
// access does not throw during navigation — matching this repo's
// established pattern (test/ui/business/petshop/product_save_plan_test.dart).
// No real backend call is ever awaited to completion; assertions only
// examine the AppBar/static shell, never the stream's own data.

Widget _testApp(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('renders the admin panel title bar', (tester) async {
    await tester.pumpWidget(_testApp(const AdminHubPage()));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(AdminHubPage)),
    )!;
    expect(find.text(l10n.userProfileAdminPanel), findsOneWidget);
  });

  testWidgets(
    'renders the Pilot Product Approvals tile with its localized title '
    'and subtitle',
    (tester) async {
      await tester.pumpWidget(_testApp(const AdminHubPage()));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AdminHubPage)),
      )!;
      final titleFinder = find.text(l10n.adminHubPilotProductApprovalsTitle);
      await tester.scrollUntilVisible(titleFinder, 300);
      expect(titleFinder, findsOneWidget);
      expect(
        find.text(l10n.adminHubPilotProductApprovalsSubtitle),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping the Pilot Product Approvals tile navigates to '
    'PilotProductApprovalListPage',
    (tester) async {
      await tester.pumpWidget(_testApp(const AdminHubPage()));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AdminHubPage)),
      )!;
      final titleFinder = find.text(l10n.adminHubPilotProductApprovalsTitle);
      await tester.scrollUntilVisible(titleFinder, 300);
      await tester.tap(titleFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // find.text(l10n.pilotAdminListTitle) is deliberately not also
      // asserted here: the English translation happens to be identical
      // to adminHubPilotProductApprovalsTitle, and the hub page's own
      // tile (still present underneath the pushed route) would make
      // that finder ambiguous. The widget-type check below is the
      // unambiguous proof that navigation actually occurred.
      expect(find.byType(PilotProductApprovalListPage), findsOneWidget);
    },
  );
}
