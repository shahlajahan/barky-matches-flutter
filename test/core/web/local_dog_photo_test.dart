import 'package:flutter_test/flutter_test.dart';

// Imports the concrete web (stub) implementation directly rather than the
// conditional-import barrel, so this test exercises the exact code path
// Flutter Web uses regardless of which platform runs the test suite. This
// is what fixed the reported Profile-tab crash: dart:io is never touched
// here at all, so a legacy dog document with a mobile-native local file
// path can never throw on Web — it safely resolves to null instead.
import 'package:barky_matches_fixed/core/web/local_dog_photo_stub.dart';

void main() {
  group('loadLocalDogPhoto (Web)', () {
    test(
      'never touches dart:io and resolves null for a legacy mobile-native path',
      () async {
        final result = await loadLocalDogPhoto(
          '/data/user/0/com.example.app/cache/dog_photo_123.jpg',
        );
        expect(result, isNull);
      },
    );

    test('resolves null for an iOS-style native container path', () async {
      final result = await loadLocalDogPhoto(
        '/var/mobile/Containers/Data/Application/ABCD/tmp/photo.png',
      );
      expect(result, isNull);
    });

    test('resolves null for an empty path without throwing', () async {
      final result = await loadLocalDogPhoto('');
      expect(result, isNull);
    });

    test('does not throw for any input — Web Profile navigation must not '
        'invoke native-only file APIs', () async {
      const paths = [
        '/some/native/path.jpg',
        'C:\\Users\\someone\\Pictures\\dog.png',
        'not-a-path-at-all',
      ];
      for (final path in paths) {
        await expectLater(loadLocalDogPhoto(path), completes);
      }
    });
  });
}
