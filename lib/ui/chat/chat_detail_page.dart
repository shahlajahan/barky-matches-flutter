import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:barky_matches_fixed/services/chat_service.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

class ChatDetailPage extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;

  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;

  String get currentUserId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markChatSeen();
    });
  }

  Future<void> _markChatSeen() async {
    try {
      await ChatService.instance.markChatAsSeen(
        chatId: widget.chatId,
        userId: currentUserId,
      );
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      await ChatService.instance
          .sendMessage(
            chatId: widget.chatId,
            senderId: currentUserId,
            text: text,
          )
          .timeout(const Duration(seconds: 12));

      _messageController.clear();

      await Future.delayed(const Duration(milliseconds: 100));

      _scrollToBottom();
    } on TimeoutException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sending timed out')),
      );
    } catch (e) {
      if (!mounted) return;

      debugPrint('❌ SEND MESSAGE ERROR → $e');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Message failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _buildMessageBubble({required Map<String, dynamic> data}) {
    final senderId = data['senderId'] ?? '';
    final text = data['text'] ?? '';

    final isMine = senderId == currentUserId;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF9E1B4F) : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMine ? Colors.white : Colors.black87,
            fontSize: 15,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    final chatDocFuture = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .get();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: chatDocFuture,

      builder: (context, chatSnapshot) {
        if (chatSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!chatSnapshot.hasData || !chatSnapshot.data!.exists) {
          return const Center(child: Text('Chat is creating...'));
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ChatService.instance.getMessagesStream(chatId: widget.chatId),

          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              debugPrint("❌ CHAT STREAM ERROR → ${snapshot.error}");

              return Center(
                child: Text('Chat failed to load', style: AppTheme.body()),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Text('Start chatting 👋', style: AppTheme.body()),
              );
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
              _markChatSeen();
            });

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              itemCount: docs.length,
              itemBuilder: (_, index) {
                final data = docs[index].data();

                return _buildMessageBubble(data: data);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Write message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF9E1B4F),
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFC),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF9E1B4F),
        foregroundColor: Colors.white,
        title: Text(
          widget.otherUserName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      body: Column(
        children: [
          Expanded(child: _buildMessages()),

          _buildInputBar(),
        ],
      ),
    );
  }
}
