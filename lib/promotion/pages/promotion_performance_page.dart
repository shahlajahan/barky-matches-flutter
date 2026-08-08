import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../ui/shared/dashboard/dashboard_metric_card.dart';
import '../../ui/shared/dashboard/dashboard_metric_grid.dart';
import '../models/promotion_campaign_stats.dart';
import '../services/promotion_analytics_service.dart';

/// Owner-facing, read-only campaign performance. The page consumes the
/// normalized server response only; it never reads attribution, payment, or
/// domain transaction records.
class PromotionPerformancePage extends StatefulWidget {
  const PromotionPerformancePage({
    super.key,
    required this.campaignId,
    this.targetLabel,
    this.loadStats,
  });

  final String campaignId;
  final String? targetLabel;
  final Future<PromotionCampaignStats> Function(String campaignId)? loadStats;

  @override
  State<PromotionPerformancePage> createState() =>
      _PromotionPerformancePageState();
}

class _PromotionPerformancePageState extends State<PromotionPerformancePage> {
  late Future<PromotionCampaignStats> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future =
        (widget.loadStats ?? PromotionAnalyticsService().readCampaignStats)(
          widget.campaignId,
        );
  }

  String _money(BuildContext context, double value, String? currency) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final number = NumberFormat.currency(
      locale: locale,
      symbol: currency == 'TRY' ? '₺' : (currency ?? ''),
      decimalDigits: value == value.roundToDouble() ? 0 : 2,
    );
    return number.format(value);
  }

  DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    try {
      final dynamic candidate = value;
      final result = candidate.toDate();
      if (result is DateTime) return result.toLocal();
    } catch (_) {
      final parsed = DateTime.tryParse(value.toString());
      return parsed?.toLocal();
    }
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _dateText(BuildContext context, Object? value) {
    final date = _date(value);
    if (date == null) return AppLocalizations.of(context)!.promotionNa;
    return DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(date);
  }

  String _targetType(BuildContext context, PromotionCampaignStats stats) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.targetLabel?.trim().isNotEmpty == true) {
      return widget.targetLabel!;
    }
    return switch (stats.targetType.toUpperCase()) {
      'PET' => l10n.promotionTargetPet,
      'PRODUCT' => l10n.promotionTargetProduct,
      'SERVICE' when stats.sector?.toUpperCase() == 'GROOMER' =>
        l10n.promotionTargetGroomyService,
      'SERVICE' => l10n.promotionTargetVetService,
      _ => l10n.promotionPerformanceTitle,
    };
  }

  String _campaignStatus(BuildContext context, PromotionCampaignStats stats) {
    final l10n = AppLocalizations.of(context)!;
    final status = stats.campaignStatus?.toUpperCase();
    if (status == 'ACTIVE') return l10n.promotionCampaignActive;
    if (status == 'EXPIRED') return l10n.promotionCampaignExpired;
    return l10n.promotionCampaignProcessing;
  }

  String _reconciliationStatus(
    BuildContext context,
    PromotionCampaignStats stats,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return switch (stats.reconciliationStatus.toUpperCase()) {
      'CONVERGED' => l10n.promotionUpToDate,
      'PENDING' => l10n.promotionCampaignProcessing,
      _ => l10n.promotionCampaignNeedsReconciliation,
    };
  }

  Widget _banner(BuildContext context, PromotionCampaignStats stats) {
    final l10n = AppLocalizations.of(context)!;
    final status = stats.financialMetricsStatus.toUpperCase();
    final isPet = stats.targetType.toUpperCase() == 'PET';
    final text = isPet
        ? l10n.promotionPetFinancialNotApplicable
        : status == 'AVAILABLE'
        ? l10n.promotionFinancialAvailable
        : status == 'PROVISIONAL'
        ? l10n.promotionFinancialProvisional
        : l10n.promotionFinancialUnavailable;
    final color = isPet || status == 'UNAVAILABLE'
        ? Colors.blueGrey
        : status == 'PROVISIONAL'
        ? Colors.orange.shade800
        : Colors.green.shade700;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Text(text, style: TextStyle(color: color)),
    );
  }

  List<DashboardMetricData> _exposureMetrics(
    BuildContext context,
    PromotionCampaignStats stats,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return [
      DashboardMetricData(
        label: l10n.promotionImpressions,
        value: '${stats.impressions}',
        icon: Icons.visibility_outlined,
      ),
      DashboardMetricData(
        label: l10n.promotionClicks,
        value: '${stats.clicks}',
        icon: Icons.touch_app_outlined,
      ),
      DashboardMetricData(
        label: l10n.promotionCtr,
        value: stats.ctr == null
            ? l10n.promotionNa
            : NumberFormat.percentPattern(
                Localizations.localeOf(context).toLanguageTag(),
              ).format(stats.ctr),
        icon: Icons.ads_click_outlined,
      ),
      DashboardMetricData(
        label: l10n.promotionDetailViews,
        value: '${stats.detailViews}',
        icon: Icons.open_in_new_outlined,
      ),
    ];
  }

  List<DashboardMetricData> _financialMetrics(
    BuildContext context,
    PromotionCampaignStats stats,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final available = stats.financialMetricsStatus.toUpperCase() == 'AVAILABLE';
    final provisional =
        stats.financialMetricsStatus.toUpperCase() == 'PROVISIONAL';
    return [
      DashboardMetricData(
        label: l10n.promotionFinancialConversions,
        value: '${stats.financialConversions}',
        icon: Icons.shopping_bag_outlined,
      ),
      DashboardMetricData(
        label: l10n.promotionNetRevenue,
        value: !available && !provisional
            ? l10n.promotionNa
            : _money(context, stats.netAttributedRevenue, stats.currency),
        icon: Icons.payments_outlined,
      ),
      if (available)
        DashboardMetricData(
          label: l10n.promotionRoas,
          value: stats.roas == null
              ? l10n.promotionNa
              : '${stats.roas!.toStringAsFixed(1)}x',
          icon: Icons.trending_up,
        ),
    ];
  }

  Widget _content(BuildContext context, PromotionCampaignStats stats) {
    final l10n = AppLocalizations.of(context)!;
    final showFinancial = stats.targetType.toUpperCase() != 'PET';
    final noExposure =
        stats.impressions == 0 && stats.clicks == 0 && stats.detailViews == 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_targetType(context, stats), style: AppTheme.h2()),
        const SizedBox(height: 4),
        Text(l10n.promotionPerformanceTitle),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                Text(
                  '${l10n.promotionCampaignStatus}: ${_campaignStatus(context, stats)}',
                ),
                Text(
                  '${l10n.promotionSpend}: ${_money(context, stats.spend, stats.currency)}',
                ),
                if (stats.durationHours != null && stats.durationHours! > 0)
                  Text(l10n.promotionDurationHours(stats.durationHours!)),
                Text(
                  '${l10n.promotionStarts}: ${_dateText(context, stats.startsAt)}',
                ),
                Text(
                  '${l10n.promotionEnds}: ${_dateText(context, stats.expiresAt)}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _banner(context, stats),
        const SizedBox(height: 16),
        DashboardMetricGrid(
          items: _exposureMetrics(context, stats),
          columns: 4,
          compact: true,
        ),
        if (noExposure) ...[
          const SizedBox(height: 16),
          Text(l10n.promotionNoPerformanceData),
        ],
        if (showFinancial &&
            stats.financialMetricsStatus.toUpperCase() != 'UNAVAILABLE') ...[
          const SizedBox(height: 24),
          Text(l10n.promotionFinancialSection, style: AppTheme.h3()),
          const SizedBox(height: 12),
          DashboardMetricGrid(
            items: _financialMetrics(context, stats),
            columns: 3,
            compact: true,
          ),
        ],
        if (showFinancial &&
            stats.financialMetricsStatus.toUpperCase() == 'UNAVAILABLE') ...[
          const SizedBox(height: 16),
          Text(l10n.promotionFinancialUnavailable),
        ],
        const SizedBox(height: 16),
        Text(
          '${l10n.promotionReconciliationStatus}: ${_reconciliationStatus(context, stats)}',
          style: AppTheme.caption(color: Colors.black54),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.promotionPerformanceTitle)),
      body: FutureBuilder<PromotionCampaignStats>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.promotionLoadError),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(_load),
                      child: Text(l10n.promotionRetry),
                    ),
                  ],
                ),
              ),
            );
          }
          return _content(context, snapshot.data!);
        },
      ),
    );
  }
}
