import 'dart:io';
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/services/pet_taxi_location_service.dart';
import 'package:barky_matches_fixed/services/pet_taxi_pricing_service.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'pet_taxi_location_picker_page.dart';
import 'pet_taxi_booking_detail_page.dart';

import 'package:firebase_auth/firebase_auth.dart';

class PetTaxiBookingPage extends StatefulWidget {
  final BusinessCardData business;

  const PetTaxiBookingPage({super.key, required this.business});

  @override
  State<PetTaxiBookingPage> createState() => _PetTaxiBookingPageState();
}

class _PetTaxiBookingPageState extends State<PetTaxiBookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _phone = TextEditingController();
  final _microchip = TextEditingController();
  final _vaccination = TextEditingController();
  final _medical = TextEditingController();
  final _behavior = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _pricingService = const PetTaxiPricingService();
  final _routeService = const PetTaxiRouteService();

  Dog? _selectedDog;
  PetTaxiLocationPoint? _pickupLocation;
  PetTaxiLocationPoint? _dropoffLocation;
  PetTaxiRouteEstimate? _routeEstimate;
  DateTime? _scheduledAt;
  String _tripType = 'one_way';
  String _serviceReason = 'vet';
  String _petSize = 'medium';
  bool _saving = false;
  bool _cageRequired = false;
  bool _leashRequired = true;
  bool _largeDog = false;
  bool _specialAssistance = false;
  bool _transportPolicyAccepted = false;
  bool _submittedOnce = false;
  bool _estimating = false;
  Timer? _estimateDebounce;
  int _estimateRequestId = 0;
  PetTaxiPriceEstimate? _estimate;

  @override
  void dispose() {
    _notes.dispose();
    _phone.dispose();
    _microchip.dispose();
    _vaccination.dispose();
    _medical.dispose();
    _behavior.dispose();
    _emergencyPhone.dispose();
    _estimateDebounce?.cancel();
    super.dispose();
  }

  bool get _canEstimate {
    return _pickupLocation != null &&
        _dropoffLocation != null &&
        _scheduledAt != null;
  }

  bool get _hasRequiredText {
    return _pickupLocation != null &&
        _dropoffLocation != null &&
        _phoneValidator(_phone.text) == null;
  }

  bool get _hasValidSchedule {
    final date = _scheduledAt;
    return date != null && date.isAfter(DateTime.now());
  }

  bool get _canSubmit {
    return !_saving &&
        _selectedDog != null &&
        _hasRequiredText &&
        _hasValidSchedule &&
        _routeEstimate != null &&
        _estimate != null &&
        !_estimating &&
        _transportPolicyAccepted;
  }

  void _refreshValidity() {
    if (mounted) setState(() {});
  }

  void _scheduleEstimate() {
    _estimateDebounce?.cancel();
    if (!_canEstimate) {
      if (_estimate != null || _estimating) {
        setState(() {
          _estimate = null;
          _estimating = false;
        });
      }
      return;
    }

    setState(() => _estimating = true);
    _estimateDebounce = Timer(
      const Duration(milliseconds: 350),
      _calculateEstimate,
    );
  }

  Future<void> _calculateEstimate() async {
    debugPrint('[PetTaxiBooking] estimate start');
    debugPrint('[PetTaxiBooking] canEstimate=$_canEstimate');
    debugPrint(
      '[PetTaxiBooking] pickup=${_pickupLocation?.formattedAddress} coords=${_pickupLocation?.lat},${_pickupLocation?.lng}',
    );
    debugPrint(
      '[PetTaxiBooking] dropoff=${_dropoffLocation?.formattedAddress} coords=${_dropoffLocation?.lat},${_dropoffLocation?.lng}',
    );
    debugPrint(
      '[PetTaxiBooking] scheduledAt=$_scheduledAt tripType=$_tripType serviceReason=$_serviceReason petSize=$_petSize largeDog=$_largeDog cageRequired=$_cageRequired specialAssistance=$_specialAssistance',
    );

    if (!_canEstimate) {
      debugPrint(
        '[PetTaxiBooking] estimate skipped: required route inputs missing',
      );
      return;
    }

    final requestId = ++_estimateRequestId;
    debugPrint('[PetTaxiBooking] requestId=$requestId');
    setState(() => _estimating = true);

    try {
      debugPrint('[PetTaxiBooking] route request calling service');
      final route = await _routeService.estimateDrivingRoute(
        pickup: _pickupLocation!,
        dropoff: _dropoffLocation!,
      );
      debugPrint(
        '[PetTaxiBooking] route success distanceKm=${route.distanceKm} durationMinutes=${route.durationMinutes} polyline=${route.encodedPolyline == null ? 'none' : 'present'}',
      );

      debugPrint('[PetTaxiBooking] pricing estimate calling service');
      final estimate = await _pricingService.estimate(
        PetTaxiPricingInput(
          routeDistanceKm: route.distanceKm,
          routeDurationMinutes: route.durationMinutes,
          tripType: _tripType,
          serviceReason: _serviceReason,
          petSize: _petSize,
          largeDog: _largeDog,
          cageCarrierRequired: _cageRequired,
          specialAssistanceRequired: _specialAssistance,
          scheduledAt: _scheduledAt!,
          businessData: widget.business.rawData ?? widget.business.data,
        ),
      );
      debugPrint(
        '[PetTaxiBooking] pricing success min=${estimate.minPrice} max=${estimate.maxPrice} currency=${estimate.currency} distanceKm=${estimate.approximateDistanceKm}',
      );

      if (!mounted) {
        debugPrint(
          '[PetTaxiBooking] estimate result ignored: widget unmounted',
        );
        return;
      }
      if (requestId != _estimateRequestId) {
        debugPrint(
          '[PetTaxiBooking] estimate result ignored: stale request old=$requestId current=$_estimateRequestId',
        );
        return;
      }

      setState(() {
        _routeEstimate = route;
        _estimate = estimate;
        _estimating = false;
      });
      debugPrint(
        '[PetTaxiBooking] state updated routeSet=${_routeEstimate != null} estimateSet=${_estimate != null} canSubmit=$_canSubmit',
      );
    } catch (e, stack) {
      debugPrint('[PetTaxiBooking] estimation failure reason=${e.toString()}');
      debugPrint('[PetTaxiBooking] estimation failure stack=$stack');

      if (!mounted) {
        debugPrint('[PetTaxiBooking] failure ignored: widget unmounted');
        return;
      }
      if (requestId != _estimateRequestId) {
        debugPrint(
          '[PetTaxiBooking] failure ignored: stale request old=$requestId current=$_estimateRequestId',
        );
        return;
      }

      setState(() {
        _routeEstimate = null;
        _estimate = null;
        _estimating = false;
      });
      _snack('Route estimate failed: ${e.toString()}');
    }
  }

  Future<void> _pickLocation({required bool pickup}) async {
    final selected = await Navigator.of(context).push<PetTaxiLocationPoint>(
      MaterialPageRoute(
        builder: (_) => PetTaxiLocationPickerPage(
          title: pickup ? 'Select Pickup Location' : 'Select Dropoff Location',
          initialLocation: pickup ? _pickupLocation : _dropoffLocation,
        ),
      ),
    );
    if (selected == null || !mounted) return;

    setState(() {
      if (pickup) {
        _pickupLocation = selected;
      } else {
        _dropoffLocation = selected;
      }

      _routeEstimate = null;
      _estimate = null;
    });

    if (_pickupLocation != null &&
        _dropoffLocation != null &&
        _scheduledAt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scheduleEstimate();
        }
      });
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
    if (_pickupLocation != null &&
        _dropoffLocation != null &&
        _scheduledAt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scheduleEstimate();
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _submittedOnce = true);
    if (!_formKey.currentState!.validate()) return;
    if (!_canSubmit) {
      _snack(_submitBlockReason());
      return;
    }

    setState(() => _saving = true);
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('createPetTaxiBooking');
      final result = await callable.call({
        'businessId': widget.business.id,
        'businessName': widget.business.name,
        'petId': _selectedDog!.id,
        'petName': _selectedDog!.name,
        'petType': _selectedDog!.petType,
        'petBreed': _selectedDog!.breed,
        'pickupAddress': _pickupLocation!.formattedAddress,
        'pickupLat': _pickupLocation!.lat,
        'pickupLng': _pickupLocation!.lng,
        'pickupLocation': _pickupLocation!.toMap(),
        'dropoffAddress': _dropoffLocation!.formattedAddress,
        'dropoffLat': _dropoffLocation!.lat,
        'dropoffLng': _dropoffLocation!.lng,
        'dropoffLocation': _dropoffLocation!.toMap(),
        'scheduledAt': _scheduledAt!.toIso8601String(),
        'tripType': _tripType,
        'serviceReason': _serviceReason,
        'petSize': _petSize,
        'specialNotes': _notes.text.trim(),
        'userPhone': _phone.text.trim(),
        'paymentMethod': 'in_app',
        'estimatedMinPrice': _estimate!.minPrice,
        'estimatedMaxPrice': _estimate!.maxPrice,
        'estimateCurrency': _estimate!.currency,
        'estimatedDistanceKm': _estimate!.approximateDistanceKm,
        'routeDistanceKm': _routeEstimate!.distanceKm,
        'routeDurationMinutes': _routeEstimate!.durationMinutes,
        'routeEstimate': _routeEstimate!.toMap(),
        'pricingRulesSnapshot': _estimate!.rulesSnapshot,
        'petMicrochipId': _microchip.text.trim(),
        'vaccinationCardInfo': _vaccination.text.trim(),
        'medicalConditionNotes': _medical.text.trim(),
        'behaviorNotes': _behavior.text.trim(),
        'emergencyContactNumber': _emergencyPhone.text.trim(),
        'cageCarrierRequired': _cageRequired,
        'leashRequired': _leashRequired,
        'largeDog': _largeDog,
        'specialAssistanceRequired': _specialAssistance,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final bookingId = data['bookingId']?.toString();
      if (!mounted) return;
      if (bookingId == null || bookingId.isEmpty) {
        _snack('Booking created, but no booking id was returned');
        Navigator.of(context).pop();
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PetTaxiBookingDetailPage(bookingId: bookingId),
        ),
      );
    } catch (e) {
      debugPrint('PetTaxiBookingPage submit error: ${e.toString()}');
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    final dogs = Hive.isBoxOpen('dogsBox') && currentUserId != null
        ? Hive.box<Dog>('dogsBox').values.where((dog) {
            return dog.ownerId == currentUserId;
          }).toList()
        : <Dog>[];
    debugPrint('🚕 PetTaxi currentUserId=$currentUserId');
    debugPrint('🚕 PetTaxi user dogs=${dogs.length}');

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(title: const Text('Book Pet Taxi')),
        bottomNavigationBar: _stickyCta(),
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: _saving,
              child: Form(
                key: _formKey,
                autovalidateMode: _submittedOnce
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                onChanged: _refreshValidity,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    _businessSummary(),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: 'Trip Details',
                      subtitle: 'Pickup, dropoff, trip type and reason',
                      icon: LucideIcons.navigation,
                      initiallyExpanded: true,
                      children: [
                        _locationSelector(
                          title: 'Pickup location',
                          point: _pickupLocation,
                          onTap: () => _pickLocation(pickup: true),
                        ),
                        _locationSelector(
                          title: 'Dropoff location',
                          point: _dropoffLocation,
                          onTap: () => _pickLocation(pickup: false),
                        ),
                        _choice(
                          'Trip type',
                          _tripType,
                          const {
                            'one_way': 'One way',
                            'round_trip': 'Round trip',
                          },
                          (value) {
                            setState(() => _tripType = value);
                            _scheduleEstimate();
                          },
                        ),
                        _choice(
                          'Reason',
                          _serviceReason,
                          const {
                            'vet': 'Vet',
                            'groomy': 'Groomy',
                            'hotel': 'Hotel',
                            'airport': 'Airport',
                            'custom': 'Custom',
                          },
                          (value) {
                            setState(() => _serviceReason = value);
                            _scheduleEstimate();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: 'Pet Details',
                      subtitle: dogs.isEmpty
                          ? 'Add a pet before booking transportation'
                          : 'Select the pet that will travel',
                      icon: LucideIcons.dog,
                      initiallyExpanded: true,
                      children: [_petSelector(dogs)],
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: 'Scheduling',
                      subtitle: 'Choose pickup date and contact phone',
                      icon: LucideIcons.calendarClock,
                      initiallyExpanded: true,
                      children: [
                        _dateTimeButton(),
                        _field(
                          _phone,
                          'User phone',
                          keyboardType: TextInputType.phone,
                          validator: _phoneValidator,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: 'Safety Details',
                      subtitle: 'Optional health and transport notes',
                      icon: LucideIcons.shieldCheck,
                      children: [
                        _choice(
                          'Pet size',
                          _petSize,
                          const {
                            'small': 'Small',
                            'medium': 'Medium',
                            'large': 'Large',
                            'giant': 'Giant',
                          },
                          (value) {
                            setState(() => _petSize = value);
                            _scheduleEstimate();
                          },
                        ),
                        _field(
                          _microchip,
                          'Pet microchip / identity number',
                          required: false,
                        ),
                        _field(
                          _vaccination,
                          'Vaccination card information',
                          required: false,
                        ),
                        _field(
                          _medical,
                          'Disease or medical condition notes',
                          required: false,
                          maxLines: 2,
                        ),
                        _field(
                          _behavior,
                          'Aggression / special behavior notes',
                          required: false,
                          maxLines: 2,
                        ),
                        _field(
                          _emergencyPhone,
                          'Emergency contact number',
                          required: false,
                          keyboardType: TextInputType.phone,
                          validator: _optionalPhoneValidator,
                        ),
                        _switchTile(
                          title: 'Cage/carrier required',
                          value: _cageRequired,
                          onChanged: (value) {
                            setState(() => _cageRequired = value);
                            _scheduleEstimate();
                          },
                        ),
                        _switchTile(
                          title: 'Leash required',
                          value: _leashRequired,
                          onChanged: (value) =>
                              setState(() => _leashRequired = value),
                        ),
                        _switchTile(
                          title: 'Large dog',
                          value: _largeDog,
                          onChanged: (value) {
                            setState(() => _largeDog = value);
                            _scheduleEstimate();
                          },
                        ),
                        _switchTile(
                          title: 'Special assistance required',
                          value: _specialAssistance,
                          onChanged: (value) {
                            setState(() => _specialAssistance = value);
                            _scheduleEstimate();
                          },
                        ),
                        _field(
                          _notes,
                          'Special notes',
                          maxLines: 3,
                          required: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _estimatedPricingCard(),
                    const SizedBox(height: 12),
                    _bookingSummary(),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: 'Legal & Compliance',
                      subtitle: 'Required before submitting',
                      icon: LucideIcons.fileCheck,
                      initiallyExpanded: true,
                      children: [
                        const Text(
                          'PetSupo only provides booking infrastructure. Transportation responsibility belongs to the provider.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _transportPolicyAccepted,
                          onChanged: (value) {
                            setState(
                              () => _transportPolicyAccepted = value ?? false,
                            );
                          },
                          title: const Text(
                            'I confirm my pet is safe for transportation.',
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        if (_submittedOnce && !_transportPolicyAccepted)
                          const Padding(
                            padding: EdgeInsets.only(left: 12, bottom: 4),
                            child: Text(
                              'Required',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_saving) _loadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _businessSummary() {
    final location = [
      widget.business.district,
      widget.business.city,
    ].where((part) => part.isNotEmpty).join(', ');

    return Semantics(
      label: 'Pet taxi business summary',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF9E1B4F).withOpacity(0.12),
              child: const Icon(LucideIcons.car, color: Color(0xFF9E1B4F)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.business.name,
                    style: AppTheme.bodyMedium().copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      location,
                      style: AppTheme.caption(color: AppTheme.muted),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _Pill(label: 'In-app payment'),
                      _Pill(label: 'Manual provider approval'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        maintainState: true,
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(icon, color: const Color(0xFF9E1B4F)),
        title: Text(
          title,
          style: AppTheme.bodyMedium().copyWith(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(subtitle),
        children: children,
      ),
    );
  }

  Widget _petSelector(List<Dog> dogs) {
    if (dogs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withOpacity(0.25)),
        ),
        child: const Text('No pets found. Add a pet profile before booking.'),
      );
    }

    return Semantics(
      label: 'Select pet for taxi booking',
      child: DropdownButtonFormField<Dog>(
        key: ValueKey(_selectedDog?.id ?? 'empty_pet'),
        initialValue: _selectedDog,
        items: dogs
            .map(
              (dog) => DropdownMenuItem(
                value: dog,
                child: _petOption(dog, compact: false),
              ),
            )
            .toList(),
        selectedItemBuilder: (context) {
          return dogs.map((dog) => _petOption(dog, compact: true)).toList();
        },
        onChanged: (dog) => setState(() => _selectedDog = dog),
        decoration: const InputDecoration(labelText: 'Pet'),
        validator: (value) => value == null ? 'Select a pet' : null,
      ),
    );
  }

  Widget _petOption(Dog dog, {required bool compact}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _petAvatar(dog, radius: compact ? 14 : 18),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dog.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (!compact)
                Text(
                  dog.breed.isEmpty ? dog.petType : dog.breed,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption(color: AppTheme.muted),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _petAvatar(Dog dog, {required double radius}) {
    final path = dog.imagePaths.isNotEmpty ? dog.imagePaths.first : null;
    ImageProvider? image;
    if (path != null && path.trim().isNotEmpty) {
      if (path.startsWith('http')) {
        image = NetworkImage(path);
      } else {
        image = FileImage(File(path));
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundImage: image,
      backgroundColor: const Color(0xFF9E1B4F).withOpacity(0.12),
      child: image == null
          ? Icon(LucideIcons.dog, size: radius, color: const Color(0xFF9E1B4F))
          : null,
    );
  }

  Widget _dateTimeButton() {
    final hasError = _submittedOnce && !_hasValidSchedule;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: 'Select pickup date and time',
            child: OutlinedButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(LucideIcons.calendarClock),
              label: Text(
                _scheduledAt == null
                    ? 'Select pickup date/time'
                    : _dateTimeText(_scheduledAt!),
              ),
            ),
          ),
          if (hasError)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 12),
              child: Text(
                'Select a future pickup date and time',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _locationSelector({
    required String title,
    required PetTaxiLocationPoint? point,
    required VoidCallback onTap,
  }) {
    final hasError = _submittedOnce && point == null;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        button: true,
        label: title,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hasError ? Colors.red : Colors.black12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.mapPin, color: Color(0xFF9E1B4F)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.caption(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        point?.formattedAddress ??
                            'Search/select address or pick on map',
                        style: AppTheme.body().copyWith(
                          fontWeight: point == null
                              ? FontWeight.w500
                              : FontWeight.w800,
                        ),
                      ),
                      if (point != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${point.lat.toStringAsFixed(6)}, ${point.lng.toStringAsFixed(6)}',
                          style: AppTheme.caption(color: AppTheme.muted),
                        ),
                      ],
                      if (hasError) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Required',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(LucideIcons.chevronRight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bookingSummary() {
    return Semantics(
      label: 'Booking summary',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.clipboardList, color: Color(0xFF9E1B4F)),
                const SizedBox(width: 10),
                Text(
                  'Booking Summary',
                  style: AppTheme.bodyMedium().copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _summaryRow('Business', widget.business.name),
            _summaryRow('Pet', _selectedDog?.name ?? 'Not selected'),
            _summaryRow('Pickup', _pickupLocation?.formattedAddress ?? '-'),
            _summaryRow('Dropoff', _dropoffLocation?.formattedAddress ?? '-'),
            _summaryRow(
              'Route',
              _routeEstimate == null
                  ? 'Not calculated'
                  : '${_routeEstimate!.distanceKm.toStringAsFixed(1)} km • ${_routeEstimate!.durationMinutes} min',
            ),
            _summaryRow(
              'Time',
              _scheduledAt == null ? '-' : _dateTimeText(_scheduledAt!),
            ),
            _summaryRow('Trip', _labelFor(_tripType)),
            _summaryRow('Reason', _labelFor(_serviceReason)),
            _summaryRow(
              'Estimate',
              _estimate == null
                  ? 'Calculate after entering trip'
                  : '≈ ${_estimate!.minPrice} - ${_estimate!.maxPrice} ${_estimate!.currency}',
            ),
            _summaryRow('Payment', 'In-app after provider final price'),
            const SizedBox(height: 4),
            Text(
              'Estimated based on Istanbul taxi tariff + pet transport service premium. Bridge, highway, waiting and provider-specific fees may be added. Final price will be confirmed by provider.',
              style: AppTheme.caption(color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _estimatedPricingCard() {
    final estimate = _estimate;
    return Semantics(
      label: 'Estimated pet taxi price range',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.badgeDollarSign, color: Color(0xFF9E1B4F)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated Price',
                    style: AppTheme.bodyMedium().copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_estimating)
                    const LinearProgressIndicator()
                  else if (estimate == null)
                    Text(
                      'Select pickup/dropoff locations and pickup time to calculate a real driving-route estimate.',
                      style: AppTheme.body(color: AppTheme.muted),
                    )
                  else ...[
                    Text(
                      '≈ ${estimate.minPrice} - ${estimate.maxPrice} ${estimate.currency}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF9E1B4F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${estimate.approximateDistanceKm} km driving route • ${_routeEstimate?.durationMinutes ?? '-'} min. Estimated based on Istanbul taxi tariff + pet transport service premium. Bridge, highway, waiting and provider-specific fees may be added. Final price will be confirmed by provider.',
                      style: AppTheme.caption(color: AppTheme.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(label, style: AppTheme.caption(color: AppTheme.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stickyCta() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 18,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Semantics(
          button: true,
          enabled: _canSubmit,
          label: 'Create pet taxi booking',
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: SizedBox(
              key: ValueKey(_saving),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _canSubmit ? 'Create Booking' : _submitBlockReason(),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingOverlay() {
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: _saving ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          color: Colors.black.withOpacity(0.18),
          child: const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Creating booking...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool required = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        textField: true,
        label: label,
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label, helperText: helperText),
          validator:
              validator ??
              (required
                  ? (value) => (value == null || value.trim().isEmpty)
                        ? 'Required'
                        : null
                  : null),
        ),
      ),
    );
  }

  Widget _choice(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: options.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  String? _phoneValidator(String? value) {
    final phone = (value ?? '').replaceAll(RegExp(r'[\s()-]'), '');
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(phone)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _optionalPhoneValidator(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    return _phoneValidator(value);
  }

  String _submitBlockReason() {
    if (_selectedDog == null) return 'Select pet';
    if (_pickupLocation == null) return 'Add pickup';
    if (_dropoffLocation == null) return 'Add dropoff';
    if (!_hasValidSchedule) return 'Select time';
    if (_phoneValidator(_phone.text) != null) return 'Add phone';
    if (_estimating) return 'Calculating route';
    if (_routeEstimate == null || _estimate == null) return 'Wait for route';
    if (!_transportPolicyAccepted) return 'Confirm safety';
    return 'Create Booking';
  }

  String _labelFor(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _dateTimeText(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black12),
      boxShadow: AppTheme.cardShadow(opacity: 0.05),
    );
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF9E1B4F).withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF9E1B4F),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
