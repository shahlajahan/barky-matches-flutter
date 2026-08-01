import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:barky_matches_fixed/ui/common/platform_path_image_provider.dart';

/// iOS/Android/desktop: a dog's stored image path may be a real local file
/// (set when the photo was added on-device). Byte-for-byte the same check
/// this codebase always did before this file existed — see
/// UserProfilePage._loadProfileImage in lib/user_profile_page.dart.
Future<ImageProvider?> loadLocalDogPhoto(String path) async {
  final file = File(path);
  if (await file.exists()) return platformPathImageProvider(file.path);
  return null;
}
