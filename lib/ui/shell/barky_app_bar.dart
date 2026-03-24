import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:badges/badges.dart' as badges;

class BarkyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final int unreadNotifications;

  final VoidCallback onMenuTap;
  final VoidCallback onChatTap;
  final VoidCallback onNotificationTap;

  const BarkyAppBar({
    super.key,
    required this.title,
    this.unreadNotifications = 0,
    required this.onMenuTap,
    required this.onChatTap,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.pink,
      elevation: 0,

      leading: IconButton(
        icon: const Icon(Icons.menu, color: Color(0xFFFFC107)),
        onPressed: onMenuTap,
      ),

      title: Text(
        title,
        style: GoogleFonts.dancingScript(
          color: const Color(0xFFFFC107),
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
      ),

      actions: [
        IconButton(
          icon: const Icon(
            Icons.chat_bubble_outline,
            color: Color(0xFFFFC107),
          ),
          onPressed: onChatTap,
        ),

        badges.Badge(
          showBadge: unreadNotifications > 0,
          badgeContent: Text(
            unreadNotifications.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          position: badges.BadgePosition.topEnd(top: -4, end: -4),
          child: IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: Color(0xFFFFC107),
            ),
            onPressed: onNotificationTap, // 🔔 کاملاً فعال
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
