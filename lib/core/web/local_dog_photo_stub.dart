import 'package:flutter/widgets.dart';

/// Flutter Web: dart:io is unavailable, and a locally-stored dog image path
/// (set when the photo was added on a mobile device) refers to a native
/// filesystem location that has no meaning in a browser sandbox. Never
/// attempt a File lookup here — the caller falls back to network/asset
/// image sources instead of a local file, exactly as it already does when
/// this returns null on other platforms.
Future<ImageProvider?> loadLocalDogPhoto(String path) async => null;
