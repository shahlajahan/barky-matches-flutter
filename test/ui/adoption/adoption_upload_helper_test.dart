import 'dart:typed_data';

import 'package:barky_matches_fixed/ui/adoption/adoption_upload_helper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('accepts adoption document and media MIME/extension combinations', () {
    expect(
      adoptionContentTypeFor(
        'id.jpg',
        reportedMimeType: 'image/jpeg',
        kind: AdoptionUploadKind.document,
      ),
      'image/jpeg',
    );
    expect(
      adoptionContentTypeFor(
        'income.pdf',
        reportedMimeType: 'application/pdf',
        kind: AdoptionUploadKind.document,
      ),
      'application/pdf',
    );
    expect(
      adoptionContentTypeFor(
        'clip.mov',
        reportedMimeType: 'video/quicktime',
        kind: AdoptionUploadKind.media,
      ),
      'video/quicktime',
    );
  });

  test('rejects unsupported or mismatched adoption upload types', () {
    expect(
      adoptionContentTypeFor(
        'id.exe',
        reportedMimeType: 'application/octet-stream',
        kind: AdoptionUploadKind.document,
      ),
      isNull,
    );
    expect(
      adoptionContentTypeFor(
        'id.jpg',
        reportedMimeType: 'application/pdf',
        kind: AdoptionUploadKind.document,
      ),
      isNull,
    );
    expect(
      adoptionContentTypeFor(
        'clip.mov',
        reportedMimeType: 'video/quicktime',
        kind: AdoptionUploadKind.document,
      ),
      isNull,
    );
  });

  test(
    'uploads selected files as bytes with metadata and preserved path prefix',
    () async {
      late String capturedPath;
      late Uint8List capturedBytes;
      late SettableMetadata capturedMetadata;

      final url = await uploadAdoptionPickedFile(
        file: XFile.fromData(
          Uint8List.fromList([1, 2, 3, 4]),
          name: 'house photo.PNG',
          mimeType: 'image/png',
        ),
        folderPath: 'adoption_requests_uploads/user-123',
        operation: 'test_document_upload',
        kind: AdoptionUploadKind.document,
        filenameTag: 'house',
        uploader:
            ({
              required storagePath,
              required bytes,
              required metadata,
              onProgress,
            }) async {
              capturedPath = storagePath;
              capturedBytes = bytes;
              capturedMetadata = metadata;
              onProgress?.call(1);
              return 'https://cdn.test/file.png';
            },
      );

      expect(url, 'https://cdn.test/file.png');
      expect(capturedBytes, [1, 2, 3, 4]);
      expect(capturedPath, startsWith('adoption_requests_uploads/user-123/'));
      expect(capturedPath, endsWith('_house.png'));
      expect(capturedMetadata.contentType, 'image/png');
    },
  );

  test(
    'rejects files over the adoption document size limit before upload',
    () async {
      var uploadCalled = false;

      await expectLater(
        uploadAdoptionPickedFile(
          file: XFile.fromData(
            Uint8List(adoptionMaxDocumentBytes + 1),
            name: 'income.pdf',
            mimeType: 'application/pdf',
          ),
          folderPath: 'adoption_requests_uploads/user-123',
          operation: 'test_document_upload',
          kind: AdoptionUploadKind.document,
          uploader:
              ({
                required storagePath,
                required bytes,
                required metadata,
                onProgress,
              }) async {
                uploadCalled = true;
                return 'unused';
              },
        ),
        throwsA(isA<AdoptionUploadException>()),
      );

      expect(uploadCalled, isFalse);
    },
  );
}
