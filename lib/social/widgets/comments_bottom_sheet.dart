import 'package:flutter/material.dart';

import '../models/social_post.dart';
import '../services/post_comment_service.dart';

class CommentsBottomSheet extends StatefulWidget {
  final SocialPost post;

  const CommentsBottomSheet({
    super.key,
    required this.post,
  });

  @override
  State<CommentsBottomSheet> createState() =>
      _CommentsBottomSheetState();
}

class _CommentsBottomSheetState
    extends State<CommentsBottomSheet> {
  final PostCommentService
  _commentService =
      PostCommentService();

  final TextEditingController
  _controller =
      TextEditingController();

  bool _sending = false;

  Future<void> _sendComment() async {
    final text =
        _controller.text.trim();

    if (text.isEmpty) return;

    setState(() {
      _sending = true;
    });

    try {
      await _commentService.addComment(
        postId: widget.post.id,
        text: text,
      );

      _controller.clear();
    } catch (e) {
      debugPrint(
        'COMMENT ERROR: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height:
          MediaQuery.of(context).size.height *
          0.82,

      decoration: const BoxDecoration(
        color: Colors.black,

        borderRadius:
            BorderRadius.vertical(
              top: Radius.circular(28),
            ),
      ),

      child: Column(
        children: [
          const SizedBox(height: 12),

          Container(
            width: 46,
            height: 5,

            decoration: BoxDecoration(
              color: Colors.grey[700],

              borderRadius:
                  BorderRadius.circular(20),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Comments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: StreamBuilder(
              stream: _commentService
                  .streamComments(
                    widget.post.id,
                  ),

              builder: (context, snapshot) {
                if (snapshot.hasError) {
  debugPrint(
    '🔥 COMMENTS ERROR: ${snapshot.error}',
  );

  return Center(
    child: Text(
      'Comments error: ${snapshot.error}',
      style: const TextStyle(
        color: Colors.white,
      ),
    ),
  );
}
                if (!snapshot.hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final comments =
                    snapshot.data ?? [];

                if (comments.isEmpty) {
                  return const Center(
                    child: Text(
                      'No comments yet',
                      style: TextStyle(
                        color:
                            Colors.white70,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: comments.length,

                  itemBuilder: (
                    context,
                    index,
                  ) {
                    final comment =
                        comments[index];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Colors.grey[800],

                        backgroundImage:
                            comment.userPhotoUrl !=
                                    null
                                ? NetworkImage(
                                    comment
                                        .userPhotoUrl!,
                                  )
                                : null,

                        child:
                            comment.userPhotoUrl ==
                                    null
                                ? const Icon(
                                    Icons.person,
                                    color:
                                        Colors
                                            .white,
                                  )
                                : null,
                      ),

                      title: Text(
                        comment.username,

                        style:
                            const TextStyle(
                              color:
                                  Colors.white,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                      ),

                      subtitle: Text(
                        comment.text,

                        style:
                            const TextStyle(
                              color:
                                  Colors.white70,
                            ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.all(12),

              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          _controller,

                      style:
                          const TextStyle(
                            color:
                                Colors.white,
                          ),

                      decoration:
                          InputDecoration(
                            hintText:
                                'Write a comment...',

                            hintStyle:
                                TextStyle(
                                  color:
                                      Colors
                                          .grey[500],
                                ),

                            filled: true,

                            fillColor:
                                Colors.grey[900],

                            border:
                                OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                        18,
                                      ),

                                  borderSide:
                                      BorderSide
                                          .none,
                                ),
                          ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  IconButton(
                    onPressed:
                        _sending
                        ? null
                        : _sendComment,

                    icon:
                        _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,

                            child:
                                CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                          )
                        : const Icon(
                            Icons.send,
                            color:
                                Colors.white,
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