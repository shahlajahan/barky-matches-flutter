import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/services/image_upload_service.dart';

/// `business_gallery/` had no matching Storage rule and fell through to the
/// deny-all, so every Vet / Groomy / Pet Hotel gallery upload was rejected.
/// Restoring the path required `storage.rules` to check the declared content
/// type, which in turn requires the callers to declare one that agrees with
/// the object name — the Firebase SDK's own inference does not.
void main() {
  group('videoContentTypeFor', () {
    test('maps every extension the dashboards can produce', () {
      expect(ImageUploadService.videoContentTypeFor('a.mp4'), 'video/mp4');
      expect(
        ImageUploadService.videoContentTypeFor('a.mov'),
        'video/quicktime',
      );
      expect(ImageUploadService.videoContentTypeFor('a.webm'), 'video/webm');
      expect(ImageUploadService.videoContentTypeFor('a.hevc'), 'video/hevc');
    });

    test('.hevc resolves rather than falling back to octet-stream', () {
      // The defect this function exists for: no UTType maps `.hevc`, so
      // putFile's own inference declares application/octet-stream, which
      // hasAllowedBusinessGalleryVideo() rejects.
      expect(ImageUploadService.videoContentTypeFor('clip.hevc'), 'video/hevc');
      expect(
        ImageUploadService.videoContentTypeFor('clip.hevc'),
        isNot('application/octet-stream'),
      );
    });

    test('is case-insensitive, matching the Rules extension check', () {
      expect(ImageUploadService.videoContentTypeFor('A.MP4'), 'video/mp4');
      expect(
        ImageUploadService.videoContentTypeFor('A.MoV'),
        'video/quicktime',
      );
      expect(ImageUploadService.videoContentTypeFor('A.HEVC'), 'video/hevc');
    });

    test('resolves against the real dashboard filename shape', () {
      // The tabs build `${millis}_${originalName}`.
      expect(
        ImageUploadService.videoContentTypeFor('1727000000000_my clip.mp4'),
        'video/mp4',
      );
      expect(
        ImageUploadService.videoContentTypeFor('1727000000000_a.b.c.mov'),
        'video/quicktime',
      );
    });

    test('fails closed for unsupported and malformed names', () {
      for (final name in const [
        'a.avi',
        'a.mkv',
        'a.jpg',
        'a.png',
        'a.exe',
        'a.',
        'a',
        '',
        '.mp4x',
        'mp4',
      ]) {
        expect(
          ImageUploadService.videoContentTypeFor(name),
          isNull,
          reason: '"$name"',
        );
      }
    });

    test('never invents a type for an image extension', () {
      // Images belong on the flat business_gallery/{id}/{file} path, which
      // is governed by a separate image-only validator.
      for (final name in const [
        'a.jpg',
        'a.jpeg',
        'a.png',
        'a.webp',
        'a.heic',
      ]) {
        expect(
          ImageUploadService.videoContentTypeFor(name),
          isNull,
          reason: name,
        );
      }
    });
  });
}
