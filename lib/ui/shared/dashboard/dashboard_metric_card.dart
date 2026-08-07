import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class DashboardMetricData {
  const DashboardMetricData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class DashboardMetricCard extends StatelessWidget {
  const DashboardMetricCard({
    super.key,
    required this.item,
    this.compact = false,
  });

  final DashboardMetricData item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decide from the height available to the normal Column after its
        // padding, rather than from the outer tile height. The 1.4 factor is
        // a conservative line-height allowance for the Poppins text styles
        // and user text scaling.
        final normalPadding = compact ? 14.0 : 16.0;
        final textScaler = MediaQuery.textScalerOf(context);
        final captionHeight = textScaler.scale(12) * 1.4;
        final valueHeight = textScaler.scale(compact ? 18 : 24) * 1.4;
        final firstRowHeight = compact
            ? 18.0
            : math.max(16.0, captionHeight);
        final normalContentHeight = compact
            ? firstRowHeight + 2 + valueHeight + captionHeight
            : firstRowHeight + 8 + valueHeight;
        final availableContentHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight - normalPadding * 2
            : double.infinity;
        final dense =
            constraints.hasBoundedHeight &&
            availableContentHeight < normalContentHeight;

        return Container(
          padding: EdgeInsets.all(dense ? 8 : compact ? 14 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              compact ? AppTheme.radius : AppTheme.radius,
            ),
            boxShadow: AppTheme.cardShadow(),
          ),
          child: dense
              ? Row(
                  children: [
                    Icon(item.icon, size: 16, color: AppTheme.card),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.value,
                            style: AppTheme.h2(
                              weight: FontWeight.w800,
                              size: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item.label,
                            style: AppTheme.caption(size: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.icon, size: 18, color: AppTheme.card),
                    const Spacer(),
                    Text(
                      item.value,
                      style: AppTheme.h2(weight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: AppTheme.caption(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(item.icon, size: 16, color: AppTheme.card),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.label,
                            style: AppTheme.caption(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.value,
                      style: AppTheme.h1(weight: FontWeight.w800, size: 24),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
