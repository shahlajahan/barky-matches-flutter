import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> downloadPayoutBytes({
  required Uint8List bytes,
  required String fileName,
  required String contentType,
}) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String?> downloadPayoutUrl({
  required String url,
  required String fileName,
}) async {
  return null;
}
