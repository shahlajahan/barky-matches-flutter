import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:barky_matches_fixed/app_state.dart' as app;
import 'package:barky_matches_fixed/ui/vet/vet_card.dart';
import 'package:barky_matches_fixed/ui/vet/vet_card_data.dart';
import 'package:barky_matches_fixed/ui/vet/vet_appointment_page.dart';
import 'dart:async';
import 'package:barky_matches_fixed/services/weather_service.dart';
import 'package:barky_matches_fixed/subscription/models/subscription_plan.dart';
import 'ui/vet/vet_details_page.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';

class VetPage extends StatefulWidget {
  const VetPage({super.key});

  @override
  State<VetPage> createState() => _VetPageState();
}

class _VetPageState extends State<VetPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  Position? _position;

  static Future<Position?>? _cachedResolveFuture;
  static Position? _cachedPosition;

  static const double _fallbackLat = 41.0103;
  static const double _fallbackLng = 28.6724;

  String _searchQuery = '';
  Timer? _searchDebounce;
  List<VetCardData> _filteredVets = [];
  List<VetCardData> _vets = [];

  int _promoIndex = 0;
  late Timer _promoTimer;
  List<String> _dynamicTips = [];

  final List<VetTip> _localTips = [
    VetTip(
      text: "🐾 Regular check-ups keep your dog healthy",
      category: "health",
    ),
    VetTip(
      text: "💉 Vaccinations are essential for prevention",
      category: "health",
    ),
    VetTip(text: "🦷 Dental care is often overlooked", category: "dental"),
    VetTip(text: "⚠️ Early diagnosis saves lives", category: "warning"),
  ];

  List<VetTip> _tips = [];
  int _tipIndex = 0;

  @override
  void initState() {
    super.initState();
    _initLocationAndTips();
    if (_cachedPosition != null) {
      _position = _cachedPosition;
      _loading = false;
    } else {
      _loading = true;
    }
    _loadTips();
    _promoTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || _dynamicTips.isEmpty) return;

      setState(() {
        _tipIndex = (_tipIndex + 1) % _dynamicTips.length;
      });
    });

    _loadVetsFromFirestore();

    _cachedResolveFuture ??= _resolveLocationSmart();

    _cachedResolveFuture!.then((pos) async {
      if (!mounted) return;

      if (pos == null) {
        if (_position == null) {
          if (!mounted) return;
          _applyFallback();
          await _loadVetsFromFirestore();
          if (!mounted) return;
        }
        return;
      }

      _cachedPosition = pos;

      setState(() {
        _position = pos;
        _loading = false;
      });

      await _loadVetsFromFirestore();
      if (!mounted) return;
    });
  }

  @override
  void dispose() {
    _promoTimer.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _initLocationAndTips() async {
    debugPrint("🔥 INIT LOCATION CALLED");
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      debugPrint("📍 VET PAGE LOCATION: ${pos.latitude}, ${pos.longitude}");

      if (!mounted) return;
      setState(() {
        _position = pos;
      });

      await _generateSmartTips(); // 🔥 این خیلی مهمه
      if (!mounted) return;
    } catch (e) {
      debugPrint("❌ location error (vet): $e");

      // حتی اگر location fail شد → tips بساز
      await _generateSmartTips();
      if (!mounted) return;
      debugPrint("🔥 FINAL TIPS: $_dynamicTips");
    }
  }

  Future<void> _generateSmartTips([Position? pos]) async {
    final position = pos ?? await Geolocator.getCurrentPosition();
    if (!mounted) return;
    final now = DateTime.now();
    final hour = now.hour;
    final appState = context.read<app.AppState>();

    final isPremium =
        appState.subscription.plan == SubscriptionPlan.premium ||
        appState.subscription.plan == SubscriptionPlan.gold;
    final apiTemp = await WeatherService.getTemperature(
      lat: position.latitude,
      lon: position.longitude,
    );
    if (!mounted) return;

    final safeTemp = apiTemp ?? _estimateTempAI(position);
    debugPrint("💳 PLAN = ${appState.subscription.plan}");
    debugPrint("👑 isPremium = $isPremium");
    debugPrint("👑 FIXED isPremium = $isPremium");
    debugPrint("👑 isPremium = $isPremium");
    debugPrint("🌡 API TEMP: $apiTemp");
    debugPrint("🧠 AI TEMP: $safeTemp");

    debugPrint("🌡 TEMP USED: $safeTemp");

    final tips = _buildAITips(temp: safeTemp, hour: hour, dogSize: "small");

    /// ⏰ TIME
    if (hour >= 7 && hour <= 10) {
      tips.add(
        SmartTip(
          text: "🌅 Morning is great for walks",
          priority: 90,
          type: "behavior",
        ),
      );
    } else if (hour >= 12 && hour <= 16) {
      tips.add(
        SmartTip(
          text: "☀️ Avoid walking during peak heat",
          priority: 95,
          type: "behavior",
        ),
      );
    } else if (hour >= 20) {
      tips.add(
        SmartTip(
          text: "🌙 Evening walk helps your dog relax",
          priority: 80,
          type: "behavior",
        ),
      );
    }

    /// 🧠 BASE
    tips.add(
      SmartTip(
        text: "💉 Regular vet checkups are essential",
        priority: 40,
        type: "health",
      ),
    );

    tips.add(
      SmartTip(
        text: "🥗 Healthy diet improves lifespan",
        priority: 40,
        type: "health",
      ),
    );

    tips.add(
      SmartTip(
        text: "🏥 20% off at Pera Vet today",
        priority: 110,
        type: "sponsored",
      ),
    );

    /// 🔥 SORT
    tips.sort((a, b) => b.priority.compareTo(a.priority));

    /// 👑 PREMIUM (بعد از همه add ها)
    final visibleTips = isPremium
        ? tips
        : tips.where((t) => t.priority >= 80).toList();

    if (!mounted) return;
    setState(() {
      _dynamicTips = visibleTips.map((e) => e.text).toList();
      _tipIndex = 0;
    });

    debugPrint("🔥 SORTED TIPS: $_dynamicTips");
  }

  double _estimateTempAI(Position? pos) {
    final now = DateTime.now();
    final month = now.month;
    final hour = now.hour;

    double baseTemp;

    /// 🌍 Season-based (Istanbul optimized)
    if (month >= 6 && month <= 8) {
      baseTemp = 30; // summer
    } else if (month >= 12 || month <= 2) {
      baseTemp = 8; // winter
    } else if (month >= 3 && month <= 5) {
      baseTemp = 18; // spring
    } else {
      baseTemp = 20; // autumn
    }

    /// 🕐 Time adjustment
    if (hour >= 12 && hour <= 16) {
      baseTemp += 3; // hottest
    } else if (hour >= 20 || hour <= 6) {
      baseTemp -= 3; // cooler
    }

    /// 📍 Optional micro-adjustment (future)
    if (pos != null) {
      if (pos.latitude > 41.05) {
        baseTemp -= 1; // slightly cooler north Istanbul
      }
    }

    return baseTemp;
  }

  List<SmartTip> _buildAITips({
    required double temp,
    required int hour,
    String? dogSize, // small / medium / large
  }) {
    final List<SmartTip> tips = [];

    /// 🔥 HEAT RISK
    if (temp > 30) {
      tips.add(
        SmartTip(
          text: "🔥 High heat — risk of heatstroke",
          priority: 100,
          type: "warning",
        ),
      );

      if (dogSize == "small") {
        tips.add(
          SmartTip(
            text: "🐶 Small dogs overheat faster",
            priority: 95,
            type: "warning",
          ),
        );
      }
    }

    /// ❄️ COLD
    if (temp < 8) {
      tips.add(
        SmartTip(
          text: "❄️ Cold weather — protect paws",
          priority: 90,
          type: "weather",
        ),
      );
    }

    /// ⏰ TIME
    if (hour >= 12 && hour <= 16) {
      tips.add(
        SmartTip(
          text: "☀️ Avoid walking during peak heat",
          priority: 95,
          type: "warning",
        ),
      );
    }

    /// 🌙 NIGHT
    if (hour >= 20) {
      tips.add(
        SmartTip(
          text: "🌙 Evening walks reduce stress",
          priority: 70,
          type: "behavior",
        ),
      );
    }

    /// 🏥 HEALTH (always)
    tips.add(
      SmartTip(
        text: "💉 Regular vet checkups are essential",
        priority: 40,
        type: "health",
      ),
    );

    return tips;
  }

  Future<void> _loadTips() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vet_tips')
          .get();
      if (!mounted) return;

      if (snapshot.docs.isNotEmpty) {
        _tips = snapshot.docs.map((doc) {
          final data = doc.data();
          return VetTip(
            text: data['text'] ?? '',
            category: data['category'] ?? 'general',
          );
        }).toList();
      } else {
        _tips = _localTips;
      }
    } catch (e) {
      _tips = _localTips;
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadVetsFromFirestore() async {
    List<VetCardData> vets = [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .where('status', isEqualTo: 'approved')
          .get();
      if (!mounted) return;

      vets = snapshot.docs
          .map((doc) {
            final data = doc.data();

            final sectors = List<String>.from(data['sectors'] ?? []);
            if (!sectors.contains('veterinary')) return null;

            final contact = Map<String, dynamic>.from(data['contact'] ?? {});
            // 🔥 COVER IMAGE LOGIC
            final coverImageUrl = (data['coverImageUrl'] ?? '').toString();
            final images = List<String>.from(data['images'] ?? []);

            final displayImage = coverImageUrl.isNotEmpty
                ? coverImageUrl
                : (images.isNotEmpty ? images.first : null);
           

            final profile = Map<String, dynamic>.from(data['profile'] ?? {});
            final sectorData = Map<String, dynamic>.from(
              data['sectorData'] ?? {},
            );

            // ✅ FIRST define veterinary
            final veterinary = Map<String, dynamic>.from(
              sectorData['veterinary'] ?? {},
            );

            // ✅ THEN use it
            final profileContent = Map<String, dynamic>.from(
              veterinary['profileContent'] ?? {},
            );
            final socialMedia = Map<String, dynamic>.from(
  profileContent['socialMedia'] ?? {},
);

final String? instagram =
    socialMedia['instagram']?.toString();

final String? website =
    socialMedia['website']?.toString();

            final String? logoUrl = profileContent['clinicLogoUrl']?.toString();
            final displayName = (profile['displayName'] ?? '').toString().trim();
            final description =
    (profileContent['bio'] ?? '')
        .toString()
        .trim();

            debugPrint("🔥 LOGO URL: $logoUrl");

            final workingHours = Map<String, dynamic>.from(
              veterinary['workingHours'] ?? {},
            );
            debugPrint("🔥 WORKING HOURS RAW: $workingHours");
            debugPrint("🔥 RAW INNER: ${workingHours['workingHours']}");
            final rawWorkingHours = workingHours['workingHours'];

            Map<String, String> workingHoursMap = {};

            if (rawWorkingHours is Map) {
              workingHoursMap = Map<String, String>.from(rawWorkingHours);
            } else if (rawWorkingHours is String &&
                rawWorkingHours.isNotEmpty) {
              workingHoursMap = {"hours": rawWorkingHours};
            }
            final services = Map<String, dynamic>.from(
              veterinary['services'] ?? {},
            );

            final city = (contact['city'] ?? '').toString().trim();
            final district = (contact['district'] ?? '').toString().trim();

            final fullAddress = [
              if (district.isNotEmpty) district,
              if (city.isNotEmpty) city,
            ].join(', ');

            final specialtyText = (profileContent['specialties'] ?? '')
                .toString()
                .trim();

            final specialties = specialtyText.isNotEmpty
                ? specialtyText
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList()
                : <String>['Veterinary'];

            final offeredServices = (services['offeredServices'] is List)
                ? List<String>.from(services['offeredServices'])
                : <String>['Check-up'];

            final lat = _extractLat(data, veterinary, contact);
            final lng = _extractLng(data, veterinary, contact);

            double? distanceKm;
            if (_position != null && lat != null && lng != null) {
              distanceKm = _distanceKm(lat, lng);
            }

            final dynamic ratingRaw = data['rating'] ?? veterinary['rating'];
            final double? rating = ratingRaw is num
                ? ratingRaw.toDouble()
                : null;

            final dynamic reviewsRaw =
                data['reviewsCount'] ?? veterinary['reviewsCount'];
            final int reviewsCount = reviewsRaw is num ? reviewsRaw.toInt() : 0;

            final String emergencyValue =
                (workingHours['emergencyService'] ?? '').toString().trim();

            final bool is24h = emergencyValue == '24_hours';
            final bool isEmergency =
                emergencyValue == 'yes' || emergencyValue == 'emergency';

            final bool isPartner =
                data['status'] == 'approved' ||
                (data['isPartner'] ?? veterinary['featuredVet'] ?? false) ==
                    true;
            debugPrint(
              '🩺 VET BUSINESS MAP → source=VetPage businessId=${doc.id} '
              'displayName=$displayName serviceCount=${offeredServices.length} '
              'selectedPricingSource=businesses/${doc.id}/sectorData.veterinary.services '
              'hasInstagram=${instagram != null && instagram.trim().isNotEmpty} '
              'descriptionLength=${description.length}',
            );
            return VetCardData(
              type: BusinessType.vet,
              id: doc.id,
              name: displayName.isNotEmpty ? displayName : 'Vet',

              city: city,
              district: district,
              address: fullAddress,

              phone: contact['phone']?.toString(),
              whatsapp:
                  contact['whatsapp']?.toString() ??
                  contact['phone']?.toString(),

              specialties: specialties,
              services: offeredServices,

              distanceKm: distanceKm,
              rating: rating,
              reviewsCount: reviewsCount,
              isPartner: isPartner,
              workingHours: workingHoursMap,
              logoUrl: logoUrl,

              description: description,

              is24h: is24h,
              isEmergency: isEmergency,
              instagram: instagram,
              website: website,
              coverImageUrl: displayImage,
              sectorData: sectorData,
              rawData: data,
            );
          })
          .whereType<VetCardData>()
          .toList();

      vets.sort((a, b) {
        final aDistance = a.distanceKm ?? 999999;
        final bDistance = b.distanceKm ?? 999999;

        final aScore = (a.rating ?? 0) * 2 - aDistance;
        final bScore = (b.rating ?? 0) * 2 - bDistance;

        return bScore.compareTo(aScore);
      });

      if (!mounted) return;

      setState(() {
        _vets = vets; // ✅ ADD
        _filteredVets = vets;
        _loading = false;
      });

      debugPrint("🐾 VETS LOADED: ${_filteredVets.length}");
    } catch (e) {
      debugPrint("❌ load vets error: $e");

      if (!mounted) return;
      setState(() {
        _loading = false;
        _filteredVets = vets;
      });
    }
  }

  double? _extractLat(
    Map<String, dynamic> root,
    Map<String, dynamic> veterinary,
    Map<String, dynamic> contact,
  ) {
    final candidates = [
      root['lat'],
      root['latitude'],
      root['location'] is Map ? root['location']['lat'] : null,
      root['location'] is Map ? root['location']['latitude'] : null,
      veterinary['lat'],
      veterinary['latitude'],
      veterinary['location'] is Map ? veterinary['location']['lat'] : null,
      veterinary['location'] is Map ? veterinary['location']['latitude'] : null,
      contact['lat'],
      contact['latitude'],
    ];

    for (final value in candidates) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  double? _extractLng(
    Map<String, dynamic> root,
    Map<String, dynamic> veterinary,
    Map<String, dynamic> contact,
  ) {
    final candidates = [
      root['lng'],
      root['longitude'],
      root['location'] is Map ? root['location']['lng'] : null,
      root['location'] is Map ? root['location']['longitude'] : null,
      veterinary['lng'],
      veterinary['longitude'],
      veterinary['location'] is Map ? veterinary['location']['lng'] : null,
      veterinary['location'] is Map
          ? veterinary['location']['longitude']
          : null,
      contact['lng'],
      contact['longitude'],
    ];

    for (final value in candidates) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final lower = query.toLowerCase();

      setState(() {
        _searchQuery = lower;

        _filteredVets = _vets.where((vet) {
          return vet.name.toLowerCase().contains(lower) ||
              vet.specialties.join(' ').toLowerCase().contains(lower) ||
              (vet.city ?? '').toLowerCase().contains(lower);
        }).toList();
      });
    });
  }

  Future<void> _openDirections(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openDirectionsByQuery(String query) async {
    if (query.trim().isEmpty) return;

    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<Position?> _resolveLocationSmart() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return null;
      if (!enabled) return null;

      var permission = await Geolocator.checkPermission();
      if (!mounted) return null;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return null;
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final last = await Geolocator.getLastKnownPosition();
      if (!mounted) return null;
      if (last != null) {
        _upgradeToBetterPositionInBackground();
        return last;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 2),
      );
      if (!mounted) return null;

      return pos;
    } catch (_) {
      return null;
    }
  }

  void _upgradeToBetterPositionInBackground() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 2),
      );
      if (!mounted) return;

      _cachedPosition = pos;
      if (!mounted) return;

      setState(() {
        _position = pos;
        _loading = false;
      });

      await _loadVetsFromFirestore();
    } catch (_) {
      // ignore
    }
  }

  void _applyFallback() {
    if (!mounted) return;
    setState(() {
      _position = Position(
        latitude: _fallbackLat,
        longitude: _fallbackLng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      _loading = false;
    });
  }

  double _distanceKm(double lat, double lng) {
    final p = _position;
    if (p == null) return 0;

    return Geolocator.distanceBetween(p.latitude, p.longitude, lat, lng) / 1000;
  }

  Future<void> _callVet(String phone) async {
    final cleaned = phone.trim();
    if (cleaned.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final appState = context.watch<app.AppState>();
    final currentUserId = appState.currentUserId;
    final selectedVet = appState.selectedVet;

    if (currentUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    /// ✅ اول appointment
    if (appState.businessSubPage == app.BusinessSubPage.appointment &&
        appState.businessAppointment != null) {
      return VetAppointmentPage(
        vet: appState.businessAppointment!,
        selectedService: appState.appointmentService,
      );
    }

    return Stack(
      children: [
        Container(
          color: const Color(0xFFFFF6F8),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: TextField(
                              onChanged: _onSearchChanged,
                              decoration: InputDecoration(
                                hintText: "Search veterinary clinics...",
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),

                          Expanded(
                            child: _filteredVets.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No veterinary clinics found.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      90,
                                    ),
                                    itemCount: _filteredVets.length,
                                    itemBuilder: (context, index) {
                                      final vetData = _filteredVets[index];

                                      final addressQuery =
                                          [vetData.name, vetData.address]
                                              .where(
                                                (e) =>
                                                    (e ?? '').trim().isNotEmpty,
                                              )
                                              .join(', ');

                                      return VetCard(
                                        data: vetData,
                                        onTap: () {
                                          debugPrint(
                                            '🟣 TAP vet=${vetData.name}',
                                          );
                                          appState.openBusinessDetails(vetData);
                                        },
                                        onCallTap:
                                            vetData.phone == null ||
                                                vetData.phone!.trim().isEmpty
                                            ? null
                                            : () => _callVet(vetData.phone!),
                                        onDirectionsTap:
                                            addressQuery.trim().isEmpty
                                            ? null
                                            : () => _openDirectionsByQuery(
                                                addressQuery,
                                              ),
                                        onWhatsAppTap: null,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildEducationBox(),
                    ),
                  ],
                ),
        ),
        if (selectedVet != null)
          Positioned.fill(
            child: VetDetailsPage(
              key: ValueKey(selectedVet.id),
              vet: selectedVet,
              onClose: () => context.read<app.AppState>().closeVetDetails(),
            ),
          ),
      ],
    );
  }

  Widget _buildEducationBox() {
    return Container(
      height: 70,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9E1B4F), Color(0xFF7A143D)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _dynamicTips.isEmpty
                ? "💉 Loading tips..."
                : _dynamicTips[_tipIndex % _dynamicTips.length],
            key: ValueKey(
              _dynamicTips.isEmpty
                  ? "fallback"
                  : _dynamicTips[_tipIndex % _dynamicTips.length],
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

class VetTip {
  final String text;
  final String category;

  VetTip({required this.text, required this.category});
}

class SmartTip {
  final String text;
  final int priority;
  final String type; // health, weather, warning

  SmartTip({required this.text, required this.priority, required this.type});
}
