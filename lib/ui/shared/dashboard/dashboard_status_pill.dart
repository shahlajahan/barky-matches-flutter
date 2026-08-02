import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class DashboardStatusPill extends StatelessWidget {
  const DashboardStatusPill({
    super.key,
    required this.prefix,
    required this.label,
    this.active = false,
  });

  final String prefix;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Text(
          '$prefix: ',
          style: AppTheme.caption(color: Colors.white.withValues(alpha: 0.7)),
        ),
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(
            color: active ? Colors.greenAccent : Colors.white54,
            shape: BoxShape.circle,
          ),
        ),
        Flexible(
          child: Text(
            label,
            softWrap: true,
            style: AppTheme.caption(
              color: Colors.white,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
