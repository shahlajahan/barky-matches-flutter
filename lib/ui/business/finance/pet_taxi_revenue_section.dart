import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/business/finance/seller_finance_repository.dart';
import 'package:barky_matches_fixed/ui/business/finance/seller_finance_summary.dart';
import 'package:barky_matches_fixed/ui/business/settings/bank_account_settings_page.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_header.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_metric_card.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_metric_grid.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_panel.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_status_pill.dart';

const double _mobileRevenueBreakpoint = 900;

class BusinessRevenueDashboard extends StatelessWidget {
  const BusinessRevenueDashboard({
    super.key,
    required this.businessId,
    required this.recordLabel,
    this.repository,
    this.summaryStream,
  });

  final String businessId;
  final String recordLabel;
  final SellerFinanceRepository? repository;
  final Stream<SellerFinanceSummary?>? summaryStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SellerFinanceSummary?>(
      stream:
          summaryStream ??
          (repository ?? SellerFinanceRepository()).watchSummary(businessId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const DashboardPanel(
            child: SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return DashboardPanel(
            child: Text(AppLocalizations.of(context)!.payoutLoadFailed),
          );
        }
        final isEmptyState = snapshot.data == null;
        final summary = snapshot.data ?? _emptyFinanceSummary(businessId);

        return LayoutBuilder(
          builder: (context, constraints) {
            // Flutter Web always uses the responsive desktop Revenue view.
            // Native mobile keeps the compact mobile summary.
            final useMobileRevenue =
                !kIsWeb && constraints.maxWidth < _mobileRevenueBreakpoint;
            final Widget view;
            if (useMobileRevenue) {
              view = _MobileRevenueView(
                summary: summary,
                recordLabel: recordLabel,
                isEmptyState: isEmptyState,
                onUpdateBank: () => _openBankSettings(context),
              );
            } else {
              view = _DesktopRevenueView(
                summary: summary,
                trend: summary.revenue.trend,
                recordLabel: recordLabel,
                isEmptyState: isEmptyState,
                onUpdateBank: () => _openBankSettings(context),
              );
            }
            return view;
          },
        );
      },
    );
  }

  void _openBankSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BankAccountSettingsPage(businessId: businessId),
      ),
    );
  }
}

/// Compatibility alias for existing dashboard integrations.
typedef PetTaxiRevenueSection = BusinessRevenueDashboard;

class _MobileRevenueView extends StatelessWidget {
  const _MobileRevenueView({
    required this.summary,
    required this.recordLabel,
    required this.isEmptyState,
    required this.onUpdateBank,
  });

  final SellerFinanceSummary summary;
  final String recordLabel;
  final bool isEmptyState;
  final VoidCallback onUpdateBank;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final date = _formatDate(context, summary.nextEligibilityDate);
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.walletCards, color: Color(0xFF9E1B4F)),
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
            ],
          ),
          const SizedBox(height: 16),
          if (isEmptyState) ...[
            Text(
              l10n.noRevenueData,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
          ],
          _MobileValue(
            label: l10n.sellerFinanceAvailable,
            value: _money(summary.available.amount, summary.currency),
          ),
          const SizedBox(height: 12),
          _MobileValue(
            label: l10n.sellerFinanceWaiting,
            value: _money(summary.waiting.amount, summary.currency),
          ),
          const SizedBox(height: 12),
          _MobileValue(
            label: l10n.creatorUpcomingPayout,
            value:
                '${date ?? '—'} • '
                '${_money(summary.amountBecomingEligibleNext, summary.currency)}',
          ),
          const SizedBox(height: 16),
          _BankStatusCard(
            status: summary.bankValidationStatus,
            onUpdateBank: onUpdateBank,
          ),
        ],
      ),
    );
  }
}

class _DesktopRevenueView extends StatelessWidget {
  const _DesktopRevenueView({
    required this.summary,
    required this.trend,
    required this.recordLabel,
    required this.isEmptyState,
    required this.onUpdateBank,
  });

  final SellerFinanceSummary summary;
  final List<SellerRevenueTrendPoint> trend;
  final String recordLabel;
  final bool isEmptyState;
  final VoidCallback onUpdateBank;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
      children: [
        DashboardHeader(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.sellerFinanceTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.revenueTitle,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              DashboardStatusPill(
                prefix: 'Bank',
                label: _bankStatusLabel(l10n, summary.bankValidationStatus),
                active: summary.bankValidationStatus == 'valid',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _HeaderSummary(
                    label: 'Net Revenue',
                    value: _money(summary.revenue.netRevenue, summary.currency),
                  ),
                  _HeaderSummary(
                    label: 'Waiting Payout',
                    value: _money(summary.waiting.amount, summary.currency),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (isEmptyState) ...[
          DashboardPanel(
            child: Text(
              l10n.noRevenueData,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(height: 18),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 5
                : constraints.maxWidth >= 650
                ? 3
                : 2;
            return DashboardMetricGrid(
              columns: columns,
              childAspectRatio: columns == 5 ? 1.75 : 2.1,
              items: [
                DashboardMetricData(
                  label: l10n.sellerFinanceTotalEarnings,
                  value: _money(summary.totalEarnings, summary.currency),
                  icon: LucideIcons.trendingUp,
                ),
                DashboardMetricData(
                  label: l10n.sellerFinanceWaiting,
                  value: _money(summary.waiting.amount, summary.currency),
                  icon: LucideIcons.clock3,
                ),
                DashboardMetricData(
                  label: l10n.sellerFinanceAvailable,
                  value: _money(summary.available.amount, summary.currency),
                  icon: LucideIcons.walletCards,
                ),
                DashboardMetricData(
                  label: l10n.sellerFinancePaidThisMonth,
                  value: _money(summary.paidThisMonth, summary.currency),
                  icon: LucideIcons.badgeCheck,
                ),
                DashboardMetricData(
                  label: l10n.vetRevenuePaidTransactions,
                  value: summary.revenue.paidRecordCount.toString(),
                  icon: LucideIcons.receipt,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        if (summary.bankValidationStatus != 'valid') ...[
          _BankStatusCard(
            status: summary.bankValidationStatus,
            onUpdateBank: onUpdateBank,
          ),
          const SizedBox(height: 18),
        ],
        _RevenueCharts(summary: summary, trend: trend, locale: locale),
        const SizedBox(height: 18),
        _SettlementTimeline(summary: summary, recordLabel: recordLabel),
        const SizedBox(height: 18),
        _PayoutHistory(summary: summary, recordLabel: recordLabel),
      ],
    );
  }
}

class _RevenueCharts extends StatelessWidget {
  const _RevenueCharts({
    required this.summary,
    required this.trend,
    required this.locale,
  });

  final SellerFinanceSummary summary;
  final List<SellerRevenueTrendPoint> trend;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _RevenueTrend(
                      summary: summary,
                      trend: trend,
                      locale: locale,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _RevenueBreakdown(summary: summary, locale: locale),
                  ),
                ],
              )
            : Column(
                children: [
                  _RevenueTrend(summary: summary, trend: trend, locale: locale),
                  const SizedBox(height: 18),
                  _RevenueBreakdown(summary: summary, locale: locale),
                ],
              );
      },
    );
  }
}

class _RevenueTrend extends StatefulWidget {
  const _RevenueTrend({
    required this.summary,
    required this.trend,
    required this.locale,
  });

  final SellerFinanceSummary summary;
  final List<SellerRevenueTrendPoint> trend;
  final String locale;

  @override
  State<_RevenueTrend> createState() => _RevenueTrendState();
}

class _RevenueTrendState extends State<_RevenueTrend> {
  int _days = 30;
  int? _touchedIndex;

  List<SellerRevenueTrendPoint> _timeline() {
    final now = DateTime.now();
    final monthly = _days == 365;
    final start = monthly
        ? DateTime(now.year, now.month - 11, 1)
        : DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: _days - 1));
    final buckets = <String, _TrendBucket>{};
    for (final point in widget.trend) {
      final date = DateTime(point.date.year, point.date.month, point.date.day);
      if (date.isBefore(start) || date.isAfter(now)) continue;
      final key = monthly
          ? '${date.year}-${date.month}'
          : '${date.year}-${date.month}-${date.day}';
      final bucket = buckets.putIfAbsent(key, _TrendBucket.new);
      bucket.add(point);
    }

    final result = <SellerRevenueTrendPoint>[];
    if (monthly) {
      for (var i = 0; i < 12; i++) {
        final date = DateTime(start.year, start.month + i, 1);
        result.add(_point(date, buckets['${date.year}-${date.month}']));
      }
    } else {
      for (var i = 0; i < _days; i++) {
        final date = start.add(Duration(days: i));
        result.add(
          _point(date, buckets['${date.year}-${date.month}-${date.day}']),
        );
      }
    }
    return result;
  }

  SellerRevenueTrendPoint _point(DateTime date, _TrendBucket? bucket) {
    return SellerRevenueTrendPoint(
      date: date,
      amount: bucket?.grossRevenue ?? 0,
      count: bucket?.paymentCount ?? 0,
      grossRevenue: bucket?.grossRevenue ?? 0,
      platformFee: bucket?.platformFee ?? 0,
      netRevenue: bucket == null ? 0 : bucket.netRevenue,
      paymentCount: bucket?.paymentCount ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final summary = widget.summary;
    final points = _timeline();
    final values = [for (final point in points) point.grossValue];
    final hasRevenue = points.any((point) => point.paymentValue > 0);
    final maxValue = values.fold<double>(0, math.max);
    final maxY = _niceMaxY(maxValue);
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.revenueTrend, style: _PanelTitle.style),
              ),
              DropdownButton<int>(
                value: _days,
                isDense: true,
                items: [
                  DropdownMenuItem(
                    value: 7,
                    child: Text(l10n.vetRevenueRange7Days),
                  ),
                  DropdownMenuItem(
                    value: 30,
                    child: Text(l10n.vetRevenueRange30Days),
                  ),
                  DropdownMenuItem(
                    value: 365,
                    child: Text(l10n.creatorTimeframe12m),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _days = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasRevenue)
            SizedBox(
              height: 220,
              child: Center(child: Text(l10n.noRevenueTrendYet)),
            )
          else
            _buildBarChart(
              context,
              points: points,
              values: values,
              maxY: maxY,
              currency: summary.currency,
            ),
          if (hasRevenue)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedPeriodLabel(),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.paymentsCount(
                      points.fold<int>(
                        0,
                        (sum, point) => sum + point.paymentValue,
                      ),
                    ),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  Text(
                    _money(values.fold(0, (a, b) => a + b), summary.currency),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBarChart(
    BuildContext context, {
    required List<SellerRevenueTrendPoint> points,
    required List<double> values,
    required double maxY,
    required String currency,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = math
            .max(
              constraints.maxWidth,
              points.length * (points.length <= 12 ? 42 : 28),
            )
            .toDouble();
        final chart = SizedBox(
          width: chartWidth,
          height: 240,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              groupsSpace: points.length <= 12 ? 18 : 8,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: _niceInterval(maxY),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: _niceInterval(maxY),
                    getTitlesWidget: (value, meta) => Text(
                      _axisAmount(value, currency),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: _labelInterval(points.length),
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          _periodLabel(
                            points[index].date,
                            points.length,
                            widget.locale,
                          ),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < values.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i],
                        width: points.length <= 12 ? 22 : 14,
                        color: i == _touchedIndex
                            ? const Color(0xFF7F123F)
                            : const Color(0xFF9E1B4F),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ],
                  ),
              ],
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  final index = response?.spot?.touchedBarGroupIndex;
                  if (index != _touchedIndex) {
                    setState(() => _touchedIndex = index);
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => const Color(0xFF24151E),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      _trendTooltip(
                        points[groupIndex],
                        currency,
                        widget.locale,
                      ),
                      const TextStyle(color: Colors.white, height: 1.35),
                    );
                  },
                ),
              ),
            ),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
          ),
        );
        return chartWidth > constraints.maxWidth
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: chart,
              )
            : chart;
      },
    );
  }

  String _selectedPeriodLabel() => switch (_days) {
    7 => 'Selected period • 7 days',
    365 => 'Selected period • 12 months',
    _ => 'Selected period • 30 days',
  };
}

class _TrendBucket {
  double grossRevenue = 0;
  double platformFee = 0;
  double? netRevenue;
  int paymentCount = 0;

  void add(SellerRevenueTrendPoint point) {
    grossRevenue += point.grossValue;
    platformFee += point.platformFee;
    if (point.netRevenue != null) {
      netRevenue = (netRevenue ?? 0) + point.netRevenue!;
    }
    paymentCount += point.paymentValue;
  }
}

class _RevenueBreakdown extends StatelessWidget {
  const _RevenueBreakdown({required this.summary, required this.locale});

  final SellerFinanceSummary summary;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final values = <String, double>{
      'Gross revenue': summary.revenue.grossSales.abs(),
      'Platform fee': summary.revenue.platformFee.abs(),
      if (summary.revenue.adjustments != 0)
        'Adjustments': summary.revenue.adjustments.abs(),
      'Net revenue': summary.revenue.netRevenue.abs(),
    };
    final total = values.values.fold<double>(0, (sum, value) => sum + value);
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.revenueBreakdown, style: _PanelTitle.style),
          const SizedBox(height: 16),
          if (summary.revenue.grossSales <= 0 && total <= 0)
            SizedBox(
              height: 220,
              child: Center(child: Text(l10n.noRevenueActivityYet)),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final chart = SizedBox(
                  width: 190,
                  height: 190,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 48,
                      sectionsSpace: 3,
                      sections: [
                        for (final entry in values.entries)
                          PieChartSectionData(
                            value: entry.value,
                            color: _breakdownColor(entry.key),
                            showTitle: false,
                            radius: 56,
                          ),
                      ],
                    ),
                  ),
                );
                final legend = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in values.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LegendRow(
                          color: _breakdownColor(entry.key),
                          label: entry.key,
                          value: _money(entry.value, summary.currency),
                        ),
                      ),
                  ],
                );
                return constraints.maxWidth < 480
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [chart, const SizedBox(height: 14), legend],
                      )
                    : Row(
                        children: [
                          chart,
                          const SizedBox(width: 14),
                          Expanded(child: legend),
                        ],
                      );
              },
            ),
        ],
      ),
    );
  }
}

class _SettlementTimeline extends StatelessWidget {
  const _SettlementTimeline({required this.summary, required this.recordLabel});

  final SellerFinanceSummary summary;
  final String recordLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = summary.waitingSchedule;
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settlementTimeline, style: _PanelTitle.style),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.waitingCount(
                    _countLabel(summary.waiting.count, recordLabel),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(context, summary.nextEligibilityDate) ??
                      'No date set',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _money(summary.amountBecomingEligibleNext, summary.currency),
                ),
              ],
            )
          else
            for (final row in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  LucideIcons.calendarClock,
                  color: Color(0xFF9E1B4F),
                ),
                title: Text((row['date'] ?? 'Upcoming settlement').toString()),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _countLabel(_number(row['count']).toInt(), recordLabel),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _money(_number(row['amount']), summary.currency),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _PayoutHistory extends StatelessWidget {
  const _PayoutHistory({required this.summary, required this.recordLabel});

  final SellerFinanceSummary summary;
  final String recordLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sellerFinancePayoutHistory, style: _PanelTitle.style),
          const SizedBox(height: 12),
          if (summary.payoutHistory.isEmpty)
            Text(l10n.noPayoutsYet)
          else
            for (final row in summary.payoutHistory)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  LucideIcons.banknote,
                  color: Color(0xFF0F766E),
                ),
                title: Text(_money(_number(row['amount']), summary.currency)),
                subtitle: Text(
                  '${row['recordCount'] ?? 0} $recordLabel • '
                  '${row['reference'] ?? row['batchNumber'] ?? 'Settled'}',
                ),
                trailing: Text('•••• ${row['bankSuffix'] ?? ''}'),
              ),
        ],
      ),
    );
  }
}

class _BankStatusCard extends StatelessWidget {
  const _BankStatusCard({required this.status, required this.onUpdateBank});

  final String status;
  final VoidCallback onUpdateBank;

  @override
  Widget build(BuildContext context) {
    final valid = status == 'valid';
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: valid ? const Color(0xFFEAF7F0) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: valid ? const Color(0xFFB7E4C7) : const Color(0xFFF2C078),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final message = Expanded(
            child: Text(
              valid
                  ? l10n.sellerFinanceBankReady
                  : l10n.sellerFinanceBankBlocked,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          );
          final icon = Icon(
            valid ? LucideIcons.badgeCheck : LucideIcons.alertTriangle,
            color: valid ? const Color(0xFF0F766E) : const Color(0xFFB45309),
          );
          final action = !valid
              ? TextButton(
                  onPressed: onUpdateBank,
                  child: Text(l10n.sellerFinanceUpdateBank),
                )
              : null;

          if (constraints.maxWidth < 520) {
            if (action case final button?) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [icon, const SizedBox(width: 12), message]),
                  Align(alignment: Alignment.centerRight, child: button),
                ],
              );
            }
          }

          return Row(
            children: [icon, const SizedBox(width: 12), message, ?action],
          );
        },
      ),
    );
  }
}

class _MobileValue extends StatelessWidget {
  const _MobileValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: Colors.black54)),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(label)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}

class _PanelTitle {
  static const style = TextStyle(fontSize: 17, fontWeight: FontWeight.w800);
}

double _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

String _money(double value, String currency) =>
    '${value.toStringAsFixed(2)} $currency';

String _trendTooltip(
  SellerRevenueTrendPoint point,
  String currency,
  String locale,
) {
  final date = DateFormat.yMMMd(locale).format(point.date);
  final net = point.netRevenue == null
      ? '—'
      : _money(point.netRevenue!, currency);
  return '$date\n'
      'Gross Revenue: ${_money(point.grossValue, currency)}\n'
      'Platform Fee: ${_money(point.platformFee, currency)}\n'
      'Net Revenue: $net\n'
      'Payments: ${point.paymentValue}';
}

double _niceInterval(double maxY) {
  if (maxY <= 0) return 1;
  final raw = maxY / 4;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final normalized = raw / magnitude;
  final rounded = normalized <= 1
      ? 1
      : normalized <= 2
      ? 2
      : normalized <= 5
      ? 5
      : 10;
  return (rounded * magnitude).toDouble();
}

double _niceMaxY(double maxValue) {
  if (maxValue <= 0) return 1;
  final padded = maxValue * 1.12;
  final interval = _niceInterval(padded);
  return (padded / interval).ceil() * interval;
}

String _axisAmount(double value, String currency) {
  if (value == 0) return '0';
  return value >= 1000
      ? '${(value / 1000).toStringAsFixed(1)}k'
      : value.toStringAsFixed(value >= 100 ? 0 : 1);
}

double _labelInterval(int pointCount) {
  if (pointCount <= 12) return 1;
  if (pointCount <= 30) return 5;
  return 2;
}

String _periodLabel(DateTime date, int pointCount, String locale) {
  return pointCount == 12
      ? DateFormat.MMM(locale).format(date)
      : DateFormat.Md(locale).format(date);
}

String? _formatDate(BuildContext context, DateTime? value) {
  if (value == null) return null;
  return DateFormat.yMMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(value);
}

String _bankStatusLabel(AppLocalizations l10n, String value) => switch (value) {
  'valid' => l10n.sellerFinanceBankReady,
  _ => l10n.sellerFinanceUpdateBank,
};

Color _breakdownColor(String label) => switch (label) {
  'Gross revenue' => const Color(0xFF2563EB),
  'Net revenue' => const Color(0xFF0F766E),
  'Platform fee' => const Color(0xFF9E1B4F),
  _ => const Color(0xFFF59E0B),
};

String _countLabel(int count, String recordLabel) {
  final singular = count == 1 && recordLabel.endsWith('s')
      ? recordLabel.substring(0, recordLabel.length - 1)
      : recordLabel;
  return '$count $singular';
}

class _HeaderSummary extends StatelessWidget {
  const _HeaderSummary({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

SellerFinanceSummary _emptyFinanceSummary(String businessId) {
  const zero = SellerFinanceAmount(count: 0, amount: 0);
  return SellerFinanceSummary(
    businessId: businessId,
    currency: 'TRY',
    available: zero,
    waiting: zero,
    batched: zero,
    paid: zero,
    blocked: zero,
    onHold: zero,
    paidThisMonth: 0,
    totalEarnings: 0,
    nextEligibilityDate: null,
    daysRemaining: 0,
    amountBecomingEligibleNext: 0,
    countBecomingEligibleNext: 0,
    oldestWaitingPaymentAt: null,
    bankValidationStatus: 'missing',
    waitingSchedule: [],
    lastPayout: null,
    eligibleRecords: [],
    payoutHistory: [],
    exceptions: [],
    revenue: SellerRevenueSummary(
      grossSales: 0,
      platformFee: 0,
      adjustments: 0,
      netRevenue: 0,
      paidRecordCount: 0,
      averageTicket: 0,
      trend: const [],
    ),
  );
}
