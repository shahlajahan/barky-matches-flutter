import 'package:cloud_firestore/cloud_firestore.dart';

enum VetRevenueStatus {
  recognizedPaid,
  pending,
  refunded,
  expired,
  financialDataMissing,
  other,
}

enum VetRevenueRange { last7Days, last30Days, last90Days, thisYear, allTime }

double? vetRevenueSafeNumber(Object? value) {
  if (value is num) {
    final parsed = value.toDouble();
    return parsed.isFinite && parsed >= 0 ? parsed : null;
  }
  if (value is String) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
  }
  return null;
}

DateTime? vetRevenueSafeDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value.trim());
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

String vetRevenueNormalizeStatus(Object? value) =>
    value?.toString().trim().toLowerCase().replaceAll('-', '_') ?? '';

Map<String, dynamic> _map(Object? value) {
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

class VetRevenueTransaction {
  const VetRevenueTransaction({
    required this.appointmentId,
    required this.customerName,
    required this.petName,
    required this.serviceTitle,
    required this.serviceCategory,
    required this.eventDate,
    required this.paidAt,
    required this.scheduledAt,
    required this.currency,
    required this.grossAmount,
    required this.commissionAmount,
    required this.businessNetAmount,
    required this.businessReceivable,
    required this.opportunityAmount,
    required this.paymentStatus,
    required this.appointmentStatus,
    required this.payoutStatus,
    required this.settlementStatus,
    required this.settlementPaidAt,
    required this.invoiceStatus,
    required this.paymentTransactionId,
    required this.status,
    required this.hasFinancialData,
  });

  final String appointmentId;
  final String customerName;
  final String petName;
  final String serviceTitle;
  final String serviceCategory;
  final DateTime? eventDate;
  final DateTime? paidAt;
  final DateTime? scheduledAt;
  final String currency;
  final double? grossAmount;
  final double? commissionAmount;
  final double? businessNetAmount;
  final double? businessReceivable;
  final double? opportunityAmount;
  final String paymentStatus;
  final String appointmentStatus;
  final String payoutStatus;
  final String settlementStatus;
  final DateTime? settlementPaidAt;
  final String invoiceStatus;
  final String paymentTransactionId;
  final VetRevenueStatus status;
  final bool hasFinancialData;

  bool get isRecognizedRevenue => status == VetRevenueStatus.recognizedPaid;

  factory VetRevenueTransaction.fromMap(
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    final financial = _map(data['financial']);
    final settlement = _map(financial['settlement']);
    final ownerProfile = _map(data['ownerProfile']);
    final invoice = _map(data['invoice']);
    final paymentStatus = vetRevenueNormalizeStatus(data['paymentStatus']);
    final appointmentStatus = vetRevenueNormalizeStatus(data['status']);
    final refundStatus = vetRevenueNormalizeStatus(data['refundStatus']);
    final paidAt = vetRevenueSafeDate(data['paidAt']);
    final scheduledAt = vetRevenueSafeDate(
      data['scheduledAt'] ?? data['scheduledDateTime'],
    );
    final createdAt = vetRevenueSafeDate(data['createdAt']);
    final gross = vetRevenueSafeNumber(
      financial['finalPrice'] ?? financial['grossAmount'],
    );
    final commission = vetRevenueSafeNumber(financial['commissionAmount']);
    final net = vetRevenueSafeNumber(
      financial['businessNetAmount'] ?? financial['sellerNetAmount'],
    );
    final hasFinancialData =
        financial.isNotEmpty &&
        gross != null &&
        commission != null &&
        net != null;

    late final VetRevenueStatus status;
    if (paymentStatus == 'refunded' || refundStatus == 'refunded') {
      status = VetRevenueStatus.refunded;
    } else if (paymentStatus == 'expired' ||
        appointmentStatus == 'payment_expired') {
      status = VetRevenueStatus.expired;
    } else if (const {
      'pending',
      'awaiting_payment',
      'payment_pending',
    }.contains(paymentStatus)) {
      status = VetRevenueStatus.pending;
    } else if (paymentStatus == 'paid') {
      status = paidAt != null && hasFinancialData
          ? VetRevenueStatus.recognizedPaid
          : VetRevenueStatus.financialDataMissing;
    } else {
      status = VetRevenueStatus.other;
    }

    final rawCurrency =
        (data['currency'] ??
                financial['currency'] ??
                data['paymentCurrency'] ??
                _map(data['payment'])['currency'] ??
                'TRY')
            .toString()
            .trim()
            .toUpperCase();

    return VetRevenueTransaction(
      appointmentId: appointmentId,
      customerName: (ownerProfile['ownerName'] ?? data['ownerName'] ?? '')
          .toString()
          .trim(),
      petName: (data['petName'] ?? data['dogName'] ?? '').toString().trim(),
      serviceTitle: (data['serviceTitle'] ?? '').toString().trim(),
      serviceCategory: (data['serviceCategory'] ?? '').toString().trim(),
      eventDate: paidAt ?? scheduledAt ?? createdAt,
      paidAt: paidAt,
      scheduledAt: scheduledAt,
      currency: rawCurrency.isEmpty ? 'TRY' : rawCurrency,
      grossAmount: gross,
      commissionAmount: commission,
      businessNetAmount: net,
      businessReceivable: vetRevenueSafeNumber(
        financial['businessReceivable'] ?? financial['sellerNetAmount'],
      ),
      opportunityAmount: vetRevenueSafeNumber(
        data['price'] ?? data['servicePrice'],
      ),
      paymentStatus: paymentStatus,
      appointmentStatus: appointmentStatus,
      payoutStatus: vetRevenueNormalizeStatus(financial['payoutStatus']),
      settlementStatus: vetRevenueNormalizeStatus(settlement['status']),
      settlementPaidAt: vetRevenueSafeDate(settlement['paidAt']),
      invoiceStatus: vetRevenueNormalizeStatus(
        invoice['status'] ?? data['invoiceStatus'],
      ),
      paymentTransactionId:
          (data['paymentTransactionId'] ??
                  data['paymentId'] ??
                  data['orderId'] ??
                  '')
              .toString()
              .trim(),
      status: status,
      hasFinancialData: hasFinancialData,
    );
  }
}

class VetRevenueCurrencyTotals {
  const VetRevenueCurrencyTotals({
    required this.currency,
    required this.gross,
    required this.commission,
    required this.net,
    required this.pendingSettlement,
  });

  final String currency;
  final double gross;
  final double commission;
  final double net;
  final double pendingSettlement;
}

class VetRevenueSummary {
  const VetRevenueSummary({
    required this.totalsByCurrency,
    required this.paidTransactions,
    required this.pendingPayments,
    required this.refundedTransactions,
    required this.expiredOpportunities,
    required this.financialDataMissing,
  });

  final Map<String, VetRevenueCurrencyTotals> totalsByCurrency;
  final int paidTransactions;
  final int pendingPayments;
  final int refundedTransactions;
  final int expiredOpportunities;
  final int financialDataMissing;

  bool get hasMixedCurrencies => totalsByCurrency.length > 1;
  bool get isEmpty =>
      paidTransactions == 0 &&
      pendingPayments == 0 &&
      refundedTransactions == 0 &&
      expiredOpportunities == 0 &&
      financialDataMissing == 0;

  factory VetRevenueSummary.fromTransactions(
    Iterable<VetRevenueTransaction> transactions,
  ) {
    final mutable = <String, List<double>>{};
    var paid = 0;
    var pending = 0;
    var refunded = 0;
    var expired = 0;
    var missing = 0;

    for (final transaction in transactions) {
      switch (transaction.status) {
        case VetRevenueStatus.recognizedPaid:
          paid++;
          final values = mutable.putIfAbsent(
            transaction.currency,
            () => <double>[0, 0, 0, 0],
          );
          values[0] += transaction.grossAmount!;
          values[1] += transaction.commissionAmount!;
          values[2] += transaction.businessNetAmount!;
          final isSettled =
              transaction.settlementPaidAt != null ||
              const {
                'paid',
                'settled',
                'completed',
              }.contains(transaction.payoutStatus) ||
              const {
                'paid',
                'settled',
                'completed',
              }.contains(transaction.settlementStatus);
          if (!isSettled) {
            values[3] +=
                transaction.businessReceivable ??
                transaction.businessNetAmount!;
          }
        case VetRevenueStatus.pending:
          pending++;
        case VetRevenueStatus.refunded:
          refunded++;
        case VetRevenueStatus.expired:
          expired++;
        case VetRevenueStatus.financialDataMissing:
          missing++;
        case VetRevenueStatus.other:
          break;
      }
    }

    return VetRevenueSummary(
      totalsByCurrency: {
        for (final entry in mutable.entries)
          entry.key: VetRevenueCurrencyTotals(
            currency: entry.key,
            gross: entry.value[0],
            commission: entry.value[1],
            net: entry.value[2],
            pendingSettlement: entry.value[3],
          ),
      },
      paidTransactions: paid,
      pendingPayments: pending,
      refundedTransactions: refunded,
      expiredOpportunities: expired,
      financialDataMissing: missing,
    );
  }
}

class VetRevenuePoint {
  const VetRevenuePoint({
    required this.date,
    required this.currency,
    required this.gross,
    required this.net,
  });

  final DateTime date;
  final String currency;
  final double gross;
  final double net;
}

List<VetRevenueTransaction> filterVetRevenueRange(
  Iterable<VetRevenueTransaction> transactions,
  VetRevenueRange range, {
  DateTime? now,
}) {
  if (range == VetRevenueRange.allTime) return transactions.toList();
  final current = now ?? DateTime.now();
  final start = switch (range) {
    VetRevenueRange.last7Days => current.subtract(const Duration(days: 7)),
    VetRevenueRange.last30Days => current.subtract(const Duration(days: 30)),
    VetRevenueRange.last90Days => current.subtract(const Duration(days: 90)),
    VetRevenueRange.thisYear => DateTime(current.year),
    VetRevenueRange.allTime => DateTime.fromMillisecondsSinceEpoch(0),
  };
  return transactions
      .where(
        (transaction) =>
            transaction.eventDate != null &&
            !transaction.eventDate!.isBefore(start),
      )
      .toList();
}

DateTime _bucketDate(DateTime date, VetRevenueRange range) {
  if (range == VetRevenueRange.last90Days) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }
  if (range == VetRevenueRange.thisYear || range == VetRevenueRange.allTime) {
    return DateTime(date.year, date.month);
  }
  return DateTime(date.year, date.month, date.day);
}

List<VetRevenuePoint> buildVetRevenuePoints(
  Iterable<VetRevenueTransaction> transactions,
  VetRevenueRange range,
) {
  final buckets = <(DateTime, String), List<double>>{};
  for (final transaction in transactions.where(
    (item) => item.isRecognizedRevenue,
  )) {
    final paidAt = transaction.paidAt;
    if (paidAt == null) continue;
    final key = (_bucketDate(paidAt, range), transaction.currency);
    final values = buckets.putIfAbsent(key, () => <double>[0, 0]);
    values[0] += transaction.grossAmount!;
    values[1] += transaction.businessNetAmount!;
  }
  final points =
      buckets.entries
          .map(
            (entry) => VetRevenuePoint(
              date: entry.key.$1,
              currency: entry.key.$2,
              gross: entry.value[0],
              net: entry.value[1],
            ),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  return points;
}
