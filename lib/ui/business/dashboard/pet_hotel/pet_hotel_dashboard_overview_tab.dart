import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

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
    
    debugPrint('🔥 LISTENING PATH => hotel_bookings where businessId == $businessId');

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

        final pendingDocs = docs
            .where((doc) => doc.data()['status'] == 'pending')
            .take(3)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                  onPressed: () => _update(
  context,
  _approvalTargetStatus(data),
),
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
      data['servicePrice'] ??
      data['price'] ??
      data['pricePerNight'];

  final double price = rawPrice is num
      ? rawPrice.toDouble()
      : double.tryParse(rawPrice?.toString() ?? '') ?? 0;

  final requiresPayment =
      data['serviceRequiresPayment'] == true ||
      data['requiresPayment'] == true ||
      price > 0;

  return requiresPayment
      ? 'awaiting_payment'
      : 'confirmed';
}
}
