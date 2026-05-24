import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/petshop/petshop_checkout_webview_page.dart';

class PetTaxiBookingDetailPage extends StatefulWidget {
  final String bookingId;

  const PetTaxiBookingDetailPage({super.key, required this.bookingId});

  @override
  State<PetTaxiBookingDetailPage> createState() =>
      _PetTaxiBookingDetailPageState();
}

class _PetTaxiBookingDetailPageState extends State<PetTaxiBookingDetailPage> {
  bool _updating = false;
  bool _paying = false;

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: const Text('The taxi business will be notified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _updating = true);
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('updatePetTaxiBookingStatus').call({
        'bookingId': widget.bookingId,
        'newStatus': 'cancelled_by_user',
      });
    } catch (e) {
      debugPrint('PetTaxiBookingDetail cancel error: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _rejectPrice() async {
    await _priceDecision(
      newStatus: 'cancelled_by_user',
      title: 'Reject final price?',
      message:
          'This will cancel your Pet Taxi booking and notify the provider.',
      priceRejected: true,
    );
  }

  Future<void> _startPayment() async {
    if (_paying) return;
    setState(() => _paying = true);

    try {
      final createCallable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('createPetTaxiOrder');

      final res = await createCallable.call({
        'bookingId': widget.bookingId,
        'appointmentId': widget.bookingId,
        'appointmentCollection': 'pet_taxi_bookings',
        'appointmentType': 'pet_taxi',
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      final orderId = data['orderId']?.toString();
      final checkoutUrl = data['checkoutUrl']?.toString();
      if (orderId == null || checkoutUrl == null || checkoutUrl.isEmpty) {
        throw StateError('Payment order did not return checkout URL');
      }

      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PetshopCheckoutWebViewPage(
            checkoutUrl: checkoutUrl,
            successUrlPrefix: 'payment-success',
            cancelUrlPrefix: 'payment-cancel',
            orderId: orderId,
          ),
        ),
      );

      if (result == 'verify') {
        final verifyCallable = FirebaseFunctions.instanceFor(
          region: 'europe-west3',
        ).httpsCallable('verifyPetTaxiPayment');
        await verifyCallable.call({'orderId': orderId});
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Payment successful')));
        }
      } else if (result == 'cancel' && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment cancelled')));
      }
    } catch (e) {
      debugPrint('PetTaxiBookingDetail payment error: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _priceDecision({
    required String newStatus,
    required String title,
    required String message,
    required bool priceRejected,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _updating = true);
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('updatePetTaxiBookingStatus').call({
        'bookingId': widget.bookingId,
        'newStatus': newStatus,
        if (priceRejected) 'priceRejected': true,
      });
    } catch (e) {
      debugPrint('PetTaxiBookingDetail price decision error: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Pet Taxi Booking')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('pet_taxi_bookings')
            .doc(widget.bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Booking error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('Booking not found'));
          }

          final data = snapshot.data!.data() ?? {};
          final status = data['status']?.toString() ?? 'pending';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(data, status),
              const SizedBox(height: 12),
              _info(LucideIcons.mapPin, 'Pickup', data['pickupAddress']),
              _info(LucideIcons.flag, 'Dropoff', data['dropoffAddress']),
              _info(LucideIcons.navigation, 'Route', _routeText(data)),
              _info(
                LucideIcons.calendarClock,
                'Pickup time',
                _dateText(data['scheduledAt']),
              ),
              _info(LucideIcons.dog, 'Pet', data['petName']),
              _info(LucideIcons.phone, 'Phone', data['userPhone']),
              _info(
                LucideIcons.creditCard,
                'Payment',
                _paymentText(data, status),
              ),
              _info(
                LucideIcons.badgeDollarSign,
                'Estimated price',
                _estimateText(data),
              ),
              if (data['finalPrice'] is num)
                _info(
                  LucideIcons.wallet,
                  'Provider final price',
                  _finalPriceText(data),
                ),
              if ((data['specialNotes']?.toString() ?? '').isNotEmpty)
                _info(LucideIcons.fileText, 'Notes', data['specialNotes']),
              const SizedBox(height: 16),
              if (status == 'awaiting_user_payment' ||
                  status == 'payment_failed')
                _paymentActions(data),
              if (status == 'awaiting_user_payment' ||
                  status == 'payment_failed')
                const SizedBox(height: 10),
              if (_canUserCancel(status))
                OutlinedButton.icon(
                  onPressed: _updating ? null : _cancel,
                  icon: const Icon(LucideIcons.x),
                  label: _updating
                      ? const Text('Updating...')
                      : const Text('Cancel booking'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(Map<String, dynamic> data, String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(LucideIcons.car, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['businessName']?.toString() ?? 'Pet Taxi',
                  style: AppTheme.bodyMedium().copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, dynamic value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _box(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9E1B4F)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.caption(color: AppTheme.muted)),
                const SizedBox(height: 3),
                Text(value?.toString() ?? '-', style: AppTheme.body()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentActions(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pet Taxi payment',
            style: AppTheme.bodyMedium().copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text('Final price: ${_finalPriceText(data)}', style: AppTheme.body()),
          const SizedBox(height: 6),
          Text(
            'Payment is required before the trip starts. Provider payout is prepared after trip completion.',
            style: AppTheme.caption(color: AppTheme.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_updating || _paying) ? null : _startPayment,
                  icon: const Icon(LucideIcons.creditCard),
                  label: Text(_paying ? 'Opening...' : 'Pay Now'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _updating ? null : _rejectPrice,
                  icon: const Icon(LucideIcons.x),
                  label: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _canUserCancel(String status) {
    return const [
      'pending',
      'awaiting_user_payment',
      'payment_failed',
      'driver_on_the_way',
    ].contains(status);
  }

  String _estimateText(Map<String, dynamic> data) {
    final min = data['estimatedMinPrice'];
    final max = data['estimatedMaxPrice'];
    final currency = data['estimateCurrency']?.toString() ?? 'TRY';
    if (min is num && max is num) {
      return '≈ ${min.toStringAsFixed(0)} - ${max.toStringAsFixed(0)} $currency\nEstimated based on Istanbul taxi tariff + pet transport service premium. Bridge, highway, waiting and provider-specific fees may be added. Final price will be confirmed by provider.';
    }
    return 'Estimated based on Istanbul taxi tariff + pet transport service premium. Bridge, highway, waiting and provider-specific fees may be added. Final price will be confirmed by provider.';
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
    return '-';
  }

  String _finalPriceText(Map<String, dynamic> data) {
    final finalPrice = data['finalPrice'];
    final currency =
        data['finalPriceCurrency']?.toString() ??
        data['estimateCurrency']?.toString() ??
        'TRY';
    if (finalPrice is num && finalPrice > 0) {
      return '${finalPrice.toStringAsFixed(0)} $currency';
    }
    return 'Waiting for provider';
  }

  String _paymentText(Map<String, dynamic> data, String status) {
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
      return 'Paid$amountText';
    }
    if (status == 'awaiting_user_payment') {
      return 'Awaiting in-app payment$amountText';
    }
    if (status == 'payment_failed' || paymentStatus == 'failed') {
      return 'Payment failed. Retry available$amountText';
    }
    return '$paymentStatus$amountText';
  }

  String _dateText(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (value is String) date = DateTime.tryParse(value);
    if (date == null) return '-';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed_paid':
      case 'driver_on_the_way':
      case 'arrived':
      case 'pet_picked_up':
      case 'on_trip':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled_by_user':
      case 'cancelled_by_business':
        return Colors.red;
      case 'awaiting_user_payment':
      case 'payment_failed':
        return Colors.orange;
      default:
        return Colors.orange;
    }
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black12),
      boxShadow: AppTheme.cardShadow(opacity: 0.05),
    );
  }
}
