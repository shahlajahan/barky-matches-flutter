import 'package:flutter/material.dart';
import 'dart:io';
import 'dog.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';


class DogDetailsPage extends StatefulWidget {
  final Dog? dog;
  final Function(Dog) onDogAdded;
  final List<Dog> dogsList;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;
  const DogDetailsPage({
    super.key,
    this.dog,
    required this.onDogAdded,
    required this.dogsList,
    required this.favoriteDogs,
    required this.onToggleFavorite,
  });

  @override
  _DogDetailsPageState createState() => _DogDetailsPageState();
}

class _DogDetailsPageState extends State<DogDetailsPage> {
  late TextEditingController nameController;
  late TextEditingController breedController;
  late TextEditingController ageController;
  late TextEditingController descriptionController;
  String? selectedGender;
  String? selectedBreed;
  String? selectedHealth;
  bool isNeutered = false;
  List<String> traits = [];
  String? selectedOwnerGender;
  List<String> imagePaths = [];
  bool isAvailableForAdoption = false;
  late Box<Dog> dogsBox;
  final List<String> breeds = [
    'breedPekingese',
    'breedLabradorRetriever',
    'breedBeagle',
    'breedGermanShepherd',
    'breedGoldenRetriever',
  ];

  @override
  void initState() {
    super.initState();
    dogsBox = Hive.box<Dog>('dogsBox');
    nameController = TextEditingController(text: widget.dog?.name ?? '');
    breedController = TextEditingController(text: widget.dog?.breed ?? '');
    ageController = TextEditingController(text: widget.dog?.age.toString() ?? '');
    descriptionController = TextEditingController(text: widget.dog?.description ?? '');
    selectedGender = widget.dog?.gender ?? 'Male';
    selectedBreed = widget.dog?.breed ?? breeds[0];
    selectedHealth = widget.dog?.healthStatus ?? 'Healthy';
    isNeutered = widget.dog?.isNeutered ?? false;
    traits = widget.dog?.traits ?? [];
    selectedOwnerGender = widget.dog?.ownerGender ?? 'Female';
    imagePaths = widget.dog?.imagePaths ?? [];
    isAvailableForAdoption = widget.dog?.isAvailableForAdoption ?? false;
    _validateImagePaths();
  }

  Future<void> _validateImagePaths() async {
    List<String> validPaths = [];
    for (var path in imagePaths) {
      final file = File(path);
      if (await file.exists()) {
        validPaths.add(path);
      } else {
        print('DogDetailsPage - Image path invalid or file does not exist: $path');
      }
    }
    setState(() {
      imagePaths = validPaths;
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    breedController.dispose();
    ageController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  String translateBreed(String breedKey) {
    final l10n = AppLocalizations.of(context)!;
    if (breedKey.isEmpty) {
      return 'Unknown Breed';
    }
    switch (breedKey) {
      case 'breedPekingese':
        return l10n.breedPekingese ?? 'Pekingese';
      case 'breedLabradorRetriever':
        return l10n.breedLabradorRetriever ?? 'Labrador Retriever';
      case 'breedBeagle':
        return l10n.breedBeagle ?? 'Beagle';
      case 'breedGermanShepherd':
        return l10n.breedGermanShepherd ?? 'German Shepherd';
      case 'breedGoldenRetriever':
        return l10n.breedGoldenRetriever ?? 'Golden Retriever';
      default:
        final parts = breedKey.split('breed');
        return parts.length > 1 ? parts[1] : breedKey;
    }
  }

  String translateTrait(String traitKey) {
    final l10n = AppLocalizations.of(context)!;
    if (traitKey.isEmpty) {
      return 'Unknown Trait';
    }
    // fix: map raw English to localized
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
    };
    final lowerTrait = traitKey.toLowerCase().trim();
    if (rawToLocalized.containsKey(lowerTrait)) {
      return rawToLocalized[lowerTrait]!;
    }
    // fallback برای keyها
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
        final parts = traitKey.split('trait');
        return parts.length > 1 ? parts[1] : traitKey;
    }
  }

  String translateHealthStatus(String status) {
    final l10n = AppLocalizations.of(context)!;
    if (status.isEmpty) {
      return 'Unknown Status';
    }
    final lowerStatus = status.toLowerCase().trim();
    if (kDebugMode) {
      print('Health Status exact: "$status" -> lower: "$lowerStatus"');
    }
    // match انگلیسی یا فارسی
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
      print('No match for health status: "$lowerStatus"');
    }
    return status;  // fallback به raw (فارسی)
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dog == null ? l10n.dogDetailsAddTitle : l10n.dogDetailsEditTitle),
        backgroundColor: Colors.pink,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.dogDetailsNameLabel,
                    labelStyle: const TextStyle(color: Colors.white),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  value: selectedBreed,
                  onChanged: (value) {
                    setState(() {
                      selectedBreed = value;
                    });
                  },
                  items: breeds
                      .map((breed) => DropdownMenuItem(
                            value: breed,
                            child: Text(translateBreed(breed)),
                          ))
                      .toList(),
                  dropdownColor: Colors.pinkAccent,
                  style: const TextStyle(color: Colors.white),
                  iconEnabledColor: Colors.white,
                  isExpanded: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ageController,
                  decoration: InputDecoration(
                    labelText: l10n.dogDetailsAgeLabel,
                    labelStyle: const TextStyle(color: Colors.white),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.dogDetailsGenderLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                DropdownButton<String>(
                  value: selectedGender,
                  onChanged: (value) {
                    setState(() {
                      selectedGender = value;
                    });
                  },
                  items: [l10n.dogDetailsGenderMale, l10n.dogDetailsGenderFemale]
                      .map((gender) => DropdownMenuItem(
                            value: gender,
                            child: Text(gender),
                          ))
                      .toList(),
                  dropdownColor: Colors.pinkAccent,
                  style: const TextStyle(color: Colors.white),
                  iconEnabledColor: Colors.white,
                  isExpanded: true,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.dogDetailsHealthLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                DropdownButton<String>(
                  value: selectedHealth,
                  onChanged: (value) {
                    setState(() {
                      selectedHealth = value;
                    });
                  },
                  items: [
                    l10n.dogDetailsHealthHealthy,
                    l10n.dogDetailsHealthSick,
                    l10n.dogDetailsHealthRecovering,
                  ]
                      .map((health) => DropdownMenuItem(
                            value: health,  // ← value رو raw نگه دار، label رو ترجمه کن
                            child: Text(translateHealthStatus(health)),  // ← label ترجمه‌شده
                          ))
                      .toList(),
                  dropdownColor: Colors.pinkAccent,
                  style: const TextStyle(color: Colors.white),
                  iconEnabledColor: Colors.white,
                  isExpanded: true,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      l10n.dogDetailsNeuteredLabel,
                      style: const TextStyle(color: Colors.white),
                    ),
                    Checkbox(
                      value: isNeutered,
                      onChanged: (value) {
                        setState(() {
                          isNeutered = value ?? false;
                        });
                      },
                      checkColor: Colors.white,
                      activeColor: Colors.pinkAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: l10n.dogDetailsDescriptionLabel,
                    labelStyle: const TextStyle(color: Colors.white),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.dogDetailsTraitsLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                Wrap(
                  spacing: 8.0,
                  children: [
                    'traitEnergetic',
                    'traitCalm',
                    'traitPlayful',
                    'traitLoyal',
                    'traitCurious',
                  ]
                      .map((trait) => ChoiceChip(
                            label: Text(translateTrait(trait)),  // ← ترجمه traits (نه حذف!)
                            selected: traits.contains(trait),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  traits.add(trait);
                                } else {
                                  traits.remove(trait);
                                }
                              });
                            },
                            selectedColor: Colors.pinkAccent,
                            labelStyle: const TextStyle(color: Colors.black),
                            backgroundColor: Colors.white.withOpacity(0.2),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.dogDetailsOwnerGenderLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                DropdownButton<String>(
                  value: selectedOwnerGender,
                  onChanged: (value) {
                    setState(() {
                      selectedOwnerGender = value;
                    });
                  },
                  items: [l10n.dogDetailsGenderMale, l10n.dogDetailsGenderFemale, l10n.dogDetailsOwnerGenderPreferNotToSay]
                      .map((gender) => DropdownMenuItem(
                            value: gender,
                            child: Text(gender),
                          ))
                      .toList(),
                  dropdownColor: Colors.pinkAccent,
                  style: const TextStyle(color: Colors.white),
                  iconEnabledColor: Colors.white,
                  isExpanded: true,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      setState(() {
                        imagePaths.add(pickedFile.path);
                      });
                      print('DogDetailsPage - Image picked: ${pickedFile.path}');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.pink,
                  ),
                  child: Text(l10n.dogDetailsPickImageButton),
                ),
                const SizedBox(height: 10),
                imagePaths.isNotEmpty
                    ? SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: imagePaths.length,
                          itemBuilder: (context, index) {
                            final file = File(imagePaths[index]);
                            return FutureBuilder<bool>(
                              future: file.exists(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                }
                                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!) {
                                  return const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: Icon(Icons.error, color: Colors.white, size: 100),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Image.file(
                                    file,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      print('DogDetailsPage - Error loading image: $error');
                                      return const Icon(Icons.error, color: Colors.white);
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      )
                    : Text(
                        l10n.noImageSelected,
                        style: const TextStyle(color: Colors.white),
                      ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      l10n.dogDetailsAdoptionLabel,
                      style: const TextStyle(color: Colors.white),
                    ),
                    Checkbox(
                      value: isAvailableForAdoption,
                      onChanged: (value) {
                        setState(() {
                          isAvailableForAdoption = value ?? false;
                        });
                      },
                      checkColor: Colors.white,
                      activeColor: Colors.pinkAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final existingDog = dogsBox.values.firstWhere(
                      (dog) =>
                          dog.name == nameController.text &&
                          dog.ownerId == Hive.box<String>('userBox').get('currentUserId'),
                      orElse: () => Dog(
  id: '',
  name: '',
  breed: '',
  gender: '',
  age: 0,
  healthStatus: '',
  isNeutered: false,
  description: '',
  traits: [],
  ownerGender: '',
  imagePaths: [],
  isAvailableForAdoption: false,
  isOwner: false,
  ownerId: '',
),
                    );
                    if (existingDog.name.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.dogDetailsNameExistsError(nameController.text)
)),
                      );
                      return;
                    }
                    final newDog = Dog(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  name: nameController.text,
  breed: selectedBreed ?? 'Pekingese',
  gender: selectedGender ?? 'Male',
  age: int.tryParse(ageController.text) ?? 0,
  healthStatus: selectedHealth ?? 'Healthy',
  isNeutered: isNeutered,
  description: descriptionController.text,
  traits: traits,
  ownerGender: selectedOwnerGender ?? 'Female',
  imagePaths: imagePaths,
  isAvailableForAdoption: isAvailableForAdoption,
  isOwner: true,
  ownerId: Hive.box<String>('userBox').get('currentUserId') ?? '',
);
                    dogsBox.add(newDog);
                    widget.onDogAdded(newDog);
                    print('DogDetailsPage - New dog added: Name=${newDog.name}, OwnerId=${newDog.ownerId}');
                    print('DogDetailsPage - Total dogs in Hive: ${dogsBox.values.length}');
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.pink,
                  ),
                  child: Text(widget.dog == null ? l10n.dogDetailsAddButton : l10n.dogDetailsUpdateButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}