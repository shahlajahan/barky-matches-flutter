import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class PetTaxiDashboardBookingsTab extends StatefulWidget {
  final String businessId;
  const PetTaxiDashboardBookingsTab({super.key, required this.businessId});

  @override
  State<PetTaxiDashboardBookingsTab> createState() =>
      _PetTaxiDashboardBookingsTabState();
}

class _PetTaxiDashboardBookingsTabState
    extends State<PetTaxiDashboardBookingsTab> {
  late final TextEditingController _finalPriceController;
  @override
  void dispose() {
    _finalPriceController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _finalPriceController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('pet_taxi_bookings')
        .where('businessId', isEqualTo: widget.businessId)
        .snapshots()
        .handleError((e) {
          debugPrint('PetTaxi bookings stream error: ${e.toString()}');
        });

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
        docs.sort((a, b) {
          final aStatus = a.data()['status']?.toString() ?? '';
          final bStatus = b.data()['status']?.toString() ?? '';
          if (aStatus == 'pending' && bStatus != 'pending') return -1;
          if (aStatus != 'pending' && bStatus == 'pending') return 1;
          final aDate = _date(a.data()['scheduledAt']);
          final bDate = _date(b.data()['scheduledAt']);
          if (aDate == null || bDate == null) return 0;
          return aDate.compareTo(bDate);
        });

        if (docs.isEmpty) return _centerText('No pet taxi bookings yet');

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

  Widget _bookingCard(
    BuildContext context,
    String bookingId,
    Map<String, dynamic> data,
  ) {
    final status = data['status']?.toString() ?? 'pending';
    final color = _statusColor(status);

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
                      data['petName']?.toString() ?? 'Pet',
                      style: AppTheme.bodyMedium().copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      data['userPhone']?.toString() ?? '',
                      style: AppTheme.caption(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row(LucideIcons.mapPin, data['pickupAddress']),
          const SizedBox(height: 8),
          _row(LucideIcons.flag, data['dropoffAddress']),
          const SizedBox(height: 8),
          _row(LucideIcons.calendarClock, _dateText(data['scheduledAt'])),
          const SizedBox(height: 8),
          _row(LucideIcons.navigation, _routeText(data)),
          const SizedBox(height: 8),
          _row(
            LucideIcons.info,
            '${data['tripType'] ?? '-'} • ${data['serviceReason'] ?? '-'} • ${data['petSize'] ?? '-'}',
          ),
          const SizedBox(height: 8),
          _row(LucideIcons.badgeDollarSign, _pricingText(data)),
          const SizedBox(height: 8),
          _row(LucideIcons.creditCard, _paymentText(data)),
          if ((data['specialNotes']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              data['specialNotes'].toString(),
              style: AppTheme.body(color: AppTheme.muted),
            ),
          ],
          const SizedBox(height: 14),
          _actions(context, bookingId, status, data),
        ],
      ),
    );
  }

  Widget _actions(
    BuildContext context,
    String bookingId,
    String status,
    Map<String, dynamic> data,
  ) {
    if (status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showFinalPriceDialog(context, bookingId, data),
              child: const Text('Propose Final Price'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _confirmAndUpdate(
                context,
                bookingId,
                'cancelled_by_business',
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      );
    }

    if (status == 'awaiting_user_payment' || status == 'payment_failed') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showFinalPriceDialog(context, bookingId, data),
              child: const Text('Edit Proposed Price'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _confirmAndUpdate(
                context,
                bookingId,
                'cancelled_by_business',
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      );
    }

    final next = _nextStatus(status);
    if (next != null) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _confirmAndUpdate(context, bookingId, next),
              child: Text(_label(next)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _confirmAndUpdate(
                context,
                bookingId,
                'cancelled_by_business',
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      );
    }

    return Text(
      'Already ${status.replaceAll('_', ' ').toUpperCase()}',
      style: AppTheme.caption(color: AppTheme.muted),
    );
  }

  Future<void> _confirmAndUpdate(
    BuildContext context,
    String bookingId,
    String status,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_label(status)}?'),
        content: const Text('This will notify the customer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west3')
          .httpsCallable('updatePetTaxiBookingStatus')
          .call({'bookingId': bookingId, 'newStatus': status});
    } catch (e) {
      debugPrint('PetTaxi status update error: ${e.toString()}');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _showFinalPriceDialog(
    BuildContext context,
    String bookingId,
    Map<String, dynamic> data,
  ) async {
    _finalPriceController.text = data['finalPrice']?.toString() ?? '';
    final currency = data['estimateCurrency']?.toString() ?? 'TRY';
    final formKey = GlobalKey<FormState>();

    final price = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Propose final price'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _estimateText(data),
                style: AppTheme.caption(color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _finalPriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Final price',
                  suffixText: currency,
                ),
                validator: (value) {
                  final parsed = double.tryParse(
                    (value ?? '').replaceAll(',', '.'),
                  );
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid final price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'The customer must pay this amount in the app before the trip can start.',
                style: AppTheme.caption(color: AppTheme.muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(
                context,
                double.parse(_finalPriceController.text.replaceAll(',', '.')),
              );
            },
            child: const Text('Send Price'),
          ),
        ],
      ),
    );

    if (price == null) return;

    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('updatePetTaxiBookingStatus').call({
        'bookingId': bookingId,
        'newStatus': 'awaiting_user_payment',
        'finalPrice': price,
        'finalPriceCurrency': currency,
      });
    } catch (e) {
      debugPrint('PetTaxi final price update error: ${e.toString()}');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _row(IconData icon, dynamic text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF9E1B4F)),
        const SizedBox(width: 8),
        Expanded(child: Text(text?.toString() ?? '-', style: AppTheme.body())),
      ],
    );
  }

  String? _nextStatus(String status) {
    switch (status) {
      case 'confirmed_paid':
        return 'driver_on_the_way';
      case 'driver_on_the_way':
        return 'arrived';
      case 'arrived':
        return 'pet_picked_up';
      case 'pet_picked_up':
        return 'on_trip';
      case 'on_trip':
        return 'completed';
    }
    return null;
  }

  String _pricingText(Map<String, dynamic> data) {
    final estimate = _estimateText(data);
    final finalPrice = data['finalPrice'];
    final currency =
        data['finalPriceCurrency']?.toString() ??
        data['estimateCurrency']?.toString() ??
        'TRY';
    if (finalPrice is num && finalPrice > 0) {
      return '$estimate • Final: ${finalPrice.toStringAsFixed(0)} $currency';
    }
    return '$estimate • Final price not proposed';
  }

  String _paymentText(Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? '';
    final paymentStatus = data['paymentStatus']?.toString() ?? 'unpaid';
    final amount = data['paymentAmount'] ?? data['finalPrice'];
    final currency =
        data['paymentCurrency']?.toString() ??
        data['finalPriceCurrency']?.toString() ??
        'TRY';
    final amountText = amount is num
        ? ' • ${amount.toStringAsFixed(0)} $currency'
        : '';
    if (status == 'confirmed_paid' || paymentStatus == 'paid') {
      return 'Paid$amountText • payout after completion';
    }
    if (status == 'awaiting_user_payment') {
      return 'Awaiting user payment$amountText';
    }
    if (status == 'payment_failed' || paymentStatus == 'failed') {
      return 'Payment failed$amountText';
    }
    return '$paymentStatus$amountText';
  }

  String _routeText(Map<String, dynamic> data) {
    final distance = data['routeDistanceKm'] ?? data['estimatedDistanceKm'];
    final duration = data['routeDurationMinutes'];
    if (distance is num && duration is num) {
      return '${distance.toStringAsFixed(1)} km driving route • ${duration.round()} min';
    }
    if (distance is num) {
      return '${distance.toStringAsFixed(1)} km driving route';
    }
    return 'Route distance not available';
  }

  String _estimateText(Map<String, dynamic> data) {
    final min = data['estimatedMinPrice'];
    final max = data['estimatedMaxPrice'];
    final currency = data['estimateCurrency']?.toString() ?? 'TRY';
    if (min is num && max is num) {
      return 'Estimate: ${min.toStringAsFixed(0)} - ${max.toStringAsFixed(0)} $currency';
    }
    return 'Estimate not available';
  }

  String _label(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) {
          if (part.isEmpty) return part;
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _dateText(dynamic value) {
    final date = _date(value);
    if (date == null) return '-';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled_by_user':
      case 'cancelled_by_business':
        return Colors.red;
      case 'pending':
      case 'awaiting_user_payment':
      case 'payment_failed':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Widget _centerText(String text) {
    return Center(
      child: Text(text, style: AppTheme.body(color: AppTheme.muted)),
    );
  }
}
