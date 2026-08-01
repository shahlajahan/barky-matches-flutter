import 'package:flutter/widgets.dart';

import 'platform_path_image_provider.dart';

/// Renders picker paths as browser Blob URLs on Web and local files natively.
class PlatformPathImage extends StatelessWidget {
  const PlatformPathImage({
    required this.path,
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.errorBuilder,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: platformPathImageProvider(path),
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      errorBuilder: errorBuilder,
    );
  }
}
