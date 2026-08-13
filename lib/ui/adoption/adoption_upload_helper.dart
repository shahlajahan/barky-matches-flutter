import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

enum AdoptionUploadKind { image, document, media }

class AdoptionUploadException implements Exception {
  final String message;

  const AdoptionUploadException(this.message);

  @override
  String toString() => message;
}

typedef AdoptionStorageUploader =
    Future<String> Function({
      required String storagePath,
      required Uint8List bytes,
      required SettableMetadata metadata,
      void Function(double progress)? onProgress,
    });

const int adoptionMaxDocumentBytes = 25 * 1024 * 1024;
const int adoptionMaxMediaBytes = 100 * 1024 * 1024;

Future<String> uploadAdoptionPickedFile({
  required XFile file,
  required String folderPath,
  required String operation,
  required AdoptionUploadKind kind,
  String? filenameTag,
  void Function(double progress)? onProgress,
  AdoptionStorageUploader uploader = firebaseAdoptionStorageUploader,
}) async {
  final bytes = await file.readAsBytes();
  final contentType = adoptionContentTypeFor(
    file.name,
    reportedMimeType: file.mimeType,
    kind: kind,
  );
  if (contentType == null) {
    throw const AdoptionUploadException('Unsupported file type');
  }

  final maxBytes = kind == AdoptionUploadKind.document
      ? adoptionMaxDocumentBytes
      : adoptionMaxMediaBytes;
  if (bytes.length > maxBytes) {
    throw const AdoptionUploadException('File too large');
  }

  final extension = adoptionExtensionForContentType(contentType);
  final storagePath =
      '${folderPath.replaceAll(RegExp(r'/+$'), '')}/'
      '${DateTime.now().microsecondsSinceEpoch}_'
      '${_safeFilenameTag(filenameTag ?? file.name, extension)}';
  final metadata = SettableMetadata(contentType: contentType);

  try {
    return await uploader(
      storagePath: storagePath,
      bytes: bytes,
      metadata: metadata,
      onProgress: onProgress,
    );
  } catch (error, stackTrace) {
    logAdoptionUploadError(
      operation: operation,
      storagePath: storagePath,
      contentType: contentType,
      fileSize: bytes.length,
      error: error,
      stackTrace: stackTrace,
    );
    throw const AdoptionUploadException(
      'Upload failed. Please try again with a supported file.',
    );
  }
}

Future<String> firebaseAdoptionStorageUploader({
  required String storagePath,
  required Uint8List bytes,
  required SettableMetadata metadata,
  void Function(double progress)? onProgress,
}) async {
  final ref = FirebaseStorage.instance.ref().child(storagePath);
  final task = ref.putData(bytes, metadata);
  if (onProgress != null) {
    task.snapshotEvents.listen((event) {
      if (event.totalBytes <= 0) return;
      onProgress((event.bytesTransferred / event.totalBytes).clamp(0.0, 1.0));
    });
  }
  final snap = await task;
  return snap.ref.getDownloadURL();
}

@visibleForTesting
String? adoptionContentTypeFor(
  String fileName, {
  String? reportedMimeType,
  required AdoptionUploadKind kind,
}) {
  final ext = _extensionFromName(fileName);
  final reported = reportedMimeType?.toLowerCase().trim();
  final byExtension = switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' when kind == AdoptionUploadKind.media => 'image/gif',
    'heic' => 'image/heic',
    'pdf' when kind == AdoptionUploadKind.document => 'application/pdf',
    'mp4' when kind == AdoptionUploadKind.media => 'video/mp4',
    'mov' when kind == AdoptionUploadKind.media => 'video/quicktime',
    'webm' when kind == AdoptionUploadKind.media => 'video/webm',
    'hevc' when kind == AdoptionUploadKind.media => 'video/hevc',
    _ => null,
  };
  if (byExtension == null && ext.isEmpty && reported != null) {
    return _isAllowedReportedContentType(reported, kind) ? reported : null;
  }
  if (byExtension == null) return null;

  if (reported == null || reported.isEmpty) return byExtension;
  if (reported == byExtension) return byExtension;
  if (byExtension == 'image/jpeg' && reported == 'image/jpg') {
    return byExtension;
  }
  return null;
}

bool _isAllowedReportedContentType(
  String contentType,
  AdoptionUploadKind kind,
) {
  return switch (contentType) {
    'image/jpeg' || 'image/png' || 'image/webp' || 'image/heic' => true,
    'image/gif' => kind == AdoptionUploadKind.media,
    'application/pdf' => kind == AdoptionUploadKind.document,
    'video/mp4' ||
    'video/quicktime' ||
    'video/webm' ||
    'video/hevc' => kind == AdoptionUploadKind.media,
    _ => false,
  };
}

@visibleForTesting
String adoptionExtensionForContentType(String contentType) {
  return switch (contentType) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
    'image/heic' => 'heic',
    'application/pdf' => 'pdf',
    'video/mp4' => 'mp4',
    'video/quicktime' => 'mov',
    'video/webm' => 'webm',
    'video/hevc' => 'hevc',
    _ => 'bin',
  };
}

void logAdoptionUploadError({
  required String operation,
  required String storagePath,
  required String contentType,
  required int fileSize,
  required Object error,
  required StackTrace stackTrace,
}) {
  debugPrint(
    'ADOPTION_UPLOAD_FAILED '
    'operation=$operation '
    'platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} '
    'storagePath=$storagePath '
    'contentType=$contentType '
    'fileSize=$fileSize '
    'error=$error',
  );
  debugPrintStack(stackTrace: stackTrace);
}

String _safeFilenameTag(String name, String extension) {
  final base = name
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(RegExp(r'\.[^.]+$'), '')
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final safeBase = base.isEmpty ? 'upload' : base;
  return '$safeBase.$extension';
}

String _extensionFromName(String name) {
  final clean = name.split('?').first.toLowerCase();
  final dot = clean.lastIndexOf('.');
  if (dot < 0 || dot == clean.length - 1) return '';
  return clean.substring(dot + 1);
}
