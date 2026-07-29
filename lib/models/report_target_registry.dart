import 'package:flutter/material.dart';

import 'report_model.dart';

/// What a target's document resolves to for display purposes.
class ReportTargetDisplay {
  final String name;
  final String? imageUrl;

  const ReportTargetDisplay({required this.name, this.imageUrl});
}

/// Client-side mirror of the server's `TARGET_REGISTRY`
/// (functions/src/moderation/targetRegistry.js). Adding a new report target
/// type means adding one entry here (and one on the server) — never an
/// exhaustive switch statement across widgets or services.
class ReportTargetTypeConfig {
  final String label;
  final IconData icon;

  /// Firestore collection the target document lives in.
  final String collection;

  /// Moderation actions an admin can pick when approving a report against
  /// this target type, keyed the same way the server's action executors are
  /// (e.g. `hide`, `suspend`) -> a short display label. Deliberately excludes
  /// `restore`: that's a standalone "undo" control shown when a target is
  /// already in a non-active moderation state, not an approve-time choice.
  final Map<String, String> moderationActions;

  /// Extracts a human-readable name + image from the target's raw Firestore
  /// data, so the admin card never has to show a raw document ID.
  final ReportTargetDisplay Function(Map<String, dynamic> data) resolveDisplay;

  /// Extracts the uid of the target's owner/author, or null if the target
  /// document IS a user (no separate "owner" concept applies).
  final String? Function(Map<String, dynamic> data) resolveOwnerId;

  /// Whether the target is currently in a non-active moderation state
  /// (hidden/restricted/removed/suspended/blocked/flagged), used to decide
  /// whether to show the generic "Restore" control.
  final bool Function(Map<String, dynamic> data) isModerated;

  const ReportTargetTypeConfig({
    required this.label,
    required this.icon,
    required this.collection,
    required this.moderationActions,
    required this.resolveDisplay,
    required this.resolveOwnerId,
    required this.isModerated,
  });
}

String? _firstNonEmpty(List<dynamic>? list) {
  if (list == null || list.isEmpty) return null;
  final first = list.first;
  return first?.toString();
}

final Map<String, ReportTargetTypeConfig> kReportTargetRegistry = {
  ReportTargetType.dog: ReportTargetTypeConfig(
    label: 'Dog',
    icon: Icons.pets,
    collection: 'dogs',
    moderationActions: const {
      'hide': 'Hide dog',
      'disable_listing': 'Disable adoption listing',
    },
    resolveDisplay: (data) => ReportTargetDisplay(
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name']
          : 'Unnamed dog',
      imageUrl: _firstNonEmpty(data['imagePaths'] as List?),
    ),
    resolveOwnerId: (data) =>
        (data['ownerUid'] ?? data['ownerId']) as String?,
    isModerated: (data) =>
        data['isHidden'] == true ||
        data['moderationStatus'] == 'hidden' ||
        data['moderationStatus'] == 'restricted' ||
        data['isAvailableForAdoption'] == false,
  ),
  ReportTargetType.post: ReportTargetTypeConfig(
    label: 'Post',
    icon: Icons.image_outlined,
    collection: 'social_posts',
    moderationActions: const {'hide': 'Hide post', 'remove': 'Remove post'},
    resolveDisplay: (data) => ReportTargetDisplay(
      name: (data['caption'] as String?)?.trim().isNotEmpty == true
          ? data['caption']
          : 'Post by ${data['username'] ?? 'user'}',
      imageUrl:
          _firstNonEmpty(data['mediaUrls'] as List?) ??
          data['thumbnailUrl'] as String?,
    ),
    resolveOwnerId: (data) => data['userId'] as String?,
    isModerated: (data) =>
        data['isHidden'] == true || data['moderationStatus'] == 'removed',
  ),
  ReportTargetType.comment: ReportTargetTypeConfig(
    label: 'Comment',
    icon: Icons.comment_outlined,
    collection: 'post_comments',
    moderationActions: const {'remove': 'Remove comment'},
    resolveDisplay: (data) => ReportTargetDisplay(
      name: (data['text'] as String?)?.trim().isNotEmpty == true
          ? data['text']
          : '(empty comment)',
      imageUrl: data['userPhotoUrl'] as String?,
    ),
    resolveOwnerId: (data) => data['userId'] as String?,
    isModerated: (data) =>
        data['isHidden'] == true || data['moderationStatus'] == 'removed',
  ),
  ReportTargetType.business: ReportTargetTypeConfig(
    label: 'Business',
    icon: Icons.store_outlined,
    collection: 'businesses',
    moderationActions: const {
      'disable': 'Disable business',
      'flag': 'Flag for review',
    },
    resolveDisplay: (data) => ReportTargetDisplay(
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name']
          : 'Unnamed business',
      imageUrl: data['logoUrl'] as String?,
    ),
    resolveOwnerId: (data) => data['ownerUid'] as String?,
    isModerated: (data) =>
        data['status'] == 'suspended' ||
        (data['moderation'] as Map?)?['status'] == 'flagged',
  ),
  ReportTargetType.user: ReportTargetTypeConfig(
    label: 'User',
    icon: Icons.person_outline,
    collection: 'users',
    moderationActions: const {
      'warning': 'Send warning',
      'suspend': 'Suspend account',
      'block': 'Block account',
    },
    resolveDisplay: (data) => ReportTargetDisplay(
      name:
          (data['username'] ?? data['name'] ?? data['displayName'])
              as String? ??
          'User',
      imageUrl: (data['photoUrl'] ?? data['profileImageUrl']) as String?,
    ),
    resolveOwnerId: (_) => null,
    isModerated: (data) =>
        data['accountStatus'] == 'suspended' ||
        data['accountStatus'] == 'blocked',
  ),
};
