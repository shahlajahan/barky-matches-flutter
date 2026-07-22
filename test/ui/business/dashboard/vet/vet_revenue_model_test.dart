import 'package:barky_matches_fixed/ui/business/dashboard/vet/web/revenue/vet_revenue_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> paidRecord({
  Object? gross = 1000,
  Object? commission = 100,
  Object? net = 900,
  Object? paidAt,
  String currency = 'TRY',
  Map<String, dynamic> financialExtra = const {},
}) => {
  'paymentStatus': 'paid',
  'paidAt': paidAt ?? Timestamp.fromDate(DateTime(2026, 7, 10)),
  'currency': currency,
  'serviceTitle': 'Consultation',
  'serviceCategory': 'Clinical',
  'ownerProfile': {'ownerName': 'Customer'},
  'petName': 'Pet',
  'financial': {
    'finalPrice': gross,
    'commissionAmount': commission,
    'businessNetAmount': net,
    'payoutStatus': 'pending',
    ...financialExtra,
  },
};

void main() {
  test('parses valid paid appointment with financial data', () {
    final transaction = VetRevenueTransaction.fromMap('a1', paidRecord());
    expect(transaction.status, VetRevenueStatus.recognizedPaid);
    expect(transaction.grossAmount, 1000);
    expect(transaction.commissionAmount, 100);
    expect(transaction.businessNetAmount, 900);
  });

  test('uses persisted surgery financial values without inference', () {
    final record = paidRecord(
      gross: 8000,
      commission: 1200,
      net: 6800,
      financialExtra: {'commissionType': 'percentage', 'sector': 'vet'},
    )..['serviceTitle'] = 'Surgery';
    final transaction = VetRevenueTransaction.fromMap('surgery', record);
    expect(transaction.commissionAmount, 1200);
    expect(transaction.businessNetAmount, 6800);
  });

  test('uses persisted fixed-per-lead financial values', () {
    final transaction = VetRevenueTransaction.fromMap(
      'lead',
      paidRecord(
        gross: 500,
        commission: 75,
        net: 425,
        financialExtra: {'commissionType': 'fixed_per_lead'},
      ),
    );
    expect(transaction.status, VetRevenueStatus.recognizedPaid);
    expect(transaction.commissionAmount, 75);
  });

  test('classifies expired opportunity without financial data', () {
    final transaction = VetRevenueTransaction.fromMap('expired', {
      'paymentStatus': 'expired',
      'price': '650.50',
      'scheduledAt': '2026-07-01T10:00:00Z',
    });
    expect(transaction.status, VetRevenueStatus.expired);
    expect(transaction.opportunityAmount, 650.5);
    expect(transaction.grossAmount, isNull);
  });

  test('refunded payment is excluded from recognized totals', () {
    final record = paidRecord()..['refundStatus'] = 'refunded';
    final transaction = VetRevenueTransaction.fromMap('refund', record);
    final summary = VetRevenueSummary.fromTransactions([transaction]);
    expect(transaction.status, VetRevenueStatus.refunded);
    expect(summary.paidTransactions, 0);
    expect(summary.totalsByCurrency, isEmpty);
    expect(summary.refundedTransactions, 1);
  });

  test('paid legacy record without financial data is missing financial', () {
    final transaction = VetRevenueTransaction.fromMap('legacy', {
      'paymentStatus': 'paid',
      'paidAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
      'price': 400,
    });
    expect(transaction.status, VetRevenueStatus.financialDataMissing);
    expect(transaction.hasFinancialData, isFalse);
  });

  test('parses int double and numeric String financial values', () {
    final transaction = VetRevenueTransaction.fromMap(
      'numbers',
      paidRecord(gross: 1000, commission: 125.5, net: '874.50'),
    );
    expect(transaction.grossAmount, 1000.0);
    expect(transaction.commissionAmount, 125.5);
    expect(transaction.businessNetAmount, 874.5);
  });

  test('parses Timestamp and ISO String dates', () {
    final timestampTransaction = VetRevenueTransaction.fromMap(
      'timestamp',
      paidRecord(paidAt: Timestamp.fromDate(DateTime.utc(2026, 6, 2))),
    );
    final isoTransaction = VetRevenueTransaction.fromMap(
      'iso',
      paidRecord(paidAt: '2026-06-03T12:30:00Z'),
    );
    expect(
      timestampTransaction.paidAt!.isAtSameMomentAs(DateTime.utc(2026, 6, 2)),
      isTrue,
    );
    expect(isoTransaction.paidAt, DateTime.utc(2026, 6, 3, 12, 30));
  });

  test('filters transactions by selected range', () {
    final recent = VetRevenueTransaction.fromMap(
      'recent',
      paidRecord(paidAt: '2026-07-18T00:00:00Z'),
    );
    final old = VetRevenueTransaction.fromMap(
      'old',
      paidRecord(paidAt: '2026-05-01T00:00:00Z'),
    );
    final filtered = filterVetRevenueRange(
      [recent, old],
      VetRevenueRange.last30Days,
      now: DateTime.utc(2026, 7, 20),
    );
    expect(filtered.map((item) => item.appointmentId), ['recent']);
  });

  test('aggregates gross commission net and pending settlement', () {
    final first = VetRevenueTransaction.fromMap('one', paidRecord());
    final second = VetRevenueTransaction.fromMap(
      'two',
      paidRecord(gross: 500, commission: 50, net: 450),
    );
    final summary = VetRevenueSummary.fromTransactions([first, second]);
    final totals = summary.totalsByCurrency['TRY']!;
    expect(totals.gross, 1500);
    expect(totals.commission, 150);
    expect(totals.net, 1350);
    expect(totals.pendingSettlement, 1350);
  });

  test('detects mixed currencies without combining totals', () {
    final tryTransaction = VetRevenueTransaction.fromMap('try', paidRecord());
    final eurTransaction = VetRevenueTransaction.fromMap(
      'eur',
      paidRecord(currency: 'EUR', gross: 100, commission: 10, net: 90),
    );
    final summary = VetRevenueSummary.fromTransactions([
      tryTransaction,
      eurTransaction,
    ]);
    expect(summary.hasMixedCurrencies, isTrue);
    expect(summary.totalsByCurrency.keys, containsAll(['TRY', 'EUR']));
    expect(summary.totalsByCurrency['TRY']!.gross, 1000);
    expect(summary.totalsByCurrency['EUR']!.gross, 100);
  });

  test('zero-data summary is empty and safe', () {
    final summary = VetRevenueSummary.fromTransactions(const []);
    expect(summary.isEmpty, isTrue);
    expect(summary.hasMixedCurrencies, isFalse);
    expect(summary.totalsByCurrency, isEmpty);
    expect(buildVetRevenuePoints(const [], VetRevenueRange.allTime), isEmpty);
  });
}
