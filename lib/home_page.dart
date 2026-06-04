import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;

import 'package:flutter/foundation.dart';

import 'dog.dart';
import 'filter_page.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/utils/localization_utils.dart';
import 'package:barky_matches_fixed/app_state.dart' as app;
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'dart:async';

import 'package:barky_matches_fixed/ui/petshop/all_products_page.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'package:barky_matches_fixed/home/widgets/home_image_card.dart';
import 'package:barky_matches_fixed/home/widgets/home_search_result_card.dart';

import 'package:lucide_icons/lucide_icons.dart';
import 'package:barky_matches_fixed/widgets/ads/banner_ad_widget.dart';
import 'package:barky_matches_fixed/widgets/ads/native_ad_widget.dart';

import 'package:barky_matches_fixed/models/featured_deal.dart';
/*
class FeaturedDeal {
  final String shopName;
  final String description;
  final int discountPercent; // 15 => 15%
  final String logoAsset; // assets/brands/petshop_a_logo.png
  final bool goldOnly;
  final bool premiumOnly;

  const FeaturedDeal({
    required this.shopName,
    required this.description,
    required this.discountPercent,
    required this.logoAsset,
    this.goldOnly = false,
    this.premiumOnly = false,
  });
}
*/

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with
        AutomaticKeepAliveClientMixin,
        SingleTickerProviderStateMixin,
        LocalizationUtils {
  late Box<String> userBox;
  String? _currentUserId;
  late Box<List<String>> savedParksBox;

  List<Map<String, dynamic>> _filteredBusinesses = [];

  double _basketTop = 25;
  double _basketLeft = 320; // 👈 سمت راست
  late AnimationController _basketAnimController;
  Animation<double>? _scaleAnim;
  //String _username = 'User';
  late Box<Dog> dogsBox;

  List<Dog> _filteredDogs = [];
  List<Dog> _userDogs = [];

  final bool _isLoading = true;
  bool _isLocationLoading = true;
  final GlobalKey _safetyKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  String? selectedBreed;
  String? selectedGender;
  RangeValues? ageRange;
  bool? selectedNeutered;
  String? selectedHealthStatus;
  String _searchQuery = "";

  bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    return false;
  }

  static String _normalizeSearchText(dynamic value) {
    return (value ?? '').toString().toLowerCase().trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }

  double? _userLatitude;
  double? _userLongitude;

  double _maxDistance = 50.0;
  final bool _isPremium = false;
  final bool _isPremiumLoaded = false;

  bool _isMapReady = false;
  bool _mapInitFailed = false;

  bool _locationPermissionInProgress = false;
  bool _locationLoaded = false;

  PageController? _dealPageController;

  int _dealIndex = 0;
  Timer? _dealTimer;

  Map<String, List<Map<String, dynamic>>> dogLikes = {};

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  static const Color _cardColor = Color(0xFF9E1B4F);
  static const double _homeRadius = 20;
  static const double _sectionGap = 24;
  static const double _cardGap = 14;

  bool _bootstrapped = false;
  List<FeaturedDeal> _featuredDeals = [];
  /*
  List<FeaturedDeal> get _featuredDeals {
    final l = AppLocalizations.of(context)!;
    return [
      FeaturedDeal(
        shopName: l.petShopDealName,
        description: l.petShopDealDesc,
        discountPercent: 15,
        logoAsset: "assets/brands/petshop_a_logo.png",
        goldOnly: false,
        premiumOnly: false,
      ),
      FeaturedDeal(
        shopName: l.groomyDealName,
        description: l.groomyDealDesc,
        discountPercent: 20,
        logoAsset: "assets/brands/groomy_logo.png",
        premiumOnly: true,
      ),
      FeaturedDeal(
        shopName: l.vetDealName,
        description: l.vetDealDesc,
        discountPercent: 0,
        logoAsset: "assets/brands/vetplus_logo.png",
        goldOnly: true,
      ),
    ];
  }
*/

  Future<void> _loadFeaturedDeals() async {
    debugPrint("🔥 FEATURED LOAD START");

    try {
      final language = Localizations.localeOf(context).languageCode;

      debugPrint("🔥 LANGUAGE = $language");

      final query = FirebaseFirestore.instance
          .collection("featured_deals")
          .orderBy("order");

      debugPrint("🔥 QUERY CREATED");

      final snapshot = await query.get();

      debugPrint("🔥 SNAPSHOT RECEIVED");

      debugPrint("🔥 DOC COUNT = ${snapshot.docs.length}");

      for (final doc in snapshot.docs) {
        debugPrint("🔥 DOC ID = ${doc.id}");

        debugPrint("🔥 DOC DATA = ${doc.data()}");
      }

      final deals = snapshot.docs
          .where((doc) {
            final active = doc.data()["isActive"];

            debugPrint("🔥 ACTIVE CHECK ${doc.id} -> $active");

            return active == true;
          })
          .map((doc) {
            debugPrint("🔥 PARSING DOC ${doc.id}");

            return FeaturedDeal.fromFirestore(doc.data(), language);
          })
          .toList();

      debugPrint("🔥 DEAL PARSE FINISHED");

      debugPrint("🔥 DEAL COUNT FINAL = ${deals.length}");

      if (!mounted) {
        debugPrint("🔥 NOT MOUNTED");

        return;
      }

      setState(() {
        _featuredDeals = deals;
      });

      debugPrint("🔥 SETSTATE DONE");
    } catch (e, stack) {
      debugPrint("❌ FEATURED ERROR = $e");

      debugPrint("❌ STACK = $stack");
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    debugPrint("🔥 INIT UID: $_currentUserId");
    _dealPageController = PageController(viewportFraction: 0.92);
    _startAutoSlide();
    debugPrint(
      '🧱 HomePage initState hash=${identityHashCode(this)} key=${widget.key}',
    );

    userBox = Hive.box<String>('userBox');
    dogsBox = Hive.box<Dog>('dogsBox');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_bootstrapped) {
        _bootstrapped = true;

        debugPrint("STEP 1");

        await _syncDogsWithFirestore();

        debugPrint("STEP 2");

        await _loadFeaturedDeals();

        debugPrint("STEP 3");

        await _applyFiltersAsync();

        debugPrint("🔥 DATA LOADED INTO HIVE");
      }
    });
    _basketAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _basketAnimController, curve: Curves.easeInOut),
    );

    _basketAnimController.repeat(reverse: true);
  }

  Future<void> _restoreSavedParksIfMissing() async {
    final uid = _currentUserId;
    if (uid == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final doc = await userRef.get();
    final data = doc.data();

    final List<String> localParks = savedParksBox.get(uid) ?? [];

    // اگر Firestore خالیه ولی لوکال داریم → restore
    if ((data?['savedParks'] == null ||
            (data?['savedParks'] as List).isEmpty) &&
        localParks.isNotEmpty) {
      await userRef.set({'savedParks': localParks}, SetOptions(merge: true));

      debugPrint('♻️ Restored savedParks from local cache: $localParks');
    }
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('🔁 HomePage didUpdateWidget hash=${identityHashCode(this)}');
  }

  Future<void> _initMapIfNeeded() async {
    if (!Platform.isIOS) {
      _isMapReady = true;
      return;
    }

    try {
      _isMapReady = true;
      debugPrint('HomePage - Map SDK ready');
    } catch (e) {
      _mapInitFailed = true;
      _isMapReady = false;
      debugPrint('HomePage - Map init failed: $e');
    }
  }

  void _startAutoSlide() {
    _dealTimer?.cancel();

    _dealTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || _dealPageController == null) return;

      if (_dealPageController!.hasClients) {
        _dealIndex++;

        if (_dealIndex >= _featuredDeals.length) {
          _dealIndex = 0;
        }

        _dealPageController!.animateToPage(
          _dealIndex,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _resetAutoSlide() {
    _startAutoSlide();
  }

  @override
  void deactivate() {
    debugPrint('🏠 HomePage deactivate mounted=$mounted');
    super.deactivate();
  }

  void _loadAd() {
    if (_dataLoaded) return;
    _dataLoaded = true;

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-8741190851877191/2113195813',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isAdLoaded = true),
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            'Ad failed to load: ${error.message} (code: ${error.code})',
          );
          ad.dispose();
        },
      ),
    )..load();
  }

  bool _dataLoaded = false;
  bool _userDogsLoaded = false;

  Future<void> _loadDataOnce() async {
    if (_dataLoaded) return;

    debugPrint('🚀 HomePage loadDataOnce start');

    _dataLoaded = true; // ✅ فقط بعد از اتمام
  }

  Future<void> _syncDogsWithFirestore() async {
    try {
      final dogsSnapshot = await FirebaseFirestore.instance
          .collection('dogs')
          .get();
      final Map<String, Dog> uniqueDogs = {};

      for (var doc in dogsSnapshot.docs) {
        final data = doc.data();

        final dog = Dog(
          id: doc.id,
          name: data['name'] ?? '',
          breed: data['breed'] ?? '',
          age: data['age'] ?? 0,
          gender: data['gender'] ?? '',
          healthStatus: data['healthStatus'] ?? '',
          isNeutered: _toBool(data['isNeutered']),
          description: data['description'] ?? '',
          traits: List<String>.from(data['traits'] ?? []),
          ownerGender: data['ownerGender'] ?? '',
          imagePaths: List<String>.from(data['imagePaths'] ?? []),
          isAvailableForAdoption: _toBool(data['isAvailableForAdoption']),
          isOwner: _toBool(data['isOwner']),
          ownerId: (data['ownerId']?.toString() ?? ''),
          latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
        );

        if (!uniqueDogs.containsKey(dog.id)) {
          uniqueDogs[dog.id] = dog;
          debugPrint(
            'HomePage - Loaded dog: ${dog.name}, id: ${dog.id}, ownerId: ${dog.ownerId}',
          );
        } else {
          debugPrint(
            'HomePage - Skipped duplicate dog: ${dog.name}, id: ${dog.id}',
          );
          await FirebaseFirestore.instance
              .collection('dogs')
              .doc(doc.id)
              .delete();
          debugPrint(
            'HomePage - Deleted duplicate dog from Firestore: ${doc.id}',
          );
        }
      }

      await dogsBox.clear();
      await dogsBox.putAll(uniqueDogs);
      debugPrint(
        'HomePage - Synced ${uniqueDogs.length} unique dogs from Firestore to Hive',
      );
    } catch (e) {
      debugPrint('HomePage - Error syncing dogs with Firestore: $e');
    }
  }

  Future<void> _loadLocationAndFilters() async {
    if (!_isMapReady) {
      _userLatitude = 41.0103;
      _userLongitude = 28.6724;
      _isLocationLoading = false;
      //await _applyFiltersAsync();
      return;
    }

    // await _getCurrentLocation();

    if (!mounted) return;
    setState(() => _isLocationLoading = false);
    //await _applyFiltersAsync();
  }

  Future<void> _loadUserDogs() async {
    if (!mounted) {
      debugPrint('⛔️ _loadUserDogs aborted (unmounted)');
      return;
    }

    final appState = context.read<app.AppState>();

    if (appState.isGuest || _currentUserId == null) {
      debugPrint('🚫 _loadUserDogs skipped (guest or no user)');
      return;
    }

    if (_userDogsLoaded) {
      debugPrint('⛔️ _loadUserDogs skipped (already loaded)');
      return;
    }

    _userDogsLoaded = true;

    final allDogs = appState.allDogs;

    debugPrint(
      '🐶 HomePage _loadUserDogs | '
      'allDogs=${allDogs.length} | '
      'uid=$_currentUserId',
    );

    final userDogs = allDogs.where((dog) {
      return dog.ownerId == _currentUserId;
    }).toList();

    if (!mounted) return;

    setState(() {
      _userDogs = userDogs;
      debugPrint(
        '✅ HomePage - Loaded ${_userDogs.length} MY dogs: '
        '${_userDogs.map((d) => d.name).toList()}',
      );
    });
  }

  Future<void> requestLocationFromUser() async {
    final appState = context.read<app.AppState>();

    if (appState.isGuestUser) {
      debugPrint('🚫 Guest → no location request');
      return;
    }

    await _getCurrentLocation();

    if (!mounted) return;

    await _applyFiltersAsync();
  }

  Future<void> _fetchLikesForDog(String dogId) async {
    try {
      final likesSnapshot = await FirebaseFirestore.instance
          .collection('likes')
          .where('dogId', isEqualTo: dogId)
          .get();

      List<Map<String, dynamic>> likers = [];
      for (var doc in likesSnapshot.docs) {
        final likerUserId = doc['likerUserId'];
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(likerUserId)
            .get();
        final username = userSnapshot.exists
            ? userSnapshot['username']
            : 'Unknown';
        final email = userSnapshot.exists
            ? userSnapshot['email']
            : 'Unknown Email';
        likers.add({'username': username, 'email': email});
      }

      if (!mounted) return;
      setState(() {
        dogLikes[dogId] = likers;
        debugPrint('HomePage - Fetched ${likers.length} likes for dog: $dogId');
      });
    } catch (e) {
      debugPrint('HomePage - Error fetching likes for dog $dogId: $e');
    }
  }

  Future<void> _loadLikesForDogs() async {
    for (var dog in dogsBox.values) {
      await Future.delayed(const Duration(milliseconds: 100));
      await _fetchLikesForDog(dog.id);
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_locationPermissionInProgress || _locationLoaded) {
      debugPrint('📍 Location request skipped');
      return;
    }

    _locationPermissionInProgress = true;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _useFallbackLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _useFallbackLocation();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _userLatitude = position.latitude;
        _userLongitude = position.longitude;
        _locationLoaded = true;
      });

      debugPrint('📍 Location loaded: $_userLatitude,$_userLongitude');
    } catch (e) {
      debugPrint('❌ Location error: $e');
      _useFallbackLocation();
    } finally {
      _locationPermissionInProgress = false;
    }
  }

  void _useFallbackLocation() {
    if (!mounted) return;
    setState(() {
      _userLatitude = 41.0103;
      _userLongitude = 28.6724;
      _locationLoaded = true;
    });
  }

  Future<void> _applyFiltersAsync({Map<String, dynamic>? filters}) async {
    if (!mounted) return;

    final appState = context.read<app.AppState>();

    if (appState.isGuestUser) {
      debugPrint('🚫 Guest → skip Firestore filters');

      final allDogs = appState.allDogs;

      if (!mounted) return;

      setState(() {
        _filteredDogs = allDogs;
      });

      return;
    }

    if (filters != null) {
      selectedBreed = filters['breed'] as String?;
      selectedGender = filters['gender'] as String?;
      ageRange = filters['ageRange'] as RangeValues?;

      _maxDistance =
          (filters['maxDistance'] as double?)?.clamp(
            1.0,
            _isPremium ? 100.0 : 50.0,
          ) ??
          _maxDistance;

      _userLatitude = filters['userLatitude'] as double? ?? _userLatitude;

      _userLongitude = filters['userLongitude'] as double? ?? _userLongitude;

      selectedNeutered = filters['neutered'] as bool?;

      selectedHealthStatus = filters['healthStatus'] as String?;
    } else {
      _maxDistance = _isPremium ? 100.0 : 50.0;
    }

    /// 🐶 DOG DATA
    final sourceDogs = dogsBox.values.toList();

    final dogsData = sourceDogs
        .map(
          (dog) => {
            'id': dog.id,
            'name': dog.name,
            'breed': dog.breed,
            'age': dog.age,
            'gender': dog.gender,
            'healthStatus': dog.healthStatus,
            'isNeutered': dog.isNeutered,
            'description': dog.description,
            'traits': dog.traits,
            'ownerGender': dog.ownerGender,
            'imagePaths': dog.imagePaths,
            'isAvailableForAdoption': dog.isAvailableForAdoption,
            'isOwner': dog.isOwner,
            'ownerId': dog.ownerId,
            'latitude': dog.latitude,
            'longitude': dog.longitude,
          },
        )
        .toList();

    final uid = _currentUserId ?? '';
    final normalizedSearch = _normalizeSearchText(_searchQuery);

    debugPrint("🔥 UID: $uid");
    debugPrint("🔥 SEARCH: $_searchQuery");
    debugPrint('🔍 NORMALIZED SEARCH: $normalizedSearch');
    debugPrint("🔥 DOG COUNT: ${dogsData.length}");

    /// 🐶 FILTER DOGS (ISOLATE)
    final filteredDogsData = await compute(_applyFiltersIsolate, {
      'dogs': dogsData,
      'currentUserId': uid,
      'selectedBreed': selectedBreed,
      'selectedGender': selectedGender,
      'ageRange': ageRange != null
          ? {'start': ageRange!.start, 'end': ageRange!.end}
          : null,
      'maxDistance': _maxDistance,
      'userLatitude': _userLatitude,
      'userLongitude': _userLongitude,
      'selectedNeutered': selectedNeutered,
      'selectedHealthStatus': selectedHealthStatus,
      'searchQuery': normalizedSearch,
    });

    if (!mounted) return;

    /// 🏪 BUSINESS DATA
    final snapshot = await FirebaseFirestore.instance
        .collection('businesses')
        .get();

    if (!mounted) return;

    final firestoreBusinesses = snapshot.docs.map((doc) {
      final data = doc.data();

      return {'id': doc.id, ...data};
    }).toList();

    String normalize(dynamic value) {
      return value?.toString().toLowerCase().trim().replaceAll(
            RegExp(r'\s+'),
            ' ',
          ) ??
          '';
    }

    String firstNormalized(List<dynamic> values) {
      for (final value in values) {
        final normalized = normalize(value);
        if (normalized.isNotEmpty) return normalized;
      }
      return '';
    }

    String displayText(List<dynamic> values) {
      for (final value in values) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    List<String> stringList(dynamic value) {
      if (value is List) {
        return value
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
      }
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? <String>[] : <String>[text];
    }

    String businessSector(dynamic business) {
      final profile =
          (business['profile'] as Map?)?.cast<String, dynamic>() ?? {};

      final sectorData =
          (business['sectorData'] as Map?)?.cast<String, dynamic>() ?? {};

      final verification =
          (business['verification'] as Map?)?.cast<String, dynamic>() ?? {};

      final sectorKeys = sectorData.keys
          .map((e) => e.toString().toLowerCase())
          .join(' ');

      final normalizedSectorData = sectorData.toString().toLowerCase();

      final raw = [
        business['sector'],
        business['sectors'],
        business['businessType'],
        business['category'],
        business['type'],

        profile['categories'],
        profile['businessType'],
        profile['category'],
        profile['tags'],
        profile['displayName'],

        verification['level'],

        sectorKeys,
        normalizedSectorData,
      ].join(' ').toLowerCase();

      if (sectorData.containsKey('adoption_center') ||
          sectorData.containsKey('adoptionCenter') ||
          raw.contains('adoption_center') ||
          raw.contains('adoption center') ||
          raw.contains('adoptioncenter') ||
          raw.contains('adoption')) {
        return 'adoption_center adoption adoption center';
      }

      if (sectorData.containsKey('pet_taxi') ||
          raw.contains('pet_taxi') ||
          raw.contains('pet taxi') ||
          raw.contains('taxi')) {
        return 'pet_taxi pet taxi';
      }

      if (raw.contains('groom') ||
          raw.contains('groomer') ||
          raw.contains('grooming') ||
          raw.contains('pet kuaf') ||
          raw.contains('kuaf')) {
        return 'grooming groomer groomy';
      }

      if (raw.contains('pet_hotel') ||
          raw.contains('pet hotel') ||
          raw.contains('hotel') ||
          raw.contains('boarding') ||
          raw.contains('pansiyon')) {
        return 'pet_hotel hotel boarding';
      }

      if (raw.contains('petshop') ||
          raw.contains('pet_shop') ||
          raw.contains('pet shop') ||
          raw.contains('seller') ||
          raw.contains('store')) {
        return 'pet_shop petshop seller store';
      }

      if (raw.contains('vet') ||
          raw.contains('veterinary') ||
          raw.contains('clinic')) {
        return 'vet veterinary clinic';
      }

      return 'unknown';
    }

    String businessRouteFromSector(String sector) {
      if (sector.contains('adoption_center') ||
          sector.contains('adoption center') ||
          sector.contains('adoption')) {
        return 'ADOPTION_CENTER';
      }

      if (sector.contains('pet_taxi') ||
          sector.contains('pet taxi') ||
          sector.contains('taxi')) {
        return 'PET_TAXI';
      }

      if (sector.contains('groomy') ||
          sector.contains('grooming') ||
          sector.contains('groomer')) {
        return 'GROOMING';
      }

      if (sector.contains('pet_hotel') ||
          sector.contains('pet hotel') ||
          sector.contains('hotel') ||
          sector.contains('boarding')) {
        return 'PET_HOTEL';
      }

      if (sector.contains('vet') ||
          sector.contains('veterinery') ||
          sector.contains('veterinary') ||
          sector.contains('clinic')) {
        return 'VET';
      }

      if (sector.contains('petshop') ||
          sector.contains('pet_shop') ||
          sector.contains('pet shop') ||
          sector.contains('seller') ||
          sector.contains('store')) {
        return 'SELLER';
      }

      return '';
    }

    BusinessType businessTypeFromRoute(String route, String sector) {
      if (route == 'ADOPTION_CENTER') return BusinessType.adoptionCenter;
      if (route == 'GROOMING') return BusinessType.groomer;
      if (route == 'SELLER') return BusinessType.petShop;
      if (route == 'VET') return BusinessType.vet;
      if (route == 'PET_HOTEL') return BusinessType.petHotel;
      if (route == 'PET_TAXI') return BusinessType.petTaxi;
      return BusinessType.petShop;
    }

    debugPrint("🏪 FIRESTORE BUSINESSES: ${firestoreBusinesses.length}");
    for (final business in firestoreBusinesses) {
      debugPrint('🏪 BUSINESS RAW: $business');
    }

    final filteredBusinesses = firestoreBusinesses
        .where((b) {
          final business = b;
          final profile =
              (business['profile'] as Map?)?.cast<String, dynamic>() ?? {};

          final name = firstNormalized([
            profile['displayName'],
            profile['businessName'],
            business['displayName'],
            business['businessName'],
            business['name'],
          ]);

          final description = firstNormalized([
            profile['description'],
            profile['bio'],
            business['description'],
            business['bio'],
          ]);

          final categories = normalize(
            stringList(
              profile['categories'] ??
                  business['categories'] ??
                  business['category'],
            ).join(' '),
          );

          final tags = normalize(
            stringList(
              profile['tags'] ?? business['tags'] ?? business['sector'],
            ).join(' '),
          );

          final searchable = [
            name,
            description,
            categories,
            tags,
            businessSector(business),
          ].join(' ');

          final matches =
              normalizedSearch.isEmpty || searchable.contains(normalizedSearch);

          debugPrint('🏪 BUSINESS PROFILE: $profile');
          debugPrint('🏪 BUSINESS NAME: $name');
          debugPrint('🏪 BUSINESS SEARCHABLE: $searchable');
          debugPrint('🏪 BUSINESS MATCH: $matches');

          return matches;
        })
        .map((b) {
          final business = b;
          final profile =
              (business['profile'] as Map?)?.cast<String, dynamic>() ?? {};
          final contact =
              (business['contact'] as Map?)?.cast<String, dynamic>() ?? {};
          final verification =
              (business['verification'] as Map?)?.cast<String, dynamic>() ?? {};

          final categories = stringList(
            profile['categories'] ??
                business['categories'] ??
                business['category'],
          );

          final tags = stringList(
            profile['tags'] ?? business['tags'] ?? business['sector'],
          );

          final name = displayText([
            profile['displayName'],
            profile['businessName'],
            business['displayName'],
            business['businessName'],
            business['name'],
          ]);

          final description = displayText([
            profile['description'],
            profile['bio'],
            business['description'],
            business['bio'],
          ]);
          final sector = businessSector(business);
          final route = businessRouteFromSector(sector);

          final businessType = businessTypeFromRoute(route, sector);

          final businessCardData = BusinessCardData(
            id: business['id']?.toString() ?? '',
            name: name,
            city: contact['city']?.toString() ?? '',
            district: contact['district']?.toString() ?? '',
            address: displayText([
              contact['address'],
              '${contact['district'] ?? ''}, ${contact['city'] ?? ''}',
            ]),
            specialties: categories.isNotEmpty ? categories : tags,
            services: tags,
            phone: contact['phone']?.toString(),
            whatsapp: contact['whatsapp']?.toString(),
            rating: (profile['rating'] as num?)?.toDouble(),
            reviewsCount: (profile['reviewCount'] as num?)?.toInt(),
            description: description,
            isVerified: verification['isVerified'] == true,
            status: business['status']?.toString() ?? 'approved',
            type: businessType,
            instagram: contact['instagram']?.toString(),
            website: contact['website']?.toString(),
            logoUrl: profile['logoUrl']?.toString(),
            rawData: business,
            data: business,
          );

          return {
            'id': business['id'],
            'name': name,
            'category': categories.join(' '),
            'sector': tags.join(' '),
            'description': description,
            'businessData': businessCardData,
            'businessSector': sector,
            'businessRoute': route,
          };
        })
        .toList();

    /// ✅ UPDATE UI
    if (!mounted) return;

    setState(() {
      /// 🐶 DOGS
      _filteredDogs = filteredDogsData
          .map(
            (data) => Dog(
              id: data['id'],
              name: data['name'],
              breed: data['breed'],
              age: data['age'],
              gender: data['gender'],
              healthStatus: data['healthStatus'],
              isNeutered: data['isNeutered'],
              description: data['description'],
              traits: List<String>.from(data['traits']),
              ownerGender: data['ownerGender'],
              imagePaths: List<String>.from(data['imagePaths']),
              isAvailableForAdoption: data['isAvailableForAdoption'],
              isOwner: data['isOwner'],
              ownerId: data['ownerId'],
              latitude: data['latitude'],
              longitude: data['longitude'],
            ),
          )
          .take(10)
          .toList();

      /// 🏪 BUSINESSES
      _filteredBusinesses = filteredBusinesses;
    });

    debugPrint('🐶 Dogs: ${_filteredDogs.length}');
    debugPrint('🏪 Businesses: ${_filteredBusinesses.length}');
    debugPrint('🐶 FILTERED DOGS: ${_filteredDogs.length}');
    debugPrint('🏪 FILTERED BUSINESSES: ${_filteredBusinesses.length}');
  }

  static List<Map<String, dynamic>> _applyFiltersIsolate(
    Map<String, dynamic> params,
  ) {
    final List<Map<String, dynamic>> dogs = params['dogs'];
    final String currentUserId = (params['currentUserId'] ?? '').toString();

    final String? selectedBreed = params['selectedBreed'];
    final String? selectedGender = params['selectedGender'];
    final Map<String, double>? ageRange = params['ageRange'];

    final double maxDistance = params['maxDistance'];
    final double? userLatitude = params['userLatitude'];
    final double? userLongitude = params['userLongitude'];

    final bool? selectedNeutered = params['selectedNeutered'];
    final String? selectedHealthStatus = params['selectedHealthStatus'];

    final uniqueDogs = <String, Map<String, dynamic>>{};
    for (var dog in dogs) {
      uniqueDogs.putIfAbsent(dog['id'], () => dog);
    }
    final String searchQuery = _normalizeSearchText(params['searchQuery']);
    return uniqueDogs.values.where((dog) {
      /// 🔥 SAFE EXTRACTION (خیلی مهم)
      final name = _normalizeSearchText(dog['name']);
      final breed = (dog['breed'] ?? '').toString();
      final normalizedBreed = _normalizeSearchText(breed);
      final description = _normalizeSearchText(dog['description']);
      final gender = (dog['gender'] ?? '').toString();
      final health = (dog['healthStatus'] ?? '').toString();
      final ownerId = (dog['ownerId'] ?? '').toString();

      final bool isMyDog = ownerId == currentUserId;
      final bool isAdoption = dog['isAvailableForAdoption'] == true;

      if (isMyDog && !isAdoption) {
        return false;
      }

      /// 🔹 FILTERS
      final matchesBreed = selectedBreed == null || breed == selectedBreed;
      final matchesGender = selectedGender == null || gender == selectedGender;

      final matchesSearch =
          searchQuery.isEmpty ||
          name.contains(searchQuery) ||
          normalizedBreed.contains(searchQuery) ||
          description.contains(searchQuery);

      final matchesHealth =
          selectedHealthStatus == null || health == selectedHealthStatus;

      /// 🔹 DISTANCE (safe)
      bool matchesDistance = true;
      if (userLatitude != null &&
          userLongitude != null &&
          dog['latitude'] != null &&
          dog['longitude'] != null) {
        final lat = (dog['latitude'] as num).toDouble();
        final lng = (dog['longitude'] as num).toDouble();

        final distanceInMeters = Geolocator.distanceBetween(
          userLatitude,
          userLongitude,
          lat,
          lng,
        );

        matchesDistance = (distanceInMeters / 1000) <= maxDistance;
      }

      return matchesBreed &&
          matchesGender &&
          matchesSearch &&
          matchesHealth &&
          matchesDistance;
    }).toList();
  }

  Future<void> _openFilterPage() async {
    final filters = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilterPage(
          dogsList: dogsBox.values.toList(),
          selectedBreed: selectedBreed,
          selectedGender: selectedGender,
          ageRange: ageRange ?? const RangeValues(0, 15),
          maxDistance: _maxDistance,
          isPremium: _isPremium,
        ),
      ),
    );

    if (filters != null) {
      await _applyFiltersAsync(filters: filters);
    }
  }

  @override
  void dispose() {
    debugPrint(
      '💥 HomePage dispose hash=${identityHashCode(this)} key=${widget.key}',
    );
    debugPrint('HomePage - Disposing resources');

    _dealPageController?.dispose();
    _dealTimer?.cancel();
    _basketAnimController.dispose();
    super.dispose();
  }

  Widget _buildHeaderGreeting(app.AppState appState) {
    final l = AppLocalizations.of(context)!;
    final username = appState.username ?? l.unknownUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// 🔸 LOGO
          Image.asset("assets/image/logo.png", height: 50),

          const SizedBox(width: 12),

          /// 🔸 TEXTS
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.welcomeTo,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),

              Text(
                username,
                style: GoogleFonts.dancingScript(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFC107),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainFeaturesGrid() {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.78,
        ),
        children: [
          /// ROW 1
          _featureCard(
            title: l.playmateService,
            subtitle: l.findPlaymates,
            imagePath: "assets/home/playmates.png",
            icon: LucideIcons.users,
            imageScale: 0.70,
            onTap: () {
              context.read<app.AppState>().setCurrentTab(NavTab.playmates);
            },
          ),

          _featureCard(
            title: "Petplore",
            subtitle: "Discover pet community",
            imagePath: "assets/home/playdate.png",
            icon: LucideIcons.image,
            imageScale: 0.62,
            onTap: () {
              context.read<app.AppState>().setCurrentTab(NavTab.petplore);
            },
          ),
          _featureCard(
            title: l.adoptionTitle,
            subtitle: l.giveLove,
            imagePath: "assets/home/adoption.png",
            icon: LucideIcons.heart,
            imageScale: 0.58,
            onTap: () {
              context.read<app.AppState>().setCurrentTab(NavTab.adoption);
            },
          ),

          /// ROW 2
          _featureCard(
            title: l.alertsTitle,
            subtitle: l.lostAndFound,
            imagePath: "assets/home/Warning-pana.png",
            icon: LucideIcons.alertTriangle,
            imageScale: 0.52,
            onTap: _scrollToSafety,
          ),

          /// 🆕 PET HOTEL
          _featureCard(
            title: l.homePetHotelTitle, // بعداً لوکالایز می‌کنیم
            subtitle: l.homeSafeStaySubtitle,
            imagePath: "assets/home/hotel.png",
            icon: LucideIcons.home,
            imageScale: 0.55,
            onTap: () {
              context.read<app.AppState>().setCurrentTab(NavTab.petHotel);
            },
          ),

          /// 🆕 PET TAXI
          _featureCard(
            title: l.homePetTaxiTitle,
            subtitle: l.homeRideSafelySubtitle,
            imagePath: "assets/home/taxi.png",
            icon: LucideIcons.car,
            imageScale: 0.55,
            onTap: () {
              context.read<app.AppState>().setCurrentTab(NavTab.petTaxi);
            },
          ),
        ],
      ),
    );
  }

  void _scrollToSafety() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _safetyKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Widget _greenMemorialCard() {
    return SizedBox(
      height: 120,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            context.read<app.AppState>().setCurrentTab(NavTab.greenMemorial);
          },
          child: Stack(
            children: [
              /// 🔹 BACKGROUND IMAGE
              Positioned.fill(
                child: Image.asset(
                  "assets/home/memorial.png",
                  fit: BoxFit.cover,
                ),
              ),

              /// 🔹 DARK OVERLAY (برای readability)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                  ),
                ),
              ),

              /// 🔥 TITLE → پایین کارت
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Text(
                  AppLocalizations.of(context)!.homeGreenMemorialTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServicesSection() {
    final l = AppLocalizations.of(context)!;
    final appState = context.read<app.AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// 🔹 ROW → VET + GREEN MEMORIAL
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              /// 🐾 VETERINARY (۶۰٪ عرض)
              Expanded(
                flex: 6,
                child: _wideImagePlaceCard(
                  title: l.homeVeterinaryTitle,
                  subtitle: l.nearbyClinics,
                  imagePath: "assets/home/vet.png",
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(
                          AppLocalizations.of(context)!.homeLocationNeededTitle,
                        ),
                        content: Text(
                          AppLocalizations.of(
                            context,
                          )!.homeLocationNeededMessage,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(AppLocalizations.of(context)!.cancel),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await requestLocationFromUser();
                              context.read<app.AppState>().setCurrentTab(
                                NavTab.vet,
                              );
                            },
                            child: Text(
                              AppLocalizations.of(context)!.homeAllowButton,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              /// 🌿 GREEN MEMORIAL (۴۰٪ عرض)
              Expanded(flex: 4, child: _greenMemorialCard()),
            ],
          ),
        ),

        const SizedBox(height: 14), // 👈 فاصله اصلاح شد
        /// 🔹 Groomy & Pet Shop
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _miniServiceCard(
                  title: l.groomyTitle,
                  subtitle: l.bookGrooming,
                  imagePath: "assets/home/groomy.png",
                  onTap: () {
                    appState.setCurrentTab(NavTab.groomy);
                  },
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: _miniServiceCard(
                  title: l.petShopTitle,
                  subtitle: l.shopNearYou,
                  imagePath: "assets/home/petshop.png",
                  onTap: () {
                    appState.setCurrentTab(NavTab.favorites);
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        _featuredDealsCarousel(deals: _featuredDeals, onTapDeal: (deal) {}),
      ],
    );
  }

  Widget _featuredDealsCarousel({
    required List<FeaturedDeal> deals,
    required void Function(FeaturedDeal deal) onTapDeal,
  }) {
    if (deals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _dealPageController!,
            itemCount: deals.length,
            onPageChanged: (i) {
              setState(() => _dealIndex = i);
              _resetAutoSlide();
            },

            itemBuilder: (context, index) {
              final deal = deals[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _featuredDealCard(
                  deal: deal,
                  onTap: () => onTapDeal(deal),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(deals.length, (i) {
            final active = i == _dealIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFFFC107)
                    : const Color(0xFFFFC107).withOpacity(0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _featuredDealCard({
    required FeaturedDeal deal,
    required VoidCallback onTap,
  }) {
    final l = AppLocalizations.of(context)!;

    const grad = LinearGradient(
      colors: [Color(0xFFFFC107), Color(0xFFFF9800)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: grad,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            child: Row(
              children: [
                // LEFT: texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            "🔥 ${l.featuredDeal}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (deal.premiumOnly) _accessPill(l.premiumLabel),
                          if (deal.goldOnly) ...[
                            const SizedBox(width: 6),
                            _accessPill(l.goldLabel),
                          ],
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        _localizedDealShopName(deal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        _localizedDealDescription(deal),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // discount
                      if (deal.discountPercent > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l.discountOff(deal.discountPercent),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // RIGHT: logo
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(deal.logoAsset, fit: BoxFit.contain),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _localizedDealShopName(FeaturedDeal deal) => deal.shopName;

  String _localizedDealDescription(FeaturedDeal deal) => deal.description;

  Widget _accessPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _homeCard(String title, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFFFC107), size: 36),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    super.build(context);

    final currentTab = context.watch<app.AppState>().currentTab;

    debugPrint('🟢 HomePage BUILD → currentTab = $currentTab');
    final lostCount = context.select<app.AppState, int>((s) => s.lostDogsCount);

    final foundCount = context.select<app.AppState, int>(
      (s) => s.foundDogsCount,
    );

    final appState = context.watch<app.AppState>();
    final userId = appState.currentUserId;

    _currentUserId = userId;
    final allDogs = appState.allDogs;

    //if (userId == null) {
    //return const Center(child: CircularProgressIndicator());
    //}
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Stack(
          children: [
            /// 🔻 MAIN CONTENT
            SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),

                  _buildHeaderGreeting(appState),

                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _fixedSearchBar(),
                  ),
                  if (_searchQuery.isNotEmpty &&
                      (_filteredDogs.isNotEmpty ||
                          _filteredBusinesses.isNotEmpty)) ...[
                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l.homeBusinessesTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    ..._filteredDogs.map((dog) {
                      return HomeSearchResultCard(
                        type: HomeSearchResultType.dog,
                        title: dog.name,
                        subtitle: dog.breed,
                        onTap: () {
                          debugPrint('🐶 SEARCH RESULT TYPE: DOG');
                          debugPrint('🐶 OPEN DOG PROFILE: ${dog.id}');
                          debugPrint('🐶 USING STANDARD NAVIGATION');

                          final ownerId = dog.ownerId;
                          if (ownerId == null || ownerId.isEmpty) return;

                          appState.setPlaymateProfile(ownerId, allDogs);
                        },
                      );
                    }),

                    ..._filteredBusinesses.map((b) {
                      return HomeSearchResultCard(
                        type: HomeSearchResultType.business,
                        title: (b['name'] ?? '').toString(),
                        subtitle: (b['description'] ?? '').toString(),
                        onTap: () {
                          debugPrint('🏪 SEARCH RESULT TYPE: BUSINESS');
                          final sector = b['businessSector']?.toString() ?? '';
                          final route = b['businessRoute']?.toString() ?? '';
                          debugPrint('🏪 BUSINESS SECTOR: $sector');

                          if (route == 'VET') {
                            debugPrint('🏪 BUSINESS ROUTE: VET');
                            final businessData = b['businessData'];
                            if (businessData is BusinessCardData) {
                              appState.openBusinessDetails(businessData);
                            }
                            return;
                          }

                          if (route == 'SELLER') {
                            debugPrint('🏪 BUSINESS ROUTE: SELLER');

                            final businessData = b['businessData'];

                            if (businessData is BusinessCardData) {
                              debugPrint('🏪 OPEN SELLER VIA BUSINESS DETAILS');

                              appState.openBusinessDetails(businessData);
                            }

                            return;
                          }

                          if (route == 'GROOMING') {
                            debugPrint('🏪 BUSINESS ROUTE: GROOMING');

                            final businessData = b['businessData'];

                            if (businessData is BusinessCardData) {
                              debugPrint(
                                '🏪 GROOMY BUSINESS TYPE: ${businessData.type}',
                              );
                              debugPrint('🏪 OPEN GROOMY BUSINESS');
                              debugPrint(
                                '🏪 OPEN GROOMY DETAIL VIA STANDARD ROUTE',
                              );

                              FocusScope.of(context).unfocus();
                              appState.setCurrentTab(NavTab.groomy);
                              appState.openBusinessDetails(businessData);
                            }

                            return;
                          }

                          if (route == 'PET_HOTEL') {
                            debugPrint('🏪 BUSINESS ROUTE: PET_HOTEL');

                            final businessData = b['businessData'];

                            if (businessData is BusinessCardData) {
                              FocusScope.of(context).unfocus();
                              appState.setCurrentTab(NavTab.petHotel);
                              appState.openBusinessDetails(businessData);
                            }

                            return;
                          }
                        },
                      );
                    }),
                  ],

                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _premiumBanner(),
                  ),

                  const SizedBox(height: 10),

                  _buildSectionHeader(l.socialAndPlay),
                  const SizedBox(height: 12),
                  _buildMainFeaturesGrid(),

                  const SizedBox(height: _sectionGap),

                  _buildSectionHeader(l.careAndServices),
                  const SizedBox(height: 10),
                  _buildServicesSection(),

                  const SizedBox(height: 16),

                  const NativeAdWidget(),

                  const SizedBox(height: 16),

                  const SizedBox(height: _sectionGap),

                  _buildSectionHeader(l.outdoorAndLifestyle),
                  const SizedBox(height: 16),
                  _buildPlacesSection(),

                  const SizedBox(height: _sectionGap),

                  Container(
                    key: _safetyKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSafetyHeader(lostCount + foundCount),
                        const SizedBox(height: 10),
                        _buildSafetySection(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const BannerAdWidget(),

                  const SizedBox(height: 80),
                ],
              ),
            ),

            /// 🔻 FLOATING BASKET
            _buildDraggableBasket(),
          ],
        ),
      ),
    );
  }

  Widget _fixedSearchBar() {
    final l = AppLocalizations.of(context)!;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3D9E4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9E1B4F).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = _normalizeSearchText(value);
          });

          _applyFiltersAsync(); // 🔥 مهم
        },
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          hintText: l.homeSearchHint,
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: Color(0xFFD94A7A)),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _premiumBanner() {
    final l = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_homeRadius),
        onTap: () {
          context.read<app.AppState>().openUpgradePage();
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9E1B4F), Color(0xFFD94A7A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_homeRadius),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9E1B4F).withValues(alpha: 0.14),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.sparkles,
                  color: Color(0xFFFFC107),
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.upgradeToPremiumTitle,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l.upgradeToPremiumSubtitle,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureCard({
    required String title,
    required String subtitle,
    required String imagePath,
    required IconData icon,
    required VoidCallback onTap,
    double imageScale = 0.62,
  }) {
    final bool isAlert = title.toLowerCase() == "alerts";
    return _buildHomeImageCard(
      title: title,
      subtitle: subtitle,
      imagePath: imagePath,
      onTap: onTap,
      hideTextForAlertTitle: isAlert,
    );
  }

  Widget _buildHomeImageCard({
    required String title,
    required String subtitle,
    required String imagePath,
    required VoidCallback onTap,
    bool hasAlert = false,
    int count = 0,
    bool hideTextForAlertTitle = false,
  }) {
    return HomeImageCard(
      title: title,
      subtitle: subtitle,
      imagePath: imagePath,
      onTap: onTap,
      hasAlert: hasAlert,
      count: count,
      hideTextForAlertTitle: hideTextForAlertTitle,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF9E1B4F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesSection() {
    final l = AppLocalizations.of(context)!;
    final appState = context.read<app.AppState>();

    return Column(
      children: [
        _wideImagePlaceCard(
          title: l.homePetFriendlyPlaceTitle,
          subtitle: l.exploreNearbyParks,
          imagePath: "assets/home/dog_park.png",
          onTap: () {
            appState.setCurrentTab(NavTab.dogParks);
          },
        ),
        const SizedBox(height: _cardGap),
        _wideImagePlaceCard(
          title: l.trainingTitle,
          subtitle: l.comingSoon,
          imagePath: "assets/home/Good doggy-cuate.png",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.trainingComingSoonMessage),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _wideImagePlaceCard({
    required String title,
    required String subtitle,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 120,

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(_homeRadius),

          onTap: onTap,

          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9E1B4F), Color(0xFFD94A7A), Colors.white],

                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),

              borderRadius: BorderRadius.circular(_homeRadius),

              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9E1B4F).withValues(alpha: 0.10),

                  blurRadius: 20,

                  offset: const Offset(0, 10),
                ),
              ],
            ),

            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

              child: Row(
                children: [
                  /// TEXT
                  Flexible(
                    flex: 5,

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Text(
                          title,

                          maxLines: 1,

                          style: GoogleFonts.poppins(
                            fontSize: 16,

                            fontWeight: FontWeight.w700,

                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          subtitle,

                          maxLines: 2,

                          overflow: TextOverflow.ellipsis,

                          style: GoogleFonts.poppins(
                            fontSize: 11,

                            fontWeight: FontWeight.w500,

                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 4),

                  /// IMAGE
                  Flexible(
                    flex: 4,

                    child: Align(
                      alignment: Alignment.centerRight,

                      child: SizedBox(
                        height: 88,

                        child: Image.asset(imagePath, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniServiceCard({
    required String title,
    required String subtitle,
    required String imagePath,
    required VoidCallback onTap,
    bool isSponsored = false,
  }) {
    final l = AppLocalizations.of(context)!;

    return Material(
      color: Colors.transparent,

      child: InkWell(
        borderRadius: BorderRadius.circular(_homeRadius),

        onTap: onTap,

        child: Ink(
          height: 120,

          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9E1B4F), Color(0xFFD94A7A), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),

            borderRadius: BorderRadius.circular(_homeRadius),

            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9E1B4F).withValues(alpha: 0.10),

                blurRadius: 20,

                offset: const Offset(0, 10),
              ),
            ],
          ),

          child: Stack(
            children: [
              /// Sponsored Badge
              if (isSponsored)
                Positioned(
                  top: 10,
                  right: 10,

                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.orange,

                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Text(
                      l.homeSponsoredLabel,

                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(14),

                child: Row(
                  children: [
                    /// TEXT
                    Expanded(
                      flex: 6, // 👈 جدید

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          Text(
                            title,

                            maxLines: 2,

                            style: GoogleFonts.poppins(
                              fontSize: 15, // 16 → 15

                              fontWeight: FontWeight.w700,

                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            subtitle,

                            maxLines: 2,

                            overflow: TextOverflow.ellipsis,

                            style: GoogleFonts.poppins(
                              fontSize: 11,

                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    /// IMAGE
                    Expanded(
                      flex: 4, // 👈 جدید

                      child: SizedBox(
                        height: 78, // 82 → 78

                        child: Image.asset(imagePath, fit: BoxFit.contain),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyHeader(int lostCount) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            l.communityHub,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF9E1B4F),
            ),
          ),
          const SizedBox(height: 10),

          if (lostCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF9E1B4F),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l.activeCount(lostCount),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSafetySection() {
    final l = AppLocalizations.of(context)!;
    final appState = context.read<app.AppState>();

    final lostCount = context.select<app.AppState, int>((s) => s.lostDogsCount);

    final foundCount = context.select<app.AppState, int>(
      (s) => s.foundDogsCount,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.90,
        ),
        children: [
          _safetyCard(
            title: l.reportTitle,
            subtitle: l.lostPetTitle,
            imagePath: "assets/home/lost_dog.png",
            onTap: () {
              appState.setCurrentTab(NavTab.reportLost);
            },
          ),

          _safetyCard(
            title: l.reportTitle,
            subtitle: l.foundPetTitle,
            imagePath: "assets/home/report_found_dog.png",
            onTap: () {
              appState.setCurrentTab(NavTab.reportFound);
            },
          ),

          _safetyCard(
            title: l.lostTitle,
            subtitle: l.petsTitle,
            imagePath: "assets/home/found_dog.png",
            hasAlert: lostCount > 0,
            count: lostCount,
            onTap: () {
              appState.setCurrentTab(NavTab.lostDogs);
            },
          ),

          _safetyCard(
            title: l.foundTitle,
            subtitle: l.petsTitle,
            imagePath: "assets/home/Good doggy-amico.png",
            hasAlert: foundCount > 0,
            count: foundCount,
            onTap: () {
              appState.closeFoundDogDetail();
              appState.setCurrentTab(NavTab.foundDogs);
            },
          ),
        ],
      ),
    );
  }

  Widget _safetyCard({
    required String title,
    required String subtitle,
    required String imagePath,
    required VoidCallback onTap,
    bool hasAlert = false,
    int count = 0,
  }) {
    return _buildHomeImageCard(
      title: title,
      subtitle: subtitle,
      imagePath: imagePath,
      onTap: onTap,
      hasAlert: hasAlert,
      count: count,
    );
  }

  Widget _buildDraggableBasket() {
    final l = AppLocalizations.of(context)!;
    return Positioned(
      top: _basketTop,
      left: _basketLeft,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _basketTop += details.delta.dy;
            _basketLeft += details.delta.dx;
          });
        },

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AllProductsPage()),
          );
        },

        child: AnimatedBuilder(
          animation: _scaleAnim ?? const AlwaysStoppedAnimation(1.0),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnim?.value ?? 1.0,
              child: child,
            );
          },

          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7DA), Color(0xFFFFC107)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9E1B4F).withValues(alpha: 0.16),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.18),
                  blurRadius: 16,
                ),
              ],
            ),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.shoppingCart, // 👈 تغییر بده
                  color: const Color(0xFF9E1B4F),
                  size: 26,
                ),

                const SizedBox(height: 2),

                Text(
                  l.homeShopButton,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9E1B4F),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
