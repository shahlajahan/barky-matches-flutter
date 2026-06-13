import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  /// =========================================================
  /// CREATE OR GET CHAT
  /// =========================================================
  Future<String> getOrCreateChat({
    required String currentUserId,
    required String otherUserId,

    required String currentUserName,
    required String otherUserName,

    String? currentUserPhoto,
    String? otherUserPhoto,
  }) async {
    debugPrint("💬 getOrCreateChat CALLED");

    if (currentUserId.isEmpty || otherUserId.isEmpty) {
      throw Exception('Invalid user ids');
    }

    if (currentUserId == otherUserId) {
      throw Exception('Cannot chat with yourself');
    }

    final ids = [currentUserId, otherUserId]..sort();

    final chatId = ids.join('_');

    final chatRef = _chats.doc(chatId);

final chatSnap = await chatRef.get();

debugPrint(
  "🐾 CHAT DOC = ${chatSnap.data()}",
);

if (chatSnap.exists) {

  final data = chatSnap.data() ?? {};

  final participantNames =
      Map<String, dynamic>.from(
    data['participantNames'] ?? {},
  );

  final names = {
    currentUserId: currentUserName,
    otherUserId: otherUserName,
  };

  debugPrint(
    "💬 EXISTING participantNames=$participantNames",
  );

  debugPrint(
    "💬 EXPECTED names=$names",
  );

  if (participantNames.isEmpty ||
      !participantNames.containsKey(currentUserId) ||
      !participantNames.containsKey(otherUserId)) {

    debugPrint(
      "💬 REPAIR RUNNING",
    );

    await chatRef.update({
      'participantNames': names,
    });

    debugPrint(
      "💬 REPAIR DONE = $names",
    );
  }

} else {

  final now = FieldValue.serverTimestamp();

  debugPrint("💬 CREATING CHAT → $chatId");

  debugPrint("💬 participants → $ids");

  debugPrint("💬 currentUserId → $currentUserId");

  debugPrint("💬 otherUserId → $otherUserId");

  try {

    await chatRef.set({
      'participants': ids,

      'participantMap': {
        currentUserId: true,
        otherUserId: true,
      },

      'participantNames': {
        currentUserId: currentUserName,
        otherUserId: otherUserName,
      },

      'participantPhotos': {
        currentUserId: currentUserPhoto,
        otherUserId: otherUserPhoto,
      },

      'lastMessage': '',
      'lastMessageAt': now,
      'lastSenderId': '',

      'unreadCount': {
        currentUserId: 0,
        otherUserId: 0,
      },

      'createdAt': now,
      'updatedAt': now,
    });

    final verify = await chatRef.get();

    if (!verify.exists) {
      throw Exception('Chat creation failed');
    }

    debugPrint("✅ CHAT VERIFIED");
    debugPrint("✅ CHAT CREATED SUCCESSFULLY");

  } catch (e, stack) {

    debugPrint("❌ CHAT CREATE ERROR → $e");
    debugPrint("$stack");

    rethrow;
  }
}

    return chatId;
  }

  /// =========================================================
  /// SEND MESSAGE
  /// =========================================================
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final trimmed = text.trim();

    if (trimmed.isEmpty) return;

    final chatRef = _chats.doc(chatId);

    final chatSnap = await chatRef.get();

    if (!chatSnap.exists) {
      throw Exception('Chat does not exist');
    }

    final chatData = chatSnap.data()!;

    final participants = List<String>.from(chatData['participants'] ?? []);

    if (!participants.contains(senderId)) {
      throw Exception('Sender is not part of this chat');
    }

    final otherUserId = participants.firstWhere((id) => id != senderId);
    final participantNames = Map<String, dynamic>.from(
      chatData['participantNames'] ?? {},
    );
    final senderName = participantNames[senderId]?.toString() ?? '';

    final messageRef = chatRef.collection('messages').doc();

    final now = FieldValue.serverTimestamp();

    final batch = _firestore.batch();

    /// MESSAGE
    batch.set(messageRef, {
      'messageId': messageRef.id,
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': otherUserId,
      'senderName': senderName,
      'text': trimmed,
      'type': 'text',

      'createdAt': now,

      'seenBy': {senderId: true},
    });

    /// CHAT UPDATE
    batch.update(chatRef, {
      'lastMessage': trimmed,
      'lastMessageAt': now,
      'lastSenderId': senderId,
      'updatedAt': now,

      'unreadCount.$otherUserId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// =========================================================
  /// MARK CHAT AS SEEN
  /// =========================================================
  Future<void> markChatAsSeen({
    required String chatId,
    required String userId,
  }) async {
    final chatRef = _chats.doc(chatId);

    final unreadMessages = await chatRef
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .limit(100)
        .get();

    final batch = _firestore.batch();

    batch.update(chatRef, {'unreadCount.$userId': 0});

    for (final doc in unreadMessages.docs) {
      final seenBy = Map<String, dynamic>.from(doc.data()['seenBy'] ?? {});
      if (seenBy[userId] == true) continue;
      batch.update(doc.reference, {'seenBy.$userId': true});
    }

    await batch.commit();
  }

  /// =========================================================
  /// MARK MESSAGE AS SEEN
  /// =========================================================
  Future<void> markMessageAsSeen({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    final messageRef = _chats.doc(chatId).collection('messages').doc(messageId);

    await messageRef.update({'seenBy.$userId': true});
  }

  /// =========================================================
  /// DELETE CHAT
  /// =========================================================
  Future<void> deleteChat({required String chatId}) async {
    final messages = await _chats.doc(chatId).collection('messages').get();

    final batch = _firestore.batch();

    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_chats.doc(chatId));

    await batch.commit();
  }

  /// =========================================================
  /// STREAM CHAT LIST
  /// =========================================================
  Stream<QuerySnapshot<Map<String, dynamic>>> getChatsStream({
    required String userId,
  }) {
    return _chats
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  Stream<int> getUnreadChatsCountStream({required String userId}) {
    return _chats.where('participants', arrayContains: userId).snapshots().map((
      snapshot,
    ) {
      var total = 0;

      for (final doc in snapshot.docs) {
        final unreadMap = Map<String, dynamic>.from(
          doc.data()['unreadCount'] ?? {},
        );
        final rawUnread = unreadMap[userId];
        total += rawUnread is int
            ? rawUnread
            : int.tryParse(rawUnread?.toString() ?? '0') ?? 0;
      }

      return total;
    });
  }

  /// =========================================================
  /// STREAM MESSAGES
  /// =========================================================
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessagesStream({
    required String chatId,
  }) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// =========================================================
  /// GET CURRENT UID
  /// =========================================================
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;
}
