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
        return Container(
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              compact ? AppTheme.radius : AppTheme.radius,
            ),
            boxShadow: AppTheme.cardShadow(),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.icon, size: 18, color: AppTheme.card),
                    const Spacer(),
                    Text(
                      item.value,
                      style: AppTheme.h2(weight: FontWeight.w800),
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
                    ),
                  ],
                ),
        );
      },
    );
  }
}
