import 'package:cloud_firestore/cloud_firestore.dart';

class PostComment {
  final String id;
  final String postId;
  final String userId;

  final String username;
  final String? userPhotoUrl;

  final String text;

  final DateTime createdAt;

  /// active / hidden / removed - soft moderation only; a "removed" comment
  /// is hidden from readers but never hard-deleted, mirroring SocialPost.
  final String moderationStatus;
  final bool isHidden;
  final DateTime? moderatedAt;
  final String? moderatedBy;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    this.userPhotoUrl,
    required this.text,
    required this.createdAt,
    this.moderationStatus = 'active',
    this.isHidden = false,
    this.moderatedAt,
    this.moderatedBy,
  });

  factory PostComment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return PostComment(
      id: doc.id,

      postId: data['postId'] ?? '',

      userId: data['userId'] ?? '',

      username: data['username'] ?? 'User',

      userPhotoUrl: data['userPhotoUrl'],

      text: data['text'] ?? '',

      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),

      moderationStatus: data['moderationStatus'] ?? 'active',

      isHidden: data['isHidden'] ?? false,

      moderatedAt: (data['moderatedAt'] as Timestamp?)?.toDate(),

      moderatedBy: data['moderatedBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'userId': userId,
      'username': username,
      'userPhotoUrl': userPhotoUrl,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'moderationStatus': moderationStatus,
      'isHidden': isHidden,
    };
  }
}
