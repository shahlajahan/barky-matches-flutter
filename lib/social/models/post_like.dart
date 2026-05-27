import 'package:cloud_firestore/cloud_firestore.dart';

class PostLike {
  final String userId;
  final String postId;
  final DateTime createdAt;

  const PostLike({
    required this.userId,
    required this.postId,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'postId': postId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PostLike.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return PostLike(
      userId: data['userId'] ?? '',
      postId: data['postId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
