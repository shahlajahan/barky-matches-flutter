import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/business/finance/seller_finance_repository.dart';
import 'package:barky_matches_fixed/ui/business/finance/seller_finance_summary.dart';
import 'package:barky_matches_fixed/ui/business/settings/bank_account_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SellerFinanceSummarySection extends StatelessWidget {
  const SellerFinanceSummarySection({
    super.key,
    required this.businessId,
    required this.recordLabel,
  });

  final String businessId;
  final String recordLabel;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SellerFinanceSummary?>(
      stream: SellerFinanceRepository().watchSummary(businessId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(AppLocalizations.of(context)!.payoutLoadFailed),
            ),
          );
        }
        final summary = snapshot.data;
        if (summary == null) return const SizedBox.shrink();
        return _FinanceSummaryCard(
          summary: summary,
          recordLabel: recordLabel,
          onOpenDetails: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SellerFinanceDetailPage(
                businessId: businessId,
                recordLabel: recordLabel,
              ),
            ),
          ),
          onUpdateBank: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BankAccountSettingsPage(businessId: businessId),
            ),
          ),
        );
      },
    );
  }
}

class _FinanceSummaryCard extends StatelessWidget {
  const _FinanceSummaryCard({
    required this.summary,
    required this.recordLabel,
    required this.onOpenDetails,
    required this.onUpdateBank,
  });

  final SellerFinanceSummary summary;
  final String recordLabel;
  final VoidCallback onOpenDetails;
  final VoidCallback onUpdateBank;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateFormat = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(0xFF9E1B4F),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.sellerFinanceTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenDetails,
                  child: Text(l10n.sellerFinanceDetails),
                ),
              ],
            ),
            if (summary.bankValidationStatus != 'valid')
              MaterialBanner(
                content: Text(l10n.sellerFinanceBankBlocked),
                actions: [
                  TextButton(
                    onPressed: onUpdateBank,
                    child: Text(l10n.sellerFinanceUpdateBank),
                  ),
                ],
              ),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                _value(
                  l10n.sellerFinanceAvailable,
                  summary.available.amount,
                  summary.currency,
                ),
                _value(
                  l10n.sellerFinanceWaiting,
                  summary.waiting.amount,
                  summary.currency,
                ),
                _value(
                  l10n.sellerFinanceProcessing,
                  summary.batched.amount,
                  summary.currency,
                ),
                _value(
                  l10n.sellerFinancePaidThisMonth,
                  summary.paidThisMonth,
                  summary.currency,
                ),
                _value(
                  l10n.sellerFinanceTotalEarnings,
                  summary.totalEarnings,
                  summary.currency,
                ),
                _value(
                  l10n.sellerFinanceBlocked,
                  summary.blocked.amount + summary.onHold.amount,
                  summary.currency,
                ),
              ],
            ),
            const Divider(height: 28),
            Text(
              l10n.revenueTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                _value(
                  l10n.grossSalesLabel,
                  summary.revenue.grossSales,
                  summary.currency,
                ),
                _value(
                  l10n.platformFeeLabel,
                  summary.revenue.platformFee,
                  summary.currency,
                ),
                _value(
                  l10n.adjustmentsLabel,
                  summary.revenue.adjustments,
                  summary.currency,
                ),
                _value(
                  l10n.netRevenueLabel,
                  summary.revenue.netRevenue,
                  summary.currency,
                ),
                _value(
                  l10n.vetRevenuePaidTransactions,
                  summary.revenue.paidRecordCount.toDouble(),
                  '',
                ),
                _value(
                  l10n.marketAvgLabel,
                  summary.revenue.averageTicket,
                  summary.currency,
                ),
              ],
            ),
            if (summary.waiting.amount > 0) ...[
              const Divider(height: 28),
              Text(
                l10n.sellerFinanceWaitingExplanation,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Text(
                '${summary.waiting.count} $recordLabel • '
                '${summary.nextEligibilityDate == null ? '—' : dateFormat.format(summary.nextEligibilityDate!)} • '
                '${summary.amountBecomingEligibleNext.toStringAsFixed(2)} ${summary.currency}',
              ),
              const SizedBox(height: 8),
              Text(
                '${l10n.financeDaysRemaining}: ${summary.daysRemaining} • '
                '${l10n.financeOldestWaitingRecord}: '
                '${summary.oldestWaitingPaymentAt == null ? '—' : dateFormat.format(summary.oldestWaitingPaymentAt!)}',
              ),
              const SizedBox(height: 8),
              Text(
                '${l10n.sellerFinanceEstimatedNext}: '
                '${summary.amountBecomingEligibleNext.toStringAsFixed(2)} ${summary.currency} • '
                '${summary.nextEligibilityDate == null ? '—' : dateFormat.format(summary.nextEligibilityDate!)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _value(String label, double amount, String currency) {
    return SizedBox(
      width: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(
            '${amount.toStringAsFixed(2)} $currency',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class SellerFinanceDetailPage extends StatelessWidget {
  const SellerFinanceDetailPage({
    super.key,
    required this.businessId,
    required this.recordLabel,
  });

  final String businessId;
  final String recordLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sellerFinanceTitle)),
      body: StreamBuilder<SellerFinanceSummary?>(
        stream: SellerFinanceRepository().watchSummary(businessId),
        builder: (context, snapshot) {
          final summary = snapshot.data;
          if (summary == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _FinanceSummaryCard(
                summary: summary,
                recordLabel: recordLabel,
                onOpenDetails: () {},
                onUpdateBank: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BankAccountSettingsPage(businessId: businessId),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.sellerFinanceWaitingSchedule,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final row in summary.waitingSchedule)
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text((row['date'] ?? '').toString()),
                  subtitle: Text('${row['count'] ?? 0} $recordLabel'),
                  trailing: Text(
                    '${((row['amount'] as num?) ?? 0).toStringAsFixed(2)} ${summary.currency}',
                  ),
                ),
              const Divider(),
              Text(
                l10n.sellerFinanceTimeline,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ListTile(
                leading: const Icon(Icons.route_outlined),
                title: Text(l10n.sellerFinanceTimelineValue),
              ),
              if (summary.eligibleRecords.isNotEmpty) ...[
                const Divider(),
                Text(
                  l10n.sellerFinanceEligibleRecords,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final row in summary.eligibleRecords)
                  ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(
                      (row['sourceNumber'] ?? recordLabel).toString(),
                    ),
                    subtitle: Text((row['sourceType'] ?? '').toString()),
                    trailing: Text(
                      '${((row['netAmount'] as num?) ?? 0).toStringAsFixed(2)} ${summary.currency}',
                    ),
                  ),
              ],
              if (summary.payoutHistory.isNotEmpty) ...[
                const Divider(),
                Text(
                  l10n.sellerFinancePayoutHistory,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final row in summary.payoutHistory)
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(
                      '${((row['amount'] as num?) ?? 0).toStringAsFixed(2)} ${summary.currency}',
                    ),
                    subtitle: Text(
                      '${row['recordCount'] ?? 0} $recordLabel • ${row['reference'] ?? row['batchNumber'] ?? ''}',
                    ),
                    trailing: Text('•••• ${row['bankSuffix'] ?? ''}'),
                  ),
              ],
              if (summary.exceptions.isNotEmpty) ...[
                const Divider(),
                Text(
                  l10n.sellerFinanceExceptions,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final row in summary.exceptions)
                  ListTile(
                    leading: const Icon(
                      Icons.warning_amber_outlined,
                      color: Colors.orange,
                    ),
                    title: Text(
                      ((row['reasonCodes'] as List?) ?? const ['blocked']).join(
                        ', ',
                      ),
                    ),
                    subtitle: Text((row['sourceNumber'] ?? '').toString()),
                    trailing: Text(
                      '${((row['amount'] as num?) ?? 0).toStringAsFixed(2)} ${summary.currency}',
                    ),
                  ),
              ],
              if (summary.lastPayout != null) ...[
                const Divider(),
                Text(
                  l10n.sellerFinanceLastPayout,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ListTile(
                  title: Text(
                    '${summary.lastPayout!['amount'] ?? 0} ${summary.currency}',
                  ),
                  subtitle: Text(
                    (summary.lastPayout!['reference'] ?? '').toString(),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
