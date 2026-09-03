import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

class ImageUploadService {
  static Future<Uint8List> _compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      throw Exception('Failed to decode image');
    }

    final resized = img.copyResize(
      decoded,
      width: decoded.width > 1080 ? 1080 : decoded.width,
    );

    final compressed = img.encodeJpg(resized, quality: 75);
    return Uint8List.fromList(compressed);
  }

  static Future<String> uploadBusinessImage({
    required File file,
    required String businessId,
    required Function(double progress) onProgress,
  }) {
    return _uploadCompressedJpeg(
      file: file,
      objectPath:
          'business_gallery/$businessId/'
          '${DateTime.now().millisecondsSinceEpoch}.jpg',
      onProgress: onProgress,
    );
  }

  /// Uploads a business cover image to `business_cover/{businessId}/`.
  ///
  /// Kept as a separate object namespace from the gallery — `storage.rules`
  /// scopes each prefix to one business and the cover is a single replaceable
  /// image rather than a gallery member — but it shares the identical
  /// compression, naming and content-type contract, so the same
  /// `hasAllowedBusinessImage()` validator governs both.
  static Future<String> uploadBusinessCoverImage({
    required File file,
    required String businessId,
    required Function(double progress) onProgress,
  }) {
    return _uploadCompressedJpeg(
      file: file,
      objectPath:
          'business_cover/$businessId/'
          '${DateTime.now().millisecondsSinceEpoch}.jpg',
      onProgress: onProgress,
    );
  }

  static Future<String> _uploadCompressedJpeg({
    required File file,
    required String objectPath,
    required Function(double progress) onProgress,
  }) async {
    final compressedBytes = await _compressImage(file);

    final ref = FirebaseStorage.instance.ref().child(objectPath);

    // The content type must be declared explicitly. `putData` has no local
    // file to infer from, so the Firebase SDK falls back to
    // `application/octet-stream` (StorageUploadTask's
    // `MIMETypeForExtension(file?.pathExtension)` receives null), which
    // `storage.rules`' `hasAllowedBusinessImage()` rejects. The
    // declaration is unconditionally truthful here: `_compressImage`
    // always returns `img.encodeJpg(...)` bytes, and the object name above
    // is always `.jpg`, so the declared type, the bytes and the extension
    // always agree.
    final uploadTask = ref.putData(
      compressedBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    uploadTask.snapshotEvents.listen((event) {
      double progress = 0;
      if (event.totalBytes > 0) {
        progress = event.bytesTransferred / event.totalBytes;
      }
      progress = progress.clamp(0.0, 1.0);
      onProgress(progress);
    });

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  static Future<List<String>> uploadBusinessImages({
    required List<File> files,
    required String businessId,
    required Function(double overallProgress) onProgress,
  }) async {
    if (files.isEmpty) return [];

    final urls = <String>[];
    final total = files.length;

    for (int i = 0; i < total; i++) {
      final file = files[i];

      final url = await uploadBusinessImage(
        file: file,
        businessId: businessId,
        onProgress: (singleProgress) {
          final overall = (i + singleProgress) / total;
          onProgress(overall.clamp(0.0, 1.0));
        },
      );

      urls.add(url);
      onProgress(((i + 1) / total).clamp(0.0, 1.0));
    }

    return urls;
  }

  /// Canonical content type for a business gallery video object, resolved
  /// from the object's own file name.
  ///
  /// The Firebase SDK's inference is not sufficient for this path.
  /// `putFile` derives the content type from the *local* file's extension
  /// (`StorageUploadTask` calls `MIMETypeForExtension(file?.pathExtension)`),
  /// and no `UTType` maps `.hevc`, so an `.hevc` capture uploads as
  /// `application/octet-stream` — which `storage.rules`'
  /// `hasAllowedBusinessGalleryVideo()` rejects. Declaring the type from
  /// the destination name keeps the client's declaration and the object
  /// name in agreement, which is exactly what that rule requires.
  ///
  /// Returns `null` for anything outside the supported set, so callers fail
  /// closed instead of uploading an object the rules would reject anyway.
  /// The mapping matches `adoptionContentTypeFor` in
  /// `lib/ui/adoption/adoption_upload_helper.dart`.
  static String? videoContentTypeFor(String fileName) {
    final clean = fileName.split('?').first.toLowerCase();
    final dot = clean.lastIndexOf('.');
    if (dot < 0 || dot == clean.length - 1) return null;
    return switch (clean.substring(dot + 1)) {
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'hevc' => 'video/hevc',
      _ => null,
    };
  }

  static Future<void> deleteImageByUrl(String url) async {
    final ref = FirebaseStorage.instance.refFromURL(url);
    await ref.delete();
  }
}
