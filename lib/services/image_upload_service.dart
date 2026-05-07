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
  }) async {
    final compressedBytes = await _compressImage(file);

    final ref = FirebaseStorage.instance
        .ref()
        .child(
          'business_gallery/$businessId/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

    final uploadTask = ref.putData(compressedBytes);

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

  static Future<void> deleteImageByUrl(String url) async {
    final ref = FirebaseStorage.instance.refFromURL(url);
    await ref.delete();
  }
}