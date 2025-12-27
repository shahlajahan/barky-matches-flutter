import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dog.dart';
import 'auth_page.dart';
import 'playmate_page.dart';
import 'vet_page.dart';
import 'adoption_page.dart';
import 'dog_park_page.dart';
import 'add_dog_page.dart';
import 'user_profile_page.dart';
import 'filter_page.dart';
import 'play_date_requests_page_new.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'offers_manager.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/utils/localization_utils.dart';

class HomePage extends StatefulWidget {
  final List<Dog> dogsList;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;

  const HomePage({
    super.key,
    required this.dogsList,
    required this.favoriteDogs,
    required this.onToggleFavorite,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, LocalizationUtils {
  late TabController _tabController;
  late Box<String> userBox;
  late String _currentUserId;
  String _username = 'User';
  late Box<Dog> dogsBox;
  List<Dog> _filteredDogs = [];
  List<Dog> _userDogs = [];
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isLocationLoading = true;

  String? selectedBreed;
  String? selectedGender;
  RangeValues? ageRange;
  bool? selectedNeutered;
  String? selectedHealthStatus;
  double? _userLatitude;
  double? _userLongitude;
  double _maxDistance = 50.0;
  bool _isPremium = false;
  bool _isPremiumLoaded = false;

  Map<String, List<Map<String, dynamic>>> dogLikes = {};
  late BannerAd _bannerAd;
  bool _isAdLoaded = false;

  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    print('HomePage - Initializing...');
    _tabController = TabController(length: 3, vsync: this);
    userBox = Hive.box<String>('userBox');
    dogsBox = Hive.box<Dog>('dogsBox');

    _checkUserStatus();
  }

  void _checkUserStatus() {
    final user = FirebaseAuth.instance.currentUser;
    print('HomePage - Firebase currentUser: ${user?.uid}');

    String? storedUserId = userBox.get('currentUserId');
    print('HomePage - Hive currentUserId: $storedUserId');

    if (user != null) {
      _currentUserId = user.uid.toLowerCase();
      print('HomePage - User found from Firebase: $_currentUserId');
      if (storedUserId != _currentUserId) {
        userBox.put('currentUserId', _currentUserId);
        print('HomePage - Updated Hive currentUserId to: $_currentUserId');
      }
      _loadData();
      _loadNotificationCount();
      OffersManager.loadOffers();
      _loadAd();
    } else {
      print('HomePage - No user logged in');
      _currentUserId = 'default_user';
      _username = 'User';
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadAd() {
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

  Future<void> _loadUserPremiumStatus() async {
    if (_isPremiumLoaded) return;
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _isPremium = userData['isPremium'] ?? false;
            _maxDistance = _isPremium ? 100.0 : 50.0;
            _isPremiumLoaded = true;
            print('HomePage - Loaded _isPremium: $_isPremium, _maxDistance: $_maxDistance');
          });
        }
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .set({
          'username': _username,
          'email': FirebaseAuth.instance.currentUser?.email ?? '',
          'isPremium': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() {
            _isPremium = false;
            _maxDistance = 50.0;
            _isPremiumLoaded = true;
            print('HomePage - Created default user document for userId: $_currentUserId');
          });
        }
      }
    } catch (e) {
      print('HomePage - Error loading premium status: $e');
      if (mounted) {
        setState(() {
          _isPremium = false;
          _maxDistance = 50.0;
          _isPremiumLoaded = true;
          print('HomePage - Error occurred, defaulting _isPremium: false, _maxDistance: 50.0');
        });
      }
    }
  }

  Future<void> _loadNotificationCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientUserId', isEqualTo: user.uid.toLowerCase())
          .where('isRead', isEqualTo: false)
          .get();
      if (mounted) {
        setState(() {
          _notificationCount = snapshot.docs.length;
          print('HomePage - Notification count: $_notificationCount');
        });
      }
    } catch (e) {
      print('HomePage - Error loading notification count: $e');
      if (mounted) {
        setState(() {
          _notificationCount = 0;
        });
      }
    }
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadUsernameFromFirebase(),
      _syncDogsWithFirestore(),
      _loadLocationAndFilters(),
      _loadUserDogs(),
      _loadUserPremiumStatus(),
    ]);
    await _loadLikesForDogs();
  }

  Future<void> _loadUsernameFromFirebase() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _username = userData['username'] ?? 'User';
            _isLoading = false;
            print('HomePage - User data found from Firestore: $userData');
            print('HomePage - Username set to: $_username');
          });
        }
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .set({
          'username': FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? 'User',
          'email': FirebaseAuth.instance.currentUser?.email ?? '',
          'isPremium': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() {
            _username = FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? 'User';
            _isLoading = false;
            print('HomePage - Created default user document for userId: $_currentUserId');
          });
        }
      }
    } catch (e) {
      print('HomePage - Error loading username from Firestore: $e');
      if (mounted) {
        setState(() {
          _username = 'User';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncDogsWithFirestore() async {
    try {
      final dogsSnapshot = await FirebaseFirestore.instance.collection('dogs').get();
      final Map<String, Dog> uniqueDogs = {};

      for (var doc in dogsSnapshot.docs) {
        final data = doc.data();
        final dog = Dog(
          id: doc.id, // اضافه کردن id از Firestore
          name: data['name'] ?? '',
          breed: data['breed'] ?? '',
          age: data['age'] ?? 0,
          gender: data['gender'] ?? '',
          healthStatus: data['healthStatus'] ?? '',
          isNeutered: data['isNeutered'] ?? false,
          description: data['description'] ?? '',
          traits: List<String>.from(data['traits'] ?? []),
          ownerGender: data['ownerGender'] ?? '',
          imagePaths: List<String>.from(data['imagePaths'] ?? []),
          isAvailableForAdoption: data['isAvailableForAdoption'] ?? false,
          isOwner: data['isOwner'] ?? false,
          ownerId: data['ownerId']?.toLowerCase() ?? '',
          latitude: data['latitude']?.toDouble() ?? 0.0,
          longitude: data['longitude']?.toDouble() ?? 0.0,
        );
        if (!uniqueDogs.containsKey(dog.id)) {
          uniqueDogs[dog.id] = dog;
          print('HomePage - Loaded dog: ${dog.name}, id: ${dog.id}, ownerId: ${dog.ownerId}');
        } else {
          print('HomePage - Skipped duplicate dog: ${dog.name}, id: ${dog.id}, ownerId: ${dog.ownerId}');
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
    await _getCurrentLocation();
    if (mounted) {
      setState(() {
        _isLocationLoading = false;
      });
      await _applyFiltersAsync();
    }
  }

  Future<void> _loadUserDogs() async {
    final dogsBox = await Hive.openBox<Dog>('dogsBox');
    final userDogs = await compute(_loadUserDogsIsolate, {
      'userId': _currentUserId,
      'dogsBox': dogsBox,
    });
    if (mounted) {
      setState(() {
        _userDogs = userDogs;
        print('HomePage - Loaded ${_userDogs.length} dogs for userId: $_currentUserId');
      });
    }
  }

  static Future<List<Dog>> _loadUserDogsIsolate(Map<String, dynamic> params) async {
    final String userId = params['userId'];
    final Box<Dog> dogsBox = params['dogsBox'];
    return dogsBox.values
        .where((dog) => (dog.ownerId?.toLowerCase() ?? '') == userId.toLowerCase())
        .toList();
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
        final username = userSnapshot.exists ? userSnapshot['username'] : 'Unknown';
        final email = userSnapshot.exists ? userSnapshot['email'] : 'Unknown Email';
        likers.add({'username': username, 'email': email});
      }

      if (mounted) {
        setState(() {
          dogLikes[dogId] = likers;
          print('HomePage - Fetched ${likers.length} likes for dog: $dogId');
        });
      }
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
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.locationServicesDisabled ?? 'Location services are disabled. Using default location.',
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
        setState(() {
          _userLatitude = 41.0103;
          _userLongitude = 28.6724;
        });
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.locationPermissionRequired ?? 'Location permission is required to find dogs nearby. Using default location.',
                style: GoogleFonts.poppins(),
              ),
              duration: const Duration(seconds: 1),
              action: SnackBarAction(
                label: AppLocalizations.of(context)!.settings ?? 'Settings',
                onPressed: () {
                  openAppSettings();
                },
              ),
            ),
          );
          setState(() {
            _userLatitude = 41.0103;
            _userLongitude = 28.6724;
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.locationPermissionPermanentlyDenied ?? 'Location permission is permanently denied. Using default location.',
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(seconds: 1),
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.settings ?? 'Settings',
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
        setState(() {
          _userLatitude = 41.0103;
          _userLongitude = 28.6724;
        });
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _userLatitude = position.latitude;
          _userLongitude = position.longitude;
          print('HomePage - Got current location: $_userLatitude, $_userLongitude');
        });
      }
    } catch (e) {
      print('HomePage - Error getting location: $e');
      if (mounted) {
        setState(() {
          _userLatitude = 41.0103;
          _userLongitude = 28.6724;
        });
      }
    }
  }

  Future<void> _applyFiltersAsync({Map<String, dynamic>? filters}) async {
    if (filters != null) {
      selectedBreed = filters['breed'] as String?;
      selectedGender = filters['gender'] as String?;
      ageRange = filters['ageRange'] as RangeValues?;
      _maxDistance = (filters['maxDistance'] as double?)?.clamp(1.0, _isPremium ? 100.0 : 50.0) ?? _maxDistance;
      _userLatitude = (filters['userLatitude'] as double?) ?? _userLatitude;
      _userLongitude = (filters['userLongitude'] as double?) ?? _userLongitude;
      selectedNeutered = filters['neutered'] as bool?;
      selectedHealthStatus = filters['healthStatus'] as String?;
      print('HomePage - Applied filters: breed=$selectedBreed, gender=$selectedGender, ageRange=$ageRange, maxDistance=$_maxDistance, neutered=$selectedNeutered, healthStatus=$selectedHealthStatus');
    } else {
      _maxDistance = _isPremium ? 100.0 : 50.0;
    }

    final dogsData = widget.dogsList.map((dog) => {
      'id': dog.id, // اضافه کردن id
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
          ? {'start': ageRange?.start ?? 0.0, 'end': ageRange?.end ?? 15.0}
          : null,
      'maxDistance': _maxDistance,
      'userLatitude': _userLatitude,
      'userLongitude': _userLongitude,
      'selectedNeutered': selectedNeutered,
      'selectedHealthStatus': selectedHealthStatus,
    });

    if (mounted) {
      setState(() {
        _filteredDogs = filteredDogsData.map((data) => Dog(
          id: data['id'], // اضافه کردن id
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
        )).toList().take(10).toList();
        print('HomePage - Filtered dogs count: ${_filteredDogs.length}');
        for (var dog in _filteredDogs) {
          print('HomePage - Filtered dog: ${dog.name}, id: ${dog.id}, ownerId: ${dog.ownerId}, isNeutered: ${dog.isNeutered}, healthStatus: ${dog.healthStatus}');
        }
      });
    }
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
      final key = dog['id'];
      if (!uniqueDogs.containsKey(key)) {
        uniqueDogs[key] = dog;
      } else {
        print('HomePage - Duplicate dog found: ${dog['name']}, id: ${dog['id']}, ownerId: ${dog['ownerId']}');
      }
    }

    return uniqueDogs.values.where((dog) {
      final notOwnDog = (dog['ownerId']?.toLowerCase() ?? '') != currentUserId.toLowerCase();
      if (!notOwnDog) {
        print('HomePage - Excluding dog ${dog['name']} because ownerId (${dog['ownerId']}) matches currentUserId ($currentUserId)');
        return false;
      }

      bool matchesBreed = selectedBreed == null || dog['breed'] == selectedBreed;
      bool matchesGender = selectedGender == null || dog['gender'] == selectedGender;
      bool matchesAge = ageRange == null || (dog['age'] >= ageRange['start']! && dog['age'] <= ageRange['end']!);
      bool matchesDistance = true;
      if (userLatitude != null && userLongitude != null && dog['latitude'] != null && dog['longitude'] != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          userLatitude,
          userLongitude,
          dog['latitude']!,
          dog['longitude']!,
        );
        double distanceInKm = distanceInMeters / 1000;
        matchesDistance = distanceInKm <= maxDistance;
        print('HomePage - Distance to ${dog['name']}: $distanceInKm km');
      } else {
        print('HomePage - Missing location data for ${dog['name']} or user: userLat=$userLatitude, userLon=$userLongitude, dogLat=${dog['latitude']}, dogLon=${dog['longitude']}');
        matchesDistance = true;
      }
      bool matchesNeutered = selectedNeutered == null || dog['isNeutered'] == selectedNeutered;
      bool matchesHealth = selectedHealthStatus == null || dog['healthStatus'] == selectedHealthStatus;

      bool matches = matchesBreed && matchesGender && matchesAge && matchesDistance && matchesNeutered && matchesHealth;
      print('HomePage - Dog ${dog['name']}: matchesBreed=$matchesBreed, matchesGender=$matchesGender, matchesAge=$matchesAge, matchesDistance=$matchesDistance, matchesNeutered=$matchesNeutered, matchesHealth=$matchesHealth, overall=$matches');
      return matches;
    }).toList();
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
      print('HomePage - Filters received from FilterPage: $filters');
      await _applyFiltersAsync(filters: filters);
    }
  }

  @override
  void dispose() {
    print('HomePage - Disposing resources');
    _tabController.dispose();
    _bannerAd.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdoptionPage(
              dogs: dogsBox.values.toList(),
              favoriteDogs: widget.favoriteDogs,
              onToggleFavorite: widget.onToggleFavorite,
            ),
          ),
        ).then((_) {
          if (mounted) {
            setState(() {
              _applyFiltersAsync();
            });
          }
        });
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const VetPage(),
          ),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayDateRequestsPageNew(
              dogsList: dogsBox.values.toList(),
              favoriteDogs: widget.favoriteDogs,
              onToggleFavorite: widget.onToggleFavorite,
            ),
          ),
        ).then((_) {
          if (mounted) {
            setState(() {
              _applyFiltersAsync();
            });
          }
        });
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfilePage(
              dogsList: dogsBox.values.toList(),
              favoriteDogs: widget.favoriteDogs,
              onToggleFavorite: widget.onToggleFavorite,
              onDogAdded: (newDog) {
                if (mounted) {
                  setState(() {
                    final dogCopy = Dog(
                      id: newDog.id, // استفاده از id
                      name: newDog.name,
                      breed: newDog.breed,
                      age: newDog.age,
                      gender: newDog.gender,
                      healthStatus: newDog.healthStatus,
                      isNeutered: newDog.isNeutered,
                      description: newDog.description,
                      traits: newDog.traits,
                      ownerGender: newDog.ownerGender,
                      imagePaths: newDog.imagePaths,
                      isAvailableForAdoption: newDog.isAvailableForAdoption,
                      isOwner: newDog.isOwner,
                      ownerId: newDog.ownerId,
                      latitude: newDog.latitude,
                      longitude: newDog.longitude,
                    );
                    final dogKey = dogCopy.id;

                    FirebaseFirestore.instance.collection('dogs').doc(dogKey).get().then((doc) {
                      if (doc.exists) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.dogNameExists(dogCopy.name) ?? 'A dog named ${dogCopy.name} already exists!')),
                        );
                      } else {
                        dogsBox.put(dogKey, dogCopy);
                        FirebaseFirestore.instance.collection('dogs').doc(dogKey).set({
                          'id': dogCopy.id, // ذخیره id در Firestore
                          'name': dogCopy.name,
                          'breed': dogCopy.breed,
                          'age': dogCopy.age,
                          'gender': dogCopy.gender,
                          'healthStatus': dogCopy.healthStatus,
                          'isNeutered': dogCopy.isNeutered,
                          'description': dogCopy.description,
                          'traits': dogCopy.traits,
                          'ownerGender': dogCopy.ownerGender,
                          'imagePaths': dogCopy.imagePaths,
                          'isAvailableForAdoption': dogCopy.isAvailableForAdoption,
                          'isOwner': dogCopy.isOwner,
                          'ownerId': dogCopy.ownerId,
                          'latitude': dogCopy.latitude,
                          'longitude': dogCopy.longitude,
                        });
                        _applyFiltersAsync();
                        _loadUserDogs();
                      }
                    });
                  });
                }
              },
              userId: _currentUserId,
            ),
          ),
        ).then((_) {
          if (mounted) {
            setState(() {
              _applyFiltersAsync();
              _loadUserDogs();
            });
          }
        });
        break;
    }
  }

  void _onDogUpdated(Dog updatedDog) {
    print('HomePage - Updating dog: ${updatedDog.name}, id: ${updatedDog.id}');
    final dogKey = updatedDog.id;
    if (dogsBox.containsKey(dogKey)) {
      dogsBox.put(dogKey, updatedDog);
      print('HomePage - Dog updated in Hive with key $dogKey: ${updatedDog.name}');

      FirebaseFirestore.instance.collection('dogs').doc(dogKey).set({
        'id': updatedDog.id, // ذخیره id در Firestore
        'name': updatedDog.name,
        'breed': updatedDog.breed,
        'age': updatedDog.age,
        'gender': updatedDog.gender,
        'healthStatus': updatedDog.healthStatus,
        'isNeutered': updatedDog.isNeutered,
        'description': updatedDog.description,
        'traits': updatedDog.traits,
        'ownerGender': updatedDog.ownerGender,
        'imagePaths': updatedDog.imagePaths,
        'isAvailableForAdoption': updatedDog.isAvailableForAdoption,
        'isOwner': updatedDog.isOwner,
        'ownerId': updatedDog.ownerId,
        'latitude': updatedDog.latitude,
        'longitude': updatedDog.longitude,
      }).then((_) {
        print('HomePage - Dog updated in Firestore: ${updatedDog.name}, id: ${updatedDog.id}');
      }).catchError((e) {
        print('HomePage - Error updating dog in Firestore: $e');
      });

      if (mounted) {
        setState(() {
          _applyFiltersAsync();
          _loadUserDogs();
          print('HomePage - UI updated after dog update: ${updatedDog.name}, id: ${updatedDog.id}');
        });
      }
    } else {
      print('HomePage - Dog not found in Hive for update with key $dogKey: ${updatedDog.name}');
    }
  }

  Widget _buildServiceBox(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.pink),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.pink,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('HomePage - Building UI for userId: $_currentUserId');
    final localizations = AppLocalizations.of(context)!;
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                localizations.loadingUserData ?? 'Loading user data...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final availableBreeds = [...getDogBreeds(context), ...dogsBox.values.map((dog) => dog.breed).toSet()];
    final List<String> uniqueBreeds = availableBreeds.cast<String>().toSet().toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFFFFC107)),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.favorite, color: Color(0xFFFFC107)),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlayDateRequestsPageNew(
                        dogsList: dogsBox.values.toList(),
                        favoriteDogs: widget.favoriteDogs,
                        onToggleFavorite: widget.onToggleFavorite,
                      ),
                    ),
                  );
                  await _loadNotificationCount();
                },
                tooltip: localizations.notificationsTooltip,
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_notificationCount',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFFFFC107)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.chatNotImplemented ?? 'Chats clicked!'), duration: const Duration(seconds: 1)),
              );
            },
            tooltip: localizations.chatTooltip,
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pink, Colors.pinkAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink, Colors.pinkAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Text(
                localizations.menuTitle,
                style: GoogleFonts.poppins(
                  color: Color(0xFFFFC107),
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.park, color: Colors.black54),
              title: Text(
                localizations.dogParkMenuItem ?? 'Dog Park',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w400),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DogParkPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border, color: Colors.black54),
              title: Text(
                localizations.adoptionCenterMenuItem ?? 'Adoption',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w400),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdoptionPage(
                      dogs: dogsBox.values.toList(),
                      favoriteDogs: widget.favoriteDogs,
                      onToggleFavorite: widget.onToggleFavorite,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_alt, color: Colors.black54),
              title: Text(
                localizations.filterDogsMenuItem ?? 'Filter Dogs',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w400),
              ),
              onTap: () {
                Navigator.push(
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
                ).then((filters) {
                  if (filters != null) {
                    _applyFiltersAsync(filters: filters);
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.pets, color: Colors.black54),
              title: Text(
                localizations.lostDogsMenuItem ?? 'Lost Dogs',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w400),
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.lostDogsComingSoon ?? 'Lost Dogs Coming Soon!'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.store, color: Colors.black54),
              title: Text(
                localizations.petShopsMenuItem ?? 'Pet Shops',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w400),
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.petShopsComingSoon ?? 'Pet Shops Coming Soon!'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital, color: Colors.black54),
              title: Text(
                localizations.hospitalsMenuItem ?? 'Hospitals',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w400),
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.hospitalsComingSoon ?? 'Hospitals Coming Soon!'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.black54),
              title: Text(
                localizations.logoutMenuItem ?? 'Logout',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w400),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                userBox.delete('currentUserId');
                Navigator.pushReplacementNamed(context, '/welcome');
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 90),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              child: Text(
                localizations.welcomeToBarkyMatches ?? 'Welcome to Barky Matches!',
                style: GoogleFonts.dancingScript(
                  color: Color(0xFFFFC107),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            OffersManager.buildOffersSection(_isPremium),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              child: Text(
                localizations.appFeaturesMessage ?? 'With our app, you can:',
                style: GoogleFonts.dancingScript(
                  color: Color(0xFFFFC107),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildServiceBox(
                    localizations.playmateService ?? 'Playmate',
                    Icons.pets,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaymatePage(
                            dogs: _filteredDogs,
                            favoriteDogs: widget.favoriteDogs,
                            onToggleFavorite: widget.onToggleFavorite,
                            currentUserId: _currentUserId,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildServiceBox(
                    localizations.vetServices ?? 'Vet Services',
                    Icons.local_hospital,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const VetPage()),
                      );
                    },
                  ),
                  _buildServiceBox(
                    localizations.adoptionService ?? 'Adoption',
                    Icons.favorite,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdoptionPage(
                            dogs: dogsBox.values.toList(),
                            favoriteDogs: widget.favoriteDogs,
                            onToggleFavorite: widget.onToggleFavorite,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildServiceBox(
                    localizations.dogTrainingService ?? 'Dog Training',
                    Icons.school,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.dogTrainingComingSoon ?? 'Dog Training Coming Soon!'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  _buildServiceBox(
                    localizations.dogParkService ?? 'Dog Park',
                    Icons.park,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DogParkPage()),
                      );
                    },
                  ),
                  _buildServiceBox(
                    localizations.findFriendsService ?? 'Find Friends',
                    Icons.people,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.findFriendsComingSoon ?? 'Find Friends Coming Soon!'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AuthPage(
                            isLogin: true,
                            onDogAdded: (Dog dog) {},
                            dogsList: widget.dogsList,
                            favoriteDogs: widget.favoriteDogs,
                            onToggleFavorite: widget.onToggleFavorite,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFFFFC107),
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    ),
                    child: Text(localizations.signInButton ?? 'Sign In', style: GoogleFonts.poppins(fontSize: 14)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AuthPage(
                            isLogin: false,
                            onDogAdded: (Dog dog) {},
                            dogsList: widget.dogsList,
                            favoriteDogs: widget.favoriteDogs,
                            onToggleFavorite: widget.onToggleFavorite,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFFFFC107),
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    ),
                    child: Text(localizations.signUpButton ?? 'Sign Up', style: GoogleFonts.poppins(fontSize: 14)),
                  ),
                ],
              ),
            ),
            _isAdLoaded
                ? Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(3),
                    child: SizedBox(
                      height: _bannerAd.size.height.toDouble(),
                      width: double.infinity,
                      child: AdWidget(ad: _bannerAd),
                    ),
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddDogPage(
                onDogAdded: (dog) async {
                  if (mounted) {
                    setState(() {
                      final dogCopy = Dog(
                        id: dog.id, // استفاده از id
                        name: dog.name,
                        breed: dog.breed,
                        age: dog.age,
                        gender: dog.gender,
                        healthStatus: dog.healthStatus,
                        isNeutered: dog.isNeutered,
                        description: dog.description,
                        traits: dog.traits,
                        ownerGender: dog.ownerGender,
                        imagePaths: dog.imagePaths,
                        isAvailableForAdoption: dog.isAvailableForAdoption,
                        isOwner: dog.isOwner,
                        ownerId: dog.ownerId,
                        latitude: dog.latitude,
                        longitude: dog.longitude,
                      );
                      final dogKey = dogCopy.id;

                      FirebaseFirestore.instance.collection('dogs').doc(dogKey).get().then((doc) {
                        if (doc.exists) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.dogNameExists(dogCopy.name) ?? 'A dog named ${dogCopy.name} already exists!')),
                          );
                        } else {
                          dogsBox.put(dogKey, dogCopy);
                          FirebaseFirestore.instance.collection('dogs').doc(dogKey).set({
                            'id': dogCopy.id, // ذخیره id در Firestore
                            'name': dogCopy.name,
                            'breed': dogCopy.breed,
                            'age': dogCopy.age,
                            'gender': dogCopy.gender,
                            'healthStatus': dogCopy.healthStatus,
                            'isNeutered': dogCopy.isNeutered,
                            'description': dogCopy.description,
                            'traits': dogCopy.traits,
                            'ownerGender': dogCopy.ownerGender,
                            'imagePaths': dogCopy.imagePaths,
                            'isAvailableForAdoption': dogCopy.isAvailableForAdoption,
                            'isOwner': dogCopy.isOwner,
                            'ownerId': dogCopy.ownerId,
                            'latitude': dogCopy.latitude,
                            'longitude': dogCopy.longitude,
                          });
                          _applyFiltersAsync();
                          _loadUserDogs();
                        }
                      });
                    });
                  }
                },
                favoriteDogs: widget.favoriteDogs,
                onToggleFavorite: widget.onToggleFavorite,
              ),
            ),
          );
        },
        backgroundColor: Color(0xFFFFC107),
        child: const Icon(Icons.add, color: Colors.pink),
      ),
    );
  }
}