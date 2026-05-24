import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/pet_story.dart';

class PetStoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _stories =>
      _firestore.collection('stories');

  Stream<List<PetStory>> streamActiveStories() {
    final now = Timestamp.fromDate(DateTime.now());

    return _stories
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt')
        .snapshots()
        .map((snapshot) {
          final stories = snapshot.docs
              .map((doc) => PetStory.fromFirestore(doc))
              .where((story) => story.mediaUrl.isNotEmpty)
              .toList();
          stories.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          debugPrint('📚 Petplore active stories count: ${stories.length}');

          return stories;
        });
  }

  Future<void> createStory({
    required File file,
    required String mediaType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Login required to create story');
    }

    final storyRef = _stories.doc();
    final storyId = storyRef.id;
    final safeMediaType = mediaType.trim().isEmpty ? 'image' : mediaType.trim();

    debugPrint('📤 Petplore story upload start: storyId=$storyId');

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final username = _firstNonEmpty(
        userData['username'],
        userData['name'],
        userData['displayName'],
        'Pet User',
      );
      final avatar = _firstNonEmptyOrNull(
        userData['photoUrl'],
        userData['profileImageUrl'],
        user.photoURL,
      );

      final ref = _storage.ref().child('stories/${user.uid}/$storyId.jpg');

      final metadata = SettableMetadata(contentType: 'image/jpeg');

      debugPrint('📦 STORY FILE SIZE = ${await file.length()}');

      await ref.putFile(file, metadata);

      final downloadUrl = await ref.getDownloadURL();
      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      await storyRef.set({
        'userId': user.uid,
        'username': username,
        'userAvatarUrl': avatar,
        'mediaUrl': downloadUrl,
        'mediaType': safeMediaType,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'viewCount': 0,
        'likeCount': 0,
        'replyCount': 0,
        'shareCount': 0,
      });

      debugPrint('✅ Petplore story upload success: storyId=$storyId');
    } catch (e) {
      debugPrint('❌ Petplore story upload error: $e');
      rethrow;
    }
  }

  Future<void> markViewed(String storyId) async {
    final user = _auth.currentUser;
    if (user == null || storyId.trim().isEmpty) return;

    final storyRef = _stories.doc(storyId);
    final viewRef = storyRef.collection('views').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final viewSnap = await transaction.get(viewRef);
      if (viewSnap.exists) return;

      transaction.set(viewRef, {
        'userId': user.uid,
        'viewedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(storyRef, {'viewCount': FieldValue.increment(1)});
    });

    debugPrint('👁️ Petplore story view marked: storyId=$storyId');
  }

  Stream<bool> likeStream(String storyId) {
    final user = _auth.currentUser;
    if (user == null || storyId.trim().isEmpty) return Stream.value(false);

    return _firestore
        .collection('story_likes')
        .doc('${storyId}_${user.uid}')
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Future<void> toggleLike(String storyId) async {
    final user = _auth.currentUser;
    if (user == null || storyId.trim().isEmpty) {
      throw StateError('Login required to like story');
    }

    final likeRef = _firestore
        .collection('story_likes')
        .doc('${storyId}_${user.uid}');
    final storyRef = _stories.doc(storyId);
    final likeSnap = await likeRef.get();
    final batch = _firestore.batch();

    if (likeSnap.exists) {
      batch.delete(likeRef);
      batch.update(storyRef, {'likeCount': FieldValue.increment(-1)});
    } else {
      batch.set(likeRef, {
        'storyId': storyId,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(storyRef, {'likeCount': FieldValue.increment(1)});
    }

    await batch.commit();
  }

  Future<void> sendReply({
    required PetStory story,
    required String text,
  }) async {
    final user = _auth.currentUser;
    final message = text.trim();

    if (user == null) {
      throw StateError('Login required to reply to story');
    }
    if (story.id.trim().isEmpty || story.userId.trim().isEmpty) return;
    if (message.isEmpty) return;

    final currentUser = user;
    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final ownerDoc = await _firestore
        .collection('users')
        .doc(story.userId)
        .get();
    final userData = userDoc.data() ?? {};
    final ownerData = ownerDoc.data() ?? {};
    final senderUsername = _firstNonEmpty(
      userData['username'],
      userData['name'],
      userData['displayName'],
      'Pet User',
    );
    final ownerUsername = _firstNonEmpty(
      ownerData['username'],
      ownerData['name'],
      ownerData['displayName'],
      story.username,
    );
    final senderPhoto = _firstNonEmptyOrNull(
      userData['photoUrl'],
      userData['profileImageUrl'],
      currentUser.photoURL,
    );
    final ownerPhoto = _firstNonEmptyOrNull(
      ownerData['photoUrl'],
      ownerData['profileImageUrl'],
      story.userAvatarUrl,
    );
    final replyRef = _firestore.collection('story_replies').doc();
    final notificationRef = _firestore.collection('notifications').doc();
    final chatsQuery = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    DocumentReference<Map<String, dynamic>>? chatRef;

    for (final doc in chatsQuery.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(story.userId)) {
        chatRef = doc.reference;
        debugPrint('💬 CHAT FOUND: ${doc.id}');
        break;
      }
    }

    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    if (chatRef == null) {
      chatRef = _firestore.collection('chats').doc();
      batch.set(chatRef, {
        'participants': [currentUser.uid, story.userId],
        'participantMap': {currentUser.uid: true, story.userId: true},
        'participantNames': {
          currentUser.uid: senderUsername,
          story.userId: ownerUsername,
        },
        'participantPhotos': {
          currentUser.uid: senderPhoto,
          story.userId: ownerPhoto,
        },
        'createdAt': now,
        'updatedAt': now,
        'lastMessage': message,
        'lastMessageType': 'story_reply',
        'lastMessageAt': now,
        'lastSenderId': currentUser.uid,
        'unreadCount': {currentUser.uid: 0, story.userId: 1},
      });
      debugPrint('🆕 CHAT CREATED: ${chatRef.id}');
    } else {
      batch.update(chatRef, {
        'lastMessage': message,
        'lastMessageType': 'story_reply',
        'lastMessageAt': now,
        'lastSenderId': currentUser.uid,
        'updatedAt': now,
        'unreadCount.${story.userId}': FieldValue.increment(1),
      });
    }

    final messageRef = chatRef.collection('messages').doc();

    batch.set(replyRef, {
      'storyId': story.id,
      'senderId': currentUser.uid,
      'receiverId': story.userId,
      'recipientUserId': story.userId,
      'senderUsername': senderUsername,
      'message': message,
      'createdAt': now,
    });
    batch.update(_stories.doc(story.id), {
      'replyCount': FieldValue.increment(1),
    });
    batch.set(notificationRef, {
      'userId': story.userId,
      'recipientUserId': story.userId,
      'type': 'story_reply',
      'storyId': story.id,
      'senderId': currentUser.uid,
      'senderUsername': senderUsername,
      'title': '$senderUsername replied to your story',
      'body': message,
      'message': message,
      'timestamp': now,
      'createdAt': now,
      'isRead': false,
    });
    batch.set(messageRef, {
      'messageId': messageRef.id,
      'chatId': chatRef.id,
      'senderId': currentUser.uid,
      'receiverId': story.userId,
      'senderName': senderUsername,
      'text': message,
      'type': 'story_reply',
      'storyId': story.id,
      'createdAt': now,
      'isRead': false,
      'seenBy': {currentUser.uid: true},
    });

    await batch.commit();

    debugPrint('📨 STORY DM MESSAGE CREATED');
    debugPrint('💬 STORY REPLY SENT: ${story.id}');
  }

  Future<void> incrementShareCount(String storyId) async {
    if (storyId.trim().isEmpty) return;

    await _stories.doc(storyId).update({'shareCount': FieldValue.increment(1)});
  }

  String _firstNonEmpty(
    Object? first,
    Object? second,
    Object? third,
    String fallback,
  ) {
    return _firstNonEmptyOrNull(first, second, third) ?? fallback;
  }

  String? _firstNonEmptyOrNull(Object? first, [Object? second, Object? third]) {
    for (final value in [first, second, third]) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}
