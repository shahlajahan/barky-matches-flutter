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
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import '../../app_state.dart';
import '../../theme/app_theme.dart';
import '../../models/business_draft.dart';

import '../../data/location_repository.dart';
import '../../data/location_models.dart';
import '../../data/location_cache.dart';
import '../widgets/location_picker_sheet.dart';

import '../../data/validators/tr_tax_validator.dart';
import '../../ui/formatters/vkn_input_formatter.dart';
import '../../config/api_keys.dart';

import 'sector_forms/vet_details_page.dart';
import 'package:barky_matches_fixed/ui/business/petshop/pet_shop_details_page.dart';

import 'package:barky_matches_fixed/ui/business/groomy/groomy_details_page.dart';
import 'package:barky_matches_fixed/ui/business/pet_hotel/pet_hotel_registration_details_page.dart';
import 'package:barky_matches_fixed/ui/business/pet_taxi/pet_taxi_registration_details_page.dart';

import 'package:lucide_icons/lucide_icons.dart';
import 'package:barky_matches_fixed/ui/business/adoption_center/adoption_center_details_page.dart';

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

enum DocStatus { idle, uploading, processing, success, error }

const String legalTextTR = """
PetSopu İŞLETME PLATFORM SÖZLEŞMESİ

1. KVKK
6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamında PetSopu veri sorumlusudur...

2. TİCARİ SORUMLULUK
Başvuru sahibi sunduğu tüm belgelerin doğru olduğunu beyan eder...

3. PLATFORM SORUMLULUK REDDİ
PetSopu yalnızca aracı dijital platformdur...

4. DOĞRULAMA HAKKI
Platform ek belge talep edebilir...

5. YARGI YETKİSİ
İşbu sözleşme Türkiye Cumhuriyeti kanunlarına tabidir.
""";

const String legalTextEN = """
PetSopu BUSINESS PLATFORM AGREEMENT

1. DATA PROTECTION
Under Turkish Law No. 6698 (KVKK), PetSopu acts as Data Controller...

2. COMMERCIAL LIABILITY
The applicant declares that all submitted documents are authentic...

3. PLATFORM DISCLAIMER
PetSopu operates solely as an intermediary...

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

  List<String> selectedSectors = [];
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

  bool _sectorCompleted = false;
  BusinessDraft? _completedSectorDraft;

  List<String> _collectStepErrors() {
    final errors = <String>[];

    if (_step == 0) {
      if (_legalName.text.trim().isEmpty) {
        errors.add(
          AppLocalizations.of(
            context,
          )!.businessRegisterLegalCompanyNameRequired,
        );
      }
      if (_displayName.text.trim().isEmpty) {
        errors.add(
          AppLocalizations.of(
            context,
          )!.businessRegisterPublicDisplayNameRequired,
        );
      }
      if (_selectedCountryCode == null) {
        errors.add(AppLocalizations.of(context)!.businessRegisterSelectCountry);
      }
      if (selectedSectors.isEmpty) {
        errors.add(
          AppLocalizations.of(context)!.businessRegisterSelectBusinessCategory,
        );
      }
    }

    if (_step == 1) {
      if (_validateEmail(_email.text) != null) {
        errors.add(
          AppLocalizations.of(context)!.businessRegisterEnterValidEmail,
        );
      }
      if (_validatePhone(_phone.text) != null) {
        errors.add(
          AppLocalizations.of(context)!.businessRegisterPhoneIncomplete,
        );
      }
      if (_selectedAdmin1 == null) {
        errors.add(
          AppLocalizations.of(context)!.businessRegisterSelectCityProvince,
        );
      }
      if (_selectedAdmin2 == null) {
        errors.add(
          AppLocalizations.of(context)!.businessRegisterSelectDistrict,
        );
      }
      if (_addressLine.text.trim().isEmpty) {
        errors.add(
          AppLocalizations.of(context)!.businessRegisterBusinessAddressRequired,
        );
      }
    }

    if (_step == 2) {
      if (_country == "Turkey") {
        if (_taxPlateUrl == null ||
            _tradeRegistryUrl == null ||
            _signatureDocUrl == null) {
          errors.add(
            AppLocalizations.of(
              context,
            )!.businessRegisterAllLegalDocumentsRequired,
          );
        }
      }
      if (_country == "Turkey") {
        if (!_taxLocked || !_mersisLocked) {
          errors.add(
            AppLocalizations.of(
              context,
            )!.businessRegisterDocumentsVerifiedBeforeContinuing,
          );
        }
      }
    }

    if (_step == 3) {
      if (!_agreeTerms) {
        errors.add(
          AppLocalizations.of(context)!.businessRegisterAcceptPlatformTerms,
        );
      }
      if (!_agreeLegalResponsibility) {
        errors.add(
          AppLocalizations.of(
            context,
          )!.businessRegisterAcceptLegalResponsibility,
        );
      }
    }

    return errors;
  }

  void _showValidationDialog(List<String> errors) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          AppLocalizations.of(context)!.businessRegisterFixHighlightedFields,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(child: Text(errors.join("\n"))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.businessRegisterOk),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _bootstrapLocations());
    // _listenForOcrResults();
  }

  Future<void> _bootstrapLocations() async {
    if (!mounted) return;
    final failedToLoadCountries = AppLocalizations.of(
      context,
    )!.businessRegisterFailedToLoadCountries;

    setState(() {
      _loadingCountries = true;
    });

    try {
      // ✅ 1. INIT REPOSITORY (خیلی مهم)
      final cache = await LocationCache.open();
      if (!mounted) return;

      _locationRepo = LocationRepository(cache: cache);

      // ✅ 2. FETCH COUNTRIES (direct Firestore)
      final snapshot = await FirebaseFirestore.instance
          .collection("countries")
          .get();

      final List<Country> list = snapshot.docs.map((d) {
        final data = d.data();

        return Country(
          code: data["code"] ?? d.id,
          name: data["name"] ?? "",
          dialCode: data["dial_code"] ?? "",
          enabled: data["enabled"] ?? true,
          sort: data["sort"] ?? 0,
        );
      }).toList();

      debugPrint("🌍 COUNTRIES MAPPED: ${list.length}");

      // ✅ 3. SET STATE
      setState(() {
        _countries = list;

        final tr = list.where((c) => c.code == "TR").toList();

        _selectedCountryCode = tr.isNotEmpty
            ? "TR"
            : (list.isNotEmpty ? list.first.code : null);

        _country = _selectedCountryCode == "TR"
            ? "Turkey"
            : (_selectedCountryCode == "DE"
                  ? "Germany"
                  : (_selectedCountryCode == "US"
                        ? "USA"
                        : (_selectedCountryCode ?? "Turkey")));

        _loadingCountries = false;
      });

      // ✅ 4. LOAD ADMIN1 (cities)
      if (_selectedCountryCode != null) {
        await _loadAdmin1(_selectedCountryCode!);
      }
    } catch (e) {
      debugPrint("❌ LOCATION ERROR: $e");

      if (!mounted) return;

      setState(() {
        _loadingCountries = false;
      });

      _snack(failedToLoadCountries);
    }
  }

  Future<void> _loadAdmin1(String countryCode) async {
    final failedToLoadCities = AppLocalizations.of(
      context,
    )!.businessRegisterFailedToLoadCities;

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
        onlyEnabled: false,
      );

      debugPrint("🌍 COUNTRY => $countryCode");
      debugPrint("🏙 ADMIN1 COUNT => ${list.length}");

      for (final item in list.take(5)) {
        debugPrint("CITY => ${item.name}");
      }
      debugPrint("ADMIN1 LOADED: ${list.length}");

      setState(() {
        _admin1List = list;
        _loadingAdmin1 = false;
      });
    } catch (e) {
      debugPrint("ADMIN1 ERROR: $e");
      setState(() => _loadingAdmin1 = false);
      _snack(failedToLoadCities);
    }
  }

  Future<void> _loadAdmin2(String countryCode, String admin1Id) async {
    final failedToLoadDistricts = AppLocalizations.of(
      context,
    )!.businessRegisterFailedToLoadDistricts;

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
      _snack(failedToLoadDistricts);
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_legalScrolledToEnd) {
                setModalState(() => _legalScrolledToEnd = true);
              }
            });
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  /// HEADER
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Text(
        AppLocalizations.of(
          context,
        )!.businessRegisterPlatformLegalAgreement,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),

    const SizedBox(width: 10),

    Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ToggleButtons(
            constraints: const BoxConstraints(
              minHeight: 36,
              minWidth: 42,
            ),
            isSelected: [
              _legalLang == "TR",
              _legalLang == "EN",
            ],
            onPressed: (i) {
              setModalState(() {
                _legalLang = i == 0 ? "TR" : "EN";
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("TR"),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("EN"),
              ),
            ],
          ),

          const SizedBox(width: 4),

          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close),
            onPressed: () =>
                Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  ],
),
                  ),

                  const Divider(),

                  /// 🔥 SCROLL FIX
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return NotificationListener<ScrollNotification>(
                          onNotification: (scrollInfo) {
                            final max = scrollInfo.metrics.maxScrollExtent;

                            // ✅ اگر اسکرول نداره → فعال کن
                            if (max == 0) {
                              setModalState(() => _legalScrolledToEnd = true);
                              return true;
                            }

                            // ✅ اگر رسید ته → فعال کن
                            if (scrollInfo.metrics.pixels >= max - 10) {
                              setModalState(() => _legalScrolledToEnd = true);
                            }

                            return true;
                          },
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _legalLang == "TR" ? legalTextTR : legalTextEN,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  /// BUTTON
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: _legalScrolledToEnd
                          ? () {
                              setState(() {
                                _agreeTerms = true;
                                _legalScrolledToEnd = false;
                              });

                              Navigator.of(context).pop(); // ✅ FIX
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9E1B4F),
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.businessRegisterReadAndAccept,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _detectCity() async {
    final locationPermissionDenied = AppLocalizations.of(
      context,
    )!.businessRegisterLocationPermissionDenied;
    final couldNotDetectCity = AppLocalizations.of(
      context,
    )!.businessRegisterCouldNotDetectCity;

    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack(locationPermissionDenied);
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
            (d) => d.name.toLowerCase() == detectedDistrict.toLowerCase(),
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
      _snack(couldNotDetectCity);
    }
  }

  String _businessLabel(BusinessKind kind) {
    switch (kind) {
      case BusinessKind.groomer:
        return AppLocalizations.of(context)!.businessRegisterGroomer;
      case BusinessKind.adoption_center:
        return AppLocalizations.of(context)!.adoptionCenter;
      case BusinessKind.pet_shop:
        return AppLocalizations.of(context)!.petShopTitle;
      case BusinessKind.vet:
        return AppLocalizations.of(context)!.businessRegisterVeterinaryClinic;
      case BusinessKind.trainer:
        return AppLocalizations.of(context)!.businessRegisterDogTrainer;
      case BusinessKind.hotel:
        return AppLocalizations.of(context)!.businessRegisterPetHotel;
      case BusinessKind.dog_walker:
        return AppLocalizations.of(context)!.businessRegisterDogWalker;
      case BusinessKind.breeder:
        return AppLocalizations.of(context)!.businessRegisterBreeder;
    }
  }

  String? _validateEmail(String? v) {
    final email = (v ?? "").trim();
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!regex.hasMatch(email))
      return AppLocalizations.of(context)!.businessRegisterInvalidEmail;
    return null;
  }

  String? _validatePhone(String? v) {
    final phone = (v ?? "").replaceAll(RegExp(r'\D'), '');

    // ✅ optional
    if (phone.isEmpty) return null;

    if (phone.length < 10) {
      return AppLocalizations.of(context)!.businessRegisterInvalidPhone;
    }

    return null;
  }

  String? _validateWebsite(String? v) {
    final url = (v ?? "").trim();
    if (url.isEmpty) return null;

    final withScheme = url.startsWith("http") ? url : "https://$url";
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasAuthority) {
      return AppLocalizations.of(context)!.businessRegisterInvalidWebsite;
    }
    return null;
  }

  Future<void> _openLegalText() async {
    final couldNotOpenLegalText = AppLocalizations.of(
      context,
    )!.businessRegisterCouldNotOpenLegalText;
    final url = Uri.parse("https://yourdomain.com/legal/turkey-business-terms");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _snack(couldNotOpenLegalText);
    }
  }

  Future<String> _uploadFile(File file, String kind) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("User not authenticated");
    }

    final uid = user.uid;

    final ref = FirebaseStorage.instance.ref().child(
      "business_docs/$uid/${DateTime.now().millisecondsSinceEpoch}_$kind",
    );

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

    setState(() {
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

      // 🔥🔥🔥 این مهم‌ترین خطه — اضافه کن
      _listenForOcrResults();
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

    if (selectedSectors.isEmpty) {
      _snack(
        AppLocalizations.of(
          context,
        )!.businessRegisterSelectAtLeastOneBusinessCategory,
      );
      return;
    }

    if (_addressLine.text.trim().isEmpty) {
      _snack(
        AppLocalizations.of(
          context,
        )!.businessRegisterPleaseEnterBusinessAddress,
      );
      return;
    }

    if (!_agreeTerms || !_agreeLegalResponsibility) {
      _snack(
        AppLocalizations.of(context)!.businessRegisterMustAcceptAllAgreements,
      );
      return;
    }

    // 🔐 OCR enforcement for Turkey
    if (_country == "Turkey") {
      if (!_taxLocked || !_mersisLocked) {
        _snack(
          AppLocalizations.of(
            context,
          )!.businessRegisterDocumentsVerifiedBeforeSubmission,
        );
        return;
      }
    }

    setState(() => _loading = true);

    try {
      final completedSectorData = _completedSectorDraft?.sectorData ?? {};

      // 🔥 STEP 1: CREATE BASE DRAFT
      final draft = BusinessDraft(
        sectors: selectedSectors,

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
          disclaimerVersion: "v1.0",
          disclaimerAcceptedAt: DateTime.now().toIso8601String(),
        ),

        sectorData: completedSectorData,
      );

      // 🔥 STEP 2: CALL CLOUD FUNCTION
      final callable = FirebaseFunctions.instanceFor(
        region: "europe-west3",
      ).httpsCallable("registerBusiness");

      debugPrint("LAT => $_lat");
      debugPrint("LNG => $_lng");

      final result = await callable.call({
        "sectors": selectedSectors, // 🔥 مهم (نه _businessKind)
        "draft": draft.toJson(),
        "lat": _lat,
        "lng": _lng,
        "countryCode": _selectedCountryCode,
        "admin1Id": _selectedAdmin1?.id,
        "admin2Id": _selectedAdmin2?.id,
      });

      if (!mounted) return;

      _snack(
        AppLocalizations.of(
          context,
        )!.businessRegisterApplicationSubmittedSuccessfully,
      );

      context.read<AppState>().closeProfileSubPage();
    } on FirebaseFunctionsException catch (e) {
      _snack(
        e.message ??
            AppLocalizations.of(context)!.businessRegisterSubmissionFailed,
      );
    } catch (e) {
      _snack(
        AppLocalizations.of(context)!.businessRegisterUnexpectedErrorOccurred,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _goToSectorDetails() async {
    BusinessDraft draft = BusinessDraft(
      sectors: selectedSectors,

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

      sectorData: {},
    );

    // 🔥 ترتیب مهم نیست، ولی بهتره ثابت باشه
    final orderedSectors = List<String>.from(selectedSectors);

    for (final sector in orderedSectors) {
      BusinessDraft? result;

      // 🟣 VET
      if (sector == "veterinary") {
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VetDetailsPage(
              baseDraft: draft,
              lat: _lat,
              lng: _lng,
              countryCode: _selectedCountryCode,
              admin1Id: _selectedAdmin1?.id,
              admin2Id: _selectedAdmin2?.id,
            ),
          ),
        );
      }
      // 🟠 PET SHOP
      else if (sector == "pet_shop") {
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PetShopDetailsPage(baseDraft: draft),
          ),
        );
      } else if (sector == "groomer") {
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroomyDetailsPage(baseDraft: draft),
          ),
        );
      } else if (sector == "adoption_center") {
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdoptionCenterDetailsPage(baseDraft: draft),
          ),
        );
      } else if (sector == "pet_hotel") {
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PetHotelRegistrationDetailsPage(baseDraft: draft),
          ),
        );
      } else if (sector == "pet_taxi") {
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PetTaxiRegistrationDetailsPage(baseDraft: draft),
          ),
        );
      }
      // 🟢 آینده
      else {
        continue;
      }

      // ❌ user cancel کرد
      if (result == null) {
        debugPrint("⚠️ user cancelled at $sector");
        return;
      }

      // ✅ merge sector data
      draft = result;
    }

    // 🔥 بعد از تکمیل همه sector ها
    setState(() {
      _completedSectorDraft = draft;
      _sectorCompleted = true;
      _step = 3; // برگرد به agreement
    });
  }

  Future<void> _submitWithSectorData(BusinessDraft draft) async {
    final callable = FirebaseFunctions.instanceFor(
      region: "europe-west3",
    ).httpsCallable("registerBusiness");

    await callable.call({
      "sectors": draft.sectors,
      "draft": draft.toJson(),
      "lat": _lat,
      "lng": _lng,
      "countryCode": _selectedCountryCode,
      "admin1Id": _selectedAdmin1?.id,
      "admin2Id": _selectedAdmin2?.id,
    });

    if (!mounted) return;

    _snack(
      AppLocalizations.of(
        context,
      )!.businessRegisterApplicationSubmittedSuccessfully,
    );
    context.read<AppState>().closeProfileSubPage();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg,
      child: SafeArea(
        child: Column(
          children: [
            _buildRegisterHeader(),

            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                child: Form(
                  key: _formKeys[_step],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProgressCard(),
                      const SizedBox(height: 14),
                      _buildCurrentStep(),
                    ],
                  ),
                ),
              ),
            ),

            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _stepIdentity();
      case 1:
        return _stepContact();
      case 2:
        return _stepLegal(); // فعلاً همونو نگه میداریم
      case 3:
        return _stepAgreement();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRegisterHeader() {
    const Color primary = Color(0xFF9E1B4F);
    const Color accent = Color(0xFFFFC107);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primary, Color(0xFFC2185B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _back,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
              ),
              child: const Icon(
                LucideIcons.chevronLeft,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.businessRegisterTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _stepTitle(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.86),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              "${_step + 1}/4",
              style: const TextStyle(
                color: primary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _stepTitle() {
    switch (_step) {
      case 0:
        return AppLocalizations.of(
          context,
        )!.businessRegisterStepIdentityCategories;
      case 1:
        return AppLocalizations.of(
          context,
        )!.businessRegisterStepContactLocation;
      case 2:
        return AppLocalizations.of(context)!.businessRegisterStepLegalDocuments;
      case 3:
        return AppLocalizations.of(
          context,
        )!.businessRegisterStepAgreementConfirmation;
      default:
        return "";
    }
  }

  Widget _buildProgressCard() {
    const Color primary = Color(0xFF9E1B4F);
    const Color accent = Color(0xFFFFC107);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (_step + 1) / 4,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: List.generate(4, (index) {
              final active = index <= _step;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? primary : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "${index + 1}",
                    style: TextStyle(
                      color: active ? Colors.white : Colors.grey.shade500,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    const Color primary = Color(0xFF9E1B4F);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _loading ? null : _back,
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: const BorderSide(color: primary),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.businessRegisterBack,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _loading
                  ? null
                  : () {
                      if (_step < 3) {
                        _next();
                      } else {
                        if (_sectorCompleted) {
                          _submit();
                        } else {
                          _goToSectorDetails();
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _step < 3
                          ? AppLocalizations.of(
                              context,
                            )!.businessRegisterContinue
                          : (_sectorCompleted
                                ? AppLocalizations.of(
                                    context,
                                  )!.businessRegisterSubmitApplication
                                : AppLocalizations.of(
                                    context,
                                  )!.businessRegisterCompleteSectorDetails),
                      style: const TextStyle(fontWeight: FontWeight.w900),
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

  InputDecoration _inputDecoration(
    String label, {
    IconData? icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade100,

      prefixIcon: icon != null
          ? Icon(icon, color: const Color(0xFF9E1B4F))
          : null,

      suffixIcon: suffixIcon,

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
      children: [
        _sectionCard(
          title: AppLocalizations.of(context)!.businessRegisterBusinessIdentity,
          subtitle: AppLocalizations.of(
            context,
          )!.businessRegisterBusinessIdentitySubtitle,
          icon: LucideIcons.store,
          child: Column(
            children: [
              TextFormField(
                controller: _legalName,
                decoration: _inputDecoration(
                  AppLocalizations.of(
                    context,
                  )!.businessRegisterLegalCompanyName,
                  icon: LucideIcons.badgeCheck,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? AppLocalizations.of(context)!.businessRegisterRequired
                    : null,
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _displayName,
                decoration: _inputDecoration(
                  AppLocalizations.of(
                    context,
                  )!.businessRegisterPublicDisplayName,
                  icon: LucideIcons.sparkles,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? AppLocalizations.of(context)!.businessRegisterRequired
                    : null,
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedCountryCode,
                decoration: _inputDecoration(
                  AppLocalizations.of(context)!.businessRegisterCountry,
                  icon: LucideIcons.globe2,
                ),
                items: _countries
                    .map(
                      (c) =>
                          DropdownMenuItem(value: c.code, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: _loadingCountries
                    ? null
                    : (v) async {
                        if (v == null) return;

                        setState(() {
                          _selectedCountryCode = v;
                          _country = v == "TR"
                              ? "Turkey"
                              : v == "DE"
                              ? "Germany"
                              : v == "US"
                              ? "USA"
                              : v;
                        });

                        await _loadAdmin1(v);
                      },
                validator: (v) => v == null
                    ? AppLocalizations.of(context)!.businessRegisterRequired
                    : null,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        _sectionCard(
          title: AppLocalizations.of(
            context,
          )!.businessRegisterBusinessCategories,
          subtitle: AppLocalizations.of(
            context,
          )!.businessRegisterBusinessCategoriesSubtitle,
          icon: LucideIcons.layoutGrid,
          child: _sectorSelector(),
        ),
      ],
    );
  }

  // ─────────────────────────────
  // STEP 2
  // ─────────────────────────────
  Widget _stepContact() {
    return _sectionCard(
      title: AppLocalizations.of(context)!.businessRegisterContactLocation,
      subtitle: AppLocalizations.of(
        context,
      )!.businessRegisterContactLocationSubtitle,
      icon: LucideIcons.mapPin,
      child: Column(
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration(
              AppLocalizations.of(context)!.emailLabel,
              icon: LucideIcons.mail,
            ),
            validator: _validateEmail,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration(
              "${AppLocalizations.of(context)!.businessRegisterPhone} (Optional)",
              icon: LucideIcons.phone,
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration(
              "WhatsApp",
              icon: LucideIcons.messageCircle,
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _website,
            keyboardType: TextInputType.url,
            decoration: _inputDecoration(
              AppLocalizations.of(context)!.businessRegisterWebsiteOptional,
              icon: LucideIcons.link,
            ),
            validator: _validateWebsite,
          ),

          const SizedBox(height: 12),

          // 🟣 CITY
          DropdownButtonFormField<Admin1>(
            value: _selectedAdmin1,
            decoration: _inputDecoration(
              _loadingAdmin1
                  ? AppLocalizations.of(context)!.businessRegisterLoadingCities
                  : AppLocalizations.of(context)!.businessRegisterCityProvince,
              icon: LucideIcons.building2,
            ),
            items: _admin1List
                .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                .toList(),
            onChanged: _loadingAdmin1
                ? null
                : (v) async {
                    if (v == null || _selectedCountryCode == null) return;

                    setState(() {
                      _selectedAdmin1 = v;
                      _city.text = v.name;
                    });

                    await _loadAdmin2(_selectedCountryCode!, v.id);
                  },
            validator: (v) => v == null
                ? AppLocalizations.of(context)!.businessRegisterRequired
                : null,
          ),

          const SizedBox(height: 12),

          // 🟡 DISTRICT
          DropdownButtonFormField<Admin2>(
            value: _selectedAdmin2,
            decoration: _inputDecoration(
              _loadingAdmin2
                  ? AppLocalizations.of(
                      context,
                    )!.businessRegisterLoadingDistricts
                  : AppLocalizations.of(context)!.businessRegisterDistrict,
              icon: LucideIcons.map,
            ),
            items: _admin2List
                .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                .toList(),
            onChanged: _loadingAdmin2
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() {
                      _selectedAdmin2 = v;
                      _district.text = v.name;
                    });
                  },
            validator: (v) => v == null
                ? AppLocalizations.of(context)!.businessRegisterRequired
                : null,
          ),

          const SizedBox(height: 12),

          // 🟢 ADDRESS (FIXED ✅)
          _AddressField(
            controller: _addressLine,
            apiKey: ApiKeys.google,
            onLatLng: (lat, lng) {
              setState(() {
                _lat = double.tryParse(lat ?? "");
                _lng = double.tryParse(lng ?? "");
              });
            },
            decoration: _inputDecoration(
              AppLocalizations.of(context)!.businessRegisterBusinessAddress,
              icon: LucideIcons.navigation,
            ),
          ),

          const SizedBox(height: 12),

          // 🔵 ACTION BUTTONS
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _detectCity,
                  icon: const Icon(LucideIcons.locateFixed, size: 18),
                  label: Text(
                    AppLocalizations.of(context)!.businessRegisterDetectCity,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9E1B4F),
                    side: const BorderSide(color: Color(0xFF9E1B4F)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _snack(
                      AppLocalizations.of(
                        context,
                      )!.businessRegisterMapPickerComingSoon,
                    );
                  },
                  icon: const Icon(LucideIcons.mapPin, size: 18),
                  label: Text(
                    AppLocalizations.of(context)!.businessRegisterPickLocation,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9E1B4F),
                    side: const BorderSide(color: Color(0xFF9E1B4F)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_lat != null && _lng != null) ...[
            const SizedBox(height: 12),
            _infoPill(
              icon: LucideIcons.checkCircle2,
              text: AppLocalizations.of(
                context,
              )!.businessRegisterLocationSelected,
              color: Colors.green,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoPill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
            AppLocalizations.of(context)!.businessRegisterTaxPlate,
            _taxPlateUrl,
            () => _pickDoc("tax"),
          ),

          _docCard(
            AppLocalizations.of(context)!.businessRegisterTradeRegistryGazette,
            _tradeRegistryUrl,
            () => _pickDoc("registry"),
          ),

          _docCard(
            AppLocalizations.of(
              context,
            )!.businessRegisterAuthorizedSignatureDocument,
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
                ),
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
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.businessRegisterTaxNumberVkn,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _taxNumberController,
                  enabled: !_taxLocked,
                  keyboardType: TextInputType.number,
                  inputFormatters: [VknInputFormatter()],
                  decoration: _inputDecoration(
                    AppLocalizations.of(
                      context,
                    )!.businessRegisterAutoFilledFromDocument,
                  ),
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
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      )!.businessRegisterDocumentVerificationInconsistencies,
                      style: const TextStyle(color: Colors.orange),
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
                ),
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
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.businessRegisterMersisNumber,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                _infoPill(
                  icon: Icons.lock,
                  text: AppLocalizations.of(
                    context,
                  )!.businessRegisterDocumentsSecurelyEncrypted,
                  color: Colors.blue,
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: _mersisNumberController,
                  enabled: !_mersisLocked,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    _mersisLocked
                        ? AppLocalizations.of(
                            context,
                          )!.businessRegisterVerifiedFromDocument
                        : AppLocalizations.of(
                            context,
                          )!.businessRegisterAutoFilledAfterVerification,
                  ),
                  validator: (v) {
                    if (_tradeRegistryUrl == null) {
                      return AppLocalizations.of(
                        context,
                      )!.businessRegisterUploadTradeRegistryFirst;
                    }
                    if (!_mersisLocked) {
                      return AppLocalizations.of(
                        context,
                      )!.businessRegisterWaitingForDocumentVerification;
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
              decoration: _inputDecoration(
                AppLocalizations.of(context)!.businessRegisterSteuernummer,
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return AppLocalizations.of(
                    context,
                  )!.businessRegisterTaxNumberRequired;
                }
                return null;
              },
            ),
          ),

          _docCard(
            AppLocalizations.of(context)!.businessRegisterGewerbeschein,
            _taxPlateUrl,
            () => _pickDoc("gewerbe"),
          ),

          _docCard(
            AppLocalizations.of(context)!.businessRegisterHandelsregisterauszug,
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
              decoration: _inputDecoration(
                AppLocalizations.of(context)!.businessRegisterEinNumber,
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return AppLocalizations.of(
                    context,
                  )!.businessRegisterEinNumberRequired;
                }
                return null;
              },
            ),
          ),

          _docCard(
            AppLocalizations.of(context)!.businessRegisterBusinessLicense,
            _taxPlateUrl,
            () => _pickDoc("license"),
          ),

          _docCard(
            AppLocalizations.of(context)!.businessRegisterIrsEinDocument,
            _tradeRegistryUrl,
            () => _pickDoc("ein"),
          ),
          if (_ocrStatus == "processing")
            _infoPill(
              icon: Icons.hourglass_top,
              text: AppLocalizations.of(
                context,
              )!.businessRegisterProcessingDocument,
              color: Colors.orange,
            ),

          if (_ocrStatus == "verified")
            _infoPill(
              icon: Icons.verified,
              text: AppLocalizations.of(
                context,
              )!.businessRegisterDocumentVerifiedSuccessfully,
              color: Colors.green,
            ),

          if (_ocrStatus == "failed")
            _infoPill(
              icon: Icons.error_outline,
              text: AppLocalizations.of(
                context,
              )!.businessRegisterCouldNotReadDocument,
              color: Colors.red,
            ),
        ],
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    IconData? icon,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9E1B4F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFF9E1B4F)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _sectorSelector() {
    final sectors = [
      {
        "id": "veterinary",
        "title": AppLocalizations.of(context)!.businessRegisterVeterinary,
        "icon": LucideIcons.stethoscope,
      },
      {
        "id": "pet_shop",
        "title": AppLocalizations.of(context)!.petShopTitle,
        "icon": LucideIcons.shoppingBag,
      },
      {
        "id": "groomer",
        "title": AppLocalizations.of(context)!.businessRegisterGroomy,
        "icon": LucideIcons.scissors,
      },
      {
        "id": "pet_hotel",
        "title": AppLocalizations.of(context)!.businessRegisterPetHotel,
        "icon": LucideIcons.hotel,
      },
      {
        "id": "pet_taxi",
        "title": AppLocalizations.of(context)!.homePetTaxiTitle,
        "icon": LucideIcons.car,
      },
      {
        "id": "adoption_center",
        "title": AppLocalizations.of(context)!.adoptionCenter,
        "icon": LucideIcons.heartHandshake,
      },
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: sectors.map((s) {
        final id = s["id"] as String;
        final selected = selectedSectors.contains(id);

        return GestureDetector(
          onTap: () {
            setState(() {
              selected ? selectedSectors.remove(id) : selectedSectors.add(id);
              _sectorCompleted = false;
              _completedSectorDraft = null;
            });
          },
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF9E1B4F) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  s["icon"] as IconData,
                  color: selected ? Colors.white : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s["title"] as String,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
          AppLocalizations.of(context)!.businessRegisterStepOfFour(_step + 1),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.businessRegisterLegalConfirmation,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),

          const SizedBox(height: 14),

          /// 🟣 TERMS CHECKBOX
          CheckboxListTile(
            value: _agreeTerms,
            onChanged: (v) {
              if (v == true) {
                _openLegalSheet(); // 👈 مجبورش می‌کنیم بخونه
              } else {
                setState(() => _agreeTerms = false);
              }
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              AppLocalizations.of(context)!.businessRegisterAcceptTermsKvkk,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),

            /// 🔥 SUBTITLE FIXED
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),

                /// داخل اپ
                GestureDetector(
                  onTap: _openLegalSheet,
                  child: Text(
                    AppLocalizations.of(context)!.businessRegisterReadInsideApp,
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: Colors.blue,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                /// لینک واقعی (FIXED ❗)
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse(
                      "https://petsupo.com/kvkk-aydinlatma-metni",
                    );
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  },
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.businessRegisterOpenOfficialLegalPage,
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: Colors.blue,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                /// نسخه قانونی
                Text(
                  AppLocalizations.of(context)!.businessRegisterLegalVersion,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),

          /// 🟢 TRUST UX
          const SizedBox(height: 8),
          _infoPill(
            icon: Icons.security,
            text: AppLocalizations.of(
              context,
            )!.businessRegisterAgreementSecurelyStored,
            color: Colors.green,
          ),

          const SizedBox(height: 12),

          /// 🔴 LEGAL RESPONSIBILITY
          CheckboxListTile(
            value: _agreeLegalResponsibility,
            onChanged: (v) =>
                setState(() => _agreeLegalResponsibility = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              AppLocalizations.of(
                context,
              )!.businessRegisterLegalResponsibilityDeclaration,
              style: const TextStyle(fontWeight: FontWeight.w500),
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
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
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
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  url == null
                      ? AppLocalizations.of(context)!.businessRegisterRequired
                      : AppLocalizations.of(context)!.businessRegisterUploaded,
                  style: TextStyle(
                    fontSize: 12,
                    color: url == null ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              if (url != null) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(
                      AppLocalizations.of(
                        context,
                      )!.businessRegisterReplaceDocument,
                    ),
                    content: Text(
                      AppLocalizations.of(
                        context,
                      )!.businessRegisterReplaceDocumentConfirmation,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(AppLocalizations.of(context)!.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          AppLocalizations.of(context)!.businessRegisterReplace,
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;

                setState(() {
                  _ocrStatus = "idle";
                  _taxLocked = false;
                  _mersisLocked = false;
                });
              }

              onTap();
            },
            child: Text(
              url == null
                  ? AppLocalizations.of(context)!.businessRegisterUpload
                  : AppLocalizations.of(context)!.businessRegisterReplace,
            ),
          ),
        ],
      ),
    );
  }

  void _listenForOcrResults() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint("❌ USER IS NULL");
      return;
    }

    // ✅ اول تعریف
    final uid = user.uid;

    // ✅ بعد استفاده
    debugPrint("🔥 AUTH UID => $uid");

    FirebaseFirestore.instance
        .collection("businessDrafts")
        .doc(uid)
        .snapshots()
        .listen((doc) {
          if (!doc.exists) {
            debugPrint("📭 NO DRAFT YET FOR UID: $uid");
            return;
          }

          final data = doc.data();
          if (data == null) return;

          final verification = data["verification"];
          final ocr = verification is Map ? verification["ocr"] : null;

          final tax = (ocr is Map) ? ocr["extractedTaxNumber"] : null;
          final mersis = (ocr is Map) ? ocr["extractedMersisNumber"] : null;

          if (!mounted) return;

          setState(() {
            bool success = false;

            if (tax != null && tax.toString().isNotEmpty) {
              _taxNumberController.text = tax.toString();
              _taxLocked = true;
              success = true;
            }

            if (mersis != null && mersis.toString().isNotEmpty) {
              _mersisNumberController.text = mersis.toString();
              _mersisLocked = true;
              success = true;
            }

            _ocrStatus = success ? "verified" : "failed";
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
  final FocusNode _focus = FocusNode(skipTraversal: true);

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
      },
    );
  }
}
