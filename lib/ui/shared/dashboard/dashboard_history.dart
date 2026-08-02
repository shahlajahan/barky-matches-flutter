import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

import 'dashboard_section.dart';

class DashboardHistoryItem {
  const DashboardHistoryItem({
    required this.date,
    required this.amount,
    required this.status,
    required this.statusColor,
    this.statusBackgroundColor,
  });

  final String date;
  final String amount;
  final String status;
  final Color? statusColor;
  final Color? statusBackgroundColor;
}

class DashboardHistory extends StatelessWidget {
  const DashboardHistory({
    super.key,
    required this.items,
    this.title,
    this.trailing,
  });

  final String? title;
  final Widget? trailing;
  final List<DashboardHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(item.date, style: AppTheme.body())),
                Text(
                  item.amount,
                  style: AppTheme.body(weight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: item.statusBackgroundColor == null
                        ? AppTheme.bg
                        : item.statusBackgroundColor!.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.status,
                    style: AppTheme.caption(
                      color: item.statusColor ?? AppTheme.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (title == null) return content;
    return DashboardSection(title: title!, trailing: trailing, child: content);
  }
}
