import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class BusinessChatService {
  BusinessChatService._();

  static final BusinessChatService instance = BusinessChatService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> clientChatsStream({
    required String clientUserId,
  }) {
    return _firestore
        .collection('business_chats')
        .where('clientUserId', isEqualTo: clientUserId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> businessChatsStream({
    required String businessId,
  }) {
    return _firestore
        .collection('business_chats')
        .where('businessId', isEqualTo: businessId)
        .snapshots();
  }

  Stream<int> getUnreadClientChatsCountStream({required String clientUserId}) {
    return clientChatsStream(clientUserId: clientUserId).map((snapshot) {
      return snapshot.docs.fold<int>(0, (total, doc) {
        return total + _intValue(doc.data()['unreadCountClient']);
      });
    });
  }

  Stream<int> getUnreadBusinessChatsCountStream({required String businessId}) {
    return businessChatsStream(businessId: businessId).map((snapshot) {
      return snapshot.docs.fold<int>(0, (total, doc) {
        return total + _intValue(doc.data()['unreadCountBusiness']);
      });
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> sortByLatestActivity(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
    sorted.sort((a, b) {
      final aTime =
          _dateValue(a.data()['lastMessageAt']) ??
          _dateValue(a.data()['updatedAt']) ??
          _dateValue(a.data()['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          _dateValue(b.data()['lastMessageAt']) ??
          _dateValue(b.data()['updatedAt']) ??
          _dateValue(b.data()['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  Future<String> getOrCreateBusinessChat({
    required String businessId,
    required String businessName,
    required String businessType,
    required String clientUserId,
    String? businessLogoUrl,
  }) async {
    final existing = await _firestore
        .collection('business_chats')
        .where('businessId', isEqualTo: businessId)
        .where('clientUserId', isEqualTo: clientUserId)
        .limit(1)
        .get();

    final identity = await _clientIdentity(clientUserId);

    final metadata = {
      'businessId': businessId,
      'businessName': businessName,
      'businessLogoUrl': businessLogoUrl ?? '',
      'businessType': businessType,
      'clientUserId': clientUserId,
      'clientUserName': identity.userName,
      'clientPhotoUrl': identity.photoUrl,
      'clientPetName': identity.petName,
      'clientPetPhotoUrl': identity.petPhotoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (existing.docs.isNotEmpty) {
      final chatId = existing.docs.first.id;
      await _firestore
          .collection('business_chats')
          .doc(chatId)
          .set(metadata, SetOptions(merge: true));
      return chatId;
    }

    final doc = await _firestore.collection('business_chats').add({
      ...metadata,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastSenderId': '',
      'lastSenderRole': '',
      'lastMessageAt': null,
      'unreadCountBusiness': 0,
      'unreadCountClient': 0,
    });

    debugPrint('💬 BUSINESS CHAT CREATED chatId=${doc.id}');
    return doc.id;
  }

  Future<void> markAsSeen({
    required String chatId,
    required String viewerRole,
  }) async {
    final field = viewerRole == 'business'
        ? 'unreadCountBusiness'
        : 'unreadCountClient';

    await _firestore.collection('business_chats').doc(chatId).set({
      field: 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('👀 BUSINESS UNREAD RESET chatId=$chatId role=$viewerRole');
  }

  Future<void> sendMessage({
    required String chatId,
    required String text,
    required String senderId,
    required String senderRole,
  }) async {
    final messageText = text.trim();
    if (messageText.isEmpty) return;

    final chatRef = _firestore.collection('business_chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();
    final unreadField = senderRole == 'business'
        ? 'unreadCountClient'
        : 'unreadCountBusiness';

    final batch = _firestore.batch();
    batch.set(messageRef, {
      'senderId': senderId,
      'senderRole': senderRole,
      'text': messageText,
      'type': 'text',
      'seen': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(chatRef, {
      'lastMessage': messageText,
      'lastSenderId': senderId,
      'lastSenderRole': senderRole,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      unreadField: FieldValue.increment(1),
    }, SetOptions(merge: true));
    await batch.commit();

    debugPrint(
      '💬 BUSINESS MESSAGE SENT chatId=$chatId role=$senderRole unreadField=$unreadField',
    );

    // Push notification preparation:
    // receiverRole: senderRole == business ? client : business
    // receiverUserId: clientUserId when receiverRole == client
    // receiverBusinessId: businessId when receiverRole == business
    // payload: {type: business_chat_message, chatId, senderRole, receiverRole}
  }

  Future<Map<String, String>> clientPreview(String clientUserId) async {
    final identity = await _clientIdentity(clientUserId);
    return {
      'clientUserName': identity.userName,
      'clientPhotoUrl': identity.photoUrl,
      'clientPetName': identity.petName,
      'clientPetPhotoUrl': identity.petPhotoUrl,
    };
  }

  Future<_ClientIdentity> _clientIdentity(String clientUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    final userDoc = await _firestore
        .collection('users')
        .doc(clientUserId)
        .get();
    final userData = userDoc.data() ?? {};

    final userName = _firstNonEmpty([
      userData['username'],
      userData['displayName'],
      userData['name'],
      user?.uid == clientUserId ? user?.displayName : null,
      'Pet Owner',
    ]);
    final photoUrl = _firstNonEmpty([
      userData['photoUrl'],
      userData['profileImageUrl'],
      userData['avatarUrl'],
      user?.uid == clientUserId ? user?.photoURL : null,
    ]);

    String petName = '';
    String petPhotoUrl = '';

    final dogQuery = await _firestore
        .collection('dogs')
        .where('ownerId', isEqualTo: clientUserId)
        .limit(1)
        .get();

    if (dogQuery.docs.isNotEmpty) {
      final dogData = dogQuery.docs.first.data();
      petName = _firstNonEmpty([dogData['name'], dogData['dogName']]);
      petPhotoUrl = _firstNonEmpty([
        dogData['imageUrl'],
        dogData['photoUrl'],
        dogData['profileImageUrl'],
      ]);
    }

    return _ClientIdentity(
      userName: userName,
      photoUrl: photoUrl,
      petName: petName,
      petPhotoUrl: petPhotoUrl,
    );
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static DateTime? _dateValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}

class _ClientIdentity {
  final String userName;
  final String photoUrl;
  final String petName;
  final String petPhotoUrl;

  const _ClientIdentity({
    required this.userName,
    required this.photoUrl,
    required this.petName,
    required this.petPhotoUrl,
  });
}
