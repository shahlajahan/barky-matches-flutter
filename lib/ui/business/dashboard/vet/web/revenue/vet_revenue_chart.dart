import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'vet_revenue_model.dart';

class VetRevenueChart extends StatelessWidget {
  const VetRevenueChart({
    super.key,
    required this.points,
    required this.localeName,
    required this.grossLabel,
    required this.netLabel,
    required this.emptyLabel,
  });

  final List<VetRevenuePoint> points;
  final String localeName;
  final String grossLabel;
  final String netLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: 280,
        child: Center(
          child: Text(
            emptyLabel,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    final maxValue = points.fold<double>(
      0,
      (value, point) => math.max(value, math.max(point.gross, point.net)),
    );
    final chartMax = maxValue <= 0 ? 1.0 : maxValue * 1.15;
    final currency = points.first.currency;
    final money = NumberFormat.currency(
      locale: localeName,
      symbol: currency == 'TRY' ? '₺' : '$currency ',
      decimalDigits: 2,
    );
    final date = DateFormat.MMMd(localeName);
    final grossSpots = <FlSpot>[
      for (var index = 0; index < points.length; index++)
        FlSpot(index.toDouble(), points[index].gross),
    ];
    final netSpots = <FlSpot>[
      for (var index = 0; index < points.length; index++)
        FlSpot(index.toDouble(), points[index].net),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _Legend(color: const Color(0xFF9E1B4F), label: grossLabel),
            _Legend(color: const Color(0xFF0F766E), label: netLabel),
          ],
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: math.max(1, points.length - 1).toDouble(),
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
                    reservedSize: 62,
                    interval: chartMax / 4,
                    getTitlesWidget: (value, meta) => Text(
                      NumberFormat.compact(locale: localeName).format(value),
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
                    reservedSize: 34,
                    interval: math
                        .max(1, (points.length / 5).ceil())
                        .toDouble(),
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          date.format(points[index].date),
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
                    final label = spot.barIndex == 0 ? grossLabel : netLabel;
                    return LineTooltipItem(
                      '$label\n${money.format(spot.y)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                _line(grossSpots, const Color(0xFF9E1B4F)),
                _line(netSpots, const Color(0xFF0F766E)),
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
    barWidth: 3,
    isCurved: spots.length > 2,
    dotData: FlDotData(show: spots.length <= 12),
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: .08)),
  );
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
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}
