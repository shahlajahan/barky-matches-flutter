import 'package:cloud_firestore/cloud_firestore.dart';

enum PayoutDatePreset {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  custom,
}

class PayoutOperationRecord {
  const PayoutOperationRecord({
    required this.indexId,
    required this.businessId,
    this.sector = '',
    required this.businessName,
    required this.legalBusinessName,
    required this.accountHolderName,
    required this.iban,
    required this.bankName,
    required this.taxNumber,
    required this.contactEmail,
    required this.contactPhone,
    required this.currency,
    required this.payoutStatus,
    required this.settlementStatus,
    required this.sourceStatus,
    required this.sourceCollection,
    required this.sourceDocumentId,
    required this.rootOrderId,
    required this.orderNumber,
    required this.grossAmount,
    required this.commissionAmount,
    required this.netAmount,
    required this.sourceCreatedAt,
    required this.sourceUpdatedAt,
    required this.batchId,
    required this.batchNumber,
    required this.paymentReference,
    this.successfulPaymentAt,
    this.eligibilityDate,
    this.eligibilityStatus = 'eligible',
    this.eligibilityReasonCodes = const [],
    this.bankValidationStatus = '',
    this.commissionDataQuality = 'commission_unknown',
    this.financialStatus,
  });

  final String indexId;
  final String businessId;
  final String sector;
  final String businessName;
  final String legalBusinessName;
  final String accountHolderName;
  final String iban;
  final String bankName;
  final String taxNumber;
  final String contactEmail;
  final String contactPhone;
  final String currency;
  final String payoutStatus;
  final String settlementStatus;
  final String sourceStatus;
  final String sourceCollection;
  final String sourceDocumentId;
  final String rootOrderId;
  final String orderNumber;
  final double grossAmount;
  final double commissionAmount;
  final double netAmount;
  final DateTime? sourceCreatedAt;
  final DateTime? sourceUpdatedAt;
  final String batchId;
  final String batchNumber;
  final String paymentReference;
  final DateTime? successfulPaymentAt;
  final DateTime? eligibilityDate;
  final String eligibilityStatus;
  final List<String> eligibilityReasonCodes;
  final String bankValidationStatus;
  final String commissionDataQuality;
  final String? financialStatus;

  String get normalizedFinancialStatus =>
      financialStatus?.trim().isNotEmpty == true
      ? financialStatus!.trim().toLowerCase()
      : commissionDataQuality == 'verified_snapshot'
      ? 'verified'
      : 'requires_repair';

  int get waitingDays {
    if (successfulPaymentAt == null || eligibilityDate == null) return 0;
    return eligibilityDate!.difference(successfulPaymentAt!).inDays;
  }

  factory PayoutOperationRecord.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    String string(String key) => (data[key] ?? '').toString().trim();
    double number(String key) {
      final value = data[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime? date(String key) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '');
    }

    return PayoutOperationRecord(
      indexId: id,
      businessId: string('businessId'),
      sector: string('sector'),
      businessName: string('businessName'),
      legalBusinessName: string('legalBusinessName'),
      accountHolderName: string('accountHolderName'),
      iban: string('iban').replaceAll(' ', '').toUpperCase(),
      bankName: string('bankName'),
      taxNumber: string('taxNumber'),
      contactEmail: string('contactEmail'),
      contactPhone: string('contactPhone'),
      currency: string('currency').toUpperCase(),
      payoutStatus: string('payoutStatus').toLowerCase(),
      settlementStatus: string('settlementStatus').toLowerCase(),
      sourceStatus: string('sourceStatus').toLowerCase(),
      sourceCollection: string('sourceCollection'),
      sourceDocumentId: string('sourceDocumentId'),
      rootOrderId: string('rootOrderId'),
      orderNumber: string('orderNumber'),
      grossAmount: number('grossAmount'),
      commissionAmount: number('commissionAmount'),
      netAmount: number('amount'),
      sourceCreatedAt: date('sourceCreatedAt'),
      sourceUpdatedAt: date('sourceUpdatedAt'),
      batchId: string('batchId'),
      batchNumber: string('batchNumber'),
      paymentReference: string('paymentReference'),
      successfulPaymentAt: date('successfulPaymentAt'),
      eligibilityDate: date('eligibilityDate'),
      eligibilityStatus: string('eligibilityStatus').toLowerCase(),
      eligibilityReasonCodes: (data['eligibilityReasonCodes'] as List? ?? [])
          .map((value) => value.toString())
          .toList(),
      bankValidationStatus: string('bankValidationStatus').toLowerCase(),
      commissionDataQuality: string('commissionDataQuality').isEmpty
          ? 'commission_unknown'
          : string('commissionDataQuality').toLowerCase(),
      financialStatus: string('financialStatus').isEmpty
          ? null
          : string('financialStatus').toLowerCase(),
    );
  }

  String get financialStatusLabel => normalizedFinancialStatus;

  List<String> validationReasons({String? allowedBatchId}) {
    final reasons = <String>[];
    if (const {
      'missing_snapshot',
      'ambiguous_legacy',
      'commission_unknown',
    }.contains(commissionDataQuality)) {
      reasons.add('commission_unknown');
    }
    if (businessId.isEmpty) reasons.add('missing_business');
    if (accountHolderName.isEmpty) reasons.add('missing_account_holder');
    if (iban.isEmpty) {
      reasons.add('missing_iban');
    } else if (!RegExp(r'^TR\d{24}$').hasMatch(iban)) {
      reasons.add('invalid_iban');
    }
    if (bankName.isEmpty) reasons.add('missing_bank_name');
    if (netAmount <= 0) reasons.add('non_positive_amount');
    if (settlementStatus != 'completed') {
      reasons.add('settlement_incomplete');
    }
    if (!const {'pending', 'ready'}.contains(payoutStatus)) {
      reasons.add(
        const {'hold', 'recovery_required'}.contains(payoutStatus)
            ? 'payout_blocked'
            : payoutStatus == 'paid'
            ? 'already_paid'
            : 'payout_ineligible',
      );
    }
    if (sourceStatus.contains('refund') ||
        sourceStatus.contains('cancel') ||
        const {'reversed', 'voided'}.contains(sourceStatus)) {
      reasons.add('refunded_or_cancelled');
    }
    if (batchId.isNotEmpty && batchId != allowedBatchId) {
      reasons.add('already_batched');
    }
    final requiredEligibility = allowedBatchId == null ? 'eligible' : 'batched';
    if (eligibilityStatus != requiredEligibility) {
      reasons.add(
        eligibilityStatus == 'waiting_period'
            ? 'waiting_period'
            : eligibilityStatus == 'on_hold'
            ? 'on_hold'
            : eligibilityStatus == 'blocked'
            ? 'eligibility_blocked'
            : 'not_eligible',
      );
    }
    return reasons.toSet().toList();
  }

  String get searchableText => [
    businessName,
    legalBusinessName,
    businessId,
    accountHolderName,
    iban,
    bankName,
    taxNumber,
    contactEmail,
    contactPhone,
    batchNumber,
    orderNumber,
    sourceDocumentId,
    paymentReference,
  ].join(' ').toLowerCase();
}

class SellerPayoutAggregate {
  const SellerPayoutAggregate({
    required this.key,
    required this.businessId,
    required this.sector,
    required this.businessName,
    required this.legalBusinessName,
    required this.accountHolderName,
    required this.iban,
    required this.bankName,
    required this.taxNumber,
    required this.contactEmail,
    required this.contactPhone,
    required this.currency,
    required this.payoutStatus,
    required this.records,
    required this.grossTotal,
    required this.commissionTotal,
    required this.netTotal,
    required this.earliestDate,
    required this.latestDate,
    required this.validationReasons,
  });

  final String key;
  final String businessId;
  final String sector;
  final String businessName;
  final String legalBusinessName;
  final String accountHolderName;
  final String iban;
  final String bankName;
  final String taxNumber;
  final String contactEmail;
  final String contactPhone;
  final String currency;
  final String payoutStatus;
  final List<PayoutOperationRecord> records;
  final double grossTotal;
  final double commissionTotal;
  final double netTotal;
  final DateTime? earliestDate;
  final DateTime? latestDate;
  final List<String> validationReasons;

  bool get isValid => validationReasons.isEmpty;
  List<String> get payoutIndexIds => records.map((e) => e.indexId).toList();
}

double _moneyFromCents(int value) => value / 100;
int _cents(double value) => (value * 100).round();

List<SellerPayoutAggregate> aggregateSellerPayouts(
  Iterable<PayoutOperationRecord> records,
) {
  final grouped = <String, List<PayoutOperationRecord>>{};
  for (final record in records) {
    final key = [
      record.businessId,
      record.currency,
      record.payoutStatus,
      record.accountHolderName.toLowerCase(),
      record.iban,
      record.taxNumber,
    ].join('|');
    grouped.putIfAbsent(key, () => []).add(record);
  }

  return grouped.entries.map((entry) {
    final values = entry.value;
    final first = values.first;
    final dates = values
        .map((e) => e.sourceCreatedAt)
        .whereType<DateTime>()
        .toList();
    final reasons = values
        .expand((record) => record.validationReasons())
        .toSet()
        .toList();
    return SellerPayoutAggregate(
      key: entry.key,
      businessId: first.businessId,
      sector: first.sector,
      businessName: first.businessName,
      legalBusinessName: first.legalBusinessName,
      accountHolderName: first.accountHolderName,
      iban: first.iban,
      bankName: first.bankName,
      taxNumber: first.taxNumber,
      contactEmail: first.contactEmail,
      contactPhone: first.contactPhone,
      currency: first.currency,
      payoutStatus: first.payoutStatus,
      records: List.unmodifiable(values),
      grossTotal: _moneyFromCents(
        values.fold(
          0,
          (total, value) => value.commissionDataQuality == 'verified_snapshot'
              ? total + _cents(value.grossAmount)
              : total,
        ),
      ),
      commissionTotal: _moneyFromCents(
        values.fold(
          0,
          (total, value) => value.commissionDataQuality == 'verified_snapshot'
              ? total + _cents(value.commissionAmount)
              : total,
        ),
      ),
      netTotal: _moneyFromCents(
        values.fold(
          0,
          (total, value) => value.commissionDataQuality == 'verified_snapshot'
              ? total + _cents(value.netAmount)
              : total,
        ),
      ),
      earliestDate: dates.isEmpty
          ? null
          : dates.reduce((a, b) => a.isBefore(b) ? a : b),
      latestDate: dates.isEmpty
          ? null
          : dates.reduce((a, b) => a.isAfter(b) ? a : b),
      validationReasons: reasons,
    );
  }).toList();
}

List<PayoutOperationRecord> filterPayoutRecords({
  required Iterable<PayoutOperationRecord> records,
  String query = '',
  String? payoutStatus,
  String? settlementStatus,
  String? eligibilityStatus,
  String? seller,
  String? bank,
  bool? validBank,
  double? minimumAmount,
  double? maximumAmount,
  bool? includedInBatch,
  DateTime? start,
  DateTime? end,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  return records.where((record) {
    if (normalizedQuery.isNotEmpty &&
        !record.searchableText.contains(normalizedQuery)) {
      return false;
    }
    if (payoutStatus != null && record.payoutStatus != payoutStatus) {
      return false;
    }
    if (settlementStatus != null &&
        record.settlementStatus != settlementStatus) {
      return false;
    }
    if (eligibilityStatus != null &&
        record.eligibilityStatus != eligibilityStatus) {
      return false;
    }
    if (seller != null) {
      final normalized = seller.trim().toLowerCase();
      if (normalized.isNotEmpty &&
          !record.businessId.toLowerCase().contains(normalized) &&
          !record.businessName.toLowerCase().contains(normalized) &&
          !record.legalBusinessName.toLowerCase().contains(normalized)) {
        return false;
      }
    }
    if (bank != null &&
        !record.bankName.toLowerCase().contains(bank.trim().toLowerCase())) {
      return false;
    }
    final bankIsValid = !record.validationReasons().any(
      (reason) => const {
        'missing_account_holder',
        'missing_iban',
        'invalid_iban',
        'missing_bank_name',
      }.contains(reason),
    );
    if (validBank != null && bankIsValid != validBank) return false;
    if (minimumAmount != null && record.netAmount < minimumAmount) return false;
    if (maximumAmount != null && record.netAmount > maximumAmount) return false;
    if (includedInBatch != null &&
        record.batchId.isNotEmpty != includedInBatch) {
      return false;
    }
    final date = record.sourceCreatedAt;
    if (start != null && (date == null || date.isBefore(start))) return false;
    if (end != null && (date == null || date.isAfter(end))) return false;
    return true;
  }).toList();
}

String maskIban(String iban) {
  final normalized = iban.replaceAll(' ', '').toUpperCase();
  if (normalized.length < 10) return normalized;
  return '${normalized.substring(0, 4)} •••• •••• •••• •••• ${normalized.substring(normalized.length - 4)}';
}
