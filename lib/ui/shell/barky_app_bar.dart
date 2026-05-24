import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:badges/badges.dart' as badges;
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/services/chat_service.dart';

class BarkyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String currentUserId;
  final int unreadNotifications;

  final VoidCallback onMenuTap;
  final VoidCallback onChatTap;
  final VoidCallback onNotificationTap;

  const BarkyAppBar({
    super.key,
    required this.title,
    required this.currentUserId,
    this.unreadNotifications = 0,
    required this.onMenuTap,
    required this.onChatTap,
    required this.onNotificationTap,
  });

  bool _isChatStylePage() {
    final normalized = title.trim().toLowerCase();

    return normalized.contains("chat") || normalized.contains("message");
  }

  @override
  Widget build(BuildContext context) {
    final isChatPage = _isChatStylePage();

    return AppBar(
      automaticallyImplyLeading: false,

      backgroundColor: isChatPage ? const Color(0xFFFFFBFC) : Colors.pink,

      surfaceTintColor: Colors.transparent,

      scrolledUnderElevation: 0,
      elevation: 0,

      centerTitle: false,

      toolbarHeight: isChatPage ? 82 : 66,

      titleSpacing: isChatPage ? 18 : 6,

      leadingWidth: isChatPage ? 72 : 56,

      shape: isChatPage
          ? Border(
              bottom: BorderSide(
                color: Colors.black.withOpacity(.05),
                width: 1,
              ),
            )
          : null,

      leading: Padding(
        padding: EdgeInsets.only(
          left: isChatPage ? 16 : 8,
          top: isChatPage ? 10 : 0,
          bottom: isChatPage ? 10 : 0,
        ),

        child: Material(
          color: Colors.transparent,

          child: InkWell(
            borderRadius: BorderRadius.circular(18),

            onTap: onMenuTap,

            child: Ink(
              decoration: BoxDecoration(
                color: isChatPage
                    ? const Color(0xFFFFE8F1)
                    : Colors.transparent,

                borderRadius: BorderRadius.circular(18),
              ),

              child: Icon(
                LucideIcons.menu,

                color: isChatPage
                    ? const Color(0xFF9E1B4F)
                    : const Color(0xFFFFC107),

                size: 24,
              ),
            ),
          ),
        ),
      ),

      title: Padding(
        padding: EdgeInsets.only(top: isChatPage ? 6 : 0),

        child: Row(
          children: [
            if (isChatPage)
              Container(
                width: 46,
                height: 46,

                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,

                    colors: [Color(0xFFFFD7E5), Color(0xFFF6B4CC)],
                  ),

                  shape: BoxShape.circle,

                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9E1B4F).withOpacity(.10),

                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),

                child: const Icon(
                  LucideIcons.messageCircle,

                  color: Color(0xFF9E1B4F),
                  size: 22,
                ),
              ),

            if (isChatPage) const SizedBox(width: 14),

            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Text(
                    title,

                    overflow: TextOverflow.ellipsis,

                    style: isChatPage
                        ? GoogleFonts.poppins(
                            color: const Color(0xFF1E1E1E),

                            fontSize: 26,

                            fontWeight: FontWeight.w800,

                            letterSpacing: -.8,
                          )
                        : GoogleFonts.fredoka(
                            color: const Color(0xFFFFC107),

                            fontSize: 24,

                            fontWeight: FontWeight.w600,

                            letterSpacing: .3,
                          ),
                  ),

                  if (isChatPage)
                    Text(
                      'Connect with pet owners',

                      style: GoogleFonts.poppins(
                        fontSize: 12.5,

                        fontWeight: FontWeight.w500,

                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),

      actions: [
        if (!isChatPage)
          Container(
            margin: const EdgeInsets.only(right: 4),

            child: IconButton(
              icon: StreamBuilder<int>(
                stream: currentUserId.isEmpty || currentUserId == 'guest'
                    ? null
                    : ChatService.instance.getUnreadChatsCountStream(
                        userId: currentUserId,
                      ),
                builder: (context, snapshot) {
                  final unreadChats = snapshot.data ?? 0;

                  return badges.Badge(
                    showBadge: unreadChats > 0,
                    badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red),
                    badgeContent: Text(
                      unreadChats > 99 ? '99+' : unreadChats.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    position: badges.BadgePosition.topEnd(top: -8, end: -8),
                    child: const Icon(
                      LucideIcons.messageCircle,
                      color: Color(0xFFFFC107),
                      size: 23,
                    ),
                  );
                },
              ),

              onPressed: onChatTap,
            ),
          ),

        Padding(
          padding: EdgeInsets.only(
            right: isChatPage ? 18 : 12,
            top: isChatPage ? 10 : 0,
            bottom: isChatPage ? 10 : 0,
          ),

          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: currentUserId.isEmpty || currentUserId == 'guest'
                ? null
                : FirebaseFirestore.instance
                      .collection('notifications')
                      .where('recipientUserId', isEqualTo: currentUserId)
                      .where('isRead', isEqualTo: false)
                      .snapshots(),
            builder: (context, snapshot) {
              final liveUnreadNotifications = snapshot.hasData
                  ? snapshot.data!.docs.length
                  : unreadNotifications;

              return badges.Badge(
                showBadge: liveUnreadNotifications > 0,

                badgeStyle: badges.BadgeStyle(
                  badgeColor: isChatPage ? const Color(0xFF9E1B4F) : Colors.red,
                ),

                badgeContent: Text(
                  liveUnreadNotifications > 99
                      ? '99+'
                      : liveUnreadNotifications.toString(),

                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                position: badges.BadgePosition.topEnd(top: -4, end: -4),

                child: Material(
                  color: Colors.transparent,

                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),

                    onTap: onNotificationTap,

                    child: Ink(
                      width: 48,
                      height: 48,

                      decoration: BoxDecoration(
                        color: isChatPage ? Colors.white : Colors.transparent,

                        borderRadius: BorderRadius.circular(18),

                        border: isChatPage
                            ? Border.all(color: const Color(0xFFF1D6E0))
                            : null,
                      ),

                      child: Icon(
                        LucideIcons.bell,

                        color: isChatPage
                            ? const Color(0xFF9E1B4F)
                            : const Color(0xFFFFC107),

                        size: 23,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(_isChatStylePage() ? 82 : 66);
}
