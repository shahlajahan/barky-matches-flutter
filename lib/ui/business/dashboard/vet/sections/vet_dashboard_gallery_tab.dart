import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barky_matches_fixed/services/image_upload_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:barky_matches_fixed/ui/common/smart_media.dart';

class AdoptionCenterDashboardGalleryTab extends StatefulWidget {
  final String businessId;

  const AdoptionCenterDashboardGalleryTab({
    super.key,
    required this.businessId,
  });

  @override
  State<AdoptionCenterDashboardGalleryTab> createState() =>
      _AdoptionCenterDashboardGalleryTabState();
}

class _AdoptionCenterDashboardGalleryTabState
    extends State<AdoptionCenterDashboardGalleryTab> {
  bool _picking = false;
  bool _uploading = false;
  double _progress = 0;

  bool _isVideo(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp4') || p.endsWith('.mov') || p.endsWith('.hevc');
  }

  Future<void> _pickAndUploadMultiple() async {
    if (_picking) return;
    _picking = true;

    final picker = ImagePicker();
    try {
      final pickedFiles = await picker.pickMultipleMedia();
      if (pickedFiles.isEmpty) return;

      final files = pickedFiles.map((x) => File(x.path)).toList();
      final imageFiles = <File>[];
      final videoFiles = <File>[];

      for (final f in files) {
        if (_isVideo(f.path)) {
          videoFiles.add(f);
        } else {
          imageFiles.add(f);
        }
      }

      debugPrint("IMAGES: ${imageFiles.length}");
      debugPrint("VIDEOS: ${videoFiles.length}");

      setState(() {
        _uploading = true;
        _progress = 0;
      });

      final docRef = FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId);

      final currentSnap = await docRef.get();
      final currentData = currentSnap.data() ?? {};
      final currentImages = _mergedImagesFromData(currentData);
      final currentVideos = List<String>.from(currentData['videos'] ?? []);
      final currentCover = (currentData['coverImageUrl'] ?? '').toString();

      List<String> imageUrls = [];
      if (imageFiles.isNotEmpty) {
        imageUrls = await ImageUploadService.uploadBusinessImages(
          files: imageFiles,
          businessId: widget.businessId,
          onProgress: (p) {
            if (!mounted) return;
            setState(() {
              _progress = p.isNaN || p.isInfinite ? 0 : p.clamp(0.0, 1.0);
            });
          },
        );
      }

      List<String> videoUrls = [];
      for (final videoFile in videoFiles) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${videoFile.path.split('/').last}';
        final ref = FirebaseStorage.instance.ref().child(
          'business_gallery/${widget.businessId}/videos/$fileName',
        );
        final task = ref.putFile(videoFile);
        final snap = await task;
        final url = await snap.ref.getDownloadURL();
        videoUrls.add(url);
      }

      final nextImages = <dynamic>{...currentImages, ...imageUrls}.toList();
      final nextVideos = <dynamic>{...currentVideos, ...videoUrls}.toList();

      await docRef.set({
        'images': nextImages,
        'videos': nextVideos,
        if (currentCover.isEmpty && imageUrls.isNotEmpty)
          'coverImageUrl': imageUrls.first,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('MULTI UPLOAD ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      _picking = false;
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _progress = 0;
      });
    }
  }

  Future<void> _deleteImage({
    required String url,
    required List<String> currentImages,
    required String currentCover,
  }) async {
    try {
      await ImageUploadService.deleteImageByUrl(url);

      final nextImages = List<String>.from(currentImages)..remove(url);
      String? nextCover;
      if (currentCover == url) {
        nextCover = nextImages.isNotEmpty ? nextImages.first : null;
      }

      final nextOnlyImages = nextImages.where((e) => !_isVideo(e)).toList();
      final nextOnlyVideos = nextImages.where((e) => _isVideo(e)).toList();

      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .set({
            'images': nextOnlyImages,
            'videos': nextOnlyVideos,
            'coverImageUrl': nextCover,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('DELETE ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _setCover(String url) async {
    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .set({
            'coverImageUrl': url,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('SET COVER ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to set cover: $e')));
      }
    }
  }

  List<String> _mergedImagesFromData(Map<String, dynamic> data) {
    return <dynamic>{...List<String>.from(data['images'] ?? [])}.toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data!.data() ?? {};
        final images = _mergedImagesFromData(data);
        final coverImageUrl = (data['coverImageUrl'] ?? '').toString();
        final videos = List<String>.from(data['videos'] ?? []);
        final media = [...images, ...videos];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _uploading ? null : _pickAndUploadMultiple,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Upload Pet Media'),
                    ),
                  ),
                  if (_uploading) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (_progress.isNaN || _progress.isInfinite)
                          ? 0
                          : _progress.clamp(0.0, 1.0),
                    ),
                    const SizedBox(height: 6),
                    Text('${(_progress * 100).toStringAsFixed(0)}% uploaded'),
                  ],
                ],
              ),
            ),
            Expanded(
              child: media.isEmpty
                  ? const Center(child: Text('No media yet'))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      itemCount: media.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.92,
                          ),
                      itemBuilder: (_, i) {
                        final url = media[i];
                        final isVideo = _isVideo(url);
                        final isCover = url == coverImageUrl;

                        return _GalleryCard(
                          imageUrl: url,
                          isCover: !isVideo && isCover,
                          isVideo: isVideo,
                          onSetCover: isVideo ? null : () => _setCover(url),
                          onDelete: () => _deleteImage(
                            url: url,
                            currentImages: media,
                            currentCover: coverImageUrl,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final String imageUrl;
  final bool isCover;
  final bool isVideo;
  final VoidCallback? onSetCover;
  final VoidCallback onDelete;

  const _GalleryCard({
    required this.imageUrl,
    required this.isCover,
    required this.isVideo,
    required this.onSetCover,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x14000000),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 🖼 IMAGE
                        if (!isVideo)
                          SmartMedia(url: imageUrl, fit: BoxFit.cover),
                        // 🎥 VIDEO PLACEHOLDER
                        if (isVideo)
                          SmartMedia(url: imageUrl, fit: BoxFit.cover),
                      ],
                    ),
                  ),
                ),
                // 🏷 COVER TAG
                if (isCover)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Cover',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                // ❌ DELETE BUTTON
                Positioned(
                  right: 10,
                  top: 10,
                  child: GestureDetector(
                    onTap: onDelete,
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 🔘 BUTTON
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: (isCover || isVideo) ? null : onSetCover,
                child: Text(
                  isVideo
                      ? 'Video'
                      : (isCover ? 'Current Cover' : 'Set as Cover'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
