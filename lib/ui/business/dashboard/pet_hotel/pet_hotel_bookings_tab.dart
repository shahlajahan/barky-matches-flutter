import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class PetHotelBookingsTab extends StatelessWidget {
  final String businessId;

  const PetHotelBookingsTab({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('hotel_bookings')
        .where('businessId', isEqualTo: businessId)
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
        if (snapshot.hasError) {
          return _centerText('Booking error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs =
            snapshot.data?.docs.toList() ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (docs.isEmpty) {
          return _centerText('No hotel bookings yet');
        }

        docs.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aStatus = aData['status']?.toString() ?? '';
          final bStatus = bData['status']?.toString() ?? '';
          if (aStatus == 'pending' && bStatus != 'pending') return -1;
          if (aStatus != 'pending' && bStatus == 'pending') return 1;
          final aDate = _date(aData['checkInDate']);
          final bDate = _date(bData['checkInDate']);
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            return _bookingCard(context, doc.id, doc.data());
          },
        );
      },
    );
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _dateText(dynamic value) {
    final date = _date(value);
    if (date == null) return '-';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _bookingCard(
    BuildContext context,
    String bookingId,
    Map<String, dynamic> data,
  ) {
    final status = data['status']?.toString() ?? 'pending';
    final petName = data['petName'] ?? data['dogName'] ?? 'Pet';
    final breed = data['petBreed'] ?? '-';
    final serviceTitle = data['serviceTitle'] ?? 'Stay';
    final nights = data['totalNights'] ?? '-';
    final price = data['totalPrice'] ?? data['price'] ?? 0;
    final notes = data['note'] ?? data['notes'] ?? '';
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: AppTheme.cardShadow(opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      petName.toString(),
                      style: AppTheme.bodyMedium().copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(breed.toString(), style: AppTheme.caption()),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row(LucideIcons.hotel, '$serviceTitle • $nights night(s) • ₺$price'),
          const SizedBox(height: 10),
          _row(
            LucideIcons.calendarDays,
            '${_dateText(data['checkInDate'])} → ${_dateText(data['checkOutDate'])}',
          ),
          if (notes.toString().trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF9E1B4F).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                notes.toString(),
                style: AppTheme.body(color: AppTheme.muted),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _actions(context, bookingId, status),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, String bookingId, String status) {
    if (status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () =>
                  _updateBookingStatus(context, bookingId, 'confirmed'),
              child: const Text('Accept'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () =>
                  _updateBookingStatus(context, bookingId, 'rejected'),
              child: const Text('Reject'),
            ),
          ),
        ],
      );
    }

    if (status == 'confirmed' || status == 'confirmed_paid') {
      return Row(
        children: [
          if (status == 'confirmed' || status == 'confirmed_paid') ...[
            Expanded(
              child: ElevatedButton(
                onPressed: () =>
                    _updateBookingStatus(context, bookingId, 'checked_in'),
                child: const Text('Check In'),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: OutlinedButton(
              onPressed: () => _updateBookingStatus(
                context,
                bookingId,
                'cancelled_by_hotel',
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      );
    }

    if (status == 'checked_in') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () =>
              _updateBookingStatus(context, bookingId, 'completed'),
          child: const Text('Complete Stay'),
        ),
      );
    }

    return Center(
      child: Text(
        'Already ${status.toUpperCase()}',
        style: AppTheme.caption(color: Colors.grey),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9E1B4F)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: AppTheme.body(color: AppTheme.muted)),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'confirmed_paid':
      case 'checked_in':
        return Colors.green;
      case 'rejected':
      case 'cancelled_by_user':
      case 'cancelled_by_hotel':
      case 'payment_expired':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Future<void> _updateBookingStatus(
    BuildContext context,
    String bookingId,
    String status,
  ) async {
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('updateHotelBookingStatus').call({
        'bookingId': bookingId,
        'appointmentId': bookingId,
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

  Widget _centerText(String text) {
    return Center(
      child: Text(text, style: AppTheme.body(color: AppTheme.muted)),
    );
  }
}
