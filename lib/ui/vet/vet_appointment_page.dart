import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import '../../theme/app_theme.dart';
import '../../app_state.dart';
import '../../dog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'package:cloud_functions/cloud_functions.dart';

class VetAppointmentPage extends StatefulWidget {
  final BusinessCardData vet;
  final Map<String, dynamic>? selectedService;

  const VetAppointmentPage({
    super.key,
    required this.vet,
    this.selectedService, // 🔥 NEW
  });

  @override
  State<VetAppointmentPage> createState() => _VetAppointmentPageState();
}

class _VetAppointmentPageState extends State<VetAppointmentPage> {
  // ─────────────────────────────
  // STATE
  // ─────────────────────────────

  Dog? _selectedDog;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final TextEditingController _noteController = TextEditingController();
  bool _submitting = false;

  Map<String, dynamic>? _selectedServiceLocal;
  String? _dogsRefreshRequestedForUid;

  bool get _isValid =>
      _selectedDog != null &&
      _selectedDate != null &&
      _selectedTime != null &&
      _selectedServiceLocal != null; // 🔥 این خط جدید

  late final Stream<QuerySnapshot> _servicesStream;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _selectedServiceLocal = widget.selectedService;

    _servicesStream = FirebaseFirestore.instance
    .collection('businesses')
    .doc(widget.vet.id)
    .collection('services')
    .snapshots();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshDogsOnce('initState');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshDogsOnce('didChangeDependencies');
    });
  }

  Future<void> _refreshDogsOnce(String source) async {
    final appState = context.read<AppState>();
    final authUid =
        FirebaseAuth.instance.currentUser?.uid ?? appState.currentUserId ?? '';

    debugPrint(
      '🩺 VetAppointmentPage lifecycle → $source authUid=$authUid appStateUid=${appState.currentUserId ?? "NULL"} '
      'ready=${appState.isUserProfileReady} myDogs=${appState.myDogs.length}',
    );

    if (authUid.isEmpty) {
      debugPrint(
        '🩺 VetAppointmentPage dog refresh skipped → missing auth uid',
      );
      return;
    }

    if (_dogsRefreshRequestedForUid == authUid) {
      return;
    }

    _dogsRefreshRequestedForUid = authUid;
    debugPrint(
      '🩺 VetAppointmentPage dog refresh requested → source=AppState.loadMyDogs uid=$authUid',
    );

    try {
      await appState.loadMyDogs();
    } catch (e) {
      debugPrint('🩺 VetAppointmentPage dog refresh failed → $e');
    }
  }

  Widget _serviceSelector() {
  final l10n = AppLocalizations.of(context)!;

  return StreamBuilder<QuerySnapshot>(
    stream: _servicesStream,
    builder: (context, snapshot) {
      /// ─────────────────────────────
      /// LOADING
      /// ─────────────────────────────
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox(
          height: 80,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
debugPrint(
  "🧪 SUBCOLLECTION DOCS = ${snapshot.data?.docs.length}",
);
      final List<Map<String, dynamic>> services = [];

      /// ─────────────────────────────
      /// NEW STRUCTURE
      /// businesses/{id}/services/*
      /// ─────────────────────────────
      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
        final docs = snapshot.data!.docs;

        services.addAll(
          docs.map((doc) {
            final data =
                doc.data() as Map<String, dynamic>;

            return {
              ...data,
              'id': doc.id,
            };
          }),
        );
      }

      /// ─────────────────────────────
      /// FALLBACK OLD STRUCTURE
      /// sectorData.veterinary.services.offeredServices
      /// ─────────────────────────────
      else {
        final businessData =
            widget.vet.rawData ?? {};

        final vetData =
            (businessData['sectorData']
                    ?['veterinary']
                as Map<String, dynamic>?) ??
            {};

        final servicesData =
            (vetData['services']
                as Map<String, dynamic>?) ??
            {};

        debugPrint(
          "🧪 APPOINTMENT FALLBACK SERVICES = $servicesData",
        );

        if (servicesData['offeredServices'] is List) {
          final offered =
              List<String>.from(
                servicesData['offeredServices'],
              );

          services.addAll(
            offered.map(
              (e) => {
                'id': e.toLowerCase(),
                'title': e,

                /// fallback values
                'price': null,
                'durationMin': 30,
              },
            ),
          );
        }
      }

      debugPrint(
        "📦 APPOINTMENT SERVICES COUNT: ${services.length}",
      );

      /// ─────────────────────────────
      /// EMPTY
      /// ─────────────────────────────
      if (services.isEmpty) {
        return SizedBox(
          height: 60,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.noServicesAvailable,
              style: AppTheme.caption(),
            ),
          ),
        );
      }

      /// ─────────────────────────────
      /// AUTO SELECT FIRST
      /// ─────────────────────────────
      if (_selectedServiceLocal == null) {
        _selectedServiceLocal = services.first;
      }

      /// ─────────────────────────────
      /// UI
      /// ─────────────────────────────
      return SizedBox(
        height: 70,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          itemCount: services.length,
          separatorBuilder: (_, __) =>
              const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final service = services[index];

            final isSelected =
                _selectedServiceLocal?['id'] ==
                service['id'];

            return GestureDetector(
              onTap: () {
                if (isSelected) return;

                setState(() {
                  _selectedServiceLocal = service;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: 180,
                ),
                padding:
                    const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.amber
                      : Colors.white,
                  borderRadius:
                      BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? Colors.amber
                        : Colors.grey.shade300,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.amber
                                .withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      service['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(width: 6),

                    Text(
                      l10n.durationMinutesShort(
                        service['durationMin'] ??
                            30,
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.black87
                            : Colors.grey,
                      ),
                    ),

                    if (service['price'] !=
                            null &&
                        service['price'] > 0) ...[
                      const SizedBox(width: 6),

                      Text(
                        "${service['price']}₺",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

  // ─────────────────────────────
  // UI
  // ─────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final authUid =
        FirebaseAuth.instance.currentUser?.uid ?? appState.currentUserId ?? '';

    debugPrint(
      '🩺 VetAppointmentPage build → authUid=$authUid appStateUid=${appState.currentUserId ?? "NULL"} '
      'ready=${appState.isUserProfileReady} myDogs=${appState.myDogs.length}',
    );

    if (!appState.isUserProfileReady) {
      debugPrint('🩺 VetAppointmentPage waiting for appState readiness');
      return const SizedBox.shrink();
    }

    return Material(
      // 👈 خیلی مهم
      color: AppTheme.bg,
      child: SafeArea(
        child: Column(
          children: [
            /// 🔙 HEADER (به جای AppBar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      context.read<AppState>().closeBusinessAppointment();
                    },
                  ),
                  Expanded(
                    child: Text(
                      '${l10n.appointmentTitle} • ${widget.vet.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// 👇 BODY
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _sectionTitle(l10n.selectService),
                  const SizedBox(height: 8),
                  _serviceSelector(),

                  const SizedBox(height: 20),

                  _sectionTitle(l10n.selectPet),
                  _dogSelector(),

                  const SizedBox(height: 20),

                  _sectionTitle(l10n.dateAndTime),
                  _dateTimePicker(),

                  const SizedBox(height: 20),

                  _sectionTitle(l10n.notesOptional),
                  _notesField(),

                  const SizedBox(height: 32),

                  _submitButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ─────────────────────────────
  // WIDGETS
  // ─────────────────────────────

  Widget _sectionTitle(String text) {
    return Text(text, style: AppTheme.h2().copyWith(fontSize: 16));
  }

  Widget _dogSelector() {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final authUid =
        FirebaseAuth.instance.currentUser?.uid ?? appState.currentUserId ?? '';
    final dogs = appState.myDogs
        .where((dog) => dog.ownerId == authUid)
        .toList();

    debugPrint(
      '🩺 VetAppointmentPage dog selector → authUid=$authUid source=AppState.myDogs filteredCount=${dogs.length}',
    );
    for (final dog in dogs.take(3)) {
      debugPrint(
        '🩺 VetAppointmentPage dog ownerId → dogId=${dog.id} ownerId=${dog.ownerId} name=${dog.name}',
      );
    }

    if (dogs.isEmpty) {
      debugPrint(
        '🩺 VetAppointmentPage empty dogs state → authUid=$authUid appStateUid=${appState.currentUserId ?? "NULL"} '
        'ready=${appState.isUserProfileReady} myDogs=${appState.myDogs.length}',
      );
      return Text(l10n.noDogsAddedYet, style: AppTheme.caption());
    }

    return Column(
      children: dogs.map((dog) {
        final selected = _selectedDog?.id == dog.id;

        return GestureDetector(
          onTap: () {
            setState(() => _selectedDog = dog);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? Colors.amber.withOpacity(0.15) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? Colors.amber : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.pets, color: selected ? Colors.amber : Colors.grey),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${dog.name} • ${dog.petType}",
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${dog.breed} • ${dog.age}${l10n.ageYearsSuffix}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _dateTimePicker() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _pickDate,
            child: Text(
              _selectedDate == null
                  ? l10n.selectDate
                  : '${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day}',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: _pickTime,
            child: Text(
              _selectedTime == null
                  ? l10n.selectTime
                  : _selectedTime!.format(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _notesField() {
    final l10n = AppLocalizations.of(context)!;
    return TextField(
      controller: _noteController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: l10n.appointmentNoteHint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _submitButton() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: !_isValid || _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _submitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                l10n.requestAppointment,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
      ),
    );
  }

  // ─────────────────────────────
  // ACTIONS
  // ─────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      initialDate: now,
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    debugPrint("🚀 SUBMIT CLICKED");

    if (!_isValid || _submitting) return;

    final appState = context.read<AppState>();
    final userId = appState.currentUserId;
    final selectedService = _selectedServiceLocal;

    if (userId == null || _selectedDog == null) {
      debugPrint("❌ Missing user or dog");
      return;
    }

    setState(() => _submitting = true);

    try {
      final scheduledDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final businessSnap = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.vet.id)
          .get();
      final businessData = businessSnap.data() ?? {};
      final profile = Map<String, dynamic>.from(businessData['profile'] ?? {});
      final liveBusinessName =
          profile['displayName']?.toString().trim().isNotEmpty == true
          ? profile['displayName'].toString()
          : widget.vet.name;

      debugPrint(
        '🩺 VET BUSINESS MAP → source=VetAppointmentPage businessId=${widget.vet.id} '
        'displayName=$liveBusinessName serviceId=${selectedService?['id']} '
        'selectedPricingSource=businesses/${widget.vet.id}/services/${selectedService?['id']}',
      );

      /// 🔥 CALL CLOUD FUNCTION (به‌جای Firestore مستقیم)
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('createVetAppointment').call({
        'petId': _selectedDog!.id,
        'petName': _selectedDog!.name,
        'petType': _selectedDog!.petType,

        'petBreed': _selectedDog!.breed,
        'petAge': _selectedDog!.age,

        'businessId': widget.vet.id,
        'businessName': liveBusinessName,

        'serviceId': selectedService?['id'],
        'serviceTitle': selectedService?['title'],
        'price': selectedService?['price'],
        'durationMin': selectedService?['durationMin'],

        'scheduledAt': scheduledDateTime.toIso8601String(),
        'note': _noteController.text.trim(),
      });

      debugPrint("✅ FUNCTION SUCCESS");

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.requestSentTitle),
          content: Text(l10n.requestSentMessage),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // فقط dialog بسته میشه

                context
                    .read<AppState>()
                    .closeBusinessAppointment(); // صفحه appointment بسته میشه
              },
              child: Text(l10n.okButton),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ Appointment submit error: $e');

      String message = l10n.somethingWentWrong;

      if (e is FirebaseFunctionsException) {
        switch (e.code) {
          case 'already-exists':
            message = l10n.alreadyBookedAtThisTime;
            break;

          case 'invalid-argument':
            message = l10n.invalidBookingData;
            break;

          default:
            message = e.message ?? message;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
