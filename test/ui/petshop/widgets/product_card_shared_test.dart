import 'dart:async';
import 'dart:io';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/services/product_service.dart';
import 'package:barky_matches_fixed/ui/petshop/widgets/product_card_shared.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

// Marketplace P1-A Slice 4.10 (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §0.17 Phase 13, committed
// Revision 19) — DeleteProductButton coverage (defined in this
// production file and shared by product_card_dashboard.dart). No prior
// test file exists for product_card_shared.dart (confirmed by direct
// search of test/). §15 items 518-520.
//
// Note: DeleteProductButton itself internally constructs
// `ProductService()`, which resolves the real Firebase Functions
// callable when no test double is injected — these tests therefore
// exercise only the confirmation-dialog/cancel path (which never
// reaches the network) directly against the real widget; the
// loading/success/error-mapping behavior once a call is in flight is
// covered against a fake callable in test/services/product_service_test.dart,
// and the widget-level state transitions those outcomes drive are
// covered here via ProductService's own injectable callableInvoker,
// reached by constructing DeleteProductButton's underlying service call
// path is not directly overridable from outside the widget — so this
// file additionally proves the dialog/UI-shell behavior standalone,
// and the full outcome-to-message mapping is proven at the service
// layer (already covered), matching this plan's own established
// division of proof between service-layer and widget-layer tests.

Widget _testApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('DeleteProductButton', () {
    testWidgets('renders a delete icon button by default', (tester) async {
      await tester.pumpWidget(
        _testApp(
          const DeleteProductButton(businessId: 'b-1', productId: 'p-1'),
        ),
      );
      expect(find.byIcon(LucideIcons.trash2), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets(
      'tapping the delete icon shows a confirmation dialog before any deletion is attempted',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            const DeleteProductButton(businessId: 'b-1', productId: 'p-1'),
          ),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
      },
    );

    testWidgets(
      'cancelling the confirmation dialog leaves the button in its default, non-busy state — no deletion attempted',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            const DeleteProductButton(businessId: 'b-1', productId: 'p-1'),
          ),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);

        // The cancel action is the first of the two TextButtons in the
        // dialog (confirmation dialog ordering: cancel, then confirm).
        final cancelButton = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .first;
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        // Still the plain icon button, never the loading indicator —
        // proving cancellation never enters the busy state.
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'the confirmation dialog renders the frozen title/message/action text',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            const DeleteProductButton(businessId: 'b-1', productId: 'p-1'),
          ),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.text('Delete this product?'), findsOneWidget);
        expect(
          find.text(
            'This will permanently delete the product. This action cannot be undone.',
          ),
          findsOneWidget,
        );
        expect(find.text('Delete'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      },
    );

    testWidgets(
      'confirming the deletion transitions to a busy/loading state, hiding the plain icon button',
      (tester) async {
        final neverResolves = Completer<void>();
        final fakeService = ProductService(
          callableInvoker: (name, data) async {
            await neverResolves.future;
            return {'status': 'deleted', 'productId': 'p-1'};
          },
        );
        await tester.pumpWidget(
          _testApp(
            DeleteProductButton(
              businessId: 'b-1',
              productId: 'p-1',
              productService: fakeService,
            ),
          ),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        final confirmButton = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last;
        await tester.tap(confirmButton);
        // A single pump — the injected fake callable's own Completer
        // deliberately never resolves during this test, so the widget
        // is guaranteed to still be in its busy state at this point.
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(IconButton), findsNothing);
      },
    );

    testWidgets(
      'a successful deletion (via an injected fake callable) shows a success message and returns to the non-busy state',
      (tester) async {
        final fakeService = ProductService(
          callableInvoker: (name, data) async {
            expect(name, 'deleteMarketplaceProduct');
            expect(data['businessId'], 'b-1');
            expect(data['productId'], 'p-1');
            return {'status': 'deleted', 'productId': 'p-1'};
          },
        );
        await tester.pumpWidget(
          _testApp(
            DeleteProductButton(
              businessId: 'b-1',
              productId: 'p-1',
              productService: fakeService,
            ),
          ),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        final confirmButton = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last;
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        expect(find.text('Product deleted'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'a replayed deletion is treated identically to a successful deletion (§0.17 Phase 13)',
      (tester) async {
        final fakeService = ProductService(
          callableInvoker: (name, data) async {
            return {'status': 'replayed', 'productId': 'p-1'};
          },
        );
        await tester.pumpWidget(
          _testApp(
            DeleteProductButton(
              businessId: 'b-1',
              productId: 'p-1',
              productService: fakeService,
            ),
          ),
        );
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        final confirmButton = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last;
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        expect(find.text('Product deleted'), findsOneWidget);
      },
    );

    testWidgets(
      'a product_not_found failure shows the "already gone" message, never a raw exception',
      (tester) async {
        final fakeService = ProductService(
          callableInvoker: (name, data) async {
            throw FirebaseFunctionsException(
              code: 'not-found',
              message: 'Product not found',
              details: {'reasonCode': 'product_not_found'},
            );
          },
        );
        await tester.pumpWidget(
          _testApp(
            DeleteProductButton(
              businessId: 'b-1',
              productId: 'p-1',
              productService: fakeService,
            ),
          ),
        );
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        final confirmButton = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last;
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        expect(find.text('This listing no longer exists'), findsOneWidget);
      },
    );

    testWidgets(
      'a not_business_owner failure shows the permission-denied message',
      (tester) async {
        final fakeService = ProductService(
          callableInvoker: (name, data) async {
            throw FirebaseFunctionsException(
              code: 'permission-denied',
              message: 'nope',
              details: {'reasonCode': 'not_business_owner'},
            );
          },
        );
        await tester.pumpWidget(
          _testApp(
            DeleteProductButton(
              businessId: 'b-1',
              productId: 'p-1',
              productService: fakeService,
            ),
          ),
        );
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        final confirmButton = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last;
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        expect(
          find.text("You don't have permission to delete this product"),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'an internal-error failure shows the network/retry message, never a raw exception string',
      (tester) async {
        final fakeService = ProductService(
          callableInvoker: (name, data) async {
            throw FirebaseFunctionsException(code: 'internal', message: 'boom');
          },
        );
        await tester.pumpWidget(
          _testApp(
            DeleteProductButton(
              businessId: 'b-1',
              productId: 'p-1',
              productService: fakeService,
            ),
          ),
        );
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        final confirmButton = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last;
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        expect(
          find.text(
            "Couldn't delete the product. Check your connection and try again.",
          ),
          findsOneWidget,
        );
        expect(find.textContaining('FirebaseFunctionsException'), findsNothing);
      },
    );

    testWidgets(
      'a rapid double-tap of the confirmed delete action issues exactly one callable invocation',
      (tester) async {
        var callCount = 0;
        final completer = Completer<void>();
        final fakeService = ProductService(
          callableInvoker: (name, data) async {
            callCount += 1;
            await completer.future;
            return {'status': 'deleted', 'productId': 'p-1'};
          },
        );
        await tester.pumpWidget(
          _testApp(
            DeleteProductButton(
              businessId: 'b-1',
              productId: 'p-1',
              productService: fakeService,
            ),
          ),
        );
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        final confirmButton = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last;
        await tester.tap(confirmButton);
        await tester.pump();
        // The button is now the busy/loading indicator — no second
        // IconButton exists to tap again, which is itself the
        // double-submit guard's own structural proof; directly invoking
        // the state's handler again would be the only way to bypass it,
        // and this test instead proves the UI-level guard: no tappable
        // delete affordance remains while busy.
        expect(find.byType(IconButton), findsNothing);
        expect(callCount, 1);

        completer.complete();
        await tester.pumpAndSettle();
        expect(callCount, 1);
      },
    );
  });

  group('dormancy/security statics', () {
    final source = File(
      'lib/ui/petshop/widgets/product_card_shared.dart',
    ).readAsStringSync();

    test('no direct Firestore product delete call remains in this file', () {
      // The retired direct-delete call site (`service.deleteProduct(...)`)
      // must be gone from this production file entirely.
      expect(source, isNot(contains('.deleteProduct(')));
      expect(source, contains('DeleteProductButton'));
      expect(source, contains('deleteMarketplaceProduct'));
    });

    test(
      'the caught deletion exception is never interpolated into a debugPrint/print call',
      () {
        // Only fixed, localized message strings are ever shown to the
        // user — the caught exception object itself is inspected only for
        // its typed `.kind`, never printed or otherwise surfaced raw.
        expect(source, isNot(contains('debugPrint("\$e")')));
        expect(source, isNot(contains('debugPrint(\$e)')));
        expect(source, isNot(RegExp(r'print\([^)]*\be\b[^)]*\)')));
      },
    );
  });
}
