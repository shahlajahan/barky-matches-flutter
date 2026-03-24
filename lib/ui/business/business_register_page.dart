// lib/ui/business/business_register_page.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app_state.dart';
import '../../theme/app_theme.dart';
import '../../models/business_draft.dart';

import '../../data/location_repository.dart';
import '../../data/location_models.dart';
import '../../data/location_cache.dart';
import '../widgets/location_picker_sheet.dart';

import '../../data/validators/tr_tax_validator.dart';
import '../../ui/formatters/vkn_input_formatter.dart';

final String kGoogleApiKey = const String.fromEnvironment(
  'GOOGLE_API_KEY',
  defaultValue: '',
);

enum BusinessKind {
  groomer,
  adoption_center,
  pet_shop,
  vet,
  trainer,
  hotel,
  dog_walker,
  breeder,
}

const String legalTextTR = """
BARKYMATCHES İŞLETME PLATFORM SÖZLEŞMESİ

1. KVKK
6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamında BarkyMatches veri sorumlusudur...

2. TİCARİ SORUMLULUK
Başvuru sahibi sunduğu tüm belgelerin doğru olduğunu beyan eder...

3. PLATFORM SORUMLULUK REDDİ
BarkyMatches yalnızca aracı dijital platformdur...

4. DOĞRULAMA HAKKI
Platform ek belge talep edebilir...

5. YARGI YETKİSİ
İşbu sözleşme Türkiye Cumhuriyeti kanunlarına tabidir.
""";

const String legalTextEN = """
BARKYMATCHES BUSINESS PLATFORM AGREEMENT

1. DATA PROTECTION
Under Turkish Law No. 6698 (KVKK), BarkyMatches acts as Data Controller...

2. COMMERCIAL LIABILITY
The applicant declares that all submitted documents are authentic...

3. PLATFORM DISCLAIMER
BarkyMatches operates solely as an intermediary...

4. VERIFICATION RIGHTS
The platform may request additional documents...

5. GOVERNING LAW
This agreement is governed by the laws of the Republic of Türkiye.
""";

class BusinessRegisterPage extends StatefulWidget {
  const BusinessRegisterPage({super.key});

  @override
  State<BusinessRegisterPage> createState() => _BusinessRegisterPageState();
}

class _BusinessRegisterPageState extends State<BusinessRegisterPage> {
  final _formKeys = List.generate(4, (_) => GlobalKey<FormState>());

  int _step = 0;
  bool _loading = false;

  bool _legalScrolledToEnd = false;
  final ScrollController _legalScrollController = ScrollController();

  final _picker = ImagePicker();
  final FocusNode _addressFocus = FocusNode();

  double? _lat;
  double? _lng;

  String? _taxNumber;
String? _mersisNumber;

String _legalLang = "TR"; // TR | EN

final TextEditingController _taxNumberController = TextEditingController();
final TextEditingController _mersisNumberController = TextEditingController();

  // ─────────────────────────────
  // ENTERPRISE LOCATIONS (Server-driven)
  // ─────────────────────────────
  LocationRepository? _locationRepo;

  List<Country> _countries = [];
  List<Admin1> _admin1List = [];
  List<Admin2> _admin2List = [];

  String? _selectedCountryCode; // "TR"
  Admin1? _selectedAdmin1;
  Admin2? _selectedAdmin2;

  bool _loadingCountries = false;
  bool _loadingAdmin1 = false;
  bool _loadingAdmin2 = false;

  // ─────────────────────────────
  // STEP 1 – BUSINESS IDENTITY
  // ─────────────────────────────
  BusinessKind? _businessKind;
  final _legalName = TextEditingController();
  final _displayName = TextEditingController();

  // keep for Step3 legacy conditions (temporary)
  String _country = "Turkey";

  // ─────────────────────────────
  // STEP 2 – CONTACT
  // ─────────────────────────────
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _website = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _addressLine = TextEditingController();

  // ─────────────────────────────
  // STEP 3 – LEGAL DOCS
  // ─────────────────────────────
  String? _taxPlateUrl;
  String? _tradeRegistryUrl;
  String? _signatureDocUrl;

  // ─────────────────────────────
  // STEP 4 – AGREEMENT
  // ─────────────────────────────
  bool _agreeTerms = false;
  bool _agreeLegalResponsibility = false;

  bool _ocrVerified = false;
  String _ocrStatus = "idle"; // idle | processing | verified | failed
List<String> _riskFlags = [];

  bool _taxLocked = false;
bool _mersisLocked = false;

  List<String> _collectStepErrors() {
  final errors = <String>[];

  if (_step == 0) {
    if (_businessKind == null) {
      errors.add("• Please select Business Type.");
    }
    if (_legalName.text.trim().isEmpty) {
      errors.add("• Legal Company Name is required.");
    }
    if (_displayName.text.trim().isEmpty) {
      errors.add("• Public Display Name is required.");
    }
    if (_selectedCountryCode == null) {
      errors.add("• Please select a Country.");
    }
  }

  if (_step == 1) {
    if (_validateEmail(_email.text) != null) {
      errors.add("• Enter a valid email address (example: name@example.com).");
    }
    if (_validatePhone(_phone.text) != null) {
      errors.add("• Phone number is incomplete.");
    }
    if (_selectedAdmin1 == null) {
      errors.add("• Please select City / Province.");
    }
    if (_selectedAdmin2 == null) {
      errors.add("• Please select District.");
    }
    if (_addressLine.text.trim().isEmpty) {
      errors.add("• Business Address is required.");
    }
  }

  if (_step == 2) {
    if (_country == "Turkey") {
      if (_taxPlateUrl == null ||
          _tradeRegistryUrl == null ||
          _signatureDocUrl == null) {
        errors.add("• All required legal documents must be uploaded.");
      }
    }
  }

  if (_step == 3) {
    if (!_agreeTerms) {
      errors.add("• You must accept the Platform Terms.");
    }
    if (!_agreeLegalResponsibility) {
      errors.add("• You must accept legal responsibility declaration.");
    }
  }

  return errors;
}

void _showValidationDialog(List<String> errors) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      title: const Text(
        "Please fix the highlighted fields",
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Text(errors.join("\n")),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("OK"),
        )
      ],
    ),
  );
}

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _bootstrapLocations());
    _listenForOcrResults();
  }

  Future<void> _bootstrapLocations() async {
  if (!mounted) return;

  setState(() {
    _loadingCountries = true;
  });

  try {
    final cache = await LocationCache.open();
    if (!mounted) return;

    _locationRepo = LocationRepository(cache: cache);

    final list = await _locationRepo!.getCountries(onlyEnabled: true);
    if (!mounted) return;

    _countries = list;

    final tr = list.where((c) => c.code == "TR").toList();

    _selectedCountryCode =
        tr.isNotEmpty ? "TR" : (list.isNotEmpty ? list.first.code : null);

    _country = _selectedCountryCode == "TR"
        ? "Turkey"
        : (_selectedCountryCode == "DE"
            ? "Germany"
            : (_selectedCountryCode == "US"
                ? "USA"
                : (_selectedCountryCode ?? "Turkey")));

    _loadingCountries = false;

    setState(() {});

    // ✅ این باید بیرون از catch باشد
    if (_selectedCountryCode != null) {
      await _loadAdmin1(_selectedCountryCode!);
    }

  } catch (e) {
    debugPrint("LOCATION ERROR: $e");

    if (!mounted) return;

    setState(() {
      _loadingCountries = false;
    });

    _snack("Failed to load countries");
  }
}
  Future<void> _loadAdmin1(String countryCode) async {
    setState(() {
      _loadingAdmin1 = true;
      _admin1List = [];
      _admin2List = [];
      _selectedAdmin1 = null;
      _selectedAdmin2 = null;
      _city.clear();
      _district.clear();
    });

    try {
      final list = await _locationRepo!.getAdmin1(
  countryCode,
  onlyEnabled: true,
);
      debugPrint("ADMIN1 LOADED: ${list.length}");

      setState(() {
        _admin1List = list;
        _loadingAdmin1 = false;
      });
    } catch (e) {
      debugPrint("ADMIN1 ERROR: $e");
      setState(() => _loadingAdmin1 = false);
      _snack("Failed to load cities");
    }
  }

  Future<void> _loadAdmin2(String countryCode, String admin1Id) async {
    setState(() {
      _loadingAdmin2 = true;
      _admin2List = [];
      _selectedAdmin2 = null;
      _district.clear();
    });

    try {
      final list = await _locationRepo!.getAdmin2(
  countryCode,
  admin1Id,
  onlyEnabled: true,
);
      debugPrint("ADMIN2 LOADED: ${list.length}");
      setState(() {
        _admin2List = list;
        _loadingAdmin2 = false;
      });
    } catch (e) {
      debugPrint("ADMIN2 ERROR: $e");
      setState(() => _loadingAdmin2 = false);
      _snack("Failed to load districts");
    }
  }

  @override
  void dispose() {
    _legalName.dispose();
    _displayName.dispose();
    _email.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _website.dispose();
    _city.dispose();
    _district.dispose();
    _addressLine.dispose();
    _legalScrollController.dispose();
    _addressFocus.dispose();
    _taxNumberController.dispose();
_mersisNumberController.dispose();
    super.dispose();
  }

  void _openLegalSheet() {
    _legalScrolledToEnd = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            _legalScrollController.addListener(() {
              if (_legalScrollController.position.pixels >=
                  _legalScrollController.position.maxScrollExtent - 20) {
                setModalState(() {
                  _legalScrolledToEnd = true;
                });
              }
            });

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text(
      "Platform Legal Agreement",
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
    ToggleButtons(
      isSelected: [
        _legalLang == "TR",
        _legalLang == "EN",
      ],
      onPressed: (index) {
        setModalState(() {
          _legalLang = index == 0 ? "TR" : "EN";
        });
      },
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text("TR"),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text("EN"),
        ),
      ],
    )
  ],
),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      controller: _legalScrollController,
                      padding: const EdgeInsets.all(16),
                      child: Text(
  _legalLang == "TR" ? legalTextTR : legalTextEN,
  style: const TextStyle(fontSize: 14),
),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: _legalScrolledToEnd
                          ? () {
                              setState(() => _agreeTerms = true);
                              Navigator.pop(context);
                            }
                          : null,
                      child: const Text("I Have Read and Accept"),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _detectCity() async {
  try {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _snack("Location permission denied");
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );

    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (!mounted || placemarks.isEmpty) return;

    final place = placemarks.first;
    final detectedCity = (place.administrativeArea ?? "").trim();
    final detectedDistrict = (place.subAdministrativeArea ?? "").trim();

    if (_admin1List.isEmpty || _selectedCountryCode == null) return;

    // 🔎 match city
    final cityMatch = _admin1List.firstWhere(
      (p) => p.name.toLowerCase() == detectedCity.toLowerCase(),
      orElse: () => _admin1List.first,
    );

    await _loadAdmin2(_selectedCountryCode!, cityMatch.id);

    // 🔎 match district
    Admin2? districtMatch;
    if (_admin2List.isNotEmpty) {
      try {
        districtMatch = _admin2List.firstWhere(
          (d) =>
              d.name.toLowerCase() == detectedDistrict.toLowerCase(),
        );
      } catch (_) {}
    }

    setState(() {
      _selectedAdmin1 = cityMatch;
      _city.text = cityMatch.name;

      if (districtMatch != null) {
        _selectedAdmin2 = districtMatch;
        _district.text = districtMatch.name;
      }
    });
  } catch (e) {
    _snack("Could not detect city");
  }
}

  String _businessLabel(BusinessKind kind) {
    switch (kind) {
      case BusinessKind.groomer:
        return "Groomer";
      case BusinessKind.adoption_center:
        return "Adoption Center";
      case BusinessKind.pet_shop:
        return "Pet Shop";
      case BusinessKind.vet:
        return "Veterinary Clinic";
      case BusinessKind.trainer:
        return "Dog Trainer";
      case BusinessKind.hotel:
        return "Pet Hotel";
      case BusinessKind.dog_walker:
        return "Dog Walker";
      case BusinessKind.breeder:
        return "Breeder";
    }
  }

  String? _validateEmail(String? v) {
    final email = (v ?? "").trim();
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!regex.hasMatch(email)) return "Invalid email";
    return null;
  }

  String? _validatePhone(String? v) {
    final phone = (v ?? "").replaceAll(RegExp(r'\D'), '');
    if (phone.length < 10) return "Invalid phone";
    return null;
  }

  String? _validateWebsite(String? v) {
    final url = (v ?? "").trim();
    if (url.isEmpty) return null;

    final withScheme = url.startsWith("http") ? url : "https://$url";
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasAuthority) {
      return "Invalid website";
    }
    return null;
  }

  Future<void> _openLegalText() async {
    final url = Uri.parse("https://yourdomain.com/legal/turkey-business-terms");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _snack("Could not open legal text");
    }
  }

  Future<String> _uploadFile(File file, String kind) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseStorage.instance
        .ref()
        .child("business_docs/$uid/${DateTime.now().millisecondsSinceEpoch}_$kind");

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _pickDoc(String kind) async {
  final xf = await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
  );
  if (xf == null) return;

  setState(() {
    _loading = true;
    _ocrStatus = "processing";
  });

  try {
    final url = await _uploadFile(File(xf.path), kind);

    if (!mounted) return;

    setState(() {
      if (kind == "tax" || kind == "gewerbe" || kind == "license") {
        _taxPlateUrl = url;
      }
      if (kind == "registry" || kind == "ein") {
        _tradeRegistryUrl = url;
      }
      if (kind == "signature") {
        _signatureDocUrl = url;
      }
    });
  } finally {
    if (mounted) {
      setState(() => _loading = false);
    }
  }
}

  void _next() {
  final formValid = _formKeys[_step].currentState!.validate();
  final errors = _collectStepErrors();

  if (!formValid || errors.isNotEmpty) {
    _showValidationDialog(errors);
    return;
  }

  if (_step < 3) {
    setState(() => _step++);
  }
}

  void _back() {
    if (_step == 0) {
      context.read<AppState>().closeProfileSubPage();
      return;
    }
    setState(() => _step--);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
  if (_loading) return;
if (_lat == null || _lng == null) {
    _snack("Please select address from suggestions");
    return;
  }

  if (!_agreeTerms || !_agreeLegalResponsibility) {
    _snack("You must accept all agreements");
    return;
  }

  // 🔐 OCR enforcement for Turkey
  if (_country == "Turkey") {
    if (!_taxLocked || !_mersisLocked) {
      _snack("Documents must be verified before submission");
      return;
    }
  }

  setState(() => _loading = true);

  try {
    final draft = BusinessDraft(
      profile: BusinessProfileDraft(
        displayName: _displayName.text.trim(),
        description: "",
      ),
      contact: BusinessContactDraft(
        phone: _phone.text.trim(),
        whatsapp: _whatsapp.text.trim(),
        email: _email.text.trim(),
        instagram: "",
        website: _website.text.trim(),
        city: _city.text.trim(),
        district: _district.text.trim(),
        addressLine: _addressLine.text.trim(),
      ),
      legal: BusinessLegalDraft(
        taxNumber: _taxNumberController.text.trim(),
        mersisNumber: _mersisNumberController.text.trim(),
        disclaimerAccepted: true,
      ),
    );

    final callable = FirebaseFunctions.instanceFor(
      region: "europe-west3",
    ).httpsCallable("registerBusiness");
debugPrint("LAT => $_lat");
debugPrint("LNG => $_lng");
    final result = await callable.call({
      "type": _businessKind.toString().split('.').last,
      "draft": draft.toJson(),
      "lat": _lat,
      "lng": _lng,
      "countryCode": _selectedCountryCode,
      "admin1Id": _selectedAdmin1?.id,
      "admin2Id": _selectedAdmin2?.id,
    });

    if (!mounted) return;

    _snack("Application submitted successfully");

    context.read<AppState>().closeProfileSubPage();
  } on FirebaseFunctionsException catch (e) {
    _snack(e.message ?? "Submission failed");
  } catch (e) {
    _snack("Unexpected error occurred");
  } finally {
    if (mounted) {
      setState(() => _loading = false);
    }
  }
}
  @override
  Widget build(BuildContext context) {
   // debugPrint("GOOGLE KEY => $kGoogleApiKey");

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text("Business Registration", style: AppTheme.h2()),
          const SizedBox(height: 12),
          Expanded(
            child: Form(
              key: _formKeys[_step],
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildProgressBar(),
                    const SizedBox(height: 18),
                    if (_step == 0) _stepIdentity(),
                    if (_step == 1) _stepContact(),
                    if (_step == 2) _stepLegal(),
                    if (_step == 3) _stepAgreement(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : _back,
                            child: Text(_step == 0 ? "Cancel" : "Back"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _loading ? null : (_step < 3 ? _next : _submit),
                            child: Text(
                              _step < 3 ? "Continue" : "Submit for Review",
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _fieldSpacing(Widget child) =>
      Padding(padding: const EdgeInsets.only(bottom: 16), child: child);

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  // ─────────────────────────────
  // STEP 1
  // ─────────────────────────────
  Widget _stepIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Business Information"),
        const SizedBox(height: 16),

        _fieldSpacing(
          DropdownButtonFormField<BusinessKind>(
            value: _businessKind,
            decoration: _inputDecoration("Business Type"),
            items: BusinessKind.values.map((e) {
              return DropdownMenuItem(
                value: e,
                child: Text(_businessLabel(e)),
              );
            }).toList(),
            onChanged: (v) => setState(() => _businessKind = v),
            validator: (v) => v == null ? "Required" : null,
          ),
        ),

        _fieldSpacing(
          TextFormField(
            controller: _legalName,
            decoration: _inputDecoration("Legal Company Name"),
            validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
          ),
        ),

        _fieldSpacing(
          TextFormField(
            controller: _displayName,
            decoration: _inputDecoration("Public Display Name"),
            validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
          ),
        ),

        _fieldSpacing(
          DropdownButtonFormField<String>(
            value: _selectedCountryCode,
            decoration: _inputDecoration("Country"),
            items: _countries.map((c) {
              return DropdownMenuItem(
                value: c.code,
                child: Text(c.name),
              );
            }).toList(),
            onTap: () => FocusScope.of(context).unfocus(),
            onChanged: _loadingCountries
                ? null
                : (code) async {
                    if (code == null) return;

                    setState(() {
                      _selectedCountryCode = code;
                      _country = code == "TR"
                          ? "Turkey"
                          : (code == "DE" ? "Germany" : (code == "US" ? "USA" : code));
                    });

                    await _loadAdmin1(code);
                  },
            validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────
  // STEP 2
  // ─────────────────────────────
  Widget _stepContact() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _field(_email, "Email", _validateEmail),
      _space(),
      _phoneField(_phone, "Phone (+90...)"),
      _space(),
      TextFormField(
  controller: _whatsapp,
  keyboardType: TextInputType.phone,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(15),
  ],
  validator: (v) {
    if (v == null || v.trim().isEmpty) {
      return "WhatsApp number is required";
    }
    return _validatePhone(v);
  },
  decoration: _inputDecoration("WhatsApp"),
),
      _space(),
      _field(_website, "Website (optional)", _validateWebsite),
      _space(),

      // ===============================
      // CITY (Searchable + Lazy)
      // ===============================
      Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _loadingAdmin1
                  ? null
                  : () async {
                      if (_admin1List.isEmpty) return;

                      FocusScope.of(context).unfocus();

                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => LocationPickerSheet<Admin1>(
                          title: "Select City / Province",
                          items: List<Admin1>.from(_admin1List),
                          itemLabel: (p) => p.displayName,
                          onSelected: (p) async {
                            if (_selectedCountryCode == null) return;

                            setState(() {
                              _selectedAdmin1 = p;
                              _city.text = p.name;
                              _selectedAdmin2 = null;
                              _district.clear();
                            });

                            await _loadAdmin2(
                              _selectedCountryCode!,
                              p.id,
                            );
                          },
                        ),
                      );
                    },
              child: AbsorbPointer(
                child: TextFormField(
                  controller: _city,
                  decoration: _inputDecoration("City / Province").copyWith(
                    suffixIcon: _loadingAdmin1
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.keyboard_arrow_down),
                  ),
                  validator: (_) =>
                      _selectedAdmin1 == null ? "Required" : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _detectCity,
            icon: const Icon(Icons.my_location),
            tooltip: "Detect city",
          ),
        ],
      ),

      _space(),

      // ===============================
      // DISTRICT
      // ===============================
      GestureDetector(
        onTap: (_selectedAdmin1 == null || _loadingAdmin2)
            ? null
            : () async {
                if (_admin2List.isEmpty) return;

                FocusScope.of(context).unfocus();

                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => LocationPickerSheet<Admin2>(
                    title: "Select District",
                    items: _admin2List,
                    itemLabel: (d) => d.displayName,
                    onSelected: (d) {
                      setState(() {
                        _selectedAdmin2 = d;
                        _district.text = d.name;
                      });
                      _formKeys[1].currentState?.validate();
                    },
                  ),
                );
              },
        child: AbsorbPointer(
          child: TextFormField(
            controller: _district,
            decoration: _inputDecoration("District").copyWith(
              suffixIcon: _loadingAdmin2
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.keyboard_arrow_down),
            ),
            validator: (_) {
  if (_district.text.trim().isEmpty) {
    return "Required";
  }
  return null;
},
          ),
        ),
      ),

      _space(),

      // ===============================
      // ADDRESS (Stable Focus Version)
      // ===============================
      Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            _addressFocus.requestFocus();
          }
        },
        child: FormField<String>(
  validator: (_) {
    if (_addressLine.text.trim().isEmpty) {
      return "Business Address is required";
    }
    return null;
  },
  builder: (field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GooglePlaceAutoCompleteTextField(
          focusNode: _addressFocus,
          textEditingController: _addressLine,
          googleAPIKey: kGoogleApiKey,
          inputDecoration: _inputDecoration("Business Address")
              .copyWith(errorText: field.errorText),
          keyboardType: TextInputType.streetAddress,
          debounceTime: 800,
          isLatLngRequired: true,
          getPlaceDetailWithLatLng: (prediction) {
  debugPrint("PLACE LAT => ${prediction.lat}");
  debugPrint("PLACE LNG => ${prediction.lng}");

  final lat = double.tryParse(prediction.lat ?? "");
  final lng = double.tryParse(prediction.lng ?? "");

  if (lat != null && lng != null) {
    _lat = lat;
    _lng = lng;
  }

  debugPrint("FINAL LAT => $_lat");
  debugPrint("FINAL LNG => $_lng");
},
          itemClick: (prediction) {

  _addressLine.text = prediction.description ?? "";

  _addressLine.selection = TextSelection.fromPosition(
    TextPosition(offset: _addressLine.text.length),
  );

  field.didChange(_addressLine.text);

  // ⭐ IMPORTANT — save coordinates
  final lat = double.tryParse(prediction.lat ?? "");
  final lng = double.tryParse(prediction.lng ?? "");

  if (lat != null && lng != null) {
    setState(() {
      _lat = lat;
      _lng = lng;
    });

    debugPrint("SELECTED LAT => $_lat");
    debugPrint("SELECTED LNG => $_lng");
  }
},
        ),
      ],
    );
  },
),
      ),
    ],
  );
}

  Widget _phoneField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
      ],
      validator: _validatePhone,
      decoration: _inputDecoration(label),
    );
  }

  Widget _space() => const SizedBox(height: 14);

  Widget _field(
    TextEditingController controller,
    String label,
    String? Function(String?) validator,
  ) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ─────────────────────────────
  // STEP 3
  // ─────────────────────────────
  Widget _stepLegal() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      // =====================================================
      // 🇹🇷 TURKEY
      // =====================================================
      if (_country == "Turkey") ...[

  // =========================
  // 1️⃣ DOCUMENT UPLOAD FIRST
  // =========================

  _docCard(
    "Vergi Levhası (Tax Plate)",
    _taxPlateUrl,
    () => _pickDoc("tax"),
  ),

  _docCard(
    "Ticaret Sicil Gazetesi",
    _tradeRegistryUrl,
    () => _pickDoc("registry"),
  ),

  _docCard(
    "Yetkili İmza Belgesi",
    _signatureDocUrl,
    () => _pickDoc("signature"),
  ),

  const SizedBox(height: 20),

  // =========================
  // 2️⃣ TAX NUMBER (AUTO-FILL)
  // =========================

  Container(
  margin: const EdgeInsets.only(bottom: 16),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
      )
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            _taxLocked ? Icons.verified : Icons.info_outline,
            color: _taxLocked ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          const Text(
            "Tax Number (VKN)",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: _taxNumberController,
        enabled: !_taxLocked,
        keyboardType: TextInputType.number,
        inputFormatters: [VknInputFormatter()],
        decoration: _inputDecoration("Auto-filled from document"),
      ),
    ],
  ),
),

  if (_riskFlags.isNotEmpty)
  Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange),
    ),
    child: Row(
      children: const [
        Icon(Icons.warning_amber_rounded, color: Colors.orange),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            "Document verification has inconsistencies. Admin review required.",
            style: TextStyle(color: Colors.orange),
          ),
        ),
      ],
    ),
  ),

  // =========================
  // 3️⃣ MERSIS NUMBER (AUTO-FILL)
  // =========================

  Container(
  margin: const EdgeInsets.only(bottom: 16),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
      )
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            _mersisLocked
                ? Icons.verified
                : (_ocrStatus == "processing"
                    ? Icons.hourglass_top
                    : Icons.info_outline),
            color: _mersisLocked
                ? Colors.green
                : (_ocrStatus == "processing"
                    ? Colors.orange
                    : Colors.grey),
          ),
          const SizedBox(width: 8),
          const Text(
            "MERSIS Number",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),

      const SizedBox(height: 8),

      TextFormField(
        controller: _mersisNumberController,
        enabled: !_mersisLocked,
        keyboardType: TextInputType.number,
        decoration: _inputDecoration(
          _mersisLocked
              ? "Verified from document"
              : "Auto-filled after document verification",
        ),
        validator: (v) {
          if (_tradeRegistryUrl == null) {
            return "Upload Trade Registry first";
          }
          if (!_mersisLocked) {
            return "Waiting for document verification...";
          }
          return null;
        },
      ),
    ],
  ),
),
],

      // =====================================================
      // 🇩🇪 GERMANY
      // =====================================================
      if (_country == "Germany") ...[

        _fieldSpacing(
          TextFormField(
            controller: _taxNumberController,
            decoration: _inputDecoration("Steuernummer"),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return "Tax Number is required";
              }
              return null;
            },
          ),
        ),

        _docCard(
          "Gewerbeschein",
          _taxPlateUrl,
          () => _pickDoc("gewerbe"),
        ),

        _docCard(
          "Handelsregisterauszug",
          _tradeRegistryUrl,
          () => _pickDoc("registry"),
        ),
      ],

      // =====================================================
      // 🇺🇸 USA
      // =====================================================
      if (_country == "USA") ...[

        _fieldSpacing(
          TextFormField(
            controller: _taxNumberController,
            decoration: _inputDecoration("EIN Number"),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return "EIN Number is required";
              }
              return null;
            },
          ),
        ),

        _docCard(
          "Business License",
          _taxPlateUrl,
          () => _pickDoc("license"),
        ),

        _docCard(
          "IRS EIN Document",
          _tradeRegistryUrl,
          () => _pickDoc("ein"),
        ),
      ],
    ],
  );
}

  Widget _buildProgressBar() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_step + 1) / 4,
          minHeight: 6,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation(AppTheme.accent),
        ),
        const SizedBox(height: 6),
        Text(
          "Step ${_step + 1} of 4",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────
  // STEP 4
  // ─────────────────────────────
  Widget _stepAgreement() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Legal Confirmation",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 14),
          CheckboxListTile(
            value: _agreeTerms,
            onChanged: (v) => setState(() => _agreeTerms = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              "I accept the Platform Terms and KVKK Data Protection Policy.",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: GestureDetector(
              onTap: _openLegalSheet,
              child: const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  "Read full legal document",
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: Colors.blue,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _agreeLegalResponsibility,
            onChanged: (v) => setState(() => _agreeLegalResponsibility = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              "I declare that all submitted documents are accurate and I accept full legal responsibility under Turkish Commercial Law.",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _docCard(String title, String? url, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        children: [
          Icon(
            url == null ? Icons.upload_file : Icons.check_circle,
            color: url == null ? Colors.grey : Colors.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  url == null ? "Required" : "Uploaded",
                  style: TextStyle(
                    fontSize: 12,
                    color: url == null ? Colors.red : Colors.green,
                  ),
                )
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(url == null ? "Upload" : "Replace"),
          )
        ],
      ),
    );
  }
  void _listenForOcrResults() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  FirebaseFirestore.instance
      .collection("businessDrafts")
      .doc(uid)
      .snapshots()
      .listen((doc) {
    if (!doc.exists) return;

    final data = doc.data();
    if (data == null) return;

    final verification = data["verification"];
    final ocr = verification is Map ? verification["ocr"] : null;

    final trust = data["trust"];
    final flags = (trust is Map) ? trust["riskFlags"] : null;

    final tax = (ocr is Map) ? ocr["extractedTaxNumber"] : null;
    final mersis = (ocr is Map) ? ocr["extractedMersisNumber"] : null;

    // 🔥 status منطقی
    String nextStatus = _ocrStatus;
    if (_taxPlateUrl == null && _tradeRegistryUrl == null && _signatureDocUrl == null) {
      nextStatus = "idle";
    } else if (tax != null || mersis != null) {
      nextStatus = "verified";
    } else {
      nextStatus = "processing"; // ⬅️ نه failed
    }

    // ✅ فقط یک setState و فقط اگر چیزی واقعاً تغییر کرد
    final nextRisk = (flags is List) ? List<String>.from(flags) : <String>[];

    final nextTaxText = (tax != null && tax.toString().isNotEmpty) ? tax.toString() : null;
    final nextMersisText = (mersis != null && mersis.toString().isNotEmpty) ? mersis.toString() : null;

    final shouldLockTax = nextTaxText != null;
    final shouldLockMersis = nextMersisText != null;

    if (!mounted) return;

    setState(() {
  _riskFlags = nextRisk;
  _ocrStatus = nextStatus;

  // TAX
  if (nextTaxText != null && nextTaxText.isNotEmpty) {
    if (_taxNumberController.text != nextTaxText) {
      _taxNumberController.text = nextTaxText;
    }
    _taxLocked = true; // فقط وقتی مقدار واقعی داریم
  }

  // MERSIS
  if (nextMersisText != null && nextMersisText.isNotEmpty) {
    if (_mersisNumberController.text != nextMersisText) {
      _mersisNumberController.text = nextMersisText;
    }
    _mersisLocked = true; // فقط وقتی مقدار واقعی داریم
  }
});
  });
}
}
class _AddressField extends StatefulWidget {
  const _AddressField({
    required this.controller,
    required this.apiKey,
    required this.onLatLng,
    required this.decoration,
  });

  final TextEditingController controller;
  final String apiKey;
  final void Function(String? lat, String? lng) onLatLng;
  final InputDecoration decoration;

  @override
  State<_AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<_AddressField> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GooglePlaceAutoCompleteTextField(
      focusNode: _focus,
      textEditingController: widget.controller,
      googleAPIKey: widget.apiKey,
      inputDecoration: widget.decoration,
      keyboardType: TextInputType.streetAddress,
      debounceTime: 800,
      isLatLngRequired: true,

      getPlaceDetailWithLatLng: (prediction) {
        widget.onLatLng(prediction.lat, prediction.lng);
      },

      itemClick: (prediction) {
        widget.controller.text = prediction.description ?? "";
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );

        // فوکوس حفظ بشه
        _focus.requestFocus();
      },
    );
  }
}