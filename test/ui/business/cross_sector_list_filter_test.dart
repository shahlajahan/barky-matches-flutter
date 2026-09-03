import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/groomy_page.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'package:barky_matches_fixed/pet_hotel_page.dart';
import 'package:barky_matches_fixed/ui/business/business_card.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'package:barky_matches_fixed/ui/vet/vet_card.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// End-to-end proof that a Pet Shop cannot reach the Groomy or Pet Hotel list.
///
/// Both pages read the same `businesses_public` collection with only a
/// `status == approved` predicate, so the client-side sector filter is the
/// only thing separating the sectors. These tests drive the real pages over a
/// mixed result set: the Pet Shop deliberately carries a "Grooming" shop type
/// and hotel-related product text, exactly the content that used to leak.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  const groomyId = 'groomy-business';
  const hotelId = 'pet-hotel-business';
  const petShopId = 'pet-shop-business';
  const legacyHotelId = 'legacy-hotel-business';

  Future<FakeFirebaseFirestore> seedFirestore() async {
    final firestore = FakeFirebaseFirestore();
    final businesses = firestore.collection('businesses_public');

    await businesses.doc(groomyId).set({
      'status': 'approved',
      'sectors': ['groomy'],
      'profile': {'displayName': 'Bella Grooming'},
      'contact': {'city': 'Istanbul'},
      'publicSectorData': {
        'groomy': {'services': <dynamic>[]},
      },
    });

    await businesses.doc(hotelId).set({
      'status': 'approved',
      'sectors': ['pet_hotel'],
      'profile': {'displayName': 'Cozy Pet Hotel'},
      'contact': {'city': 'Istanbul'},
      'publicSectorData': {
        'pet_hotel': {'amenities': <dynamic>[]},
      },
    });

    // Supported legacy shape: no canonical sectors array, membership carried
    // only by the recognized `hotel` sector-map key.
    await businesses.doc(legacyHotelId).set({
      'status': 'approved',
      'sectors': <String>[],
      'profile': {'displayName': 'Legacy Boarding House'},
      'contact': {'city': 'Izmir'},
      'publicSectorData': {
        'hotel': {'amenities': <dynamic>[]},
      },
    });

    // The regression fixture: a canonical Pet Shop whose legitimate product
    // data mentions grooming, hotels, boarding and "kuafor".
    await businesses.doc(petShopId).set({
      'status': 'approved',
      'sectors': ['pet_shop'],
      'profile': {
        'displayName': 'Pharos',
        'categories': ['Grooming Tools', 'Hotel Beds'],
        'tags': ['boarding'],
      },
      'contact': {'city': 'Istanbul'},
      'publicSectorData': {
        'petshop': {
          'shopName': 'Pharos',
          'shopTypes': ['Pet Food', 'Grooming'],
          'categories': ['Boarding Accessories', 'Beds for hotel stays'],
          'brands': 'GroomPro',
          'profileContent': {'bio': 'Kuafor ve pansiyon urunleri'},
        },
      },
    });

    return firestore;
  }

  AppState buildAppState() {
    return AppState(
      favoriteDogs: <Dog>[],
      favoriteDogsNotifier: ValueNotifier<List<Dog>>(<Dog>[]),
      likesNotifier: ValueNotifier<Map<String, List<String>>>(
        <String, List<String>>{},
      ),
      onToggleFavorite: (_) async {},
      notificationService: NotificationService(),
      currentUserId: 'test-user',
    );
  }

  Widget harness(AppState appState, Widget page) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: page),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('the Groomy list excludes a Pet Shop selling grooming products', (
    tester,
  ) async {
    final firestore = await seedFirestore();
    final appState = buildAppState();

    await tester.pumpWidget(
      harness(appState, GroomyPage(firestore: firestore)),
    );
    await settle(tester);

    final cards = tester
        .widgetList<BusinessCard>(find.byType(BusinessCard))
        .toList();

    expect(cards.map((card) => card.data.id).toList(), [groomyId]);
    expect(cards.map((card) => card.data.id), isNot(contains(petShopId)));
  });

  testWidgets('the Pet Hotel list excludes a Pet Shop selling hotel products', (
    tester,
  ) async {
    final firestore = await seedFirestore();
    final appState = buildAppState();

    await tester.pumpWidget(
      harness(appState, PetHotelPage(firestore: firestore)),
    );
    await settle(tester);

    final cards = tester.widgetList<VetCard>(find.byType(VetCard)).toList();
    final ids = cards.map((card) => card.data.id).toList()..sort();

    expect(ids, [hotelId, legacyHotelId]..sort());
    expect(ids, isNot(contains(petShopId)));
  });

  testWidgets('legitimate Groomy and Pet Hotel businesses stay visible', (
    tester,
  ) async {
    final firestore = await seedFirestore();

    await tester.pumpWidget(
      harness(buildAppState(), GroomyPage(firestore: firestore)),
    );
    await settle(tester);
    expect(find.text('Bella Grooming'), findsOneWidget);
    expect(find.text('No grooming businesses found.'), findsNothing);

    await tester.pumpWidget(
      harness(buildAppState(), PetHotelPage(firestore: firestore)),
    );
    await settle(tester);
    expect(find.text('Cozy Pet Hotel'), findsOneWidget);
    expect(find.text('Legacy Boarding House'), findsOneWidget);
    expect(find.text('No pet hotels found.'), findsNothing);
  });

  testWidgets('a Pet Shop cannot be force-typed into a Groomy card', (
    tester,
  ) async {
    final firestore = await seedFirestore();
    final appState = buildAppState();

    await tester.pumpWidget(
      harness(appState, GroomyPage(firestore: firestore)),
    );
    await settle(tester);

    // Every card the Groomy list renders is stamped `BusinessType.groomer` and
    // routed to the Groomy details overlay, so a leaked Pet Shop would open the
    // wrong profile surface. No Pet Shop card exists to tap.
    final cards = tester
        .widgetList<BusinessCard>(find.byType(BusinessCard))
        .toList();
    final petShopCards = cards.where((card) => card.data.id == petShopId);

    expect(petShopCards, isEmpty);
    expect(
      cards.every((card) => card.data.type == BusinessType.groomer),
      isTrue,
    );
    expect(appState.activeBusiness, isNull);

    await tester.tap(find.byType(BusinessCard).first);
    await tester.pump();

    expect(appState.activeBusiness?.id, groomyId);
  });
}
