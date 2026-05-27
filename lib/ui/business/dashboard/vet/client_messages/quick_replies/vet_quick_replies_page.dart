import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class VetQuickRepliesPage extends StatefulWidget {
  final String businessId;

  const VetQuickRepliesPage({
    super.key,
    required this.businessId,
  });

  @override
  State<VetQuickRepliesPage> createState() =>
      _VetQuickRepliesPageState();
}

class _VetQuickRepliesPageState
    extends State<VetQuickRepliesPage> {
  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController _messageController =
      TextEditingController();

  CollectionReference<Map<String, dynamic>>
      get _quickRepliesRef =>
          FirebaseFirestore.instance
              .collection('businesses')
              .doc(widget.businessId)
              .collection('quickReplies');

  Future<void> _showAddReplySheet({
    String? docId,
    String? initialTitle,
    String? initialMessage,
  }) async {
    _titleController.text = initialTitle ?? '';
    _messageController.text = initialMessage ?? '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                docId == null
                    ? 'Add Quick Reply'
                    : 'Edit Quick Reply',
                style: AppTheme.h2(),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Title',
                  filled: true,
                  fillColor: AppTheme.bg,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextField(
                controller: _messageController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Message',
                  filled: true,
                  fillColor: AppTheme.bg,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final title =
                        _titleController.text.trim();

                    final message =
                        _messageController.text.trim();

                    if (title.isEmpty ||
                        message.isEmpty) {
                      return;
                    }

                    if (docId == null) {
                      await _quickRepliesRef.add({
                        'title': title,
                        'message': message,
                        'createdAt':
                            FieldValue.serverTimestamp(),
                        'updatedAt':
                            FieldValue.serverTimestamp(),
                        'isActive': true,
                      });
                    } else {
                      await _quickRepliesRef
                          .doc(docId)
                          .update({
                        'title': title,
                        'message': message,
                        'updatedAt':
                            FieldValue.serverTimestamp(),
                      });
                    }

                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.card,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                  ),

                  child: Text(
                    docId == null
                        ? 'Save Reply'
                        : 'Update Reply',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteReply(String docId) async {
    await _quickRepliesRef.doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,

      appBar: AppBar(
        title: const Text('Quick Replies'),

        leading: IconButton(
          icon: const Icon(
            LucideIcons.arrowLeft,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.card,
        onPressed: () {
          _showAddReplySheet();
        },

        child: const Icon(
          LucideIcons.plus,
          color: Colors.white,
        ),
      ),

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _quickRepliesRef
            .orderBy('updatedAt', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.reply,
                      size: 54,
                      color: Colors.grey.shade400,
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'No quick replies yet',
                      style: AppTheme.h2(),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Create reusable responses for common client questions.',
                      textAlign: TextAlign.center,
                      style: AppTheme.caption(),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),

            itemCount: docs.length,

            separatorBuilder: (_, __) =>
                const SizedBox(height: 12),

            itemBuilder: (context, index) {
              final doc = docs[index];

              final data = doc.data();

              final title =
                  data['title'] ?? '';

              final message =
                  data['message'] ?? '';

              final isActive =
                  data['isActive'] ?? true;

              return Container(
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(20),
                  boxShadow:
                      AppTheme.cardShadow(
                    opacity: 0.06,
                  ),
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTheme.h3(
                              size: 16,
                            ),
                          ),
                        ),

                        Switch(
                          value: isActive,
                          activeColor:
                              AppTheme.accent,
                          onChanged: (value) async {
                            await _quickRepliesRef
                                .doc(doc.id)
                                .update({
                              'isActive': value,
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      message,
                      style: AppTheme.caption(),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            _showAddReplySheet(
                              docId: doc.id,
                              initialTitle: title,
                              initialMessage:
                                  message,
                            );
                          },

                          icon: const Icon(
                            LucideIcons.edit2,
                            size: 16,
                          ),

                          label: const Text(
                            'Edit',
                          ),
                        ),

                        const SizedBox(width: 10),

                        OutlinedButton.icon(
                          onPressed: () {
                            _deleteReply(doc.id);
                          },

                          style:
                              OutlinedButton.styleFrom(
                            foregroundColor:
                                Colors.red,
                          ),

                          icon: const Icon(
                            LucideIcons.trash2,
                            size: 16,
                          ),

                          label: const Text(
                            'Delete',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}