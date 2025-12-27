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
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:badges/badges.dart' as badges;
import 'dog_card.dart';
import 'filter_page.dart';
import 'favorites_page.dart';
import 'user_profile_page.dart';
import 'vet_page.dart';
import 'all_notifications_page.dart';
import 'dog_park_page.dart';
import 'adoption_page.dart';
import 'offers_manager.dart';
import 'screens/lost_dogs_list_page.dart';
import 'screens/found_dogs_list_page.dart';
import 'dart:io' show InternetAddress, SocketException;
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/utils/localization_utils.dart';
import 'package:flutter/foundation.dart';


class PlaymatePage extends StatefulWidget {
  final List<Dog> dogs;
  final String currentUserId;
  final List<Dog>? favoriteDogs;
  final void Function(Dog)? onToggleFavorite;

  const PlaymatePage({
    super.key,
    required this.dogs,
    required this.currentUserId,
    this.favoriteDogs,
    this.onToggleFavorite,
  });

  @override
  State<PlaymatePage> createState() => _PlaymatePageState();
}

class _PlaymatePageState extends State<PlaymatePage> with AutomaticKeepAliveClientMixin, LocalizationUtils {
  String? selectedBreed;
  String? selectedGender;
  RangeValues? ageRange;
  bool? selectedNeutered;
  String? selectedHealthStatus;
  List<Dog> _filteredDogs = [];
  late Box<Dog> dogsBox;
  double? _userLatitude;
  double? _userLongitude;
  double _maxDistance = 50.0;
  bool _isPremium = false;
  bool _isPremiumLoaded = false;
  bool _isLoading = true;
  int _unreadNotificationsCount = 0;
  late StreamSubscription<QuerySnapshot> _notificationsSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    dogsBox = Hive.box<Dog>('dogsBox');
    if (kDebugMode) {
      print('PlaymatePage - Init: Current userId: ${widget.currentUserId}, Dogs count: ${widget.dogs.length}');
    }
    _loadData();
    _checkInternetAndStartStream();
  }

  Future<void> _checkInternetAndStartStream() async {
    bool hasInternet = await _checkInternetConnection();
    if (hasInternet) {
      _notificationsSubscription = FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientUserId', isEqualTo: widget.currentUserId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _unreadNotificationsCount = snapshot.docs.length;
            if (kDebugMode) {
              print('PlaymatePage - Updated unread notifications count (realtime): $_unreadNotificationsCount');
            }
          });
        }
      }, onError: (e, stackTrace) {
        if (kDebugMode) {
          print('PlaymatePage - Error in notifications stream: $e');
          print('StackTrace: $stackTrace');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingNotifications(e.toString()), style: GoogleFonts.poppins())),
          );
        }
      });
    } else {
      await Future.delayed(const Duration(seconds: 5));
      await _checkInternetAndStartStream();
    }
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
    try {
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientUserId', isEqualTo: widget.currentUserId)
          .where('isRead', isEqualTo: false)
          .get();
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = notificationsSnapshot.docs.length;
          if (kDebugMode) {
            print('PlaymatePage - Loaded unread notifications count: $_unreadNotificationsCount');
          }
        });
      }
    } catch (e, stackTrace) {
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
    if (kDebugMode) {
      print('PlaymatePage - Starting _loadData');
    }
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
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 5),
            );
            userLatitude = position.latitude;
            userLongitude = position.longitude;
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

      final dogsList = widget.dogs.map((dog) => {
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
        'id': dog.id,
      }).toList();

      final filteredDogs = await compute(_applyFiltersIsolate, [
        dogsList,
        widget.currentUserId,
        selectedBreed,
        selectedGender,
        ageRange,
        userLatitude,
        userLongitude,
        maxDistance,
        selectedNeutered,
        selectedHealthStatus,
      ]);

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

      final existingKeys = dogsBox.keys.cast<String>().toList();
      for (var key in existingKeys) {
        if (!uniqueDogs.containsKey(key)) {
          await dogsBox.delete(key);
          if (kDebugMode) {
            print('PlaymatePage - Deleted stale dog from Hive: $key');
          }
        }
      }
      for (final entry in uniqueDogs.entries) {
        if (!dogsBox.containsKey(entry.key)) {
          await dogsBox.put(entry.key, entry.value);
          if (kDebugMode) {
            print('PlaymatePage - Added dog to dogsBox: ${entry.value.name}, id: ${entry.value.id}');
          }
        }
      }
      if (kDebugMode) {
        print('PlaymatePage - Loaded ${uniqueDogs.length} unique dogs into Hive');
      }

      if (mounted) {
        setState(() {
          _isPremium = isPremium;
          _maxDistance = maxDistance;
          _userLatitude = userLatitude;
          _userLongitude = userLongitude;
          _filteredDogs = uniqueDogs.values.toList();
          _isPremiumLoaded = true;
          _isLoading = false;
          if (kDebugMode) {
            print('PlaymatePage - _isLoading set to false, filteredDogs: ${_filteredDogs.length}');
          }
        });
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
      final notOwnDog = (dogMap['ownerId']?.toLowerCase() ?? '') != currentUserId.toLowerCase();
      if (!notOwnDog) {
        if (kDebugMode) {
          print('PlaymatePage - Excluding dog ${dogMap['name']} because ownerId (${dogMap['ownerId']}) matches currentUserId ($currentUserId)');
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
          isNeutered: dogMap['isNeutered'] as bool,
          description: dogMap['description'] as String,
          traits: List<String>.from(dogMap['traits'] ?? []),
          ownerGender: dogMap['ownerGender'] as String,
          imagePaths: List<String>.from(dogMap['imagePaths'] ?? []),
          isAvailableForAdoption: dogMap['isAvailableForAdoption'] as bool,
          isOwner: dogMap['isOwner'] as bool,
          ownerId: dogMap['ownerId'] as String,
          latitude: dogMap['latitude'] as double,
          longitude: dogMap['longitude'] as double,
        )).toList();

    return filteredDogs;
  }

  Future<void> _applyFiltersAsync({Map<String, dynamic>? filters}) async {
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
      final dogsList = _filteredDogs.map((dog) => {
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
        'id': dog.id,
      }).toList();

      final filteredDogs = await compute(_applyFiltersIsolate, [
        dogsList,
        widget.currentUserId,
        selectedBreed,
        selectedGender,
        ageRange,
        _userLatitude,
        _userLongitude,
        _maxDistance,
        selectedNeutered,
        selectedHealthStatus,
      ]);

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
    _notificationsSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final availableBreeds = [...getDogBreeds(context), ..._filteredDogs.map((dog) => dog.breed).toSet()];
    final List<String> uniqueBreeds = availableBreeds.cast<String>().toSet().toList();
    final appState = context.watch<AppState>();
    final favs = widget.favoriteDogs ?? appState.favoriteDogs ?? const <Dog>[];

    if (kDebugMode) {
      print('PlaymatePage - Building UI with _isLoading: $_isLoading, filteredDogs: ${_filteredDogs.length}');
    }

    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.findPlaymateTitle,
          style: GoogleFonts.dancingScript(color: const Color(0xFFFFC107)),
        ),
        backgroundColor: Colors.pink,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFFFFC107)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          badges.Badge(
            showBadge: _unreadNotificationsCount > 0,
            badgeContent: Text(
              '$_unreadNotificationsCount',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications, color: Color(0xFFFFC107)),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllNotificationsPage(
                      currentUserId: widget.currentUserId,
                      dogsList: _filteredDogs,
                      favoriteDogs: favs,
                      onToggleFavorite: widget.onToggleFavorite ?? appState.toggleFavorite,
                    ),
                  ),
                );
              },
              tooltip: localizations.notificationsTooltip,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat, color: Color(0xFFFFC107)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.chatNotImplemented, style: GoogleFonts.poppins())),
              );
            },
            tooltip: localizations.chatTooltip,
          ),
        ],
      ),
      drawer: Drawer(
        width: 240.0,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.pink),
              child: Text(
                localizations.menuTitle ?? 'Menu',
                style: GoogleFonts.poppins(color: const Color(0xFFFFC107), fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.black),
              title: Text(localizations.homeMenuItem ?? 'Home', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/playmate');
              },
            ),
            ListTile(
              leading: const Icon(Icons.pets, color: Colors.black),
              title: Text(localizations.myDogsMenuItem ?? 'My Dogs', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfilePage(
                      dogsList: _filteredDogs,
                      favoriteDogs: favs,
                      onToggleFavorite: widget.onToggleFavorite ?? appState.toggleFavorite,
                      userId: widget.currentUserId,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.black),
              title: Text(localizations.favoritesMenuItem ?? 'Favorites', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FavoritesPage(
                      favoriteDogs: favs,
                      dogsList: _filteredDogs,
                      onToggleFavorite: widget.onToggleFavorite ?? appState.toggleFavorite,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.pets, color: Colors.black),
              title: Text(localizations.adoptionCenterMenuItem ?? 'Adoption Center', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdoptionPage(
                      dogs: _filteredDogs,
                      favoriteDogs: favs,
                      onToggleFavorite: widget.onToggleFavorite ?? appState.toggleFavorite,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.park, color: Colors.black),
              title: Text(localizations.dogParkMenuItem ?? 'Dog Park', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DogParkPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.black),
              title: Text(localizations.reportLostDogMenuItem ?? 'Report Lost Dog', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/lost_dog_report');
              },
            ),
            ListTile(
              leading: const Icon(Icons.list, color: Colors.black),
              title: Text(localizations.lostDogsMenuItem ?? 'Lost Dogs', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LostDogsListPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.black),
              title: Text(localizations.reportFoundDogMenuItem ?? 'Report Found Dog', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/found_dog_report');
              },
            ),
            ListTile(
              leading: const Icon(Icons.list, color: Colors.black),
              title: Text(localizations.foundDogsMenuItem ?? 'Found Dogs', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FoundDogsListPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.pink,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Center(
                      child: SizedBox(
                        width: 150,
                        height: 150,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: Icon(
                            Icons.pets,
                            size: 80,
                            color: Color(0xFFFFC107),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        localizations.helloMessage(FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? 'User'),
                        style: GoogleFonts.dancingScript(
                          color: const Color(0xFFFFC107),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    OffersManager.buildOffersSection(_isPremium),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SizedBox(
                            width: 150,
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: Text(
                                localizations.selectBreedHint,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFFC107),
                                ),
                              ),
                              value: selectedBreed,
                              onChanged: (value) {
                                setState(() {
                                  selectedBreed = value;
                                });
                                _applyFiltersAsync();
                              },
                              items: uniqueBreeds
                                  .map((breed) => DropdownMenuItem<String>(
                                        value: breed,
                                        child: Text(
                                          breed,
                                          style: GoogleFonts.poppins(),
                                        ),
                                      ))
                                  .toList(),
                              dropdownColor: Colors.pinkAccent,
                              style: GoogleFonts.poppins(color: const Color(0xFFFFC107)),
                              iconEnabledColor: const Color(0xFFFFC107),
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: Text(
                                localizations.selectGenderHint,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFFC107),
                                ),
                              ),
                              value: selectedGender,
                              onChanged: (value) {
                                setState(() {
                                  selectedGender = value;
                                });
                                _applyFiltersAsync();
                              },
                              items: [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text(
                                    localizations.anyGender,
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'Male',
                                  child: Text(
                                    'Male',
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'Female',
                                  child: Text(
                                    'Female',
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                              ],
                              dropdownColor: Colors.pinkAccent,
                              style: GoogleFonts.poppins(color: const Color(0xFFFFC107)),
                              iconEnabledColor: const Color(0xFFFFC107),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              localizations.distanceLabel(_maxDistance.toStringAsFixed(1)),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFFFC107),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _maxDistance,
                              min: 1,
                              max: _isPremium ? 100.0 : 50.0,
                              divisions: _isPremium ? 99 : 49,
                              label: _maxDistance.toStringAsFixed(1),
                              onChanged: (value) {
                                setState(() {
                                  _maxDistance = value;
                                });
                                _applyFiltersAsync();
                              },
                              activeColor: const Color(0xFFFFC107),
                              inactiveColor: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _resetFilters,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFFFC107),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            child: Text(
                              localizations.resetFiltersButton,
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _openFilterPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFFFC107),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            child: Text(
                              localizations.moreFiltersButton,
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _filteredDogs.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text(
                                  localizations.noDogsMatchFilters,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFFFC107),
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  localizations.adjustFiltersSuggestion,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFFFC107),
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            key: const ValueKey('dog_list'),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            cacheExtent: 1000.0,
                            itemCount: _filteredDogs.length,
                            itemBuilder: (context, index) {
                              final dog = _filteredDogs[index];
                              if (kDebugMode) {
                                print(
                                    'PlaymatePage - Displaying dog at index $index: Name=${dog.name}, Breed=${dog.breed}, Age=${dog.age}, Gender=${dog.gender}, ImagePaths=${dog.imagePaths}, ID=${dog.id}');
                              }
                              return RepaintBoundary(
                                child: DogCard(
                                  key: ValueKey(dog.id),
                                  dog: dog,
                                  allDogs: widget.dogs,
                                  currentUserId: widget.currentUserId,
                                  favoriteDogs: favs,
                                  onToggleFavorite: widget.onToggleFavorite ?? appState.toggleFavorite,
                                  selectedRequesterDogId: appState.selectedRequesterDogId,
                                  onRequesterDogChanged: (value) {
                                    appState.setSelectedRequesterDogId(value);
                                    if (kDebugMode) {
                                      print('PlaymatePage - Selected requester dog changed: $value');
                                    }
                                  },
                                  onDogUpdated: (updatedDog) {
                                    if (mounted) {
                                      setState(() {
                                        dogsBox.put(updatedDog.id, updatedDog);
                                        FirebaseFirestore.instance.collection('dogs').doc(updatedDog.id).set({
                                          'id': updatedDog.id,
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
                                        }, SetOptions(merge: true));
                                        _applyFiltersAsync();
                                        if (kDebugMode) {
                                          print('PlaymatePage - Updated dog: ${updatedDog.name}, id: ${updatedDog.id}');
                                        }
                                      });
                                    }
                                  },
                                  getSelectedDog: () {
                                    final selectedId = appState.selectedRequesterDogId;
                                    return selectedId != null
                                        ? widget.dogs.firstWhereOrNull(
                                            (d) => d.id == selectedId,
                                          )
                                        : null;
                                  },
                                  showDogSelection: false,
                                  likers: appState.dogLikes[dog.id] ?? [],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: localizations.homeNavItem),
          BottomNavigationBarItem(icon: const Icon(Icons.favorite), label: localizations.favoritesNavItem),
          BottomNavigationBarItem(icon: const Icon(Icons.local_hospital), label: localizations.visitVetNavItem),
          BottomNavigationBarItem(icon: const Icon(Icons.calendar_today), label: localizations.playdateNavItem),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: localizations.profileNavItem),
        ],
        selectedItemColor: const Color(0xFFFFC107),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.pink,
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/playmate');
              break;
            case 1:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FavoritesPage(
                    favoriteDogs: favs,
                    dogsList: _filteredDogs,
                    onToggleFavorite: widget.onToggleFavorite ?? appState.toggleFavorite,
                  ),
                ),
              );
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
              Navigator.pushNamed(context, '/schedule_playdate');
              break;
            case 4:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfilePage(
                    dogsList: _filteredDogs,
                    favoriteDogs: favs,
                    onToggleFavorite: widget.onToggleFavorite ?? appState.toggleFavorite,
                    userId: widget.currentUserId,
                  ),
                ),
              );
              break;
          }
        },
      ),
    );
  }
}