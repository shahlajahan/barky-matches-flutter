import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/creator/creator_dashboard_data.dart';
import 'package:barky_matches_fixed/ui/creator/creator_placeholder_badge.dart';

class CreatorRewardDonut extends StatelessWidget {
  const CreatorRewardDonut({super.key, required this.slices});

  final List<CreatorRewardSlice> slices;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.creatorRewardBreakdown, style: AppTheme.h3()),
            ),
            const CreatorPlaceholderBadge(),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: [
                    for (final slice in slices)
                      PieChartSectionData(
                        value: slice.value,
                        color: slice.color,
                        radius: 34,
                        showTitle: false,
                      ),
                  ],
                  centerSpaceRadius: 56,
                  sectionsSpace: 3,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.creatorTotalEarned, style: AppTheme.caption()),
                  Text(
                    money.format(total),
                    style: AppTheme.h2(weight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: slice.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(slice.label, style: AppTheme.body())),
                Text(
                  money.format(slice.value),
                  style: AppTheme.body(weight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(slice.value / total * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: AppTheme.caption(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
