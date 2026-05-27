// lib/play_date_scheduling_page.dart
//
// ✅ CLEAN (Phase 2) – نسخه اصلاح‌شده با Cloud Function
// - فقط UI + فراخوانی Cloud Function برای ساخت درخواست
// - هیچ نوشتن مستقیم Firestore در کلاینت وجود ندارد
// - push notification از سمت بک‌اند (Cloud Function) ارسال می‌شود

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
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/utils/dog_filter.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';

class PlayDateSchedulingPage extends StatefulWidget {
  final Dog? selectedDog; // 👈 nullable
  final List<Dog>? allDogs; // 👈 nullable

  const PlayDateSchedulingPage({super.key, this.selectedDog, this.allDogs});

  @override
  State<PlayDateSchedulingPage> createState() => _PlayDateSchedulingPageState();
}

class _PlayDateSchedulingPageState extends State<PlayDateSchedulingPage> {
  late AppState appState;
  List<Dog> _friendDogs = [];
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

    final uid = appState.currentUserId;

    /// 🐶 حالت قبلی (اگر از DogCard اومدی)
    final requestedDogId = appState.selectedRequesterDogId;

    if (requestedDogId != null) {
      final box = Hive.box<Dog>('dogsBox');
      final allDogs = box.values.toList();

      try {
        final selectedDog = allDogs.firstWhere((d) => d.id == requestedDogId);

        _selectedRequestedDog = selectedDog;

        // _loadFriendDogs(selectedDog.ownerId!); // ✅ اینم میمونه
      } catch (_) {
        _selectedRequestedDog = null;
        _friendDogs = [];
      }
    }

    if (appState.myDogs.isNotEmpty && _selectedRequesterDogId == null) {
      _selectedRequesterDogId = appState.myDogs.first.id;
    }
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
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
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
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
              ),
            ),

            textTheme: GoogleFonts.poppinsTextTheme(
              Theme.of(context).textTheme.apply(bodyColor: Colors.white),
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
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
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
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),

            // ✅ CTA مثل Location (card زرد)
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
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
                              : l10n.coordinatesLatLng(
                                  picked.latitude.toString(),
                                  picked.longitude.toString(),
                                ),
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
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),

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

    debugPrint("🌍 Functions region: europe-west3");
    debugPrint("🚀 BEFORE CALL - mounted=$mounted");

    final clientRequestId = DateTime.now().millisecondsSinceEpoch.toString();

    debugPrint("🆔 clientRequestId = $clientRequestId");

    final myDogs = appState.myDogs;

    if (myDogs.isEmpty || _selectedRequesterDogId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.selectYourDogHint)));
      return;
    }

    final scheduled = _buildScheduledDateTime();
    if (scheduled == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorSelectDateAndTime)));
      return;
    }

    if (_selectedLat == null || _selectedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorMissingLocationCoordinates)),
      );
      return;
    }

    final nowUtc = DateTime.now().toUtc();
    if (scheduled.isBefore(nowUtc.add(const Duration(minutes: 15)))) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorPlaydateLeadTime)));
      return;
    }

    if (!_isPresetPark &&
        (_selectedLocationText == null ||
            _selectedLocationText!.trim().isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.selectLocation)));
      return;
    }

    Dog? requesterDog;
    try {
      requesterDog = myDogs.firstWhere((d) => d.id == _selectedRequesterDogId);
    } catch (_) {
      requesterDog = null;
    }

    if (requesterDog == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.selectYourDogHint)));
      return;
    }

    final requestedDog = _selectedRequestedDog;
    if (requestedDog == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.selectFriendsDog)));
      return;
    }

    final requestedOwnerId = requestedDog.ownerId ?? '';
    if (requestedOwnerId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorNoOwnerFound)));
      return;
    }

    setState(() => _sending = true);

    try {
      debugPrint("🚀 SEND REQUEST PRESSED");

      final callable = FirebaseFunctions.instanceFor(region: 'europe-west3')
          .httpsCallable(
            'createPlayDateRequest',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          );

      debugPrint("📡 About to call createPlayDateRequest");

      final result = await callable.call({
        'clientRequestId': clientRequestId,
        'requesterUserId': appState.currentUserId,
        'requestedUserId': requestedOwnerId,
        'requesterDogName': requesterDog.name,
        'requestedDogName': requestedDog.name,
        'scheduledDateTime': scheduled.toUtc().toIso8601String(),
        'requesterDogId': requesterDog.id,
        'requestedDogId': requestedDog.id,
        'locationText': _selectedLocationText,
        'locationLat': _selectedLat,
        'locationLng': _selectedLng,
        'isPresetPark': _isPresetPark,
      });

      final data = result.data;

      debugPrint("🟢 FUNCTION RESPONSE DATA: $data");

      /// 🧠 HANDLE TIME CONFLICT (🔥 مهم)
      if (data is Map && data['success'] == false) {
        if (data['reason'] == 'time_conflict') {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.playdateTimeConflict)));

          setState(() => _sending = false);
          return;
        }
      }

      debugPrint("✅ FUNCTION RESPONSE: $data");

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.requestCreatedSuccess)));

      appState.clearPlaydateFlow();

      if (mounted) {
        appState.setCurrentTab(NavTab.home);
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
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildFriendDogSelector(AppLocalizations l10n, List<Dog> friendDogs) {
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
        hintText: l10n.selectFriendsDog, // ✅ فقط placeholder
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      initialValue: friendDogs.contains(_selectedRequestedDog)
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
              child: Text(value, style: AppTheme.body(color: fg)),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final myDogs = appState.myDogs;

    final friendDogs = appState.allDogs.where((d) => d.ownerId != uid).toList();

    debugPrint("🐶 FRIEND DOGS COUNT: ${friendDogs.length}");

    if (_selectedRequesterDogId == null && myDogs.isNotEmpty) {
      _selectedRequesterDogId = myDogs.first.id;
    }

    final park = appState.activePlaydatePark;
    final bool isPresetPark = park != null;

    if (isPresetPark && _selectedLocationText == null) {
      _selectedLocationText = park['name']?.toString();
      _selectedLat = (park['lat'] as num?)?.toDouble();
      _selectedLng = (park['lng'] as num?)?.toDouble();
    }

    final scheduledText = _buildScheduledDateTime() == null
        ? l10n.selectDateAndTime
        : '${DateFormat('yyyy-MM-dd').format(_selectedDate!)} • ${_selectedTime!.format(context)}';

    return Scaffold(
      backgroundColor: AppTheme.bg,

      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed:
                (_sending ||
                    friendDogs.isEmpty ||
                    myDogs.isEmpty ||
                    _selectedRequesterDogId == null)
                ? null
                : _createRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              disabledBackgroundColor: Colors.grey.withOpacity(0.25),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _sending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    l10n.sendRequestButton,
                    style: AppTheme.button().copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.schedulePlayDate} 🐾',
                style: AppTheme.h1(color: const Color(0xFF9E1B4F), size: 24),
              ),

              const SizedBox(height: 6),

              Text(
                l10n.playdateSchedulingSubtitle,
                style: AppTheme.body(color: Colors.black54, size: 13),
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppTheme.cardShadow(opacity: 0.08),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.selectDateAndTime,
                      style: AppTheme.h2(color: const Color(0xFF9E1B4F)),
                    ),

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
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          scheduledText,
                          style: AppTheme.caption(
                            color: const Color(0xFF9E1B4F),
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppTheme.cardShadow(opacity: 0.08),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.selectLocation,
                      style: AppTheme.h2(color: const Color(0xFF9E1B4F)),
                    ),

                    const SizedBox(height: 12),

                    if (isPresetPark)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.park, color: Colors.green),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedLocationText ?? '',
                                style: AppTheme.body(
                                  color: Colors.black87,
                                  weight: FontWeight.w600,
                                ),
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
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppTheme.cardShadow(opacity: 0.08),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.selectYourDog,
                      style: AppTheme.h2(color: const Color(0xFF9E1B4F)),
                    ),

                    const SizedBox(height: 10),

                    if (myDogs.isEmpty)
                      Text(l10n.selectYourDogHint, style: AppTheme.caption())
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRequesterDogId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFFFF3F7),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: myDogs
                            .map(
                              (d) => DropdownMenuItem<String>(
                                value: d.id,
                                child: Text(
                                  '${d.name} • ${d.breed}',
                                  style: AppTheme.body(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() => _selectedRequesterDogId = v);
                        },
                      ),

                    const SizedBox(height: 18),

                    Text(
                      l10n.selectFriendsDog,
                      style: AppTheme.h2(color: const Color(0xFF9E1B4F)),
                    ),

                    const SizedBox(height: 10),

                    if (friendDogs.isEmpty)
                      Text(l10n.noDogsFound, style: AppTheme.caption())
                    else
                      _buildFriendDogSelector(l10n, friendDogs),
                  ],
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadFriendDogs(String ownerId) async {
    try {
      debugPrint("🐶 OWNER ID: $ownerId");

      final snapshot = await FirebaseFirestore.instance
          .collection('dogs')
          .where('ownerId', isEqualTo: ownerId)
          .get();

      final dogs = snapshot.docs
          .map((doc) {
            final data = doc.data();

            debugPrint("🐶 RAW DATA: $data");

            if (!shouldIncludeDog(data, DogFilterMode.playdate)) {
              debugPrint("🚫 FILTERED OUT: ${data['name']}");
              return null;
            }

            return Dog.fromMap(data, doc.id);
          })
          .whereType<Dog>() // حذف null ها
          .toList();

      debugPrint("🐶 FINAL FRIEND DOGS: ${dogs.length}");

      setState(() {
        _friendDogs = dogs;
      });
    } catch (e) {
      debugPrint('❌ Failed to load friend dogs: $e');
    }
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
      appBar: AppBar(title: Text(l10n.selectLocation)),
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
