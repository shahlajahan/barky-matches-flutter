import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/services/business_chat_service.dart';
import 'package:lucide_icons/lucide_icons.dart';

class BusinessChatPage extends StatefulWidget {
  final String chatId;
  final String businessName;
  final String viewerRole;

  const BusinessChatPage({
    super.key,
    required this.chatId,
    required this.businessName,
    required this.viewerRole,
  }) : assert(viewerRole == 'client' || viewerRole == 'business');

  @override
  State<BusinessChatPage> createState() => _BusinessChatPageState();
}

class _BusinessChatPageState extends State<BusinessChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _markAsSeen();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

Future<void> _openQuickReplies() async {
  final chatDoc = await FirebaseFirestore.instance
      .collection('business_chats')
      .doc(widget.chatId)
      .get();

  final businessId =
      chatDoc.data()?['businessId']?.toString();

  if (businessId == null || businessId.isEmpty) {
    debugPrint('❌ BUSINESS ID NOT FOUND');
    return;
  }

  final repliesSnapshot = await FirebaseFirestore.instance
      .collection('businesses')
      .doc(businessId)
      .collection('quickReplies')
      .where('isActive', isEqualTo: true)
      .get();

  final docs = repliesSnapshot.docs;

  if (!mounted) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(28),
      ),
    ),
    builder: (context) {
      if (docs.isEmpty) {
        return const SizedBox(
          height: 180,
          child: Center(
            child: Text(
              'No quick replies found',
            ),
          ),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Quick Replies',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 18),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: docs.length,

                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),

                  itemBuilder: (context, index) {
                    final data = docs[index].data();

                    final title =
                        data['title']?.toString() ?? '';

                    final message =
                        data['message']?.toString() ?? '';

                    return InkWell(
                      borderRadius:
                          BorderRadius.circular(18),

                      onTap: () {
                        Navigator.pop(context);

                        _messageController.text =
                            message;

                        _messageController.selection =
                            TextSelection.fromPosition(
                          TextPosition(
                            offset: _messageController
                                .text.length,
                          ),
                        );
                      },

                      child: Container(
                        padding:
                            const EdgeInsets.all(16),

                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF8F1F4,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                        ),

                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              message,
                              style: TextStyle(
                                color:
                                    Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Future<void> _markAsSeen() async {
    try {
      await BusinessChatService.instance.markAsSeen(
        chatId: widget.chatId,
        viewerRole: widget.viewerRole,
      );
    } catch (e) {
      debugPrint('❌ MARK SEEN ERROR: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _sending = true);

    try {
      await BusinessChatService.instance.sendMessage(
        chatId: widget.chatId,
        text: text,
        senderId: user.uid,
        senderRole: widget.viewerRole,
      );

      _messageController.clear();

      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || !_scrollController.hasClients) return;

      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } catch (e) {
      debugPrint('❌ SEND MESSAGE ERROR: $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F1F4),
      appBar: AppBar(title: Text(widget.businessName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('business_chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Chat failed to load'));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final senderId = data['senderId']?.toString() ?? '';
                    final senderRole = data['senderRole']?.toString() ?? '';
                    final text = data['text']?.toString() ?? '';
                    final isMine = senderRole.isNotEmpty
                        ? senderRole == widget.viewerRole
                        : senderId == currentUserId;

                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMine
                              ? const Color(0xFFE91E63)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: isMine ? Colors.white : Colors.black87,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [

  if (widget.viewerRole == 'business') ...[
    GestureDetector(
      onTap: _openQuickReplies,

      child: Container(
        width: 52,
        height: 52,
        margin: const EdgeInsets.only(right: 10),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),

        child: const Icon(
          LucideIcons.reply,
          color: Color(0xFFE91E63),
        ),
      ),
    ),
  ],

  Expanded(
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),

      child: TextField(
        controller: _messageController,
        minLines: 1,
        maxLines: 5,

        decoration: const InputDecoration(
          hintText: 'Type a message...',
          border: InputBorder.none,

          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    ),
  ),

  const SizedBox(width: 10),

  GestureDetector(
    onTap: _sending ? null : _sendMessage,

    child: Container(
      width: 52,
      height: 52,

      decoration: const BoxDecoration(
        color: Color(0xFFE91E63),
        shape: BoxShape.circle,
      ),

      child: _sending
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(
              Icons.send,
              color: Colors.white,
            ),
    ),
  ),
],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
