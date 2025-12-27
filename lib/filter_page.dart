import 'package:flutter/material.dart';
import 'dog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
 // اضافه کردن برای localizations
import 'package:barky_matches_fixed/utils/localization_utils.dart'; // اضافه کردن برای استفاده از getDogBreeds

class FilterPage extends StatefulWidget {
  final List<Dog> dogsList;
  final String? selectedBreed;
  final String? selectedGender;
  final RangeValues ageRange;
  final double maxDistance;
  final bool isPremium; // دریافت وضعیت پرمیوم از HomePage یا PlaymatePage

  const FilterPage({
    super.key,
    required this.dogsList,
    required this.selectedBreed,
    required this.selectedGender,
    required this.ageRange,
    required this.maxDistance,
    required this.isPremium, // اجباری کردن دریافت isPremium
  });

  @override
  _FilterPageState createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> with LocalizationUtils {
  late String? _selectedBreed;
  late String? _selectedGender;
  late RangeValues _ageRange;
  late double _maxDistance;
  late bool? _selectedNeutered;
  late String? _selectedHealthStatus;
  bool _isLoading = true; // اضافه کردن وضعیت لودینگ

  final List<String> _genders = ['Male', 'Female'];
  final List<bool> _neuteredOptions = [true, false];
  final List<String> _healthStatusOptions = ['Healthy', 'Needs Care', 'Under Treatment'];

  @override
  void initState() {
    super.initState();
    _selectedBreed = widget.selectedBreed;
    _selectedGender = widget.selectedGender;
    _ageRange = widget.ageRange;
    _maxDistance = widget.maxDistance.clamp(1.0, widget.isPremium ? 1000.0 : 50.0); // تغییر حداکثر به 1000 برای پرمیوم
    _selectedNeutered = null; // پیش‌فرض "Any"
    _selectedHealthStatus = null; // پیش‌فرض "Any"
    _loadInitialData(); // لود اولیه داده‌ها
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = false; // لودینگ به پایان رسید
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; // اضافه کردن localizations
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final availableBreeds = [...getDogBreeds(context), ...widget.dogsList.map((dog) => dog.breed).toSet()];
    final uniqueBreeds = availableBreeds.toSet().toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.moreFiltersButton, // استفاده از localizations
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - kToolbarHeight - 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.filterByBreed, // استفاده از localizations
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBreed,
                    hint: Text(
                      localizations.selectBreedHint,
                      style: GoogleFonts.poppins(color: Colors.white),
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
                    style: GoogleFonts.poppins(color: Colors.white),
                    iconEnabledColor: Colors.white,
                    items: uniqueBreeds.map((breed) {
                      return DropdownMenuItem<String>(
                        value: breed,
                        child: Text(
                          breed,
                          style: GoogleFonts.poppins(),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBreed = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.filterByGender, // استفاده از localizations
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    hint: Text(
                      localizations.selectGenderHint,
                      style: GoogleFonts.poppins(color: Colors.white),
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
                    style: GoogleFonts.poppins(color: Colors.white),
                    iconEnabledColor: Colors.white,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Any'),
                      ),
                      ..._genders.map((gender) {
                        return DropdownMenuItem<String>(
                          value: gender,
                          child: Text(
                            gender,
                            style: GoogleFonts.poppins(),
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.filterByAge, // استفاده از localizations
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  RangeSlider(
                    values: _ageRange,
                    min: 0,
                    max: 15,
                    divisions: 15,
                    labels: RangeLabels(
                      _ageRange.start.round().toString(),
                      _ageRange.end.round().toString(),
                    ),
                    onChanged: (RangeValues values) {
                      setState(() {
                        _ageRange = values;
                      });
                    },
                    activeColor: Colors.pink,
                    inactiveColor: Colors.white.withOpacity(0.3),
                  ),
                  if (widget.isPremium) ...[
                    const SizedBox(height: 16),
                    Text(
                      localizations.filterByNeuteredStatus, // استفاده از localizations
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<bool>(
                      initialValue: _selectedNeutered,
                      hint: Text(
                        localizations.selectNeuteredStatusHint,
                        style: GoogleFonts.poppins(color: Colors.white),
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
                      style: GoogleFonts.poppins(color: Colors.white),
                      iconEnabledColor: Colors.white,
                      items: [
                        const DropdownMenuItem<bool>(
                          value: null,
                          child: Text('Any'),
                        ),
                        ..._neuteredOptions.map((neutered) {
                          return DropdownMenuItem<bool>(
                            value: neutered,
                            child: Text(
                              neutered ? 'Yes' : 'No',
                              style: GoogleFonts.poppins(),
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedNeutered = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      localizations.filterByHealthStatus, // استفاده از localizations
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedHealthStatus,
                      hint: Text(
                        localizations.selectHealthStatusHint,
                        style: GoogleFonts.poppins(color: Colors.white),
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
                      style: GoogleFonts.poppins(color: Colors.white),
                      iconEnabledColor: Colors.white,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Any'),
                        ),
                        ..._healthStatusOptions.map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(
                              status,
                              style: GoogleFonts.poppins(),
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedHealthStatus = value;
                        });
                      },
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Text(
                      localizations.upgradeToPremiumForMoreFilters, // استفاده از localizations
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    localizations.distanceLabel(_maxDistance.toStringAsFixed(1)), // استفاده از localizations
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Slider(
                    value: _maxDistance,
                    min: 1,
                    max: widget.isPremium ? 1000.0 : 50.0,
                    divisions: widget.isPremium ? 999 : 49,
                    label: _maxDistance.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        _maxDistance = value;
                      });
                    },
                    activeColor: Colors.pink,
                    inactiveColor: Colors.white.withOpacity(0.3),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.pink,
                          minimumSize: const Size(150, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          localizations.cancelButton,
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          print('FilterPage - Applying filters: breed=$_selectedBreed, gender=$_selectedGender, ageRange=$_ageRange, maxDistance=$_maxDistance, neutered=$_selectedNeutered, healthStatus=$_selectedHealthStatus');
                          Navigator.pop(context, {
                            'breed': _selectedBreed,
                            'gender': _selectedGender,
                            'ageRange': _ageRange,
                            'maxDistance': _maxDistance,
                            'neutered': _selectedNeutered, // همیشه برگردونده می‌شه
                            'healthStatus': _selectedHealthStatus, // همیشه برگردونده می‌شه
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.pink,
                          minimumSize: const Size(150, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          localizations.apply, // استفاده از localizations
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    ],
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