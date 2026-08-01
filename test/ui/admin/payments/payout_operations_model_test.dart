import 'package:barky_matches_fixed/ui/admin/payments/payout_operations_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PayoutOperationRecord record({
    String id = 'idx-1',
    String businessId = 'business-1',
    String businessName = 'Şirin Patiler',
    String currency = 'TRY',
    String payoutStatus = 'pending',
    String settlementStatus = 'completed',
    String sourceStatus = 'paid',
    String iban = 'TR123456789012345678901234',
    String bank = 'Türkiye İş Bankası',
    String batchId = '',
    double gross = 5.05,
    double commission = 0.6,
    double net = 4.45,
    String orderNumber = 'BM-1',
    String commissionDataQuality = 'verified_snapshot',
  }) {
    return PayoutOperationRecord(
      indexId: id,
      businessId: businessId,
      businessName: businessName,
      legalBusinessName: '$businessName Ltd.',
      accountHolderName: '$businessName Ltd.',
      iban: iban,
      bankName: bank,
      taxNumber: '1234567890',
      contactEmail: 'finance@example.com',
      contactPhone: '+905001112233',
      currency: currency,
      payoutStatus: payoutStatus,
      settlementStatus: settlementStatus,
      sourceStatus: sourceStatus,
      sourceCollection: 'sellerOrders',
      sourceDocumentId: 'seller-$id',
      rootOrderId: 'root-1',
      orderNumber: orderNumber,
      grossAmount: gross,
      commissionAmount: commission,
      netAmount: net,
      sourceCreatedAt: DateTime(2026, 7, 30),
      sourceUpdatedAt: DateTime(2026, 7, 30),
      batchId: batchId,
      batchNumber: batchId.isEmpty ? '' : 'PB-1',
      paymentReference: '',
      commissionDataQuality: commissionDataQuality,
    );
  }

  test('same seller records aggregate with deterministic cent totals', () {
    final aggregates = aggregateSellerPayouts([
      record(),
      record(id: 'idx-2', gross: 10.1, commission: 0, net: 10.1),
    ]);

    expect(aggregates, hasLength(1));
    expect(aggregates.single.records, hasLength(2));
    expect(aggregates.single.grossTotal, 15.15);
    expect(aggregates.single.commissionTotal, 0.6);
    expect(aggregates.single.netTotal, 14.55);
  });

  test(
    'seller, currency, payout status, and legal recipient stay separate',
    () {
      final aggregates = aggregateSellerPayouts([
        record(),
        record(id: 'idx-2', businessId: 'business-2'),
        record(id: 'idx-3', currency: 'USD'),
        record(id: 'idx-4', payoutStatus: 'ready'),
      ]);

      expect(aggregates, hasLength(4));
    },
  );

  test('refunded and invalid bank records expose blocking reasons', () {
    expect(
      record(sourceStatus: 'refunded').validationReasons(),
      contains('refunded_or_cancelled'),
    );
    expect(record(iban: 'TR123').validationReasons(), contains('invalid_iban'));
  });

  test('search spans seller, bank, order, and source identity', () {
    final records = [
      record(),
      record(
        id: 'idx-2',
        businessId: 'business-2',
        businessName: 'Koray Pet',
        bank: 'Ziraat Bankası',
        orderNumber: 'BM-2',
      ),
    ];

    expect(
      filterPayoutRecords(records: records, query: 'ziraat'),
      hasLength(1),
    );
    expect(filterPayoutRecords(records: records, query: 'BM-1'), hasLength(1));
    expect(
      filterPayoutRecords(records: records, query: 'seller-idx-2'),
      hasLength(1),
    );
  });

  test('amount, settlement, bank, and batch filters combine', () {
    final records = [
      record(),
      record(
        id: 'idx-2',
        batchId: 'batch-1',
        settlementStatus: 'processing',
        net: 100,
      ),
    ];

    expect(
      filterPayoutRecords(
        records: records,
        settlementStatus: 'completed',
        validBank: true,
        maximumAmount: 10,
        includedInBatch: false,
      ),
      hasLength(1),
    );
  });

  test('IBAN masking keeps operational prefix and suffix only', () {
    expect(
      maskIban('TR123456789012345678901234'),
      'TR12 •••• •••• •••• •••• 1234',
    );
  });

  test('normal and unknown records expose financial status and waiting days', () {
    final normal = PayoutOperationRecord(
      indexId: 'idx-normal',
      businessId: 'business-1',
      businessName: 'Seller',
      legalBusinessName: 'Seller Ltd.',
      accountHolderName: 'Seller Ltd.',
      iban: 'TR123456789012345678901234',
      bankName: 'Bank',
      taxNumber: '123',
      contactEmail: 'finance@example.com',
      contactPhone: '+905001112233',
      currency: 'TRY',
      payoutStatus: 'pending',
      settlementStatus: 'completed',
      sourceStatus: 'paid',
      sourceCollection: 'sellerOrders',
      sourceDocumentId: 'seller-order-1',
      rootOrderId: 'root-1',
      orderNumber: 'BM-1',
      grossAmount: 5.05,
      commissionAmount: 0.6,
      netAmount: 4.45,
      sourceCreatedAt: DateTime(2026, 7, 1),
      sourceUpdatedAt: DateTime(2026, 7, 1),
      batchId: '',
      batchNumber: '',
      paymentReference: '',
      successfulPaymentAt: DateTime(2026, 7, 1),
      eligibilityDate: DateTime(2026, 7, 22),
      commissionDataQuality: 'verified_snapshot',
    );
    final unknown = record(commissionDataQuality: 'commission_unknown');

    expect(normal.normalizedFinancialStatus, 'verified');
    expect(normal.waitingDays, 21);
    expect(unknown.normalizedFinancialStatus, 'requires_repair');
  });
}
