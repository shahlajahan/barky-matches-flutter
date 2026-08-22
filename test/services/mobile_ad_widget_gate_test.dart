import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'package:barky_matches_fixed/services/mobile_advertising_service.dart';
import 'package:barky_matches_fixed/subscription/models/user_subscription.dart';
import 'package:barky_matches_fixed/widgets/ads/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:provider/provider.dart';

class _UnsupportedPlatform implements MobileAdvertisingPlatform {
  @override
  bool get isSupported => false;

  @override
  Future<bool> canRequestAds() async => false;

  @override
  Future<InitializationStatus> initializeMobileAds() async {
    return InitializationStatus(const {});
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() async {}

  @override
  Future<PrivacyOptionsRequirementStatus>
  privacyOptionsRequirementStatus() async {
    return PrivacyOptionsRequirementStatus.notRequired;
  }

  @override
  Future<void> requestConsentInfoUpdate(
    ConsentRequestParameters parameters,
  ) async {}

  @override
  Future<void> showPrivacyOptionsForm() async {}
}

AppState _appState() {
  return AppState(
    favoriteDogs: const <Dog>[],
    favoriteDogsNotifier: ValueNotifier<List<Dog>>(const <Dog>[]),
    likesNotifier: ValueNotifier<Map<String, List<String>>>({}),
    onToggleFavorite: (_) async {},
    notificationService: NotificationService(),
  );
}

void main() {
  testWidgets('banner is empty before ad readiness', (tester) async {
    final ads = MobileAdvertisingService(platform: _UnsupportedPlatform());
    await ads.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: _appState()),
          ChangeNotifierProvider<MobileAdvertisingService>.value(value: ads),
        ],
        child: const MaterialApp(home: Scaffold(body: BannerAdWidget())),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.byType(AdWidget), findsNothing);
  });

  test('free subscription remains ad eligible', () {
    final subscription = UserSubscription.normal();

    expect(subscription.hasValidPaidAccess, isFalse);
  });

  test('active paid subscription suppresses ads while unexpired', () {
    final subscription = UserSubscription.fromMap({
      'plan': 'premium',
      'status': 'active',
      'expiresAt': DateTime.now().add(const Duration(days: 7)),
    });

    expect(subscription.hasValidPaidAccess, isTrue);
  });
}
