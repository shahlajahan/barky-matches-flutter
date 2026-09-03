import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import '../../app_state.dart';
import 'nav_tab.dart';

class BarkyBottomNav extends StatefulWidget {
  final NavTab currentTab;

  const BarkyBottomNav({super.key, required this.currentTab});

  @override
  State<BarkyBottomNav> createState() => _BarkyBottomNavState();
}

class _BarkyBottomNavState extends State<BarkyBottomNav> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void activate() {
    super.activate();
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showBottomNav = kIsWeb
        ? context.select<AppState, bool>((state) => state.showBottomNav)
        : context.watch<AppState>().showBottomNav;
    final appState = context.read<AppState>();
    // Resolved during build, so a locale change rebuilds the labels in place
    // without restarting the app. Never cached in a field or initState.
    final l10n = AppLocalizations.of(context)!;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 250),
      offset: showBottomNav ? Offset.zero : const Offset(0, 1.5),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: showBottomNav ? 1 : 0,
        child: SizedBox(
          height: 65,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // 🔲 Main Bar Background
              Container(
                height: 65,
                color: Colors.pink,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildItem(
                      context,
                      icon: LucideIcons.home,
                      label: l10n.homeNavItem,
                      tab: NavTab.home,
                    ),

                    _buildItem(
                      context,
                      icon: LucideIcons.heart,
                      label: l10n.favoritesNavItem,
                      tab: NavTab.favorites,
                    ),

                    const SizedBox(width: 60),

                    _buildItem(
                      context,
                      icon: LucideIcons.calendar,
                      label: l10n.scheduleNavItem,
                      tab: NavTab.playdateScheduling,
                    ),

                    _buildItem(
                      context,
                      icon: LucideIcons.user,
                      label: l10n.profileNavItem,
                      tab: NavTab.profile,
                    ),
                  ],
                ),
              ),

              // ⭐ CENTER VET BUTTON
              Positioned(
                top: -10,
                child: GestureDetector(
                  onTap: () {
                    if (widget.currentTab == NavTab.vet) return;

                    appState.closeNotifications();

                    appState.setBottomNavVisibility(true);

                    appState.setCurrentTab(NavTab.vet);
                  },
                  child: Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.currentTab == NavTab.vet
                          ? const Color(0xFFFFC107)
                          : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      LucideIcons.stethoscope,
                      color: widget.currentTab == NavTab.vet
                          ? Colors.black
                          : Colors.pink,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required NavTab tab,
  }) {
    final appState = context.read<AppState>();
    final isActive = tab == widget.currentTab;

    return GestureDetector(
      onTap: () {
        if (isActive && tab != NavTab.profile) {
          return;
        }

        appState.closeNotifications();

        appState.setBottomNavVisibility(true);

        appState.setCurrentTab(tab);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22, // 👈 unify size
            color: isActive
                ? const Color(0xFFFFC107)
                : Colors.white.withOpacity(0.85),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive
                  ? const Color(0xFFFFC107)
                  : Colors.white.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }
}
