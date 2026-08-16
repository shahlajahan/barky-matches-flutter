import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/social_post.dart';
import '../services/post_comment_service.dart';
import 'petplore_avatar.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/models/report_model.dart';
import 'package:barky_matches_fixed/ui/common/report_dialog.dart';

class CommentsBottomSheet extends StatefulWidget {
  final SocialPost post;
  final PostCommentService? commentService;

  /// Test-only override for the comment-author avatar's image cache
  /// manager (see PetploreAvatar). Never set in production.
  final BaseCacheManager? avatarCacheManager;

  const CommentsBottomSheet({
    super.key,
    required this.post,
    this.commentService,
    this.avatarCacheManager,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  late final PostCommentService _commentService;

  final TextEditingController _controller = TextEditingController();

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _commentService = widget.commentService ?? PostCommentService();
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();

    if (text.isEmpty) return;
    if (text.length > PostCommentService.kMaxCommentLength) return;
    if (_sending) return;

    setState(() {
      _sending = true;
    });

    try {
      await _commentService.addComment(postId: widget.post.id, text: text);

      // Only clear/dismiss on confirmed success; a failed write leaves the
      // draft intact so the user doesn't lose what they typed.
      _controller.clear();
    } catch (e) {
      debugPrint('COMMENT ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.somethingWentWrong),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.82,
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),

          child: Column(
            children: [
              const SizedBox(height: 12),

              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(20),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                AppLocalizations.of(context)!.commentsTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: StreamBuilder(
                  stream: _commentService.streamComments(widget.post.id),

                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      debugPrint('🔥 COMMENTS ERROR: ${snapshot.error}');

                      return Center(
                        child: Text(
                          AppLocalizations.of(
                            context,
                          )!.commentsError('${snapshot.error}'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final comments = snapshot.data ?? [];

                    if (comments.isEmpty) {
                      return Center(
                        child: Text(
                          AppLocalizations.of(context)!.noCommentsYet,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: comments.length,

                      itemBuilder: (context, index) {
                        final comment = comments[index];

                        return ListTile(
                          leading: PetploreAvatar(
                            imageUrl: comment.userPhotoUrl,
                            radius: 20,
                            backgroundColor: Colors.grey.shade800,
                            icon: Icons.person,
                            iconColor: Colors.white,
                            cacheManager: widget.avatarCacheManager,
                            semanticLabel: '${comment.username} avatar',
                          ),

                          title: Text(
                            comment.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          subtitle: Text(
                            comment.text,
                            style: const TextStyle(color: Colors.white70),
                          ),

                          trailing:
                              FirebaseAuth.instance.currentUser?.uid ==
                                  comment.userId
                              ? null
                              : PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.white54,
                                  ),
                                  onSelected: (value) {
                                    if (value == 'report') {
                                      showReportSheet(
                                        context,
                                        targetType: ReportTargetType.comment,
                                        targetId: comment.id,
                                        targetOwnerId: comment.userId,
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'report',
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.reportMenuComment,
                                      ),
                                    ),
                                  ],
                                ),
                        );
                      },
                    );
                  },
                ),
              ),

              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),

                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,

                          minLines: 1,
                          maxLines: 4,

                          textInputAction: TextInputAction.newline,

                          style: const TextStyle(color: Colors.white),

                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(
                              context,
                            )!.writeCommentHint,

                            hintStyle: TextStyle(color: Colors.grey[500]),

                            filled: true,

                            fillColor: Colors.grey[900],

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),

                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      IconButton(
                        onPressed: _sending ? null : _sendComment,

                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
