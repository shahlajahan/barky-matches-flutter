import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import 'package:barky_matches_fixed/ui/appointments/appointment_status_utils.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/groomy/groomy_clients_page.dart';
import 'package:barky_matches_fixed/ui/marketplace/marketplace_transaction_status.dart';
import 'package:barky_matches_fixed/ui/petshop/petshop_checkout_webview_page.dart';

class AppointmentPaymentPage extends StatefulWidget {
  final String appointmentId;
  final String appointmentCollection;
  final String appointmentType;
  final String updateStatusFunctionName;
  final String createOrderFunctionName;
  final String verifyPaymentFunctionName;
  final String serviceFallbackName;
  final String businessFallbackName;
  final String businessInfoLabel;

  const AppointmentPaymentPage({
    super.key,
    required this.appointmentId,
    this.appointmentCollection = 'vet_appointments',
    this.appointmentType = 'veterinary',
    this.updateStatusFunctionName = 'updateVetAppointmentStatus',
    this.createOrderFunctionName = 'createAppointmentOrder',
    this.verifyPaymentFunctionName = 'verifyPayment',
    this.serviceFallbackName = 'Veterinary service',
    this.businessFallbackName = 'Vet clinic',
    this.businessInfoLabel = 'Clinic',
  });

  @override
  State<AppointmentPaymentPage> createState() => _AppointmentPaymentPageState();
}

class _AppointmentPaymentPageState extends State<AppointmentPaymentPage> {
  static const Color primary = Color(0xFF9E1B4F);
  static const Color accent = Color(0xFFFFC107);
  static const Color bg = Color(0xFFFFF6F8);

  Map<String, dynamic>? appointment;
  bool loading = true;
  bool paying = false;
  bool cancelling = false;
  String? errorText;
  bool _loggedCancelVisible = false;
  bool _loggedStatusSnapshot = false;
  String? _lastLoggedStatus;
  String? _lastLoggedPaymentStatus;
  Timer? _deadlineTicker;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _appointmentSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _businessSub;
  Map<String, dynamic>? _businessData;
  String? _watchedBusinessId;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    debugPrint("🩺 USER APPOINTMENT PAGE OPENED");
    _deadlineTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    _watchAppointment();
  }

  @override
  void dispose() {
    _deadlineTicker?.cancel();
    _appointmentSub?.cancel();
    _businessSub?.cancel();
    super.dispose();
  }

  void _watchAppointment() {
    _appointmentSub?.cancel();
    debugPrint('🩺 APPOINTMENT SNAPSHOT WATCH START → ${widget.appointmentId}');
    _appointmentSub = FirebaseFirestore.instance
        .collection(widget.appointmentCollection)
        .doc(widget.appointmentId)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;

            final data = snap.data();
            final status = data?['status']?.toString() ?? 'pending';
            final paymentStatus =
                data?['paymentStatus']?.toString() ?? 'unpaid';

            setState(() {
              appointment = data;
              loading = false;
              errorText = null;
            });

            final businessId = data?['businessId']?.toString() ?? '';
            _watchBusiness(businessId);

            if (!_loggedStatusSnapshot ||
                _lastLoggedStatus != status ||
                _lastLoggedPaymentStatus != paymentStatus) {
              _loggedStatusSnapshot = true;
              _lastLoggedStatus = status;
              _lastLoggedPaymentStatus = paymentStatus;
              debugPrint('🩺 PAYMENT PAGE STATUS → $status');
              debugPrint('🩺 PAYMENT PAGE PAYMENT STATUS → $paymentStatus');
              debugPrint(
                '🩺 PAYMENT CTA DECISION → '
                'status=$status paymentStatus=$paymentStatus '
                'serviceRequiresPayment=${data?['serviceRequiresPayment']} '
                'price=${data?['price'] ?? data?['servicePrice'] ?? 'n/a'}',
              );
            }
          },
          onError: (e) {
            if (!mounted) return;
            setState(() {
              loading = false;
              errorText = e.toString();
            });
          },
        );
  }

  void _watchBusiness(String businessId) {
    if (businessId.isEmpty || _watchedBusinessId == businessId) return;
    _watchedBusinessId = businessId;
    _businessSub?.cancel();
    debugPrint(
      '🩺 BUSINESS WATCH → source=AppointmentPayment businessId=$businessId',
    );
    _businessSub = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          final data = snap.data();
          if (data == null) return;
          final profile = Map<String, dynamic>.from(data['profile'] ?? {});

          final sectorData = Map<String, dynamic>.from(
            data['sectorData'] ?? {},
          );

          final sectorKey = widget.appointmentType == 'pet_hotel'
              ? 'hotel'
              : widget.appointmentType == 'grooming'
              ? 'groomy'
              : 'veterinary';

          final sector = Map<String, dynamic>.from(sectorData[sectorKey] ?? {});

          final services = Map<String, dynamic>.from(sector['services'] ?? {});

          final offeredServices = services['offeredServices'];

          final serviceCount = offeredServices is List
              ? offeredServices.length
              : 0;

          debugPrint(
            '🩺 BUSINESS MAP → '
            'source=AppointmentPayment '
            'businessId=$businessId '
            'displayName=${profile['displayName']} '
            'serviceCount=$serviceCount '
            'selectedPricingSource='
            'businesses/$businessId/sectorData.$sectorKey.services',
          );

          setState(() => _businessData = data);
        });
  }

  Future<void> _refreshAppointment() async {
    await _appointmentSub?.cancel();
    if (!mounted) return;
    setState(() {
      loading = true;
      errorText = null;
    });
    _watchAppointment();
  }

  Future<void> _logLatestAppointmentSnapshot(String reason) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(widget.appointmentCollection)
          .doc(widget.appointmentId)
          .get();
      final data = snap.data() ?? {};
      debugPrint(
        '🩺 APPOINTMENT SNAPSHOT AFTER $reason → '
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

  Future<void> _syncClientRecordAfterPayment() async {
    final data = appointment;
    if (data == null) return;

    if (widget.appointmentCollection == 'hotel_bookings') {
      return;
    }

    final businessId = data['businessId']?.toString().trim() ?? '';
    final petId = (data['petId'] ?? data['dogId'])?.toString().trim() ?? '';
    final ownerId =
        (data['ownerId'] ??
                data['petOwnerUid'] ??
                data['userId'] ??
                data['requesterUserId'])
            ?.toString()
            .trim() ??
        '';
    final petName = (data['petName'] ?? data['dogName'] ?? data['pet'] ?? 'Pet')
        .toString();
    final ownerName =
        (data['ownerName'] ??
                data['username'] ??
                data['clientName'] ??
                data['owner'] ??
                'Owner')
            .toString();
    final breed = (data['petBreed'] ?? data['breed'] ?? data['dogBreed'] ?? '')
        .toString();
    final phone = (data['ownerPhone'] ?? data['phone'] ?? '').toString().trim();
    final appointmentDateRaw = data['scheduledAt'] ?? data['scheduledDateTime'];
    final appointmentDate = appointmentDateRaw is Timestamp
        ? appointmentDateRaw.toDate()
        : null;

    if (widget.appointmentCollection == 'groomy_appointments') {
      if (businessId.isEmpty || petId.isEmpty) return;

      await GroomyClientsPage.upsertClientFromAppointment(
        businessId: businessId,
        petId: petId,
        ownerId: ownerId.isEmpty ? 'unknown' : ownerId,
        petName: petName,
        ownerName: ownerName,
        breed: breed.isEmpty ? null : breed,
        phone: phone.isEmpty ? null : phone,
        appointmentDate: appointmentDate,
      );
      return;
    }

    if (widget.appointmentCollection != 'vet_appointments') {
      return;
    }

    if (businessId.isEmpty || petId.isEmpty) return;

    final patientId = '${businessId}_$petId';
    final patientRef = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('patients')
        .doc(patientId);

    await patientRef.set({
      'businessId': businessId,
      'patientId': patientId,
      'petId': petId,
      'ownerId': ownerId.isEmpty ? 'unknown' : ownerId,
      'petName': petName,
      'ownerName': ownerName,
      'breed': breed,
      'ownerPhone': phone,
      'phone': phone,
      'createdFrom': 'appointment',
      'source': 'appointment_auto',
      'lastAppointmentAt': appointmentDate != null
          ? Timestamp.fromDate(appointmentDate)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _startPayment() async {
    if (appointment == null || paying) return;

    setState(() => paying = true);

    try {
      debugPrint("🔥 SENDING appointmentId → ${widget.appointmentId}");

      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable(widget.createOrderFunctionName);

      final res = await callable.call({
        'appointmentId': widget.appointmentId,
        'appointmentCollection': widget.appointmentCollection,
        'appointmentType': widget.appointmentType,
      });

      final orderId = res.data['orderId'];
      final checkoutUrl = res.data['checkoutUrl'];

      debugPrint("💳 ORDER → $orderId");
      debugPrint("🌐 URL → $checkoutUrl");

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PetshopCheckoutWebViewPage(
            checkoutUrl: checkoutUrl,
            successUrlPrefix: "payment-success",
            cancelUrlPrefix: "payment-cancel",
            orderId: orderId,
          ),
        ),
      );

      if (result == "verify") {
        debugPrint("💳 VERIFY PAYMENT");

        final verifyCallable = FirebaseFunctions.instanceFor(
          region: 'europe-west3',
        ).httpsCallable(widget.verifyPaymentFunctionName);

        final verifyResult = await verifyCallable.call({'orderId': orderId});
        final verifyData = Map<String, dynamic>.from(verifyResult.data as Map);

        debugPrint("✅ PAYMENT VERIFIED → $verifyData");

        await _syncClientRecordAfterPayment();

        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Payment successful")));

        await _refreshAppointment();
      }

      if (result == "cancel") {
        debugPrint("❌ PAYMENT CANCELLED");

        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Payment cancelled")));
      }
    } catch (e) {
      debugPrint("❌ PAYMENT ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Payment failed: $e")));
    } finally {
      if (mounted) {
        setState(() => paying = false);
      }
    }
  }

  Future<void> _cancelAppointment() async {
    if (cancelling || appointment == null) return;

    final l10n = AppLocalizations.of(context)!;

    debugPrint("🩺 USER CANCEL APPOINTMENT → ${widget.appointmentId}");

    setState(() => cancelling = true);

    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable(widget.updateStatusFunctionName).call({
        'appointmentId': widget.appointmentId,
        'status': 'cancelled_by_user',
      });

      debugPrint("🩺 CANCEL SUCCESS → ${widget.appointmentId}");
      await _logLatestAppointmentSnapshot('CANCEL');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.appointmentCancelled)));

      await _refreshAppointment();
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
        setState(() => cancelling = false);
      }
    }
  }

  Future<void> _showCancelDialog() async {
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
      await _cancelAppointment();
    }
  }

  bool _requiresPayment() {
    final raw =
        appointment?['serviceRequiresPayment'] ??
        appointment?['requiresPayment'];

    if (raw is bool) return raw;

    final rawPrice =
        appointment?['price'] ??
        appointment?['servicePrice'] ??
        appointment?['totalPrice'];

    final price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0;

    return price > 0;
  }

  Timestamp? _deadlineTimestamp() {
    final raw = appointment?['paymentDeadlineAt'];
    if (raw is Timestamp) return raw;
    if (raw is DateTime) return Timestamp.fromDate(raw);
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return Timestamp.fromDate(parsed);
    }
    return null;
  }

  String _formatRemaining(Duration duration) {
    if (duration.isNegative || duration.inSeconds <= 0) {
      return "Payment window expired";
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }

    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _paymentDeadlineText() {
    final deadline = _deadlineTimestamp();
    if (deadline == null) return '';

    final remaining = deadline.toDate().difference(_now);
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      return "Payment window expired";
    }

    return "Pay within ${_formatRemaining(remaining)}";
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (loading) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorText != null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: _appBar(),
        body: _centerMessage(
          icon: LucideIcons.alertTriangle,
          title: "Something went wrong",
          subtitle: errorText!,
          buttonText: "Retry",
          onTap: _refreshAppointment,
        ),
      );
    }

    if (appointment == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: _appBar(),
        body: _centerMessage(
          icon: LucideIcons.calendarX,
          title: "Appointment not found",
          subtitle: "This appointment may have been removed.",
          buttonText: "Go back",
          onTap: () => Navigator.pop(context),
        ),
      );
    }

    final serviceTitle =
        appointment!['serviceTitle']?.toString().trim().isNotEmpty == true
        ? appointment!['serviceTitle'].toString()
        : widget.serviceFallbackName;

    final businessProfile = Map<String, dynamic>.from(
      _businessData?['profile'] ?? {},
    );
    final businessName =
        businessProfile['displayName']?.toString().trim().isNotEmpty == true
        ? businessProfile['displayName'].toString()
        : appointment!['businessName']?.toString().trim().isNotEmpty == true
        ? appointment!['businessName'].toString()
        : widget.businessFallbackName;

    final petName = appointment!['petName'] ?? appointment!['dogName'] ?? "Pet";
    final petType = appointment!['petType'] ?? "dog";
    final petBreed = appointment!['petBreed'] ?? "-";
    final petAge = appointment!['petAge'] ?? "-";
    final isHotelBooking =
        widget.appointmentCollection == 'hotel_bookings' ||
        widget.appointmentType == 'pet_hotel';

    final status = appointment!['status']?.toString() ?? "pending";
    final paymentStatus = appointment!['paymentStatus']?.toString() ?? "unpaid";
    final refundRequired = appointment!['refundRequired'] == true;
    final refundStatus = appointment!['refundStatus']?.toString() ?? "";
    final refundLabel = AppointmentStatusUtils.refundStatusLabel(
      refundRequired: refundRequired,
      refundStatus: refundStatus,
      l10n: l10n,
    );
    final serviceRequiresPayment = _requiresPayment();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final ownerUid = (appointment!['userId'] ?? appointment!['buyerUid'] ?? '')
        .toString();
    final canCancel =
        currentUserId != null &&
        currentUserId == ownerUid &&
        (status == 'pending' ||
            status == 'awaiting_payment' ||
            status == 'confirmed' ||
            status == 'confirmed_paid');

    if (canCancel && !_loggedCancelVisible) {
      debugPrint("🩺 CANCEL BUTTON VISIBLE");
      _loggedCancelVisible = true;
    }

    final rawPrice =
        appointment!['price'] ??
        appointment!['servicePrice'] ??
        appointment!['totalPrice'];
    final double price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0;

    final hasPrice = price > 0;
    final isPaid =
        paymentStatus == "paid" ||
        status == "confirmed_paid" ||
        status == "paid";
    final isConfirmedWithoutPayment =
        status == "confirmed" && !serviceRequiresPayment;
    final paymentDeadlineText = _paymentDeadlineText();

    if (!_loggedStatusSnapshot ||
        _lastLoggedStatus != status ||
        _lastLoggedPaymentStatus != paymentStatus) {
      _loggedStatusSnapshot = true;
      _lastLoggedStatus = status;
      _lastLoggedPaymentStatus = paymentStatus;
      debugPrint('🩺 PAYMENT PAGE STATUS → $status');
      debugPrint('🩺 PAYMENT PAGE PAYMENT STATUS → $paymentStatus');
      debugPrint(
        '🩺 PAYMENT CTA DECISION → '
        'status=$status paymentStatus=$paymentStatus '
        'serviceRequiresPayment=$serviceRequiresPayment '
        'showButton=${status == "awaiting_payment"}',
      );
    }

    final ts = appointment!['scheduledAt'] ?? appointment!['scheduledDateTime'];
    final dt = ts is Timestamp ? ts.toDate() : null;
    final checkIn = appointment!['checkInDate'] is Timestamp
        ? (appointment!['checkInDate'] as Timestamp).toDate()
        : null;
    final checkOut = appointment!['checkOutDate'] is Timestamp
        ? (appointment!['checkOutDate'] as Timestamp).toDate()
        : null;
    String fmtDate(DateTime value) {
      return "${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}";
    }

    final dateText = isHotelBooking && checkIn != null && checkOut != null
        ? "${fmtDate(checkIn)} → ${fmtDate(checkOut)} • ${appointment!['totalNights'] ?? checkOut.difference(checkIn).inDays} night(s)"
        : dt == null
        ? "Date not selected"
        : "${fmtDate(dt)} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: bg,
      appBar: _appBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heroCard(
                serviceTitle: serviceTitle,
                businessName: businessName,
                status: status,
                paymentStatus: paymentStatus,
                isPaid: isPaid,
                refundLabel: refundLabel,
                l10n: l10n,
              ),
              const SizedBox(height: 14),
              _sectionTitle(
                isHotelBooking ? "Stay Details" : "Appointment Details",
              ),
              const SizedBox(height: 10),
              _infoCard(
                children: [
                  _infoRow(
                    LucideIcons.calendarDays,
                    isHotelBooking ? "Check-in / Check-out" : "Date & Time",
                    dateText,
                  ),
                  _divider(),
                  _infoRow(
                    isHotelBooking
                        ? LucideIcons.hotel
                        : LucideIcons.stethoscope,
                    "Service",
                    serviceTitle,
                  ),
                  _divider(),
                  _infoRow(
                    LucideIcons.building2,
                    widget.businessInfoLabel,
                    businessName,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _sectionTitle("Pet Information"),
              const SizedBox(height: 10),
              _infoCard(
                children: [
                  _infoRow(Icons.pets, "Pet", "$petName • $petType"),
                  _divider(),
                  _infoRow(LucideIcons.badgeInfo, "Breed", petBreed.toString()),
                  _divider(),
                  _infoRow(LucideIcons.clock3, "Age", petAge.toString()),
                ],
              ),
              const SizedBox(height: 14),
              _sectionTitle("Payment Summary"),
              const SizedBox(height: 10),
              _paymentCard(
                hasPrice: hasPrice,
                price: price,
                isPaid: isPaid,
                serviceRequiresPayment: serviceRequiresPayment,
                status: status,
                paymentDeadlineText: paymentDeadlineText,
                refundLabel: refundLabel,
                refundColor: AppointmentStatusUtils.refundStatusColor(
                  refundRequired: refundRequired,
                  refundStatus: refundStatus,
                ),
              ),
              MarketplaceTransactionStatus(
                data: appointment!,
                compact: true,
                showUserInvoiceActions: true,
                collectionName: widget.appointmentCollection,
                transactionId: widget.appointmentId,
              ),
              const SizedBox(height: 24),
              if (canCancel) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: cancelling ? null : _showCancelDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: cancelling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            l10n.cancelAppointmentButton,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _mainButton(
                isPaid: isPaid || isConfirmedWithoutPayment,
                status: status,
                serviceRequiresPayment: serviceRequiresPayment,
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: primary,
      foregroundColor: Colors.white,
      centerTitle: true,
      title: Text(
        "Appointment Payment",
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17),
      ),
    );
  }

  Widget _heroCard({
    required String serviceTitle,
    required String businessName,
    required String status,
    required String paymentStatus,
    required bool isPaid,
    required String refundLabel,
    required AppLocalizations l10n,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primary, Color(0xFFC2185B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPaid ? LucideIcons.checkCircle2 : LucideIcons.creditCard,
            color: accent,
            size: 34,
          ),
          const SizedBox(height: 14),
          Text(
            serviceTitle,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            businessName,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                text: AppointmentStatusUtils.statusLabel(status, l10n),
                icon: LucideIcons.calendarCheck,
              ),
              _chip(
                text: AppointmentStatusUtils.paymentStatusLabel(
                  paymentStatus,
                  l10n,
                ),
                icon: LucideIcons.walletCards,
              ),
              if (refundLabel.isNotEmpty)
                _chip(text: refundLabel, icon: LucideIcons.refreshCw),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({required String text, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.black87,
      ),
    );
  }

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paymentCard({
    required bool hasPrice,
    required double price,
    required bool isPaid,
    required bool serviceRequiresPayment,
    required String status,
    required String paymentDeadlineText,
    required String refundLabel,
    required Color refundColor,
  }) {
    final isAwaitingPayment = status == "awaiting_payment";
    final showPrice = serviceRequiresPayment && hasPrice;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPaid ? Colors.green.withOpacity(0.35) : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPaid ? LucideIcons.badgeCheck : LucideIcons.receipt,
                color: isPaid ? Colors.green : primary,
                size: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isPaid
                      ? "This appointment is already paid."
                      : isAwaitingPayment
                      ? "Payment deadline"
                      : serviceRequiresPayment
                      ? "Total amount"
                      : "No online payment required",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                isPaid
                    ? "PAID"
                    : showPrice
                    ? "₺${price.toStringAsFixed(2)}"
                    : serviceRequiresPayment
                    ? "—"
                    : "Free",
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: isPaid ? Colors.green : primary,
                ),
              ),
            ],
          ),
          if (isAwaitingPayment && paymentDeadlineText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              paymentDeadlineText,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.deepOrange,
              ),
            ),
          ],
          if (refundLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              refundLabel,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: refundColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mainButton({
    required bool isPaid,
    required String status,
    required bool serviceRequiresPayment,
  }) {
    if (status == 'cancelled_by_user' ||
        status == 'cancelled_by_vet' ||
        status == 'expired') {
      return const SizedBox.shrink();
    }

    final deadline = _deadlineTimestamp();
    debugPrint("🩺 DEADLINE → ${deadline?.toDate()}");
    debugPrint("🩺 NOW → $_now");
    if (status == 'awaiting_payment' &&
        deadline != null &&
        deadline.toDate().isBefore(_now)) {
      return const SizedBox.shrink();
    }

    if (isPaid) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(LucideIcons.checkCircle2),
          label: Text(
            "Done",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    if (status != 'awaiting_payment') {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: serviceRequiresPayment ? primary : accent,
          foregroundColor: serviceRequiresPayment ? Colors.white : Colors.black,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 3,
        ),
        onPressed: paying ? null : _startPayment,
        child: paying
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                "Pay Now",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: Colors.black.withOpacity(0.08)),
    );
  }

  Widget _centerMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: primary),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
              ),
              onPressed: onTap,
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
