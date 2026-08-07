import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:barky_matches_fixed/ui/common/platform_path_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import '../models/social_post.dart';
import '../services/social_post_service.dart';

const Set<String> _allowedSocialMediaExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'heic',
  'mp4',
  'mov',
  'webm',
};

String socialMediaExtensionForFile(XFile file, {required bool isVideo}) {
  final fromName = _socialMediaExtensionFromName(file.name);
  if (fromName != null) return fromName;

  final fromMimeType = _socialMediaExtensionFromMimeType(file.mimeType);
  if (fromMimeType != null) return fromMimeType;

  return isVideo ? 'mp4' : 'jpg';
}

String? _socialMediaExtensionFromName(String name) {
  final normalizedName = name.trim();
  if (normalizedName.isEmpty ||
      normalizedName.contains('/') ||
      normalizedName.contains(r'\') ||
      normalizedName.contains('?') ||
      normalizedName.contains('#')) {
    return null;
  }

  final dot = normalizedName.lastIndexOf('.');
  if (dot <= 0 || dot == normalizedName.length - 1) return null;
  return _normalizeSocialMediaExtension(normalizedName.substring(dot + 1));
}

String? _socialMediaExtensionFromMimeType(String? mimeType) {
  final normalizedMimeType = mimeType?.trim().toLowerCase();
  if (normalizedMimeType == null || normalizedMimeType.isEmpty) return null;

  switch (normalizedMimeType) {
    case 'image/jpg':
    case 'image/jpeg':
      return 'jpg';
    case 'video/quicktime':
      return 'mov';
  }

  final slash = normalizedMimeType.lastIndexOf('/');
  if (slash == -1 || slash == normalizedMimeType.length - 1) return null;
  return _normalizeSocialMediaExtension(
    normalizedMimeType.substring(slash + 1),
  );
}

String? _normalizeSocialMediaExtension(String extension) {
  final normalized = extension.trim().toLowerCase();
  if (normalized.contains('.') ||
      normalized.contains('/') ||
      normalized.contains(r'\') ||
      normalized.contains('?') ||
      normalized.contains('#')) {
    return null;
  }

  final mapped = switch (normalized) {
    'heif' => 'heic',
    'm4v' => 'mp4',
    _ => normalized,
  };
  return _allowedSocialMediaExtensions.contains(mapped) ? mapped : null;
}

String _sanitizeSocialMediaFileName(String fileName) {
  return fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}

class CreateSocialPostPage extends StatefulWidget {
  const CreateSocialPostPage({super.key});

  @override
  State<CreateSocialPostPage> createState() => _CreateSocialPostPageState();
}

class _CreateSocialPostPageState extends State<CreateSocialPostPage> {
  final TextEditingController _captionController = TextEditingController();
  final SocialPostService _postService = SocialPostService();
  final PageController _previewController = PageController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<_SelectedSocialMedia> _selectedMedia = [];

  bool _isLoading = false;
  double _uploadProgress = 0;
  int _previewIndex = 0;

  void _pickMedia() {
    debugPrint('OPEN SHEET');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.grey[950],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        debugPrint('BUILD SHEET');

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MediaPickOption(
                icon: LucideIcons.image,
                label: 'Photos',
                onTap: () => _dismissAndSchedulePicker(
                  context,
                  _SocialMediaPickAction.photos,
                ),
              ),
              _MediaPickOption(
                icon: LucideIcons.video,
                label: 'Video',
                onTap: () => _dismissAndSchedulePicker(
                  context,
                  _SocialMediaPickAction.video,
                ),
              ),
              _MediaPickOption(
                icon: LucideIcons.camera,
                label: 'Camera Photo',
                onTap: () => _dismissAndSchedulePicker(
                  context,
                  _SocialMediaPickAction.cameraPhoto,
                ),
              ),
              _MediaPickOption(
                icon: LucideIcons.video,
                label: 'Camera Video',
                onTap: () => _dismissAndSchedulePicker(
                  context,
                  _SocialMediaPickAction.cameraVideo,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _dismissAndSchedulePicker(
    BuildContext sheetContext,
    _SocialMediaPickAction action,
  ) {
    Navigator.pop(sheetContext);
    Future.delayed(Duration.zero, () {
      _pickMediaForAction(action);
    });
  }

  Future<void> _pickMediaForAction(_SocialMediaPickAction action) async {
    try {
      switch (action) {
        case _SocialMediaPickAction.photos:
          final files = await _imagePicker.pickMultiImage(
            limit: 10,
            imageQuality: 100,
          );
          _handlePickedItems(
            files
                .map((file) => _SelectedSocialMedia(file: file, type: 'image'))
                .toList(),
          );
          break;
        case _SocialMediaPickAction.video:
          final file = await _imagePicker.pickVideo(
            source: ImageSource.gallery,
          );
          if (file != null) {
            _handlePickedItems([
              _SelectedSocialMedia(file: file, type: 'video'),
            ]);
          }
          break;
        case _SocialMediaPickAction.cameraPhoto:
          final file = await _imagePicker.pickImage(
            source: ImageSource.camera,
            imageQuality: 100,
          );
          if (file != null) {
            _handlePickedItems([
              _SelectedSocialMedia(file: file, type: 'image'),
            ]);
          }
          break;
        case _SocialMediaPickAction.cameraVideo:
          final file = await _imagePicker.pickVideo(source: ImageSource.camera);
          if (file != null) {
            _handlePickedItems([
              _SelectedSocialMedia(file: file, type: 'video'),
            ]);
          }
          break;
      }
    } catch (e) {
      return;
    }
  }

  void _handlePickedItems(List<_SelectedSocialMedia> nextItems) {
    final addedItems = _addSelectedMedia(nextItems);

    for (final item in addedItems) {
      if (item.isVideo) {
        _startVideoThumbnailGeneration(item);
      }
    }
  }

  List<_SelectedSocialMedia> _addSelectedMedia(
    List<_SelectedSocialMedia> items,
  ) {
    if (items.isEmpty || !mounted) return const [];

    final remainingSlots = 10 - _selectedMedia.length;
    if (remainingSlots <= 0) return const [];

    final addedItems = items.take(remainingSlots).toList();
    setState(() {
      _selectedMedia.addAll(addedItems);
      if (_previewIndex >= _selectedMedia.length) {
        _previewIndex = (_selectedMedia.length - 1).clamp(0, 999);
      }
    });

    return addedItems;
  }

  void _startVideoThumbnailGeneration(_SelectedSocialMedia item) {
    final thumbnailFuture = _generateVideoThumbnail(item.file);
    unawaited(
      thumbnailFuture.then((thumbnailBytes) {
        if (thumbnailBytes == null) {
          return;
        }

        if (!mounted || !_selectedMedia.contains(item)) {
          return;
        }

        setState(() {
          item.thumbnailBytes = thumbnailBytes;
        });
      }),
    );
  }

  Future<Uint8List?> _generateVideoThumbnail(XFile file) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 900,
        quality: 82,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<SocialPostMedia>> _uploadMedia({
    required String uid,
    required String postId,
  }) async {
    final media = <SocialPostMedia>[];

    for (var i = 0; i < _selectedMedia.length; i++) {
      final item = _selectedMedia[i];
      final ext = _extensionForFile(item.file, item);
      final fileName = _sanitizeSocialMediaFileName(
        '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.$ext',
      );
      final ref = FirebaseStorage.instance.ref().child(
        'social_posts/$uid/$postId/$fileName',
      );

      final metadata = SettableMetadata(
        contentType: _contentTypeFor(ext, item.type),
        customMetadata: const {'visibility': 'public'},
      );
      Uint8List? webBytes;
      if (kIsWeb) {
        webBytes = await item.file.readAsBytes();
      }

      final uploadSize = webBytes?.length ?? await item.file.length();
      final auth = FirebaseAuth.instance.currentUser;
      debugPrint('UPLOAD START');
      debugPrint('uid=${auth?.uid}');
      debugPrint('localFilePath=${item.file.path}');
      debugPrint('originalFilename=${item.file.name}');
      debugPrint('generatedFilename=$fileName');
      debugPrint('generatedStoragePath=${ref.fullPath}');
      debugPrint('bucket=${ref.bucket}');
      debugPrint('storagePath=${ref.fullPath}');
      debugPrint('mimeType=${metadata.contentType}');
      debugPrint('extension=$ext');
      debugPrint('size=$uploadSize');
      debugPrint('uploadMethod=${kIsWeb ? 'putData' : 'putFile'}');
      debugPrint('UPLOAD REQUEST');

      debugPrint('================================================');
      debugPrint('RUNTIME STORAGE DIAGNOSTICS');
      debugPrint('================================================');
      debugPrint('item.file.name=${item.file.name}');
      debugPrint('item.file.path=${item.file.path}');
      debugPrint('item.file.mimeType=${item.file.mimeType}');
      debugPrint('ext=$ext');
      debugPrint('fileName=$fileName');
      debugPrint('ref.name=${ref.name}');
      debugPrint('ref.fullPath=${ref.fullPath}');
      debugPrint('ref.bucket=${ref.bucket}');
      debugPrint('metadata.contentType=${metadata.contentType}');
      debugPrint('metadata.customMetadata=${metadata.customMetadata}');
      debugPrint('================================================');

      final UploadTask uploadTask;
      debugPrint('preUpload.ref.fullPath=${ref.fullPath}');
      debugPrint('preUpload.ref.name=${ref.name}');
      debugPrint('preUpload.ref.bucket=${ref.bucket}');
      debugPrint('preUpload.metadata.contentType=${metadata.contentType}');
      debugPrint(
        'preUpload.metadata.customMetadata=${metadata.customMetadata}',
      );
      debugPrint('preUpload.extension=$ext');
      debugPrint('preUpload.generatedFilename=$fileName');
      debugPrint('preUpload.byteLength=$uploadSize');
      debugPrint('preUpload.uid=${auth?.uid}');
      debugPrint('preUpload.kIsWeb=$kIsWeb');
      debugPrint('preUpload.uploadMethod=${kIsWeb ? 'putData' : 'putFile'}');
      if (kIsWeb) {
        debugPrint('webBytes=$webBytes');
        uploadTask = ref.putData(webBytes!, metadata);
      } else {
        uploadTask = ref.putFile(File(item.file.path), metadata);
      }

      debugPrint(
        'uploadTask.snapshot.ref.fullPath=${uploadTask.snapshot.ref.fullPath}',
      );
      debugPrint(
        'uploadTask.snapshot.ref.name=${uploadTask.snapshot.ref.name}',
      );
      debugPrint(
        'uploadTask.snapshot.ref.bucket=${uploadTask.snapshot.ref.bucket}',
      );

      TaskSnapshot? lastUploadSnapshot;
      uploadTask.snapshotEvents.listen((snapshot) {
        lastUploadSnapshot = snapshot;
        if (!mounted || snapshot.totalBytes <= 0) return;
        setState(() {
          _uploadProgress =
              ((i + snapshot.bytesTransferred / snapshot.totalBytes) /
                      _selectedMedia.length)
                  .clamp(0.0, 1.0);
        });
      });

      try {
        await uploadTask;
      } on FirebaseException catch (error, stackTrace) {
        debugPrint('UPLOAD ERROR');
        debugPrint('FirebaseException full object: $error');
        debugPrint('exception.runtimeType=${error.runtimeType}');
        debugPrint('code=${error.code}');
        debugPrint('plugin=${error.plugin}');
        debugPrint('message=${error.message}');
        debugPrint('details=not exposed by FirebaseException API');
        debugPrint('stackTrace=$stackTrace');
        debugPrint('toString=${error.toString()}');
        debugPrint('storagePath=${ref.fullPath}');
        debugPrint('ref.name=${ref.name}');
        debugPrint('bucket=${ref.bucket}');
        debugPrint('mimeType=${metadata.contentType}');
        debugPrint('extension=$ext');
        debugPrint('size=$uploadSize');
        debugPrint('snapshot.state=${lastUploadSnapshot?.state}');
        debugPrint(
          'snapshot.bytesTransferred=${lastUploadSnapshot?.bytesTransferred}',
        );
        debugPrint('snapshot.totalBytes=${lastUploadSnapshot?.totalBytes}');
        debugPrint('exception.toString=${error.toString()}');
        debugPrint('stack=$stackTrace');
        rethrow;
      } catch (error, stackTrace) {
        debugPrint('UPLOAD ERROR');
        debugPrint('exception.runtimeType=${error.runtimeType}');
        debugPrint('message=$error');
        debugPrint('toString=$error');
        debugPrint('storagePath=${ref.fullPath}');
        debugPrint('ref.name=${ref.name}');
        debugPrint('bucket=${ref.bucket}');
        debugPrint('mimeType=${metadata.contentType}');
        debugPrint('extension=$ext');
        debugPrint('size=$uploadSize');
        debugPrint('snapshot.state=${lastUploadSnapshot?.state}');
        debugPrint(
          'snapshot.bytesTransferred=${lastUploadSnapshot?.bytesTransferred}',
        );
        debugPrint('snapshot.totalBytes=${lastUploadSnapshot?.totalBytes}');
        debugPrint('exception.toString=$error');
        debugPrint('stack=$stackTrace');
        rethrow;
      }

      final String url;
      try {
        debugPrint('lastUploadSnapshot=$lastUploadSnapshot');
        debugPrint('uploadTask.snapshot=${uploadTask.snapshot}');
        url = await ref.getDownloadURL();
        debugPrint('UPLOAD SUCCESS');
        debugPrint('downloadUrl=$url');
      } catch (_) {
        rethrow;
      }
      String? thumbnailUrl;

      if (item.type == 'video' && item.thumbnailBytes != null) {
        final thumbRef = FirebaseStorage.instance.ref().child(
          'social_posts/$uid/$postId/thumbnails/${fileName}_thumb.jpg',
        );
        final thumbnailMetadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: const {'visibility': 'public'},
        );
        final thumbnailPath = thumbRef.fullPath;
        debugPrint('thumbnailBytes=${item.thumbnailBytes}');
        final thumbnailSize = item.thumbnailBytes!.length;
        debugPrint('UPLOAD START');
        debugPrint('uid=${auth?.uid}');
        debugPrint('localFilePath=${item.file.path}');
        debugPrint('originalFilename=${item.file.name}');
        debugPrint('generatedFilename=${fileName}_thumb.jpg');
        debugPrint('generatedStoragePath=$thumbnailPath');
        debugPrint('bucket=${thumbRef.bucket}');
        debugPrint('storagePath=$thumbnailPath');
        debugPrint('mimeType=${thumbnailMetadata.contentType}');
        debugPrint('extension=jpg');
        debugPrint('size=$thumbnailSize');
        debugPrint('uploadMethod=putData');
        debugPrint('UPLOAD REQUEST');
        TaskSnapshot? lastThumbnailSnapshot;
        try {
          debugPrint('thumbnailBytes=${item.thumbnailBytes}');
          debugPrint('preUpload.ref.fullPath=${thumbRef.fullPath}');
          debugPrint('preUpload.ref.name=${thumbRef.name}');
          debugPrint('preUpload.ref.bucket=${thumbRef.bucket}');
          debugPrint(
            'preUpload.metadata.contentType=${thumbnailMetadata.contentType}',
          );
          debugPrint(
            'preUpload.metadata.customMetadata=${thumbnailMetadata.customMetadata}',
          );
          debugPrint('preUpload.extension=jpg');
          debugPrint('preUpload.generatedFilename=${fileName}_thumb.jpg');
          debugPrint('preUpload.byteLength=$thumbnailSize');
          debugPrint('preUpload.uid=${auth?.uid}');
          debugPrint('preUpload.kIsWeb=$kIsWeb');
          debugPrint('preUpload.uploadMethod=putData');
          final thumbnailUploadTask = thumbRef.putData(
            item.thumbnailBytes!,
            thumbnailMetadata,
          );
          thumbnailUploadTask.snapshotEvents.listen((snapshot) {
            lastThumbnailSnapshot = snapshot;
          });
          await thumbnailUploadTask;
        } on FirebaseException catch (error, stackTrace) {
          debugPrint('UPLOAD ERROR');
          debugPrint('FirebaseException full object: $error');
          debugPrint('exception.runtimeType=${error.runtimeType}');
          debugPrint('code=${error.code}');
          debugPrint('plugin=${error.plugin}');
          debugPrint('message=${error.message}');
          debugPrint('details=not exposed by FirebaseException API');
          debugPrint('stackTrace=$stackTrace');
          debugPrint('toString=${error.toString()}');
          debugPrint('storagePath=$thumbnailPath');
          debugPrint('ref.name=${thumbRef.name}');
          debugPrint('bucket=${thumbRef.bucket}');
          debugPrint('mimeType=${thumbnailMetadata.contentType}');
          debugPrint('extension=jpg');
          debugPrint('size=$thumbnailSize');
          debugPrint('snapshot.state=${lastThumbnailSnapshot?.state}');
          debugPrint(
            'snapshot.bytesTransferred=${lastThumbnailSnapshot?.bytesTransferred}',
          );
          debugPrint(
            'snapshot.totalBytes=${lastThumbnailSnapshot?.totalBytes}',
          );
          debugPrint('stack=$stackTrace');
          rethrow;
        } catch (error, stackTrace) {
          debugPrint('UPLOAD ERROR');
          debugPrint('exception.runtimeType=${error.runtimeType}');
          debugPrint('message=$error');
          debugPrint('toString=$error');
          debugPrint('storagePath=$thumbnailPath');
          debugPrint('ref.name=${thumbRef.name}');
          debugPrint('bucket=${thumbRef.bucket}');
          debugPrint('mimeType=${thumbnailMetadata.contentType}');
          debugPrint('extension=jpg');
          debugPrint('size=$thumbnailSize');
          debugPrint('snapshot.state=${lastThumbnailSnapshot?.state}');
          debugPrint(
            'snapshot.bytesTransferred=${lastThumbnailSnapshot?.bytesTransferred}',
          );
          debugPrint(
            'snapshot.totalBytes=${lastThumbnailSnapshot?.totalBytes}',
          );
          debugPrint('stack=$stackTrace');
          rethrow;
        }

        try {
          thumbnailUrl = await thumbRef.getDownloadURL();
          debugPrint('UPLOAD SUCCESS');
          debugPrint('downloadUrl=$thumbnailUrl');
        } catch (_) {
          rethrow;
        }
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

  String _extensionForFile(XFile file, _SelectedSocialMedia item) {
    return socialMediaExtensionForFile(file, isVideo: item.isVideo);
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
        SnackBar(
          content: Text(
            (() {
              final localizations = AppLocalizations.of(context);
              debugPrint('localizations=$localizations');
              return localizations!.selectAtLeastOnePhotoOrVideo;
            })(),
          ),
        ),
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

      debugPrint('POST CREATE START');
      debugPrint('uid=${currentUser.uid}');
      debugPrint('postId=$postId');
      debugPrint('mediaUrl=${post.mediaUrls.join(',')}');
      debugPrint('mediaType=${post.mediaType}');
      try {
        await _postService.createPost(post);
        debugPrint('POST CREATE SUCCESS');
      } catch (error) {
        debugPrint('POST CREATE ERROR');
        debugPrint('exception.runtimeType=${error.runtimeType}');
        debugPrint('message=$error');
        rethrow;
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('CreateSocialPostPage error: $e');
      debugPrint('CreateSocialPostPage original exception before error UI: $e');

      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      final message =
          localizations?.errorCreatingPost('$e') ??
          'Failed to create post. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      rethrow;
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
        title: Text(
          (() {
            final localizations = AppLocalizations.of(context);
            debugPrint('localizations=$localizations');
            return localizations!.createPostTitle;
          })(),
        ),
        actions: [
          TextButton(
            onPressed: canShare ? _createPost : null,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    (() {
                      final localizations = AppLocalizations.of(context);
                      debugPrint('localizations=$localizations');
                      return localizations!.share;
                    })(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
                      label: Text(
                        (() {
                          final localizations = AppLocalizations.of(context);
                          debugPrint('localizations=$localizations');
                          return localizations!.addPhotosOrVideos;
                        })(),
                      ),
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
                  hintText: (() {
                    final localizations = AppLocalizations.of(context);
                    debugPrint('localizations=$localizations');
                    return localizations!.writeSomethingHint;
                  })(),
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
  final XFile file;
  final String type;
  Uint8List? thumbnailBytes;

  _SelectedSocialMedia({required this.file, required this.type});

  bool get isVideo => type == 'video';
}

enum _SocialMediaPickAction { photos, video, cameraPhoto, cameraVideo }

class _MediaPickOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MediaPickOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('BUILD OPTION: $label');

    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
      title: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
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
          (() {
            debugPrint('thumbnailBytes=${item.thumbnailBytes}');
            return Image.memory(item.thumbnailBytes!, fit: BoxFit.cover);
          })()
        else if (item.isVideo)
          ColoredBox(color: Colors.grey.shade900)
        else
          PlatformPathImage(path: item.file.path, fit: BoxFit.cover),
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
                      ? (() {
                          debugPrint('thumbnailBytes=${item.thumbnailBytes}');
                          return Image.memory(
                            item.thumbnailBytes!,
                            fit: BoxFit.cover,
                          );
                        })()
                      : item.isVideo
                      ? ColoredBox(color: Colors.grey.shade900)
                      : PlatformPathImage(
                          path: item.file.path,
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
                  onTap: onRemove == null
                      ? null
                      : () {
                          debugPrint('onRemove=$onRemove');
                          onRemove!(index);
                        },
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
