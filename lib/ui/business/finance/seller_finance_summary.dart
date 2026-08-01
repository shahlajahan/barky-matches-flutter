import 'package:cloud_firestore/cloud_firestore.dart';

class SellerFinanceAmount {
  const SellerFinanceAmount({required this.count, required this.amount});

  final int count;
  final double amount;

  factory SellerFinanceAmount.fromMap(Object? value) {
    final map = value is Map ? value.cast<String, dynamic>() : const {};
    return SellerFinanceAmount(
      count: (map['count'] as num?)?.toInt() ?? 0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SellerRevenueSummary {
  const SellerRevenueSummary({
    required this.grossSales,
    required this.platformFee,
    required this.adjustments,
    required this.netRevenue,
    required this.paidRecordCount,
    required this.averageTicket,
  });

  final double grossSales;
  final double platformFee;
  final double adjustments;
  final double netRevenue;
  final int paidRecordCount;
  final double averageTicket;

  factory SellerRevenueSummary.fromMap(Object? value) {
    final map = value is Map ? value.cast<String, dynamic>() : const {};
    double number(String key) => (map[key] as num?)?.toDouble() ?? 0;
    return SellerRevenueSummary(
      grossSales: number('grossSales'),
      platformFee: number('platformFee'),
      adjustments: number('adjustments'),
      netRevenue: number('netRevenue'),
      paidRecordCount: (map['paidRecordCount'] as num?)?.toInt() ?? 0,
      averageTicket: number('averageTicket'),
    );
  }
}

class SellerFinanceSummary {
  const SellerFinanceSummary({
    required this.businessId,
    required this.currency,
    required this.available,
    required this.waiting,
    required this.batched,
    required this.paid,
    required this.blocked,
    required this.onHold,
    required this.paidThisMonth,
    required this.totalEarnings,
    required this.nextEligibilityDate,
    required this.daysRemaining,
    required this.amountBecomingEligibleNext,
    required this.countBecomingEligibleNext,
    required this.oldestWaitingPaymentAt,
    required this.bankValidationStatus,
    required this.waitingSchedule,
    required this.lastPayout,
    required this.eligibleRecords,
    required this.payoutHistory,
    required this.exceptions,
    required this.revenue,
  });

  final String businessId;
  final String currency;
  final SellerFinanceAmount available;
  final SellerFinanceAmount waiting;
  final SellerFinanceAmount batched;
  final SellerFinanceAmount paid;
  final SellerFinanceAmount blocked;
  final SellerFinanceAmount onHold;
  final double paidThisMonth;
  final double totalEarnings;
  final DateTime? nextEligibilityDate;
  final int daysRemaining;
  final double amountBecomingEligibleNext;
  final int countBecomingEligibleNext;
  final DateTime? oldestWaitingPaymentAt;
  final String bankValidationStatus;
  final List<Map<String, dynamic>> waitingSchedule;
  final Map<String, dynamic>? lastPayout;
  final List<Map<String, dynamic>> eligibleRecords;
  final List<Map<String, dynamic>> payoutHistory;
  final List<Map<String, dynamic>> exceptions;
  final SellerRevenueSummary revenue;

  factory SellerFinanceSummary.fromMap(Map<String, dynamic> data) {
    DateTime? date(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '');
    }

    return SellerFinanceSummary(
      businessId: (data['businessId'] ?? '').toString(),
      currency: (data['currency'] ?? 'TRY').toString(),
      available: SellerFinanceAmount.fromMap(data['available']),
      waiting: SellerFinanceAmount.fromMap(data['waiting']),
      batched: SellerFinanceAmount.fromMap(data['batched']),
      paid: SellerFinanceAmount.fromMap(data['paid']),
      blocked: SellerFinanceAmount.fromMap(data['blocked']),
      onHold: SellerFinanceAmount.fromMap(data['onHold']),
      paidThisMonth: (data['paidThisMonth'] as num?)?.toDouble() ?? 0,
      totalEarnings: (data['totalEarnings'] as num?)?.toDouble() ?? 0,
      nextEligibilityDate: date(data['nextEligibilityDate']),
      daysRemaining: (data['daysRemaining'] as num?)?.toInt() ?? 0,
      amountBecomingEligibleNext:
          (data['amountBecomingEligibleNext'] as num?)?.toDouble() ?? 0,
      countBecomingEligibleNext:
          (data['countBecomingEligibleNext'] as num?)?.toInt() ?? 0,
      oldestWaitingPaymentAt: date(data['oldestWaitingPaymentAt']),
      bankValidationStatus: (data['bankValidationStatus'] ?? 'missing')
          .toString(),
      waitingSchedule: (data['waitingSchedule'] as List? ?? [])
          .whereType<Map>()
          .map((entry) => entry.cast<String, dynamic>())
          .toList(),
      lastPayout: data['lastPayout'] is Map
          ? (data['lastPayout'] as Map).cast<String, dynamic>()
          : null,
      eligibleRecords: _mapList(data['eligibleRecords']),
      payoutHistory: _mapList(data['payoutHistory']),
      exceptions: _mapList(data['exceptions']),
      revenue: SellerRevenueSummary.fromMap(data['revenue']),
    );
  }

  static List<Map<String, dynamic>> _mapList(Object? value) {
    return (value as List? ?? const [])
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .toList();
  }
}
