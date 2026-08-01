import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider platformPathImageProvider(String path) {
  final uri = Uri.tryParse(path);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return NetworkImage(path);
  }
  return FileImage(File(path));
}
