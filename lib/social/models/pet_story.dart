import 'package:cloud_firestore/cloud_firestore.dart';

class PetStory {
  final String id;
  final String userId;
  final String username;
  final String? userAvatarUrl;
  final String mediaUrl;
  final String mediaType;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewCount;
  final int likeCount;
  final int replyCount;
  final int shareCount;

  const PetStory({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
    required this.mediaUrl,
    this.mediaType = 'image',
    required this.createdAt,
    required this.expiresAt,
    this.viewCount = 0,
    this.likeCount = 0,
    this.replyCount = 0,
    this.shareCount = 0,
  });

  factory PetStory.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime readDate(Object? value, DateTime fallback) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        return DateTime.tryParse(value) ?? fallback;
      }
      return fallback;
    }

    int readInt(Object? value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return PetStory(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      username: (data['username'] ?? 'Pet User').toString(),
      userAvatarUrl: data['userAvatarUrl']?.toString(),
      mediaUrl: (data['mediaUrl'] ?? '').toString(),
      mediaType: (data['mediaType'] ?? 'image').toString(),
      createdAt: readDate(data['createdAt'], DateTime.now()),
      expiresAt: readDate(
        data['expiresAt'],
        DateTime.now().add(const Duration(hours: 24)),
      ),
      viewCount: readInt(data['viewCount']),
      likeCount: readInt(data['likeCount']),
      replyCount: readInt(data['replyCount']),
      shareCount: readInt(data['shareCount']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewCount': viewCount,
      'likeCount': likeCount,
      'replyCount': replyCount,
      'shareCount': shareCount,
    };
  }
}
