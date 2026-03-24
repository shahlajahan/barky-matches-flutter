import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart' as app;
import 'package:barky_matches_fixed/ui/vet/vet_card.dart';
import 'package:barky_matches_fixed/ui/vet/vet_card_data.dart';
import 'package:barky_matches_fixed/ui/vet/vet_appointment_page.dart';




class VetPage extends StatefulWidget {
  const VetPage({super.key});

  @override
  State<VetPage> createState() => _VetPageState();
}

class _VetPageState extends State<VetPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  Position? _position;

  // ✅ Memoize: حتی اگر VetPage دوباره ساخته شد، یک resolve بیشتر نزن
  static Future<Position?>? _cachedResolveFuture;
  static Position? _cachedPosition; // آخرین position موفق

  static const _fallbackLat = 41.0103;
  static const _fallbackLng = 28.6724;

  

  final List<Map<String, dynamic>> _vets = const [
    {
      'name': 'Dr. Ayşe Yılmaz',
      'specialty': 'General Vet',
      'lat': 41.0082,
      'lng': 28.9784,
      'phone': '+905551234567',
      'address': 'Kadıköy, İstanbul',
    },
    {
      'name': 'Dr. Mehmet Özkan',
      'specialty': 'Surgeon',
      'lat': 41.0137,
      'lng': 28.9815,
      'phone': '+905551234568',
      'address': 'Sultanahmet, İstanbul',
    },
  ];

  @override
  void initState() {
    super.initState();

    // اگر قبلاً position موفق داشتیم → فوراً UI رو سریع پر کن
    if (_cachedPosition != null) {
      _position = _cachedPosition;
      _loading = false;
    } else {
      _loading = true;
    }

    // resolve رو memoize کن
    _cachedResolveFuture ??= _resolveLocationSmart();

    // نتیجه رو apply کن (اگر لازم شد)
    _cachedResolveFuture!.then((pos) {
      if (!mounted) return;
      if (pos == null) {
        // اگر هنوز position نداریم، fallback بده
        if (_position == null) _applyFallback();
        return;
      }
      _cachedPosition = pos;
      setState(() {
        _position = pos;
        _loading = false;
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


  Future<Position?> _resolveLocationSmart() async {
    try {
      // 1) سرویس روشن؟
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      // 2) permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // 3) سریع‌ترین گزینه: last known
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        // ✅ همینو برگردون تا UI سریع بالا بیاد
        // و هم‌زمان یه تلاش سبک‌تر برای دقیق‌تر انجام بده:
        _upgradeToBetterPositionInBackground();
        return last;
      }

      // 4) اگر last نبود: یه getCurrentPosition سبک‌تر (نه high)
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 2),
      );

      return pos;
    } catch (_) {
      return null;
    }
  }

  void _upgradeToBetterPositionInBackground() async {
    try {
      // فقط اگر قبلاً یک cachedPosition داریم یا UI از last استفاده کرده
      // اینجا یک تلاش “بهتر” می‌کنیم ولی با limit کوتاه تا battery/UI رو نکشه
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 2),
      );

      _cachedPosition = pos;
      if (!mounted) return;

      // اگر روی صفحه Vet هستیم، آپدیت کن؛ اگر نیستیم هم cached می‌مونه
      setState(() {
        _position = pos;
        _loading = false;
      });
    } catch (_) {
      // ignore
    }
  }

  void _applyFallback() {
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
    return Geolocator.distanceBetween(
          p.latitude,
          p.longitude,
          lat,
          lng,
        ) /
        1000;
  }

  Future<void> _callVet(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
Widget build(BuildContext context) {
  super.build(context);

  final appState = context.watch<app.AppState>();
  final currentUserId = appState.currentUserId;

  // ⏳ هنوز یوزر لود نشده
  if (currentUserId == null) {
    return const Center(child: CircularProgressIndicator());
  }

  // 🔀 TYPE D – Vet Appointment (Full Page)
  if (appState.businessSubPage == app.BusinessSubPage.appointment &&
    appState.businessAppointment != null) {
   return VetAppointmentPage(
  vet: appState.businessAppointment!,
);

  }

  // 🧱 TYPE A – Vet Tab Page
  return Container(
    color: const Color(0xFFFFF6F8),
    child: _loading
        ? const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFFC107),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _vets.length,
            itemBuilder: (context, index) {
              final vet = _vets[index];

              final km = _distanceKm(
                vet['lat'] as double,
                vet['lng'] as double,
              ).toStringAsFixed(1);

              // 📍 Address parsing
              final fullAddress = vet['address'] as String;
              final parts = fullAddress.split(',');

              final district =
                  parts.isNotEmpty ? parts.first.trim() : 'Unknown';
              final city =
                  parts.length > 1 ? parts.last.trim() : 'Istanbul';

              final vetData = VetCardData(
                id: 'local_$index',
                name: vet['name'],
                city: city,
                district: district,
                address: fullAddress,
                distanceKm: double.tryParse(km),
                specialties: [vet['specialty']],
                phone: vet['phone'],

                // 👇 Detail data
                rating: 4.6,
                reviewsCount: 128,
                isPartner: vet['name'] == 'Dr. Ayşe Yılmaz', // 🔥 فقط موقت برای تست// فعلاً یکی partner
                whatsapp: '+905551234567',
                services: const [
                  'General Check-up',
                  'Vaccination',
                  'Surgery',
                  'Dental Care',
                  'Emergency Service',
                ],
                description:
                    'Experienced veterinary clinic providing comprehensive care for pets. Equipped with modern diagnostic tools.',
                workingHours: const {
                  'Mon–Fri': '09:00 – 19:00',
                  'Saturday': '10:00 – 16:00',
                  'Sunday': 'Closed',
                },
                is24h: false,
                isEmergency: true,
              );

              return VetCard(
                data: vetData,

                // 🩺 Open overlay
                onTap: () {
                  debugPrint('🟣 TAP vet=${vetData.name} partner=${vetData.isPartner}');
appState.openBusinessDetails(vetData);
                },

                // 📞 Call
                onCallTap: vetData.phone == null
                    ? null
                    : () => _callVet(vetData.phone!),

                // 🧭 Directions
                onDirectionsTap: () {
                  _openDirections(
                    vet['lat'] as double,
                    vet['lng'] as double,
                  );
                },

                onWhatsAppTap: null,
              );
            },
          ),
  );
}

}

