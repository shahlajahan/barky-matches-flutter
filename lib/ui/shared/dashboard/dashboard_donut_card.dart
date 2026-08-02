import 'package:flutter/material.dart';

import 'dashboard_panel.dart';

class DashboardDonutCard extends StatelessWidget {
  const DashboardDonutCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DashboardPanel(child: child);
}
