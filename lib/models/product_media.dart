class ProductMedia {
  final String type; // image | video
  final String originalUrl;
  final String? playbackUrl;
  final String? thumbnailUrl;
  final String status;

  ProductMedia({
    required this.type,
    required this.originalUrl,
    this.playbackUrl,
    this.thumbnailUrl,
    required this.status,
  });

  factory ProductMedia.fromJson(Map<String, dynamic> json) {
    return ProductMedia(
      type: json['type'] as String,
      originalUrl: json['originalUrl'] as String,
      playbackUrl: json['playbackUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      status: (json['status'] as String?) ?? 'ready',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'originalUrl': originalUrl,
      'playbackUrl': playbackUrl,
      'thumbnailUrl': thumbnailUrl,
      'status': status,
    };
  }
}