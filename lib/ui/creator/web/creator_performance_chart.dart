import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/creator/creator_dashboard_data.dart';
import 'package:barky_matches_fixed/ui/creator/creator_placeholder_badge.dart';

enum _CreatorChartRange { d7, d30, d90, m12 }

/// Full Web dashboard performance chart with a 7d/30d/90d/12mo filter —
/// mirrors the fl_chart LineChart pattern already established by
/// VetRevenueChart (lib/ui/business/dashboard/vet/web/revenue), including
/// the same #9E1B4F brand line color.
class CreatorPerformanceChart extends StatefulWidget {
  const CreatorPerformanceChart({super.key});

  @override
  State<CreatorPerformanceChart> createState() =>
      _CreatorPerformanceChartState();
}

class _CreatorPerformanceChartState extends State<CreatorPerformanceChart> {
  _CreatorChartRange _range = _CreatorChartRange.d30;

  int get _days => switch (_range) {
    _CreatorChartRange.d7 => 7,
    _CreatorChartRange.d30 => 30,
    _CreatorChartRange.d90 => 90,
    _CreatorChartRange.m12 => 365,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final points = CreatorDashboardData.generateSeries(_days);
    // 12-month view: sample weekly so the chart stays legible.
    final displayPoints = _range == _CreatorChartRange.m12
        ? [for (var i = 0; i < points.length; i += 7) points[i]]
        : points;

    final maxClicks = displayPoints.fold<int>(
      0,
      (value, p) => math.max(value, p.clicks),
    );
    final chartMax = maxClicks <= 0 ? 1.0 : maxClicks * 1.15;
    final date = DateFormat.MMMd();

    final clickSpots = <FlSpot>[
      for (var i = 0; i < displayPoints.length; i++)
        FlSpot(i.toDouble(), displayPoints[i].clicks.toDouble()),
    ];
    final regSpots = <FlSpot>[
      for (var i = 0; i < displayPoints.length; i++)
        FlSpot(i.toDouble(), displayPoints[i].registrations.toDouble()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.creatorPerformanceOverview, style: AppTheme.h3()),
            const CreatorPlaceholderBadge(),
            const Spacer(),
            _RangeChip(
              label: l10n.creatorTimeframe7d,
              selected: _range == _CreatorChartRange.d7,
              onTap: () => setState(() => _range = _CreatorChartRange.d7),
            ),
            _RangeChip(
              label: l10n.creatorTimeframe30d,
              selected: _range == _CreatorChartRange.d30,
              onTap: () => setState(() => _range = _CreatorChartRange.d30),
            ),
            _RangeChip(
              label: l10n.creatorTimeframe90d,
              selected: _range == _CreatorChartRange.d90,
              onTap: () => setState(() => _range = _CreatorChartRange.d90),
            ),
            _RangeChip(
              label: l10n.creatorTimeframe12m,
              selected: _range == _CreatorChartRange.m12,
              onTap: () => setState(() => _range = _CreatorChartRange.m12),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _Legend(
              color: const Color(0xFF9E1B4F),
              label: l10n.creatorTotalClicks,
            ),
            const SizedBox(width: 18),
            _Legend(
              color: const Color(0xFFF0B429),
              label: l10n.creatorRegistrations,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: math.max(1, displayPoints.length - 1).toDouble(),
              minY: 0,
              maxY: chartMax,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: chartMax / 4,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Color(0xFFE9E5E7), strokeWidth: 1),
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
                    reservedSize: 44,
                    interval: chartMax / 4,
                    getTitlesWidget: (value, meta) => Text(
                      NumberFormat.compact().format(value),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: math
                        .max(1, (displayPoints.length / 6).ceil())
                        .toDouble(),
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= displayPoints.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          date.format(displayPoints[index].date),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((spot) {
                    final isClicks = spot.barIndex == 0;
                    final label = isClicks
                        ? l10n.creatorTotalClicks
                        : l10n.creatorRegistrations;
                    return LineTooltipItem(
                      '$label\n${NumberFormat.decimalPattern().format(spot.y)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                _line(clickSpots, const Color(0xFF9E1B4F)),
                _line(regSpots, const Color(0xFFF0B429)),
              ],
            ),
            duration: const Duration(milliseconds: 250),
          ),
        ),
      ],
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
    spots: spots,
    color: color,
    barWidth: 2.5,
    isCurved: spots.length > 2,
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: .08)),
  );
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.card : AppTheme.bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTheme.caption(
            color: selected ? Colors.white : AppTheme.muted,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Text(label, style: AppTheme.caption(weight: FontWeight.w600)),
    ],
  );
}
