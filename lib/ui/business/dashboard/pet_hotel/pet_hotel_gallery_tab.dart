import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:barky_matches_fixed/services/image_upload_service.dart';
import 'package:barky_matches_fixed/ui/common/smart_media.dart';

class PetHotelGalleryTab extends StatefulWidget {
  final String businessId;

  const PetHotelGalleryTab({
    super.key,
    required this.businessId,
  });

  @override
  State<PetHotelGalleryTab> createState() => _PetHotelGalleryTabState();
}

class _PetHotelGalleryTabState extends State<PetHotelGalleryTab> {
  bool _uploading = false;
  bool _picking = false;
  double _progress = 0;

  bool _isVideo(String path) {
    final p = path.toLowerCase();

    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.hevc') ||
        p.endsWith('.m4v');
  }

  List<String> _mergedImages(Map<String, dynamic> data) {
    return <String>{
      ...List<String>.from(data['images'] ?? []),
    }.toList();
  }

  Future<void> _pickAndUploadMultiple() async {
    if (_picking) return;

    _picking = true;

    try {
      final picker = ImagePicker();

      final picked = await picker.pickMultipleMedia();

      if (picked.isEmpty) return;

      final files = picked.map((e) => File(e.path)).toList();

      final imageFiles = <File>[];
      final videoFiles = <File>[];

      for (final file in files) {
        if (_isVideo(file.path)) {
          videoFiles.add(file);
        } else {
          imageFiles.add(file);
        }
      }

      setState(() {
        _uploading = true;
        _progress = 0;
      });

      final docRef = FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId);

      final snap = await docRef.get();

      final data = snap.data() ?? {};

      final existingImages = _mergedImages(data);

      final existingVideos =
          List<String>.from(data['videos'] ?? []);

      final cover =
          (data['coverImageUrl'] ?? '').toString();

      List<String> uploadedImages = [];

      if (imageFiles.isNotEmpty) {
        uploadedImages =
            await ImageUploadService.uploadBusinessImages(
          files: imageFiles,
          businessId: widget.businessId,
          onProgress: (value) {
            if (!mounted) return;

            setState(() {
              _progress =
                  value.clamp(0.0, 1.0);
            });
          },
        );
      }

      final uploadedVideos = <String>[];

      for (final video in videoFiles) {
        final name =
            '${DateTime.now().millisecondsSinceEpoch}_${video.path.split('/').last}';

        final ref = FirebaseStorage.instance
            .ref()
            .child(
              'business_gallery/${widget.businessId}/videos/$name',
            );

        final task = ref.putFile(video);

        final result = await task;

        final url =
            await result.ref.getDownloadURL();

        uploadedVideos.add(url);
      }

      final nextImages = <dynamic>{
        ...existingImages,
        ...uploadedImages,
      }.toList();

      final nextVideos = <dynamic>{
        ...existingVideos,
        ...uploadedVideos,
      }.toList();

      await docRef.set({
        'images': nextImages,
        'videos': nextVideos,
        if (cover.isEmpty &&
            uploadedImages.isNotEmpty)
          'coverImageUrl': uploadedImages.first,
        'updatedAt':
            FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("HOTEL GALLERY ERROR $e");
    }

    _picking = false;

    if (!mounted) return;

    setState(() {
      _uploading = false;
      _progress = 0;
    });
  }

  Future<void> _setCover(String url) async {
    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.businessId)
        .set({
      'coverImageUrl': url,
      'updatedAt':
          FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteMedia({
    required String url,
    required List<String> currentImages,
    required String cover,
  }) async {
    await ImageUploadService.deleteImageByUrl(
      url,
    );

    final next =
        List<String>.from(currentImages)
          ..remove(url);

    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.businessId)
        .set({
      'images':
          next.where((e) => !_isVideo(e)).toList(),
      'videos':
          next.where((e) => _isVideo(e)).toList(),
      'coverImageUrl':
          cover == url
              ? (next.isNotEmpty
                    ? next.first
                    : null)
              : cover,
      'updatedAt':
          FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .snapshots(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        final data =
            snapshot.data!.data() ?? {};

        final images =
            _mergedImages(data);

        final videos =
            List<String>.from(
          data['videos'] ?? [],
        );

        final cover =
            (data['coverImageUrl'] ?? '')
                .toString();

        final media = [
          ...images,
          ...videos,
        ];

        return Column(
          children: [

            Padding(
              padding:
                  const EdgeInsets.all(16),
              child: Column(
                children: [

                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          _uploading
                              ? null
                              : _pickAndUploadMultiple,
                      icon: const Icon(
                        Icons
                            .add_photo_alternate,
                      ),
                      label: const Text(
                        "Upload Hotel Media",
                      ),
                    ),
                  ),

                  if (_uploading) ...[
                    const SizedBox(
                      height: 12,
                    ),

                    LinearProgressIndicator(
                      value: _progress,
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      "${(_progress * 100).toStringAsFixed(0)}%",
                    ),
                  ]
                ],
              ),
            ),

            Expanded(
              child: media.isEmpty
                  ? const Center(
                      child: Text(
                        "No media yet",
                      ),
                    )
                  : GridView.builder(
                      padding:
                          const EdgeInsets.all(
                              16),
                      itemCount:
                          media.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            2,
                        crossAxisSpacing:
                            12,
                        mainAxisSpacing:
                            12,
                        childAspectRatio:
                            .92,
                      ),
                      itemBuilder:
                          (_, index) {
                        final url =
                            media[index];

                        final isVideo =
                            _isVideo(
                          url,
                        );

                        final isCover =
                            cover ==
                                url;

                        return _GalleryCard(
                          url: url,
                          isVideo:
                              isVideo,
                          isCover:
                              isCover,
                          onSetCover:
                              isVideo
                                  ? null
                                  : () =>
                                      _setCover(
                                        url,
                                      ),
                          onDelete:
                              () =>
                                  _deleteMedia(
                            url: url,
                            currentImages:
                                media.cast<
                                    String>(),
                            cover:
                                cover,
                          ),
                        );
                      },
                    ),
            )
          ],
        );
      },
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final String url;
  final bool isVideo;
  final bool isCover;

  final VoidCallback? onSetCover;
  final VoidCallback onDelete;

  const _GalleryCard({
    required this.url,
    required this.isVideo,
    required this.isCover,
    required this.onSetCover,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(18),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color:
                Color(0x15000000),
          )
        ],
      ),
      child: Column(
        children: [

          Expanded(
            child: Stack(
              children: [

                Positioned.fill(
                  child:
                      ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(
                      top:
                          Radius.circular(
                        18,
                      ),
                    ),
                    child:
                        SmartMedia(
                      url: url,
                      fit:
                          BoxFit.cover,
                    ),
                  ),
                ),

                if (isCover)
                  Positioned(
                    top: 10,
                    left: 10,
                    child:
                        Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal:
                            10,
                        vertical:
                            5,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.black,
                        borderRadius:
                            BorderRadius.circular(
                          999,
                        ),
                      ),
                      child:
                          const Text(
                        "Cover",
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  right: 10,
                  top: 10,
                  child:
                      GestureDetector(
                    onTap:
                        onDelete,
                    child:
                        const CircleAvatar(
                      radius: 16,
                      child: Icon(
                        Icons.close,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.all(
                    10),
            child:
                SizedBox(
              width:
                  double.infinity,
              child:
                  OutlinedButton(
                onPressed:
                    (isVideo ||
                            isCover)
                        ? null
                        : onSetCover,
                child: Text(
                  isVideo
                      ? "Video"
                      : isCover
                          ? "Current Cover"
                          : "Set as Cover",
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}