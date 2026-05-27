enum MediaType { image, video }

class MediaItem {
  final String url;
  final MediaType type;

  MediaItem({required this.url, required this.type});

  static bool isVideoUrl(String url) {
    final u = url.toLowerCase();

    return u.contains('.mp4') ||
        u.contains('.mov') ||
        u.contains('.webm') ||
        u.contains('.hevc');
  }

  factory MediaItem.fromUrl(String url) {
    return MediaItem(
      url: url,
      type: isVideoUrl(url) ? MediaType.video : MediaType.image,
    );
  }
}
