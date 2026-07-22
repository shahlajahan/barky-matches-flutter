import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import 'vet_revenue_chart.dart';
import 'vet_revenue_model.dart';
import 'vet_revenue_repository.dart';
import 'vet_revenue_table.dart';

class VetRevenueSection extends StatefulWidget {
  const VetRevenueSection({
    super.key,
    required this.businessId,
    this.repository,
  });

  final String businessId;
  final VetRevenueRepository? repository;

  @override
  State<VetRevenueSection> createState() => _VetRevenueSectionState();
}

class _VetRevenueSectionState extends State<VetRevenueSection>
    with AutomaticKeepAliveClientMixin {
  late VetRevenueRepository _repository;
  late Stream<List<VetRevenueTransaction>> _stream;
  VetRevenueRange _range = VetRevenueRange.last30Days;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _configureStream();
  }

  @override
  void didUpdateWidget(covariant VetRevenueSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId ||
        oldWidget.repository != widget.repository) {
      _configureStream();
    }
  }

  void _configureStream() {
    _repository = widget.repository ?? VetRevenueRepository();
    _stream = _repository.streamRevenue(widget.businessId);
  }

  void refresh() => setState(_configureStream);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return StreamBuilder<List<VetRevenueTransaction>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _RevenueState(
            icon: LucideIcons.cloudOff,
            title: l10n.vetRevenueLoadErrorTitle,
            message: l10n.vetRevenueLoadErrorMessage,
            actionLabel: l10n.vetRevenueRetry,
            onAction: refresh,
          );
        }

        final allTransactions = snapshot.data ?? const [];
        final transactions = filterVetRevenueRange(allTransactions, _range);
        final summary = VetRevenueSummary.fromTransactions(transactions);
        final points = buildVetRevenuePoints(transactions, _range);

        return ListView(
          key: const PageStorageKey('vet_web_revenue_scroll'),
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: 580,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.vetRevenueTitle,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.vetRevenueDescription,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                _RangeSelector(
                  value: _range,
                  onChanged: (value) => setState(() => _range = value),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (summary.financialDataMissing > 0)
              _WarningBanner(
                icon: LucideIcons.alertTriangle,
                text: l10n.vetRevenueMissingFinancialWarning(
                  summary.financialDataMissing,
                ),
              ),
            if (summary.hasMixedCurrencies)
              _WarningBanner(
                icon: LucideIcons.coins,
                text: l10n.vetRevenueMixedCurrencyWarning,
              ),
            if (allTransactions.isEmpty)
              _RevenueState(
                icon: LucideIcons.calendarX,
                title: l10n.vetRevenueNoAppointmentsTitle,
                message: l10n.vetRevenueNoAppointmentsMessage,
              )
            else if (transactions.isEmpty)
              _RevenueState(
                icon: LucideIcons.calendarSearch,
                title: l10n.vetRevenueNoRangeTitle,
                message: l10n.vetRevenueNoRangeMessage,
              )
            else ...[
              _PrimaryKpis(summary: summary, locale: locale),
              const SizedBox(height: 16),
              _OperationalMetrics(summary: summary),
              const SizedBox(height: 20),
              _Panel(
                title: l10n.vetRevenueTrendTitle,
                child: summary.hasMixedCurrencies
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 42),
                        child: Center(
                          child: Text(l10n.vetRevenueMixedCurrencyChartHidden),
                        ),
                      )
                    : VetRevenueChart(
                        points: points,
                        localeName: locale,
                        grossLabel: l10n.vetRevenueGross,
                        netLabel: l10n.vetRevenueNet,
                        emptyLabel: l10n.vetRevenueNoRecognizedRevenue,
                      ),
              ),
              const SizedBox(height: 20),
              _Panel(
                title: l10n.vetRevenueTopServices,
                child: _ServiceBreakdown(
                  transactions: transactions,
                  locale: locale,
                ),
              ),
              const SizedBox(height: 20),
              _Panel(
                title: l10n.vetRevenueTransactions,
                child: VetRevenueTable(transactions: transactions),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value, required this.onChanged});

  final VetRevenueRange value;
  final ValueChanged<VetRevenueRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = {
      VetRevenueRange.last7Days: l10n.vetRevenueRange7Days,
      VetRevenueRange.last30Days: l10n.vetRevenueRange30Days,
      VetRevenueRange.last90Days: l10n.vetRevenueRange90Days,
      VetRevenueRange.thisYear: l10n.vetRevenueRangeThisYear,
      VetRevenueRange.allTime: l10n.vetRevenueRangeAllTime,
    };
    return SegmentedButton<VetRevenueRange>(
      segments: [
        for (final range in VetRevenueRange.values)
          ButtonSegment(value: range, label: Text(labels[range]!)),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFF9E1B4F)
              : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
      ),
    );
  }
}

class _PrimaryKpis extends StatelessWidget {
  const _PrimaryKpis({required this.summary, required this.locale});

  final VetRevenueSummary summary;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String values(double Function(VetRevenueCurrencyTotals) read) {
      if (summary.totalsByCurrency.isEmpty) return '—';
      return summary.totalsByCurrency.values
          .map((totals) {
            return NumberFormat.currency(
              locale: locale,
              symbol: totals.currency == 'TRY' ? '₺' : '${totals.currency} ',
              decimalDigits: 2,
            ).format(read(totals));
          })
          .join('\n');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 48) / 4;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _KpiCard(
              width: width,
              title: l10n.vetRevenueGrossRevenue,
              value: values((item) => item.gross),
              icon: LucideIcons.walletCards,
              color: const Color(0xFF9E1B4F),
            ),
            _KpiCard(
              width: width,
              title: l10n.vetRevenuePetsupoCommission,
              value: values((item) => item.commission),
              icon: LucideIcons.badgePercent,
              color: const Color(0xFFD97706),
            ),
            _KpiCard(
              width: width,
              title: l10n.vetRevenueNetRevenue,
              value: values((item) => item.net),
              icon: LucideIcons.landmark,
              color: const Color(0xFF0F766E),
            ),
            _KpiCard(
              width: width,
              title: l10n.vetRevenuePendingSettlement,
              value: values((item) => item.pendingSettlement),
              icon: LucideIcons.clock3,
              color: const Color(0xFF6B7280),
            ),
          ],
        );
      },
    );
  }
}

class _OperationalMetrics extends StatelessWidget {
  const _OperationalMetrics({required this.summary});

  final VetRevenueSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Metric(l10n.vetRevenuePaidTransactions, summary.paidTransactions),
        _Metric(l10n.vetRevenuePendingPayments, summary.pendingPayments),
        _Metric(l10n.vetRevenueRefunded, summary.refundedTransactions),
        _Metric(
          l10n.vetRevenueExpiredOpportunities,
          summary.expiredOpportunities,
        ),
        _Metric(
          l10n.vetRevenueMissingFinancialData,
          summary.financialDataMissing,
        ),
      ],
    );
  }
}

class _ServiceBreakdown extends StatelessWidget {
  const _ServiceBreakdown({required this.transactions, required this.locale});

  final List<VetRevenueTransaction> transactions;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totals = <String, double>{};
    for (final transaction in transactions.where(
      (item) => item.isRecognizedRevenue,
    )) {
      final service = transaction.serviceCategory.isNotEmpty
          ? transaction.serviceCategory
          : transaction.serviceTitle.isNotEmpty
          ? transaction.serviceTitle
          : l10n.vetRevenueUncategorized;
      final key = '${transaction.currency}\u0000$service';
      totals[key] = (totals[key] ?? 0) + transaction.grossAmount!;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Text(l10n.vetRevenueNoRecognizedRevenue)),
      );
    }
    return Column(
      children: [
        for (final entry in entries.take(8)) ...[
          Builder(
            builder: (context) {
              final parts = entry.key.split('\u0000');
              final currency = parts.first;
              final service = parts.last;
              final formatted = NumberFormat.currency(
                locale: locale,
                symbol: currency == 'TRY' ? '₺' : '$currency ',
                decimalDigits: 2,
              ).format(entry.value);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(child: Text(service)),
                    Text(
                      formatted,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            },
          ),
          if (entry != entries.take(8).last) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width.clamp(210, 360).toDouble(),
    constraints: const BoxConstraints(minHeight: 132),
    padding: const EdgeInsets.all(18),
    decoration: _panelDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 14),
        Text(title, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    width: 190,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: _panelDecoration(),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: _panelDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E6),
      border: Border.all(color: const Color(0xFFF5C76B)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF9A6700)),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _RevenueState extends StatelessWidget {
  const _RevenueState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 80),
    child: Column(
      children: [
        Icon(icon, size: 42, color: const Color(0xFF9E1B4F)),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        if (onAction != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

BoxDecoration _panelDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: const Color(0xFFECE6E9)),
  boxShadow: const [
    BoxShadow(color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 5)),
  ],
);
