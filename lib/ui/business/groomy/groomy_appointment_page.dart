import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';

class GroomyAppointmentPage extends StatefulWidget {
  final BusinessCardData groomy;
  final Map<String, dynamic>? selectedService;

  const GroomyAppointmentPage({
    super.key,
    required this.groomy,
    this.selectedService,
  });

  @override
  State<GroomyAppointmentPage> createState() => _GroomyAppointmentPageState();
}

class _GroomyAppointmentPageState extends State<GroomyAppointmentPage> {
  Dog? _selectedDog;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Map<String, dynamic>? _selectedServiceLocal;
  String? _dogsRefreshRequestedForUid;

  final TextEditingController _noteController = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _servicesStream;

  bool _submitting = false;

  bool get _isValid =>
      _selectedDog != null &&
      _selectedDate != null &&
      _selectedTime != null &&
      _selectedServiceLocal != null;

  @override
  void initState() {
    super.initState();
    _selectedServiceLocal = widget.selectedService;
    _servicesStream = FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.groomy.id)
        .collection('services')
        .orderBy('sortOrder')
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

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _refreshDogsOnce(String source) async {
    final appState = context.read<AppState>();
    final authUid =
        FirebaseAuth.instance.currentUser?.uid ?? appState.currentUserId ?? '';

    debugPrint(
      '✂️ GroomyAppointmentPage dog refresh → source=$source uid=$authUid',
    );

    if (authUid.isEmpty || _dogsRefreshRequestedForUid == authUid) return;

    _dogsRefreshRequestedForUid = authUid;
    try {
      await appState.loadMyDogs();
    } catch (e) {
      debugPrint('✂️ GroomyAppointmentPage dog refresh failed → $e');
    }
  }

  List<Map<String, dynamic>> _fallbackServices() {
    final rawData = widget.groomy.rawData ?? widget.groomy.data ?? {};
    final sectorData = Map<String, dynamic>.from(rawData['sectorData'] ?? {});
    final groomingData = Map<String, dynamic>.from(
      sectorData['grooming'] ?? sectorData['groomer'] ?? {},
    );
    final servicesData = groomingData['services'];

    List<String> titles = [];
    if (servicesData is Map && servicesData['offeredServices'] is List) {
      titles = List<String>.from(servicesData['offeredServices']);
    } else if (servicesData is List) {
      titles = servicesData.map((item) => item.toString()).toList();
    } else if (widget.groomy.services != null) {
      titles = widget.groomy.services!;
    }

    return titles
        .where((title) => title.trim().isNotEmpty)
        .map(
          (title) => {
            'id': title.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
            'title': title,
            'price': null,
            'durationMin': 60,
          },
        )
        .toList();
  }

  double _servicePrice(Map<String, dynamic> service) {
    final raw = service['price'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  int _serviceDuration(Map<String, dynamic> service) {
    final raw = service['durationMin'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 60;
  }

  Widget _serviceSelector() {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _servicesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final services = <Map<String, dynamic>>[];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          services.addAll(
            snapshot.data!.docs.map((doc) {
              final data = doc.data();
              return {...data, 'id': doc.id};
            }),
          );
        } else {
          services.addAll(_fallbackServices());
        }

        if (services.isEmpty) {
          return SizedBox(
            height: 60,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.noServicesAvailable, style: AppTheme.caption()),
            ),
          );
        }

        if (_selectedServiceLocal == null) {
          _selectedServiceLocal = services.first;
        }

        return SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final service = services[index];
              final selected = _selectedServiceLocal?['id'] == service['id'];
              final price = _servicePrice(service);
              final durationMin = _serviceDuration(service);

              return GestureDetector(
                onTap: () {
                  if (selected) return;
                  setState(() => _selectedServiceLocal = service);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? Colors.amber : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected ? Colors.amber : Colors.grey.shade300,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.25),
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
                        service['title']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.durationMinutesShort(durationMin),
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      if (price > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}₺',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();

    if (!appState.isUserProfileReady) {
      return const SizedBox.shrink();
    }

    return Material(
      color: AppTheme.bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      context.read<AppState>().closeBusinessAppointment();
                    },
                  ),
                  Expanded(
                    child: Text(
                      '${l10n.appointmentTitle} • ${widget.groomy.name}',
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

    if (dogs.isEmpty) {
      return Text(l10n.noDogsAddedYet, style: AppTheme.caption());
    }

    return Column(
      children: dogs.map((dog) {
        final selected = _selectedDog?.id == dog.id;

        return GestureDetector(
          onTap: () => setState(() => _selectedDog = dog),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${dog.name} • ${dog.petType}',
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${dog.breed} • ${dog.age}${l10n.ageYearsSuffix}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
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
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                l10n.requestAppointment,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      initialDate: now,
    );
    if (!mounted || date == null) return;
    setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (!mounted || time == null) return;
    setState(() => _selectedTime = time);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;

    if (!_isValid || _submitting) return;

    final appState = context.read<AppState>();
    final userId = appState.currentUserId;
    final selectedService = _selectedServiceLocal;

    if (userId == null || _selectedDog == null || selectedService == null) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
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
          .doc(widget.groomy.id)
          .get();
      final businessData = businessSnap.data() ?? {};
      final profile = Map<String, dynamic>.from(businessData['profile'] ?? {});
      final liveBusinessName =
          profile['displayName']?.toString().trim().isNotEmpty == true
          ? profile['displayName'].toString()
          : widget.groomy.name;

      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('createGroomyAppointment').call({
        'petId': _selectedDog!.id,
        'petName': _selectedDog!.name,
        'petType': _selectedDog!.petType,
        'petBreed': _selectedDog!.breed,
        'petAge': _selectedDog!.age,
        'businessId': widget.groomy.id,
        'businessName': liveBusinessName,
        'serviceId': selectedService['id'],
        'serviceTitle': selectedService['title'],
        'price': selectedService['price'],
        'durationMin': selectedService['durationMin'],
        'scheduledAt': scheduledDateTime.toIso8601String(),
        'note': _noteController.text.trim(),
      });

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.requestSentTitle),
          content: Text(l10n.requestSentMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.okButton),
            ),
          ],
        ),
      );

      if (!mounted) return;
      context.read<AppState>().closeBusinessAppointment();
    } catch (e) {
      debugPrint('✂️ Groomy appointment submit error: $e');

      var message = l10n.somethingWentWrong;
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
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
