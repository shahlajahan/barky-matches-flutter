import 'package:barky_matches_fixed/social/pages/create_social_post_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('uses the Web-selected name instead of a Blob URL', () {
    final file = _TestXFile(
      path: 'blob:https://app.petsupo.com/ba619ca5-9816-4525-af1f-7d0d911a564e',
      name: 'photo.jpg',
    );

    expect(socialMediaExtensionForFile(file, isVideo: false), 'jpg');
  });

  test('uses MIME type when the Web-selected name has no extension', () {
    final file = _TestXFile(
      path: 'blob:https://app.petsupo.com/ba619ca5-9816-4525-af1f-7d0d911a564e',
      name: 'photo',
      mimeType: 'image/png',
    );

    expect(socialMediaExtensionForFile(file, isVideo: false), 'png');
  });

  test('falls back to jpg for an image without usable type information', () {
    final file = _TestXFile(
      path: 'blob:https://app.petsupo.com/ba619ca5-9816-4525-af1f-7d0d911a564e',
      name: 'photo',
    );

    expect(socialMediaExtensionForFile(file, isVideo: false), 'jpg');
  });

  test('falls back to mp4 for a video without usable type information', () {
    final file = _TestXFile(
      path: 'blob:https://app.petsupo.com/ba619ca5-9816-4525-af1f-7d0d911a564e',
      name: 'video',
    );

    expect(socialMediaExtensionForFile(file, isVideo: true), 'mp4');
  });

  test('rejects a malformed extension containing a slash', () {
    final file = _TestXFile(
      path: 'blob:https://app.petsupo.com/ba619ca5-9816-4525-af1f-7d0d911a564e',
      name: 'photo.com/uuid',
    );

    expect(socialMediaExtensionForFile(file, isVideo: false), 'jpg');
  });

  test('uses the selected filename extension for mov', () {
    final file = _TestXFile(path: '/tmp/video-without-extension', name: 'video.mov');

    expect(socialMediaExtensionForFile(file, isVideo: true), 'mov');
  });
}

class _TestXFile extends XFile {
  _TestXFile({required String path, required this.name, this.mimeType})
    : pathValue = path,
      super(path);

  final String pathValue;
  @override
  final String name;
  @override
  final String? mimeType;

  @override
  String get path => pathValue;
}
