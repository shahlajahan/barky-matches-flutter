import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// A safe circular avatar for Petplore surfaces (feed, comments, stories,
/// search, profile, followers/following).
///
/// Renders [imageUrl] through `CachedNetworkImage` with an explicit error
/// boundary. Any load failure — missing, empty, malformed, or a non-2xx
/// HTTP response such as the Firebase Storage 403 returned once a
/// download token is revoked/expired — falls back to a neutral icon
/// instead of throwing an unhandled `FlutterError` or leaving an
/// unexplained blank circle. `CircleAvatar.backgroundImage` has no error
/// callback at all, which is what let that 403 escape as an unhandled
/// exception on every feed rebuild before this widget existed.
class PetploreAvatar extends StatelessWidget {
  const PetploreAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 20,
    this.backgroundColor = Colors.white12,
    this.icon = LucideIcons.dog,
    this.iconColor = Colors.white70,
    this.iconSize,
    this.semanticLabel = 'User avatar',
    this.cacheManager,
  });

  final String? imageUrl;
  final double radius;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final double? iconSize;
  final String semanticLabel;

  /// Overridable for tests only (a controlled fake image server/cache
  /// manager), so tests never hit the real network. Production call
  /// sites never pass this; `CachedNetworkImage` uses its default
  /// singleton cache manager when null.
  final BaseCacheManager? cacheManager;

  bool get _hasUrl {
    final url = imageUrl;
    return url != null && url.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;

    return Semantics(
      label: semanticLabel,
      image: true,
      child: ClipOval(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: ColoredBox(
            color: backgroundColor,
            child: _hasUrl
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    cacheManager: cacheManager,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    // No `placeholder` builder: the ColoredBox behind this
                    // already shows a neutral circle while loading, and
                    // only the confirmed-failure state needs the explicit
                    // icon fallback below (matches the proven pattern
                    // already used by PetploreStoriesBar).
                    errorWidget: (context, url, error) => _fallbackIcon(),
                  )
                : _fallbackIcon(),
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Center(
      child: Icon(icon, color: iconColor, size: iconSize ?? radius),
    );
  }
}
