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
import 'dog_card.dart';
//import 'filter_page.dart';
import 'adoption_page.dart';
import 'dart:io' show InternetAddress, SocketException;
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/utils/localization_utils.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

import 'package:barky_matches_fixed/utils/dog_filter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:barky_matches_fixed/social/services/follow_service.dart';


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

stt.SpeechToText? _speech;
bool _isListening = false;
  late AnimationController _overlayController;
  late Animation<double> _overlayAnimation;
  Map<String, bool> _userPremiumMap = {};
  String? selectedBreed;
  String? selectedPetType;
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
String? selectedOwnerGender;
List<Dog> _sourceDogs = []; // 🔥 SOURCE OF TRUTH
StreamSubscription<QuerySnapshot>? _dogsSubscription;
  String _searchQuery = '';
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;
      static bool _safeBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  return false;
}

 double similarity(String s1, String s2) {
  int matches = 0;

  final minLength = s1.length < s2.length ? s1.length : s2.length;

  for (int i = 0; i < minLength; i++) {
    if (s1[i] == s2[i]) matches++;
  }

  return matches / s1.length;
}

  @override
  bool get wantKeepAlive => true;
@override
void initState() {
  super.initState();

  dogsBox = Hive.box<Dog>('dogsBox');

  final appState = context.read<AppState>();
  final followService = FollowService();



  // 🚫 GUEST MODE HARD BLOCK
  if (appState.isGuest) {
    debugPrint("🚫 Guest mode → PlaymatePage LIMITED");

    _allDogs = appState.allDogs;
    _filteredDogs = _allDogs;
    _sourceDogs = _allDogs;

    _isLoading = false;

    _speech = stt.SpeechToText();

    return; // ⛔️ VERY IMPORTANT
  }

  // ✅ NORMAL MODE
  if (!isSelectMode) {
    _checkInternetAndStartStream();
    _startDogsStream();
    //_loadUserLocation();
  } else {
    _allDogs = appState.allDogs;
    _filteredDogs = _allDogs;
    _isLoading = false;

    _speech = stt.SpeechToText();
  }

  _overlayController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  _overlayAnimation = CurvedAnimation(
    parent: _overlayController,
    curve: Curves.easeOut,
  );


  if (appState.playmateFilters != null) {

    _applyFiltersAsync(filters: appState.playmateFilters!);

  }

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
  required String? selectedPetType, // 🔥 ADD
}) {

 debugPrint("🧪 FILTER START → total dogs = ${sourceDogs.length}");
  return sourceDogs.where((dog) {

  debugPrint("🐶 CHECK DOG → ${dog.name}");

  final data = {
    'isHidden': dog.isHidden,
    'dogProfileVisible': dog.dogProfileVisible,
    'ownerProfileVisible': dog.ownerProfileVisible,
    'isAvailableForAdoption': dog.isAvailableForAdoption,
  };

  final include = shouldIncludeDog(data, DogFilterMode.discover);

  if (!include) {
    debugPrint("❌ FILTERED (visibility) → ${dog.name}");
    return false;
  }

  if (currentUserId.isNotEmpty &&
    dog.ownerId == currentUserId) {
  debugPrint("🚫 OWN DOG REMOVED → ${dog.name}");
  return false;
}

  final matchesBreed =
      selectedBreed == null || dog.breed == selectedBreed;

  if (!matchesBreed) {
    debugPrint("❌ FILTERED (breed) → ${dog.name}");
    return false;
  }

  final matchesGender =
      selectedGender == null || dog.gender == selectedGender;

  if (!matchesGender) {
    debugPrint("❌ FILTERED (gender) → ${dog.name}");
    return false;
  }

  final matchesOwnerGender =
    selectedOwnerGender == null ||
    dog.ownerGender == selectedOwnerGender;

if (!matchesOwnerGender) return false;

  final matchesAge =
      ageRange == null ||
      (dog.age >= ageRange.start &&
          dog.age <= ageRange.end);

  if (!matchesAge) {
    debugPrint("❌ FILTERED (age) → ${dog.name}");
    return false;
  }

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

  final km = meters / 1000;

  debugPrint("📍 DISTANCE ${dog.name} = $km km");

  // 🚨 اگر فاصله غیرواقعی بود → ignore کن
  if (km > 1000) {
    debugPrint("⚠️ INVALID DISTANCE → skipping filter");
    matchesDistance = true;
  } else {
    matchesDistance = km <= maxDistance;
  }
}

  final matchesHealth =
      selectedHealthStatus == null ||
      dog.healthStatus == selectedHealthStatus;

  if (!matchesHealth) {
    debugPrint("❌ FILTERED (health) → ${dog.name}");
    return false;
  }

  final matchesPetType =
      selectedPetType == null || dog.petType == selectedPetType;

  if (!matchesPetType) {
    debugPrint("❌ FILTERED (petType) → ${dog.name} | dog=${dog.petType} filter=$selectedPetType");
    return false;
  }

  debugPrint("✅ PASSED → ${dog.name}");

  return true;

}).toList();

}
Future<void> _loadUserPremiums(List<Dog> dogs) async {
  final ownerIds = dogs
      .map((d) => d.ownerId)
      .where((id) => id != null && id.isNotEmpty)
      .toSet();

  final futures = ownerIds.map((id) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(id)
        .get();

    final data = doc.data();

    return MapEntry(
      id!,
      data?['isPremium'] == true,
    );
  } catch (e) {
    debugPrint("❌ premium read denied for $id → $e");

    return MapEntry(id!, false);
  }
});

  final results = await Future.wait(futures);

  _userPremiumMap = {
    for (var e in results) e.key: e.value,
  };

  debugPrint("🔥 USER PREMIUM MAP LOADED: $_userPremiumMap");
}

Future<void> _loadUserLocation() async {
  try {
    Position? position;

    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint("⚠️ GPS FAILED → using fallback");
    }

    final lat = position?.latitude;
    final lng = position?.longitude;

    // 🚨 اگر لوکیشن مشکوک بود (مثلا simulator)
    final isInvalid =
        lat == null ||
        lng == null ||
        (lat > 30 && lat < 40 && lng < -100); // USA detection

    setState(() {
      _userLatitude = isInvalid ? null : lat;
      _userLongitude = isInvalid ? null : lng;
    });

    debugPrint("📍 FINAL USER LOCATION → $_userLatitude , $_userLongitude");

    // 🔥 مهم
    _applyFiltersAsync();

  } catch (e) {
    debugPrint("❌ LOCATION ERROR: $e");

    setState(() {
      _userLatitude = null;
      _userLongitude = null;
    });
  }
}
int levenshtein(String s, String t) {
  final m = s.length;
  final n = t.length;

  List<List<int>> dp =
      List.generate(m + 1, (_) => List.filled(n + 1, 0));

  for (int i = 0; i <= m; i++) {
    dp[i][0] = i;
  }
  for (int j = 0; j <= n; j++) {
    dp[0][j] = j;
  }

  for (int i = 1; i <= m; i++) {
    for (int j = 1; j <= n; j++) {
      int cost = s[i - 1] == t[j - 1] ? 0 : 1;

      dp[i][j] = [
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost
      ].reduce((a, b) => a < b ? a : b);
    }
  }

  return dp[m][n];
}

void _startListening() async {
  _speech ??= stt.SpeechToText();

  if (!_isListening) {
    final available = await _speech!.initialize(
      onStatus: (status) {
        debugPrint("🎤 STATUS: $status");

        if (status == "done" || status == "notListening") {
          if (mounted) {
            setState(() => _isListening = false);
          }
        }
      },
      onError: (error) {
        debugPrint("❌ VOICE ERROR: $error");
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );

    if (!available) {
      debugPrint("❌ Speech not available");
      return;
    }

    if (_sourceDogs.isEmpty) {
      debugPrint("⚠️ NO DOGS LOADED YET");
      return;
    }

    setState(() => _isListening = true);

    _speech!.listen(
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      localeId: "en_US",
      onResult: (result) {
        final raw = result.recognizedWords;

        final cleanText = raw
            .toLowerCase()
            .trim()
            .replaceAll(RegExp(r'[^\w\s]'), '');

        debugPrint("🎤 RAW: $raw");
        debugPrint("🧹 CLEAN: $cleanText");

        if (!mounted) return;

        setState(() {
          _searchQuery = cleanText;
        });

       final appState = context.read<AppState>(); // 🔥 ADD THIS

final filtered = _applyFiltersMainThread(
  sourceDogs: _sourceDogs, // 🔥 FIX
  currentUserId: appState.currentUserId ?? '', // 🔥 FIX
  selectedBreed: selectedBreed,
  selectedGender: selectedGender,
  ageRange: ageRange,
  userLatitude: _userLatitude,
  userLongitude: _userLongitude,
  maxDistance: _maxDistance,
  selectedNeutered: selectedNeutered,
  selectedHealthStatus: selectedHealthStatus,
  selectedPetType: selectedPetType,
);

        List<Dog> finalList = [];

        if (cleanText.isEmpty) {
          finalList = filtered;
        } else {
          final words = cleanText
              .split(" ")
              .where((w) => w.trim().isNotEmpty)
              .where((w) => w.length >= 2)
              .toSet()
              .toList();

          Map<Dog, int> scoreMap = {};

          for (final dog in filtered) {
  final name = dog.name.toLowerCase();
  int score = 0;

  for (final word in words) {

    // ✅ exact
    if (name.contains(word)) {
      score += 3;
    }

    // ✅ startsWith
    if (name.startsWith(word)) {
      score += 5;
    }

    // ✅ levenshtein full word
    final dist = levenshtein(name, word);
    final similarity = 1 - (dist / name.length);

    if (similarity > 0.6) {
      score += 4;
    }

    // 🔥🔥🔥 THIS IS WHERE YOU ADD IT
    // ✅ substring fuzzy (خیلی مهم برای voice)
    if (word.length <= name.length) {
      for (int i = 0; i <= name.length - word.length; i++) {
        final sub = name.substring(i, i + word.length);

        final subDist = levenshtein(sub, word);
        final subSimilarity = 1 - (subDist / word.length);

        if (subSimilarity > 0.7) {
          score += 5;
          break;
        }
      }
    }
  }

  if (score > 0) {
    scoreMap[dog] = score;
  }
}

          // 🔥 sort by best match
          final sorted = scoreMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          finalList = sorted.map((e) => e.key).toList();

          // 🔥 fallback (اگر هیچی پیدا نشد)
          if (finalList.isEmpty && words.isNotEmpty) {
            debugPrint("⚠️ fallback activated");

            final first = words.first;

            finalList = filtered.where((dog) {
              final name = dog.name.toLowerCase();
              return name.startsWith(first.substring(0, 1));
            }).toList();
          }
        }

        setState(() {
          _filteredDogs = finalList;
        });

        debugPrint("🎯 VOICE RESULTS: ${finalList.length}");
      },
    );
  } else {
    setState(() => _isListening = false);
    _speech!.stop();
  }
}
void _startDogsStream() {

  final appState = context.read<AppState>();

  // 🚫 GUEST BLOCK
  if (appState.isGuest) {
    debugPrint("🚫 Guest → skip dogs stream");
    return;
  }

  if (_dogsSubscription != null) return;

  _dogsSubscription = FirebaseFirestore.instance
      .collection('dogs')
      .snapshots()
      .listen((snapshot) async {

    final appState = context.read<AppState>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // 🐶 MAP DATA
    final List<Dog> sourceDogs = snapshot.docs.map((doc) {
      final data = doc.data();

      return Dog(
        id: doc.id,
        isSponsored: data['isSponsored'] ?? false,
boostScore: (data['boostScore'] as num?)?.toInt() ?? 0,
        updatedAt: data['updatedAt'],
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
        petType: data['petType'] ?? 'dog',
      );
    }).toList();
 debugPrint("🔥 RAW DOGS FROM FIRESTORE:");
for (var d in sourceDogs) {
  debugPrint("🐶 ${d.name} | owner=${d.ownerId} | hidden=${d.isHidden} | visible=${d.dogProfileVisible}/${d.ownerProfileVisible} | petType=${d.petType}");
}
    // 🔥 جلوگیری از update بی‌خودی AppState
    final currentDogs = appState.allDogs;

    final isSame = listEquals(
      currentDogs.map((e) => e.id).toList(),
      sourceDogs.map((e) => e.id).toList(),
    );

    if (!isSame) {
      appState.setAllDogs(sourceDogs);
    }
await _loadUserPremiums(sourceDogs);
    // 🔍 APPLY FILTERS
    final filtered = _applyFiltersMainThread(
      sourceDogs: sourceDogs,
      currentUserId: currentUserId ?? '',
      selectedBreed: selectedBreed,
      selectedGender: selectedGender,
      ageRange: ageRange,
      userLatitude: _userLatitude,
      userLongitude: _userLongitude,
      maxDistance: _maxDistance,
      selectedNeutered: selectedNeutered,
      selectedHealthStatus: selectedHealthStatus,
      selectedPetType: selectedPetType,
    );

    // 🔍 APPLY SEARCH
    final words = _searchQuery.split(" ");

final finalList = _searchQuery.isEmpty
    ? filtered
    : filtered.where((dog) {
        final name = dog.name.toLowerCase();
        final breed = dog.breed.toLowerCase();

        bool fuzzyMatch(String text, String query) {
          if (text.contains(query)) return true;

          if (query.length >= 2) {
            for (int i = 0; i < text.length - 1; i++) {
              final part = text.substring(i, i + 2);
              if (query.contains(part)) return true;
            }
          }


          return false;
        }

        return words.any((w) =>
            fuzzyMatch(name, w) ||
            fuzzyMatch(breed, w));
      }).toList();

// 🔥 SMART RANKING (ADD HERE)
finalList.sort((a, b) {
  final scoreA = _calculateDogScore(a);
  final scoreB = _calculateDogScore(b);
  return scoreB.compareTo(scoreA);
});
for (var dog in finalList) {
  debugPrint("🏆 ORDER → ${dog.name}");
  debugPrint("📍 USER: $_userLatitude , $_userLongitude");
debugPrint("📍 DOG: ${dog.latitude} , ${dog.longitude}");
}
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

int _calculateDogScore(Dog dog) {
  int score = 0;

  // 🟡 Activity boost
  if (dog.updatedAt != null) {
    final hours = DateTime.now()
        .difference(dog.updatedAt!.toDate())
        .inHours;

    score += (24 - hours).clamp(0, 24);
  }

  // 🟣 Premium boost
  final isPremium = _userPremiumMap[dog.ownerId] == true;
  if (isPremium) score += 30;

  // 🔴 Sponsored boost (🔥 پول‌ساز)
  if (dog.isSponsored) score += dog.boostScore;

  return score;
}





Future<void> safePrecacheImage(
  BuildContext context,
  String imageUrl,
) async {

  try {

    final imageProvider = NetworkImage(imageUrl);

    await precacheImage(
      imageProvider,
      context,
    );

    debugPrint('🧠 precached: $imageUrl');

  } catch (e) {

    debugPrint(
      '⚠️ precache failed: $e',
    );
  }
}

Future<void> _precacheDogImages(
  List<Dog> dogs,
) async {

  for (final dog in dogs.take(6)) {

    for (final path in dog.imagePaths.take(1)) {

      if (!mounted) return;

      if (!path.contains('firebasestorage')) {
        continue;
      }

      await safePrecacheImage(
        context,
        path,
      );

      await Future.delayed(
        const Duration(milliseconds: 80),
      );
    }
  }
}

  Future<void> _checkInternetAndStartStream() async {

  final appState = context.read<AppState>();

  // 🚫 BLOCK FOR GUEST
 if (appState.isGuest) {
    debugPrint('🚫 Guest → skip notifications listener');
    return;
  }

  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    debugPrint('🛑 PlaymatePage: user is null');
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

  _notificationsSubscription = FirebaseFirestore.instance
      .collection('notifications')
      .where('recipientUserId', isEqualTo: user.uid)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .listen((snapshot) {

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

  // 🚫 GUEST BLOCK
  if (appState.isGuest) {
    debugPrint("🚫 Guest → skip unread notifications count");
    return;
  }

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
            debugPrint('PlaymatePage - Loaded unread notifications count: $_unreadNotificationsCount');
          }
        });
      }
     catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('PlaymatePage - Error loading unread notifications count: $e');
        debugPrint('StackTrace: $stackTrace');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingNotifications(e.toString()), style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> requestLocationFromUser() async {
  final appState = context.read<AppState>();

  if (appState.isGuest) {
    debugPrint('🚫 Guest → no location');
    return;
  }

  try {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (!mounted) return;

    setState(() {
      _userLatitude = position.latitude;
      _userLongitude = position.longitude;
    });

    _applyFiltersAsync();
  } catch (e) {
    debugPrint("❌ location error: $e");
  }
}

  Future<void> _loadData() async {
  if (isSelectMode) {
    if (kDebugMode) {
      debugPrint('⛔ _loadData blocked (selectDogForPlaydate)');
    }
    return;
  }

  if (!mounted) return;

  final appState = context.read<AppState>();

  setState(() {
    _isLoading = true;
  });

  try {
    // ===============================
    // 🟣 PREMIUM
    // ===============================
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

        isPremium = userDoc.data()?['isPremium'] ?? false;
        maxDistance = isPremium ? 100.0 : 50.0;

        if (kDebugMode) {
          debugPrint('PlaymatePage - Premium: $isPremium | maxDistance: $maxDistance');
        }
      }
    } catch (e) {
      debugPrint('❌ premium load error: $e');
    }

    // ===============================
    // 📍 LOCATION (SAFE — NO PERMISSION)
    // ===============================
    double? userLatitude;
    double? userLongitude;

    try {
      final lastPosition = await Geolocator.getLastKnownPosition();

      if (lastPosition != null) {
        userLatitude = lastPosition.latitude;
        userLongitude = lastPosition.longitude;

        if (kDebugMode) {
          debugPrint('📍 Using last known location');
        }
      } else {
        // ❗ NO requestPermission here
        userLatitude = null;
        userLongitude = null;

        if (kDebugMode) {
          debugPrint('⚠️ No cached location → waiting for user action');
        }
      }
    } catch (e) {
      debugPrint('❌ location read error: $e');

      userLatitude = null;
      userLongitude = null;
    }

    // ===============================
    // 🧹 HIVE SYNC
    // ===============================
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

      if (kDebugMode) {
        debugPrint('🧠 Hive sync done → ${dogsBox.length}');
      }
    }

    // ===============================
    // ✅ FINAL STATE
    // ===============================
    if (!mounted) return;

    setState(() {
      _isPremium = isPremium;
      _maxDistance = maxDistance;
      _userLatitude = userLatitude;
      _userLongitude = userLongitude;
      _filteredDogs = _sourceDogs;
      _isPremiumLoaded = true;
      _isLoading = false;
    });

    if (!mounted) return;

    _loadUnreadNotificationsCount();

  } catch (e, stackTrace) {
    debugPrint('❌ loadData error: $e');
    debugPrint('$stackTrace');

    if (!mounted) return;

    setState(() {
      _isPremium = false;
      _maxDistance = 50.0;
      _isPremiumLoaded = true;
      _userLatitude = null;
      _userLongitude = null;
      _filteredDogs = [];
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!
              .errorLoadingData(e.toString()),
          style: GoogleFonts.poppins(),
        ),
      ),
    );
  }
}

Map<String, dynamic>? _lastAppliedFilters;

@override
void didChangeDependencies() {
  super.didChangeDependencies();

  final appState = context.read<AppState>();

  if (appState.playmateFilters != null &&
      appState.playmateFilters != _lastAppliedFilters) {

    _lastAppliedFilters = appState.playmateFilters;

    _applyFiltersAsync(filters: appState.playmateFilters);
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
final String? selectedOwnerGender = args[11] as String?;
    final filteredDogs = dogs.where((dogMap) {
      if (dogMap['isHidden'] == true) return false;

if (dogMap['ownerProfileVisible'] == false) return false;

if (dogMap['dogProfileVisible'] == false) return false;
      //final notOwnDog = (dogMap['ownerId']?.toLowerCase() ?? '') != currentUserId.toLowerCase();
      final ownerId = dogMap['ownerId'] as String?;

if (ownerId == currentUserId) {
  if (kDebugMode) {
    debugPrint(
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
          debugPrint('PlaymatePage - Distance to ${dogMap['name']}: $distanceInKm km');
        }
      }
      bool matchesNeutered = selectedNeutered == null || dogMap['isNeutered'] == selectedNeutered;
      bool matchesHealth = selectedHealthStatus == null || dogMap['healthStatus'] == selectedHealthStatus;
final selectedPetType = args[10] as String?;

bool matchesOwnerGender =
    selectedOwnerGender == null ||
    dogMap['ownerGender'] == selectedOwnerGender;

bool matchesPetType =
    selectedPetType == null ||
    (dogMap['petType']?.toString().toLowerCase() ==
     selectedPetType.toLowerCase());

     bool matches = matchesBreed &&
    matchesGender &&
    matchesAge &&
    matchesDistance &&
    matchesNeutered &&
    matchesHealth &&
    matchesPetType &&
    matchesOwnerGender;
      if (kDebugMode) {
        debugPrint('PlaymatePage - Dog ${dogMap['name']}: matchesBreed=$matchesBreed, matchesGender=$matchesGender, matchesAge=$matchesAge, matchesDistance=$matchesDistance, matchesNeutered=$matchesNeutered, matchesHealth=$matchesHealth, overall=$matches');
      }
      return matches;
    }).map((dogMap) => Dog(
      updatedAt: dogMap['updatedAt'],
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
petType: dogMap['petType'] ?? 'dog',

        )).toList();

    return filteredDogs;
  }

  Future<void> _applyFiltersAsync({Map<String, dynamic>? filters}) async {
    if (_sourceDogs.isEmpty) return;
    final appState = context.read<AppState>();
    
    if (kDebugMode) {
      debugPrint('PlaymatePage - Starting _applyFiltersAsync with filters: $filters');
    }
    if (filters != null) {
      selectedPetType = filters['petType'] as String?;
      selectedBreed = filters['breed'] as String?;
      selectedGender = filters['gender'] as String?;
      ageRange = filters['ageRange'] as RangeValues?;
      _maxDistance = (filters['maxDistance'] as double?)?.clamp(1.0, _isPremium ? 100.0 : 50.0) ?? _maxDistance;
      _userLatitude = filters['userLatitude'] as double?;
      _userLongitude = filters['userLongitude'] as double?;
      selectedNeutered = filters['neutered'] as bool?;
      selectedHealthStatus = filters['healthStatus'] as String?;
      selectedOwnerGender = filters['ownerGender'] as String?;

      debugPrint("🔥 selectedPetType = $selectedPetType");
      if (kDebugMode) {
        debugPrint('PlaymatePage - Applied filters: breed=$selectedBreed, gender=$selectedGender, ageRange=$ageRange, maxDistance=$_maxDistance, neutered=$selectedNeutered, healthStatus=$selectedHealthStatus');
      }
    }



    if (selectedPetType != null) {
  debugPrint("🐾 ACTIVE petType filter = $selectedPetType");
} else {
  debugPrint("🐾 NO petType filter");
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
        'petType': dog.petType, 
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
         selectedPetType,
         selectedOwnerGender,
      ]);
      for (var dog in filteredDogs) {
  debugPrint("🐾 result petType = ${dog.petType}");
}

debugPrint("🧠 AFTER FILTER ASYNC: ${filteredDogs.length}");
      final uniqueDogs = <String, Dog>{};
      for (var dog in filteredDogs) {
        if (!uniqueDogs.containsKey(dog.id)) {
          uniqueDogs[dog.id] = dog;
          if (kDebugMode) {
            debugPrint('PlaymatePage - Using dog: ${dog.name}, id: ${dog.id}');
          }
        } else {
          if (kDebugMode) {
            debugPrint('PlaymatePage - Skipping duplicate dog: ${dog.name}, id: ${dog.id}');
          }
        }
      }

      if (mounted) {
        setState(() {
          _filteredDogs = uniqueDogs.values.toList();
          _filteredDogs.sort((a, b) {
  final scoreA = _calculateDogScore(a);
  final scoreB = _calculateDogScore(b);
  return scoreB.compareTo(scoreA);
});
          if (kDebugMode) {
            debugPrint('PlaymatePage - Filtered dogs count: ${_filteredDogs.length}');
            for (var dog in _filteredDogs) {
              debugPrint('PlaymatePage - Filtered dog: ${dog.name}, id: ${dog.id}, isNeutered: ${dog.isNeutered}, healthStatus: ${dog.healthStatus}');
            }
          }
        });
        _precacheDogImages(_filteredDogs);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('PlaymatePage - Error in _applyFiltersAsync: $e');
        debugPrint('StackTrace: $stackTrace');
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


  
  @override
void dispose() {
  _overlayController.dispose(); // 🔥 خیلی مهم
  _dogsSubscription?.cancel();
  _notificationsSubscription?.cancel();
  _searchDebounce?.cancel();
  super.dispose();
}

void showLoginDialog(BuildContext context) {
  final localizations = AppLocalizations.of(context)!;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(localizations.signInTitle),
      content: Text(localizations.signInToAccessPlaymate),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/auth');
          },
          child: Text(localizations.signInButton),
        ),
      ],
    ),
  );
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

          // 🔹 HEADER (UPGRADED)
Padding(
  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
  child: Row(
    children: [
          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.playmateService,
            style: AppTheme.h1().copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: const Color(0xFF9E1B4F),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            localizations.signInToFindFriends,
            style: AppTheme.caption().copyWith(
              color: Colors.black54,
            ),
          ),
        ],
      ),
      const Spacer(),

      // 🎛 FILTER BUTTON
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow(opacity: 0.05),
        ),
        child: IconButton(

    onPressed: () {

      context.read<AppState>().openPlaymateFilter();

    },

    icon: const Icon(
            LucideIcons.slidersHorizontal,
            color: Color(0xFF9E1B4F),
            size: 20,
          ),
        ),
      ),
    ],
  ),
),

const SizedBox(height: 12),

// 🔎 SEARCH BAR (UPGRADED)
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Container(
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        Icon(
          LucideIcons.search,
          size: 18,
          color: Colors.grey.shade600,
        ),

        const SizedBox(width: 10),

        Expanded(
          child: TextField(
            style: AppTheme.body(),
            decoration: InputDecoration(
              hintText: localizations.playmateSearchHint,
              border: InputBorder.none,
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
                    currentUserId: appState.currentUserId ?? '',
                    selectedBreed: selectedBreed,
                    selectedGender: selectedGender,
                    ageRange: ageRange,
                    userLatitude: _userLatitude,
                    userLongitude: _userLongitude,
                    maxDistance: _maxDistance,
                    selectedNeutered: selectedNeutered,
                    selectedHealthStatus: selectedHealthStatus,
                    selectedPetType: selectedPetType,
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

        // 🎤 VOICE
        GestureDetector(
          onTap: _startListening,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isListening
                  ? const Color(0xFF9E1B4F).withOpacity(0.1)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.mic,
              size: 18,
              color: _isListening
                  ? const Color(0xFF9E1B4F)
                  : Colors.grey,
            ),
          ),
        ),
      ],
    ),
  ),
),

          const SizedBox(height: 12),

          IconButton(
  icon: Icon(Icons.my_location),
  onPressed: () {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(localizations.playmateLocationNeededTitle),
        content: Text(localizations.playmateLocationNeededMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await requestLocationFromUser();
            },
            child: Text(localizations.homeAllowButton),
          ),
        ],
      ),
    );
  },
),

         

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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12, // ✅ improved spacing
                        ),
                        itemCount: dogs.length,
                        itemBuilder: (context, index) {
                          final dog = dogs[index];

                          return Padding(
                            padding: const EdgeInsets.only(
                                bottom: 14), // ✅ better spacing
                            child: RepaintBoundary(
                              child: DogCard(
                                disableTap: appState.isGuest,
                                key: ValueKey(dog.id),
                                dog: dog,
                                mode: DogCardMode.compact,
                                allDogs: _filteredDogs,
                                currentUserId:
                                    appState.currentUserId ?? '',
                                favoriteDogs: favs,

                                onCardTap: () {
  if (appState.isGuest) {
    showLoginDialog(context);
    return;
  }

  final ownerId = dog.ownerId;
  if (ownerId == null || ownerId.isEmpty) return;

  appState.setPlaymateProfile(
    ownerId,
    _filteredDogs,
  );
},
                                // ❤️ FAVORITE
                                onToggleFavorite: (dog) {
                                  if (appState.isGuest) {
                                    showLoginDialog(context);
                                    return;
                                  }
                                  appState.toggleFavorite(dog);
                                },

                                // 🏠 ADOPTION
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

                                // 🎯 REQUEST
                                selectedRequesterDogId: isSelectMode
                                    ? null
                                    : appState.selectedRequesterDogId,

                                onRequesterDogChanged: isSelectMode
                                    ? null
                                    : (value) {
                                        if (appState.isGuest) {
                                          showLoginDialog(context);
                                          return;
                                        }

                                        appState
                                            .setSelectedRequesterDogId(value);
                                      },

                                showDogSelection: isSelectMode,
                                likers:
                                    appState.dogLikes[dog.id] ?? [],
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
  final localizations = AppLocalizations.of(context)!;

  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
  LucideIcons.dog,
  size: 56,
  color: const Color(0xFF9E1B4F).withOpacity(0.4),
),
        const SizedBox(height: 10),
        Text(
  localizations.noDogsMatchFilters,
  style: AppTheme.h2().copyWith(
    color: const Color(0xFF9E1B4F),
    fontWeight: FontWeight.w600,
  ),
),
        const SizedBox(height: 6),
        Text(
  localizations.adjustFiltersSuggestion,
  style: AppTheme.caption().copyWith(
    color: AppTheme.muted,
  ),
),
      ],
    ),
  );
}



@override
Widget build(BuildContext context) {
  final appState = context.watch<AppState>();

  

  final isGuest = appState.isGuest; // ✅ ADD

  debugPrint("🧨 PlaymatePage BUILD | isGuest=$isGuest");

  return Container(
  color: AppTheme.bg,
  child: Stack(
    children: [
      _buildPlaymateBody(
        context,
        appState.favoriteDogs,
        appState,
      ),
if (appState.showPlaymateFilter)
  PlaymateFilterOverlay(
    dogsList: _sourceDogs,
    isPremium: _isPremium,
  ),
      if (appState.playmateProfileUserId != null)
        PlaymateProfileOverlay(
          targetUserId: appState.playmateProfileUserId!,
          dogsList: appState.playmateDogsSnapshot ?? _filteredDogs,
        ),
       
    ],
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

    
    final localizations = AppLocalizations.of(context)!;
   final appState = context.read<AppState>();

final followService = FollowService();

final currentUserId =
    FirebaseAuth.instance.currentUser?.uid;

final isOwnProfile =
    currentUserId == targetUserId;

    final userDogs =
        dogsList.where((d) => d.ownerId == targetUserId).toList();

    return Stack(
      children: [

        // 🔥 BACKGROUND
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              context.read<AppState>().closePlaymateProfile();
            },
            child: Container(color: Colors.black54),
          ),
        ),

        // 🎴 CARD
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(
                maxHeight: 600, // 🔥 مهم → جلوگیری از overflow
              ),
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF9E1B4F),
                borderRadius: BorderRadius.circular(20),
              ),

              child: Column(
                children: [

                 // 🔝 HEADER
Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [

    // ❌ CLOSE
    IconButton(
      icon: const Icon(
        Icons.close,
        color: Colors.white,
      ),
      onPressed: () {
        context
            .read<AppState>()
            .closePlaymateProfile();
      },
    ),

    const SizedBox(width: 8),

    // 🐶 TITLE
    Expanded(
      child: Text(
        localizations.dogsOfThisUser,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.h2(
          color: Colors.white,
        ),
      ),
    ),

    // 🔥 FOLLOW BUTTON
   // if (!isOwnProfile)
      StreamBuilder<bool>(
        stream: followService.isFollowing(
          targetUserId,
        ),

        builder: (context, snapshot) {

          final isFollowing =
              snapshot.data ?? false;

          return Padding(
            padding: const EdgeInsets.only(left: 10),

            child: Material(
              color: Colors.transparent,

              child: InkWell(

                borderRadius:
                    BorderRadius.circular(14),

                onTap: () async {

                  if (isFollowing) {

                    await followService.unfollowUser(
                      targetUserId: targetUserId,
                    );

                  } else {

                    await followService.followUser(
                      targetUserId: targetUserId,
                    );
                  }
                },

                child: Container(

                  height: 42,

                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),

                  alignment: Alignment.center,

                  decoration: BoxDecoration(

                    color: isFollowing
                        ? Colors.white.withOpacity(0.14)
                        : Colors.white,

                    borderRadius:
                        BorderRadius.circular(14),

                    border: Border.all(
                      color: isFollowing
                          ? Colors.white24
                          : Colors.transparent,
                    ),
                  ),

                  child: Text(

                    isFollowing
                        ? 'Following'
                        : 'Follow',

                    style: TextStyle(

                      color: isFollowing
                          ? Colors.white
                          : const Color(0xFF9E1B4F),

                      fontWeight:
                          FontWeight.w700,

                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
  ],
),
                  const SizedBox(height: 10),

                  // 🔥 SCROLLABLE CONTENT
                  Expanded(
                    child: userDogs.isEmpty
                        ? Center(
                            child: Text(
                              localizations.noDogsFound,
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        : ListView.builder(
                            itemCount: userDogs.length,
                            itemBuilder: (context, index) {
                              final dog = userDogs[index];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: DogCard(
                                  dog: dog,
                                  mode: DogCardMode.playdate,
                                  disableTap: true,
                                  allDogs: dogsList,
                                  currentUserId:
                                      appState.currentUserId ?? '',
                                  favoriteDogs: appState.favoriteDogs,
                                  onToggleFavorite: (d) =>
                                      appState.toggleFavorite(d),
                                  likers:
                                      appState.dogLikes[dog.id] ?? [],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PlaymateFilterOverlay extends StatefulWidget {
  final List<Dog> dogsList;
  final bool isPremium;

  const PlaymateFilterOverlay({
    super.key,
    required this.dogsList,
    required this.isPremium,
  });

  @override
  State<PlaymateFilterOverlay> createState() =>
      _PlaymateFilterOverlayState();
}

class _PlaymateFilterOverlayState
    extends State<PlaymateFilterOverlay> {
  String? petType;
  String? breed;
  String? gender;
  String? ownerGender;
  RangeValues ageRange = const RangeValues(0, 15);
  double maxDistance = 50;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();

    final isGold = appState.isGold;
    final isPremium = appState.isPremium;
debugPrint("🟡 isGold = $isGold");
debugPrint("🟣 isPremium = $isPremium");
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: appState.closePlaymateFilter,
            child: Container(color: Colors.black54),
          ),
        ),

        Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF9E1B4F),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                /// HEADER
                Row(
                  children: [
                    Text(
                      localizations.playmateFiltersTitle,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Spacer(),

                    /// 🔄 RESET
                    TextButton(
                      onPressed: () {
                        setState(() {
                          petType = null;
                          breed = null;
                          gender = null;
                          ownerGender = null;
                          ageRange = const RangeValues(0, 15);
                          maxDistance = 50;
                        });

                        appState.clearPlaymateFilters();
                      },
                      child: Text(
                        localizations.resetFiltersButton,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                /// 🐾 PET TYPE
                DropdownButtonFormField<String>(
                  initialValue: petType,
                  hint: Text(localizations.petTypeLabel),
                  items: [
                    DropdownMenuItem(
                      value: 'dog',
                      child: Text(localizations.petTypeDog),
                    ),
                    DropdownMenuItem(
                      value: 'cat',
                      child: Text(localizations.petTypeCat),
                    ),
                    DropdownMenuItem(
                      value: 'bird',
                      child: Text(localizations.petTypeBird),
                    ),
                    DropdownMenuItem(
                      value: 'horse',
                      child: Text(localizations.petTypeHorse),
                    ),
                  ],
                  onChanged: (v) => setState(() => petType = v),
                ),

                const SizedBox(height: 10),

                /// 🐶 BREED (Gold only)
                DropdownButtonFormField<String>(
                  initialValue: breed,
                  hint: Text(
                    isGold
                        ? localizations.breed
                        : localizations.playmateBreedPremiumHint,
                  ),
                  items: isGold
                      ? widget.dogsList
                          .map((d) => d.breed)
                          .toSet()
                          .map((b) => DropdownMenuItem(
                                value: b,
                                child: Text(b),
                              ))
                          .toList()
                      : [],
                  onChanged: isGold
                      ? (v) => setState(() => breed = v)
                      : null,
                ),

                const SizedBox(height: 10),

                /// ⚥ DOG GENDER
                DropdownButtonFormField<String>(
                  initialValue: gender,
                  hint: Text(localizations.gender),
                  items: [
                    DropdownMenuItem(
                      value: 'male',
                      child: Text(localizations.genderMale),
                    ),
                    DropdownMenuItem(
                      value: 'female',
                      child: Text(localizations.genderFemale),
                    ),
                  ],
                  onChanged: (v) => setState(() => gender = v),
                ),

                const SizedBox(height: 10),

                /// 👤 OWNER GENDER (Premium)
                DropdownButtonFormField<String>(
                  initialValue: ownerGender,
                  hint: Text(
                    isPremium
                        ? localizations.selectOwnerGenderHint
                        : localizations.playmateOwnerGenderPremiumHint,
                  ),
                  items: isPremium
                      ? [
                          DropdownMenuItem(
                              value: 'male', child: Text(localizations.genderMale)),
                          DropdownMenuItem(
                              value: 'female', child: Text(localizations.genderFemale)),
                        ]
                      : [],
                  onChanged: isPremium
                      ? (v) => setState(() => ownerGender = v)
                      : null,
                ),

                const SizedBox(height: 10),

                /// 🎂 AGE
                RangeSlider(
                  values: ageRange,
                  min: 0,
                  max: 15,
                  onChanged: (v) => setState(() => ageRange = v),
                ),

                const SizedBox(height: 10),

                /// 📍 DISTANCE (Premium unlock)
                Slider(
                  value: maxDistance,
                  min: 1,
                  max: isPremium ? 100 : 50,
                  onChanged: (v) => setState(() => maxDistance = v),
                ),

                const SizedBox(height: 16),

                /// APPLY
                ElevatedButton(
                  onPressed: () {
                    appState.applyPlaymateFilters({
                      'petType': petType,
                      'breed': breed,
                      'gender': gender,
                      'ownerGender': ownerGender,
                      'ageRange': ageRange,
                      'maxDistance': maxDistance,
                    });
                  },
                  child: Text(localizations.apply),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
