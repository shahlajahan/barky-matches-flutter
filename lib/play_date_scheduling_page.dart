// lib/play_date_scheduling_page.dart
//
// ✅ CLEAN (Phase 2) – نسخه اصلاح‌شده با Cloud Function
// - فقط UI + فراخوانی Cloud Function برای ساخت درخواست
// - هیچ نوشتن مستقیم Firestore در کلاینت وجود ندارد
// - push notification از سمت بک‌اند (Cloud Function) ارسال می‌شود

import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dog.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';





class PlayDateSchedulingPage extends StatefulWidget {
  final Dog? selectedDog;        // 👈 nullable
  final List<Dog>? allDogs;      // 👈 nullable

  const PlayDateSchedulingPage({
    super.key,
    this.selectedDog,
    this.allDogs,
  });

  @override
  State<PlayDateSchedulingPage> createState() => _PlayDateSchedulingPageState();
}

class _PlayDateSchedulingPageState extends State<PlayDateSchedulingPage> {
  late AppState appState;

  static const Duration _minPlaydateLeadTime = Duration(minutes: 15);

  bool get _isPresetPark => appState.activePlaydatePark != null;

String? _lastPresetParkName;

  Dog? _selectedRequestedDog;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedLocationText;
  double? _selectedLat;
  double? _selectedLng;
  String? _selectedRequesterDogId;

  bool _sending = false;

  @override
void initState() {
  super.initState();
  appState = context.read<AppState>();

  // 🐶 اگر از DogCard وارد شده باشیم (friend dog از قبل مشخص است)
  final requestedDogId = appState.selectedRequesterDogId;
  if (requestedDogId != null) {
    final box = Hive.box<Dog>('dogsBox');
    final allDogs = box.values.toList();

    try {
      _selectedRequestedDog =
          allDogs.firstWhere((d) => d.id == requestedDogId);
    } catch (_) {
      // اگر به هر دلیلی سگ پیدا نشد، قفل نمی‌کنیم
      _selectedRequestedDog = null;
    }
  }
/*
  // 📍 اگر از Park وارد شده باشیم، لوکیشن preset می‌شود
  final park = appState.activePlaydatePark;
  if (park != null) {
    _selectedLocationText = park['name']?.toString();
    _selectedLat = (park['lat'] as num?)?.toDouble() ?? 41.0103;
_selectedLng = (park['lng'] as num?)?.toDouble() ?? 28.6724;

  }
  */
}

  Future<void> _pickDate() async {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final firstDate = DateTime(now.year, now.month, now.day);
  final lastDate = firstDate.add(const Duration(days: 365));

  final picked = await showDatePicker(
    context: context,
    initialDate: _selectedDate ?? firstDate,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          dialogTheme: DialogThemeData(
            backgroundColor: AppTheme.card,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusCard),
            ),
          ),

          colorScheme: ColorScheme.dark(
            primary: AppTheme.accent, // 🟡 روز انتخاب‌شده
            onPrimary: Colors.black,
            surface: AppTheme.card,
            onSurface: Colors.white,
          ),

          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70, // Cancel
            ),
          ),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent, // OK زرد
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radius),
              ),
            ),
          ),

          textTheme: GoogleFonts.poppinsTextTheme(
            Theme.of(context)
                .textTheme
                .apply(bodyColor: Colors.white),
          ),
        ),
        child: child!,
      );
    },
  );

  if (!mounted || picked == null) return;

  setState(() => _selectedDate = picked);
}
  Future<void> _pickTime() async {
  final l10n = AppLocalizations.of(context)!;

  final picked = await showTimePicker(
    context: context,
    initialTime: _selectedTime ?? TimeOfDay.now(),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: AppTheme.card, // 🎀 background کامل صورتی

            // ✅ عنوان سفید
            helpTextStyle: AppTheme.h2(color: Colors.white),

            // ✅ باکس عددی ساعت رنگ جدید (تیره‌تر از بکگراند)
            hourMinuteColor: AppTheme.primary.withOpacity(0.6),

            hourMinuteTextColor: Colors.white,

            // حالت انتخاب‌شده
            dayPeriodTextColor: Colors.white,
            dayPeriodColor: AppTheme.primary,

            dialBackgroundColor: Colors.white.withOpacity(0.08),
            dialTextColor: Colors.white,
            dialHandColor: AppTheme.accent, // عقربه زرد

            entryModeIconColor: Colors.white70,

            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusCard),
            ),
          ),

          colorScheme: ColorScheme.dark(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            surface: AppTheme.card,
            onSurface: Colors.white,
          ),

          // ❌ TextButton حذف شد
          textButtonTheme: TextButtonThemeData(
  style: TextButton.styleFrom(
    foregroundColor: Colors.white, // ✅ OK / Cancel سفید
    textStyle: const TextStyle(
      fontWeight: FontWeight.w600,
    ),
  ),
),

          // ✅ CTA مثل Location (card زرد)
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radius),
              ),
            ),
          ),
        ),
        child: child!,
      );
    },
  );

  if (!mounted || picked == null) return;

  setState(() => _selectedTime = picked);
}

  Future<void> _pickLocation() async {
    final l10n = AppLocalizations.of(context)!;
    LatLng fallback = const LatLng(41.0103, 28.6724); // Istanbul

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 6),
      );
      fallback = LatLng(pos.latitude, pos.longitude);
    } catch (_) {}

    String? typedText = _selectedLocationText;

    final result = await showDialog<_PickedLocation>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: typedText ?? '');
        return AlertDialog(
  backgroundColor: AppTheme.card, // 🎀 صورتی برند
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
  ),
  title: Text(
    l10n.selectLocation,
    style: AppTheme.h2(color: AppTheme.textLight),
  ),
  content: SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: ctrl,
          style: AppTheme.body(color: AppTheme.textLight),
          decoration: InputDecoration(
            labelText: l10n.locationLabel,
            labelStyle: AppTheme.caption(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) => typedText = v,
        ),

        const SizedBox(height: 16),

        /// 🗺 Pick on Map — زرد
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent, // 🟡 زرد برند
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
            ),
            onPressed: () async {
              final picked = await Navigator.push<LatLng?>(
                ctx,
                MaterialPageRoute(
                  builder: (_) =>
                      MapPickerPage(initialLocation: fallback),
                ),
              );
              if (picked == null) return;

              Navigator.pop(
                ctx,
                _PickedLocation(
                  text: typedText?.trim().isNotEmpty == true
                      ? typedText!.trim()
                      : 'Lat: ${picked.latitude}, Lng: ${picked.longitude}',
                  lat: picked.latitude,
                  lng: picked.longitude,
                ),
              );
            },
            child: Text(l10n.pickOnMap),
          ),
        ),
      ],
    ),
  ),

  /// 🔘 ACTIONS
  actionsPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

  actions: [
    TextButton(
      onPressed: () => Navigator.pop(ctx),
      child: Text(
        l10n.cancel,
        style: AppTheme.body(color: Colors.white70),
      ),
    ),

    TextButton(
  onPressed: () {
    final t = typedText?.trim();
    if (t == null || t.isEmpty) {
      Navigator.pop(ctx);
      return;
    }

    Navigator.pop(
      ctx,
      _PickedLocation(
        text: t,
        lat: _selectedLat,
        lng: _selectedLng,
      ),
    );
  },
  child: Text(
    l10n.confirm,
    style: AppTheme.body(
      color: Colors.white, // 👈 مثل OK تو TimePicker
    ),
  ),
),
  ],
);
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _selectedLocationText = result.text;
      _selectedLat = result.lat;
      _selectedLng = result.lng;
    });
  }

  DateTime? _buildScheduledDateTime() {
  if (_selectedDate == null || _selectedTime == null) return null;

  final local = DateTime(
    _selectedDate!.year,
    _selectedDate!.month,
    _selectedDate!.day,
    _selectedTime!.hour,
    _selectedTime!.minute,
  );

  return local.toUtc(); // ✅ بسیار مهم
}


  Future<void> _createRequest() async {
    final l10n = AppLocalizations.of(context)!;
    if (_sending) return;

    final appState = context.read<AppState>();
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west3')
    .httpsCallable('createPlayDateRequest');

debugPrint("🌍 Functions region: europe-west3");

debugPrint("🚀 BEFORE CALL - mounted=$mounted");

debugPrint("🔥 CREATE REQUEST DEBUG:");
debugPrint("uid(appState.currentUserId) = ${appState.currentUserId}");
debugPrint("activePlaydatePark = ${appState.activePlaydatePark}");
debugPrint("selectedRequesterDogId(appState) = ${appState.selectedRequesterDogId}");
debugPrint("_selectedRequesterDogId(local) = $_selectedRequesterDogId");
debugPrint("_selectedRequestedDog(local) = ${_selectedRequestedDog?.id} / ${_selectedRequestedDog?.name}");
debugPrint("_selectedLocationText = $_selectedLocationText");
debugPrint("_selectedLatLng = $_selectedLat , $_selectedLng");
debugPrint("_dateTimeLocal = ${_selectedDate} / ${_selectedTime}");

final clientRequestId =
    DateTime.now().millisecondsSinceEpoch.toString();

debugPrint("🆔 clientRequestId = $clientRequestId");



    // اعتبارسنجی‌های ساده
    final allDogs = appState.allDogs;
    final uid = appState.currentUserId!;
    final myDogs = allDogs.where((d) => d.ownerId == uid).toList();

    if (myDogs.isEmpty || _selectedRequesterDogId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectYourDogHint, style: GoogleFonts.poppins())),
      );
      return;
    }

    final scheduled = _buildScheduledDateTime();
if (scheduled == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Please select date and time.'),
    ),
  );
  return;
}
// ⛔️ DEBUG: check park coordinates
if (_selectedLat == null || _selectedLng == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Park location coordinates missing.'),
    ),
  );
  debugPrint("🚀 AFTER CALL - mounted=$mounted");

  debugPrint('❌ locationLat/locationLng are NULL');
  return;
}


// ⛔️ RULE: must be at least 15 minutes later
final nowUtc = DateTime.now().toUtc();

if (scheduled.isBefore(nowUtc.add(const Duration(minutes: 15)))) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Playdate must be scheduled at least 15 minutes in advance.',
      ),
    ),
  );
  return;
}




    if (!_isPresetPark &&
        (_selectedLocationText == null || _selectedLocationText!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectLocation, style: GoogleFonts.poppins())),
      );
      return;
    }

    Dog? requesterDog;
try {
  requesterDog =
      myDogs.firstWhere((d) => d.id == _selectedRequesterDogId);
} catch (_) {
  requesterDog = null;
}

    if (requesterDog == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectYourDogHint, style: GoogleFonts.poppins())),
      );
      return;
    }

    final requestedDog = _selectedRequestedDog;
    if (requestedDog == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectFriendsDog, style: GoogleFonts.poppins())),
      );
      return;
    }

    final requestedOwnerId = requestedDog.ownerId ?? '';
    if (requestedOwnerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorNoOwnerFound, style: GoogleFonts.poppins())),
      );
      return;
    }

    setState(() => _sending = true);

    // ✅ اگر preset park است ولی مختصات نداریم، اصلاً call نکن
if (_isPresetPark && (_selectedLat == null || _selectedLng == null)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Park location coordinates missing.'),
    ),
  );
  return;
}


    try {
  debugPrint("🚀 SEND REQUEST PRESSED");
debugPrint("🔥 Firebase apps: ${Firebase.apps}");
debugPrint("🔥 Current user UID: ${FirebaseAuth.instance.currentUser?.uid}");
  final functions = FirebaseFunctions.instanceFor(
    region: 'europe-west3',
  );

  debugPrint("📡 About to call createPlayDateRequest");

  debugPrint("AUTH UID = ${FirebaseAuth.instance.currentUser?.uid}");
debugPrint("APPSTATE UID = ${appState.currentUserId}");

  

  final result = await functions
      .httpsCallable(
        'createPlayDateRequest',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      )
      .call({
  'clientRequestId': clientRequestId,
  'requesterUserId': appState.currentUserId,
  'requestedUserId': requestedOwnerId,
  'requesterDogName': requesterDog.name,
  'requestedDogName': requestedDog.name,
  'scheduledDateTime': scheduled.toUtc().toIso8601String(),
  'requesterDogId': requesterDog.id,
  'requestedDogId': requestedDog.id,
  'locationText': _selectedLocationText,
  'locationLat': _selectedLat != null ? _selectedLat! * 1.0 : null,
  'locationLng': _selectedLng != null ? _selectedLng! * 1.0 : null,
  'isPresetPark': _isPresetPark,
});


  debugPrint("✅ FUNCTION RESPONSE: ${result.data}");
  debugPrint("🟢 AFTER FUNCTION CALL SUCCESS");


      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.requestCreatedSuccess,
            style: GoogleFonts.poppins(),
          ),
        ),
      );

      appState.clearPlaydateFlow();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e, stack) {
  debugPrint("❌ FUNCTION ERROR: $e");
  debugPrint("📍 STACK: $stack");

      if (!mounted) return;

      String errorMsg = l10n.errorCreatingRequest(e.toString());
      if (e is FirebaseFunctionsException) {
        errorMsg = e.message ?? errorMsg;
         debugPrint("🔥 CODE: ${e.code}");
    debugPrint("🔥 MESSAGE: ${e.message}");
    debugPrint("🔥 DETAILS: ${e.details}");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg, style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildFriendDogSelector(
  AppLocalizations l10n,
  List<Dog> friendDogs,
) {
  final bool isLocked = _selectedRequestedDog != null;

  // 🔒 اگر از DogCard آمده‌ایم
  if (isLocked) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        '${_selectedRequestedDog!.name} • ${_selectedRequestedDog!.breed}',
        style: GoogleFonts.poppins(fontSize: 14),
      ),
    );
  }

  // ✅ فقط Dropdown
  return DropdownButtonFormField<Dog>(
  isExpanded: true,
  decoration: InputDecoration(
    hintText: l10n.selectFriendsDog,   // ✅ فقط placeholder
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
    value: friendDogs.contains(_selectedRequestedDog)
        ? _selectedRequestedDog
        : null,
    items: friendDogs
        .map(
          (d) => DropdownMenuItem<Dog>(
            value: d,
            child: Text(
              '${d.name} • ${d.breed}',
              style: GoogleFonts.poppins(),
            ),
          ),
        )
        .toList(),
    onChanged: (v) {
      setState(() {
        _selectedRequestedDog = v;
      });
    },
  );
}
Widget _dateTimeTile({
  required IconData icon,
  required String value,
  required VoidCallback onTap,
  bool pink = false, // ✅ جدید
}) {
  final bg = pink ? AppTheme.card : Colors.white;
  final fg = pink ? AppTheme.textLight : AppTheme.textDark;
  final iconColor = pink ? AppTheme.accent : AppTheme.primary;
  final chevronColor = pink ? Colors.white70 : Colors.black45;

  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppTheme.radius),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppTheme.cardShadow(opacity: pink ? 0.18 : 0.05),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: AppTheme.body(color: fg),
            ),
          ),
          Icon(Icons.chevron_right, color: chevronColor),
        ],
      ),
    ),
  );
}
  @override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final appState = context.watch<AppState>();

  final uid = appState.currentUserId;
  if (uid == null) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  final park = appState.activePlaydatePark;
  final bool isPresetPark = park != null;

  if (isPresetPark && _selectedLocationText == null) {
    _selectedLocationText = park['name']?.toString();
    _selectedLat = (park['lat'] as num?)?.toDouble();
    _selectedLng = (park['lng'] as num?)?.toDouble();
  }

  final allDogs = appState.allDogs;
  final myDogs = allDogs.where((d) => d.ownerId == uid).toList();
  final dogsNotMine = allDogs.where((d) => d.ownerId != uid).toList();

  final friendDogs = dogsNotMine;

  final scheduledText = _buildScheduledDateTime() == null
      ? l10n.selectDateAndTime
      : '${DateFormat('yyyy-MM-dd').format(_selectedDate!)} • ${_selectedTime!.format(context)}';

  return Scaffold(
    backgroundColor: AppTheme.bg,
    //appBar: AppBar(
      //title: Text(l10n.schedulePlayDate),
    //),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: (_sending || friendDogs.isEmpty || myDogs.isEmpty)
            ? null
            : _createRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
        ),
        child: Text(_sending ? l10n.sending : l10n.sendRequestButton),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// DATE & TIME
            Text(l10n.selectDateAndTime, style: AppTheme.h2()),
            const SizedBox(height: 12),

            _dateTimeTile(
              icon: Icons.calendar_today,
              value: _selectedDate == null
                  ? l10n.pickDate
                  : DateFormat('yyyy-MM-dd').format(_selectedDate!),
              onTap: _pickDate,
            ),

            const SizedBox(height: 12),

            _dateTimeTile(
              icon: Icons.access_time,
              value: _selectedTime == null
                  ? l10n.pickTime
                  : _selectedTime!.format(context),
              onTap: _pickTime,
            ),

            if (_buildScheduledDateTime() != null) ...[
              const SizedBox(height: 8),
              Text(scheduledText, style: AppTheme.caption()),
            ],

            const SizedBox(height: 24),

            /// LOCATION
            Text(l10n.selectLocation, style: AppTheme.h2()),
            const SizedBox(height: 12),

            if (isPresetPark)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.park, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedLocationText ?? '',
                        style: AppTheme.body(),
                      ),
                    ),
                  ],
                ),
              )
            else
              _dateTimeTile(
                icon: Icons.location_on,
                value: _selectedLocationText ?? l10n.selectLocation,
                onTap: _pickLocation,
              ),

            const SizedBox(height: 24),

            /// YOUR DOG
            Text(l10n.selectYourDog, style: AppTheme.h2()),
            const SizedBox(height: 8),

            if (myDogs.isEmpty)
              Text(l10n.selectYourDogHint, style: AppTheme.caption())
            else
              DropdownButtonFormField<String>(
                value: _selectedRequesterDogId,
                isExpanded: true,
                decoration: const InputDecoration(),
                items: myDogs
                    .map(
                      (d) => DropdownMenuItem<String>(
                        value: d.id,
                        child: Text(d.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() => _selectedRequesterDogId = v);
                },
              ),

            const SizedBox(height: 24),

            /// FRIEND DOG
            Text(l10n.selectFriendsDog, style: AppTheme.h2()),
            const SizedBox(height: 8),

            if (friendDogs.isEmpty)
              Text("No available dogs", style: AppTheme.caption())
            else
              _buildFriendDogSelector(l10n, friendDogs),

            const SizedBox(height: 100),
          ],
        ),
      ),
    ),
  );
}
}

// ────────────────────────────────────────────────
// Map Picker Page
// ────────────────────────────────────────────────

class MapPickerPage extends StatefulWidget {
  final LatLng initialLocation;

  const MapPickerPage({super.key, required this.initialLocation});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  GoogleMapController? _mapController;
  LatLng? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectLocation),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation,
              zoom: 13,
            ),
            onMapCreated: (c) => _mapController = c,
            onTap: (p) => setState(() => _selected = p),
            markers: {
              if (_selected != null)
                Marker(
                  markerId: const MarkerId('picked'),
                  position: _selected!,
                ),
            },
            zoomControlsEnabled: true,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ElevatedButton(
              onPressed: () {
                if (_selected == null) return;
                Navigator.pop(context, _selected);
              },
              child: Text(l10n.confirm),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class _PickedLocation {
  final String text;
  final double? lat;
  final double? lng;

  _PickedLocation({required this.text, required this.lat, required this.lng});
}