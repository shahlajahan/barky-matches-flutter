import 'package:flutter/widgets.dart';

void postFrameLog(String tag, VoidCallback fn) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // زمان دقیق + تگ
    debugPrint('🟨 POST-FRAME RUN: $tag');
    fn();
  });
}
