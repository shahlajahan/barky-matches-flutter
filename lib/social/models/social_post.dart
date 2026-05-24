import 'package:cloud_firestore/cloud_firestore.dart';

class SocialPostMedia {
  final String url;
  final String type; // image | video
  final String? thumbnailUrl;

  const SocialPostMedia({
    required this.url,
    required this.type,
    this.thumbnailUrl,
  });

  factory SocialPostMedia.fromMap(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['mediaType'] ?? 'image').toString();
    final url =
        (data['url'] ?? data['originalUrl'] ?? data['playbackUrl'] ?? '')
            .toString();

    return SocialPostMedia(
      url: url,
      type: type == 'video' ? 'video' : 'image',
      thumbnailUrl:
          (data['thumbnailUrl'] ?? data['thumbnail'] ?? data['coverUrl'])
              ?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'type': type,
      if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
        'thumbnailUrl': thumbnailUrl,
    };
  }

  bool get isVideo => type == 'video';

  String get previewUrl {
    if (isVideo && thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return thumbnailUrl!;
    }

    return url;
  }
}

class SocialPost {
  final String id;
  final String userId;

  final String? petId;

  final String? username;
  final String? userPhotoUrl;

  final String? petName;
  final String? petImageUrl;

  final List<SocialPostMedia> media;
  final List<String> mediaUrls;

  /// image | video
  final String mediaType;

  final String caption;

  final DateTime createdAt;

  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int saveCount;
  final int viewCount;

  /// public / private
  final String visibility;

  /// active / hidden / flagged
  final String moderationStatus;

  final bool isHidden;

  final int reportCount;

  final List<String> tags;

  const SocialPost({
    required this.id,
    required this.userId,
    this.petId,
    this.username,
    this.userPhotoUrl,
    this.petName,
    this.petImageUrl,
    required this.media,
    required this.mediaUrls,
    required this.mediaType,
    required this.caption,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.saveCount,
    required this.viewCount,
    required this.visibility,
    required this.moderationStatus,
    required this.isHidden,
    required this.reportCount,
    required this.tags,
  });

  factory SocialPost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final media = _parseMedia(data);
    final mediaUrls = media.isNotEmpty
        ? media.map((item) => item.url).where((url) => url.isNotEmpty).toList()
        : data['mediaUrls'] != null
        ? List<String>.from(data['mediaUrls'])
        : data['media'] is String
        ? [data['media'].toString()]
        : <String>[];

    return SocialPost(
      id: doc.id,
      userId: data['userId'] ?? '',

      petId: data['petId'],

      username: data['username'] ?? data['userName'],
      userPhotoUrl: data['userPhotoUrl'] ?? data['userPhoto'],

      petName: data['petName'],
      petImageUrl: data['petImageUrl'],

      media: media.isNotEmpty
          ? media
          : mediaUrls
                .map(
                  (url) => SocialPostMedia(
                    url: url,
                    type: (data['mediaType'] ?? 'image').toString(),
                    thumbnailUrl: data['thumbnailUrl']?.toString(),
                  ),
                )
                .toList(),
      mediaUrls: mediaUrls,

      mediaType:
          data['mediaType'] ??
          (media.any((item) => item.isVideo) ? 'mixed' : 'image'),

      caption: data['caption'] ?? '',

      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),

      likeCount: data['likeCount'] ?? data['likesCount'] ?? 0,
      commentCount: data['commentCount'] ?? data['commentsCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      saveCount: data['saveCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,

      visibility: data['visibility'] ?? 'public',

      moderationStatus: data['moderationStatus'] ?? 'active',

      isHidden: data['isHidden'] ?? false,

      reportCount: data['reportCount'] ?? 0,

      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,

      'petId': petId,

      'username': username,
      'userPhotoUrl': userPhotoUrl,
      'userPhoto': userPhotoUrl,

      'petName': petName,
      'petImageUrl': petImageUrl,

      'mediaUrls': mediaUrls,
      'media': media.map((item) => item.toMap()).toList(),
      'thumbnailUrl': _firstThumbnailUrl(media),

      'mediaType': mediaType,

      'caption': caption,

      'createdAt': Timestamp.fromDate(createdAt),

      'likeCount': likeCount,
      'likesCount': likeCount,
      'commentCount': commentCount,
      'commentsCount': commentCount,
      'shareCount': shareCount,
      'saveCount': saveCount,
      'viewCount': viewCount,

      'visibility': visibility,

      'moderationStatus': moderationStatus,

      'isHidden': isHidden,

      'reportCount': reportCount,

      'tags': tags,
    };
  }

  static String? _firstThumbnailUrl(List<SocialPostMedia> media) {
    for (final item in media) {
      final thumbnailUrl = item.thumbnailUrl;
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        return thumbnailUrl;
      }
    }

    return null;
  }

  static List<SocialPostMedia> _parseMedia(Map<String, dynamic> data) {
    final rawMedia = data['media'];

    if (rawMedia is List) {
      return rawMedia
          .whereType<Map>()
          .map(
            (item) => SocialPostMedia.fromMap(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.url.isNotEmpty)
          .toList();
    }

    return [];
  }

  SocialPost copyWith({
    String? id,
    String? userId,
    String? petId,
    String? username,
    String? userPhotoUrl,
    String? petName,
    String? petImageUrl,
    List<SocialPostMedia>? media,
    List<String>? mediaUrls,
    String? mediaType,
    String? caption,
    DateTime? createdAt,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? saveCount,
    int? viewCount,
    String? visibility,
    String? moderationStatus,
    bool? isHidden,
    int? reportCount,
    List<String>? tags,
  }) {
    return SocialPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      petId: petId ?? this.petId,
      username: username ?? this.username,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      petName: petName ?? this.petName,
      petImageUrl: petImageUrl ?? this.petImageUrl,
      media: media ?? this.media,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      saveCount: saveCount ?? this.saveCount,
      viewCount: viewCount ?? this.viewCount,
      visibility: visibility ?? this.visibility,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      isHidden: isHidden ?? this.isHidden,
      reportCount: reportCount ?? this.reportCount,
      tags: tags ?? this.tags,
    );
  }
}
