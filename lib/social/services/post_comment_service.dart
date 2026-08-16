import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post_comment.dart';

class PostCommentService {
  /// Must match `addSocialCommentCore`'s `SOCIAL_COMMENT_MAX_LENGTH` bound
  /// (functions/src/social/addSocialCommentCore.js) so the client rejects
  /// oversized input with immediate UI feedback instead of a round-trip
  /// callable error.
  static const int kMaxCommentLength = 2000;

  PostCommentService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    User? Function()? currentUser,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3'),
       _currentUser = currentUser ?? (() => FirebaseAuth.instance.currentUser);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Resolves the acting user. Defaults to the real
  /// `FirebaseAuth.instance.currentUser`; tests inject a fixed value since
  /// `FirebaseAuth.instance` cannot be faked without a real Firebase
  /// app/plugin.
  final User? Function() _currentUser;

  CollectionReference<Map<String, dynamic>> get _comments =>
      _firestore.collection('post_comments');

  Stream<List<PostComment>> streamComments(String postId) {
    // Filtered client-side rather than with a `.where('isHidden', ...)`
    // clause: Firestore equality filters don't match documents missing the
    // field at all, which would hide every comment created before this
    // field existed. PostComment.fromFirestore already defaults isHidden
    // to false for those legacy docs, so filtering here handles both
    // correctly.
    return _comments
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PostComment.fromFirestore(doc))
              .where((comment) => !comment.isHidden)
              .toList(),
        );
  }

  /// Creates a comment and increments the post's commentCount atomically
  /// via the addSocialComment trusted callable. Comments use
  /// auto-generated IDs, so — unlike likes, which use a deterministic
  /// "{postId}_{uid}" document — firestore.rules has no way to prove a
  /// direct client write is genuinely paired with its counter increment.
  /// The callable performs both writes in a single server-side
  /// transaction via the Admin SDK instead; see
  /// functions/src/social/addSocialCommentCore.js.
  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final user = _currentUser();

    if (user == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Comment text must not be empty.');
    }
    if (trimmed.length > kMaxCommentLength) {
      throw ArgumentError(
        'Comment text exceeds $kMaxCommentLength characters.',
      );
    }

    // A locally generated (no network round trip) Firestore auto-ID used
    // as an idempotency key: if this exact call is retried after an
    // ambiguous network response, the callable finds the comment it
    // already created via this id instead of creating a duplicate and
    // double-incrementing commentCount.
    final requestId = _comments.doc().id;

    await _functions.httpsCallable('addSocialComment').call({
      'postId': postId,
      'text': trimmed,
      'requestId': requestId,
    });
  }
}
