// Test-only fake network/cache-manager infrastructure for exercising
// PetploreAvatar (and anything that embeds it) without ever touching a
// real network or the platform's disk cache. Not a production file.
import 'dart:async';
import 'dart:typed_data';

import 'package:file/file.dart' as file_pkg;
import 'package:file/memory.dart' as mem;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal valid 1x1 transparent PNG, used as the "successful load"
/// response body — small enough to inline, but a real decodable image so
/// a success test genuinely proves the image (not just a non-error state)
/// renders.
final Uint8List onePixelPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class FakeAvatarResponse implements FileServiceResponse {
  FakeAvatarResponse({required this.statusCode, Uint8List? bytes})
    : content = Stream.value(bytes ?? Uint8List(0));

  @override
  final Stream<List<int>> content;
  @override
  final int statusCode;
  @override
  int? get contentLength => null;
  @override
  DateTime get validTill => DateTime.now().add(const Duration(minutes: 1));
  @override
  String? get eTag => null;
  @override
  String get fileExtension => '.png';
}

class _FakeAvatarFileService extends FileService {
  _FakeAvatarFileService(this._responder);
  final FutureOr<FakeAvatarResponse> Function(String url) _responder;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    return _responder(url);
  }
}

class _MemoryFileSystemAdapter implements FileSystem {
  _MemoryFileSystemAdapter(this._fs, this._dir);
  final mem.MemoryFileSystem _fs;
  final String _dir;

  @override
  Future<file_pkg.File> createFile(String name) async {
    final f = _fs.file('$_dir/$name');
    await f.create(recursive: true);
    return f;
  }
}

int _keyCounter = 0;

/// Builds a CacheManager backed entirely by in-memory/no-op storage (no
/// sqflite, no path_provider, no real HTTP) whose fetch behavior is fully
/// controlled by [responder]. Each call gets a fresh unique cache key so
/// tests never see stale results from an earlier test's cache entries.
CacheManager fakeAvatarCacheManager(
  FutureOr<FakeAvatarResponse> Function(String url) responder,
) {
  _keyCounter += 1;
  final memFs = mem.MemoryFileSystem();
  return CacheManager(
    Config(
      'petplore-avatar-test-$_keyCounter',
      fileService: _FakeAvatarFileService(responder),
      repo: NonStoringObjectProvider(),
      fileSystem: _MemoryFileSystemAdapter(memFs, '/cache'),
    ),
  );
}

/// A responder that always throws, for proving a code path never attempts
/// a network fetch at all (e.g. empty/null image URLs).
FutureOr<FakeAvatarResponse> neverCalledResponder(String url) {
  throw StateError('No network fetch should have been attempted for $url');
}

/// flutter_cache_manager schedules an internal disk-cleanup Timer on each
/// cache lookup that outlives a single pump/pumpAndSettle cycle. Advancing
/// the (fake-async) clock past its 10s delay lets it fire and clears it,
/// so `AutomatedTestWidgetsFlutterBinding`'s pending-timer check at test
/// teardown doesn't flag it as a leak. Call this once after your final
/// pump in any test that renders a PetploreAvatar with a real image URL.
Future<void> settleAvatarCacheTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 11));
}
