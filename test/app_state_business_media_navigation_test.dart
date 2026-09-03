import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seller Settings → Business Media is reached through the same business
/// sub-page mechanism the Pet Shop dashboard already uses for Products,
/// Orders, Returns and Settings. These tests pin that navigation contract:
/// the entry exists, it is distinct from Settings, and closing returns the
/// seller to the dashboard rather than stranding them on the media page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  AppState buildAppState() => AppState(
    favoriteDogs: <Dog>[],
    favoriteDogsNotifier: ValueNotifier<List<Dog>>(<Dog>[]),
    likesNotifier: ValueNotifier<Map<String, List<String>>>(
      <String, List<String>>{},
    ),
    onToggleFavorite: (_) async {},
    notificationService: NotificationService(),
    currentUserId: 'test-user',
  );

  test('1. the Business Media sub-page is a distinct destination', () {
    // A dedicated value, not a reuse of petshopSettings: the media page and
    // the profile editor are separate surfaces with separate write paths.
    expect(BusinessSubPage.values, contains(BusinessSubPage.petshopMedia));
    expect(
      BusinessSubPage.petshopMedia,
      isNot(BusinessSubPage.petshopSettings),
    );
    expect(BusinessSubPage.petshopMedia, isNot(BusinessSubPage.none));
  });

  test('1b. opening Business Media selects exactly that sub-page', () {
    final state = buildAppState();
    addTearDown(state.dispose);

    expect(state.businessSubPage, BusinessSubPage.none);

    state.openPetShopMedia();
    expect(state.businessSubPage, BusinessSubPage.petshopMedia);

    state.closeBusinessSubPage();
    expect(state.businessSubPage, BusinessSubPage.none);
  });

  test('1c. Business Media and Settings do not shadow each other', () {
    final state = buildAppState();
    addTearDown(state.dispose);

    state.openPetShopSettings();
    expect(state.businessSubPage, BusinessSubPage.petshopSettings);

    state.openPetShopMedia();
    expect(
      state.businessSubPage,
      BusinessSubPage.petshopMedia,
      reason: 'media must replace settings, not be swallowed by it',
    );

    state.openPetShopSettings();
    expect(state.businessSubPage, BusinessSubPage.petshopSettings);
  });

  test('1d. opening the media page notifies listeners', () {
    final state = buildAppState();
    addTearDown(state.dispose);

    var notifications = 0;
    state.addListener(() => notifications += 1);

    state.openPetShopMedia();
    expect(notifications, greaterThan(0));
  });
}
