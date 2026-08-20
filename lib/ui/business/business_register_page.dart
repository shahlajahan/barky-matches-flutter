// lib/ui/business/business_register_page.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:barky_matches_fixed/services/location_permission_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import '../../app_state.dart';
import '../../theme/app_theme.dart';
import '../../models/business_draft.dart';
import '../../models/company_type.dart';
import '../../models/business_document_requirements.dart';

import '../../data/location_repository.dart';
import '../../data/location_models.dart';
import '../../data/location_cache.dart';

import '../../ui/formatters/vkn_input_formatter.dart';
import '../../config/api_keys.dart';
import '../../services/web_google_location_service.dart';

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
  // COMPANY TYPE (legal entity structure — controls which of the legal
  // documents below are required; distinct from the `businessType`
  // field used elsewhere for the service sector/category)
  // ─────────────────────────────
  CompanyType? _companyType;

  TurkeyBusinessDocumentRequirements get _documentRequirements =>
      TurkeyBusinessDocumentRequirements.forCompanyType(_companyType);

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

  final bool _ocrVerified = false;
  String _ocrStatus = "idle"; // idle | processing | verified | failed
  final List<String> _riskFlags = [];

  bool _taxLocked = false;
  bool _mersisLocked = false;
  bool _documentsVerified = false;
  bool _verificationSyncInFlight = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _ocrSubscription;

  bool get _isPetTaxiRegistration =>
      selectedSectors.length == 1 && selectedSectors.contains('pet_taxi');

  bool _sectorCompleted = false;
  BusinessDraft? _completedSectorDraft;

  List<String> _collectStepErrors() {
    final errors = <String>[];

    if (_step == 0) {
      if (_companyType == null) {
        errors.add(
          AppLocalizations.of(context)!.businessRegisterCompanyTypeRequired,
        );
      }
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
        if (_isPetTaxiRegistration && _taxPlateUrl == null) {
          errors.add(
            AppLocalizations.of(context)!.businessRegisterTaxPlateRequired,
          );
        } else if (!_isPetTaxiRegistration &&
            (_taxPlateUrl == null ||
                (_documentRequirements.requiresTradeRegistryGazette &&
                    _tradeRegistryUrl == null) ||
                _signatureDocUrl == null)) {
          errors.add(
            AppLocalizations.of(
              context,
            )!.businessRegisterAllLegalDocumentsRequired,
          );
        }
      }
      if (_country == "Turkey" && !_isPetTaxiRegistration) {
        if (!_documentsVerified || !_taxLocked || !_mersisLocked) {
          errors.add(
            AppLocalizations.of(
              context,
            )!.businessRegisterDocumentsVerifiedBeforeContinuing,
          );
        }
      }
      if (_country == "Turkey" && _isPetTaxiRegistration) {
        if (_taxNumberController.text.trim().isEmpty) {
          errors.add(
            AppLocalizations.of(context)!.businessRegisterTaxNumberRequired,
          );
        }
        if (_mersisNumberController.text.trim().isEmpty) {
          errors.add(
            AppLocalizations.of(context)!.businessRegisterMersisNumberRequired,
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
    _listenForOcrResults();
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
    _ocrSubscription?.cancel();
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
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.languageCodeTr,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.languageCodeEn,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(width: 4),

                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(),
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
      final allowed = await LocationPermissionService.ensurePermission(
        context,
        title: AppLocalizations.of(
          context,
        )!.businessRegisterDetectLocationTitle,
        message: AppLocalizations.of(
          context,
        )!.businessRegisterDetectLocationMessage,
      );
      if (!allowed) {
        _snack(locationPermissionDenied);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      String detectedCity;
      String detectedDistrict;
      if (kIsWeb) {
        final location = await const WebGoogleLocationService().reverseGeocode(
          position.latitude,
          position.longitude,
        );
        if (location == null) {
          throw StateError('Web reverse geocoding returned no location.');
        }
        detectedCity = location.city ?? '';
        detectedDistrict = location.district ?? '';
      } else {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isEmpty) {
          throw StateError('Reverse geocoding returned no placemark.');
        }
        final place = placemarks.first;
        detectedCity = (place.administrativeArea ?? '').trim();
        detectedDistrict = (place.subAdministrativeArea ?? '').trim();
      }

      if (!mounted) return;
      await _selectDetectedCity(detectedCity, detectedDistrict);
      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
    } catch (error, stackTrace) {
      debugPrint('Detect City failed: $error\n$stackTrace');
      _snack(couldNotDetectCity);
    }
  }

  Future<void> _selectDetectedCity(String city, String district) async {
    final countryCode = _selectedCountryCode;
    if (_admin1List.isEmpty || countryCode == null || city.trim().isEmpty) {
      return;
    }

    final normalizedCity = city.trim().toLowerCase();
    Admin1? cityMatch;
    for (final candidate in _admin1List) {
      final name = candidate.name.trim().toLowerCase();
      if (name == normalizedCity ||
          name.contains(normalizedCity) ||
          normalizedCity.contains(name)) {
        cityMatch = candidate;
        break;
      }
    }
    if (cityMatch == null) return;
    final selectedCity = cityMatch;

    await _loadAdmin2(countryCode, selectedCity.id);
    if (!mounted) return;

    final normalizedDistrict = district.trim().toLowerCase();
    Admin2? districtMatch;
    if (normalizedDistrict.isNotEmpty) {
      for (final candidate in _admin2List) {
        final name = candidate.name.trim().toLowerCase();
        if (name == normalizedDistrict ||
            name.contains(normalizedDistrict) ||
            normalizedDistrict.contains(name)) {
          districtMatch = candidate;
          break;
        }
      }
    }

    setState(() {
      _selectedAdmin1 = selectedCity;
      _city.text = selectedCity.name;
      if (districtMatch != null) {
        _selectedAdmin2 = districtMatch;
        _district.text = districtMatch.name;
      }
    });
  }

  Future<void> _pickLocationOnWeb() async {
    final initial = LatLng(_lat ?? 41.0082, _lng ?? 28.9784);
    final selected = await showDialog<LatLng>(
      context: context,
      builder: (_) => _WebLocationPickerDialog(initialLocation: initial),
    );
    if (!mounted || selected == null) return;

    setState(() {
      _lat = selected.latitude;
      _lng = selected.longitude;
    });

    try {
      final location = await const WebGoogleLocationService().reverseGeocode(
        selected.latitude,
        selected.longitude,
      );
      if (!mounted || location == null) return;
      if (location.formattedAddress.isNotEmpty) {
        _addressLine.text = location.formattedAddress;
      }
      await _selectDetectedCity(location.city ?? '', location.district ?? '');
    } catch (error, stackTrace) {
      debugPrint('Pick Location reverse geocoding failed: $error\n$stackTrace');
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
    if (!regex.hasMatch(email)) {
      return AppLocalizations.of(context)!.businessRegisterInvalidEmail;
    }
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

  Future<String> _uploadNativeFile(
    File file,
    String kind,
    String fileName,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("User not authenticated");
    }

    final uid = user.uid;
    final extension = fileName.split('.').last.toLowerCase();

    final ref = FirebaseStorage.instance.ref().child(
      "business_docs/$uid/${DateTime.now().millisecondsSinceEpoch}_$kind.$extension",
    );

    debugPrint(
      '📤 Firebase upload started: kind=$kind filename=$fileName mode=putFile',
    );
    await ref.putFile(
      file,
      SettableMetadata(
        contentType: _documentContentType(fileName),
        customMetadata: {'documentKind': kind},
      ),
    );
    debugPrint('✅ Firebase upload completed: kind=$kind filename=$fileName');
    final url = await ref.getDownloadURL();
    debugPrint(
      '🔗 Download URL received: kind=$kind filename=$fileName url=$url',
    );
    return url;
  }

  Future<String> _uploadWebFile(PlatformFile platformFile, String kind) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final bytes = platformFile.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw StateError(
        'The browser returned no bytes for ${platformFile.name}',
      );
    }

    final safeName = platformFile.name.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final ref = FirebaseStorage.instance.ref().child(
      'business_docs/${user.uid}/'
      '${DateTime.now().millisecondsSinceEpoch}_${kind}_$safeName',
    );

    debugPrint(
      '📤 Firebase upload started: kind=$kind '
      'filename=${platformFile.name} mode=putData bytes=${bytes.length}',
    );
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: _documentContentType(platformFile.name),
        customMetadata: {'documentKind': kind},
      ),
    );
    debugPrint(
      '✅ Firebase upload completed: kind=$kind '
      'filename=${platformFile.name}',
    );
    final url = await ref.getDownloadURL();
    debugPrint(
      '🔗 Download URL received: kind=$kind '
      'filename=${platformFile.name} url=$url',
    );
    return url;
  }

  Future<void> _pickDoc(String kind) async {
    debugPrint('🖱️ Upload button pressed: kind=$kind');

    String url;
    try {
      if (kIsWeb) {
        debugPrint('📂 File picker opened: kind=$kind platform=web');
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
          allowMultiple: false,
          withData: true,
        );
        if (result == null || result.files.isEmpty) {
          debugPrint('↩️ File picker closed without selection: kind=$kind');
          return;
        }

        final platformFile = result.files.first;
        final bytesLength = platformFile.bytes?.length;
        debugPrint('📄 File selected: kind=$kind platform=web');
        debugPrint('📄 filename=${platformFile.name}');
        debugPrint('📄 size=${platformFile.size}');
        debugPrint('📄 bytes length=${bytesLength ?? 0}');
        if (bytesLength == null || bytesLength == 0) {
          throw StateError(
            'Selected Web file has no bytes: ${platformFile.name}',
          );
        }

        if (mounted) {
          setState(() {
            _loading = true;
            _ocrStatus = 'processing';
          });
        }
        url = await _uploadWebFile(platformFile, kind);
      } else {
        debugPrint('📂 File picker opened: kind=$kind platform=native');
        final xf = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (xf == null) {
          debugPrint('↩️ File picker closed without selection: kind=$kind');
          return;
        }

        final size = await xf.length();
        debugPrint('📄 File selected: kind=$kind platform=native');
        debugPrint('📄 filename=${xf.name}');
        debugPrint('📄 size=$size');
        debugPrint('📄 bytes length=not loaded (native putFile)');
        if (mounted) {
          setState(() {
            _loading = true;
            _ocrStatus = 'processing';
          });
        }
        url = await _uploadNativeFile(File(xf.path), kind, xf.name);
      }
    } catch (error, stackTrace) {
      debugPrint('❌ Document upload failed: kind=$kind error=$error');
      debugPrint('$stackTrace');
      if (mounted) {
        setState(() => _loading = false);
        _snack(AppLocalizations.of(context)!.somethingWentWrong);
      }
      return;
    }

    try {
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

  String _documentContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'application/octet-stream',
    };
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
    if (_country == "Turkey" && !_isPetTaxiRegistration) {
      if (!_documentsVerified || !_taxLocked || !_mersisLocked) {
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
          companyType: _companyType?.toFirestore(),
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
        companyType: _companyType?.toFirestore(),
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
  // COMPANY TYPE — asked first, before any document-upload step. Controls
  // which legal documents are required later in the flow (see
  // _documentRequirements / _stepLegal). Remains editable until final
  // submission; persisted to businessDrafts/{uid} so it survives a
  // draft reopen (see _onCompanyTypeSelected and _listenForOcrResults).
  // ─────────────────────────────
  Widget _companyTypeCard() {
    final l10n = AppLocalizations.of(context)!;
    final options = <(CompanyType, String)>[
      (
        CompanyType.soleProprietorship,
        l10n.businessRegisterCompanyTypeSoleProprietorship,
      ),
      (
        CompanyType.limitedCompany,
        l10n.businessRegisterCompanyTypeLimitedCompany,
      ),
      (
        CompanyType.jointStockCompany,
        l10n.businessRegisterCompanyTypeJointStockCompany,
      ),
    ];

    return _sectionCard(
      title: l10n.businessRegisterCompanyTypeQuestion,
      subtitle: l10n.businessRegisterCompanyTypeHelper,
      icon: LucideIcons.building2,
      child: Column(
        children: options.map((option) {
          final type = option.$1;
          final label = option.$2;
          final selected = _companyType == type;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _onCompanyTypeSelected(type),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF9E1B4F).withOpacity(0.08)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF9E1B4F)
                        : Colors.grey.shade200,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected ? const Color(0xFF9E1B4F) : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _companyTypeLabel(CompanyType type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case CompanyType.soleProprietorship:
        return l10n.businessRegisterCompanyTypeSoleProprietorship;
      case CompanyType.limitedCompany:
        return l10n.businessRegisterCompanyTypeLimitedCompany;
      case CompanyType.jointStockCompany:
        return l10n.businessRegisterCompanyTypeJointStockCompany;
    }
  }

  void _onCompanyTypeSelected(CompanyType type) {
    if (_companyType == type) return;
    setState(() => _companyType = type);
    _persistCompanyTypeToDraft(type);
  }

  /// Persists the selected company type to businessDrafts/{uid} so it
  /// survives the user closing and reopening the registration form, and so
  /// the server-side OCR verification pipeline (ocrBusinessDoc /
  /// syncBusinessDocumentVerification) can compute the correct
  /// document-verification requirement for this user without needing a
  /// MERSIS number from a sole proprietor who has no trade registry
  /// document. Best-effort: failure here does not block the form, since
  /// the value is also submitted directly with the final application.
  Future<void> _persistCompanyTypeToDraft(CompanyType type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('businessDrafts')
          .doc(user.uid)
          .set({'companyType': type.toFirestore()}, SetOptions(merge: true));
    } catch (error) {
      debugPrint('⚠️ Failed to persist companyType to draft: $error');
    }
  }

  // ─────────────────────────────
  // STEP 1
  // ─────────────────────────────
  Widget _stepIdentity() {
    return Column(
      children: [
        _companyTypeCard(),
        const SizedBox(height: 16),
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
                initialValue: _selectedCountryCode,
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
              AppLocalizations.of(context)!.businessRegisterPhoneOptional,
              icon: LucideIcons.phone,
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration(
              AppLocalizations.of(context)!.businessRegisterWhatsApp,
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
            initialValue: _selectedAdmin1,
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
            initialValue: _selectedAdmin2,
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
            countryCode: _selectedCountryCode,
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
                  onPressed: kIsWeb
                      ? _pickLocationOnWeb
                      : () {
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

          // Şahıs İşletmesi (sole proprietorship) is not required to
          // register with the Turkish Trade Registry, so it may have no
          // Ticaret Sicil Gazetesi — the card is hidden entirely, not just
          // marked optional, per the confirmed product requirement. Pet
          // taxi's existing (pre-existing, unrelated) optional-display
          // behavior is preserved unchanged.
          if (shouldShowTradeRegistryCard(
            isPetTaxiRegistration: _isPetTaxiRegistration,
            companyType: _companyType,
          ))
            _docCard(
              AppLocalizations.of(
                context,
              )!.businessRegisterTradeRegistryGazette,
              _tradeRegistryUrl,
              () => _pickDoc("registry"),
              required: !_isPetTaxiRegistration,
            ),

          _docCard(
            AppLocalizations.of(
              context,
            )!.businessRegisterAuthorizedSignatureDocument,
            _signatureDocUrl,
            () => _pickDoc("signature"),
            required: !_isPetTaxiRegistration,
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
                  validator: _isPetTaxiRegistration
                      ? (value) => value == null || value.trim().isEmpty
                            ? AppLocalizations.of(
                                context,
                              )!.businessRegisterTaxNumberRequired
                            : null
                      : null,
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
          // Hidden for a non-pet-taxi Şahıs İşletmesi: MERSIS numbers are
          // issued through Trade Registry registration, which sole
          // proprietorships are not required to have (see the trade
          // registry card above).
          // =========================
          if (shouldShowMersisSection(
            isPetTaxiRegistration: _isPetTaxiRegistration,
            companyType: _companyType,
          ))
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
                      if (_isPetTaxiRegistration) {
                        if (v == null || v.trim().isEmpty) {
                          return AppLocalizations.of(
                            context,
                          )!.businessRegisterMersisNumberRequired;
                        }
                        return null;
                      }
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

          const SizedBox(height: 10),

          // Review/summary of the selected company type — this is the
          // closest thing to a review screen this flow currently has
          // before final submission; the user can still go Back to step 0
          // to change it.
          if (_companyType != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.building2,
                    size: 18,
                    color: Color(0xFF9E1B4F),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.businessRegisterCompanyTypeLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(_companyTypeLabel(_companyType!)),
                ],
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

  Widget _docCard(
    String title,
    String? url,
    VoidCallback onTap, {
    bool required = true,
  }) {
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
                      ? (required
                            ? AppLocalizations.of(
                                context,
                              )!.businessRegisterRequired
                            : AppLocalizations.of(
                                context,
                              )!.businessRegisterOptional)
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
                  _documentsVerified = false;
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
      debugPrint('❌ OCR listener not started: user is null');
      return;
    }

    final uid = user.uid;
    debugPrint('👂 OCR verification listener started: uid=$uid');
    _ocrSubscription?.cancel();
    _ocrSubscription = FirebaseFirestore.instance
        .collection("businessDrafts")
        .doc(uid)
        .snapshots()
        .listen(
          (doc) async {
            if (!doc.exists) {
              debugPrint('📭 OCR draft does not exist yet: uid=$uid');
              return;
            }

            final data = doc.data();
            if (data == null) return;

            // Restore the previously-selected company type when reopening
            // an in-progress draft. Only applied if nothing has been
            // selected locally yet, so it never clobbers a fresher local
            // choice mid-session.
            final restoredCompanyType = CompanyType.fromString(
              data['companyType']?.toString(),
            );
            if (_companyType == null && restoredCompanyType != null) {
              _companyType = restoredCompanyType;
            }

            final verification = data["verification"];
            final ocr = verification is Map ? verification["ocr"] : null;
            final tax = (ocr is Map) ? ocr["extractedTaxNumber"] : null;
            final mersis = (ocr is Map) ? ocr["extractedMersisNumber"] : null;
            final verificationStatus = verification is Map
                ? verification['status']?.toString() ?? 'missing'
                : 'missing';
            final backendDocumentsVerified =
                verification is Map &&
                verification['documentsVerified'] == true;
            final pendingVerification =
                verification is Map &&
                verification['pendingVerification'] == true;
            final taxText = tax?.toString().trim() ?? '';
            final mersisText = mersis?.toString().trim() ?? '';
            final hasTax = RegExp(r'^\d{10}$').hasMatch(taxText);
            final hasMersis = RegExp(r'^\d{16}$').hasMatch(mersisText);
            // A non-pet-taxi Şahıs İşletmesi has no MERSIS number to
            // extract (see _documentRequirements) — the backend's own
            // documentsVerified already accounts for this (see
            // ocrBusinessDoc / syncBusinessDocumentVerification), but this
            // client-side flag is recomputed independently and must apply
            // the same rule so it doesn't stay permanently "processing".
            final verified =
                backendDocumentsVerified &&
                verificationStatus == 'verified' &&
                hasTax &&
                (!_documentRequirements.requiresMersisNumber || hasMersis);

            debugPrint(
              '🔄 OCR STATE TRANSITION: uid=$uid '
              'verificationStatus=$verificationStatus '
              'documentsVerified=$backendDocumentsVerified '
              'pendingVerification=$pendingVerification '
              'hasVkn=$hasTax hasMersis=$hasMersis',
            );

            if (!mounted) return;

            setState(() {
              if (hasTax) {
                _taxNumberController.text = taxText;
              }
              if (hasMersis) {
                _mersisNumberController.text = mersisText;
              }
              _documentsVerified = verified;
              _taxLocked = verified;
              _mersisLocked = verified;
              _ocrStatus = verified
                  ? 'verified'
                  : (verificationStatus == 'failed' ? 'failed' : 'processing');
            });

            debugPrint(
              '➡️ CONTINUE STATE: enabled=${_documentsVerified && _taxLocked && _mersisLocked} '
              'verificationStatus=$verificationStatus '
              'documentsVerified=$_documentsVerified',
            );

            if (verificationStatus == 'ocr_extracted' &&
                !backendDocumentsVerified &&
                !_verificationSyncInFlight) {
              await _syncExistingOcrVerification(uid);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('❌ OCR listener failed: $error\n$stackTrace');
          },
        );
  }

  Future<void> _syncExistingOcrVerification(String uid) async {
    _verificationSyncInFlight = true;
    debugPrint(
      '🔁 Verification synchronization requested: uid=$uid '
      'reason=ocr_complete_status_pending',
    );
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('syncBusinessDocumentVerification');
      final response = await callable.call();
      final result = response.data;
      debugPrint(
        '✅ Verification synchronization completed: uid=$uid result=$result',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '❌ Verification synchronization failed: uid=$uid '
        'error=$error\n$stackTrace',
      );
    } finally {
      _verificationSyncInFlight = false;
    }
  }
}

class _AddressField extends StatefulWidget {
  const _AddressField({
    required this.controller,
    required this.apiKey,
    required this.countryCode,
    required this.onLatLng,
    required this.decoration,
  });

  final TextEditingController controller;
  final String apiKey;
  final String? countryCode;
  final void Function(String? lat, String? lng) onLatLng;
  final InputDecoration decoration;

  @override
  State<_AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<_AddressField> {
  final FocusNode _focus = FocusNode(skipTraversal: true);
  final WebGoogleLocationService _webLocationService =
      const WebGoogleLocationService();
  Timer? _debounce;
  List<WebGooglePlacePrediction> _webPredictions = const [];
  int _requestGeneration = 0;
  late String _sessionToken = _newSessionToken();

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWebField();

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

  Widget _buildWebField() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          keyboardType: TextInputType.streetAddress,
          decoration: widget.decoration,
          onChanged: _onWebQueryChanged,
        ),
        if (_webPredictions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: Material(
              elevation: 4,
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _webPredictions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final prediction = _webPredictions[index];
                  return ListTile(
                    leading: const Icon(LucideIcons.mapPin, size: 18),
                    title: Text(prediction.description),
                    onTap: () => _selectWebPrediction(prediction),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  void _onWebQueryChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      _requestGeneration++;
      if (_webPredictions.isNotEmpty) {
        setState(() => _webPredictions = const []);
      }
      return;
    }

    final generation = ++_requestGeneration;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final predictions = await _webLocationService.autocomplete(
          trimmed,
          countryCode: widget.countryCode,
          sessionToken: _sessionToken,
        );
        if (!mounted || generation != _requestGeneration) return;
        setState(() => _webPredictions = predictions);
      } catch (error, stackTrace) {
        debugPrint('Web Places autocomplete failed: $error\n$stackTrace');
        if (!mounted || generation != _requestGeneration) return;
        setState(() => _webPredictions = const []);
      }
    });
  }

  Future<void> _selectWebPrediction(WebGooglePlacePrediction prediction) async {
    _debounce?.cancel();
    _requestGeneration++;
    setState(() => _webPredictions = const []);

    try {
      final location = await _webLocationService.placeDetails(
        prediction.placeId,
        sessionToken: _sessionToken,
      );
      if (!mounted || location == null) return;

      final address = location.formattedAddress.isNotEmpty
          ? location.formattedAddress
          : prediction.description;
      widget.controller.value = TextEditingValue(
        text: address,
        selection: TextSelection.collapsed(offset: address.length),
      );
      widget.onLatLng(
        location.latitude.toString(),
        location.longitude.toString(),
      );
      _sessionToken = _newSessionToken();
    } catch (error, stackTrace) {
      debugPrint('Web Place details failed: $error\n$stackTrace');
    }
  }

  String _newSessionToken() {
    return '${DateTime.now().microsecondsSinceEpoch}-$hashCode';
  }
}

class _WebLocationPickerDialog extends StatefulWidget {
  const _WebLocationPickerDialog({required this.initialLocation});

  final LatLng initialLocation;

  @override
  State<_WebLocationPickerDialog> createState() =>
      _WebLocationPickerDialogState();
}

class _WebLocationPickerDialogState extends State<_WebLocationPickerDialog> {
  late LatLng _selected = widget.initialLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return AlertDialog(
      title: Text(l10n.businessRegisterPickLocation),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: size.width.clamp(320, 720),
        height: size.height.clamp(320, 560),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation,
              zoom: 14,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('business-location'),
                position: _selected,
              ),
            },
            onTap: (location) => setState(() => _selected = location),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(l10n.businessRegisterOk),
        ),
      ],
    );
  }
}
