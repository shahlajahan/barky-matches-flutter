import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

class BusinessWebDashboardDestination {
  const BusinessWebDashboardDestination({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Widget child;
}

class BusinessWebDashboardShell extends StatefulWidget {
  const BusinessWebDashboardShell({
    super.key,
    required this.businessName,
    required this.sectorName,
    required this.destinations,
  });

  final String businessName;
  final String sectorName;
  final List<BusinessWebDashboardDestination> destinations;

  @override
  State<BusinessWebDashboardShell> createState() =>
      _BusinessWebDashboardShellState();
}

class _BusinessWebDashboardShellState extends State<BusinessWebDashboardShell> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final current = widget.destinations[_selected];
    return ColoredBox(
      color: AppTheme.bg,
      child: Row(
        children: [
          Container(
            width: 248,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PetSupo',
                  style: TextStyle(
                    color: Color(0xFF9E1B4F),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  widget.sectorName,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 32),
                for (var index = 0; index < widget.destinations.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DestinationButton(
                      destination: widget.destinations[index],
                      selected: _selected == index,
                      onTap: () => setState(() => _selected = index),
                    ),
                  ),
                const Spacer(),
                Text(
                  widget.businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 82,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              current.label,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              current.subtitle,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        widget.businessName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1680),
                      child: IndexedStack(
                        index: _selected,
                        children: [
                          for (final item in widget.destinations) item.child,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationButton extends StatelessWidget {
  const _DestinationButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });
  final BusinessWebDashboardDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF9E1B4F) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            destination.icon,
            size: 19,
            color: selected ? Colors.white : Colors.black54,
          ),
          const SizedBox(width: 11),
          Text(
            destination.label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

String businessDashboardName(Map<String, dynamic> data, String fallback) {
  final profile =
      (data['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
  for (final value in [
    profile['businessName'],
    data['businessName'],
    data['name'],
  ]) {
    final name = value?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
  }
  return fallback;
}
