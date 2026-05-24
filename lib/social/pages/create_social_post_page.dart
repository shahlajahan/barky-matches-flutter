import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../models/social_post.dart';
import '../services/social_post_service.dart';

class CreateSocialPostPage extends StatefulWidget {
  const CreateSocialPostPage({super.key});

  @override
  State<CreateSocialPostPage> createState() => _CreateSocialPostPageState();
}

class _CreateSocialPostPageState extends State<CreateSocialPostPage> {
  final TextEditingController _captionController = TextEditingController();
  final SocialPostService _postService = SocialPostService();
  final PageController _previewController = PageController();
  final List<_SelectedSocialMedia> _selectedMedia = [];

  bool _isLoading = false;
  double _uploadProgress = 0;
  int _previewIndex = 0;

  Future<void> _pickMedia() async {
    final result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 10,
        requestType: RequestType.common,
        selectedAssets: _selectedMedia.map((item) => item.asset).toList(),
        gridCount: 4,
        themeColor: Colors.black,
        textDelegate: const EnglishAssetPickerTextDelegate(),
      ),
    );

    if (result == null) return;

    final nextItems = <_SelectedSocialMedia>[];

    for (final asset in result) {
      final thumbnailBytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(900, 900),
        quality: 82,
      );

      nextItems.add(
        _SelectedSocialMedia(
          asset: asset,
          type: asset.type == AssetType.video ? 'video' : 'image',
          thumbnailBytes: thumbnailBytes,
        ),
      );
    }

    if (nextItems.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _selectedMedia
        ..clear()
        ..addAll(nextItems);
      if (_previewIndex >= _selectedMedia.length) {
        _previewIndex = (_selectedMedia.length - 1).clamp(0, 999);
      }
    });
  }

  Future<List<SocialPostMedia>> _uploadMedia({
    required String uid,
    required String postId,
  }) async {
    final media = <SocialPostMedia>[];

    for (var i = 0; i < _selectedMedia.length; i++) {
      final item = _selectedMedia[i];
      final file = await item.asset.file;
      if (file == null) {
        throw Exception('Unable to read selected media');
      }

      final ext = _extensionForFile(file, item);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.$ext';
      final ref = FirebaseStorage.instance.ref().child(
        'social_posts/$uid/$postId/$fileName',
      );

      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: _contentTypeFor(ext, item.type)),
      );

      uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted || snapshot.totalBytes <= 0) return;
        setState(() {
          _uploadProgress =
              ((i + snapshot.bytesTransferred / snapshot.totalBytes) /
                      _selectedMedia.length)
                  .clamp(0.0, 1.0);
        });
      });

      await uploadTask;
      final url = await ref.getDownloadURL();
      String? thumbnailUrl;

      if (item.type == 'video' && item.thumbnailBytes != null) {
        final thumbRef = FirebaseStorage.instance.ref().child(
          'social_posts/$uid/$postId/thumbnails/${fileName}_thumb.jpg',
        );

        await thumbRef.putData(
          item.thumbnailBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        thumbnailUrl = await thumbRef.getDownloadURL();
      }

      media.add(
        SocialPostMedia(
          url: url,
          type: item.type,
          thumbnailUrl: item.type == 'video' ? thumbnailUrl : url,
        ),
      );
    }

    return media;
  }

  String _extensionForFile(File file, _SelectedSocialMedia item) {
    final path = file.path;
    final dot = path.lastIndexOf('.');
    if (dot != -1 && dot < path.length - 1) {
      return path.substring(dot + 1).toLowerCase();
    }

    return item.isVideo ? 'mp4' : 'jpg';
  }

  String _contentTypeFor(String ext, String type) {
    if (type == 'video') {
      switch (ext) {
        case 'mov':
          return 'video/quicktime';
        case 'm4v':
          return 'video/x-m4v';
        case 'webm':
          return 'video/webm';
        default:
          return 'video/mp4';
      }
    }

    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _createPost() async {
    if (_isLoading) return;

    if (_selectedMedia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one photo/video')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final postId = FirebaseFirestore.instance
          .collection('social_posts')
          .doc()
          .id;

      final media = await _uploadMedia(uid: currentUser.uid, postId: postId);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data() ?? {};

      final username =
          userData['username'] ??
          userData['name'] ??
          userData['displayName'] ??
          'Pet User';
      final userPhoto =
          userData['photoUrl'] ??
          userData['profileImageUrl'] ??
          userData['profilePhoto'] ??
          currentUser.photoURL;
      final hasVideo = media.any((item) => item.isVideo);
      final hasImage = media.any((item) => !item.isVideo);

      final post = SocialPost(
        id: postId,
        userId: currentUser.uid,
        media: media,
        mediaUrls: media.map((item) => item.url).toList(),
        mediaType: hasVideo && hasImage
            ? 'mixed'
            : hasVideo
            ? 'video'
            : 'image',
        caption: _captionController.text.trim(),
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        shareCount: 0,
        saveCount: 0,
        viewCount: 0,
        visibility: 'public',
        moderationStatus: 'active',
        isHidden: false,
        reportCount: 0,
        tags: const [],
        username: username.toString(),
        userPhotoUrl: userPhoto?.toString(),
      );

      await _postService.createPost(post);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('CreateSocialPostPage error: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating post: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
      if (_previewIndex >= _selectedMedia.length) {
        _previewIndex = (_selectedMedia.length - 1).clamp(0, 999);
      }
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canShare = !_isLoading && _selectedMedia.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: canShare ? _createPost : null,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Share',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: FocusScope.of(context).unfocus,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ComposerPreview(
                media: _selectedMedia,
                controller: _previewController,
                previewIndex: _previewIndex,
                onPickMedia: _pickMedia,
                onPageChanged: (value) => setState(() => _previewIndex = value),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _pickMedia,
                      icon: const Icon(LucideIcons.image),
                      label: const Text('Add photos/videos'),
                    ),
                  ),
                ],
              ),
              if (_selectedMedia.length > 1) ...[
                const SizedBox(height: 12),
                _MediaDots(count: _selectedMedia.length, index: _previewIndex),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _captionController,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Write something...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_selectedMedia.isNotEmpty)
                _SelectedMediaStrip(
                  media: _selectedMedia,
                  onRemove: _isLoading ? null : _removeMedia,
                ),
              if (_isLoading) ...[
                const SizedBox(height: 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: _uploadProgress),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedSocialMedia {
  final AssetEntity asset;
  final String type;
  final Uint8List? thumbnailBytes;

  const _SelectedSocialMedia({
    required this.asset,
    required this.type,
    this.thumbnailBytes,
  });

  bool get isVideo => type == 'video';
}

class _ComposerPreview extends StatelessWidget {
  final List<_SelectedSocialMedia> media;
  final PageController controller;
  final int previewIndex;
  final VoidCallback onPickMedia;
  final ValueChanged<int> onPageChanged;

  const _ComposerPreview({
    required this.media,
    required this.controller,
    required this.previewIndex,
    required this.onPickMedia,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: media.isEmpty ? onPickMedia : null,
      child: Container(
        height: 360,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: media.isEmpty
            ? const Center(
                child: Icon(
                  LucideIcons.imagePlus,
                  color: Colors.white,
                  size: 58,
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: controller,
                    itemCount: media.length,
                    onPageChanged: onPageChanged,
                    itemBuilder: (context, index) {
                      return _SelectedMediaPreview(item: media[index]);
                    },
                  ),
                  if (media.length > 1)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: _MediaCounter(
                        index: previewIndex + 1,
                        count: media.length,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SelectedMediaPreview extends StatelessWidget {
  final _SelectedSocialMedia item;

  const _SelectedMediaPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.thumbnailBytes != null)
          Image.memory(item.thumbnailBytes!, fit: BoxFit.cover)
        else
          AssetEntityImage(item.asset, isOriginal: false, fit: BoxFit.cover),
        if (item.isVideo) ...[
          Container(color: Colors.black.withValues(alpha: 0.20)),
          const Center(
            child: Icon(LucideIcons.playCircle, color: Colors.white, size: 70),
          ),
        ],
      ],
    );
  }
}

class _SelectedMediaStrip extends StatelessWidget {
  final List<_SelectedSocialMedia> media;
  final ValueChanged<int>? onRemove;

  const _SelectedMediaStrip({required this.media, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = media[index];

          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: item.thumbnailBytes != null
                      ? Image.memory(item.thumbnailBytes!, fit: BoxFit.cover)
                      : AssetEntityImage(
                          item.asset,
                          isOriginal: false,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              if (item.isVideo)
                const Positioned.fill(
                  child: Icon(
                    LucideIcons.playCircle,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: onRemove == null ? null : () => onRemove!(index),
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.x,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MediaDots extends StatelessWidget {
  final int count;
  final int index;

  const _MediaDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: active ? 8 : 6,
          height: active ? 8 : 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white38,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _MediaCounter extends StatelessWidget {
  final int index;
  final int count;

  const _MediaCounter({required this.index, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$index / $count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
