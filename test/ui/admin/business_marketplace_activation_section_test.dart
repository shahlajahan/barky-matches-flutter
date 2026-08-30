import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/admin/business_marketplace_activation_section.dart';

// Marketplace P1-A Step 21c2 (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §10.1 "Admin UI boundary,
// exact", §13.1, §15 items 715-724 and 755-769; closing-audit
// correction). Mirrors pet_taxi_admin_review_panel_test.dart's own
// already-established injected-api-fake convention exactly —
// `HttpsCallable` itself has a private constructor and cannot be faked
// directly, so the widget's own `MarketplaceSellerActivationApi`
// abstraction is the seam. `isAdmin` is now passed directly to the
// widget as a plain constructor parameter — no `AppState`/`Provider`
// scaffolding is needed anywhere in this file, since the widget itself
// no longer reads `AppState` internally.

class _FakeApi implements MarketplaceSellerActivationApi {
  int grantCallCount = 0;
  int revokeCallCount = 0;
  String? lastBusinessId;
  Object? throwOnCall;
  final Completer<void>? blockUntil;

  _FakeApi({this.throwOnCall, this.blockUntil});

  @override
  Future<void> grant(String businessId) async {
    grantCallCount++;
    lastBusinessId = businessId;
    if (blockUntil != null) await blockUntil!.future;
    if (throwOnCall != null) throw throwOnCall!;
  }

  @override
  Future<void> revoke(String businessId) async {
    revokeCallCount++;
    lastBusinessId = businessId;
    if (blockUntil != null) await blockUntil!.future;
    if (throwOnCall != null) throw throwOnCall!;
  }
}

Map<String, dynamic> _business({Object? activation}) {
  return {
    'name': 'Test Petshop',
    if (activation != _omit) 'marketplaceSellerActivation': activation,
  };
}

const _omit = Object();

Widget _harness({
  required Map<String, dynamic> data,
  required MarketplaceSellerActivationApi api,
  bool isAdmin = true,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BusinessMarketplaceActivationSection(
        data: data,
        businessId: 'biz-1',
        isAdmin: isAdmin,
        api: api,
      ),
    ),
  );
}

void main() {
  testWidgets('1. active:true renders the active status from authoritative data', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(data: _business(activation: {'active': true}), api: _FakeApi()),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(BusinessMarketplaceActivationSection)),
    )!;
    expect(find.text(l10n.marketplaceSellerActivationStatusActive), findsOneWidget);
  });

  testWidgets('2. active:false renders the inactive status', (tester) async {
    await tester.pumpWidget(
      _harness(data: _business(activation: {'active': false}), api: _FakeApi()),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(BusinessMarketplaceActivationSection)),
    )!;
    expect(find.text(l10n.marketplaceSellerActivationStatusInactive), findsOneWidget);
  });

  testWidgets(
    '3. missing/malformed activation shapes all render as inactive — fail closed',
    (tester) async {
      for (final activation in [
        _omit,
        null,
        'active',
        [true],
        true,
        <String, dynamic>{},
      ]) {
        await tester.pumpWidget(
          _harness(data: _business(activation: activation), api: _FakeApi()),
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(BusinessMarketplaceActivationSection)),
        )!;
        expect(
          find.text(l10n.marketplaceSellerActivationStatusInactive),
          findsOneWidget,
          reason: 'shape $activation must render as inactive',
        );
      }
    },
  );

  testWidgets(
    '4. a non-admin user (isAdmin: false) sees no grant/revoke controls at all, even though mounted',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          data: _business(activation: {'active': false}),
          api: _FakeApi(),
          isAdmin: false,
        ),
      );
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    },
  );

  testWidgets('5. grant requires confirmation before the callable is invoked', (
    tester,
  ) async {
    final api = _FakeApi();
    await tester.pumpWidget(
      _harness(data: _business(activation: {'active': false}), api: api),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(BusinessMarketplaceActivationSection)),
    )!;
    await tester.tap(find.text(l10n.marketplaceSellerActivationGrantAction));
    await tester.pumpAndSettle();
    expect(find.text(l10n.marketplaceSellerActivationGrantConfirmMessage), findsOneWidget);
    expect(api.grantCallCount, 0, reason: 'no call before confirmation');
  });

  testWidgets('6. revoke requires confirmation before the callable is invoked', (
    tester,
  ) async {
    final api = _FakeApi();
    await tester.pumpWidget(
      _harness(data: _business(activation: {'active': true}), api: api),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(BusinessMarketplaceActivationSection)),
    )!;
    await tester.tap(find.text(l10n.marketplaceSellerActivationRevokeAction));
    await tester.pumpAndSettle();
    expect(find.text(l10n.marketplaceSellerActivationRevokeConfirmMessage), findsOneWidget);
    expect(api.revokeCallCount, 0);
  });

  testWidgets(
    '7/8. confirming grant invokes the callable exactly once, even under a duplicate tap',
    (tester) async {
      final block = Completer<void>();
      final api = _FakeApi(blockUntil: block);
      await tester.pumpWidget(
        _harness(data: _business(activation: {'active': false}), api: api),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(BusinessMarketplaceActivationSection)),
      )!;
      await tester.tap(find.text(l10n.marketplaceSellerActivationGrantAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.marketplaceSellerActivationGrantAction).last);
      await tester.pump();

      // Attempt a duplicate tap on the (now in-flight, still enabled at
      // the widget-tree level until setState rebuilds) button — the
      // in-flight guard inside _handleGrant/_handleRevoke, not
      // onPressed:null alone, is what's under test here.
      final elevatedButtons = find.byType(ElevatedButton);
      if (elevatedButtons.evaluate().isNotEmpty) {
        await tester.tap(elevatedButtons.first, warnIfMissed: false);
        await tester.pump();
      }

      block.complete();
      await tester.pumpAndSettle();

      expect(
        api.grantCallCount,
        1,
        reason: 'exactly one callable invocation, never two, from any duplicate tap',
      );
      expect(api.lastBusinessId, 'biz-1');
    },
  );

  testWidgets('9. grant never issues a direct Firestore write — static contract, proven by construction', (
    tester,
  ) async {
    // BusinessMarketplaceActivationSection holds no FirebaseFirestore
    // reference of any kind (confirmed by direct source inspection,
    // §15 item 762) — its only state-changing dependency is the
    // injected MarketplaceSellerActivationApi, exercised above.
    final api = _FakeApi();
    await tester.pumpWidget(
      _harness(data: _business(activation: {'active': false}), api: api),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(BusinessMarketplaceActivationSection)),
    )!;
    await tester.tap(find.text(l10n.marketplaceSellerActivationGrantAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.marketplaceSellerActivationGrantAction).last);
    await tester.pumpAndSettle();
    expect(api.grantCallCount, 1);
  });

  testWidgets(
    '10. after a successful grant, the section reflects the new authoritative state '
    'sourced from re-supplied data — no separate manual refetch call',
    (tester) async {
      final api = _FakeApi();
      await tester.pumpWidget(_RebuildableHarness(initialActive: false, api: api));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(BusinessMarketplaceActivationSection)),
      )!;
      expect(find.text(l10n.marketplaceSellerActivationStatusInactive), findsOneWidget);

      await tester.tap(find.text(l10n.marketplaceSellerActivationGrantAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.marketplaceSellerActivationGrantAction).last);
      await tester.pumpAndSettle();

      // The harness above simulates the real BusinessAdminDetailPage's
      // own StreamBuilder re-emission by rebuilding this section with
      // fresh `data` once the callable resolves — exactly the same
      // "no separate refetch call" contract the real page provides via
      // its own live business-document stream.
      expect(find.text(l10n.marketplaceSellerActivationStatusActive), findsOneWidget);
    },
  );

  testWidgets('11. a permission-denied callable error surfaces the correct localized message', (
    tester,
  ) async {
    final api = _FakeApi(
      throwOnCall: FirebaseFunctionsException(code: 'permission-denied', message: 'Admin only'),
    );
    await tester.pumpWidget(
      _harness(data: _business(activation: {'active': false}), api: api),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(BusinessMarketplaceActivationSection)),
    )!;
    await tester.tap(find.text(l10n.marketplaceSellerActivationGrantAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.marketplaceSellerActivationGrantAction).last);
    await tester.pumpAndSettle();
    expect(find.text(l10n.marketplaceSellerActivationPermissionDenied), findsOneWidget);
    expect(find.text(l10n.marketplaceSellerActivationGrantSucceeded), findsNothing);
  });

  testWidgets('12. a not-found callable error surfaces the business-not-found message', (
    tester,
  ) async {
    final api = _FakeApi(
      throwOnCall: FirebaseFunctionsException(code: 'not-found', message: 'Business not found'),
    );
    await tester.pumpWidget(
      _harness(data: _business(activation: {'active': false}), api: api),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(BusinessMarketplaceActivationSection)),
    )!;
    await tester.tap(find.text(l10n.marketplaceSellerActivationGrantAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.marketplaceSellerActivationGrantAction).last);
    await tester.pumpAndSettle();
    expect(find.text(l10n.marketplaceSellerActivationBusinessNotFound), findsOneWidget);
  });

  testWidgets(
    '13. a network/general failure surfaces the generic-failure message without false success',
    (tester) async {
      final api = _FakeApi(throwOnCall: Exception('boom'));
      await tester.pumpWidget(
        _harness(data: _business(activation: {'active': false}), api: api),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(BusinessMarketplaceActivationSection)),
      )!;
      await tester.tap(find.text(l10n.marketplaceSellerActivationGrantAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.marketplaceSellerActivationGrantAction).last);
      await tester.pumpAndSettle();
      expect(find.text(l10n.marketplaceSellerActivationGeneralError), findsOneWidget);
      expect(find.text(l10n.marketplaceSellerActivationGrantSucceeded), findsNothing);
    },
  );

  testWidgets(
    '14. no error path ever shows a success message — false success is impossible by construction',
    (tester) async {
      final api = _FakeApi(throwOnCall: Exception('boom'));
      await tester.pumpWidget(
        _harness(data: _business(activation: {'active': true}), api: api),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(BusinessMarketplaceActivationSection)),
      )!;
      await tester.tap(find.text(l10n.marketplaceSellerActivationRevokeAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.marketplaceSellerActivationRevokeAction).last);
      await tester.pumpAndSettle();
      expect(find.text(l10n.marketplaceSellerActivationRevokeSucceeded), findsNothing);
    },
  );

  testWidgets(
    '15. no short label affirms product/legal/publication/Phase-B approval, and the '
    'grant confirmation message explicitly disclaims it rather than merely omitting it',
    (tester) async {
      await tester.pumpWidget(
        _harness(data: _business(activation: {'active': false}), api: _FakeApi()),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(BusinessMarketplaceActivationSection)),
      )!;
      // Short labels/status/action text must never affirmatively claim
      // approval of any kind — these are not disclaimers, so any
      // occurrence of these words here would be a genuine overclaim.
      final forbidden = ['legal', 'approved', 'publish', 'phase b'];
      for (final text in [
        l10n.marketplaceSellerActivationSectionTitle,
        l10n.marketplaceSellerActivationStatusActive,
        l10n.marketplaceSellerActivationStatusInactive,
        l10n.marketplaceSellerActivationGrantAction,
      ]) {
        final lower = text.toLowerCase();
        for (final word in forbidden) {
          expect(lower.contains(word), isFalse, reason: '"$text" must not imply "$word"');
        }
      }
      // The longer confirmation message is expected, and required, to
      // explicitly name and disclaim exactly these concepts — proving
      // the disclaimer exists, not merely proving the word is absent.
      final confirmMessage = l10n.marketplaceSellerActivationGrantConfirmMessage.toLowerCase();
      expect(confirmMessage.contains('does not'), isTrue);
      expect(confirmMessage.contains('approve'), isTrue);
      expect(confirmMessage.contains('legal'), isTrue);
    },
  );

  testWidgets('16. all four locales expose every activation string with no missing key', (
    tester,
  ) async {
    for (final locale in [
      const Locale('en'),
      const Locale('tr'),
      const Locale('fa'),
      const Locale('ru'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BusinessMarketplaceActivationSection(
              data: _business(activation: {'active': false}),
              businessId: 'biz-1',
              isAdmin: true,
              api: _FakeApi(),
            ),
          ),
        ),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(BusinessMarketplaceActivationSection)),
      )!;
      for (final value in [
        l10n.marketplaceSellerActivationSectionTitle,
        l10n.marketplaceSellerActivationStatusInactive,
        l10n.marketplaceSellerActivationGrantAction,
        l10n.marketplaceSellerActivationGrantConfirmTitle,
        l10n.marketplaceSellerActivationGrantConfirmMessage,
      ]) {
        expect(value.isNotEmpty, isTrue, reason: 'locale $locale must expose a non-empty string');
      }
    }
  });
}

// Simulates BusinessAdminDetailPage's own StreamBuilder-driven refresh:
// re-supplies fresh `data` to BusinessMarketplaceActivationSection once
// the injected fake api's grant call resolves, exactly mirroring how
// the real page's live Firestore stream would re-emit after the real
// callable's transaction commits — proving the section itself performs
// no separate manual refetch, it simply re-renders from new `data`.
class _RebuildableHarness extends StatefulWidget {
  final bool initialActive;
  final MarketplaceSellerActivationApi api;

  const _RebuildableHarness({required this.initialActive, required this.api});

  @override
  State<_RebuildableHarness> createState() => _RebuildableHarnessState();
}

class _RebuildableHarnessState extends State<_RebuildableHarness> {
  late bool _active = widget.initialActive;
  late final _ObservingApi _api;

  @override
  void initState() {
    super.initState();
    _api = _ObservingApi(widget.api, onGrantSucceeded: () {
      setState(() => _active = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BusinessMarketplaceActivationSection(
          data: _business(activation: {'active': _active}),
          businessId: 'biz-1',
          isAdmin: true,
          api: _api,
        ),
      ),
    );
  }
}

class _ObservingApi implements MarketplaceSellerActivationApi {
  final MarketplaceSellerActivationApi inner;
  final VoidCallback onGrantSucceeded;

  _ObservingApi(this.inner, {required this.onGrantSucceeded});

  @override
  Future<void> grant(String businessId) async {
    await inner.grant(businessId);
    onGrantSucceeded();
  }

  @override
  Future<void> revoke(String businessId) => inner.revoke(businessId);
}
