import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:barky_matches_fixed/services/business_chat_service.dart';
import 'package:barky_matches_fixed/services/chat_service.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/chat/chat_detail_page.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barky_matches_fixed/ui/chat/chat_search_delegate.dart';
import 'package:barky_matches_fixed/ui/business/chat/business_chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  static const Color _primary = Color(0xFF9E1B4F);
  static const Color _background = Color(0xFFFFFBFC);
  static const Color _cardBorder = Color(0xFFF1D6E0);
  static const Color _softPink = Color(0xFFFCE7F0);

  String get currentUserId => FirebaseAuth.instance.currentUser!.uid;

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: _softPink,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble_rounded,
                size: 48,
                color: _primary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'No chats yet',
              style: AppTheme.h2().copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1F1F1F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start chatting with pet owners and make new friends for your pet 👋',
              textAlign: TextAlign.center,
              style: AppTheme.body(
                color: AppTheme.muted,
              ).copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveOtherUserId({required List<dynamic> participants}) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  String _resolveOtherUserName({
    required Map<String, dynamic> data,
    required String otherUserId,
  }) {
    final participantNames = data['participantNames'];

    if (participantNames is Map && participantNames[otherUserId] != null) {
      return participantNames[otherUserId].toString();
    }

    return 'Chat';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();

    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final yesterday = now.subtract(const Duration(days: 1));

    final isYesterday =
        date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    if (isToday) {
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    if (isYesterday) {
      return 'Yesterday';
    }

    const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final difference = now.difference(date).inDays;

    if (difference < 7) {
      return weekDays[date.weekday - 1];
    }

    final d = date.day.toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');

    return '$d/$mo';
  }

  String _initialLetter(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) return '?';

    return trimmed.characters.first.toUpperCase();
  }

  Widget _buildAvatar({required String name}) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,

        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD7E5), Color(0xFFF7B1CC)],
        ),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9E1B4F).withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      alignment: Alignment.center,

      child: Text(
        _initialLetter(name),
        style: const TextStyle(
          color: Color(0xFF9E1B4F),
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildUnreadBadge(int unreadCount) {
    if (unreadCount <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 8),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        unreadCount > 99 ? '99+' : unreadCount.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildChatTile({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data();

    final participants = List<dynamic>.from(data['participants'] ?? []);

    final otherUserId = _resolveOtherUserId(participants: participants);

    final otherUserName = _resolveOtherUserName(
      data: data,
      otherUserId: otherUserId,
    );

    final lastMessage = (data['lastMessage'] ?? '').toString();

    final unreadMap = Map<String, dynamic>.from(data['unreadCount'] ?? {});

    final rawUnread = unreadMap[currentUserId];

    final unreadCount = rawUnread is int
        ? rawUnread
        : int.tryParse(rawUnread?.toString() ?? '0') ?? 0;

    final Timestamp? ts = data['lastMessageAt'];
    final DateTime? date = ts?.toDate();
    final String timeText = _formatTime(date);

    final bool isUnread = unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatDetailPage(
                  chatId: doc.id,
                  otherUserId: otherUserId,
                  otherUserName: otherUserName,
                ),
              ),
            );
          },
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isUnread
                    ? _primary.withValues(alpha: 0.22)
                    : _cardBorder,
                width: isUnread ? 1.2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.045),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  _buildAvatar(name: otherUserName),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                otherUserName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: isUnread
                                      ? FontWeight.w900
                                      : FontWeight.w800,
                                  color: const Color(0xFF1E1E1E),
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeText,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isUnread
                                    ? _primary
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMessage.isEmpty
                                    ? 'Start a conversation'
                                    : lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  height: 1.2,
                                  color: isUnread
                                      ? const Color(0xFF222222)
                                      : Colors.grey.shade500,
                                  fontWeight: isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            _buildUnreadBadge(unreadCount),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 10),
      itemCount: 6,
      itemBuilder: (_, index) => _buildLoadingTile(index),
    );
  }

  Widget _buildLoadingTile(int index) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 12,
                      margin: const EdgeInsets.only(right: 70),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              'Failed to load chats',
              style: AppTheme.h2().copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppTheme.body(color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Text(
        'Personal chats could not be loaded.',
        style: AppTheme.body(color: AppTheme.muted),
      ),
    );
  }

  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BusinessChatService.instance.clientChatsStream(
        clientUserId: currentUserId,
      ),
      builder: (context, businessSnapshot) {
        final businessDocs = BusinessChatService.instance.sortByLatestActivity(
          businessSnapshot.data?.docs ?? [],
        );
        if (businessSnapshot.hasData) {
          debugPrint('💬 BUSINESS CHATS COUNT: ${businessDocs.length}');
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ChatService.instance.getChatsStream(userId: currentUserId),
          builder: (context, chatSnapshot) {
            final chatDocs = chatSnapshot.data?.docs ?? [];
            final personalLoading =
                chatSnapshot.connectionState == ConnectionState.waiting;
            final businessLoading =
                businessSnapshot.connectionState == ConnectionState.waiting;

            if (businessLoading && personalLoading) {
              return _buildLoadingState();
            }

            if (businessSnapshot.hasError && chatSnapshot.hasError) {
              return _buildErrorState();
            }

            if (businessDocs.isEmpty && chatDocs.isEmpty && !personalLoading) {
              return _buildEmptyState();
            }

            final items = <_ChatInboxItem>[
              if (businessDocs.isNotEmpty) ...[
                const _ChatInboxItem.businessHeader(),
                ...businessDocs.map(_ChatInboxItem.businessChat),
              ],
              if (personalLoading)
                ...List.generate(4, _ChatInboxItem.loading)
              else if (chatSnapshot.hasError)
                const _ChatInboxItem.personalError()
              else
                ...chatDocs.map(_ChatInboxItem.personalChat),
            ];

            debugPrint(
              '💬 CHAT INBOX ITEMS business=${businessDocs.length} personal=${chatDocs.length} total=${items.length}',
            );

            return ListView.builder(
              key: const PageStorageKey('chat_inbox_combined_v2'),
              padding: const EdgeInsets.only(top: 10, bottom: 18),
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                switch (item.type) {
                  case _ChatInboxItemType.businessHeader:
                    debugPrint('🟢 BUSINESS SECTION RENDERED');
                    return _buildBusinessHeader();
                  case _ChatInboxItemType.businessChat:
                    debugPrint(
                      '🟢 BUSINESS TILE INSERTED index=$index chatId=${item.businessDoc!.id}',
                    );
                    return _buildBusinessChatTile(item.businessDoc!);
                  case _ChatInboxItemType.personalChat:
                    return _buildChatTile(doc: item.personalDoc!);
                  case _ChatInboxItemType.loading:
                    return _buildLoadingTile(index);
                  case _ChatInboxItemType.personalError:
                    return _buildInlineError();
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBusinessHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Text(
        'Business Conversations',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E1E1E),
        ),
      ),
    );
  }

  Widget _buildBusinessChatTile(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final businessName = data['businessName']?.toString() ?? 'Business';
    final businessLogoUrl = data['businessLogoUrl']?.toString() ?? '';
    final lastMessage = data['lastMessage']?.toString() ?? '';
    final rawUnread = data['unreadCountClient'];
    final unreadCount = rawUnread is int
        ? rawUnread
        : int.tryParse(rawUnread?.toString() ?? '0') ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessChatPage(
                  chatId: doc.id,
                  businessName: businessName,
                  viewerRole: 'client',
                ),
              ),
            );
          },
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _cardBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _buildBusinessAvatar(businessLogoUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _buildUnreadBadge(unreadCount),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lastMessage.isEmpty
                              ? 'Start conversation'
                              : lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessAvatar(String imageUrl) {
    if (imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildBusinessAvatar(''),
        ),
      );
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _softPink),
      child: const Icon(
        Icons.medical_services_rounded,
        color: _primary,
        size: 30,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,

      appBar: _buildAppBar(),

      body: _buildChatList(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,

      toolbarHeight: 74,

      backgroundColor: Colors.pink,

      surfaceTintColor: Colors.transparent,

      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Color(0xFFFFC107),
          size: 20,
        ),

        onPressed: () {
          Navigator.pop(context);
        },
      ),

      titleSpacing: 18,

      centerTitle: false,

      title: Row(
        children: [
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
                  color: Colors.black.withValues(alpha: .12),
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

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Text(
                  'Chats',

                  style: GoogleFonts.fredoka(
                    fontSize: 28,

                    fontWeight: FontWeight.w700,

                    letterSpacing: .2,

                    color: const Color(0xFFFFC107),
                  ),
                ),

                Text(
                  'Connect with pet owners',

                  style: GoogleFonts.poppins(
                    fontSize: 12.5,

                    fontWeight: FontWeight.w500,

                    color: Colors.white.withValues(alpha: .85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),

          child: Material(
            color: Colors.transparent,

            child: InkWell(
              borderRadius: BorderRadius.circular(18),

              onTap: () async {
                final snapshot = await FirebaseFirestore.instance
                    .collection('chats')
                    .where('participants', arrayContains: currentUserId)
                    .get();

                final chats = snapshot.docs.map((doc) {
                  final data = doc.data();

                  final participants = List<dynamic>.from(
                    data['participants'] ?? [],
                  );

                  final otherUserId = _resolveOtherUserId(
                    participants: participants,
                  );

                  final otherUserName = _resolveOtherUserName(
                    data: data,
                    otherUserId: otherUserId,
                  );

                  return {
                    'chatId': doc.id,
                    'name': otherUserName,
                    'message': data['lastMessage'] ?? '',
                  };
                }).toList();

                if (!mounted) return;

                showSearch(
                  context: context,

                  delegate: ChatSearchDelegate(chats: chats),
                );
              },

              child: Ink(
                width: 48,
                height: 48,

                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),

                  borderRadius: BorderRadius.circular(18),

                  border: Border.all(
                    color: Colors.white.withValues(alpha: .15),
                  ),
                ),

                child: const Icon(
                  Icons.search_rounded,

                  color: Color(0xFFFFC107),

                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _ChatInboxItemType {
  businessHeader,
  businessChat,
  personalChat,
  loading,
  personalError,
}

class _ChatInboxItem {
  final _ChatInboxItemType type;
  final QueryDocumentSnapshot<Map<String, dynamic>>? businessDoc;
  final QueryDocumentSnapshot<Map<String, dynamic>>? personalDoc;

  const _ChatInboxItem._({
    required this.type,
    this.businessDoc,
    this.personalDoc,
  });

  const _ChatInboxItem.businessHeader()
    : this._(type: _ChatInboxItemType.businessHeader);

  const _ChatInboxItem.businessChat(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) : this._(type: _ChatInboxItemType.businessChat, businessDoc: doc);

  const _ChatInboxItem.personalChat(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) : this._(type: _ChatInboxItemType.personalChat, personalDoc: doc);

  const _ChatInboxItem.loading(int index)
    : this._(type: _ChatInboxItemType.loading);

  const _ChatInboxItem.personalError()
    : this._(type: _ChatInboxItemType.personalError);
}
