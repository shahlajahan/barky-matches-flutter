import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:cached_network_image/cached_network_image.dart';

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
import 'package:barky_matches_fixed/services/location_permission_service.dart';
import 'package:barky_matches_fixed/home/widgets/home_image_card.dart';
import 'package:barky_matches_fixed/home/widgets/home_search_result_card.dart';
import 'package:barky_matches_fixed/home/widgets/homepage_responsive_photo_image.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/pet_taxi_booking_page.dart';
import 'package:barky_matches_fixed/utils/business_sector.dart';
import 'package:barky_matches_fixed/widgets/overflow_marquee_text.dart';
import 'package:barky_matches_fixed/services/business_query_diagnostics.dart';

import 'package:lucide_icons/lucide_icons.dart';
import 'package:barky_matches_fixed/widgets/ads/banner_ad_widget.dart';
import 'package:barky_matches_fixed/models/featured_deal.dart';
import 'package:barky_matches_fixed/promotion/services/promotion_analytics_service.dart';
import 'package:barky_matches_fixed/promotion/services/promotion_featured_deal_refresh_policy.dart';
import 'package:barky_matches_fixed/promotion/services/featured_deal_inventory.dart';
import 'package:intl/intl.dart';
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
        LocalizationUtils,
        WidgetsBindingObserver {
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
  Timer? _promotionInventoryTimer;
  DateTime? _lastPromotionInventoryFetch;
  late final VoidCallback _promotionInvalidationListener;
  int _lastPromotionInventoryRevision =
      PromotionFeaturedDealRefreshPolicy.invalidation.value;

  Map<String, List<Map<String, dynamic>>> dogLikes = {};

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  static const Color _cardColor = Color(0xFF9E1B4F);
  static const double _homeRadius = 20;
  static const double _sectionGap = 24;
  static const double _cardGap = 14;

  bool _bootstrapped = false;
  List<FeaturedDeal> _featuredDeals = [];
  List<FeaturedDeal> _editorialFeaturedDeals = [];
  List<FeaturedDeal> _promotedServiceDeals = [];
  int _featuredInventoryRequest = 0;
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
    if (!mounted) {
      debugPrint("🔥 FEATURED LOAD SKIPPED → NOT MOUNTED");
      return;
    }

    debugPrint("🔥 FEATURED LOAD START");

    // Capture context-dependent values before the Firestore async gap.
    final language = Localizations.localeOf(context).languageCode;

    debugPrint("🔥 LANGUAGE = $language");

    final requestId = ++_featuredInventoryRequest;
    try {
      final query = FirebaseFirestore.instance
          .collection("featured_deals")
          .orderBy("order")
          .limit(12);

      debugPrint("🔥 QUERY CREATED");

      final snapshot = await query.get();

      if (!mounted) {
        debugPrint("🔥 FEATURED LOAD CANCELLED → DISPOSED AFTER QUERY");
        return;
      }

      debugPrint("🔥 SNAPSHOT RECEIVED");
      debugPrint("🔥 DOC COUNT = ${snapshot.docs.length}");

      for (final doc in snapshot.docs) {
        debugPrint("🔥 DOC ID = ${doc.id}");
        debugPrint("🔥 DOC DATA = ${doc.data()}");
      }

      final deals = snapshot.docs
          .where((doc) => !isLegacyDemoFeaturedDealDocument(doc.id))
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

      final serviceDeals = await _fetchPromotedServiceDeals();

      debugPrint("🔥 DEAL PARSE FINISHED");
      debugPrint("🔥 DEAL COUNT FINAL = ${deals.length}");

      if (!mounted) {
        debugPrint("🔥 FEATURED SETSTATE SKIPPED → NOT MOUNTED");
        return;
      }

      // A refresh can be started by activation invalidation or app resume
      // while the initial load is still in flight. Older responses must not
      // overwrite a newer inventory response.
      if (requestId != _featuredInventoryRequest) return;

      _editorialFeaturedDeals = deals;
      if (serviceDeals != null) {
        _promotedServiceDeals = serviceDeals;
      }

      setState(() {
        _featuredDeals = composeFeaturedDealInventory(
          editorialDeals: _editorialFeaturedDeals,
          promotedDeals: serviceDeals,
          previousPromotedDeals: _promotedServiceDeals,
          placeholder: FeaturedDeal.neutralPlaceholder(
            title: AppLocalizations.of(context)!.featuredDealsEmptyTitle,
            description: AppLocalizations.of(
              context,
            )!.featuredDealsEmptyDescription,
          ),
        );
      });

      _startPromotionInventoryRefresh();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recordVisibleFeaturedDeal();
      });

      debugPrint("🔥 SETSTATE DONE");
    } on FirebaseException catch (e, stack) {
      debugPrint("❌ FEATURED ERROR = $e");

      debugPrint("❌ STACK = $stack");
    } catch (e, stack) {
      debugPrint("❌ FEATURED ERROR = $e");
      debugPrint("❌ STACK = $stack");
    }
  }

  Future<List<FeaturedDeal>?> _fetchPromotedServiceDeals() async {
    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('readFeaturedServiceDeals').call();
      final data = result.data;
      if (data is Map && data['deals'] is List) {
        _lastPromotionInventoryFetch = DateTime.now();
        _lastPromotionInventoryRevision =
            PromotionFeaturedDealRefreshPolicy.invalidation.value;
        return (data['deals'] as List)
            .whereType<Map>()
            .map(
              (deal) => FeaturedDeal.fromPromotedService(
                Map<String, dynamic>.from(deal),
              ),
            )
            .toList();
      }
    } catch (error) {
      // Editorial deals remain available if the optional promotion inventory
      // read is unavailable. This must never affect Home navigation.
      debugPrint('Featured service inventory unavailable: $error');
    }
    return null;
  }

  void _startPromotionInventoryRefresh() {
    _promotionInventoryTimer?.cancel();
    _promotionInventoryTimer = Timer(
      PromotionFeaturedDealRefreshPolicy.clientTtl,
      () {
        unawaited(_refreshPromotedServiceDeals());
      },
    );
  }

  Future<void> _refreshPromotedServiceDeals() async {
    if (!mounted) return;
    final requestId = ++_featuredInventoryRequest;
    final serviceDeals = await _fetchPromotedServiceDeals();
    if (!mounted) return;
    if (serviceDeals == null) {
      _startPromotionInventoryRefresh();
      return;
    }
    if (requestId != _featuredInventoryRequest) return;

    _promotedServiceDeals = serviceDeals;
    setState(() {
      _featuredDeals = composeFeaturedDealInventory(
        editorialDeals: _editorialFeaturedDeals,
        promotedDeals: serviceDeals,
        previousPromotedDeals: _promotedServiceDeals,
        placeholder: FeaturedDeal.neutralPlaceholder(
          title: AppLocalizations.of(context)!.featuredDealsEmptyTitle,
          description: AppLocalizations.of(
            context,
          )!.featuredDealsEmptyDescription,
        ),
      );
      if (_featuredDeals.isEmpty) {
        _dealIndex = 0;
      } else if (_dealIndex >= _featuredDeals.length) {
        _dealIndex = 0;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordVisibleFeaturedDeal();
    });
    _startPromotionInventoryRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final lastFetch = _lastPromotionInventoryFetch;
    if (PromotionFeaturedDealRefreshPolicy.isStale(
      lastFetchedAt: lastFetch,
      now: DateTime.now(),
    )) {
      unawaited(_refreshPromotedServiceDeals());
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _promotionInvalidationListener = () {
      if (!mounted) return;
      final revision = PromotionFeaturedDealRefreshPolicy.invalidation.value;
      if (revision == _lastPromotionInventoryRevision) return;
      unawaited(_refreshPromotedServiceDeals());
    };
    PromotionFeaturedDealRefreshPolicy.invalidation.addListener(
      _promotionInvalidationListener,
    );
    WidgetsBinding.instance.addObserver(this);
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

        await context.read<app.AppState>().refreshDogs();

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
    if (kIsWeb || !Platform.isIOS) {
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

  void _recordVisibleFeaturedDeal() {
    if (!mounted || _featuredDeals.isEmpty) return;
    final index = _dealIndex.clamp(0, _featuredDeals.length - 1);
    final deal = _featuredDeals[index];
    if (!deal.isPromotion || deal.campaignId == null || deal.targetId == null) {
      return;
    }
    unawaited(
      PromotionAnalyticsService().recordImpression(
        campaignId: deal.campaignId!,
        targetType: deal.targetType ?? 'SERVICE',
        targetId: deal.targetId!,
        placement: 'home_featured_deal',
        sector: deal.sector,
      ),
    );
  }

  void _openFeaturedDeal(FeaturedDeal deal) {
    if (!deal.isPromotion ||
        deal.targetType?.toUpperCase() != 'SERVICE' ||
        deal.businessId == null ||
        deal.serviceId == null ||
        deal.campaignId == null ||
        deal.targetId == null) {
      return;
    }

    unawaited(
      PromotionAnalyticsService().recordClick(
        campaignId: deal.campaignId!,
        targetType: deal.targetType!,
        targetId: deal.targetId!,
        placement: 'home_featured_deal',
        sector: deal.sector,
      ),
    );

    final isGroomer = deal.sector?.toUpperCase() == 'GROOMER';
    final business = BusinessCardData(
      id: deal.businessId!,
      name: deal.businessName?.trim().isNotEmpty == true
          ? deal.businessName!
          : deal.shopName,
      city: deal.location ?? '',
      district: '',
      address: deal.location ?? '',
      specialties: [deal.sector ?? 'SERVICE'],
      services: [deal.serviceTitle ?? deal.shopName],
      status: 'approved',
      type: isGroomer ? BusinessType.groomer : BusinessType.vet,
      logoUrl: deal.logoAsset.isEmpty ? null : deal.logoAsset,
    );
    final service = <String, dynamic>{
      'id': deal.serviceId,
      'title': deal.serviceTitle ?? deal.shopName,
      if (deal.price != null) 'price': deal.price,
      if (deal.currency != null) 'currency': deal.currency,
    };
    final appState = context.read<app.AppState>();
    appState.setCurrentTab(isGroomer ? NavTab.groomy : NavTab.vet);
    appState.openBusinessAppointment(business, selectedService: service);
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
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
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
            : l.unknownUser;
        final email = userSnapshot.exists
            ? userSnapshot['email']
            : l.notProvided;
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
    final appState = context.read<app.AppState>();

    for (var dog in appState.allDogs) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
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
      final permission = await LocationPermissionService.ensurePermission(
        context,
        title: 'Nearby services need your location',
        message: 'We use your location to show nearby services and pets.',
      );
      if (!permission) {
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
    final sourceDogs = appState.allDogs;

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
    BusinessQueryDiagnostics.start(
      'HomePage._applyFiltersAsync',
      'businesses_public',
      'none',
    );
    final businessesQuery = FirebaseFirestore.instance.collection(
      'businesses_public',
    );
    late final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await businessesQuery.get();
      BusinessQueryDiagnostics.result(
        'HomePage._applyFiltersAsync',
        snapshot.docs.length,
      );
    } catch (error, stack) {
      BusinessQueryDiagnostics.error(
        'HomePage._applyFiltersAsync',
        error,
        stack,
      );
      rethrow;
    }

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

    BusinessType businessTypeFromSector(String sector) {
      return switch (sector) {
        BusinessSector.adoptionCenter => BusinessType.adoptionCenter,
        BusinessSector.groomy => BusinessType.groomer,
        BusinessSector.petShop => BusinessType.petShop,
        BusinessSector.vet => BusinessType.vet,
        BusinessSector.petHotel => BusinessType.petHotel,
        BusinessSector.petTaxi => BusinessType.petTaxi,
        _ => BusinessType.petShop,
      };
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
            ...BusinessSector.searchAliases(
              BusinessSector.fromBusiness(business),
            ),
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
          final sector = BusinessSector.fromBusiness(business);
          final rawSector = BusinessSector.rawValue(business);
          final businessType = businessTypeFromSector(sector ?? '');

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
            'businessRawData': business,
            'rawBusinessSector': rawSector,
            'businessSector': sector,
          };
        })
        .toList();

    BusinessQueryDiagnostics.filtered(
      'HomePage._applyFiltersAsync',
      filteredBusinesses.length,
    );

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
    final appState = context.read<app.AppState>();

    final filters = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilterPage(
          dogsList: appState.allDogs,
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
    _promotionInventoryTimer?.cancel();
    PromotionFeaturedDealRefreshPolicy.invalidation.removeListener(
      _promotionInvalidationListener,
    );
    WidgetsBinding.instance.removeObserver(this);
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
          Image.asset(
            "assets/image/logo.png",
            height: 50,
            fit: kIsWeb ? BoxFit.contain : null,
          ),

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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          /// HERO PETPLORE
          _BigPhotoHomeCard(
            title: l.communityHub,
            subtitle: l.socialAndPlay,
            imagePath: "assets/home/heroes/petplore_hero.png",
            imageAlignment: const Alignment(0.2, -0.45),
            onTap: () {
              context.read<app.AppState>().setCurrentTab(NavTab.petplore);
            },
          ),

          const SizedBox(height: 16),

          /// GRID
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _SmallPhotoHomeCard(
                    title: l.playmateService,
                    subtitle: l.signInToFindFriends,
                    imagePath: "assets/home/playmate.png",
                    onTap: () {
                      context.read<app.AppState>().setCurrentTab(
                        NavTab.playmates,
                      );
                    },
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: _SmallPhotoHomeCard(
                    title: l.adoptionTitle,
                    subtitle: l.giveLove,
                    imagePath: "assets/home/adoption.png",
                    onTap: () {
                      context.read<app.AppState>().setCurrentTab(
                        NavTab.adoption,
                      );
                    },
                  ),
                ),
              ],
            ),
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
    final l = AppLocalizations.of(context)!;
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
                child: buildHomepageResponsivePhotoImage(
                  assetPath: "assets/home/memorial.png",
                  coverAlignment: Alignment.center,
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
                left: 22,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.homeGreenMemorialTitle,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      l.createMemoriesTogether,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
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

  Widget _buildServicesSection() {
    final l = AppLocalizations.of(context)!;
    final appState = context.read<app.AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// 🔹 VETERINARY HERO
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _BigPhotoHomeCard(
            title: l.homeVeterinaryTitle,
            subtitle: l.expertCareForYourPet,
            imagePath: "assets/home/heroes/vet_hero.png",
            onTap: () {
              requestLocationFromUser().then((_) {
                if (mounted) {
                  context.read<app.AppState>().setCurrentTab(NavTab.vet);
                }
              });
            },
          ),
        ),

        const SizedBox(height: 14),

        /// 🔹 Groomy & Pet Shop
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _SmallPhotoHomeCard(
                  title: l.groomyTitle,
                  subtitle: l.pamperYourPet,
                  imagePath: "assets/home/heroes/groomy_hero.png",
                  imageAlignment: Alignment.centerRight,
                  textAlignment: Alignment.topLeft,
                  onTap: () {
                    appState.setCurrentTab(NavTab.groomy);
                  },
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: _SmallPhotoHomeCard(
                  title: l.petShopTitle,
                  subtitle: l.shopNearYou,
                  imagePath: "assets/home/heroes/petshop_hero.png",
                  imageAlignment: Alignment.centerRight,
                  textAlignment: Alignment.topLeft,
                  onTap: () {
                    requestLocationFromUser().then((_) {
                      if (mounted) {
                        context.read<app.AppState>().setCurrentTab(
                          NavTab.petShop,
                        );
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        /// 🔹 Pet Hotel & Pet Taxi
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _SmallPhotoHomeCard(
                  title: l.homePetHotelTitle,
                  subtitle: l.homeSafeStaySubtitle,
                  imagePath: "assets/home/heroes/hotel_hero.png",
                  imageAlignment: Alignment.centerRight,
                  textAlignment: Alignment.topLeft,
                  onTap: () {
                    appState.setCurrentTab(NavTab.petHotel);
                  },
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: _SmallPhotoHomeCard(
                  title: l.homePetTaxiTitle,
                  subtitle: l.homeRideSafelySubtitle,
                  imagePath: "assets/home/heroes/taxi_hero.png",
                  imageAlignment: Alignment.centerRight,
                  textAlignment: Alignment.topLeft,
                  onTap: () {
                    appState.setCurrentTab(NavTab.petTaxi);
                  },
                ),
              ),
            ],
          ),
        ),
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
          height: 130,
          child: PageView.builder(
            controller: _dealPageController!,
            itemCount: deals.length,
            onPageChanged: (i) {
              setState(() => _dealIndex = i);
              _resetAutoSlide();
              _recordVisibleFeaturedDeal();
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

    final grad = LinearGradient(
      colors: deal.isPlaceholder
          ? [const Color(0xFF607D8B), const Color(0xFF455A64)]
          : [const Color(0xFFFFC107), const Color(0xFFFF9800)],
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
                            deal.isPromotion
                                ? l.homeSponsoredLabel
                                : l.featuredDeal,
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
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        _localizedDealDescription(deal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      if (deal.isPromotion && deal.price != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _dealPrice(deal, context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // discount
                      if (deal.discountPercent > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l.discountOff(deal.discountPercent),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 11,
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
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: deal.isPlaceholder
                      ? const Icon(
                          Icons.local_offer_outlined,
                          color: Colors.white,
                          size: 30,
                        )
                      : _buildFeaturedDealLogo(deal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _localizedDealShopName(FeaturedDeal deal) {
    if (!deal.isPromotion || deal.shopName.trim().isNotEmpty) {
      return deal.shopName;
    }
    final l = AppLocalizations.of(context)!;
    return deal.sector?.toUpperCase() == 'GROOMER'
        ? l.promotionTargetGroomyService
        : l.promotionTargetVetService;
  }

  String _localizedDealDescription(FeaturedDeal deal) {
    if (!deal.isPromotion) return deal.description;
    final l = AppLocalizations.of(context)!;
    final sector = deal.sector?.toUpperCase() == 'GROOMER'
        ? l.promotionTargetGroomyService
        : l.promotionTargetVetService;
    return [
      sector,
      if (deal.businessName?.trim().isNotEmpty == true) deal.businessName!,
      if (deal.location?.trim().isNotEmpty == true) deal.location!,
    ].join(' · ');
  }

  String _dealPrice(FeaturedDeal deal, BuildContext context) {
    final raw = deal.price;
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (value == null) return '';
    final locale = Localizations.localeOf(context).toLanguageTag();
    final currency = deal.currency ?? 'TRY';
    return NumberFormat.currency(
      locale: locale,
      symbol: currency == 'TRY' ? '₺' : currency,
      decimalDigits: value == value.roundToDouble() ? 0 : 2,
    ).format(value);
  }

  Widget _buildFeaturedDealLogo(FeaturedDeal deal) {
    final promotedLogoUrl = promotedFeaturedDealLogoUrl(deal);
    if (deal.isPromotion) {
      if (promotedLogoUrl == null) {
        return const Icon(Icons.storefront, color: Colors.white, size: 30);
      }
      return Stack(
        children: [
          CachedNetworkImage(
            imageUrl: promotedLogoUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) =>
                const Icon(Icons.storefront, color: Colors.white, size: 30),
            errorWidget: (context, url, error) =>
                const Icon(Icons.storefront, color: Colors.white, size: 30),
          ),
        ],
      );
    }

    final source = deal.logoAsset;
    if (source.trim().isEmpty) {
      return const Icon(Icons.storefront, color: Colors.white, size: 30);
    }

    final uri = Uri.tryParse(source);
    final isNetworkImage =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    final imageProvider = isNetworkImage
        ? NetworkImage(source) as ImageProvider<Object>
        : AssetImage(source);

    return Image(
      image: imageProvider,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.storefront, color: Colors.white, size: 30),
    );
  }

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
                        onTap: () => _openBusinessSearchResult(b, appState),
                      );
                    }),
                  ],

                  const SizedBox(height: 10),

                  if (!appState.isGold && !appState.isPremium) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _premiumBanner(),
                    ),

                    const SizedBox(height: 20),
                  ],

                  const SizedBox(height: 10),

                  _buildSectionHeader(l.careAndServices),
                  const SizedBox(height: 12),

                  _buildServicesSection(),
                  if (_featuredDeals.isNotEmpty) ...[
                    const SizedBox(height: _sectionGap),

                    _buildSectionHeader(l.featuredDeal),

                    const SizedBox(height: 12),

                    _featuredDealsCarousel(
                      deals: _featuredDeals,
                      onTapDeal: _openFeaturedDeal,
                    ),
                  ],

                  const SizedBox(height: _sectionGap),

                  _buildSectionHeader(l.communityHub),
                  const SizedBox(height: 12),
                  _buildMainFeaturesGrid(),

                  const SizedBox(height: _sectionGap),

                  _buildSectionHeader(l.socialAndPlay),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _greenMemorialCard(),
                  ),

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

                  const SizedBox(height: _sectionGap),

                  _buildSectionHeader(l.outdoorAndLifestyle),
                  const SizedBox(height: 12),
                  _buildPlacesSection(),

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
          hint: OverflowMarqueeText(
            l.homeSearchHint,
            style:
                (Theme.of(context).textTheme.bodyLarge ??
                        const TextStyle(fontSize: 16))
                    .copyWith(color: Theme.of(context).hintColor),
          ),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: Color(0xFFD94A7A)),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  void _openBusinessSearchResult(
    Map<String, dynamic> result,
    app.AppState appState,
  ) {
    final l = AppLocalizations.of(context)!;
    final businessId = result['id']?.toString() ?? '';
    final rawSector = result['rawBusinessSector']?.toString() ?? '';
    final canonicalSector = BusinessSector.normalize(result['businessSector']);
    final businessData = result['businessData'];

    debugPrint('🏪 SEARCH RESULT TYPE: BUSINESS');
    debugPrint(
      '🏪 BUSINESS NAVIGATION id=$businessId '
      'rawSector="$rawSector" normalizedSector="${canonicalSector ?? 'unknown'}"',
    );

    if (businessData is! BusinessCardData ||
        businessData.id.isEmpty ||
        businessData.id != businessId) {
      debugPrint(
        '⛔ BUSINESS NAVIGATION INVALID DATA id=$businessId '
        'rawSector="$rawSector" normalizedSector="${canonicalSector ?? 'unknown'}"',
      );
      _showBusinessNavigationFallback(l.somethingWentWrong);
      return;
    }

    if (businessData.status != 'approved') {
      debugPrint(
        '⛔ BUSINESS NAVIGATION UNAVAILABLE id=$businessId '
        'status="${businessData.status}" rawSector="$rawSector" '
        'normalizedSector="${canonicalSector ?? 'unknown'}"',
      );
      _showBusinessNavigationFallback(l.somethingWentWrong);
      return;
    }

    FocusScope.of(context).unfocus();

    switch (BusinessSector.destination(canonicalSector)) {
      case BusinessSectorDestination.petTaxiBooking:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PetTaxiBookingPage(business: businessData),
          ),
        );
        return;
      case BusinessSectorDestination.businessDetails:
        appState.openBusinessDetails(businessData);
        return;
      case BusinessSectorDestination.trainingUnavailable:
        _showBusinessNavigationFallback(l.trainingComingSoonMessage);
        return;
      case BusinessSectorDestination.unavailable:
        debugPrint(
          '⛔ BUSINESS NAVIGATION UNKNOWN SECTOR id=$businessId '
          'rawSector="$rawSector" '
          'normalizedSector="${canonicalSector ?? 'unknown'}"',
        );
        _showBusinessNavigationFallback(l.somethingWentWrong);
        return;
    }
  }

  void _showBusinessNavigationFallback(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
    double imageScale = 1.18,
  }) {
    final bool isAlert = title.toLowerCase() == "alerts";
    return _buildHomeImageCard(
      title: title,
      subtitle: subtitle,
      imagePath: imagePath,
      onTap: onTap,
      hideTextForAlertTitle: isAlert,
      imageScale: imageScale,
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
    double imageScale = 1.18,
  }) {
    return HomeImageCard(
      title: title,
      subtitle: subtitle,
      imagePath: imagePath,
      onTap: onTap,
      hasAlert: hasAlert,
      count: count,
      hideTextForAlertTitle: hideTextForAlertTitle,
      imageScale: imageScale,
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
          subtitle: l.createMemoriesTogether,
          imagePath: "assets/home/heroes/pet_friendly_place_hero.png",
          onTap: () {
            appState.setCurrentTab(NavTab.dogParks);
          },
        ),

        const SizedBox(height: 14),

        _wideImagePlaceCard(
          title: l.trainingTitle,
          subtitle: l.comingSoon,
          imagePath: "assets/home/heroes/training_hero.png",
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _BigPhotoHomeCard(
        title: title,
        subtitle: subtitle,
        imagePath: imagePath,
        onTap: onTap,
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
            l.safetyAndRescue,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          /// HERO REPORT LOST
          _BigPhotoHomeCard(
            title: l.reportTitle,
            subtitle: l.lostPetTitle,
            imagePath: "assets/home/lost_dog.png",
            imageAlignment: const Alignment(0.35, -0.35),
            onTap: () {
              appState.setCurrentTab(NavTab.reportLost);
            },
          ),

          const SizedBox(height: 14),

          /// LOST PETS + FOUND PETS
          Row(
            children: [
              Expanded(
                child: _SmallPhotoHomeCard(
                  title: l.lostPetsTitle,
                  subtitle: l.activeReportsNearby,
                  imagePath: "assets/home/lost_dog_list.png",
                  onTap: () {
                    appState.setCurrentTab(NavTab.lostDogs);
                  },
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: _SmallPhotoHomeCard(
                  title: l.foundPetsTitle,
                  subtitle: l.waitingToReunite,
                  imagePath: "assets/home/found_dog.png",
                  onTap: () {
                    appState.setCurrentTab(NavTab.foundDogs);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          /// HERO REPORT FOUND
          _BigPhotoHomeCard(
            title: l.reportFoundTitle,
            subtitle: l.reconnectFamilies,
            imagePath: "assets/home/found-dog.png",
            onTap: () {
              appState.setCurrentTab(NavTab.reportFound);
            },
          ),
        ],
      ),
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

class _BigPhotoHomeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final VoidCallback onTap;
  final Alignment imageAlignment;

  const _BigPhotoHomeCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.onTap,
    this.imageAlignment = const Alignment(0.2, 0.15),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 135,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              buildHomepageResponsivePhotoImage(
                assetPath: imagePath,
                coverAlignment: imageAlignment,
              ),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.02),
                      Colors.black.withOpacity(0.38),
                    ],
                  ),
                ),
              ),

              Positioned(
                left: 22,
                top: 32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    SizedBox(
                      width: 220,
                      child: Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
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
}

class _SmallPhotoHomeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final VoidCallback onTap;
  final Alignment imageAlignment;
  final Alignment textAlignment;

  const _SmallPhotoHomeCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.onTap,
    this.imageAlignment = Alignment.centerRight,
    this.textAlignment = Alignment.topLeft,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              buildHomepageResponsivePhotoImage(
                assetPath: imagePath,
                coverAlignment: imageAlignment,
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xCC000000),
                      Color(0x66000000),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
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
}
