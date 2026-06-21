import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/services/business_chat_service.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/chat/business_chat_page.dart';

class VetInboxPage extends StatelessWidget {
  final String businessId;

  const VetInboxPage({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Inbox'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: BusinessChatService.instance.businessChatsStream(
          businessId: businessId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint('❌ INBOX ERROR: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Inbox error:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: AppTheme.body(),
                ),
              ),
            );
          }

          final docs = BusinessChatService.instance.sortByLatestActivity(
            snapshot.data?.docs ?? [],
          );

          debugPrint(
            '📥 BUSINESS INBOX LOADED businessId=$businessId count=${docs.length}',
          );

          if (docs.isEmpty) {
            return const _EmptyInbox();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return _BusinessInboxTile(
                chatId: doc.id,
                clientUserId: data['clientUserId']?.toString() ?? '',
                clientName: _firstNonEmpty([
                  data['clientUserName'],
                  data['clientName'],
                  'Pet Owner',
                ]),
                clientPhotoUrl: data['clientPhotoUrl']?.toString() ?? '',
                petName: _firstNonEmpty([
                  data['clientPetName'],
                  data['petName'],
                ]),
                petPhotoUrl: data['clientPetPhotoUrl']?.toString() ?? '',
                lastMessage: data['lastMessage']?.toString() ?? '',
                unreadCount: _intValue(data['unreadCountBusiness']),
                emergency: data['emergency'] == true,
              );
            },
          );
        },
      ),
    );
  }
}

class _BusinessInboxTile extends StatelessWidget {
  final String chatId;
  final String clientUserId;
  final String clientName;
  final String clientPhotoUrl;
  final String petName;
  final String petPhotoUrl;
  final String lastMessage;
  final int unreadCount;
  final bool emergency;

  const _BusinessInboxTile({
    required this.chatId,
    required this.clientUserId,
    required this.clientName,
    required this.clientPhotoUrl,
    required this.petName,
    required this.petPhotoUrl,
    required this.lastMessage,
    required this.unreadCount,
    required this.emergency,
  });

  @override
  Widget build(BuildContext context) {
    if (clientName == 'Pet Owner' && clientUserId.isNotEmpty) {
      return FutureBuilder<Map<String, String>>(
        future: BusinessChatService.instance.clientPreview(clientUserId),
        builder: (context, snapshot) {
          final preview = snapshot.data ?? const <String, String>{};
          return _tile(
            context,
            displayName: _firstNonEmpty([
              preview['clientUserName'],
              clientName,
            ]),
            displayPhotoUrl: _firstNonEmpty([
              preview['clientPhotoUrl'],
              clientPhotoUrl,
            ]),
            displayPetName: _firstNonEmpty([preview['clientPetName'], petName]),
            displayPetPhotoUrl: _firstNonEmpty([
              preview['clientPetPhotoUrl'],
              petPhotoUrl,
            ]),
          );
        },
      );
    }

    return _tile(
      context,
      displayName: clientName,
      displayPhotoUrl: clientPhotoUrl,
      displayPetName: petName,
      displayPetPhotoUrl: petPhotoUrl,
    );
  }

  Widget _tile(
    BuildContext context, {
    required String displayName,
    required String displayPhotoUrl,
    required String displayPetName,
    required String displayPetPhotoUrl,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BusinessChatPage(
              chatId: chatId,
              businessName: displayName,
              viewerRole: 'business',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: emergency
              ? Border.all(
                  color: Colors.red.withValues(alpha: 0.25),
                  width: 1.4,
                )
              : null,
          boxShadow: AppTheme.cardShadow(opacity: 0.06),
        ),
        child: Row(
          children: [
            _avatar(displayPhotoUrl, fallbackIcon: LucideIcons.user),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(displayName, style: AppTheme.h3(size: 16)),
                      ),
                      if (emergency) _emergencyBadge(),
                    ],
                  ),
                  if (displayPetName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _petPreview(displayPetPhotoUrl),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            displayPetName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.caption(),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    lastMessage.isEmpty ? 'Start conversation' : lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                if (unreadCount > 0) _unreadBadge(unreadCount),
                const SizedBox(height: 12),
                const Icon(LucideIcons.chevronRight, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String imageUrl, {required IconData fallbackIcon}) {
    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          imageUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _fallbackAvatar(fallbackIcon),
        ),
      );
    }

    return _fallbackAvatar(fallbackIcon);
  }

  Widget _fallbackAvatar(IconData icon) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: emergency
            ? Colors.red.withValues(alpha: 0.12)
            : AppTheme.card.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: emergency ? Colors.red : AppTheme.card),
    );
  }

  Widget _petPreview(String imageUrl) {
    if (imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: 22,
          height: 22,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(LucideIcons.dog, size: 16),
        ),
      );
    }

    return const Icon(LucideIcons.dog, size: 16, color: Colors.black45);
  }

  Widget _emergencyBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Text(
        'Emergency',
        style: TextStyle(
          color: Colors.red,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _unreadBadge(int count) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: AppTheme.accent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.card.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.messagesSquare,
                size: 42,
                color: AppTheme.card,
              ),
            ),
            const SizedBox(height: 22),
            Text('No client messages yet', style: AppTheme.h2()),
            const SizedBox(height: 10),
            Text(
              'When pet owners contact your clinic, conversations will appear here.',
              textAlign: TextAlign.center,
              style: AppTheme.caption(),
            ),
          ],
        ),
      ),
    );
  }
}

String _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '0') ?? 0;
}
