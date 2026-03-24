import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
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
import 'package:barky_matches_fixed/playmate_page.dart';

import 'package:barky_matches_fixed/screens/lost_dog_report_page.dart';
import 'package:barky_matches_fixed/screens/lost_dogs_list_page.dart';
import 'package:barky_matches_fixed/screens/found_dogs_list_page.dart';
import 'package:barky_matches_fixed/screens/found_dog_report_page.dart';

import 'dart:async';

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


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin, LocalizationUtils {

  
  late Box<String> userBox;
  String? _currentUserId;
late Box<List<String>> savedParksBox;


  //String _username = 'User';
  late Box<Dog> dogsBox;

  List<Dog> _filteredDogs = [];
  List<Dog> _userDogs = [];

  bool _isLoading = true;
  bool _isLocationLoading = true;
  final GlobalKey _safetyKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  String? selectedBreed;
  String? selectedGender;
  RangeValues? ageRange;
  bool? selectedNeutered;
  String? selectedHealthStatus;

  bool _toBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  return false;
}


  double? _userLatitude;
  double? _userLongitude;

  double _maxDistance = 50.0;
  bool _isPremium = false;
  bool _isPremiumLoaded = false;

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

  //final appState = context.watch<AppState>();
//final username = appState.username ?? 'User';


  static const Color _cardColor = Color(0xFF9E1B4F);

  bool _bootstrapped = false;

  final List<FeaturedDeal> _featuredDeals = const [
  FeaturedDeal(
    shopName: "Pet Shop A",
    description: "15% OFF on all food",
    discountPercent: 15,
    logoAsset: "assets/brands/petshop_a_logo.png",
    goldOnly: false,
    premiumOnly: false,
  ),
  FeaturedDeal(
    shopName: "Groomy Studio",
    description: "20% OFF grooming this week",
    discountPercent: 20,
    logoAsset: "assets/brands/groomy_logo.png",
    premiumOnly: true,
  ),
  FeaturedDeal(
    shopName: "VetPlus",
    description: "Gold members: free checkup",
    discountPercent: 0,
    logoAsset: "assets/brands/vetplus_logo.png",
    goldOnly: true,
  ),
];


@override
bool get wantKeepAlive => true;


@override
void initState() {
  super.initState();
_dealPageController = PageController(viewportFraction: 0.92);
_startAutoSlide();
  debugPrint('🧱 HomePage initState hash=${identityHashCode(this)} key=${widget.key}');


  userBox = Hive.box<String>('userBox');
  dogsBox = Hive.box<Dog>('dogsBox');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_bootstrapped) {
      _bootstrapped = true;
      //_bootstrapHome();
    }
  });
}

Future<void> _restoreSavedParksIfMissing() async {
  final uid = _currentUserId;
  if (uid == null) return;

  final userRef =
      FirebaseFirestore.instance.collection('users').doc(uid);

  final doc = await userRef.get();
  final data = doc.data();

  final List<String> localParks =
      savedParksBox.get(uid) ?? [];

  // اگر Firestore خالیه ولی لوکال داریم → restore
  if ((data?['savedParks'] == null ||
          (data?['savedParks'] as List).isEmpty) &&
      localParks.isNotEmpty) {
    await userRef.set(
      {'savedParks': localParks},
      SetOptions(merge: true),
    );

    debugPrint(
        '♻️ Restored savedParks from local cache: $localParks');
  }
}


@override
void didUpdateWidget(covariant HomePage oldWidget) {
  super.didUpdateWidget(oldWidget);
  debugPrint('🔁 HomePage didUpdateWidget hash=${identityHashCode(this)}');
}

/*
Future<void> _bootstrapHome() async {
  debugPrint('🚀 HomePage bootstrap start');

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  _currentUserId = user.uid;

  // 🔥 این خط حیاتی است
  if (!Hive.isBoxOpen('savedParksBox')) {
    await Hive.openBox<List<String>>('savedParksBox');
  }

  savedParksBox = Hive.box<List<String>>('savedParksBox');

  await _restoreSavedParksIfMissing();
  await _loadDataOnce();
}
*/


  Future<void> _initMapIfNeeded() async {
    if (!Platform.isIOS) {
      _isMapReady = true;
      return;
    }

    try {
      _isMapReady = true;
      print('HomePage - Map SDK ready');
    } catch (e) {
      _mapInitFailed = true;
      _isMapReady = false;
      print('HomePage - Map init failed: $e');
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
          print('Ad failed to load: ${error.message} (code: ${error.code})');
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

  //await _loadUsernameFromFirebase();
  //await _loadUserPremiumStatus();
  //await _loadLocationAndFilters();

  _dataLoaded = true; // ✅ فقط بعد از اتمام
}


/*
  Future<void> _loadUserPremiumStatus() async {
    if (_isPremiumLoaded) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _isPremium = userData['isPremium'] ?? false;
          _maxDistance = _isPremium ? 100.0 : 50.0;
          _isPremiumLoaded = true;
          print('HomePage - Loaded _isPremium: $_isPremium, _maxDistance: $_maxDistance');
        });
      } else {
       

        if (!mounted) return;
        setState(() {
          _isPremium = false;
          _maxDistance = 50.0;
          _isPremiumLoaded = true;
          print('HomePage - Created default user document for userId: $_currentUserId');
        });
      }
    } catch (e) {
      print('HomePage - Error loading premium status: $e');
      if (!mounted) return;
      setState(() {
        _isPremium = false;
        _maxDistance = 50.0;
        _isPremiumLoaded = true;
        print('HomePage - Error occurred, defaulting _isPremium: false, _maxDistance: 50.0');
      });
    }
  }


  Future<void> _loadUsernameFromFirebase() async {
  try {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) {
      debugPrint('⛔️ _loadUsernameFromFirebase skipped (no uid)');
      return;
    }

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(uid);

    final userDoc = await userRef.get();

    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _username = userData['username'] ?? 'User';
        _isLoading = false;
      });

      debugPrint('HomePage - User data found from Firestore: $userData');
      debugPrint('HomePage - Username set to: $_username');
    } else {
      final defaultUsername =
          FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? 'User';

      // 🔐 بسیار مهم: merge:true تا هیچ دیتایی (مثل savedParks) پاک نشه
      await userRef.set(
        {
          'username': defaultUsername,
          'email': FirebaseAuth.instance.currentUser?.email ?? '',
          'isPremium': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() {
        _username = defaultUsername;
        _isLoading = false;
      });

      debugPrint(
        'HomePage - Default user document ensured (merge) for userId: $uid',
      );
    }
  } catch (e, s) {
    debugPrint('❌ HomePage - Error loading username from Firestore: $e');
    debugPrint('$s');

    if (!mounted) return;
    setState(() {
      _username = 'User';
      _isLoading = false;
    });
  }
}

*/

  Future<void> _syncDogsWithFirestore() async {
    try {
      final dogsSnapshot = await FirebaseFirestore.instance.collection('dogs').get();
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
          print('HomePage - Loaded dog: ${dog.name}, id: ${dog.id}, ownerId: ${dog.ownerId}');
        } else {
          print('HomePage - Skipped duplicate dog: ${dog.name}, id: ${dog.id}');
          await FirebaseFirestore.instance.collection('dogs').doc(doc.id).delete();
          print('HomePage - Deleted duplicate dog from Firestore: ${doc.id}');
        }
      }

      await dogsBox.clear();
      await dogsBox.putAll(uniqueDogs);
      print('HomePage - Synced ${uniqueDogs.length} unique dogs from Firestore to Hive');
    } catch (e) {
      print('HomePage - Error syncing dogs with Firestore: $e');
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

    await _getCurrentLocation();

    if (!mounted) return;
    setState(() => _isLocationLoading = false);
    //await _applyFiltersAsync();
  }

  Future<void> _loadUserDogs() async {
  if (!mounted) {
    debugPrint('⛔️ _loadUserDogs aborted (unmounted)');
    return;
  }

  if (_currentUserId == null) {
    debugPrint('⛔️ _loadUserDogs skipped (uid is null)');
    return;
  }

  if (_userDogsLoaded) {
    debugPrint('⛔️ _loadUserDogs skipped (already loaded)');
    return;
  }

  _userDogsLoaded = true;

  final appState = context.read<app.AppState>();
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

  Future<void> _fetchLikesForDog(String dogId) async {
    try {
      final likesSnapshot = await FirebaseFirestore.instance
          .collection('likes')
          .where('dogId', isEqualTo: dogId)
          .get();

      List<Map<String, dynamic>> likers = [];
      for (var doc in likesSnapshot.docs) {
        final likerUserId = doc['likerUserId'];
        final userSnapshot = await FirebaseFirestore.instance.collection('users').doc(likerUserId).get();
        final username = userSnapshot.exists ? userSnapshot['username'] : 'Unknown';
        final email = userSnapshot.exists ? userSnapshot['email'] : 'Unknown Email';
        likers.add({'username': username, 'email': email});
      }

      if (!mounted) return;
      setState(() {
        dogLikes[dogId] = likers;
        print('HomePage - Fetched ${likers.length} likes for dog: $dogId');
      });
    } catch (e) {
      print('HomePage - Error fetching likes for dog $dogId: $e');
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
    if (filters != null) {
      selectedBreed = filters['breed'] as String?;
      selectedGender = filters['gender'] as String?;
      ageRange = filters['ageRange'] as RangeValues?;
      _maxDistance = (filters['maxDistance'] as double?)
              ?.clamp(1.0, _isPremium ? 100.0 : 50.0) ??
          _maxDistance;

      _userLatitude = (filters['userLatitude'] as double?) ?? _userLatitude;
      _userLongitude = (filters['userLongitude'] as double?) ?? _userLongitude;

      selectedNeutered = filters['neutered'] as bool?;
      selectedHealthStatus = filters['healthStatus'] as String?;
    } else {
      _maxDistance = _isPremium ? 100.0 : 50.0;
    }

    final sourceDogs = dogsBox.values.toList(); // ✅ منبع واقعی داده
final dogsData = sourceDogs.map((dog) => {
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
}).toList();


    final filteredDogsData = await compute(_applyFiltersIsolate, {
      'dogs': dogsData,
      'currentUserId': _currentUserId,
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
    });

    if (!mounted) return;
    setState(() {
      _filteredDogs = filteredDogsData
          .map((data) => Dog(
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
              ))
          .toList()
          .take(10)
          .toList();

      print('HomePage - Filtered dogs count: ${_filteredDogs.length}');
    });
  }

  static List<Map<String, dynamic>> _applyFiltersIsolate(Map<String, dynamic> params) {
    final List<Map<String, dynamic>> dogs = params['dogs'];
    final String currentUserId = params['currentUserId'];

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

    return uniqueDogs.values.where((dog) {
      // 1) not own dog
     final bool isMyDog = dog['ownerId'] == currentUserId;
final bool isAdoption = dog['isAvailableForAdoption'] == true;

// 🔑 فقط سگ‌های خودم که adoption نیستن حذف بشن
if (isMyDog && !isAdoption) {
  return false;
}

      // 2) filters
      final matchesBreed = selectedBreed == null || dog['breed'] == selectedBreed;
      final matchesGender = selectedGender == null || dog['gender'] == selectedGender;
      final matchesAge = ageRange == null ||
          (dog['age'] >= ageRange['start']! && dog['age'] <= ageRange['end']!);

      bool matchesDistance = true;
      if (userLatitude != null &&
          userLongitude != null &&
          dog['latitude'] != null &&
          dog['longitude'] != null &&
          userLatitude != 0.0 &&
          userLongitude != 0.0) {
        final distanceInMeters = Geolocator.distanceBetween(
          userLatitude,
          userLongitude,
          dog['latitude'],
          dog['longitude'],
        );
        matchesDistance = (distanceInMeters / 1000) <= maxDistance;
      }

      final matchesNeutered = selectedNeutered == null || dog['isNeutered'] == selectedNeutered;
      final matchesHealth = selectedHealthStatus == null || dog['healthStatus'] == selectedHealthStatus;

      return matchesBreed &&
          matchesGender &&
          matchesAge &&
          matchesDistance &&
          matchesNeutered &&
          matchesHealth;
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
  debugPrint('💥 HomePage dispose hash=${identityHashCode(this)} key=${widget.key}');
  print('HomePage - Disposing resources');

  _dealPageController?.dispose();
  _dealTimer?.cancel();

  super.dispose();
}


  Widget _buildHeaderGreeting(app.AppState appState) {
  final username = appState.username ?? 'User';

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello,',
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
  );
}



  Widget _buildMainFeaturesGrid() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.75,
      ),
      children: [

        _featureCard(
          title: "Playmates",
          subtitle: "Find new friends",
          imagePath: "assets/home/playmates.png",
          onTap: () {
            context.read<app.AppState>()
                .setCurrentTab(NavTab.playmates);
          },
        ),

        _featureCard(
          title: "Playdates",
          subtitle: "Manage requests",
          imagePath: "assets/home/playdate.png",
          onTap: () {
            context.read<app.AppState>()
                .setCurrentTab(NavTab.playdate);
          },
        ),

        _featureCard(
          title: "Adoption",
          subtitle: "Give love",
          imagePath: "assets/home/adoption.png",
          onTap: () {
            context.read<app.AppState>()
                .setCurrentTab(NavTab.adoption);
          },
        ),

        _featureCard(
  title: "Alerts",
  subtitle: "Lost & Found",
  imagePath: "assets/home/Warning-pana.png",
  onTap: _scrollToSafety,
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


Widget _buildServicesSection() {
  final appState = context.read<app.AppState>();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      /// 🔹 Vet (Wide Premium Card)
      _wideImagePlaceCard(
        title: "Vet",
        subtitle: "Nearby clinics",
        imagePath: "assets/home/vet.png",
        onTap: () {
          appState.setCurrentTab(NavTab.vet);
        },
      ),

      const SizedBox(height: 16),

      /// 🔹 Groomy & Pet Shop
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [

            Expanded(
              child: _miniServiceCard(
                title: "Groomy",
                subtitle: "Book grooming",
                imagePath: "assets/home/groomy.png",
                onTap: () {
                  // navigate to grooming list
                },
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: _miniServiceCard(
                title: "Pet Shop",
                subtitle: "Shop near you",
                imagePath: "assets/home/petshop.png",
                onTap: () {
                  // navigate to pet shop list
                },
              ),
            ),
          ],
        ),
      ),

      /// 👇 اینجا باید بیاد 👇
      const SizedBox(height: 20),

      _featuredDealsCarousel(
        deals: _featuredDeals,
        onTapDeal: (deal) {
          // اینجا تصمیم می‌گیری به کجا بره
          // مثلا:
          // Navigator.push(...)
        },
      ),

    ],
  );
}

Widget _featuredDealsCarousel({
  required List<FeaturedDeal> deals,
  required void Function(FeaturedDeal deal) onTapDeal,
}) {
  if (deals.isEmpty) return const SizedBox.shrink();

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
  // همون vibe تصویرت: گرادیان نارنجی/طلایی
  const grad = LinearGradient(
    colors: [
      Color(0xFFFFC107),
      Color(0xFFFF9800),
    ],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        const Text(
                          "🔥 Featured Deal",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (deal.premiumOnly)
                          _accessPill("Premium"),
                        if (deal.goldOnly) ...[
                          const SizedBox(width: 6),
                          _accessPill("Gold"),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      deal.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      deal.description,
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
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          "${deal.discountPercent}% OFF",
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

              // RIGHT: logo (نه تصویر تبلیغاتی)
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  deal.logoAsset,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
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
  super.build(context);

  final currentTab = context.watch<app.AppState>().currentTab;

  debugPrint('🟢 HomePage BUILD → currentTab = $currentTab');
final lostCount =
    context.select<app.AppState, int>((s) => s.lostDogsCount);

final foundCount =
    context.select<app.AppState, int>((s) => s.foundDogsCount);

  final appState = context.watch<app.AppState>();
  final userId = appState.currentUserId;
 

final allDogs = appState.allDogs;


  //if (userId == null) {
    //return const Center(child: CircularProgressIndicator());
  //}
return SingleChildScrollView(
  controller: _scrollController,

  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      const SizedBox(height: 16),

      _buildHeaderGreeting(appState),

    
      // 🔹 SECTION 1 — Social
      _buildSectionHeader("Social & Play"),
      const SizedBox(height: 16),
      _buildMainFeaturesGrid(),

      const SizedBox(height: 32),

      // 🔹 SECTION 2 — Revenue
      _buildSectionHeader("Care & Services"),
      const SizedBox(height: 16),
      _buildServicesSection(),

      const SizedBox(height: 32),

      // 🔹 SECTION 3 — Outdoor
      _buildSectionHeader("Outdoor & Lifestyle"),
      const SizedBox(height: 16),
      _buildPlacesSection(),

      const SizedBox(height: 32),

      // 🔹 SECTION 4 — Safety
      Container(
  key: _safetyKey,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSafetyHeader(lostCount + foundCount),
      const SizedBox(height: 16),
      _buildSafetySection(),
    ],
  ),
),


      const SizedBox(height: 32),

    ],
  ),
);

}
Widget _featureCard({
  required String title,
  required String subtitle,
  required String imagePath,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF9E1B4F),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.start,
    children: [

      const SizedBox(height: 6),

      /// TITLE (کمی بالاتر)
      Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      const SizedBox(height: 16),

      /// IMAGE (بزرگ‌تر)
      SizedBox(
        height: 110,
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
        ),
      ),

      const Spacer(),

      /// SUBTITLE (باکس جدا)
      Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF7C123A).withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.white.withOpacity(0.95),
          ),
          textAlign: TextAlign.center,
        ),
      ),

      const SizedBox(height: 8),
    ],
  ),
),

      ),
    ),
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
  final appState = context.read<app.AppState>();

  return Column(
    children: [
      _wideImagePlaceCard(
        title: "Dog Park",
        subtitle: "Explore nearby parks",
        imagePath: "assets/home/dog_park.png",
        onTap: () {
          appState.setCurrentTab(NavTab.dogParks);
        },
      ),
      const SizedBox(height: 16),
      _wideImagePlaceCard(
        title: "Training",
        subtitle: "Coming soon",
        imagePath: "assets/home/Good doggy-cuate.png",
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Training feature coming soon 🐾"),
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
    padding: const EdgeInsets.symmetric(horizontal: 20), // ✅ فاصله از کناره‌ها
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          height: 150,
          decoration: BoxDecoration(
            color: const Color(0xFF9E1B4F),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [

                /// 🔹 LEFT SIDE (Texts)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C123A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// 🔹 RIGHT SIDE (Image)
                SizedBox(
                  height: 95,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
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
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFF9E1B4F),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [

            /// 🔹 Sponsored Badge
            if (isSponsored)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Sponsored",
                    style: TextStyle(
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

                  /// Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color:
                                Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// Image
                  SizedBox(
                    height: 70,
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.contain,
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
          "Community Hub",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF9E1B4F),
          ),
        ),
        const Spacer(),

        if (lostCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF9E1B4F),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "$lostCount active",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
      ],
    ),
  );
}


Widget _buildSafetySection() {
  final appState = context.read<app.AppState>();
final lostCount =
    context.select<app.AppState, int>((s) => s.lostDogsCount);

final foundCount =
    context.select<app.AppState, int>((s) => s.foundDogsCount);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.75,
      ),
      children: [

        _safetyCard(
          title: "Report",
          subtitle: "Lost Dog",
          imagePath: "assets/home/Warning-pana.png",
          onTap: () {
            appState.setCurrentTab(NavTab.reportLost);
          },
        ),

        _safetyCard(
          title: "Report",
          subtitle: "Found Dog",
          imagePath: "assets/home/lost_dog.png",
          onTap: () {
            appState.setCurrentTab(NavTab.reportFound);
          },
        ),

        _safetyCard(
  title: "Lost",
  subtitle: "Dogs",
  imagePath: "assets/home/found_dog.png",
  hasAlert: lostCount > 0,
  count: lostCount,
  onTap: () {
    appState.setCurrentTab(NavTab.lostDogs);
  },
),


        _safetyCard(
  title: "Found",
  subtitle: "Dogs",
  imagePath: "assets/home/Good doggy-amico.png",
  hasAlert: foundCount > 0,
  count: foundCount,
  onTap: () {
  appState.closeFoundDogDetail(); // 🔥 این درستشه
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
  return _AnimatedSafetyCard(
  title: title,
  subtitle: subtitle,
  imagePath: imagePath,
  onTap: onTap,
  hasAlert: hasAlert,
  count: count,
);
}

}

class _AnimatedSafetyCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final VoidCallback onTap;
  final bool hasAlert;
  final int count;


  const _AnimatedSafetyCard({
  required this.title,
  required this.subtitle,
  required this.imagePath,
  required this.onTap,
  required this.hasAlert,
  required this.count,
});

  @override
  State<_AnimatedSafetyCard> createState() => _AnimatedSafetyCardState();
}

class _AnimatedSafetyCardState extends State<_AnimatedSafetyCard>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _glow;

  @override
void initState() {
  super.initState();

  _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  _glow = Tween<double>(
    begin: 0.15,
    end: 0.35,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ),
  );

  _controller.repeat(reverse: true);
}

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  return AnimatedBuilder(
    animation: _glow,
    builder: (context, child) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: widget.hasAlert
                ? const LinearGradient(
                    colors: [
                      Color(0xFFFF5252),
                      Color(0xFFFF9800),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [
                      Color(0xFFFFD54F),
                      Color(0xFFFFC107),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: [
              BoxShadow(
                color: widget.hasAlert
                    ? Colors.red.withOpacity(_glow.value)
                    : const Color(0xFFFFC107)
                        .withOpacity(_glow.value),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF9E1B4F),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 18),
              child: Column(
                children: [

                  /// TITLE
                  Text(
                    widget.title,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// IMAGE (same as main cards)
                  SizedBox(
                    height: 110,
                    child: Image.asset(
                      widget.imagePath,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const Spacer(),

                  /// SUBTITLE
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C123A)
                          .withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.95),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
}