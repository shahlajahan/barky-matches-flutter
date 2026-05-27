import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../theme/app_theme.dart';

class VetGalleryManagementPage extends StatefulWidget {
  final String businessId;

  const VetGalleryManagementPage({
    super.key,
    required this.businessId,
  });

  @override
  State<VetGalleryManagementPage> createState() =>
      _VetGalleryManagementPageState();
}

class _VetGalleryManagementPageState
    extends State<VetGalleryManagementPage> {
  final ImagePicker _picker = ImagePicker();

  bool _loading = false;

  // ─────────────────────────────────────────────
  // 🔥 FIRESTORE DOC
  // ─────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> get _businessRef =>
      FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId);

  // ─────────────────────────────────────────────
  // 🔥 LOAD GALLERY
  // ─────────────────────────────────────────────
String? _coverImageUrl;
  Stream<List<String>> _galleryStream() {
    return _businessRef.snapshots().map((snapshot) {
      final data = snapshot.data();

      if (data == null) {
        return [];
      }

      final sectorData =
          (data['sectorData'] as Map<String, dynamic>?) ??
          {};

      final veterinary =
          (sectorData['veterinary']
              as Map<String, dynamic>?) ??
          {};

      final profileContent =
          (veterinary['profileContent']
              as Map<String, dynamic>?) ??
          {};
_coverImageUrl =
    profileContent['coverImageUrl']
        ?.toString();
      final raw =
          profileContent['clinicPhotoUrls'];

      if (raw is List) {
        return raw
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      return [];
    });
  }

  // ─────────────────────────────────────────────
  // 🔥 PICK & UPLOAD
  // ─────────────────────────────────────────────

  Future<void> _addPhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) {
        return;
      }

      setState(() => _loading = true);

      final file = File(picked.path);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child(
            'business_gallery/${widget.businessId}/${DateTime.now().millisecondsSinceEpoch}.jpg',
          );

      await storageRef.putFile(file);

      final url = await storageRef.getDownloadURL();

      final snapshot = await _businessRef.get();

      final data = snapshot.data() ?? {};

      final sectorData =
          Map<String, dynamic>.from(
            data['sectorData'] ?? {},
          );

      final veterinary =
          Map<String, dynamic>.from(
            sectorData['veterinary'] ?? {},
          );

      final profileContent =
          Map<String, dynamic>.from(
            veterinary['profileContent'] ?? {},
          );

      final current =
          (profileContent['clinicPhotoUrls']
                  as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      current.add(url);

      profileContent['clinicPhotoUrls'] =
          current;

      veterinary['profileContent'] =
          profileContent;

      sectorData['veterinary'] = veterinary;

      await _businessRef.update({
        'sectorData': sectorData,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Photo uploaded successfully',
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        '❌ GALLERY UPLOAD ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Upload failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ─────────────────────────────────────────────
  // 🔥 DELETE PHOTO
  // ─────────────────────────────────────────────

  Future<void> _deletePhoto(
    String imageUrl,
  ) async {
    try {
      setState(() => _loading = true);

      final snapshot = await _businessRef.get();

      final data = snapshot.data() ?? {};

      final sectorData =
          Map<String, dynamic>.from(
            data['sectorData'] ?? {},
          );

      final veterinary =
          Map<String, dynamic>.from(
            sectorData['veterinary'] ?? {},
          );

      final profileContent =
          Map<String, dynamic>.from(
            veterinary['profileContent'] ?? {},
          );

      final current =
          (profileContent['clinicPhotoUrls']
                  as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      current.remove(imageUrl);

      profileContent['clinicPhotoUrls'] =
          current;

      veterinary['profileContent'] =
          profileContent;

      sectorData['veterinary'] = veterinary;

      await _businessRef.update({
        'sectorData': sectorData,
      });

      // 🔥 DELETE STORAGE FILE
      try {
        await FirebaseStorage.instance
            .refFromURL(imageUrl)
            .delete();
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Photo deleted',
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        '❌ DELETE PHOTO ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delete failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ─────────────────────────────────────────────
  // 🔥 REORDER
  // ─────────────────────────────────────────────

  Future<void> _reorderPhotos(
    int oldIndex,
    int newIndex,
    List<String> images,
  ) async {
    try {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final updated =
          List<String>.from(images);

      final item =
          updated.removeAt(oldIndex);

      updated.insert(newIndex, item);

      final snapshot = await _businessRef.get();

      final data = snapshot.data() ?? {};

      final sectorData =
          Map<String, dynamic>.from(
            data['sectorData'] ?? {},
          );

      final veterinary =
          Map<String, dynamic>.from(
            sectorData['veterinary'] ?? {},
          );

      final profileContent =
          Map<String, dynamic>.from(
            veterinary['profileContent'] ?? {},
          );

      profileContent['clinicPhotoUrls'] =
          updated;

      veterinary['profileContent'] =
          profileContent;

      sectorData['veterinary'] = veterinary;

      await _businessRef.update({
        'sectorData': sectorData,
      });
    } catch (e) {
      debugPrint(
        '❌ REORDER ERROR: $e',
      );
    }
  }
Future<void> _changeCoverImage() async {
  try {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (picked == null) {
      return;
    }

    setState(() => _loading = true);

    final file = File(picked.path);

    final storageRef =
        FirebaseStorage.instance
            .ref()
            .child(
              'business_cover/${widget.businessId}/${DateTime.now().millisecondsSinceEpoch}.jpg',
            );

    await storageRef.putFile(file);

    final url =
        await storageRef.getDownloadURL();

    final snapshot =
        await _businessRef.get();

    final data = snapshot.data() ?? {};

    final sectorData =
        Map<String, dynamic>.from(
          data['sectorData'] ?? {},
        );

    final veterinary =
        Map<String, dynamic>.from(
          sectorData['veterinary'] ?? {},
        );

    final profileContent =
        Map<String, dynamic>.from(
          veterinary['profileContent'] ??
              {},
        );

    profileContent['coverImageUrl'] =
        url;

    veterinary['profileContent'] =
        profileContent;

    sectorData['veterinary'] =
        veterinary;

    await _businessRef.update({
      'sectorData': sectorData,
    });

    if (!mounted) return;

    setState(() {
      _coverImageUrl = url;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
          const SnackBar(
            content: Text(
              'Cover image updated',
            ),
          ),
        );
  } catch (e) {
    debugPrint(
      '❌ COVER IMAGE ERROR: $e',
    );
  } finally {
    if (mounted) {
      setState(() => _loading = false);
    }
  }
}
  // ─────────────────────────────────────────────
  // 🔥 UI
  // ─────────────────────────────────────────────

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppTheme.bg,

    appBar: AppBar(
      title: const Text(
        'Gallery Management',
      ),
    ),

    floatingActionButton:
        FloatingActionButton.extended(
          backgroundColor:
              AppTheme.accent,

          onPressed:
              _loading ? null : _addPhoto,

          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                )
              : const Icon(
                  LucideIcons.plus,
                ),

          label: Text(
            _loading
                ? 'Uploading...'
                : 'Add Photo',
          ),
        ),

    body: SafeArea(
      child: StreamBuilder<List<String>>(
        stream: _galleryStream(),

        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final images =
              snapshot.data ?? [];

          return Column(
            children: [

              // 🔥 COVER IMAGE
Padding(
  padding: const EdgeInsets.fromLTRB(
    16,
    16,
    16,
    0,
  ),

  child: Column(
    crossAxisAlignment:
        CrossAxisAlignment.start,

    children: [
      Text(
        'Cover Image',
        style: AppTheme.h2(),
      ),

      const SizedBox(
        height: 12,
      ),

      GestureDetector(
        onTap: _loading
            ? null
            : _changeCoverImage,

        child: Container(
          height: 180,
          width: double.infinity,

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.circular(
                  20,
                ),

            boxShadow:
                AppTheme.cardShadow(),
          ),

          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(
                  20,
                ),

            child:
                _coverImageUrl != null &&
                        _coverImageUrl!
                            .isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,

                        children: [

                          // 🔥 COVER IMAGE
                          Image.network(
                            _coverImageUrl!,
                            fit: BoxFit.cover,

                            errorBuilder:
                                (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                              return Container(
                                color:
                                    Colors
                                        .grey
                                        .shade200,

                                child:
                                    const Center(
                                      child:
                                          Icon(
                                            Icons
                                                .broken_image,

                                            size:
                                                42,
                                          ),
                                    ),
                              );
                            },
                          ),

                          // 🔥 DARK OVERLAY
                          Container(
                            decoration:
                                BoxDecoration(
                                  gradient:
                                      LinearGradient(
                                        begin:
                                            Alignment
                                                .topCenter,

                                        end:
                                            Alignment
                                                .bottomCenter,

                                        colors: [
                                          Colors.black
                                              .withOpacity(
                                                0.12,
                                              ),

                                          Colors.black
                                              .withOpacity(
                                                0.38,
                                              ),
                                        ],
                                      ),
                                ),
                          ),

                          // 🔥 EDIT ICON
                          Positioned(
                            right: 12,
                            top: 12,

                            child:
                                Container(
                                  padding:
                                      const EdgeInsets.all(
                                        8,
                                      ),

                                  decoration:
                                      BoxDecoration(
                                        color: Colors
                                            .black
                                            .withOpacity(
                                              0.55,
                                            ),

                                        shape:
                                            BoxShape
                                                .circle,
                                      ),

                                  child:
                                      const Icon(
                                        LucideIcons
                                            .edit2,

                                        color:
                                            Colors
                                                .white,

                                        size:
                                            18,
                                      ),
                                ),
                          ),

                          // 🔥 TAP HINT
                          Positioned(
                            left: 14,
                            bottom: 14,

                            child:
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                        horizontal:
                                            12,
                                        vertical:
                                            8,
                                      ),

                                  decoration:
                                      BoxDecoration(
                                        color: Colors
                                            .black
                                            .withOpacity(
                                              0.55,
                                            ),

                                        borderRadius:
                                            BorderRadius.circular(
                                              12,
                                            ),
                                      ),

                                  child:
                                      const Row(
                                        mainAxisSize:
                                            MainAxisSize
                                                .min,

                                        children: [
                                          Icon(
                                            LucideIcons
                                                .imagePlus,

                                            color:
                                                Colors
                                                    .white,

                                            size:
                                                16,
                                          ),

                                          SizedBox(
                                            width:
                                                8,
                                          ),

                                          Text(
                                            'Tap to change cover',

                                            style:
                                                TextStyle(
                                                  color:
                                                      Colors.white,

                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                ),
                          ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,

                          children: [
                            Icon(
                              LucideIcons
                                  .image,

                              size: 42,

                              color: Colors
                                  .grey
                                  .shade500,
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            Text(
                              'Upload cover image',

                              style:
                                  AppTheme.body(),
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            Text(
                              'Tap to upload clinic cover photo',

                              textAlign:
                                  TextAlign
                                      .center,

                              style:
                                  AppTheme.body(
                                    color: Colors
                                        .grey
                                        .shade600,
                                  ),
                            ),
                          ],
                        ),
                      ),
          ),
        ),
      ),

      const SizedBox(height: 22),

      Align(
        alignment:
            Alignment.centerLeft,

        child: Text(
          'Gallery Photos',
          style: AppTheme.h2(),
        ),
      ),

      const SizedBox(height: 14),
    ],
  ),
),

              // 🔥 EMPTY STATE
              if (images.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                            24,
                          ),

                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,

                        children: [
                          Icon(
                            LucideIcons.image,
                            size: 70,
                            color: Colors
                                .grey.shade400,
                          ),

                          const SizedBox(
                            height: 18,
                          ),

                          Text(
                            'No gallery photos yet',
                            style:
                                AppTheme.h2(),
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          Text(
                            'Upload clinic photos to improve trust and visibility.',

                            textAlign:
                                TextAlign.center,

                            style:
                                AppTheme.body(
                                  color: Colors
                                      .grey
                                      .shade600,
                                ),
                          ),

                          const SizedBox(
                            height: 24,
                          ),

                          ElevatedButton.icon(
                            style:
                                ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppTheme.accent,

                                  foregroundColor:
                                      Colors.white,

                                  padding:
                                      const EdgeInsets.symmetric(
                                        horizontal:
                                            18,
                                        vertical:
                                            14,
                                      ),
                                ),

                            onPressed:
                                _loading
                                ? null
                                : _addPhoto,

                            icon:
                                const Icon(
                                  LucideIcons
                                      .plus,
                                ),

                            label:
                                const Text(
                                  'Upload First Photo',
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )

              // 🔥 GALLERY LIST
              else
                Expanded(
                  child:
                      ReorderableListView.builder(
                        padding:
                            const EdgeInsets.all(
                              16,
                            ),

                        itemCount:
                            images.length,

                        onReorder:
                            (
                              oldIndex,
                              newIndex,
                            ) =>
                                _reorderPhotos(
                                  oldIndex,
                                  newIndex,
                                  images,
                                ),

                        itemBuilder:
                            (
                              context,
                              index,
                            ) {
                              final imageUrl =
                                  images[index];

                              return Container(
                                key: ValueKey(
                                  imageUrl,
                                ),

                                margin:
                                    const EdgeInsets.only(
                                      bottom:
                                          14,
                                    ),

                                decoration:
                                    BoxDecoration(
                                      color:
                                          Colors.white,

                                      borderRadius:
                                          BorderRadius.circular(
                                            18,
                                          ),

                                      boxShadow:
                                          AppTheme.cardShadow(),
                                    ),

                                child:
                                    Column(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top:
                                                    Radius.circular(
                                                      18,
                                                    ),
                                              ),

                                          child:
                                              AspectRatio(
                                                aspectRatio:
                                                    16 /
                                                    9,

                                                child:
                                                    Image.network(
                                                      imageUrl,

                                                      fit:
                                                          BoxFit.cover,

                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) {
                                                            return Container(
                                                              color:
                                                                  Colors.grey.shade200,

                                                              child:
                                                                  const Center(
                                                                    child:
                                                                        Icon(
                                                                          Icons.broken_image,
                                                                        ),
                                                                  ),
                                                            );
                                                          },
                                                    ),
                                              ),
                                        ),

                                        Padding(
                                          padding:
                                              const EdgeInsets.all(
                                                14,
                                              ),

                                          child:
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          8,
                                                        ),

                                                    decoration:
                                                        BoxDecoration(
                                                          color:
                                                              AppTheme.accent.withOpacity(
                                                                0.1,
                                                              ),

                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),

                                                    child:
                                                        Icon(
                                                          LucideIcons.move,

                                                          size:
                                                              18,

                                                          color:
                                                              AppTheme.accent,
                                                        ),
                                                  ),

                                                  const SizedBox(
                                                    width:
                                                        12,
                                                  ),

                                                  Expanded(
                                                    child:
                                                        Text(
                                                          'Drag to reorder gallery photos',

                                                          style:
                                                              AppTheme.body(),
                                                        ),
                                                  ),

                                                  IconButton(
                                                    onPressed:
                                                        _loading
                                                        ? null
                                                        : () => _deletePhoto(
                                                            imageUrl,
                                                          ),

                                                    icon:
                                                        const Icon(
                                                          LucideIcons.trash2,
                                                        ),

                                                    color:
                                                        Colors.red,
                                                  ),
                                                ],
                                              ),
                                        ),
                                      ],
                                    ),
                              );
                            },
                      ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
}