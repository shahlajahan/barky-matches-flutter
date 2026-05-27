import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';

class AddDogPage extends StatefulWidget {
  final Function(Dog)? onDogAdded;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;

  const AddDogPage({
    super.key,
    required this.onDogAdded,
    required this.favoriteDogs,
    required this.onToggleFavorite,
  });

  @override
  _AddDogPageState createState() => _AddDogPageState();
}

class _AddDogPageState extends State<AddDogPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedBreed;
  String _selectedPetType = 'dog';
  final _ageController = TextEditingController();
  String? _selectedGender;
  String? _selectedHealthStatus;
  bool? _isNeutered;
  final _descriptionController = TextEditingController();
  final List<String> _selectedTraits = [];
  String? _selectedOwnerGender;
  bool _isAvailableForAdoption = false;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  List<String> _imageUrls = [];
  final List<XFile> _imageFiles = [];

  final List<String> _genders = ['Male', 'Female'];
  final List<String> _healthStatuses = [
    'Healthy',
    'Needs Attention',
    'Under Treatment',
  ];
  final List<String> _ownerGenders = ['Male', 'Female', 'Other'];
  final List<String> _traitKeys = [
    'traitEnergetic',
    'traitPlayful',
    'traitCalm',
    'traitLoyal',
    'traitFriendly',
    'traitProtective',
    'traitIntelligent',
    'traitAffectionate',
    'traitCurious',
    'traitIndependent',
    'traitShy',
    'traitTrained',
    'traitSocial',
    'traitGoodWithKids',
  ];

  bool _didInitLocation = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didInitLocation) {
      _didInitLocation = true;
      _checkUserAndGetLocation();
    }
  }

  String translateTrait(String traitKey) {
    final l10n = AppLocalizations.of(context)!;
    if (traitKey.isEmpty) {
      return l10n.unknownTrait;
    }
    final rawToLocalized = {
      'energetic': l10n.traitEnergetic,
      'playful': l10n.traitPlayful,
      'calm': l10n.traitCalm,
      'loyal': l10n.traitLoyal,
      'friendly': l10n.traitFriendly,
      'protective': l10n.traitProtective,
      'intelligent': l10n.traitIntelligent,
      'affectionate': l10n.traitAffectionate,
      'curious': l10n.traitCurious,
      'independent': l10n.traitIndependent,
      'shy': l10n.traitShy,
      'trained': l10n.traitTrained,
      'social': l10n.traitSocial,
      'good with kids': l10n.traitGoodWithKids,
      'پر انرژی': l10n.traitEnergetic,
      'دوستانه': l10n.traitFriendly,
      'خوب با بچه‌ها': l10n.traitGoodWithKids,
    };
    final lowerTrait = traitKey.toLowerCase().trim();
    if (kDebugMode) {
      debugPrint(
        'AddDogPage - Trait exact: "$traitKey" -> lower: "$lowerTrait"',
      );
    }
    if (rawToLocalized.containsKey(lowerTrait)) {
      return rawToLocalized[lowerTrait]!;
    }
    switch (traitKey) {
      case 'traitEnergetic':
        return l10n.traitEnergetic;
      case 'traitPlayful':
        return l10n.traitPlayful;
      case 'traitCalm':
        return l10n.traitCalm;
      case 'traitLoyal':
        return l10n.traitLoyal;
      case 'traitFriendly':
        return l10n.traitFriendly;
      case 'traitProtective':
        return l10n.traitProtective;
      case 'traitIntelligent':
        return l10n.traitIntelligent;
      case 'traitAffectionate':
        return l10n.traitAffectionate;
      case 'traitCurious':
        return l10n.traitCurious;
      case 'traitIndependent':
        return l10n.traitIndependent;
      case 'traitShy':
        return l10n.traitShy;
      case 'traitTrained':
        return l10n.traitTrained;
      case 'traitSocial':
        return l10n.traitSocial;
      case 'traitGoodWithKids':
        return l10n.traitGoodWithKids;
      default:
        if (kDebugMode) {
          debugPrint('AddDogPage - No match for trait: "$traitKey"');
        }
        return traitKey;
    }
  }

  String translateGender(String gender) {
    final l10n = AppLocalizations.of(context)!;
    if (gender.isEmpty) {
      return l10n.unknownGender;
    }
    final lowerGender = gender.toLowerCase().trim();
    if (kDebugMode) {
      debugPrint(
        'AddDogPage - Gender exact: "$gender" -> lower: "$lowerGender"',
      );
    }
    final maleFa = l10n.genderMale.toLowerCase();
    final femaleFa = l10n.genderFemale.toLowerCase();
    if (lowerGender == maleFa || lowerGender == 'نر' || lowerGender == 'male') {
      return l10n.genderMale;
    }
    if (lowerGender == femaleFa ||
        lowerGender == 'ماده' ||
        lowerGender == 'female') {
      return l10n.genderFemale;
    }
    return gender;
  }

  String translateHealthStatus(String status) {
    final l10n = AppLocalizations.of(context)!;
    if (status.isEmpty) {
      return l10n.unknownStatus;
    }
    final lowerStatus = status.toLowerCase().trim();
    if (kDebugMode) {
      debugPrint(
        'AddDogPage - Health Status exact: "$status" -> lower: "$lowerStatus"',
      );
    }
    final healthyFa = l10n.healthHealthy.toLowerCase();
    final needsFa = l10n.healthNeedsCare.toLowerCase();
    final underFa = l10n.healthUnderTreatment.toLowerCase();
    if (lowerStatus == healthyFa ||
        lowerStatus == 'سالم' ||
        lowerStatus == 'healthy') {
      return l10n.healthHealthy;
    }
    if (lowerStatus == needsFa ||
        lowerStatus == 'نیاز به مراقبت' ||
        lowerStatus == 'needs care' ||
        lowerStatus == 'needs attention') {
      return l10n.healthNeedsCare;
    }
    if (lowerStatus == underFa ||
        lowerStatus == 'در حال درمان' ||
        lowerStatus == 'under treatment') {
      return l10n.healthUnderTreatment;
    }
    if (kDebugMode) {
      debugPrint('AddDogPage - No match for health status: "$lowerStatus"');
    }
    return status;
  }

  String _localizedPetTypeLabel(String petType) {
    final l10n = AppLocalizations.of(context)!;
    switch (petType.toLowerCase().trim()) {
      case 'dog':
        return l10n.petTypeDog;
      case 'cat':
        return l10n.petTypeCat;
      case 'bird':
        return l10n.petTypeBird;
      case 'horse':
        return l10n.petTypeHorse;
      default:
        return petType;
    }
  }

  String _localizedGenderOption(String gender) {
    final l10n = AppLocalizations.of(context)!;
    switch (gender.toLowerCase().trim()) {
      case 'male':
        return l10n.genderMale;
      case 'female':
        return l10n.genderFemale;
      case 'other':
        return l10n.genderOther;
      default:
        return gender;
    }
  }

  String _localizedHealthStatusOption(String status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status.toLowerCase().trim()) {
      case 'healthy':
        return l10n.healthHealthy;
      case 'needs attention':
      case 'needs care':
        return l10n.healthNeedsCare;
      case 'under treatment':
        return l10n.healthUnderTreatment;
      default:
        return status;
    }
  }

  String _localizedBreedLabel(String breed) {
    final l10n = AppLocalizations.of(context)!;
    switch (breed.toLowerCase().trim()) {
      case 'persian':
        return l10n.breedPersian;
      case 'siamese':
        return l10n.breedSiamese;
      case 'maine coon':
        return l10n.breedMaineCoon;
      case 'british shorthair':
        return l10n.breedBritishShorthair;
      case 'parrot':
        return l10n.breedParrot;
      case 'canary':
        return l10n.breedCanary;
      case 'budgerigar':
        return l10n.breedBudgerigar;
      case 'arabian':
        return l10n.breedArabian;
      case 'thoroughbred':
        return l10n.breedThoroughbred;
      case 'mustang':
        return l10n.breedMustang;
      default:
        return breed;
    }
  }

  Future<void> _checkUserAndGetLocation() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint("AddDogPage - No user logged in");
      return;
    }

    await _getCurrentLocation();
    if (!mounted) return;
  }

  Future<void> _getCurrentLocation() async {
    final l10n = AppLocalizations.of(context)!;
    debugPrint('AddDogPage - Attempting to get current location');
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('AddDogPage - Location services are disabled');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.locationServicesDisabled,
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('AddDogPage - Location permission denied');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  l10n.locationPermissionRequired,
                  style: GoogleFonts.poppins(),
                ),
                action: SnackBarAction(
                  label: l10n.settings,
                  onPressed: () async {
                    await openAppSettings();
                  },
                ),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('AddDogPage - Location permission permanently denied');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.locationPermissionPermanentlyDenied,
                style: GoogleFonts.poppins(),
              ),
              action: SnackBarAction(
                label: l10n.settings,
                onPressed: () async {
                  await openAppSettings();
                },
              ),
            ),
          );
        }
        return;
      }

      LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
        timeLimit: Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          debugPrint(
            'AddDogPage - Location acquired: Latitude: $_latitude, Longitude: $_longitude',
          );
        });
      }
    } catch (e) {
      debugPrint('AddDogPage - Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorGettingLocation(e.toString())),
            action: SnackBarAction(
              label: l10n.settings,
              onPressed: () async {
                await openAppSettings();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1400,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFiles.add(pickedFile);
        debugPrint('AddDogPage - Added image file: ${pickedFile.path}');
      });
    } else {
      debugPrint('AddDogPage - No image picked');
    }
  }

  Future<List<String>> _uploadImages(String dogId) async {
    List<String> urls = [];

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('AddDogPage - Upload failed: user not logged in');
      return urls;
    }

    final userId = user.uid;

    for (var imageFile in _imageFiles) {
      try {
        final file = File(imageFile.path);

        final fileName = DateTime.now().millisecondsSinceEpoch.toString();

        final ref = FirebaseStorage.instance.ref().child(
          'dog_images/$userId/$dogId/$fileName.jpg',
        );

        debugPrint("AddDogPage - Uploading image to ${ref.fullPath}");

        await ref.putFile(file);

        final url = await ref.getDownloadURL();

        urls.add(url);

        debugPrint("AddDogPage - Uploaded image URL: $url");
      } catch (e) {
        debugPrint('AddDogPage - Error uploading image: $e');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                      context,
                    )?.errorUploadingImage(e.toString()) ??
                    'Error uploading image: $e',
              ),
            ),
          );
        }
      }
    }

    return urls;
  }

  Future<void> _submit() async {
    debugPrint('AddDogPage - Add Dog button pressed');
    debugPrint('AddDogPage - Validating form...');
    debugPrint('AddDogPage - Name: ${_nameController.text}');
    debugPrint('AddDogPage - Breed: $_selectedBreed');
    debugPrint('AddDogPage - Age: ${_ageController.text}');
    debugPrint('AddDogPage - Gender: $_selectedGender');
    debugPrint('AddDogPage - Health Status: $_selectedHealthStatus');
    debugPrint('AddDogPage - Neutered: $_isNeutered');
    debugPrint('AddDogPage - Traits: $_selectedTraits');
    debugPrint('AddDogPage - Owner Gender: $_selectedOwnerGender');
    debugPrint('AddDogPage - Description: ${_descriptionController.text}');
    debugPrint('AddDogPage - Available for Adoption: $_isAvailableForAdoption');
    debugPrint('AddDogPage - Latitude: $_latitude, Longitude: $_longitude');

    if (_isLoading) {
      debugPrint(
        'AddDogPage - Already submitting, ignoring additional presses',
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      debugPrint('AddDogPage - Form validation passed for required fields');
      if (_isNeutered == null) {
        debugPrint('AddDogPage - Validation failed: Neutered not specified');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.pleaseSpecifyNeutered,
              ),
            ),
          );
        }
        return;
      }

      if (_selectedTraits.isEmpty) {
        debugPrint('AddDogPage - Validation failed: No traits selected');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.pleaseSelectAtLeastOneTrait,
              ),
            ),
          );
        }
        return;
      }

      if (_latitude == null || _longitude == null) {
        debugPrint('AddDogPage - Validation failed: Location not acquired');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.locationRequired),
              action: SnackBarAction(
                label: AppLocalizations.of(context)!.settings,
                onPressed: () async {
                  await openAppSettings();
                },
              ),
            ),
          );
        }
        await _getCurrentLocation(); // Retry getting location
        if (_latitude == null || _longitude == null) {
          debugPrint('AddDogPage - Retry failed: Location still not acquired');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.locationNotAcquired,
                ),
              ),
            );
          }
          return;
        }
      }

      debugPrint('AddDogPage - All validations passed, proceeding to save dog');
      setState(() {
        _isLoading = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          debugPrint('AddDogPage - No user logged in');

          if (mounted) {
            debugPrint("AddDogPage - User lost session");
          }

          return;
        }
        final userId = user.uid;
        debugPrint('AddDogPage - Current userId: $userId');

        final dogId = FirebaseFirestore.instance.collection('dogs').doc().id;
        debugPrint('AddDogPage - Generated dogId: $dogId');

        final dogsBox = Hive.box<Dog>('dogsBox');
        final doc = await FirebaseFirestore.instance
            .collection('dogs')
            .doc(dogId)
            .get();
        if (doc.exists) {
          debugPrint(
            'AddDogPage - Validation failed: A dog with this ID already exists',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(
                    context,
                  )!.dogNameAlreadyExists(_nameController.text),
                ),
              ),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }

        if (_imageFiles.isNotEmpty) {
          _imageUrls = await _uploadImages(dogId);
        }

        final newDog = Dog(
          id: dogId,
          name: _nameController.text,
          breed: _selectedBreed!,
          age: int.parse(_ageController.text),
          gender: _selectedGender!,
          healthStatus: _selectedHealthStatus!,
          isNeutered: _isNeutered!,
          description: _descriptionController.text,
          traits: _selectedTraits,
          ownerGender: _selectedOwnerGender!,
          imagePaths: _imageUrls,
          isAvailableForAdoption: _isAvailableForAdoption,
          isOwner: true,
          ownerId: userId,
          latitude: _latitude!,
          longitude: _longitude!,
          petType: _selectedPetType,
        );

        debugPrint(
          'AddDogPage - Saving dog to Hive: dogId=$dogId, ownerId=$userId',
        );
        await dogsBox.put(dogId, newDog);
        debugPrint(
          'AddDogPage - Dog added to Hive: ${newDog.name}, ID: $dogId',
        );

        await FirebaseFirestore.instance.collection('dogs').doc(dogId).set({
          'id': dogId,
          'name': newDog.name,
          'petName': newDog.name,
          'breed': newDog.breed,
          'age': newDog.age,
          'gender': newDog.gender,
          'healthStatus': newDog.healthStatus,
          'isNeutered': newDog.isNeutered,
          'description': newDog.description,
          'traits': newDog.traits,
          'ownerGender': newDog.ownerGender,
          'imagePaths': newDog.imagePaths,
          'isAvailableForAdoption': newDog.isAvailableForAdoption,
          'isOwner': newDog.isOwner,
          'ownerId': userId,
          'latitude': newDog.latitude,
          'longitude': newDog.longitude,
          'petType': newDog.petType,

          // 🔐 Trust & Safety fields
          'reportCount': 0,
          'isHidden': false,
          'moderationStatus': 'active',
        });
        debugPrint(
          '🐾 PET NAME SYNC → name=${newDog.name} petName=${newDog.name}',
        );
        debugPrint(
          'AddDogPage - Dog added to Firestore: ${newDog.name}, dogId=$dogId',
        );

        debugPrint('AddDogPage - Redirecting to Home...');

        widget.onDogAdded?.call(newDog);

        FocusScope.of(context).unfocus();

        await Future.delayed(const Duration(milliseconds: 100));

        if (!mounted) return;

        Navigator.pop(context);
        debugPrint('AddDogPage - Navigation completed');
      } catch (e) {
        debugPrint('AddDogPage - Error adding dog: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.errorAddingDog(e.toString()),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      debugPrint('AddDogPage - Form validation failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.pleaseFillRequiredFields,
            ),
          ),
        );
      }
    }
  }

  Widget _buildRetryLocationButton() {
    return ElevatedButton(
      onPressed: _getCurrentLocation,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        AppLocalizations.of(context)!.retryLocation,
        style: GoogleFonts.poppins(
          color: Colors.black, // 🔥 مهم (نه pink)
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('AddDogPage - Disposing controllers');
    _nameController.dispose();
    _ageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.addYourDog,
          style: GoogleFonts.dancingScript(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF9E1B4F),
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        color: const Color(0xFF9E1B4F),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: AppLocalizations.of(context)!.nameLabel,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            debugPrint(
                              'AddDogPage - Validation failed: Name is empty',
                            );
                            return AppLocalizations.of(
                              context,
                            )!.pleaseEnterDogName;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _buildDropdownField(
                        value: _selectedPetType,
                        hint: AppLocalizations.of(context)!.petTypeLabel,
                        items: const ['dog', 'cat', 'bird', 'horse'],
                        displayItemLabel: _localizedPetTypeLabel,
                        onChanged: (value) {
                          setState(() {
                            _selectedPetType = value ?? 'dog';
                            _selectedBreed = null; // reset
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildDropdownField(
                        value: _selectedBreed,
                        hint: AppLocalizations.of(context)!.selectBreedHint,
                        items: getBreedsByPetType(context, _selectedPetType),
                        displayItemLabel: _localizedBreedLabel,
                        onChanged: (value) {
                          setState(() {
                            _selectedBreed = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            debugPrint(
                              'AddDogPage - Validation failed: Breed not selected',
                            );
                            return AppLocalizations.of(
                              context,
                            )!.pleaseSelectBreed;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _ageController,
                        label: AppLocalizations.of(context)!.ageLabel,

                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            debugPrint(
                              'AddDogPage - Validation failed: Age is empty',
                            );
                            return AppLocalizations.of(
                              context,
                            )!.pleaseEnterDogAge;
                          }
                          if (int.tryParse(value) == null ||
                              int.parse(value) <= 0) {
                            debugPrint(
                              'AddDogPage - Validation failed: Age is invalid',
                            );
                            return AppLocalizations.of(
                              context,
                            )!.pleaseEnterValidAge;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildDropdownField(
                        value: _selectedGender,
                        hint: AppLocalizations.of(context)!.selectGenderHint,
                        items: _genders,
                        displayItemLabel: _localizedGenderOption,
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            debugPrint(
                              'AddDogPage - Validation failed: Gender not selected',
                            );
                            return AppLocalizations.of(
                              context,
                            )!.pleaseSelectGender;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildDropdownField(
                        value: _selectedHealthStatus,
                        hint: AppLocalizations.of(
                          context,
                        )!.selectHealthStatusHint,
                        items: _healthStatuses,
                        displayItemLabel: _localizedHealthStatusOption,
                        onChanged: (value) {
                          setState(() {
                            _selectedHealthStatus = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            debugPrint(
                              'AddDogPage - Validation failed: Health Status not selected',
                            );
                            return AppLocalizations.of(
                              context,
                            )!.pleaseSelectHealthStatus;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildNeuteredField(),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _descriptionController,
                        label: AppLocalizations.of(context)!.descriptionLabel,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 14),
                      _buildTraitsField(),
                      const SizedBox(height: 14),
                      _buildDropdownField(
                        value: _selectedOwnerGender,
                        hint: AppLocalizations.of(
                          context,
                        )!.selectOwnerGenderHint,
                        items: _ownerGenders,
                        displayItemLabel: _localizedGenderOption,
                        onChanged: (value) {
                          setState(() {
                            _selectedOwnerGender = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            debugPrint(
                              'AddDogPage - Validation failed: Owner Gender not selected',
                            );
                            return AppLocalizations.of(
                              context,
                            )!.pleaseSelectOwnerGender;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.photosLabel,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),

                          SizedBox(
                            height: 110,
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _pickImage(ImageSource.gallery),
                                  child: Container(
                                    width: 100,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.add,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildAdoptionCheckbox(),
                      const SizedBox(height: 14),
                      _buildRetryLocationButton(),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.pink,
                              )
                            : Text(
                                AppLocalizations.of(context)!.addDogButton,
                                style: GoogleFonts.poppins(
                                  color: Colors.pink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.pink),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hint,
    required List<String> items,
    required String Function(String) displayItemLabel,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(displayItemLabel(item)),
            );
          }).toList(),
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildNeuteredField() {
    return Row(
      children: [
        Text(
          AppLocalizations.of(context)!.neuteredLabel,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: _isNeutered,
              onChanged: (value) {
                setState(() {
                  _isNeutered = value;
                });
              },
              activeColor: Colors.white,
            ),
            Text(
              AppLocalizations.of(context)!.yes,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        Row(
          children: [
            Radio<bool>(
              value: false,
              groupValue: _isNeutered,
              onChanged: (value) {
                setState(() {
                  _isNeutered = value;
                });
              },
              activeColor: Colors.white,
            ),
            Text(
              AppLocalizations.of(context)!.no,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTraitsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.traitsLabel,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _traitKeys.map((trait) {
            final selected = _selectedTraits.contains(trait);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedTraits.remove(trait);
                  } else {
                    _selectedTraits.add(trait);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  translateTrait(trait),
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildImagePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.uploadImagesLabel,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.gallery),
              child: Text(AppLocalizations.of(context)!.pickFromGallery),
            ),
            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.camera),
              child: Text(AppLocalizations.of(context)!.takePhoto),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_imageFiles.isNotEmpty)
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _imageFiles.map((imageFile) {
              return FutureBuilder<File?>(
                future: File(imageFile.path).exists().then(
                  (exists) => exists ? File(imageFile.path) : null,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError || snapshot.data == null) {
                    debugPrint(
                      'AddDogPage - Error loading image: ${snapshot.error} or file does not exist',
                    );
                    return const Icon(Icons.error, color: Colors.red);
                  }
                  return Image.file(
                    snapshot.data!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('AddDogPage - Image error: $error');
                      return const Icon(Icons.error, color: Colors.red);
                    },
                  );
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildAdoptionCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _isAvailableForAdoption,
          onChanged: (value) {
            setState(() {
              _isAvailableForAdoption = value ?? false;
            });
          },
          checkColor: Colors.white,
          activeColor: Colors.pink,
        ),
        Text(
          AppLocalizations.of(context)!.availableForAdoption,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

List<String> getDogBreeds(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return [
    l10n.breedPekingese,
    l10n.breedLabradorRetriever,
    l10n.breedBeagle,
    l10n.breedGermanShepherd,
    l10n.breedGoldenRetriever,
    l10n.breedAfghanHound,
    l10n.breedAiredaleTerrier,
    l10n.breedAkita,
    l10n.breedAlaskanMalamute,
    l10n.breedAmericanBulldog,
    l10n.breedAmericanPitBullTerrier,
    l10n.breedAustralianCattleDog,
    l10n.breedAustralianShepherd,
    l10n.breedBassetHound,
    l10n.breedBelgianMalinois,
    l10n.breedBerneseMountainDog,
    l10n.breedBichonFrise,
    l10n.breedBloodhound,
    l10n.breedBorderCollie,
    l10n.breedBostonTerrier,
    l10n.breedBoxer,
    l10n.breedBulldog,
    l10n.breedBullmastiff,
    l10n.breedCairnTerrier,
    l10n.breedCaneCorso,
    l10n.breedCavalierKingCharlesSpaniel,
    l10n.breedChihuahua,
    l10n.breedChowChow,
    l10n.breedCockerSpaniel,
    l10n.breedCollie,
    l10n.breedDachshund,
    l10n.breedDalmatian,
    l10n.breedDobermanPinscher,
    l10n.breedEnglishSpringerSpaniel,
    l10n.breedFrenchBulldog,
    l10n.breedGreatDane,
    l10n.breedGreatPyrenees,
    l10n.breedHavanese,
    l10n.breedIrishSetter,
    l10n.breedIrishWolfhound,
    l10n.breedJackRussellTerrier,
    l10n.breedLhasaApso,
    l10n.breedMaltese,
    l10n.breedMastiff,
    l10n.breedMiniatureSchnauzer,
    l10n.breedNewfoundland,
    l10n.breedPapillon,
    l10n.breedPomeranian,
    l10n.breedPoodle,
    l10n.breedPug,
    l10n.breedRottweiler,
    l10n.breedSaintBernard,
    l10n.breedSamoyed,
    l10n.breedShetlandSheepdog,
    l10n.breedShihTzu,
    l10n.breedSiberianHusky,
    l10n.breedStaffordshireBullTerrier,
    l10n.breedVizsla,
    l10n.breedWeimaraner,
    l10n.breedWestHighlandWhiteTerrier,
    l10n.breedYorkshireTerrier,
  ];
}

List<String> getBreedsByPetType(BuildContext context, String petType) {
  switch (petType) {
    case 'cat':
      return ['Persian', 'Siamese', 'Maine Coon', 'British Shorthair'];
    case 'bird':
      return ['Parrot', 'Canary', 'Budgerigar'];
    case 'horse':
      return ['Arabian', 'Thoroughbred', 'Mustang'];
    case 'dog':
    default:
      return getDogBreeds(context);
  }
}
