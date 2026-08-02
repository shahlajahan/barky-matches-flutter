import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

import 'dashboard_section.dart';

class DashboardTimelineItem {
  const DashboardTimelineItem({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final IconData icon;
  final Color color;
}

class DashboardTimeline extends StatelessWidget {
  const DashboardTimeline({
    super.key,
    required this.items,
    this.title,
    this.trailing,
  });

  final String? title;
  final Widget? trailing;
  final List<DashboardTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: items[i].color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(items[i].icon, size: 16, color: items[i].color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items[i].title,
                      style: AppTheme.body(weight: FontWeight.w600),
                    ),
                    Text(items[i].subtitle, style: AppTheme.caption()),
                  ],
                ),
              ),
              Text(items[i].trailing, style: AppTheme.caption()),
            ],
          ),
        ],
      ],
    );

    if (title == null) return content;
    return DashboardSection(title: title!, trailing: trailing, child: content);
  }
}
