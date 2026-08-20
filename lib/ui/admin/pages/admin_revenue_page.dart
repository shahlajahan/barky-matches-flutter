import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class AdminRevenuePage extends StatelessWidget {
  const AdminRevenuePage({super.key, this.revenueStream});

  final Stream<DocumentSnapshot<Map<String, dynamic>>>? revenueStream;

  @override
  Widget build(BuildContext context) {
    final stream =
        revenueStream ??
        FirebaseFirestore.instance
            .collection('admin_stats')
            .doc('revenue_v2')
            .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.revenueTitle)),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AdminRevenueView(error: snapshot.error);
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const AdminRevenueView(isLoading: true);
          }
          final data = snapshot.data?.data();
          return AdminRevenueView(data: data);
        },
      ),
    );
  }
}

class AdminRevenueView extends StatelessWidget {
  const AdminRevenueView({
    super.key,
    this.data,
    this.error,
    this.isLoading = false,
  });

  final Map<String, dynamic>? data;
  final Object? error;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return _StatePanel(
        icon: Icons.error_outline,
        title: 'Revenue data is unavailable',
        message:
            'The admin revenue query failed. No values were replaced with zero.',
      );
    }
    final root = data;
    if (root == null || root.isEmpty || root['schemaVersion'] != 2) {
      return _StatePanel(
        icon: Icons.insights_outlined,
        title: 'Revenue v2 has not been calculated',
        message:
            'Legacy revenue metrics are intentionally hidden because they are not finance-safe.',
      );
    }

    final model = _RevenueModel.fromMap(root);
    final stale =
        model.calculatedAt == null ||
        DateTime.now().difference(model.calculatedAt!).inHours >= 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(model: model, stale: stale),
                  if (model.incompleteSources.isNotEmpty || stale) ...[
                    const SizedBox(height: 14),
                    _WarningBanner(model: model, stale: stale),
                  ],
                  const SizedBox(height: 22),
                  _SectionTitle(
                    title: 'Financial Overview',
                    subtitle:
                        'Verified payment records only. Entitlements, free plans, and admin grants are excluded.',
                  ),
                  const SizedBox(height: 12),
                  for (final currency in model.currencies) ...[
                    _CurrencyPanel(currency: currency),
                    const SizedBox(height: 14),
                  ],
                  if (model.currencies.isEmpty)
                    const _StatePanel(
                      icon: Icons.payments_outlined,
                      title: 'No verified revenue yet',
                      message:
                          'Evaluated sources produced no recognized financial revenue.',
                    ),
                  const SizedBox(height: 22),
                  _SectionTitle(
                    title: 'Subscription & Business Overview',
                    subtitle:
                        'Operational counts. These are not revenue totals.',
                  ),
                  const SizedBox(height: 12),
                  _ResponsiveMetricGrid(
                    metrics: [
                      _Metric(
                        'Active Premium Entitlements',
                        model.entitlements.premiumActive.toString(),
                      ),
                      _Metric(
                        'Active Gold Entitlements',
                        model.entitlements.goldActive.toString(),
                      ),
                      _Metric(
                        'Paid Active Entitlements',
                        model.entitlements.paidActive.toString(),
                      ),
                      _Metric(
                        'Unverified Paid-Plan Entitlements',
                        model.entitlements.unverifiedPaidPlanActive.toString(),
                      ),
                      _Metric(
                        'Free/Trial Active Entitlements',
                        model.entitlements.freeActive.toString(),
                      ),
                      _Metric(
                        'Active Admin Grants',
                        model.entitlements.adminGrantActive.toString(),
                      ),
                      _Metric(
                        'Expiring Within 7 Days',
                        model.entitlements.expiringSoon.toString(),
                      ),
                      _Metric(
                        'Approved Businesses',
                        model.businesses.approvedCount.toString(),
                      ),
                      _Metric(
                        'Paid Business Subscriptions',
                        model.businesses.paidSubscriptionCount.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _SectionTitle(
                    title: 'Payment Status',
                    subtitle:
                        'Pending and failed payments are excluded from revenue.',
                  ),
                  const SizedBox(height: 12),
                  _ResponsiveMetricGrid(
                    metrics: [
                      _Metric(
                        'Successful Payments',
                        model.payments.successfulCount.toString(),
                      ),
                      _Metric(
                        'Pending Payments',
                        model.payments.pendingCount.toString(),
                      ),
                      _Metric(
                        'Failed Payments',
                        model.payments.failedCount.toString(),
                      ),
                      _Metric(
                        'Paying Customers',
                        model.customers.payingCount.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _CoveragePanel(model: model),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.model, required this.stale});

  final _RevenueModel model;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final calculated = model.calculatedAt == null
        ? 'Unavailable'
        : DateFormat.yMMMd().add_Hm().format(model.calculatedAt!.toLocal());
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Admin Revenue',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            Text('Last calculated: $calculated'),
            Text('Timezone: ${model.timezone}'),
            if (stale)
              const Chip(
                avatar: Icon(Icons.schedule, size: 16),
                label: Text('Stale'),
              ),
          ],
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.model, required this.stale});

  final _RevenueModel model;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final unavailable = model.incompleteSources
        .where(
          (source) => source.count > 0 || source.reason.contains('excluded'),
        )
        .length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFF59E0B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFF92400E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stale
                  ? 'Revenue data is stale. Incomplete or unavailable source groups: $unavailable.'
                  : 'Some source groups are unavailable or intentionally excluded from finance totals: $unavailable.',
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyPanel extends StatelessWidget {
  const _CurrencyPanel({required this.currency});

  final _CurrencyBucket currency;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currency.currency,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _ResponsiveMetricGrid(
              metrics: [
                _Metric(
                  'Gross Revenue',
                  _formatMinor(currency.grossMinor, currency.currency),
                ),
                _Metric(
                  'Refunds',
                  _formatMinor(currency.refundMinor, currency.currency),
                ),
                _Metric(
                  'Net Revenue',
                  _formatMinor(currency.netMinor, currency.currency),
                ),
                _Metric(
                  'Monthly Net Revenue',
                  _formatMinor(currency.monthlyNetMinor, currency.currency),
                ),
                _Metric(
                  'Pending Amount',
                  _formatMinor(currency.pendingMinor, currency.currency),
                ),
                _Metric(
                  'ARPPU',
                  _formatMinor(currency.arppuMinor, currency.currency),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoveragePanel extends StatelessWidget {
  const _CoveragePanel({required this.model});

  final _RevenueModel model;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Coverage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text('Included: ${model.includedSources.join(', ')}'),
            const SizedBox(height: 8),
            if (model.incompleteSources.isEmpty)
              const Text('No incomplete sources reported.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final source in model.incompleteSources)
                    Chip(
                      label: Text(
                        '${source.source}: ${source.reason}'
                        '${source.count > 0 ? ' (${source.count})' : ''}',
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
      ],
    );
  }
}

class _ResponsiveMetricGrid extends StatelessWidget {
  const _ResponsiveMetricGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 680
            ? 3
            : constraints.maxWidth >= 440
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _MetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            metric.label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.value,
              maxLines: 1,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: const Color(0xFF64748B)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value);

  final String label;
  final String value;
}

class _RevenueModel {
  _RevenueModel({
    required this.timezone,
    required this.calculatedAt,
    required this.currencies,
    required this.payments,
    required this.customers,
    required this.entitlements,
    required this.businesses,
    required this.includedSources,
    required this.incompleteSources,
  });

  final String timezone;
  final DateTime? calculatedAt;
  final List<_CurrencyBucket> currencies;
  final _Payments payments;
  final _Customers customers;
  final _Entitlements entitlements;
  final _Businesses businesses;
  final List<String> includedSources;
  final List<_IncompleteSource> incompleteSources;

  factory _RevenueModel.fromMap(Map<String, dynamic> data) {
    final financial = _map(data['financial']);
    final byCurrency = _map(financial['byCurrency']);
    final currencies =
        byCurrency.entries
            .map(
              (entry) => _CurrencyBucket.fromMap(entry.key, _map(entry.value)),
            )
            .toList()
          ..sort((a, b) => a.currency.compareTo(b.currency));
    return _RevenueModel(
      timezone: data['timezone']?.toString() ?? 'Europe/Istanbul',
      calculatedAt: _date(data['calculatedAt']),
      currencies: currencies,
      payments: _Payments.fromMap(_map(data['payments'])),
      customers: _Customers.fromMap(_map(data['customers'])),
      entitlements: _Entitlements.fromMap(_map(data['entitlements'])),
      businesses: _Businesses.fromMap(_map(data['businesses'])),
      includedSources: _stringList(_map(data['coverage'])['includedSources']),
      incompleteSources: _list(
        _map(data['coverage'])['incompleteSources'],
      ).map((entry) => _IncompleteSource.fromMap(_map(entry))).toList(),
    );
  }
}

class _CurrencyBucket {
  const _CurrencyBucket({
    required this.currency,
    required this.grossMinor,
    required this.refundMinor,
    required this.netMinor,
    required this.monthlyNetMinor,
    required this.pendingMinor,
    required this.arppuMinor,
  });

  final String currency;
  final int grossMinor;
  final int refundMinor;
  final int netMinor;
  final int monthlyNetMinor;
  final int pendingMinor;
  final int arppuMinor;

  factory _CurrencyBucket.fromMap(String key, Map<String, dynamic> data) {
    return _CurrencyBucket(
      currency: data['currency']?.toString() ?? key,
      grossMinor: _int(data['grossMinor']),
      refundMinor: _int(data['refundMinor']),
      netMinor: _int(data['netMinor']),
      monthlyNetMinor: _int(data['monthlyNetMinor']),
      pendingMinor: _int(data['pendingMinor']),
      arppuMinor: _int(data['arppuMinor']),
    );
  }
}

class _Payments {
  const _Payments({
    required this.successfulCount,
    required this.pendingCount,
    required this.failedCount,
  });

  final int successfulCount;
  final int pendingCount;
  final int failedCount;

  factory _Payments.fromMap(Map<String, dynamic> data) => _Payments(
    successfulCount: _int(data['successfulCount']),
    pendingCount: _int(data['pendingCount']),
    failedCount: _int(data['failedCount']),
  );
}

class _Customers {
  const _Customers({required this.payingCount});

  final int payingCount;

  factory _Customers.fromMap(Map<String, dynamic> data) =>
      _Customers(payingCount: _int(data['payingCount']));
}

class _Entitlements {
  const _Entitlements({
    required this.premiumActive,
    required this.goldActive,
    required this.paidActive,
    required this.unverifiedPaidPlanActive,
    required this.freeActive,
    required this.adminGrantActive,
    required this.expiringSoon,
  });

  final int premiumActive;
  final int goldActive;
  final int paidActive;
  final int unverifiedPaidPlanActive;
  final int freeActive;
  final int adminGrantActive;
  final int expiringSoon;

  factory _Entitlements.fromMap(Map<String, dynamic> data) => _Entitlements(
    premiumActive: _int(data['premiumActive']),
    goldActive: _int(data['goldActive']),
    paidActive: _int(data['paidActive']),
    unverifiedPaidPlanActive: _int(data['unverifiedPaidPlanActive']),
    freeActive: _int(data['freeActive']),
    adminGrantActive: _int(data['adminGrantActive']),
    expiringSoon: _int(data['expiringSoon']),
  );
}

class _Businesses {
  const _Businesses({
    required this.approvedCount,
    required this.paidSubscriptionCount,
  });

  final int approvedCount;
  final int paidSubscriptionCount;

  factory _Businesses.fromMap(Map<String, dynamic> data) => _Businesses(
    approvedCount: _int(data['approvedCount']),
    paidSubscriptionCount: _int(data['paidSubscriptionCount']),
  );
}

class _IncompleteSource {
  const _IncompleteSource({
    required this.source,
    required this.reason,
    required this.count,
  });

  final String source;
  final String reason;
  final int count;

  factory _IncompleteSource.fromMap(Map<String, dynamic> data) =>
      _IncompleteSource(
        source: data['source']?.toString() ?? 'unknown',
        reason: data['reason']?.toString() ?? 'unavailable',
        count: _int(data['count']),
      );
}

String _formatMinor(int minor, String currency) {
  final value = minor / 100;
  return '$currency ${value.toStringAsFixed(2)}';
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Object?> _list(Object? value) {
  if (value is List) return value;
  return const [];
}

List<String> _stringList(Object? value) {
  if (value is List) return value.map((entry) => entry.toString()).toList();
  return const [];
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
