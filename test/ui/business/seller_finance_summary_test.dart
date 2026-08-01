import 'package:barky_matches_fixed/ui/business/finance/seller_finance_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'seller finance summary reads canonical projection without recalculation',
    () {
      final summary = SellerFinanceSummary.fromMap({
        'businessId': 'business-1',
        'currency': 'TRY',
        'available': {'count': 2, 'amount': 88.0},
        'waiting': {'count': 1, 'amount': 44.0},
        'batched': {'count': 3, 'amount': 132.0},
        'paid': {'count': 4, 'amount': 176.0},
        'blocked': {'count': 1, 'amount': 12.0},
        'onHold': {'count': 1, 'amount': 8.0},
        'paidThisMonth': 176.0,
        'totalEarnings': 460.0,
        'daysRemaining': 8,
        'amountBecomingEligibleNext': 44.0,
        'countBecomingEligibleNext': 1,
        'bankValidationStatus': 'valid',
        'waitingSchedule': [
          {'date': '2026-08-18', 'count': 1, 'amount': 44.0},
        ],
        'eligibleRecords': [
          {'sourceNumber': 'BM-1', 'netAmount': 44.0},
        ],
        'payoutHistory': [
          {'reference': 'BANK-1', 'amount': 176.0},
        ],
        'exceptions': [
          {
            'reasonCodes': ['refund_pending'],
            'amount': 12.0,
          },
        ],
      });

      expect(summary.available.amount, 88);
      expect(summary.waiting.count, 1);
      expect(summary.daysRemaining, 8);
      expect(summary.eligibleRecords.single['sourceNumber'], 'BM-1');
      expect(summary.payoutHistory.single['reference'], 'BANK-1');
      expect(summary.exceptions.single['amount'], 12);
    },
  );
}
