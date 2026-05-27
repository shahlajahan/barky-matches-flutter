import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:barky_matches_fixed/services/business_chat_service.dart';
import 'package:barky_matches_fixed/ui/business/chat/business_chat_page.dart';

class UserInboxPage extends StatelessWidget {
  const UserInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F1F4),

      appBar: AppBar(title: const Text('Messages')),

      body: currentUserId == null
          ? const Center(child: Text('User not logged in'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: BusinessChatService.instance.clientChatsStream(
                clientUserId: currentUserId,
              ),

              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint('❌ USER INBOX ERROR: ${snapshot.error}');

                  return Center(child: Text('Failed to load messages'));
                }

                final docs = BusinessChatService.instance.sortByLatestActivity(
                  snapshot.data?.docs ?? [],
                );

                if (docs.isEmpty) {
                  return const _EmptyInbox();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),

                  itemCount: docs.length,

                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),

                  itemBuilder: (context, index) {
                    final data = docs[index].data();

                    final businessName =
                        data['businessName']?.toString() ?? 'Business';

                    final lastMessage = data['lastMessage']?.toString() ?? '';

                    final unreadCount = data['unreadCountClient'] ?? 0;

                    final businessType = data['businessType']?.toString() ?? '';

                    final chatId = docs[index].id;

                    return InkWell(
                      borderRadius: BorderRadius.circular(22),

                      onTap: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => BusinessChatPage(
                              chatId: chatId,
                              businessName: businessName,
                              viewerRole: 'client',
                            ),
                          ),
                        );
                      },

                      child: Container(
                        padding: const EdgeInsets.all(16),

                        decoration: BoxDecoration(
                          color: Colors.white,

                          borderRadius: BorderRadius.circular(22),

                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),

                              blurRadius: 14,

                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),

                        child: Row(
                          children: [
                            // AVATAR
                            Container(
                              width: 60,
                              height: 60,

                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFE91E63,
                                ).withValues(alpha: 0.08),

                                borderRadius: BorderRadius.circular(18),
                              ),

                              child: const Icon(
                                Icons.medical_services_outlined,

                                color: Color(0xFFE91E63),

                                size: 30,
                              ),
                            ),

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
                                            fontSize: 19,

                                            fontWeight: FontWeight.w700,

                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),

                                      if (unreadCount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),

                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE91E63),

                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),

                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : unreadCount.toString(),

                                            style: const TextStyle(
                                              color: Colors.white,

                                              fontWeight: FontWeight.bold,

                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  Text(
                                    businessType.toUpperCase(),

                                    style: TextStyle(
                                      color: Colors.black54,

                                      fontSize: 12,

                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    lastMessage,

                                    maxLines: 1,

                                    overflow: TextOverflow.ellipsis,

                                    style: const TextStyle(
                                      fontSize: 15,

                                      color: Colors.black54,

                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            const Icon(
                              Icons.chevron_right_rounded,

                              color: Colors.black38,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
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
              width: 100,
              height: 100,

              decoration: BoxDecoration(
                color: const Color(0xFFE91E63).withValues(alpha: 0.08),

                shape: BoxShape.circle,
              ),

              child: const Icon(
                Icons.chat_bubble_outline_rounded,

                size: 44,

                color: Color(0xFFE91E63),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'No conversations yet',

              style: TextStyle(
                fontSize: 28,

                fontWeight: FontWeight.w700,

                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'When you contact a business,\nyour conversations will appear here.',

              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 16,

                color: Colors.black54,

                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
