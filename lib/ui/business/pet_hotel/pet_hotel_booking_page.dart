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

class PetHotelBookingPage extends StatefulWidget {
  final BusinessCardData hotel;
  final Map<String, dynamic>? selectedService;

  const PetHotelBookingPage({
    super.key,
    required this.hotel,
    this.selectedService,
  });

  @override
  State<PetHotelBookingPage> createState() => _PetHotelBookingPageState();
}

class _PetHotelBookingPageState extends State<PetHotelBookingPage> {
  Dog? _selectedDog;
  DateTimeRange? _selectedRange;
  Map<String, dynamic>? _selectedServiceLocal;
  String? _dogsRefreshRequestedForUid;

  final TextEditingController _noteController = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _servicesStream;

  bool _submitting = false;

  bool get _isValid =>
      _selectedDog != null &&
      _selectedRange != null &&
      _selectedServiceLocal != null &&
      _totalNights > 0;

  int get _totalNights {
    final range = _selectedRange;
    if (range == null) return 0;
    final nights = range.end.difference(range.start).inDays;
    return nights <= 0 ? 0 : nights;
  }

  @override
  void initState() {
    super.initState();
    _selectedServiceLocal = widget.selectedService;
    debugPrint('🔥 LISTENING PATH => businesses/${widget.hotel.id}/services');
    _servicesStream = FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.hotel.id)
        .collection('services')
        .orderBy('sortOrder')
        .snapshots()
        .handleError((e) {
          debugPrint('🔥 FIRESTORE STREAM ERROR => businesses/${widget.hotel.id}/services :: $e');
        });

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
      '🏨 PetHotelBookingPage dog refresh → source=$source uid=$authUid',
    );

    if (authUid.isEmpty || _dogsRefreshRequestedForUid == authUid) return;

    _dogsRefreshRequestedForUid = authUid;
    try {
      await appState.loadMyDogs();
    } catch (e) {
      debugPrint('🏨 PetHotelBookingPage dog refresh failed → $e');
    }
  }

  List<Map<String, dynamic>> _fallbackServices() {
    final rawData = widget.hotel.rawData ?? widget.hotel.data ?? {};
    final sectorData = Map<String, dynamic>.from(rawData['sectorData'] ?? {});
    final hotelData = Map<String, dynamic>.from(
      sectorData['pet_hotel'] ??
          sectorData['hotel'] ??
          sectorData['petHotel'] ??
          {},
    );
    final servicesData = hotelData['services'];

    List<String> titles = [];
    if (servicesData is Map && servicesData['offeredServices'] is List) {
      titles = List<String>.from(servicesData['offeredServices']);
    } else if (servicesData is List) {
      titles = servicesData.map((item) => item.toString()).toList();
    } else if (widget.hotel.services != null) {
      titles = widget.hotel.services!;
    }

    if (titles.isEmpty) {
      titles = const ['Standard Room', 'VIP Room', 'Daily Care'];
    }

    return titles
        .where((title) => title.trim().isNotEmpty)
        .map(
          (title) => {
            'id': title.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
            'title': title,
            'price': null,
            'durationType': 'night',
          },
        )
        .toList();
  }

  double _servicePrice(Map<String, dynamic> service) {
    final raw = service['price'] ?? service['pricePerNight'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
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
            snapshot.data!.docs
                .map((doc) => {...doc.data(), 'id': doc.id})
                .where((service) => service['isActive'] != false),
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

        _selectedServiceLocal ??= services.first;

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

              return GestureDetector(
                onTap: selected
                    ? null
                    : () => setState(() => _selectedServiceLocal = service),
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
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      if (price > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}₺ / night',
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
                      'Book stay • ${widget.hotel.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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
                  _sectionTitle('Select room or service'),
                  const SizedBox(height: 8),
                  _serviceSelector(),
                  const SizedBox(height: 20),
                  _sectionTitle('Select pet'),
                  _dogSelector(),
                  const SizedBox(height: 20),
                  _sectionTitle('Stay dates'),
                  _dateRangePicker(),
                  const SizedBox(height: 20),
                  _sectionTitle('Notes'),
                  _notesField(),
                  const SizedBox(height: 20),
                  _priceSummary(),
                  const SizedBox(height: 24),
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

  Widget _dateRangePicker() {
    return OutlinedButton(
      onPressed: _pickDateRange,
      child: Text(
        _selectedRange == null
            ? 'Select check-in and check-out'
            : '${_formatDate(_selectedRange!.start)} → ${_formatDate(_selectedRange!.end)} ($_totalNights night${_totalNights == 1 ? '' : 's'})',
      ),
    );
  }

  Widget _notesField() {
    return TextField(
      controller: _noteController,
      maxLines: 3,
      decoration: const InputDecoration(
        hintText: 'Feeding, medication, or care notes',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _priceSummary() {
    final service = _selectedServiceLocal;
    if (service == null || _selectedRange == null) {
      return const SizedBox.shrink();
    }

    final pricePerNight = _servicePrice(service);
    final total = pricePerNight * _totalNights;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: Color(0xFF9E1B4F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pricePerNight <= 0
                  ? 'Price will be confirmed by the hotel'
                  : '₺${pricePerNight.toStringAsFixed(0)} x $_totalNights night(s)',
              style: AppTheme.body(),
            ),
          ),
          if (total > 0)
            Text(
              '₺${total.toStringAsFixed(0)}',
              style: AppTheme.bodyMedium().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }

  Widget _submitButton() {
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
            : const Text(
                'Request Booking',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 180)),
      initialDateRange:
          _selectedRange ??
          DateTimeRange(
            start: today.add(const Duration(days: 1)),
            end: today.add(const Duration(days: 2)),
          ),
    );
    if (!mounted || range == null) return;

    if (!range.end.isAfter(range.start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-out must be after check-in')),
      );
      return;
    }

    setState(() => _selectedRange = range);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;

    if (!_isValid || _submitting) return;

    final userId = context.read<AppState>().currentUserId;
    final selectedService = _selectedServiceLocal;
    final range = _selectedRange;

    if (userId == null ||
        _selectedDog == null ||
        selectedService == null ||
        range == null) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);

    try {
      final businessSnap = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.hotel.id)
          .get();
      final businessData = businessSnap.data() ?? {};
      final profile = Map<String, dynamic>.from(businessData['profile'] ?? {});
      final liveBusinessName =
          profile['displayName']?.toString().trim().isNotEmpty == true
          ? profile['displayName'].toString()
          : widget.hotel.name;

      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('createHotelBooking').call({
        'petId': _selectedDog!.id,
        'petName': _selectedDog!.name,
        'petType': _selectedDog!.petType,
        'petBreed': _selectedDog!.breed,
        'petAge': _selectedDog!.age,
        'dogId': _selectedDog!.id,
        'dogName': _selectedDog!.name,
        'businessId': widget.hotel.id,
        'businessName': liveBusinessName,
        'serviceId': selectedService['id'],
        'serviceTitle': selectedService['title'],
        'pricePerNight':
            selectedService['price'] ?? selectedService['pricePerNight'],
        'price': selectedService['price'] ?? selectedService['pricePerNight'],
        'checkInDate': range.start.toIso8601String(),
        'checkOutDate': range.end.toIso8601String(),
        'note': _noteController.text.trim(),
      });

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.requestSentTitle),
          content: const Text('Your hotel booking request was sent.'),
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
      debugPrint('🏨 Hotel booking submit error: $e');

      var message = l10n.somethingWentWrong;
      if (e is FirebaseFunctionsException) {
        switch (e.code) {
          case 'already-exists':
            message = 'This hotel is fully booked for those dates.';
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
      if (mounted) setState(() => _submitting = false);
    }
  }
}
