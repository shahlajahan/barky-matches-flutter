import 'package:flutter/material.dart';
import 'dog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/utils/localization_utils.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/app_state.dart';

typedef EditDogCallback = void Function(Dog updatedDog)?;

class EditDogPage extends StatefulWidget {
  final Dog dog;
  final EditDogCallback? onEditDog;

  const EditDogPage({
    super.key,
    required this.dog,
    this.onEditDog,
  });

  @override
  _EditDogPageState createState() => _EditDogPageState();
}

class _EditDogPageState extends State<EditDogPage> with LocalizationUtils {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _descriptionController;
  late String? _selectedOwnerGender;
  late bool _isNeutered;
  late List<String> _selectedTraits;
  late List<String> _imagePaths;
  late String? _selectedHealthStatus;
  late bool _isAvailableForAdoption;
  bool _isSaving = false;

  final List<String> _healthStatusOptions = [
    'editDogHealthHealthy',
    'editDogHealthNeedsCare',
    'editDogHealthUnderTreatment',
  ];
  final List<String> _ownerGenderOptions = [
    'editDogOwnerGenderMale',
    'editDogOwnerGenderFemale',
    'editDogOwnerGenderOther',
  ];

  @override
  void initState() {
    super.initState();
    print('EditDogPage - Initializing for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
    _nameController = TextEditingController(text: widget.dog.name);
    _ageController = TextEditingController(text: widget.dog.age.toString());
    _descriptionController = TextEditingController(text: widget.dog.description);
    _selectedOwnerGender = _mapOwnerGender(widget.dog.ownerGender);
    _isNeutered = widget.dog.isNeutered;
    _selectedTraits = List.from(widget.dog.traits ?? []);
    _imagePaths = List.from(widget.dog.imagePaths ?? []);
    _selectedHealthStatus = widget.dog.healthStatus.isNotEmpty && _healthStatusOptions.contains(widget.dog.healthStatus)
        ? widget.dog.healthStatus
        : _healthStatusOptions[0];
    _isAvailableForAdoption = widget.dog.isAvailableForAdoption;
  }

  String? _mapOwnerGender(String? gender) {
    if (gender == 'Male') return 'editDogOwnerGenderMale';
    if (gender == 'Female') return 'editDogOwnerGenderFemale';
    if (gender == 'Other') return 'editDogOwnerGenderOther';
    return 'editDogOwnerGenderOther'; // پیش‌فرض
  }

  @override
  void dispose() {
    print('EditDogPage - Disposing for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
    _nameController.dispose();
    _ageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

 Future<void> _saveDog() async {
    if (_isSaving) {
      print('EditDogPage - Save already in progress for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
      return;
    }

   

    setState(() {
      _isSaving = true;
      print('EditDogPage - Saving dog: ${widget.dog.name}, ID: ${widget.dog.id}');
    });

    final name = _nameController.text.trim();
    final ageText = _ageController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      print('EditDogPage - Name is empty for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.editDogEnterName)),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }

    final int? age = int.tryParse(ageText);
    if (age == null || age <= 0) {
      print('EditDogPage - Invalid age for dog: ${widget.dog.name}, ID: ${widget.dog.id}, age: $ageText');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.editDogEnterValidAge)),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }

/*
    final localizations = AppLocalizations.of(context)!;
    final healthStatus = _selectedHealthStatus == 'editDogHealthHealthy' ? localizations.editDogHealthHealthy :
                        _selectedHealthStatus == 'editDogHealthNeedsCare' ? localizations.editDogHealthNeedsCare :
                        _selectedHealthStatus == 'editDogHealthUnderTreatment' ? localizations.editDogHealthUnderTreatment :
                        localizations.editDogHealthHealthy; // پیش‌فرض

    final ownerGender = _selectedOwnerGender == 'editDogOwnerGenderMale' ? localizations.editDogOwnerGenderMale :
                       _selectedOwnerGender == 'editDogOwnerGenderFemale' ? localizations.editDogOwnerGenderFemale :
                       localizations.editDogOwnerGenderOther;

*/

    final updatedDog = Dog(
      id: widget.dog.id,
      name: name,
      breed: widget.dog.breed,
      age: age,
      gender: widget.dog.gender,
      healthStatus: _selectedHealthStatus ?? widget.dog.healthStatus,
      isNeutered: _isNeutered,
      description: description,
      traits: _selectedTraits,
      ownerGender: _selectedOwnerGender ?? widget.dog.ownerGender,
      imagePaths: _imagePaths,
      isAvailableForAdoption: _isAvailableForAdoption,
      isOwner: widget.dog.isOwner,
      ownerId: widget.dog.ownerId,
      latitude: widget.dog.latitude,
      longitude: widget.dog.longitude,
    );

    print('EditDogPage - Dog updated: ${updatedDog.name}, ID: ${updatedDog.id}, calling onEditDog');
   try {
  await context.read<AppState>().saveEditedDog(updatedDog);

  if (!mounted) return;

  Navigator.of(context, rootNavigator: true).pop();
} finally {
  if (mounted) {
    setState(() {
      _isSaving = false;
    });
  }
}
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    print('EditDogPage - Building UI for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.pets,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                localizations.editDog,
                style: GoogleFonts.dancingScript(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: localizations.nameLabel,
                  labelStyle: GoogleFonts.poppins(color: Colors.white),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                decoration: InputDecoration(
                  labelText: localizations.ageLabel,
                  labelStyle: GoogleFonts.poppins(color: Colors.white),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: GoogleFonts.poppins(color: Colors.white),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedHealthStatus,
                decoration: InputDecoration(
                  labelText: localizations.selectHealthStatusHint,
                  labelStyle: GoogleFonts.poppins(color: Colors.white),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: Colors.pinkAccent,
                style: GoogleFonts.poppins(color: Colors.white),
                iconEnabledColor: Colors.white,
                items: _healthStatusOptions.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(
                      status == 'editDogHealthHealthy' ? localizations.editDogHealthHealthy :
                      status == 'editDogHealthNeedsCare' ? localizations.editDogHealthNeedsCare :
                      localizations.editDogHealthUnderTreatment,
                      style: GoogleFonts.poppins(color: Colors.black),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedHealthStatus = value;
                    print('EditDogPage - Health status changed to: $value');
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    localizations.neuteredLabel,
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
                            _isNeutered = value!;
                            print('EditDogPage - Neutered changed to: true');
                          });
                        },
                        activeColor: Colors.white,
                      ),
                      Text(
                        localizations.yes,
                        style: GoogleFonts.poppins(color: Colors.white),
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
                            _isNeutered = value!;
                            print('EditDogPage - Neutered changed to: false');
                          });
                        },
                        activeColor: Colors.white,
                      ),
                      Text(
                        localizations.no,
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: localizations.descriptionLabel,
                  labelStyle: GoogleFonts.poppins(color: Colors.white),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: GoogleFonts.poppins(color: Colors.white),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text(
                localizations.traitsLabel,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4.0,
                children: getDogTraits(context).map((trait) { // استفاده مستقیم از متد mixin
                  final isSelected = _selectedTraits.contains(trait);
                  return FilterChip(
                    label: Text(
                      trait,
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTraits.add(trait);
                          print('EditDogPage - Trait added: $trait');
                        } else {
                          _selectedTraits.remove(trait);
                          print('EditDogPage - Trait removed: $trait');
                        }
                      });
                    },
                    selectedColor: Colors.pinkAccent,
                    backgroundColor: Colors.white.withOpacity(0.2),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedOwnerGender,
                decoration: InputDecoration(
                  labelText: localizations.selectOwnerGenderHint,
                  labelStyle: GoogleFonts.poppins(color: Colors.white),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: Colors.pinkAccent,
                style: GoogleFonts.poppins(color: Colors.white),
                iconEnabledColor: Colors.white,
                items: _ownerGenderOptions.map((gender) {
                  return DropdownMenuItem<String>(
                    value: gender,
                    child: Text(
                      gender == 'editDogOwnerGenderMale' ? localizations.editDogOwnerGenderMale :
                      gender == 'editDogOwnerGenderFemale' ? localizations.editDogOwnerGenderFemale :
                      localizations.editDogOwnerGenderOther,
                      style: GoogleFonts.poppins(color: Colors.black),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedOwnerGender = value;
                    print('EditDogPage - Owner gender changed to: $value');
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isAvailableForAdoption,
                    onChanged: (value) {
                      setState(() {
                        _isAvailableForAdoption = value ?? false;
                        print('EditDogPage - Available for adoption changed to: $_isAvailableForAdoption');
                      });
                    },
                    checkColor: Colors.white,
                    activeColor: Colors.pink,
                  ),
                  Text(
                    localizations.availableForAdoption,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      print('EditDogPage - Cancel button pressed for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.pink,
                      minimumSize: const Size(120, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      localizations.cancelButton,
                      style: GoogleFonts.poppins(
                        color: Colors.pink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveDog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.pink,
                      minimumSize: const Size(120, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(
                            color: Colors.pink,
                          )
                        : Text(
                            localizations.save,
                            style: GoogleFonts.poppins(
                              color: Colors.pink,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditDogDialog extends StatelessWidget {
  final Dog dog;
  final EditDogCallback? onEditDog;

  const EditDogDialog({
    super.key,
    required this.dog,
    this.onEditDog,
  });

  @override
  Widget build(BuildContext context) {
    print('EditDogDialog - Building for dog: ${dog.name}, ID: ${dog.id}');
    return EditDogPage(
      dog: dog,
      onEditDog: onEditDog,
    );
  }
}