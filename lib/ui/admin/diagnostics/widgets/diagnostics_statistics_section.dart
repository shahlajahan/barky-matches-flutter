import 'package:flutter/material.dart';

import '../models/diagnostics_reports_statistics.dart';

class DiagnosticsStatisticsSection extends StatelessWidget {
  const DiagnosticsStatisticsSection({
    super.key,
    required this.statistics,
    required this.loading,
    required this.error,
  });

  final DiagnosticsReportsStatistics? statistics;
  final bool loading;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(error.toString(), textAlign: TextAlign.center),
      );
    }

    final statistics = this.statistics;
    if (statistics == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              _StatisticCard(label: 'Total', value: statistics.totalReports),
              _StatisticCard(label: 'Open', value: statistics.openReports),
              _StatisticCard(
                label: 'Resolved',
                value: statistics.resolvedReports,
              ),
              _StatisticCard(
                label: 'Ignored',
                value: statistics.ignoredReports,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatisticCard(
                label: 'Critical',
                value: statistics.criticalReports,
              ),
              _StatisticCard(label: 'Error', value: statistics.errorReports),
              _StatisticCard(
                label: 'Warning',
                value: statistics.warningReports,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                value.toString(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
