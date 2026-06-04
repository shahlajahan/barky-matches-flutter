import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/pet_hotel/edit_pet_hotel_profile_page.dart';

class PetHotelDashboardOverviewTab extends StatelessWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  const PetHotelDashboardOverviewTab({
    super.key,
    required this.businessId,
    required this.businessData,
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

    debugPrint(
      '🔥 LISTENING PATH => hotel_bookings where businessId == $businessId',
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        debugPrint('🔥 DOC COUNT => ${snapshot.data?.docs.length}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Booking error: ${snapshot.error}',
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
        final revenue = docs.fold<double>(0, (sum, doc) {
          final data = doc.data();
          final status = data['status']?.toString() ?? '';
          final paymentStatus = data['paymentStatus']?.toString() ?? '';
          if (status == 'confirmed_paid' ||
              status == 'completed' ||
              paymentStatus == 'paid') {
            return sum + _money(data['totalPrice'] ?? data['price']);
          }
          return sum;
        });
        final occupancy = maxCapacity <= 0
            ? 0
            : ((activePets / maxCapacity) * 100).clamp(0, 100).round();
        final paidDocs = docs
            .where((doc) => _isPaidBooking(doc.data()))
            .toList();
        double grossSales = 0;
        double commissionTotal = 0;

        for (final doc in paidDocs) {
          final data = doc.data();
          grossSales += _money(
            data['totalPrice'] ?? data['price'] ?? data['finalPrice'],
          );
          commissionTotal += _money(
            data['platformCommissionAmount'] ??
                data['commissionAmount'] ??
                data['platformFee'],
          );
        }

        final netRevenue = grossSales - commissionTotal;
        final averageTicket = paidDocs.isEmpty
            ? 0.0
            : grossSales / paidDocs.length;

        final pendingDocs = docs
            .where((doc) => doc.data()['status'] == 'pending')
            .take(3)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hotel Profile', style: AppTheme.h2()),
            const SizedBox(height: 10),
            _profileCard(context),
            const SizedBox(height: 20),
            Text('Revenue', style: AppTheme.h2()),
            const SizedBox(height: 10),
            _revenueCard(
              netRevenue: netRevenue,
              grossSales: grossSales,
              commissionTotal: commissionTotal,
              paidBookingCount: paidDocs.length,
              averageTicket: averageTicket,
            ),
            const SizedBox(height: 20),
            Text('Hotel Overview', style: AppTheme.h2()),
            const SizedBox(height: 12),
            Row(
              children: [
                _KpiCard(
                  title: 'Bookings',
                  value: '$totalBookings',
                  icon: LucideIcons.calendarDays,
                ),
                const SizedBox(width: 10),
                _KpiCard(
                  title: 'Active pets',
                  value: '$activePets',
                  icon: LucideIcons.dog,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _KpiCard(
                  title: 'Pending',
                  value: '$pendingRequests',
                  icon: LucideIcons.clock,
                ),
                const SizedBox(width: 10),
                _KpiCard(
                  title: 'Completed',
                  value: '$completedStays',
                  icon: LucideIcons.checkCircle,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _KpiCard(
                  title: 'Revenue',
                  value: '₺${revenue.toStringAsFixed(0)}',
                  icon: LucideIcons.wallet,
                ),
                const SizedBox(width: 10),
                _KpiCard(
                  title: 'Occupancy',
                  value: '$occupancy%',
                  icon: LucideIcons.hotel,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text('Pending Requests', style: AppTheme.h2()),
            const SizedBox(height: 10),
            if (pendingDocs.isEmpty)
              _emptyBox('No pending hotel booking requests')
            else
              ...pendingDocs.map(
                (doc) =>
                    _PendingBookingCard(bookingId: doc.id, data: doc.data()),
              ),
          ],
        );
      },
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
                label: const Text('Edit'),
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

  Widget _revenueCard({
    required double netRevenue,
    required double grossSales,
    required double commissionTotal,
    required int paidBookingCount,
    required double averageTicket,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF9E1B4F),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Net Revenue', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            '₺${netRevenue.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'After platform commission',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _revenueRow('Gross Sales', grossSales),
          _revenueRow('Platform Fee', -commissionTotal),
          const SizedBox(height: 14),
          Row(
            children: [
              _revenueKpi(
                label: 'Paid Bookings',
                value: paidBookingCount.toString(),
              ),
              const SizedBox(width: 10),
              _revenueKpi(
                label: 'Average Ticket',
                value: '₺${averageTicket.toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _revenueRow(String title, double value) {
    final isNegative = value < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          Text(
            '${isNegative ? '-' : ''}₺${value.abs().toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _revenueKpi({required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow(opacity: 0.05),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF9E1B4F)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodyMedium().copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(title, style: AppTheme.caption(color: AppTheme.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Booking updated: $status')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
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
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _update(context, 'rejected'),
                  child: const Text('Reject'),
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
