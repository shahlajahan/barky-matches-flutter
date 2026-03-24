import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import 'nav_tab.dart';

class BarkyBottomNav extends StatelessWidget {
  final NavTab currentTab;

  const BarkyBottomNav({
    super.key,
    required this.currentTab,
  });

  @override
Widget build(BuildContext context) {
  final appState = context.read<AppState>();

  return SizedBox(
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
                icon: Icons.home,
                label: 'Home',
                tab: NavTab.home,
              ),

              _buildItem(
                context,
                icon: Icons.favorite,
                label: 'Favorites',
                tab: NavTab.favorites,
              ),

              const SizedBox(width: 60),

              _buildItem(
                context,
                icon: Icons.calendar_today,
                label: 'Schedule',
                tab: NavTab.playdateScheduling,
              ),

              _buildItem(
                context,
                icon: Icons.person,
                label: 'Profile',
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
              if (currentTab == NavTab.vet) return;
              appState.closeNotifications();
              appState.setCurrentTab(NavTab.vet);
            },
            child: Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentTab == NavTab.vet
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
                Icons.local_hospital,
                color: currentTab == NavTab.vet
                    ? Colors.black
                    : Colors.pink,
                size: 28,
              ),
            ),
          ),
        ),
      ],
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
    final isActive = tab == currentTab;

    return GestureDetector(
      onTap: () {
        if (isActive) return;
        appState.closeNotifications();
        appState.setCurrentTab(tab);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive
                ? const Color(0xFFFFC107)
                : Colors.white70,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive
                  ? const Color(0xFFFFC107)
                  : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}