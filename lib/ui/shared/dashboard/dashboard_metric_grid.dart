import 'package:flutter/material.dart';

import 'dashboard_metric_card.dart';

class DashboardMetricGrid extends StatelessWidget {
  const DashboardMetricGrid({
    super.key,
    required this.items,
    required this.columns,
    this.compact = false,
    this.trailing,
    this.childAspectRatio = 2.1,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
  });

  final List<DashboardMetricData> items;
  final int columns;
  final bool compact;
  final Widget? trailing;
  final double childAspectRatio;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Three compact cards become too narrow on phones: the card's
        // existing icon/value/label stack needs a taller tile than the
        // three-column geometry can provide. Keep the requested desktop
        // columns, but use two columns when the available width cannot give
        // each compact tile a reasonable width.
        final effectiveColumns =
            compact && columns > 2 && constraints.maxWidth < 420 ? 2 : columns;
        final ratio = compact ? 1.35 : childAspectRatio;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (trailing != null) ...[
              Padding(
                padding: EdgeInsets.only(bottom: compact ? 8 : 10),
                child: trailing,
              ),
            ],
            GridView.count(
              crossAxisCount: effectiveColumns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: compact ? 12 : mainAxisSpacing,
              crossAxisSpacing: compact ? 12 : crossAxisSpacing,
              childAspectRatio: ratio,
              children: [
                for (final item in items)
                  DashboardMetricCard(item: item, compact: compact),
              ],
            ),
          ],
        );
      },
    );
  }
}
