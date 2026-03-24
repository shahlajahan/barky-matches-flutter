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
import 'package:barky_matches_fixed/auth_page.dart';


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
  final List<String> _healthStatuses = ['Healthy', 'Needs Attention', 'Under Treatment'];
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
      'پر انرژی': l10n.traitEnergetic ?? 'Energetic',
      'دوستانه': l10n.traitFriendly ?? 'Friendly',
      'خوب با بچه‌ها': l10n.traitGoodWithKids ?? 'Good with kids',
    };
    final lowerTrait = traitKey.toLowerCase().trim();
    if (kDebugMode) {
      print('AddDogPage - Trait exact: "$traitKey" -> lower: "$lowerTrait"');
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
      case 'traitTrained':
        return l10n.traitTrained ?? 'Trained';
      case 'traitSocial':
        return l10n.traitSocial ?? 'Social';
      case 'traitGoodWithKids':
        return l10n.traitGoodWithKids ?? 'Good with kids';
      default:
        if (kDebugMode) {
          print('AddDogPage - No match for trait: "$traitKey"');
        }
        return traitKey;
    }
  }

  String translateGender(String gender) {
    final l10n = AppLocalizations.of(context)!;
    if (gender.isEmpty) {
      return l10n.unknownGender ?? 'Unknown Gender';
    }
    final lowerGender = gender.toLowerCase().trim();
    if (kDebugMode) {
      print('AddDogPage - Gender exact: "$gender" -> lower: "$lowerGender"');
    }
    final maleFa = (l10n.genderMale ?? 'male').toLowerCase();
    final femaleFa = (l10n.genderFemale ?? 'female').toLowerCase();
    if (lowerGender == maleFa || lowerGender == 'نر' || lowerGender == 'male') {
      return l10n.genderMale ?? 'Male';
    }
    if (lowerGender == femaleFa || lowerGender == 'ماده' || lowerGender == 'female') {
      return l10n.genderFemale ?? 'Female';
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
      print('AddDogPage - Health Status exact: "$status" -> lower: "$lowerStatus"');
    }
    final healthyFa = (l10n.healthHealthy ?? 'healthy').toLowerCase();
    final needsFa = (l10n.healthNeedsCare ?? 'needs care').toLowerCase();
    final underFa = (l10n.healthUnderTreatment ?? 'under treatment').toLowerCase();
    if (lowerStatus == healthyFa || lowerStatus == 'سالم' || lowerStatus == 'healthy') {
      return l10n.healthHealthy ?? 'Healthy';
    }
    if (lowerStatus == needsFa || lowerStatus == 'نیاز به مراقبت' || lowerStatus == 'needs care' || lowerStatus == 'needs attention') {
      return l10n.healthNeedsCare ?? 'Needs Care';
    }
    if (lowerStatus == underFa || lowerStatus == 'در حال درمان' || lowerStatus == 'under treatment') {
      return l10n.healthUnderTreatment ?? 'Under Treatment';
    }
    if (kDebugMode) {
      print('AddDogPage - No match for health status: "$lowerStatus"');
    }
    return status;
  }

  Future<void> _checkUserAndGetLocation() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    print("AddDogPage - No user logged in");
    return;
  }

  await _getCurrentLocation();
}
  Future<void> _getCurrentLocation() async {
    final l10n = AppLocalizations.of(context)!;
    print('AddDogPage - Attempting to get current location');
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('AddDogPage - Location services are disabled');
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
          print('AddDogPage - Location permission denied');
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
        print('AddDogPage - Location permission permanently denied');
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
          print('AddDogPage - Location acquired: Latitude: $_latitude, Longitude: $_longitude');
        });
      }
    } catch (e) {
      print('AddDogPage - Error getting location: $e');
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
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFiles.add(pickedFile);
        print('AddDogPage - Added image file: ${pickedFile.path}');
      });
    } else {
      print('AddDogPage - No image picked');
    }
  }

  Future<List<String>> _uploadImages(String dogId) async {
  List<String> urls = [];

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('AddDogPage - Upload failed: user not logged in');
    return urls;
  }

  final userId = user.uid;

  for (var imageFile in _imageFiles) {
    try {
      final file = File(imageFile.path);

      final fileName = DateTime.now().millisecondsSinceEpoch.toString();

      final ref = FirebaseStorage.instance
          .ref()
          .child('dog_images/$userId/$dogId/$fileName.jpg');

      print("AddDogPage - Uploading image to ${ref.fullPath}");

      await ref.putFile(file);

      final url = await ref.getDownloadURL();

      urls.add(url);

      print("AddDogPage - Uploaded image URL: $url");

    } catch (e) {
      print('AddDogPage - Error uploading image: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)
                      ?.errorUploadingImage(e.toString()) ??
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
    print('AddDogPage - Add Dog button pressed');
    print('AddDogPage - Validating form...');
    print('AddDogPage - Name: ${_nameController.text}');
    print('AddDogPage - Breed: $_selectedBreed');
    print('AddDogPage - Age: ${_ageController.text}');
    print('AddDogPage - Gender: $_selectedGender');
    print('AddDogPage - Health Status: $_selectedHealthStatus');
    print('AddDogPage - Neutered: $_isNeutered');
    print('AddDogPage - Traits: $_selectedTraits');
    print('AddDogPage - Owner Gender: $_selectedOwnerGender');
    print('AddDogPage - Description: ${_descriptionController.text}');
    print('AddDogPage - Available for Adoption: $_isAvailableForAdoption');
    print('AddDogPage - Latitude: $_latitude, Longitude: $_longitude');

    if (_isLoading) {
      print('AddDogPage - Already submitting, ignoring additional presses');
      return;
    }

    if (_formKey.currentState!.validate()) {
      print('AddDogPage - Form validation passed for required fields');
      if (_isNeutered == null) {
        print('AddDogPage - Validation failed: Neutered not specified');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSpecifyNeutered)),
          );
        }
        return;
      }

      if (_selectedTraits.isEmpty) {
        print('AddDogPage - Validation failed: No traits selected');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectAtLeastOneTrait)),
          );
        }
        return;
      }

      if (_latitude == null || _longitude == null) {
        print('AddDogPage - Validation failed: Location not acquired');
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
          print('AddDogPage - Retry failed: Location still not acquired');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.locationNotAcquired)),
            );
          }
          return;
        }
      }

      print('AddDogPage - All validations passed, proceeding to save dog');
      setState(() {
        _isLoading = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
  print('AddDogPage - No user logged in');

  if (mounted) {
    print("AddDogPage - User lost session");
  }

  return;
}
        final userId = user.uid;
        print('AddDogPage - Current userId: $userId');

        final dogId = FirebaseFirestore.instance.collection('dogs').doc().id;
        print('AddDogPage - Generated dogId: $dogId');

        final dogsBox = Hive.box<Dog>('dogsBox');
        final doc = await FirebaseFirestore.instance.collection('dogs').doc(dogId).get();
        if (doc.exists) {
          print('AddDogPage - Validation failed: A dog with this ID already exists');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.dogNameExists(_nameController.text)),
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
        );

        print('AddDogPage - Saving dog to Hive: dogId=$dogId, ownerId=$userId');
        await dogsBox.put(dogId, newDog);
        print('AddDogPage - Dog added to Hive: ${newDog.name}, ID: $dogId');

        await FirebaseFirestore.instance.collection('dogs').doc(dogId).set({
          'id': dogId,
          'name': newDog.name,
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

          // 🔐 Trust & Safety fields
  'reportCount': 0,
  'isHidden': false,
  'moderationStatus': 'active',
        });
        print('AddDogPage - Dog added to Firestore: ${newDog.name}, dogId=$dogId');

        widget.onDogAdded?.call(newDog);

        print('AddDogPage - Navigating back...');
        if (mounted) {
          Navigator.pop(context, true);
        }
        print('AddDogPage - Navigation completed');
      } catch (e) {
        print('AddDogPage - Error adding dog: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorAddingDog(e.toString()))),
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
      print('AddDogPage - Form validation failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.pleaseFillRequiredFields)),
        );
      }
    }
  }

  Widget _buildRetryLocationButton() {
    return ElevatedButton(
      onPressed: _getCurrentLocation,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.pink,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        AppLocalizations.of(context)!.retryLocation ?? 'Retry Location',
        style: GoogleFonts.poppins(
          color: Colors.pink,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  void dispose() {
    print('AddDogPage - Disposing controllers');
    _nameController.dispose();
    _ageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('AddDogPage - Building UI');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.addYourDog ?? 'Add Your Dog',
          style: GoogleFonts.dancingScript(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.pink[400],
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
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
                        label: AppLocalizations.of(context)?.nameLabel ?? 'Name *',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            print('AddDogPage - Validation failed: Name is empty');
                            return AppLocalizations.of(context)?.pleaseEnterDogName ?? 'Please enter your dog\'s name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        value: _selectedBreed,
                        hint: AppLocalizations.of(context)?.selectBreedHint ?? 'Select Breed',
                        items: getDogBreeds(context),
                        onChanged: (value) {
                          setState(() {
                            _selectedBreed = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            print('AddDogPage - Validation failed: Breed not selected');
                            return AppLocalizations.of(context)?.pleaseSelectBreed ?? 'Please select a breed';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _ageController,
                        label: AppLocalizations.of(context)?.ageLabel ?? 'Age *',
                        icon: const Icon(Icons.cake, color: Colors.white),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            print('AddDogPage - Validation failed: Age is empty');
                            return AppLocalizations.of(context)?.pleaseEnterDogAge ?? 'Please enter your dog\'s age';
                          }
                          if (int.tryParse(value) == null || int.parse(value) <= 0) {
                            print('AddDogPage - Validation failed: Age is invalid');
                            return AppLocalizations.of(context)?.pleaseEnterValidAge ?? 'Please enter a valid age';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        value: _selectedGender,
                        hint: AppLocalizations.of(context)?.selectGenderHint ?? 'Select Gender',
                        items: _genders,
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            print('AddDogPage - Validation failed: Gender not selected');
                            return AppLocalizations.of(context)?.pleaseSelectGender ?? 'Please select a gender';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        value: _selectedHealthStatus,
                        hint: AppLocalizations.of(context)?.selectHealthStatusHint ?? 'Select Health Status',
                        items: _healthStatuses,
                        onChanged: (value) {
                          setState(() {
                            _selectedHealthStatus = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            print('AddDogPage - Validation failed: Health Status not selected');
                            return AppLocalizations.of(context)?.pleaseSelectHealthStatus ?? 'Please select a health status';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildNeuteredField(),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _descriptionController,
                        label: AppLocalizations.of(context)?.descriptionLabel ?? 'Description',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      _buildTraitsField(),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        value: _selectedOwnerGender,
                        hint: AppLocalizations.of(context)?.selectOwnerGenderHint ?? 'Owner Gender',
                        items: _ownerGenders,
                        onChanged: (value) {
                          setState(() {
                            _selectedOwnerGender = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            print('AddDogPage - Validation failed: Owner Gender not selected');
                            return AppLocalizations.of(context)?.pleaseSelectOwnerGender ?? 'Please select your gender';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildImagePickerField(),
                      const SizedBox(height: 16),
                      _buildAdoptionCheckbox(),
                      const SizedBox(height: 16),
                      _buildRetryLocationButton(),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.pink,
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
                                AppLocalizations.of(context)?.addDogButton ?? 'Add Dog',
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
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.pink,
                  ),
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
    Icon? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
        prefixIcon: icon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(
        hint,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: Colors.pinkAccent,
      style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
      iconEnabledColor: Colors.white,
      menuMaxHeight: 300,
      isExpanded: true,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: GoogleFonts.poppins(),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildNeuteredField() {
    return Row(
      children: [
        Text(
          AppLocalizations.of(context)?.neuteredLabel ?? 'Neutered *',
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
              AppLocalizations.of(context)?.yes ?? 'Yes',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
              ),
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
              AppLocalizations.of(context)?.no ?? 'No',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
              ),
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
          AppLocalizations.of(context)?.traitsLabel ?? 'Traits *',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: _traitKeys.map((traitKey) {
            final isSelected = _selectedTraits.contains(traitKey);
            return FilterChip(
              label: Text(
                translateTrait(traitKey),
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTraits.add(traitKey);
                    print('AddDogPage - Trait added: $traitKey');
                  } else {
                    _selectedTraits.remove(traitKey);
                    print('AddDogPage - Trait removed: $traitKey');
                  }
                });
              },
              selectedColor: Colors.pinkAccent,
              backgroundColor: Colors.white.withOpacity(0.2),
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
          AppLocalizations.of(context)?.uploadImagesLabel ?? 'Upload Images',
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
              child: Text(AppLocalizations.of(context)?.pickFromGallery ?? 'Pick from Gallery'),
            ),
            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.camera),
              child: Text(AppLocalizations.of(context)?.takePhoto ?? 'Take a Photo'),
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
                future: File(imageFile.path).exists().then((exists) => exists ? File(imageFile.path) : null),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError || snapshot.data == null) {
                    print('AddDogPage - Error loading image: ${snapshot.error} or file does not exist');
                    return const Icon(Icons.error, color: Colors.red);
                  }
                  return Image.file(
                    snapshot.data!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('AddDogPage - Image error: $error');
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
          AppLocalizations.of(context)?.availableForAdoption ?? 'Available for Adoption',
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