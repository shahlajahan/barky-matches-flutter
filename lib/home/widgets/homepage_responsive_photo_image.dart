import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Homepage-only image treatment for fixed-height promotional photo cards.
Widget buildHomepageResponsivePhotoImage({
  required String assetPath,
  required Alignment coverAlignment,
}) {
  if (!kIsWeb) {
    return Image.asset(assetPath, fit: BoxFit.cover, alignment: coverAlignment);
  }

  final imageProvider = AssetImage(assetPath);
  return Stack(
    fit: StackFit.expand,
    children: [
      Image(
        image: imageProvider,
        fit: BoxFit.cover,
        alignment: coverAlignment,
        excludeFromSemantics: true,
      ),
      const ColoredBox(color: Color(0x33000000)),
      Image(
        image: imageProvider,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        excludeFromSemantics: true,
      ),
    ],
  );
}
