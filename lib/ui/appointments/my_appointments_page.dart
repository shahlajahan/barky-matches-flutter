import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/appointments/appointment_status_utils.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/appointment_payment_page.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/pet_taxi_booking_detail_page.dart';

class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage> {
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> _userDocs = {};
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> _buyerDocs =
      {};
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
  _groomyUserDocs = {};
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
  _groomyBuyerDocs = {};
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
  _hotelUserDocs = {};
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
  _hotelBuyerDocs = {};

  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
    _petTaxiUserDocs = {};

StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    _petTaxiUserSub;

bool _petTaxiUserLoaded = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _buyerSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _groomyUserSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _groomyBuyerSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _hotelUserSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _hotelBuyerSub;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _appointments = [];
  bool _loading = true;
  bool _userLoaded = false;
  bool _buyerLoaded = false;
  bool _groomyUserLoaded = false;
  bool _groomyBuyerLoaded = false;
  bool _hotelUserLoaded = false;
  bool _hotelBuyerLoaded = false;
  String? _errorText;
  String? _processingAppointmentId;
  int _lastLoggedCount = -1;

  @override
  void initState() {
    super.initState();
    debugPrint("🩺 MY APPOINTMENTS OPENED");
    _attachListeners();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _buyerSub?.cancel();
    _groomyUserSub?.cancel();
    _groomyBuyerSub?.cancel();
    _hotelUserSub?.cancel();
    _hotelBuyerSub?.cancel();
    _petTaxiUserSub?.cancel();
    super.dispose();
  }

  void _attachListeners() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      setState(() {
        _loading = false;
        _errorText = null;
      });
      return;
    }

    final vetCollection = FirebaseFirestore.instance.collection(
      'vet_appointments',
    );
    final groomyCollection = FirebaseFirestore.instance.collection(
      'groomy_appointments',
    );
    final hotelCollection = FirebaseFirestore.instance.collection(
      'hotel_bookings',
    );

    final petTaxiCollection = FirebaseFirestore.instance.collection(
  'pet_taxi_bookings',
);

    _userSub = vetCollection
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen(
          _handleUserSnapshot,
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _errorText = error.toString();
              _loading = false;
            });
          },
        );

    _buyerSub = vetCollection
        .where('buyerUid', isEqualTo: uid)
        .snapshots()
        .listen(
          _handleBuyerSnapshot,
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _errorText = error.toString();
              _loading = false;
            });
          },
        );

    _groomyUserSub = groomyCollection
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen(
          _handleGroomyUserSnapshot,
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _errorText = error.toString();
              _loading = false;
            });
          },
        );

    _groomyBuyerSub = groomyCollection
        .where('buyerUid', isEqualTo: uid)
        .snapshots()
        .listen(
          _handleGroomyBuyerSnapshot,
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _errorText = error.toString();
              _loading = false;
            });
          },
        );

    _hotelUserSub = hotelCollection
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen(
          _handleHotelUserSnapshot,
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _errorText = error.toString();
              _loading = false;
            });
          },
        );

    _hotelBuyerSub = hotelCollection
        .where('buyerUid', isEqualTo: uid)
        .snapshots()
        .listen(
          _handleHotelBuyerSnapshot,
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _errorText = error.toString();
              _loading = false;
            });
          },
        );
        _petTaxiUserSub = petTaxiCollection
    .where('userId', isEqualTo: uid)
    .snapshots()
    .listen(
      _handlePetTaxiUserSnapshot,
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _errorText = error.toString();
          _loading = false;
        });
      },
    );
  }

  void _handlePetTaxiUserSnapshot(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  _petTaxiUserDocs
    ..clear()
    ..addEntries(snapshot.docs.map((doc) => MapEntry(_docKey(doc), doc)));

  _petTaxiUserLoaded = true;
  _errorText = null;

  _rebuildAppointments();
}

  String _docKey(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return '${doc.reference.parent.id}/${doc.id}';
  }

  void _handleUserSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _userDocs
      ..clear()
      ..addEntries(snapshot.docs.map((doc) => MapEntry(_docKey(doc), doc)));
    _userLoaded = true;
    _errorText = null;
    _rebuildAppointments();
  }

  void _handleBuyerSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _buyerDocs
      ..clear()
      ..addEntries(snapshot.docs.map((doc) => MapEntry(_docKey(doc), doc)));
    _buyerLoaded = true;
    _errorText = null;
    _rebuildAppointments();
  }

  void _handleGroomyUserSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _groomyUserDocs
      ..clear()
      ..addEntries(snapshot.docs.map((doc) => MapEntry(_docKey(doc), doc)));
    _groomyUserLoaded = true;
    _errorText = null;
    _rebuildAppointments();
  }

  void _handleGroomyBuyerSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    _groomyBuyerDocs
      ..clear()
      ..addEntries(snapshot.docs.map((doc) => MapEntry(_docKey(doc), doc)));
    _groomyBuyerLoaded = true;
    _errorText = null;
    _rebuildAppointments();
  }

  void _handleHotelUserSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _hotelUserDocs
      ..clear()
      ..addEntries(snapshot.docs.map((doc) => MapEntry(_docKey(doc), doc)));
    _hotelUserLoaded = true;
    _errorText = null;
    _rebuildAppointments();
  }

  void _handleHotelBuyerSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _hotelBuyerDocs
      ..clear()
      ..addEntries(snapshot.docs.map((doc) => MapEntry(_docKey(doc), doc)));
    _hotelBuyerLoaded = true;
    _errorText = null;
    _rebuildAppointments();
  }

  void _rebuildAppointments() {
    final merged = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{}
  ..addAll(_userDocs)
  ..addAll(_buyerDocs)
  ..addAll(_groomyUserDocs)
  ..addAll(_groomyBuyerDocs)
  ..addAll(_hotelUserDocs)
  ..addAll(_hotelBuyerDocs)
  ..addAll(_petTaxiUserDocs);

    final list = merged.values.toList()
      ..sort((a, b) => _compareAppointments(a, b));

    if (!mounted) return;

    setState(() {
      _appointments = list;
      _loading =
    !(_userLoaded &&
        _buyerLoaded &&
        _groomyUserLoaded &&
        _groomyBuyerLoaded &&
        _hotelUserLoaded &&
        _hotelBuyerLoaded &&
        _petTaxiUserLoaded);
    });

    if (_lastLoggedCount != list.length) {
      debugPrint("🩺 MY APPOINTMENTS COUNT → ${list.length}");
      _lastLoggedCount = list.length;
    }
  }

  int _compareAppointments(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aDate = _appointmentDateTime(a.data());
    final bDate = _appointmentDateTime(b.data());

    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;

    return bDate.compareTo(aDate);
  }

  DateTime? _appointmentDateTime(Map<String, dynamic> data) {
    final raw = data['scheduledAt'] ?? data['scheduledDateTime'];
    final hotelRaw = data['checkInDate'];

    final value = raw ?? hotelRaw;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);

    return null;
  }

  Future<void> _openAppointmentDetail(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final collection = doc.reference.parent.id;
    final appointmentId = doc.id;
    final isGroomy = collection == 'groomy_appointments';
    final isHotel = collection == 'hotel_bookings';
final isPetTaxi = collection == 'pet_taxi_bookings';
    debugPrint("🩺 OPEN USER APPOINTMENT DETAIL → $collection/$appointmentId");

    await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) {
      if (isPetTaxi) {
        return PetTaxiBookingDetailPage(
          bookingId: appointmentId,
        );
      }

      return AppointmentPaymentPage(
        appointmentId: appointmentId,
        appointmentCollection: collection,
        appointmentType: isHotel
            ? 'pet_hotel'
            : isGroomy
            ? 'grooming'
            : 'veterinary',
        updateStatusFunctionName: isHotel
            ? 'updateHotelBookingStatus'
            : isGroomy
            ? 'updateGroomyAppointmentStatus'
            : 'updateVetAppointmentStatus',
        createOrderFunctionName: isHotel
            ? 'createHotelBookingOrder'
            : 'createAppointmentOrder',
        verifyPaymentFunctionName: isHotel
            ? 'verifyHotelBookingPayment'
            : 'verifyPayment',
        serviceFallbackName: isHotel
            ? 'Hotel stay'
            : isGroomy
            ? 'Grooming service'
            : 'Veterinary service',
        businessFallbackName: isHotel
            ? 'Pet hotel'
            : isGroomy
            ? 'Grooming studio'
            : 'Vet clinic',
        businessInfoLabel: isHotel
            ? 'Hotel'
            : isGroomy
            ? 'Groomy'
            : 'Clinic',
      );
    },
  ),
);
  }

  Future<void> _logLatestAppointmentSnapshot(
    String collection,
    String appointmentId,
  ) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .doc(appointmentId)
          .get();
      final data = snap.data() ?? {};
      debugPrint(
        '🩺 APPOINTMENT SNAPSHOT AFTER CANCEL → '
        'status=${data['status']} '
        'paymentStatus=${data['paymentStatus']} '
        'refundStatus=${data['refundStatus']} '
        'refundRequired=${data['refundRequired']} '
        'refundRequestId=${data['refundRequestId']} '
        'refundedAt=${data['refundedAt']} '
        'refundError=${data['refundError']}',
      );
    } catch (e) {
      debugPrint('🩺 APPOINTMENT SNAPSHOT LOG FAILED → $e');
    }
  }

  Future<void> _cancelAppointment(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final collection = doc.reference.parent.id;
    final appointmentId = doc.id;
    if (_processingAppointmentId == appointmentId) return;

    final l10n = AppLocalizations.of(context)!;

    setState(() => _processingAppointmentId = appointmentId);

    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west3')
          .httpsCallable(
            collection == 'groomy_appointments'
                ? 'updateGroomyAppointmentStatus'
                : collection == 'hotel_bookings'
                ? 'updateHotelBookingStatus'
                : 'updateVetAppointmentStatus',
          )
          .call({
            'appointmentId': appointmentId,
            'status': 'cancelled_by_user',
          });

      debugPrint("🩺 CANCEL SUCCESS → $appointmentId");
      await _logLatestAppointmentSnapshot(collection, appointmentId);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.appointmentCancelled)));
    } on FirebaseFunctionsException catch (e, stack) {
      debugPrint("🩺 CANCEL RAW ERROR → $e");
      debugPrint("🩺 CANCEL STACK → $stack");
      debugPrint(
        "🩺 CANCEL FUNCTION ERROR → code=${e.code} message=${e.message} details=${e.details}",
      );
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cancelAppointmentFailed)));
    } catch (e, stack) {
      debugPrint("🩺 CANCEL RAW ERROR → $e");
      debugPrint("🩺 CANCEL STACK → $stack");
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cancelAppointmentFailed)));
    } finally {
      if (mounted) {
        setState(() => _processingAppointmentId = null);
      }
    }
  }

  Future<void> _showCancelDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.cancelAppointmentTitle),
          content: Text(l10n.cancelAppointmentConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.keepAppointmentButton),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.cancelAppointmentButton),
            ),
          ],
        );
      },
    );

    if (shouldCancel == true) {
      await _cancelAppointment(doc);
    }
  }

  String _refundStatusLabel(Map<String, dynamic> data, AppLocalizations l10n) {
    final refundRequired = data['refundRequired'] == true;
    final refundStatus = data['refundStatus']?.toString() ?? '';

    return AppointmentStatusUtils.refundStatusLabel(
      refundRequired: refundRequired,
      refundStatus: refundStatus,
      l10n: l10n,
    );
  }

  Color _refundStatusColor(Map<String, dynamic> data) {
    return AppointmentStatusUtils.refundStatusColor(
      refundRequired: data['refundRequired'] == true,
      refundStatus: data['refundStatus']?.toString() ?? '',
    );
  }

  String _displayName(String? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
  return Center(
    child: Text(l10n.myAppointmentsLoginRequired),
  );
}

return Container(
  color: const Color(0xFFFDF2F5),
  child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorText != null
          ? Center(child: Text(l10n.errorOccurred(_errorText!)))
          : _appointments.isEmpty
          ? Center(child: Text(l10n.noAppointmentsYet))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  l10n.appointmentHistory,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF9E1B4F),
                  ),
                ),
                const SizedBox(height: 12),
                ..._appointments.map((doc) {
                  final data = doc.data();
                  final collection = doc.reference.parent.id;
                  final isGroomy =
                      collection == 'groomy_appointments' ||
                      data['appointmentType'] == 'grooming';
                  final isHotel =
                      collection == 'hotel_bookings' ||
                      data['appointmentType'] == 'pet_hotel';
                      final isPetTaxi =
    collection == 'pet_taxi_bookings' ||
    data['appointmentType'] == 'pet_taxi';
                  final status = (data['status'] ?? 'pending').toString();
                  final businessName = _displayName(
  data['businessName']?.toString() ??
      data['clinicName']?.toString() ??
      data['vetName']?.toString(),
  isPetTaxi
      ? 'Pet Taxi'
      : isHotel
      ? 'Pet hotel'
      : isGroomy
      ? 'Grooming studio'
      : l10n.veterinaryClinicFallback,
);
                  final serviceTitle = _displayName(
  data['serviceTitle']?.toString(),
  isPetTaxi
      ? 'Pet transportation'
      : isHotel
      ? 'Hotel stay'
      : isGroomy
      ? 'Grooming service'
      : l10n.veterinaryServiceFallback,
);
                  final petName = _displayName(
                    data['petName']?.toString() ?? data['dogName']?.toString(),
                    l10n.petFallback,
                  );
                  final petType = _displayName(
                    data['petType']?.toString(),
                    l10n.dogTypeLabel,
                  );
                  final priceRaw = data['totalPrice'] ?? data['price'];
                  final price = priceRaw is num
                      ? priceRaw.toDouble()
                      : double.tryParse(priceRaw?.toString() ?? '') ?? 0;
                  final paymentStatus = data['paymentStatus']?.toString() ?? '';
                  final refundLabel = _refundStatusLabel(data, l10n);
                  final refundColor = _refundStatusColor(data);
                  final ownerUid = (data['userId'] ?? data['buyerUid'] ?? '')
                      .toString();
                  final canCancel =
                      ownerUid == uid &&
                      (status == 'pending' ||
                          status == 'awaiting_payment' ||
                          status == 'confirmed' ||
                          status == 'confirmed_paid');
                  if (canCancel) {
                    debugPrint("🩺 CANCEL BUTTON VISIBLE");
                  }
                  final dateTime = _appointmentDateTime(data);
                  final checkOutRaw = data['checkOutDate'];
                  final checkOut = checkOutRaw is Timestamp
                      ? checkOutRaw.toDate()
                      : checkOutRaw is DateTime
                      ? checkOutRaw
                      : checkOutRaw is String
                      ? DateTime.tryParse(checkOutRaw)
                      : null;
                  final dateText = dateTime == null
                      ? '-'
                      : isHotel && checkOut != null
                      ? '${MaterialLocalizations.of(context).formatFullDate(dateTime)} → ${MaterialLocalizations.of(context).formatFullDate(checkOut)}'
                      : MaterialLocalizations.of(
                          context,
                        ).formatFullDate(dateTime);
                  final timeText = dateTime == null || isHotel
                      ? (isHotel
                            ? '${data['totalNights'] ?? '-'} night(s)'
                            : '-')
                      : MaterialLocalizations.of(
                          context,
                        ).formatTimeOfDay(TimeOfDay.fromDateTime(dateTime));
                  final badgeColor = AppointmentStatusUtils.statusColor(status);
                  final paymentColor =
                      AppointmentStatusUtils.paymentStatusColor(paymentStatus);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 7),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    businessName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    serviceTitle,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                AppointmentStatusUtils.statusLabel(
                                  status,
                                  l10n,
                                ),
                                style: TextStyle(
                                  color: badgeColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$petName • $petType',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$dateText • $timeText',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (price > 0)
                              Expanded(
                                child: Text(
                                  '${l10n.totalLabel} ₺${price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            else
                              const Expanded(child: SizedBox()),
                            if (paymentStatus.isNotEmpty ||
                                refundLabel.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (paymentStatus.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: paymentColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        AppointmentStatusUtils.paymentStatusLabel(
                                          paymentStatus,
                                          l10n,
                                        ),
                                        style: TextStyle(
                                          color: paymentColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  if (refundLabel.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: refundColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        refundLabel,
                                        style: TextStyle(
                                          color: refundColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => _openAppointmentDetail(doc),
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: Text(l10n.viewAppointment),
                              ),
                            ),
                          ],
                        ),
                        if (canCancel) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _processingAppointmentId == doc.id
                                  ? null
                                  : () => _showCancelDialog(doc),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: _processingAppointmentId == doc.id
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(l10n.cancelAppointmentButton),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
