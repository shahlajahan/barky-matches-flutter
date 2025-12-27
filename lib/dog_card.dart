
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'dart:io';
import 'other_user_dog_page.dart';
import 'dog.dart';
import 'edit_dog_dialog.dart';
import 'app_state.dart';
import 'notification_service.dart';
import 'utils/extensions.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';


// متغیر برای ذخیره RootIsolateToken در Main Isolate
RootIsolateToken? _rootIsolateToken;

Future<void> initializeRootIsolateToken() async {
  _rootIsolateToken = RootIsolateToken.instance;
  if (kDebugMode) {
    print('DogCard - Initialized RootIsolateToken in Main Isolate');
  }
}

Future<Position?> _getCurrentPosition() async {
  try {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 10),
    );
    return position;
  } catch (e) {
    if (kDebugMode) {
      print('DogCard - Error getting current position: $e');
    }
    return null;
  }
}

class MapPickerPage extends StatefulWidget {
  final LatLng initialLocation;
  const MapPickerPage({super.key, required this.initialLocation});

  @override
  _MapPickerPageState createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(0, 0);
  bool _isLoading = true;
  String? _errorMessage;
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _checkApiKeyAndLoadMap();
  }

  Future<void> _checkApiKeyAndLoadMap() async {
    try {
      final apiKey = await _getApiKeyFromManifest();
      if (apiKey == null || apiKey.isEmpty) {
        setState(() {
          _errorMessage = 'API Key not found. Please check AndroidManifest.xml.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _isLoading = false;
        _showMap = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing map: $e';
        _isLoading = false;
      });
    }
  }

  Future<String?> _getApiKeyFromManifest() async {
    const String defaultApiKey = 'AIzaSyDZYlA4OIsLEqOtKXXRtMyyqP8TF7H6dcE';
    if (kDebugMode) {
      print('DogCard - Using default API key: $defaultApiKey');
    }
    return defaultApiKey;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController ??= controller;
    rootBundle.loadString('assets/map_style.json').then((style) {
      _mapController?.setMapStyle(style);
      if (kDebugMode) {
        print('MapPickerPage - Applied map style');
      }
    }).catchError((e) {
      if (kDebugMode) {
        print('MapPickerPage - Error applying map style: $e');
      }
    });
  }

  void _onTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.selectLocation, style: GoogleFonts.poppins()),
        backgroundColor: Colors.pink,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              : Stack(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: ValueNotifier(_showMap),
                      builder: (context, showMap, _) {
                        if (!showMap) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        return GoogleMap(
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: CameraPosition(
                            target: widget.initialLocation,
                            zoom: 12.0,
                          ),
                          onTap: _onTap,
                          markers: {
                            Marker(
                              markerId: const MarkerId('selected-location'),
                              position: _selectedLocation,
                            ),
                          },
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: true,
                          zoomGesturesEnabled: true,
                          scrollGesturesEnabled: true,
                          tiltGesturesEnabled: false,
                          rotateGesturesEnabled: false,
                          buildingsEnabled: false,
                        );
                      },
                    ),
                    Positioned(
                      bottom: 16.0,
                      left: 16.0,
                      right: 16.0,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.pink,
                        ),
                        onPressed: () {
                          if (_errorMessage == null) {
                            Navigator.pop(context, _selectedLocation);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_errorMessage!, style: GoogleFonts.poppins())),
                            );
                          }
                        },
                        child: Text(localizations.confirmLocation, style: GoogleFonts.poppins()),
                      ),
                    ),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class DogCard extends StatefulWidget {
  final Dog dog;
  final List<Dog> allDogs;
  final String currentUserId;
  final List<Dog>? favoriteDogs;
  final String? selectedRequesterDogId;
  final void Function(String?)? onRequesterDogChanged;
  final void Function(Dog)? onToggleFavorite;
  final void Function(Dog)? onDogUpdated;
  final VoidCallback? onAdopt;
  final Dog? Function()? getSelectedDog;
  final bool showDogSelection;
  final List<Map<String, dynamic>> likers;

  const DogCard({
    super.key,
    required this.dog,
    required this.allDogs,
    required this.currentUserId,
    this.favoriteDogs,
    this.selectedRequesterDogId,
    this.onRequesterDogChanged,
    this.onToggleFavorite,
    this.onDogUpdated,
    this.onAdopt,
    this.getSelectedDog,
    this.showDogSelection = true,
    required this.likers,
  });

  @override
  _DogCardState createState() => _DogCardState();
}

class _DogCardState extends State<DogCard> {
  late AppLocalizations localizations;
  bool _isEditing = false;
  bool _isDialogOpen = false;
  bool _sending = false;
  late ScaffoldMessengerState _scaffoldMessenger;
  late List<Dog> _userDogs;
  String? _autoSelectedDogId;
  bool _isFavorite = false;
  int _likeCount = 0;
  bool _isDisliked = false;
  GoogleMapController? _mapController;

  String? get _selectedId {
    if (_selectedIdFromOutside != null) return _selectedIdFromOutside;
    if (_autoSelectedDogId != null) return _autoSelectedDogId;
    return Provider.of<AppState>(context, listen: false).selectedRequesterDogId;
  }

  String? get _selectedIdFromOutside => widget.selectedRequesterDogId;

  Widget _buildDogImage(String imagePath) {
    return imagePath.startsWith('http')
        ? CachedNetworkImage(
            imageUrl: imagePath,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                const CircularProgressIndicator(color: Colors.white),
            errorWidget: (context, url, error) {
              if (kDebugMode) {
                print('DogCard - Error loading image: $error');
              }
              return const Image(
                image: AssetImage('assets/image/default_dog.png'),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              );
            },
          )
        : Image(
            image: FileImage(File(imagePath)),
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode) {
                print('DogCard - Error loading file image: $error');
              }
              return const Image(
                image: AssetImage('assets/image/default_dog.png'),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              );
            },
          );
  }

  Widget _buildExpandedDogImage(String imagePath) {
    return imagePath.startsWith('http')
        ? CachedNetworkImage(
            imageUrl: imagePath,
            width: double.infinity,
            height: 150,
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) {
              if (kDebugMode) {
                print('DogCard - Error loading expanded image: $error');
              }
              return const Image(
                image: AssetImage('assets/image/default_dog.png'),
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
              );
            },
          )
        : Image(
            image: FileImage(File(imagePath)),
            width: double.infinity,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode) {
                print('DogCard - Error loading file image: $error');
              }
              return const Image(
                image: AssetImage('assets/image/default_dog.png'),
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
              );
            },
          );
  }

  String translateGender(String gender) {
    if (gender.isEmpty) {
      return localizations.unknownGender ?? 'Unknown Gender';
    }
    final lowerGender = gender.toLowerCase().trim();
    if (kDebugMode) {
      print('Gender exact: "$gender" -> lower: "$lowerGender"');
    }
    final maleFa = (localizations.genderMale ?? 'male').toLowerCase();
    final femaleFa = (localizations.genderFemale ?? 'female').toLowerCase();
    if (lowerGender == maleFa || lowerGender == 'نر' || lowerGender == 'male') {
      return localizations.genderMale ?? 'Male';
    }
    if (lowerGender == femaleFa || lowerGender == 'ماده' || lowerGender == 'female') {
      return localizations.genderFemale ?? 'Female';
    }
    return gender;
  }

  String translateHealthStatus(String status) {
    final l10n = AppLocalizations.of(context)!;
    if (status.isEmpty) {
      return l10n.unknownStatus ?? 'Unknown Status';
    }
    final lowerStatus = status.toLowerCase().trim();
    if (kDebugMode) {
      print('Health Status exact: "$status" -> lower: "$lowerStatus"');
    }
    final healthyFa = (l10n.healthHealthy ?? 'healthy').toLowerCase();
    final needsFa = (l10n.healthNeedsCare ?? 'needs care').toLowerCase();
    final underFa = (l10n.healthUnderTreatment ?? 'under treatment').toLowerCase();
    if (lowerStatus == healthyFa || lowerStatus == 'سالم' || lowerStatus == 'healthy') {
      return l10n.healthHealthy ?? 'Healthy';
    }
    if (lowerStatus == needsFa ||
        lowerStatus == 'نیاز به مراقبت' ||
        lowerStatus == 'needs care' ||
        lowerStatus == 'needs attention') {
      return l10n.healthNeedsCare ?? 'Needs Care';
    }
    if (lowerStatus == underFa ||
        lowerStatus == 'در حال درمان' ||
        lowerStatus == 'under treatment') {
      return l10n.healthUnderTreatment ?? 'Under Treatment';
    }
    if (kDebugMode) {
      print('No match for health status: "$lowerStatus"');
    }
    return status;
  }

  String translateBreed(String breedKey) {
    if (breedKey.isEmpty) {
      return localizations.unknownBreed ?? 'Unknown Breed';
    }
    switch (breedKey) {
      case 'breedAfghanHound':
        return localizations.breedAfghanHound ?? 'Afghan Hound';
      case 'breedAiredaleTerrier':
        return localizations.breedAiredaleTerrier ?? 'Airedale Terrier';
      case 'breedAkita':
        return localizations.breedAkita ?? 'Akita';
      case 'breedAlaskanMalamute':
        return localizations.breedAlaskanMalamute ?? 'Alaskan Malamute';
      case 'breedAmericanBulldog':
        return localizations.breedAmericanBulldog ?? 'American Bulldog';
      case 'breedAmericanPitBullTerrier':
        return localizations.breedAmericanPitBullTerrier ??
            'American Pit Bull Terrier';
      case 'breedAustralianCattleDog':
        return localizations.breedAustralianCattleDog ?? 'Australian Cattle Dog';
      case 'breedAustralianShepherd':
        return localizations.breedAustralianShepherd ?? 'Australian Shepherd';
      case 'breedBassetHound':
        return localizations.breedBassetHound ?? 'Basset Hound';
      case 'breedBeagle':
        return localizations.breedBeagle ?? 'Beagle';
      case 'breedBelgianMalinois':
        return localizations.breedBelgianMalinois ?? 'Belgian Malinois';
      case 'breedBerneseMountainDog':
        return localizations.breedBerneseMountainDog ?? 'Bernese Mountain Dog';
      case 'breedBichonFrise':
        return localizations.breedBichonFrise ?? 'Bichon Frise';
      case 'breedBloodhound':
        return localizations.breedBloodhound ?? 'Bloodhound';
      case 'breedBorderCollie':
        return localizations.breedBorderCollie ?? 'Border Collie';
      case 'breedBostonTerrier':
        return localizations.breedBostonTerrier ?? 'Boston Terrier';
      case 'breedBoxer':
        return localizations.breedBoxer ?? 'Boxer';
      case 'breedBulldog':
        return localizations.breedBulldog ?? 'Bulldog';
      case 'breedBullmastiff':
        return localizations.breedBullmastiff ?? 'Bullmastiff';
      case 'breedCairnTerrier':
        return localizations.breedCairnTerrier ?? 'Cairn Terrier';
      case 'breedCaneCorso':
        return localizations.breedCaneCorso ?? 'Cane Corso';
      case 'breedCavalierKingCharlesSpaniel':
        return localizations.breedCavalierKingCharlesSpaniel ??
            'Cavalier King Charles Spaniel';
      case 'breedChihuahua':
        return localizations.breedChihuahua ?? 'Chihuahua';
      case 'breedChowChow':
        return localizations.breedChowChow ?? 'Chow Chow';
      case 'breedCockerSpaniel':
        return localizations.breedCockerSpaniel ?? 'Cocker Spaniel';
      case 'breedCollie':
        return localizations.breedCollie ?? 'Collie';
      case 'breedDachshund':
        return localizations.breedDachshund ?? 'Dachshund';
      case 'breedDalmatian':
        return localizations.breedDalmatian ?? 'Dalmatian';
      case 'breedDobermanPinscher':
        return localizations.breedDobermanPinscher ?? 'Doberman Pinscher';
      case 'breedEnglishSpringerSpaniel':
        return localizations.breedEnglishSpringerSpaniel ??
            'English Springer Spaniel';
      case 'breedFrenchBulldog':
        return localizations.breedFrenchBulldog ?? 'French Bulldog';
      case 'breedGermanShepherd':
        return localizations.breedGermanShepherd ?? 'German Shepherd';
      case 'breedGermanShorthairedPointer':
        return localizations.breedGermanShorthairedPointer ??
            'German Shorthaired Pointer';
      case 'breedGoldenRetriever':
        return localizations.breedGoldenRetriever ?? 'Golden Retriever';
      case 'breedGreatDane':
        return localizations.breedGreatDane ?? 'Great Dane';
      case 'breedGreatPyrenees':
        return localizations.breedGreatPyrenees ?? 'Great Pyrenees';
      case 'breedHavanese':
        return localizations.breedHavanese ?? 'Havanese';
      case 'breedIrishSetter':
        return localizations.breedIrishSetter ?? 'Irish Setter';
      case 'breedIrishWolfhound':
        return localizations.breedIrishWolfhound ?? 'Irish Wolfhound';
      case 'breedJackRussellTerrier':
        return localizations.breedJackRussellTerrier ?? 'Jack Russell Terrier';
      case 'breedLabradorRetriever':
        return localizations.breedLabradorRetriever ?? 'Labrador Retriever';
      case 'breedLhasaApso':
        return localizations.breedLhasaApso ?? 'Lhasa Apso';
      case 'breedMaltese':
        return localizations.breedMaltese ?? 'Maltese';
      case 'breedMastiff':
        return localizations.breedMastiff ?? 'Mastiff';
      case 'breedMiniatureSchnauzer':
        return localizations.breedMiniatureSchnauzer ?? 'Miniature Schnauzer';
      case 'breedNewfoundland':
        return localizations.breedNewfoundland ?? 'Newfoundland';
      case 'breedPapillon':
        return localizations.breedPapillon ?? 'Papillon';
      case 'breedPekingese':
        return localizations.breedPekingese ?? 'Pekingese';
      case 'breedPomeranian':
        return localizations.breedPomeranian ?? 'Pomeranian';
      case 'breedPoodle':
        return localizations.breedPoodle ?? 'Poodle';
      case 'breedPug':
        return localizations.breedPug ?? 'Pug';
      case 'breedRottweiler':
        return localizations.breedRottweiler ?? 'Rottweiler';
      case 'breedSaintBernard':
        return localizations.breedSaintBernard ?? 'Saint Bernard';
      case 'breedSamoyed':
        return localizations.breedSamoyed ?? 'Samoyed';
      case 'breedShetlandSheepdog':
        return localizations.breedShetlandSheepdog ?? 'Shetland Sheepdog';
      case 'breedShihTzu':
        return localizations.breedShihTzu ?? 'Shih Tzu';
      case 'breedSiberianHusky':
        return localizations.breedSiberianHusky ?? 'Siberian Husky';
      case 'breedStaffordshireBullTerrier':
        return localizations.breedStaffordshireBullTerrier ??
            'Staffordshire Bull Terrier';
      case 'breedVizsla':
        return localizations.breedVizsla ?? 'Vizsla';
      case 'breedWeimaraner':
        return localizations.breedWeimaraner ?? 'Weimaraner';
      case 'breedWestHighlandWhiteTerrier':
        return localizations.breedWestHighlandWhiteTerrier ??
            'West Highland White Terrier';
      case 'breedYorkshireTerrier':
        return localizations.breedYorkshireTerrier ?? 'Yorkshire Terrier';
      default:
        final parts = breedKey.split('breed');
        return parts.length > 1 ? parts[1] : breedKey;
    }
  }

  String translateTrait(String traitKey) {
    final l10n = AppLocalizations.of(context)!;
    if (traitKey.isEmpty) {
      return l10n.unknownTrait ?? 'Unknown Trait';
    }
    final rawToLocalized = {
      'energetic': l10n.traitEnergetic ?? 'Energetic',
      'playful': l10n.traitPlayful ?? 'Playful',
      'calm': l10n.traitCalm ?? 'Calm',
      'loyal': l10n.traitLoyal ?? 'Loyal',
      'friendly': l10n.traitFriendly ?? 'Friendly',
      'protective': l10n.traitProtective ?? 'Protective',
      'intelligent': l10n.traitIntelligent ?? 'Intelligent',
      'affectionate': l10n.traitAffectionate ?? 'Affectionate',
      'curious': l10n.traitCurious ?? 'Curious',
      'independent': l10n.traitIndependent ?? 'Independent',
      'shy': l10n.traitShy ?? 'Shy',
      'trained': l10n.traitTrained ?? 'Trained',
      'social': l10n.traitSocial ?? 'Social',
      'good with kids': l10n.traitGoodWithKids ?? 'Good with kids',
      'دوستانه': l10n.traitFriendly ?? 'Friendly',
      'پر انرژی': l10n.traitEnergetic ?? 'Energetic',
      'خوب با بچه‌ها': l10n.traitGoodWithKids ?? 'Good with kids',
    };
    final lowerTrait = traitKey.toLowerCase().trim();
    if (kDebugMode) {
      print('Trait exact: "$traitKey" -> lower: "$lowerTrait"');
    }
    if (rawToLocalized.containsKey(lowerTrait)) {
      return rawToLocalized[lowerTrait]!;
    }
    switch (traitKey) {
      case 'traitEnergetic':
        return l10n.traitEnergetic ?? 'Energetic';
      case 'traitPlayful':
        return l10n.traitPlayful ?? 'Playful';
      case 'traitCalm':
        return l10n.traitCalm ?? 'Calm';
      case 'traitLoyal':
        return l10n.traitLoyal ?? 'Loyal';
      case 'traitFriendly':
        return l10n.traitFriendly ?? 'Friendly';
      case 'traitProtective':
        return l10n.traitProtective ?? 'Protective';
      case 'traitIntelligent':
        return l10n.traitIntelligent ?? 'Intelligent';
      case 'traitAffectionate':
        return l10n.traitAffectionate ?? 'Affectionate';
      case 'traitCurious':
        return l10n.traitCurious ?? 'Curious';
      case 'traitIndependent':
        return l10n.traitIndependent ?? 'Independent';
      case 'traitShy':
        return l10n.traitShy ?? 'Shy';
      default:
        if (kDebugMode) {
          print('No match for trait: "$traitKey"');
        }
        final parts = traitKey.split('trait');
        return parts.length > 1 ? parts[1] : traitKey;
    }
  }

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('DogCard - Initializing for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
      print('DogCard - Likers received: ${widget.likers}');
    }
    if (_rootIsolateToken == null) {
      _rootIsolateToken = RootIsolateToken.instance;
      if (kDebugMode) {
        print('DogCard - Initialized RootIsolateToken in initState');
      }
    }
    _userDogs = widget.allDogs
        .where((dog) => (dog.ownerId ?? '') == widget.currentUserId)
        .distinctBy((d) => d.id)
        .toList();
    if (kDebugMode) {
      print('DogCard - Unique user dogs: ${_userDogs.map((dog) => 'Name: ${dog.name}, OwnerId: ${dog.ownerId}, ID: ${dog.id}').toList()}');
      print('DogCard - Traits for ${widget.dog.name}: ${widget.dog.traits}');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_userDogs.isNotEmpty && mounted) {
        _autoSelectedDogId = _userDogs[0].id;
        Provider.of<AppState>(context, listen: false).setSelectedRequesterDogId(_autoSelectedDogId);
        if (kDebugMode) {
          print('DogCard - Auto-selected dog: ${_userDogs[0].name}, ID: $_autoSelectedDogId');
        }
      } else if (_userDogs.isEmpty) {
        if (kDebugMode) {
          print('DogCard - No user dogs found for currentUserId: ${widget.currentUserId}');
        }
      }
      _updateLikesAndFavorites();
    });
  }

  void _updateLikesAndFavorites() {
    final appState = Provider.of<AppState>(context, listen: false);
    final userId = widget.currentUserId ?? 'default_user';
    final dogKey = widget.dog.id;
    final likes = appState.likesNotifier.value;
    final userLikes = likes[userId] ?? [];
    _isFavorite = (widget.favoriteDogs ?? appState.favoriteDogs ?? []).any((favDog) =>
        favDog.id == widget.dog.id);
    _isDisliked = userLikes.contains('dislike_$dogKey');
    _likeCount = likes.values.fold(0, (count, userLikes) => count + (userLikes.contains(dogKey) ? 1 : 0));
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = AppLocalizations.of(context)!;
    _scaffoldMessenger = ScaffoldMessenger.of(context);
    if (kDebugMode) {
      print('DogCard - Dependencies changed for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
    }
  }

  Future<void> _schedulePlaydate(BuildContext context) async {
    if (kDebugMode) {
      print('DogCard - Attempting to schedule playdate for ${widget.dog.name}, ID: ${widget.dog.id}');
    }
    if (_sending) {
      if (kDebugMode) {
        print('DogCard - Playdate request already in progress');
      }
      return;
    }
    setState(() => _sending = true);
    try {
      await _actuallySchedulePlaydate();
    } catch (e) {
      if (kDebugMode) {
        print('DogCard - Error scheduling playdate: $e');
      }
      if (mounted) {
        _scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text(
                  localizations.errorSchedulingPlaydate(e.toString()),
                  style: GoogleFonts.poppins())),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _actuallySchedulePlaydate() async {
    if (!mounted) return;
    await Future.microtask(() async {
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (context, child) {
          return Theme(
            data: ThemeData(
              primaryColor: Colors.pink,
              colorScheme: ColorScheme.fromSwatch().copyWith(
                secondary: Colors.pinkAccent,
              ),
              textTheme: GoogleFonts.poppinsTextTheme(),
            ),
            child: child!,
          );
        },
      );
      if (pickedDate != null) {
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
          builder: (context, child) {
            return Theme(
              data: ThemeData(
                primaryColor: Colors.pink,
                colorScheme: ColorScheme.fromSwatch().copyWith(
                  secondary: Colors.pinkAccent,
                ),
                textTheme: GoogleFonts.poppinsTextTheme(),
              ),
              child: child!,
            );
          },
        );
        if (pickedTime != null) {
          final DateTime scheduledDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          String? location;
          Map<String, double>? positionData;
          if (_rootIsolateToken != null) {
            final ReceivePort receivePort = ReceivePort();
            await Isolate.spawn(_getCurrentPositionIsolate, [receivePort.sendPort, _rootIsolateToken]);
            final result = await receivePort.first;
            if (result is Map<String, double>) {
              positionData = result;
            }
          } else {
            if (kDebugMode) {
              print('DogCard - RootIsolateToken is null, falling back to main thread');
            }
            final position = await _getCurrentPosition();
            if (position != null) {
              positionData = {'latitude': position.latitude, 'longitude': position.longitude};
            }
          }
          if (positionData != null) {
            location = 'Lat: ${positionData['latitude']}, Long: ${positionData['longitude']}';
          } else {
            location = 'Lat: 41.0103, Long: 28.6724';
            if (kDebugMode) {
              print('DogCard - Using default location due to null currentPosition');
            }
          }
          final selectedOption = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(localizations.selectLocation, style: GoogleFonts.poppins()),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: localizations.enterLocation,
                        labelText: localizations.locationLabel,
                        labelStyle: GoogleFonts.poppins(),
                      ),
                      controller: TextEditingController(text: location),
                      onChanged: (value) => location = value,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.pink,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: () async {
                        final LatLng? pickedLocation = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapPickerPage(
                              initialLocation: positionData != null
                                  ? LatLng(positionData['latitude']!, positionData['longitude']!)
                                  : const LatLng(41.0103, 28.6724),
                            ),
                          ),
                        );
                        if (pickedLocation != null && mounted) {
                          location = 'Lat: ${pickedLocation.latitude}, Long: ${pickedLocation.longitude}';
                          Navigator.pop(context, location);
                        }
                      },
                      child: Text(
                        localizations.pickOnMap,
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      localizations.quickLocations,
                      style: GoogleFonts.poppins(color: Colors.pink, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.pink,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onPressed: () {
                            setState(() {
                              location = 'Lat: 41.0103, Long: 28.6724 (${localizations.parkA})';
                            });
                            Navigator.pop(context, location);
                          },
                          child: Text(
                            localizations.parkA,
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.pink,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onPressed: () {
                            setState(() {
                              location = 'Lat: 41.0156, Long: 28.6789 (${localizations.parkB})';
                            });
                            Navigator.pop(context, location);
                          },
                          child: Text(
                            localizations.parkB,
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text(localizations.cancel, style: GoogleFonts.poppins()),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: Text(localizations.confirm, style: GoogleFonts.poppins()),
                  onPressed: () => Navigator.pop(context, location ?? 'Unknown location'),
                ),
              ],
            ),
          );
          if (location == null) return;
          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (kDebugMode) {
            print('DogCard - CurrentUserId: $currentUserId');
          }
          if (currentUserId.isEmpty || FirebaseAuth.instance.currentUser == null) {
            if (kDebugMode) {
              print('DogCard - No authenticated user found');
            }
            if (mounted) {
              _scaffoldMessenger.showSnackBar(
                SnackBar(content: Text(localizations.pleaseLoginToSchedulePlaydate, style: GoogleFonts.poppins())),
              );
            }
            return;
          }
          if (_userDogs.isEmpty) {
            if (kDebugMode) {
              print('DogCard - No dogs found for user: $currentUserId');
            }
            if (mounted) {
              _scaffoldMessenger.showSnackBar(
                SnackBar(content: Text(localizations.noDogFoundForAccount, style: GoogleFonts.poppins())),
              );
            }
            return;
          }
          final selectedDogId = _selectedId;
          final Dog? requesterDog = widget.getSelectedDog != null
              ? widget.getSelectedDog!()
              : selectedDogId != null
                  ? _userDogs.firstWhereOrNull((d) => d.id == selectedDogId)
                  : _userDogs[0];
          if (requesterDog == null) {
            if (kDebugMode) {
              print('DogCard - No dog selected for playdate');
            }
            if (mounted) {
              _scaffoldMessenger.showSnackBar(
                SnackBar(content: Text(localizations.pleaseSelectYourDog, style: GoogleFonts.poppins())),
              );
            }
            return;
          }
          if (currentUserId == widget.dog.ownerId) {
            if (kDebugMode) {
              print('DogCard - Cannot schedule playdate with own dog: ${widget.dog.name}');
            }
            if (mounted) {
              _scaffoldMessenger.showSnackBar(
                SnackBar(content: Text(localizations.cannotScheduleWithOwnDog, style: GoogleFonts.poppins())),
              );
            }
            return;
          }
          final requestedDog = widget.dog;
          if (kDebugMode) {
            print('DogCard - RequestedDog: ${requestedDog.name}, OwnerId: ${requestedDog.ownerId}, ID: ${requestedDog.id}');
          }
          if (requestedDog.ownerId == null || requestedDog.ownerId!.isEmpty || requestedDog.ownerId!.startsWith('temp_')) {
            if (mounted) {
              _scaffoldMessenger.showSnackBar(
                SnackBar(content: Text(localizations.cannotScheduleWithTempUser, style: GoogleFonts.poppins())),
              );
            }
            if (kDebugMode) {
              print('DogCard - Invalid requestedDog ownerId: ${requestedDog.ownerId}');
            }
            return;
          }
          final newRequest = {
            'requesterUserId': currentUserId,
            'requestedUserId': requestedDog.ownerId!,
            'requesterDogId': requesterDog.id,
            'requestedDogId': requestedDog.id,
            'requesterDog': {
              'id': requesterDog.id,
              'name': requesterDog.name,
              'ownerId': currentUserId,
              'breed': requesterDog.breed,
              'age': requesterDog.age,
              'gender': requesterDog.gender,
              'healthStatus': requesterDog.healthStatus,
              'isNeutered': requesterDog.isNeutered,
              'description': requesterDog.description ?? '',
              'traits': requesterDog.traits,
              'ownerGender': requesterDog.ownerGender ?? '',
              'imagePaths': requesterDog.imagePaths,
              'isAvailableForAdoption': requesterDog.isAvailableForAdoption,
              'isOwner': false,
              'latitude': requesterDog.latitude,
              'longitude': requesterDog.longitude,
            },
            'requestedDog': {
              'id': requestedDog.id,
              'name': requestedDog.name,
              'ownerId': requestedDog.ownerId!,
              'breed': requestedDog.breed,
              'age': requestedDog.age,
              'gender': requestedDog.gender,
              'healthStatus': requestedDog.healthStatus,
              'isNeutered': requestedDog.isNeutered,
              'description': requestedDog.description ?? '',
              'traits': requestedDog.traits,
              'ownerGender': requestedDog.ownerGender ?? '',
              'imagePaths': requestedDog.imagePaths,
              'isAvailableForAdoption': requestedDog.isAvailableForAdoption,
              'isOwner': false,
              'latitude': requestedDog.latitude,
              'longitude': requestedDog.longitude,
            },
            'status': 'pending',
            'requestDate': FieldValue.serverTimestamp(),
            'scheduledDateTime': Timestamp.fromDate(scheduledDateTime),
            'location': location,
            'requesterName': Provider.of<AppState>(context, listen: false).currentUserName ?? 'Unknown User',
            'message': localizations.playdateRequestBody(requesterDog.name, requestedDog.name),
          };
          if (kDebugMode) {
            print('DogCard - Creating new playdate request for ${requestedDog.name}, ID: ${requestedDog.id}');
          }
          try {
            final docRef = await FirebaseFirestore.instance.collection('playDateRequests').add(newRequest);
            if (kDebugMode) {
              print('DogCard - Request created with ID: ${docRef.id}');
            }
            final notificationService = NotificationService();
            final body = localizations.playdateRequestBody(requesterDog.name, requestedDog.name);
            await notificationService.showNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: localizations.newPlayDateRequestTitle,
              body: body,
              likerUserId: currentUserId,
              payload: jsonEncode({
                'type': 'playdate_request',
                'requestId': docRef.id,
                'requesterUserId': currentUserId,
              }),
            );
            await FirebaseFirestore.instance.collection('notifications').add({
              'recipientUserId': requestedDog.ownerId,
              'timestamp': FieldValue.serverTimestamp(),
              'title': localizations.newPlayDateRequestTitle,
              'body': body,
              'payload': jsonEncode({
                'type': 'playdate_request',
                'requestId': docRef.id,
                'requesterUserId': currentUserId,
              }),
              'isRead': false,
            });
            if (mounted) {
              _scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(
                    localizations.playdateScheduled(
                      requestedDog.name,
                      scheduledDateTime.toString(),
                      location ?? 'Unknown location',
                    ),
                    style: GoogleFonts.poppins(),
                  ),
                ),
              );
            }
          } catch (e) {
            if (kDebugMode) {
              print('DogCard - Error creating request: $e');
            }
            if (mounted) {
              _scaffoldMessenger.showSnackBar(
                SnackBar(content: Text(localizations.errorCreatingRequest(e.toString()), style: GoogleFonts.poppins())),
              );
            }
          }
        }
      }
    });
  }

  Future<void> _openEditDialog(BuildContext context) async {
    if (widget.onDogUpdated == null) {
      if (kDebugMode) {
        print('DogCard - Edit not allowed for dog: ${widget.dog.name}, ID: ${widget.dog.id}, onDogUpdated is null');
      }
      return;
    }
    if (_isEditing || _isDialogOpen) {
      if (kDebugMode) {
        print('DogCard - Edit dialog already open or editing in progress for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
      }
      return;
    }
    setState(() {
      _isEditing = true;
      _isDialogOpen = true;
      if (kDebugMode) {
        print('DogCard - Opening EditDogDialog for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
      }
    });
    try {
      final updatedDog = await showDialog<Dog>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => EditDogDialog(
          dog: widget.dog,
          onEditDog: (updatedDog) {
            if (kDebugMode) {
              print('DogCard - Dog updated in dialog: ${updatedDog.name}, ID: ${updatedDog.id}');
            }
            widget.onDogUpdated!(updatedDog);
            Navigator.pop(dialogContext, updatedDog);
            if (kDebugMode) {
              print('DogCard - Dialog popped successfully for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
            }
          },
        ),
      );
      if (updatedDog != null && mounted) {
        if (kDebugMode) {
          print('DogCard - Updated dog returned from dialog: ${updatedDog.name}, ID: ${updatedDog.id}');
        }
        setState(() {});
      }
    } catch (e) {
      if (kDebugMode) {
        print('DogCard - Error in showDialog for dog: ${widget.dog.name}, ID: ${widget.dog.id}: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isDialogOpen = false;
          if (kDebugMode) {
            print('DogCard - Dialog closed, isEditing: $_isEditing, isDialogOpen: $_isDialogOpen');
          }
        });
      } else {
        _isDialogOpen = false;
        if (kDebugMode) {
          print('DogCard - Widget not mounted, isDialogOpen reset to: $_isDialogOpen');
        }
      }
    }
  }

  Future<void> _sendDislikeNotification() async {
  if (!mounted) return;
  try {
    final appState = Provider.of<AppState>(context, listen: false);
    final userId = widget.currentUserId ?? 'default_user';
    final dogId = widget.dog.id;
    final dogOwnerId = widget.dog.ownerId;
    
    if (dogOwnerId == null || dogOwnerId.isEmpty) {
      if (kDebugMode) {
        print('DogCard - Error: No valid ownerId for dog ${widget.dog.name}, ID: $dogId');
      }
      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            localizations.errorNoOwnerFound,
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    final dislikeKey = 'dislike_$dogId';
    final likes = Map<String, List<String>>.from(appState.likesNotifier.value);
    final userLikes = List<String>.from(likes[userId] ?? []);
    bool wasDisliked = userLikes.contains(dislikeKey);

    if (wasDisliked) {
      userLikes.remove(dislikeKey);
      if (kDebugMode) {
        print('DogCard - Removed dislike for ${widget.dog.name}, ID: $dogId');
      }
    } else {
      userLikes.add(dislikeKey);
      if (kDebugMode) {
        print('DogCard - Added dislike for ${widget.dog.name}, ID: $dogId');
      }
    }
    likes[userId] = userLikes;
    appState.likesNotifier.value = likes;

    final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'europe-west3')
        .httpsCallable('sendDislikeNotification');
    final result = await callable.call({
      'dogId': dogId,
      'userId': userId,
    });

    if (result.data['success'] == true) {
      if (kDebugMode) {
        print('DogCard - Dislike notification sent successfully for ${widget.dog.name}, ID: $dogId');
      }
      if (mounted) {
        final message = wasDisliked
            ? localizations.removedDislike(widget.dog.name)
            : localizations.addedDislike(widget.dog.name);
        _scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    } else {
      if (kDebugMode) {
        print('DogCard - Dislike notification failed: ${result.data['message']}');
      }
      if (mounted) {
        _scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              localizations.errorSendingDislike(result.data['message']),
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
    _updateLikesAndFavorites();
  } catch (e) {
    if (kDebugMode) {
      print('DogCard - Error sending dislike notification for ${widget.dog.name}, ID: ${widget.dog.id}: $e');
    }
    if (mounted) {
      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            localizations.errorSendingDislike(e.toString()),
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }
  }
}

  Future<void> _sendLikeNotification() async {
    if (!mounted) return;
    try {
      final notificationService = NotificationService();
      final currentUserName = Provider.of<AppState>(context, listen: false).currentUserName ?? 'Unknown';
      await notificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: localizations.newLikeTitle,
        body: localizations.newLikeBody(currentUserName, widget.dog.name),
        likerUserId: widget.currentUserId ?? 'unknown',
        payload: jsonEncode({
          'type': 'like',
          'likerUserId': widget.currentUserId,
          'dogId': widget.dog.id,
        }),
      );
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientUserId': widget.dog.ownerId,
        'timestamp': FieldValue.serverTimestamp(),
        'title': localizations.newLikeTitle,
        'body': localizations.newLikeBody(currentUserName, widget.dog.name),
        'payload': jsonEncode({
          'type': 'like',
          'likerUserId': widget.currentUserId,
          'dogId': widget.dog.id,
        }),
        'isRead': false,
      });
      if (kDebugMode) {
        print('DogCard - Like notification sent successfully for ${widget.dog.name}, ID: ${widget.dog.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DogCard - Error sending like notification for ${widget.dog.name}, ID: ${widget.dog.id}: $e');
      }
      if (mounted) {
        _scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text(
                  localizations.errorSendingDislike(e.toString()), // استفاده از رشته عمومی برای خطا
                  style: GoogleFonts.poppins())),
        );
      }
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('DogCard - Disposing for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
    }
    if (_isEditing) {
      _isDialogOpen = false;
      if (kDebugMode) {
        print('DogCard - Reset isDialogOpen on dispose: $_isDialogOpen');
      }
    }
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('DogCard - Building UI for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
    }
    bool canEdit = widget.dog.ownerId == widget.currentUserId;
    bool isOwnerDog = widget.dog.ownerId == widget.currentUserId;
    List<Color> gradientColors;
    if (widget.dog.isAvailableForAdoption) {
      gradientColors = const [Colors.pink, Colors.pinkAccent];
    } else if (widget.dog.healthStatus == 'Needs Care' || widget.dog.healthStatus == 'Under Treatment') {
      gradientColors = const [Color.fromARGB(255, 195, 146, 204), Colors.purpleAccent];
    } else {
      gradientColors = const [Colors.pink, Colors.pinkAccent];
    }
    final appState = Provider.of<AppState>(context, listen: false);
    final isLiked = appState.likesNotifier.value[appState.currentUserId]?.contains(widget.dog.id) ?? false;

    return RepaintBoundary(
      child: SafeArea(
        child: Card(
          elevation: 4,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: InkWell(
            onTap: !isOwnerDog && mounted
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OtherUserDogPage(
                          targetUserId: widget.dog.ownerId!,
                          dogsList: widget.allDogs,
                          favoriteDogs: widget.favoriteDogs,
                          onToggleFavorite: widget.onToggleFavorite ?? (dog) {},
                        ),
                      ),
                    );
                  }
                : null,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              ),
              child: ExpansionTile(
                key: ValueKey(widget.dog.id),
                clipBehavior: Clip.hardEdge,
                leading: RepaintBoundary(
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: widget.dog.imagePaths.isNotEmpty
                        ? _buildDogImage(widget.dog.imagePaths[0])
                        : const Image(
                            image: AssetImage('assets/image/default_dog.png'),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.dog.name,
                            style: GoogleFonts.dancingScript(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (canEdit) ...[
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: _isEditing || _isDialogOpen ? null : () => _openEditDialog(context),
                            tooltip: localizations.viewEditDogDetails,
                          ),
                        ],
                        if (!isOwnerDog)
                          IconButton(
                            icon: Icon(
                              _isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              if (kDebugMode) {
                                print('DogCard - Toggling favorite for ${widget.dog.name}, ID: ${widget.dog.id}, isFavorite: $_isFavorite');
                              }
                              try {
                                if (widget.onToggleFavorite != null) {
                                  widget.onToggleFavorite!(widget.dog);
                                } else {
                                  await Provider.of<AppState>(context, listen: false).toggleFavorite(widget.dog);
                                }
                                _updateLikesAndFavorites();
                                if (mounted) {
                                  final message = _isFavorite
                                      ? localizations.removedFromFavorites(widget.dog.name)
                                      : localizations.addedToFavorites(widget.dog.name);
                                  if (kDebugMode) {
                                    print('DogCard - SnackBar message for favorite: $message');
                                  }
                                  _scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        message,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                  );
                                  if (!_isFavorite) {
                                    final notificationService = NotificationService();
                                    final currentUserName = Provider.of<AppState>(context, listen: false).currentUserName ?? 'Unknown';
                                    await notificationService.showNotification(
                                      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                                      title: localizations.newFavoriteTitle,
                                      body: localizations.newFavoriteBody(currentUserName, widget.dog.name),
                                      likerUserId: widget.currentUserId ?? 'unknown',
                                      payload: jsonEncode({
                                        'type': 'favorite',
                                        'likerUserId': widget.currentUserId,
                                      }),
                                    );
                                    await FirebaseFirestore.instance.collection('notifications').add({
                                      'recipientUserId': widget.dog.ownerId,
                                      'timestamp': FieldValue.serverTimestamp(),
                                      'title': localizations.newFavoriteTitle,
                                      'body': localizations.newFavoriteBody(currentUserName, widget.dog.name),
                                      'payload': jsonEncode({
                                        'type': 'favorite',
                                        'likerUserId': widget.currentUserId,
                                      }),
                                      'isRead': false,
                                    });
                                  }
                                }
                              } catch (e) {
                                if (kDebugMode) {
                                  print('DogCard - Error toggling favorite for ${widget.dog.name}, ID: ${widget.dog.id}: $e');
                                }
                                if (mounted) {
                                  _scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        localizations.errorTogglingFavorite(e.toString()),
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            tooltip: localizations.addToFavorites,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      children: [
                        if (widget.dog.isAvailableForAdoption)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                            ),
                            child: Text(
                              localizations.forAdoption,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Text(
                            translateHealthStatus(widget.dog.healthStatus),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Text(
                            widget.dog.isNeutered ? localizations.neutered : localizations.notNeutered,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isOwnerDog && widget.likers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        localizations.likedBy(
                          widget.likers
                              .map((liker) => liker['username']?.toString() ?? 'Unknown')
                              .join(', '),
                        ),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Wrap(
                        spacing: 8.0,
                        children: widget.likers.map((liker) {
                          final likerName = liker['username']?.toString() ?? 'Unknown';
                          if (kDebugMode) {
                            print('DogCard - Displaying liker: $likerName for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
                          }
                          return Chip(
                            label: Text(
                              likerName,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                            backgroundColor: Colors.pinkAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          );
                        }).toList(),
                      ),
                    ],
                    if (!isOwnerDog && widget.showDogSelection && _userDogs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        localizations.pleaseSelectDogForPlaydate,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                      ),
                      DropdownButton<String>(
                        value: _selectedId,
                        hint: Text(
                          localizations.selectYourDog,
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                        onChanged: (value) {
                          Provider.of<AppState>(context, listen: false).setSelectedRequesterDogId(value);
                          widget.onRequesterDogChanged?.call(value);
                          if (kDebugMode) {
                            print('DogCard - Selected dog ID: $value');
                          }
                          setState(() {});
                        },
                        items: _userDogs
                            .map((dog) => DropdownMenuItem<String>(
                                  value: dog.id,
                                  child: Text(
                                    dog.name,
                                    style: GoogleFonts.poppins(),
                                  ),
                                ))
                            .toList(),
                        dropdownColor: Colors.pinkAccent,
                        style: GoogleFonts.poppins(color: Colors.white),
                        iconEnabledColor: Colors.white,
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  '🎂 ${widget.dog.age} ${localizations.years} • ${translateBreed(widget.dog.breed)}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white70, Colors.white30],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        widget.dog.imagePaths.isNotEmpty
                            ? _buildExpandedDogImage(widget.dog.imagePaths[0])
                            : const Image(
                                image: AssetImage('assets/image/default_dog.png'),
                                width: double.infinity,
                                height: 150,
                                fit: BoxFit.cover,
                              ),
                        const SizedBox(height: 12),
                        Text(
                          '${localizations.breed}: ${translateBreed(widget.dog.breed)}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${localizations.gender}: ${translateGender(widget.dog.gender)}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${localizations.healthStatus}: ${translateHealthStatus(widget.dog.healthStatus)}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${localizations.neuteredStatus}: ${widget.dog.isNeutered ? localizations.yes : localizations.no}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizations.traits,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              widget.dog.traits.isNotEmpty
                                  ? Wrap(
                                      spacing: 8.0,
                                      children: widget.dog.traits
                                          .where((trait) => trait.isNotEmpty)
                                          .map(
                                            (trait) => Chip(
                                              label: Text(
                                                translateTrait(trait),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              backgroundColor: Colors.pinkAccent,
                                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                            ),
                                          )
                                          .toList(),
                                    )
                                  : Text(
                                      localizations.noTraits,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white30, Colors.white30],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (!isOwnerDog) ...[
                                Column(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isLiked ? Icons.thumb_up : Icons.thumb_up_off_alt,
                                        color: Colors.white,
                                      ),
                                      onPressed: () async {
                                        if (kDebugMode) {
                                          print('DogCard - Toggling like for ${widget.dog.name}, ID: ${widget.dog.id}, isLiked: $isLiked');
                                        }
                                        try {
                                          await appState.toggleLike(widget.currentUserId ?? '', widget.dog, context);
                                          _updateLikesAndFavorites();
                                          if (mounted) {
                                            final message = isLiked
                                                ? localizations.removedLike(widget.dog.name)
                                                : localizations.addedLike(widget.dog.name);
                                            if (kDebugMode) {
                                              print('DogCard - SnackBar message for like: $message');
                                            }
                                            _scaffoldMessenger.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  message,
                                                  style: GoogleFonts.poppins(),
                                                ),
                                              ),
                                            );
                                            if (!isLiked) {
                                              await _sendLikeNotification();
                                            }
                                          }
                                        } catch (e) {
                                          if (kDebugMode) {
                                            print('DogCard - Error toggling like for ${widget.dog.name}, ID: ${widget.dog.id}: $e');
                                          }
                                          if (mounted) {
                                            _scaffoldMessenger.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  localizations.errorTogglingLike(e.toString()),
                                                  style: GoogleFonts.poppins(),
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      tooltip: isLiked ? localizations.removeLike : localizations.addLike,
                                    ),
                                    Text(
                                      '${localizations.likes}: ${_likeCount}',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: Icon(
                                    _isDisliked ? Icons.thumb_down : Icons.thumb_down_off_alt,
                                    color: Colors.white,
                                  ),
                                  onPressed: () async {
                                    if (mounted) {
                                      try {
                                        await _sendDislikeNotification();
                                      } catch (e) {
                                        if (kDebugMode) {
                                          print('DogCard - Error toggling dislike for ${widget.dog.name}, ID: ${widget.dog.id}: $e');
                                        }
                                        if (mounted) {
                                          _scaffoldMessenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                localizations.errorTogglingDislike(e.toString()),
                                                style: GoogleFonts.poppins(),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  tooltip: _isDisliked ? localizations.removeDislike : localizations.dislike,
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.calendar_today,
                                    color: _sending ? Colors.grey : Colors.white,
                                  ),
                                  onPressed: () => _schedulePlaydate(context),
                                  tooltip: _sending ? localizations.sending : localizations.schedulePlayDate,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat, color: Colors.white),
                                  onPressed: () {
                                    if (mounted) {
                                      _scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            localizations.chatWithOwner(widget.dog.name),
                                            style: GoogleFonts.poppins(),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  tooltip: localizations.chat,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isOwnerDog && widget.dog.isAvailableForAdoption && widget.onAdopt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.pets, color: Colors.white),
                                  onPressed: widget.onAdopt,
                                  tooltip: localizations.adoptDog,
                                ),
                              ],
                            ),
                          ),
                        if (widget.dog.latitude != null && widget.dog.longitude != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: ValueListenableBuilder<bool>(
                              valueListenable: ValueNotifier(true),
                              builder: (context, showMap, _) {
                                if (!showMap) {
                                  return const SizedBox.shrink();
                                }
                                return SizedBox(
                                  height: 150,
                                  child: GoogleMap(
                                    onMapCreated: (GoogleMapController controller) {
                                      _mapController = controller;
                                      rootBundle.loadString('assets/map_style.json').then((style) {
                                        _mapController?.setMapStyle(style);
                                        if (kDebugMode) {
                                          print('DogCard - Applied map style for dog: ${widget.dog.name}');
                                        }
                                      }).catchError((e) {
                                        if (kDebugMode) {
                                          print('DogCard - Error applying map style: $e');
                                        }
                                      });
                                    },
                                    initialCameraPosition: CameraPosition(
                                      target: LatLng(widget.dog.latitude!, widget.dog.longitude!),
                                      zoom: 12.0,
                                    ),
                                    markers: {
                                      Marker(
                                        markerId: MarkerId(widget.dog.id),
                                        position: LatLng(widget.dog.latitude!, widget.dog.longitude!),
                                        infoWindow: InfoWindow(title: widget.dog.name),
                                      ),
                                    },
                                    myLocationEnabled: false,
                                    myLocationButtonEnabled: false,
                                    zoomControlsEnabled: true,
                                    zoomGesturesEnabled: true,
                                    scrollGesturesEnabled: true,
                                    tiltGesturesEnabled: false,
                                    rotateGesturesEnabled: false,
                                    buildingsEnabled: false,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
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
}

Future<void> _getCurrentPositionIsolate(List<dynamic> args) async {
  final SendPort sendPort = args[0] as SendPort;
  final RootIsolateToken? token = args[1] as RootIsolateToken?;
  try {
    if (token != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(token);
      if (kDebugMode) {
        print('DogCard - Initialized BackgroundIsolateBinaryMessenger in Isolate');
      }
    } else {
      if (kDebugMode) {
        print('DogCard - RootIsolateToken is null in Isolate, cannot initialize BackgroundIsolateBinaryMessenger');
      }
      sendPort.send({'latitude': null, 'longitude': null});
      return;
    }
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 10),
    );
    sendPort.send({'latitude': position.latitude, 'longitude': position.longitude});
  } catch (e) {
    if (kDebugMode) {
      print('DogCard - Error getting current position in Isolate: $e');
    }
    sendPort.send({'latitude': null, 'longitude': null});
  }
}
