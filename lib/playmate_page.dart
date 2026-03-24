

import 'dart:async';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:collection/collection.dart';
import 'dog_card.dart';
import 'filter_page.dart';
import 'adoption_page.dart';
import 'dart:io' show InternetAddress, SocketException;
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/utils/localization_utils.dart';
import 'dart:io' show Platform;
import 'package:barky_matches_fixed/ui/shell/barky_scaffold.dart';
import 'ui/shell/nav_tab.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'other_user_dog_page.dart';
import 'debug/firestore_debug.dart';


enum PlaymatePageMode {
  browse,
  selectDogForPlaydate,
}


class PlaymatePage extends StatefulWidget {
  final List<Dog> dogs;
  final String currentUserId;
  final List<Dog>? favoriteDogs;
  final void Function(Dog)? onToggleFavorite;
  final PlaymatePageMode mode; // ✅ ADD

  const PlaymatePage({
    super.key,
    required this.dogs,
    required this.currentUserId,
    this.favoriteDogs,
    this.onToggleFavorite,
    this.mode = PlaymatePageMode.browse, // ✅ DEFAULT
  });



  @override
  State<PlaymatePage> createState() => _PlaymatePageState();
}

class _PlaymatePageState extends State<PlaymatePage>
    with AutomaticKeepAliveClientMixin, LocalizationUtils, SingleTickerProviderStateMixin {

  late AnimationController _overlayController;
  late Animation<double> _overlayAnimation;
  String? selectedBreed;
  String? selectedGender;
  RangeValues? ageRange;
  bool? selectedNeutered;
  String? selectedHealthStatus;
  List<Dog> _filteredDogs = [];
  List<Dog> _allDogs = [];
  late Box<Dog> dogsBox;
  double? _userLatitude;
  double? _userLongitude;
  double _maxDistance = 50.0;
  bool _isPremium = false;
  bool _isPremiumLoaded = false;
  bool _isLoading = true;
  int _unreadNotificationsCount = 0;
  bool get isSelectMode =>
    widget.mode == PlaymatePageMode.selectDogForPlaydate;
Timer? _searchDebounce;
List<Dog> _sourceDogs = []; // 🔥 SOURCE OF TRUTH
StreamSubscription<QuerySnapshot>? _dogsSubscription;
  String _searchQuery = '';
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;
      static bool _safeBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  return false;
}

 
  bool get wantKeepAlive => true;
@override
void initState() {
  super.initState();
  dogsBox = Hive.box<Dog>('dogsBox');

  if (kDebugMode) {
    print('PlaymatePage - Init: mode=${widget.mode}');
  }
final appState = context.read<AppState>();

if (appState.isGuest) {
  debugPrint("👀 Guest mode → Playmate limited mode");
}
  if (!isSelectMode) {
   //_loadData();
    _checkInternetAndStartStream();
    _startDogsStream();
    Future.delayed(const Duration(milliseconds: 500), () {
  if (mounted) {
    _precacheDogImages(_filteredDogs);
  }
});
  } else {
  final appState = context.read<AppState>();

  _allDogs = appState.allDogs;
  _filteredDogs = _allDogs;
  _isLoading = false;

  if (kDebugMode) {
    print(
      '🟢 PlaymatePage SELECT MODE → using AppState.allDogs only: ${_filteredDogs.length}',
    );
  }

  }
  _overlayController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 250),
);

_overlayAnimation = CurvedAnimation(
  parent: _overlayController,
  curve: Curves.easeOut,
);
}

// ===============================
// 🧠 FILTER FUNCTION (MOVE HERE)
// ===============================
List<Dog> _applyFiltersMainThread({
  required List<Dog> sourceDogs,
  required String currentUserId,
  required String? selectedBreed,
  required String? selectedGender,
  required RangeValues? ageRange,
  required double? userLatitude,
  required double? userLongitude,
  required double maxDistance,
  required bool? selectedNeutered,
  required String? selectedHealthStatus,
}) {
  return sourceDogs.where((dog) {

    if (dog.isHidden == true) return false;
    if (dog.ownerProfileVisible != true) return false;
    if (dog.dogProfileVisible != true) return false;
    if (dog.ownerId == currentUserId) return false;

    final matchesBreed =
        selectedBreed == null || dog.breed == selectedBreed;

    final matchesGender =
        selectedGender == null || dog.gender == selectedGender;

    final matchesAge =
        ageRange == null ||
        (dog.age >= ageRange.start &&
            dog.age <= ageRange.end);

    bool matchesDistance = true;

    if (userLatitude != null &&
        userLongitude != null &&
        dog.latitude != null &&
        dog.longitude != null) {

      final meters = Geolocator.distanceBetween(
        userLatitude,
        userLongitude,
        dog.latitude!,
        dog.longitude!,
      );

      matchesDistance = (meters / 1000) <= maxDistance;
    }

    final matchesNeutered =
        selectedNeutered == null ||
        dog.isNeutered == selectedNeutered;

    final matchesHealth =
        selectedHealthStatus == null ||
        dog.healthStatus == selectedHealthStatus;

    return matchesBreed &&
        matchesGender &&
        matchesAge &&
        matchesDistance &&
        matchesNeutered &&
        matchesHealth;

  }).toList();
}

void _startDogsStream() {
  if (_dogsSubscription != null) return;

  _dogsSubscription = FirebaseFirestore.instance
      .collection('dogs')
      .snapshots()
      .listen((snapshot) {

    final appState = context.read<AppState>();

    // 🐶 MAP DATA
    final List<Dog> sourceDogs = snapshot.docs.map((doc) {
      final data = doc.data();

      return Dog(
        id: doc.id,
        name: data['name'] ?? '',
        breed: data['breed'] ?? '',
        age: (data['age'] ?? 0),
        gender: data['gender'] ?? '',
        healthStatus: data['healthStatus'] ?? '',
        isNeutered: data['isNeutered'] ?? false,
        description: data['description'] ?? '',
        traits: List<String>.from(data['traits'] ?? []),
        ownerGender: data['ownerGender'] ?? '',
        imagePaths: List<String>.from(data['imagePaths'] ?? []),
        isAvailableForAdoption: data['isAvailableForAdoption'] ?? false,
        isOwner: data['isOwner'] ?? false,
        ownerId: data['ownerId'] ?? '',
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        isHidden: data['isHidden'] ?? false,
        dogProfileVisible: data['dogProfileVisible'] ?? true,
        ownerProfileVisible: data['ownerProfileVisible'] ?? true,
      );
    }).toList();

    // 🔥 جلوگیری از update بی‌خودی AppState
    final currentDogs = appState.allDogs;

    final isSame = listEquals(
      currentDogs.map((e) => e.id).toList(),
      sourceDogs.map((e) => e.id).toList(),
    );

    if (!isSame) {
      appState.setAllDogs(sourceDogs);
    }

    // 🔍 APPLY FILTERS
    final filtered = _applyFiltersMainThread(
      sourceDogs: sourceDogs,
      currentUserId: appState.currentUserId ?? '',
      selectedBreed: selectedBreed,
      selectedGender: selectedGender,
      ageRange: ageRange,
      userLatitude: _userLatitude,
      userLongitude: _userLongitude,
      maxDistance: _maxDistance,
      selectedNeutered: selectedNeutered,
      selectedHealthStatus: selectedHealthStatus,
    );

    // 🔍 APPLY SEARCH
    final finalList = _searchQuery.isEmpty
        ? filtered
        : filtered.where((dog) {
            return dog.name.toLowerCase().contains(_searchQuery);
          }).toList();

    // 🧹 REMOVE DUPLICATES
    final Map<String, Dog> uniqueDogs = {};
    for (final dog in finalList) {
      uniqueDogs.putIfAbsent(dog.id, () => dog);
    }

    if (!mounted) return;

    setState(() {
      
      _sourceDogs = sourceDogs;
      _filteredDogs = uniqueDogs.values.toList();
      _isLoading = false;

      debugPrint("🔥 SOURCE DOGS: ${_sourceDogs.length}");
      debugPrint("🎯 FINAL DOGS: ${_filteredDogs.length}");
    });
_precacheDogImages(_filteredDogs);
  });
}

Future<void> _precacheDogImages(List<Dog> dogs) async {
  if (!mounted) return;

  for (final dog in dogs.take(6)) { // 👈 فقط 6 تا اول (performance safe)
    for (final path in dog.imagePaths.take(1)) { // 👈 فقط عکس اول
      try {
        final imageProvider = NetworkImage(path);

        await precacheImage(imageProvider, context);

        debugPrint("🧠 precached: $path");
      } catch (e) {
        debugPrint("❌ precache failed: $e");
      }
    }
  }
}

  Future<void> _checkInternetAndStartStream() async {

  final user = FirebaseAuth.instance.currentUser;

  // 🚨 اگر logout شده باشد listener اصلاً شروع نمی‌شود
  if (user == null) {
    debugPrint('🛑 PlaymatePage: user is null, notifications stream blocked');
    return;
  }

  if (_notificationsSubscription != null) return;

  bool hasInternet = await _checkInternetConnection();
  if (!hasInternet) {
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) {
      _checkInternetAndStartStream();
    }
    return;
  }

 _notificationsSubscription = debugSnapshots(
  FirebaseFirestore.instance
      .collection('notifications')
      .where('recipientUserId', isEqualTo: user.uid)
      .where('isRead', isEqualTo: false),
  "PlaymatePage notifications",
).listen((snapshot) {

        if (!mounted) return;

        setState(() {
          _unreadNotificationsCount = snapshot.docs.length;
        });

      }, onError: (e) {
        debugPrint('❌ notifications listener error: $e');
      });
}
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _loadUnreadNotificationsCount() async {
    final appState = context.read<AppState>();
    try {
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientUserId', isEqualTo: appState.currentUserId ?? '')
          .where('isRead', isEqualTo: false)
          .get();
      if (!mounted) return;

setState(() {
          _unreadNotificationsCount = notificationsSnapshot.docs.length;
          if (kDebugMode) {
            print('PlaymatePage - Loaded unread notifications count: $_unreadNotificationsCount');
          }
        });
      }
     catch (e, stackTrace) {
      if (kDebugMode) {
        print('PlaymatePage - Error loading unread notifications count: $e');
        print('StackTrace: $stackTrace');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingNotifications(e.toString()), style: GoogleFonts.poppins())),
        );
      }
    }
  }

  

  Future<void> _loadData() async {
  if (isSelectMode) {
    if (kDebugMode) {
      print('⛔ _loadData blocked (selectDogForPlaydate)');
    }
    return;
  }
if (!mounted) return;

final appState = context.read<AppState>();

if (!mounted) return;

setState(() {
  _isLoading = true;
});
    try {
      bool isPremium = false;
      double maxDistance = 50.0;
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
if (!mounted) return;

          isPremium = userDoc.data()?['isPremium'] as bool? ?? false;
          maxDistance = isPremium ? 100.0 : 50.0;
          if (kDebugMode) {
            print('PlaymatePage - Loaded _isPremium: $isPremium, _maxDistance: $maxDistance');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('PlaymatePage - Error loading premium status: $e');
        }
      }

      double? userLatitude;
      double? userLongitude;
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          userLatitude = 41.0103;
          userLongitude = 28.6724;
          if (kDebugMode) {
            print('PlaymatePage - Location services are disabled, using default position');
          }
        } else {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
            permission = await Geolocator.requestPermission();
            if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
              userLatitude = 41.0103;
              userLongitude = 28.6724;
              if (kDebugMode) {
                print('PlaymatePage - Location permission denied, using default position');
              }
            }
          }
          if (permission == LocationPermission.whileInUse ||
    permission == LocationPermission.always) {

  final lastPosition = await Geolocator.getLastKnownPosition();

  if (lastPosition != null) {
    userLatitude = lastPosition.latitude;
    userLongitude = lastPosition.longitude;
  } else {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );

    userLatitude = position.latitude;
    userLongitude = position.longitude;
  }

  if (!mounted) return;

  if (kDebugMode) {
    print('PlaymatePage - Current position: $userLatitude, $userLongitude');
  }
}
        }
      } catch (e) {
        userLatitude = 41.0103;
        userLongitude = 28.6724;
        if (kDebugMode) {
          print('PlaymatePage - Error getting location: $e, using default position');
        }
      }

      // ===============================
// 🧹 Hive Sync (Always ON)
// ===============================

// 1️⃣ حذف سگ‌های قدیمی که دیگه در uniqueDogs نیستن


  if (!isSelectMode) {

  final existingKeys = dogsBox.keys.cast<String>().toList();

  for (final key in existingKeys) {
    if (!_allDogs.any((d) => d.id == key)) {
      await dogsBox.delete(key);
    }
  }

  for (final dog in _allDogs) {
    await dogsBox.put(dog.id, dog);
  }

}

// 2️⃣ اضافه‌کردن یا آپدیت سگ‌های جدید


  

if (kDebugMode) {
  print(
    'PlaymatePage - Hive sync completed, total dogs in Hive: ${dogsBox.length}',
  );
}

      if (mounted) {
        setState(() {
          _isPremium = isPremium;
          _maxDistance = maxDistance;
          _userLatitude = userLatitude;
          _userLongitude = userLongitude;
         _filteredDogs = _sourceDogs;
          _isPremiumLoaded = true;
          _isLoading = false;
          if (kDebugMode) {
            print('PlaymatePage - _isLoading set to false, filteredDogs: ${_filteredDogs.length}');
          }
        });
        if (!mounted) return;
_loadUnreadNotificationsCount();
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('PlaymatePage - Error in _loadData: $e');
        print('StackTrace: $stackTrace');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingData(e.toString()), style: GoogleFonts.poppins())),
        );
        setState(() {
          _isPremium = false;
          _maxDistance = 50.0;
          _isPremiumLoaded = true;
          _userLatitude = 41.0103;
          _userLongitude = 28.6724;
          _filteredDogs = [];
          _isLoading = false;
        });
      }
    }
  }

  static List<Dog> _applyFiltersIsolate(List<dynamic> args) {
    final List<Map<String, dynamic>> dogs = args[0] as List<Map<String, dynamic>>;
    final String currentUserId = args[1] as String;
    final String? selectedBreed = args[2] as String?;
    final String? selectedGender = args[3] as String?;
    final RangeValues? ageRange = args[4] as RangeValues?;
    final double? userLatitude = args[5] as double?;
    final double? userLongitude = args[6] as double?;
    final double maxDistance = args[7] as double;
    final bool? selectedNeutered = args[8] as bool?;
    final String? selectedHealthStatus = args[9] as String?;

    final filteredDogs = dogs.where((dogMap) {
      if (dogMap['isHidden'] == true) return false;

if (dogMap['ownerProfileVisible'] == false) return false;

if (dogMap['dogProfileVisible'] == false) return false;
      //final notOwnDog = (dogMap['ownerId']?.toLowerCase() ?? '') != currentUserId.toLowerCase();
      final ownerId = dogMap['ownerId'] as String?;

if (ownerId == currentUserId) {
  if (kDebugMode) {
    print(
      'PlaymatePage - Excluding dog ${dogMap['name']} because ownerId ($ownerId) matches currentUserId ($currentUserId)',
    );
  }
  return false;
}

      bool matchesBreed = selectedBreed == null || dogMap['breed'] == selectedBreed;
      bool matchesGender = selectedGender == null || dogMap['gender'] == selectedGender;
      bool matchesAge = ageRange == null || (dogMap['age'] >= ageRange.start && dogMap['age'] <= ageRange.end);
      bool matchesDistance = true;
      if (userLatitude != null && userLongitude != null && dogMap['latitude'] != null && dogMap['longitude'] != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          userLatitude,
          userLongitude,
          dogMap['latitude'] as double,
          dogMap['longitude'] as double,
        );
        double distanceInKm = distanceInMeters / 1000;
        matchesDistance = distanceInKm <= maxDistance;
        if (kDebugMode) {
          print('PlaymatePage - Distance to ${dogMap['name']}: $distanceInKm km');
        }
      }
      bool matchesNeutered = selectedNeutered == null || dogMap['isNeutered'] == selectedNeutered;
      bool matchesHealth = selectedHealthStatus == null || dogMap['healthStatus'] == selectedHealthStatus;

      bool matches = matchesBreed && matchesGender && matchesAge && matchesDistance && matchesNeutered && matchesHealth;
      if (kDebugMode) {
        print('PlaymatePage - Dog ${dogMap['name']}: matchesBreed=$matchesBreed, matchesGender=$matchesGender, matchesAge=$matchesAge, matchesDistance=$matchesDistance, matchesNeutered=$matchesNeutered, matchesHealth=$matchesHealth, overall=$matches');
      }
      return matches;
    }).map((dogMap) => Dog(
          id: dogMap['id'] as String,
          name: dogMap['name'] as String,
          breed: dogMap['breed'] as String,
          age: (dogMap['age'] as num).toInt(),
          gender: dogMap['gender'] as String,
          healthStatus: dogMap['healthStatus'] as String,
          isNeutered: _safeBool(dogMap['isNeutered']),
          description: dogMap['description'] as String,
          traits: List<String>.from(dogMap['traits'] ?? []),
          ownerGender: dogMap['ownerGender'] as String,
          imagePaths: List<String>.from(dogMap['imagePaths'] ?? []),
          isAvailableForAdoption: _safeBool(dogMap['isAvailableForAdoption']),
          isOwner: _safeBool(dogMap['isOwner']),
          ownerId: dogMap['ownerId'] as String,
          latitude: (dogMap['latitude'] as num?)?.toDouble() ?? 0.0,
longitude: (dogMap['longitude'] as num?)?.toDouble() ?? 0.0,
reportCount: dogMap['reportCount'] ?? 0,
isHidden: dogMap['isHidden'] ?? false,
moderationStatus: dogMap['moderationStatus'] ?? "active",

        )).toList();

    return filteredDogs;
  }

  Future<void> _applyFiltersAsync({Map<String, dynamic>? filters}) async {
    final appState = context.read<AppState>();
    if (kDebugMode) {
      print('PlaymatePage - Starting _applyFiltersAsync with filters: $filters');
    }
    if (filters != null) {
      selectedBreed = filters['breed'] as String?;
      selectedGender = filters['gender'] as String?;
      ageRange = filters['ageRange'] as RangeValues?;
      _maxDistance = (filters['maxDistance'] as double?)?.clamp(1.0, _isPremium ? 100.0 : 50.0) ?? _maxDistance;
      _userLatitude = filters['userLatitude'] as double?;
      _userLongitude = filters['userLongitude'] as double?;
      selectedNeutered = filters['neutered'] as bool?;
      selectedHealthStatus = filters['healthStatus'] as String?;
      if (kDebugMode) {
        print('PlaymatePage - Applied filters: breed=$selectedBreed, gender=$selectedGender, ageRange=$ageRange, maxDistance=$_maxDistance, neutered=$selectedNeutered, healthStatus=$selectedHealthStatus');
      }
    }

    try {
      final dogsList = _sourceDogs.map((dog) => {
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
        'reportCount': dog.reportCount,
'isHidden': dog.isHidden,
'moderationStatus': dog.moderationStatus,
        'id': dog.id,
      }).toList();




      final filteredDogs = await compute(_applyFiltersIsolate, [
        dogsList,
        appState.currentUserId ?? '',
        selectedBreed,
        selectedGender,
        ageRange,
        _userLatitude,
        _userLongitude,
        _maxDistance,
        selectedNeutered,
        selectedHealthStatus,
      ]);
print("🧠 AFTER FILTER ASYNC: ${filteredDogs.length}");
      final uniqueDogs = <String, Dog>{};
      for (var dog in filteredDogs) {
        if (!uniqueDogs.containsKey(dog.id)) {
          uniqueDogs[dog.id] = dog;
          if (kDebugMode) {
            print('PlaymatePage - Using dog: ${dog.name}, id: ${dog.id}');
          }
        } else {
          if (kDebugMode) {
            print('PlaymatePage - Skipping duplicate dog: ${dog.name}, id: ${dog.id}');
          }
        }
      }

      if (mounted) {
        setState(() {
          _filteredDogs = uniqueDogs.values.toList();
          if (kDebugMode) {
            print('PlaymatePage - Filtered dogs count: ${_filteredDogs.length}');
            for (var dog in _filteredDogs) {
              print('PlaymatePage - Filtered dog: ${dog.name}, id: ${dog.id}, isNeutered: ${dog.isNeutered}, healthStatus: ${dog.healthStatus}');
            }
          }
        });
        _precacheDogImages(_filteredDogs);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('PlaymatePage - Error in _applyFiltersAsync: $e');
        print('StackTrace: $stackTrace');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorApplyingFilters(e.toString()), style: GoogleFonts.poppins())),
        );
      }
    }
  }

  void _resetFilters() {
    if (mounted) {
      setState(() {
        selectedBreed = null;
        selectedGender = null;
        ageRange = null;
        selectedNeutered = null;
        selectedHealthStatus = null;
        _maxDistance = _isPremium ? 100.0 : 50.0;
      });
      _applyFiltersAsync();
    }
  }

  Future<void> _openFilterPage() async {
    final filters = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilterPage(
          dogsList: _filteredDogs,
          selectedBreed: selectedBreed,
          selectedGender: selectedGender,
          ageRange: ageRange ?? const RangeValues(0, 15),
          maxDistance: _maxDistance,
          isPremium: _isPremium,
        ),
      ),
    );

    if (filters != null) {
      if (kDebugMode) {
        print('PlaymatePage - Filters received from FilterPage: $filters');
      }
      await _applyFiltersAsync(filters: filters);
    }
  }

  @override
void dispose() {
  _overlayController.dispose(); // 🔥 خیلی مهم
  _dogsSubscription?.cancel();
  _notificationsSubscription?.cancel();
  _searchDebounce?.cancel();
  super.dispose();
}

 Widget _buildPlaymateBody(
  BuildContext context,
  List<Dog> favs,
  AppState appState,
) {
  final localizations = AppLocalizations.of(context)!;
  final dogs = _filteredDogs;

  return Container(
    color: AppTheme.bg,
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 12),

          // 🔹 Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  "Playmates",
                  style: AppTheme.h1(),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _openFilterPage,
                  icon: Icon(
                    Icons.tune,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 🔎 Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Search by name...",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                if (_searchDebounce?.isActive ?? false) {
                  _searchDebounce!.cancel();
                }

                _searchDebounce = Timer(
                  const Duration(milliseconds: 300),
                  () {
                    _searchQuery = value.toLowerCase();

                    final filtered = _applyFiltersMainThread(
                      sourceDogs: _sourceDogs,
                      currentUserId:
                          appState.currentUserId ?? '',
                      selectedBreed: selectedBreed,
                      selectedGender: selectedGender,
                      ageRange: ageRange,
                      userLatitude: _userLatitude,
                      userLongitude: _userLongitude,
                      maxDistance: _maxDistance,
                      selectedNeutered: selectedNeutered,
                      selectedHealthStatus:
                          selectedHealthStatus,
                    );

                    final finalList = _searchQuery.isEmpty
                        ? filtered
                        : filtered.where((dog) {
                            return dog.name
                                .toLowerCase()
                                .contains(_searchQuery);
                          }).toList();

                    if (!mounted) return;

                    setState(() {
                      _filteredDogs = finalList;
                    });

                    _precacheDogImages(_filteredDogs);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // 🐶 LIST
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.accent,
                    ),
                  )
                : dogs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        cacheExtent: 1000,
                        addRepaintBoundaries: true,
                        addAutomaticKeepAlives: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: dogs.length,
                        itemBuilder: (context, index) {
                          final dog = dogs[index];

                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: 12),
                            child: RepaintBoundary(
                              child: DogCard(
                                disableTap: appState.isGuest, // ✅ ADD THIS
                                key: ValueKey(dog.id),
                                dog: dog,
                                mode: DogCardMode.compact,
                                allDogs: _filteredDogs,
                                currentUserId:
                                    appState.currentUserId ?? '',
                                favoriteDogs: favs,
                                onToggleFavorite: (dog) {
  if (appState.isGuest) {
    showLoginDialog(context);
    return;
  }

  appState.toggleFavorite(dog);
},
                                onAdopt: dog.isAvailableForAdoption
    ? () {
        if (appState.isGuest) {
          showLoginDialog(context);
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdoptionPage(
              dogs: appState.allDogs,
              favoriteDogs: favs,
              onToggleFavorite: (dog) {
                appState.toggleFavorite(dog);
              },
            ),
          ),
        );
      }
    : null,
                                selectedRequesterDogId:
                                    isSelectMode
                                        ? null
                                        : appState
                                            .selectedRequesterDogId,
                                onRequesterDogChanged:
    isSelectMode
        ? null
        : (value) {
            if (appState.isGuest) {
              showLoginDialog(context);
              return;
            }

            appState.setSelectedRequesterDogId(value);
          },
                                showDogSelection:
                                    isSelectMode,
                                likers: appState
                                        .dogLikes[dog.id] ??
                                    [],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
  Icons.pets,
  size: 56,
  color: AppTheme.muted.withOpacity(0.6),
),
        const SizedBox(height: 10),
        Text(
          "No dogs found",
          style: AppTheme.h2(color: AppTheme.muted),
        ),
        const SizedBox(height: 6),
        Text(
          "Try adjusting your filters",
          style: AppTheme.caption(),
        ),
      ],
    ),
  );
}

@override
Widget build(BuildContext context) {
  final appState = context.watch<AppState>(); // 🔥 watch کن نه read

  final isGuest = appState.isGuest; // ✅ ADD

  debugPrint("🧨 PlaymatePage BUILD | isGuest=$isGuest");

  return Container(
    color: AppTheme.bg,
    child: _buildPlaymateBody(
      context,
      appState.favoriteDogs,
      appState,
    ),
  );
}

}
class PlaymateProfileOverlay extends StatelessWidget {
  final String targetUserId;
  final List<Dog> dogsList;

  const PlaymateProfileOverlay({
    super.key,
    required this.targetUserId,
    required this.dogsList,
  });

  @override
Widget build(BuildContext context) {
  debugPrint("🧨 POPUP BUILD");

  final appState = context.read<AppState>();

  final userDogs =
      dogsList.where((d) => d.ownerId == targetUserId).toList();

  final content = userDogs.isEmpty
      ? const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "No dogs found",
              style: TextStyle(color: Colors.white),
            ),
          ),
        )
      : Column(
          children: userDogs.map((dog) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DogCard(
                dog: dog,
                mode: DogCardMode.playdate,
                disableTap: true,
                allDogs: dogsList,
                currentUserId: appState.currentUserId ?? '',
                favoriteDogs: appState.favoriteDogs,
                onToggleFavorite: (d) =>
                    appState.toggleFavorite(d),
                likers: appState.dogLikes[dog.id] ?? [],
                enableEdit: false,
              ),
            );
          }).toList(),
        );

  return Stack(
    children: [

      // ===============================
      // 🔥 BACKGROUND
      // ===============================
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            context.read<AppState>().closePlaymateProfile();
          },
          child: Container(color: Colors.black54),
        ),
      ),

      // ===============================
      // 🎴 CARD
      // ===============================
      Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 250),
          tween: Tween(begin: 0.8, end: 1),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },

          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF9E1B4F),
                borderRadius: BorderRadius.circular(20),
              ),

              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ===============================
                    // 🔝 HEADER (FIXED CLEAN)
                    // ===============================
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            context.read<AppState>().closePlaymateProfile();
                          },
                        ),

                        const SizedBox(width: 6),

                        Expanded(
                          child: Text(
                            "Dogs of this User",
                            style: AppTheme.h2(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onPressed: () {
                            _showUserActions(context);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ===============================
                    // 🐶 CONTENT
                    // ===============================
                    content,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
void _showUserActions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            ListTile(
              leading: const Icon(Icons.flag, color: Colors.red),
              title: const Text("Report User"),
              onTap: () {
  final appState = context.read<AppState>();

  if (appState.isGuest) {
    Navigator.pop(context);
    showLoginDialog(context);
    return;
  }

  Navigator.pop(context);
  debugPrint("🚨 REPORT CLICKED");
},
            ),

            ListTile(
              leading: const Icon(Icons.block),
              title: const Text("Block User"),
              onTap: () {
                Navigator.pop(context);
                debugPrint("⛔ BLOCK CLICKED");
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
}
void showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Login required"),
      content: const Text("Please sign in to use this feature"),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/auth');
          },
          child: const Text("Sign in"),
        ),
      ],
    ),
  );
}