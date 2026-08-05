import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/pet_hotel/edit_pet_hotel_profile_page.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_header.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_metric_card.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_metric_grid.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_panel.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_section.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_status_pill.dart';

class PetHotelDashboardOverviewTab extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  PetHotelDashboardOverviewTab({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  State<PetHotelDashboardOverviewTab> createState() =>
      _PetHotelDashboardOverviewTabState();
}

class _PetHotelDashboardOverviewTabState
    extends State<PetHotelDashboardOverviewTab> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _bookingsStream;

  @override
  void initState() {
    super.initState();
    _bookingsStream = _createBookingsStream(widget.businessId);
  }

  @override
  void didUpdateWidget(covariant PetHotelDashboardOverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) {
      _bookingsStream = _createBookingsStream(widget.businessId);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _createBookingsStream(
    String businessId,
  ) {
    final stream = FirebaseFirestore.instance
        .collection('hotel_bookings')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((e) {
          debugPrint(
            '🔥 FIRESTORE STREAM ERROR => hotel_bookings?businessId=$businessId :: $e',
          );
        });
    return stream;
  }

  @override
  Widget build(BuildContext context) {
    return _PetHotelDashboardOverviewContent(
      businessId: widget.businessId,
      businessData: widget.businessData,
      bookingsStream: _bookingsStream,
    );
  }
}

class _PetHotelDashboardOverviewContent extends StatelessWidget {
  final String businessId;
  final Map<String, dynamic> businessData;
  final Stream<QuerySnapshot<Map<String, dynamic>>> bookingsStream;

  const _PetHotelDashboardOverviewContent({
    required this.businessId,
    required this.businessData,
    required this.bookingsStream,
  });

  int _maxCapacity(Map<String, dynamic> data) {
    final sectorData = Map<String, dynamic>.from(data['sectorData'] ?? {});
    final hotel = Map<String, dynamic>.from(
      sectorData['pet_hotel'] ??
          sectorData['hotel'] ??
          sectorData['petHotel'] ??
          {},
    );
    final capacity = Map<String, dynamic>.from(hotel['capacity'] ?? {});
    final raw =
        capacity['maxCapacity'] ?? hotel['maxCapacity'] ?? data['maxCapacity'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 25;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _isActiveStay(Map<String, dynamic> data, DateTime now) {
    final status = data['status']?.toString() ?? '';
    if (!['confirmed', 'confirmed_paid', 'checked_in'].contains(status)) {
      return false;
    }
    final checkIn = _date(data['checkInDate']);
    final checkOut = _date(data['checkOutDate']);
    if (checkIn == null || checkOut == null) return false;
    return checkIn.isBefore(now) && checkOut.isAfter(now);
  }

  double _money(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _hotelData(Map<String, dynamic> data) {
    final sectorData = _map(data['sectorData']);
    return _map(
      sectorData['pet_hotel'] ?? sectorData['hotel'] ?? sectorData['petHotel'],
    );
  }

  bool _isPaidBooking(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    final paymentStatus = (data['paymentStatus'] ?? '')
        .toString()
        .toLowerCase();
    return status == 'completed' ||
        status == 'confirmed_paid' ||
        paymentStatus == 'paid';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: bookingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.bookingError('${snapshot.error}'),
              style: AppTheme.body(color: AppTheme.muted),
            ),
          );
        }

        final docs =
            snapshot.data?.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final now = DateTime.now();
        final maxCapacity = _maxCapacity(businessData);

        final totalBookings = docs.length;
        final pendingRequests = docs.where((doc) {
          return doc.data()['status'] == 'pending';
        }).length;
        final completedStays = docs.where((doc) {
          return doc.data()['status'] == 'completed';
        }).length;
        final activePets = docs
            .where((doc) => _isActiveStay(doc.data(), now))
            .length;
        final occupancy = maxCapacity <= 0
            ? 0
            : ((activePets / maxCapacity) * 100).clamp(0, 100).round();
        final pendingDocs = docs
            .where((doc) => doc.data()['status'] == 'pending')
            .take(3)
            .toList();
        final upcomingDocs = docs
            .where((doc) {
              final status = doc.data()['status'];
              final checkIn = _date(doc.data()['checkInDate']);
              return checkIn != null &&
                  checkIn.isAfter(now) &&
                  status != 'rejected' &&
                  status != 'cancelled' &&
                  status != 'completed';
            })
            .take(3)
            .toList();
        final activeDocs = docs
            .where((doc) => _isActiveStay(doc.data(), now))
            .take(3)
            .toList();
        final availableCapacity = math.max(0, maxCapacity - activePets);
        final paidDocs = docs.where((doc) => _isPaidBooking(doc.data()));
        final recordedRevenue = paidDocs.fold<double>(
          0,
          (total, doc) =>
              total + _money(doc.data()['totalPrice'] ?? doc.data()['price']),
        );

        final l10n = AppLocalizations.of(context)!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000 ? 4 : 2;
            final profile = _map(businessData['profile']);
            final hotelData = _hotelData(businessData);
            final hotelName =
                (profile['displayName'] ??
                        profile['businessName'] ??
                        hotelData['hotelName'] ??
                        hotelData['businessName'] ??
                        'Pet Hotel')
                    .toString();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                DashboardHeader(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hotelName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.hotelOverview,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      DashboardStatusPill(
                        prefix: 'Hotel',
                        label: availableCapacity > 0
                            ? 'Available capacity'
                            : 'At capacity',
                        active: availableCapacity > 0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _profileCard(context),
                const SizedBox(height: 18),
                DashboardMetricGrid(
                  columns: columns,
                  compact: true,
                  items: [
                    DashboardMetricData(
                      label: 'Total bookings',
                      value: '$totalBookings',
                      icon: LucideIcons.calendarDays,
                    ),
                    DashboardMetricData(
                      label: 'Pending bookings',
                      value: '$pendingRequests',
                      icon: LucideIcons.clock,
                    ),
                    DashboardMetricData(
                      label: 'Active stays',
                      value: '$activePets',
                      icon: LucideIcons.dog,
                    ),
                    DashboardMetricData(
                      label: 'Completed stays',
                      value: '$completedStays',
                      icon: LucideIcons.checkCircle,
                    ),
                    DashboardMetricData(
                      label: 'Occupancy',
                      value: '$occupancy%',
                      icon: LucideIcons.hotel,
                    ),
                    DashboardMetricData(
                      label: 'Available capacity',
                      value: '$availableCapacity',
                      icon: LucideIcons.bed,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DashboardPanel(
                  child: DashboardSection(
                    title: 'Revenue summary',
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        _SummaryValue(
                          label: 'Recorded revenue',
                          value: '₺${recordedRevenue.toStringAsFixed(2)}',
                        ),
                        _SummaryValue(
                          label: 'Paid bookings',
                          value: '${paidDocs.length}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _bookingPanel(
                  title: 'Upcoming check-ins',
                  emptyText: 'No upcoming check-ins',
                  docs: upcomingDocs,
                ),
                const SizedBox(height: 18),
                _bookingPanel(
                  title: 'Current stays',
                  emptyText: 'No active stays',
                  docs: activeDocs,
                ),
                const SizedBox(height: 18),
                DashboardPanel(
                  child: DashboardSection(
                    title: l10n.pendingRequests,
                    child: pendingDocs.isEmpty
                        ? _emptyBox('No pending hotel booking requests')
                        : Column(
                            children: [
                              for (final doc in pendingDocs)
                                _PendingBookingCard(
                                  bookingId: doc.id,
                                  data: doc.data(),
                                ),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _bookingPanel({
    required String title,
    required String emptyText,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  }) {
    return DashboardPanel(
      child: DashboardSection(
        title: title,
        child: docs.isEmpty
            ? _emptyBox(emptyText)
            : Column(
                children: [
                  for (final doc in docs) _HotelBookingRow(data: doc.data()),
                ],
              ),
      ),
    );
  }

  Widget _profileCard(BuildContext context) {
    final profile = _map(businessData['profile']);
    final contact = _map(businessData['contact']);
    final hotelData = _hotelData(businessData);
    final name =
        (profile['displayName'] ??
                profile['businessName'] ??
                hotelData['hotelName'] ??
                hotelData['businessName'] ??
                'Pet Hotel')
            .toString();
    final description =
        (profile['description'] ??
                profile['bio'] ??
                hotelData['description'] ??
                'No description yet')
            .toString();
    final chips = <String>[
      if ((contact['phone'] ?? '').toString().isNotEmpty)
        '📞 ${contact['phone']}',
      if ((contact['city'] ?? '').toString().isNotEmpty)
        '📍 ${contact['city']}',
      if ((contact['district'] ?? '').toString().isNotEmpty)
        '📍 ${contact['district']}',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: AppTheme.h3(weight: FontWeight.w800)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EditPetHotelProfilePage(businessId: businessId),
                    ),
                  );
                },
                icon: const Icon(LucideIcons.edit2, size: 18),
                label: Text(AppLocalizations.of(context)!.edit),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(description, style: AppTheme.body(color: AppTheme.muted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (chips.isEmpty) _chip('Pet Hotel'),
              ...chips.map(_chip),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(text, style: AppTheme.caption(color: AppTheme.muted)),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black12),
      boxShadow: AppTheme.cardShadow(opacity: 0.06),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF9E1B4F).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: AppTheme.caption(color: const Color(0xFF9E1B4F)),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption(color: AppTheme.muted)),
        const SizedBox(height: 3),
        Text(value, style: AppTheme.h3(weight: FontWeight.w800)),
      ],
    ),
  );
}

class _HotelBookingRow extends StatelessWidget {
  const _HotelBookingRow({required this.data});

  final Map<String, dynamic> data;

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _range() {
    final checkIn = _date(data['checkInDate']);
    final checkOut = _date(data['checkOutDate']);
    if (checkIn == null || checkOut == null) return 'Dates unavailable';
    String format(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    return '${format(checkIn)} → ${format(checkOut)}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.dog, color: Color(0xFF9E1B4F), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${data['petName'] ?? data['dogName'] ?? 'Pet'} • ${data['serviceTitle'] ?? 'Stay'}',
                style: AppTheme.body(weight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(_range(), style: AppTheme.caption(color: AppTheme.muted)),
            ],
          ),
        ),
        Text(
          '${data['status'] ?? 'pending'}',
          style: AppTheme.caption(color: const Color(0xFF9E1B4F)),
        ),
      ],
    ),
  );
}

class _PendingBookingCard extends StatelessWidget {
  final String bookingId;
  final Map<String, dynamic> data;

  const _PendingBookingCard({required this.bookingId, required this.data});

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _range() {
    final checkIn = _date(data['checkInDate']);
    final checkOut = _date(data['checkOutDate']);
    if (checkIn == null || checkOut == null) return '-';
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '${fmt(checkIn)} → ${fmt(checkOut)}';
  }

  Future<void> _update(BuildContext context, String status) async {
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('updateHotelBookingStatus').call({
        'appointmentId': bookingId,
        'bookingId': bookingId,
        'status': status,
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.bookingUpdated(status)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.updateFailed('$e')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = data['totalPrice'] ?? data['price'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data['petName'] ?? data['dogName'] ?? 'Pet'} • ${data['serviceTitle'] ?? 'Stay'}',
            style: AppTheme.bodyMedium().copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(_range(), style: AppTheme.caption(color: AppTheme.muted)),
          const SizedBox(height: 6),
          Text('₺$price', style: AppTheme.caption(color: AppTheme.muted)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      _update(context, _approvalTargetStatus(data)),
                  child: Text(AppLocalizations.of(context)!.accept),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _update(context, 'rejected'),
                  child: Text(AppLocalizations.of(context)!.reject),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _approvalTargetStatus(Map<String, dynamic> data) {
    final rawPrice =
        data['servicePrice'] ?? data['price'] ?? data['pricePerNight'];

    final double price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0;

    final requiresPayment =
        data['serviceRequiresPayment'] == true ||
        data['requiresPayment'] == true ||
        price > 0;

    return requiresPayment ? 'awaiting_payment' : 'confirmed';
  }
}
