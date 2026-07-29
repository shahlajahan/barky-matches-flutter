import 'package:flutter/material.dart';

import 'report_model.dart';

/// Client-side mirror of the server's `TARGET_REGISTRY`
/// (functions/src/moderation/targetRegistry.js). Adding a new report target
/// type means adding one entry here (and one on the server) — never an
/// exhaustive switch statement across widgets.
class ReportTargetTypeConfig {
  final String label;
  final IconData icon;

  /// Firestore collection the target document lives in.
  final String collection;

  /// Moderation actions an admin can pick when approving a report against
  /// this target type, keyed the same way the server's action executors are
  /// (e.g. `hide`, `suspend`) -> a short display label. Deliberately excludes
  /// `restore`/`reactivate`: those are a standalone "undo" control shown when
  /// a target is already in a non-active moderation state, not an
  /// approve-time choice.
  final Map<String, String> moderationActions;

  const ReportTargetTypeConfig({
    required this.label,
    required this.icon,
    required this.collection,
    required this.moderationActions,
  });
}

final Map<String, ReportTargetTypeConfig> kReportTargetRegistry = {
  ReportTargetType.dog: const ReportTargetTypeConfig(
    label: 'Dog',
    icon: Icons.pets,
    collection: 'dogs',
    moderationActions: {
      'hide': 'Hide dog',
      'disable_listing': 'Disable adoption listing',
    },
  ),
  ReportTargetType.post: const ReportTargetTypeConfig(
    label: 'Post',
    icon: Icons.image_outlined,
    collection: 'social_posts',
    moderationActions: {'hide': 'Hide post', 'remove': 'Remove post'},
  ),
  ReportTargetType.comment: const ReportTargetTypeConfig(
    label: 'Comment',
    icon: Icons.comment_outlined,
    collection: 'post_comments',
    moderationActions: {'remove': 'Remove comment'},
  ),
  ReportTargetType.business: const ReportTargetTypeConfig(
    label: 'Business',
    icon: Icons.store_outlined,
    collection: 'businesses',
    moderationActions: {
      'disable': 'Disable business',
      'flag': 'Flag for review',
    },
  ),
  ReportTargetType.user: const ReportTargetTypeConfig(
    label: 'User',
    icon: Icons.person_outline,
    collection: 'users',
    moderationActions: {
      'warning': 'Send warning',
      'suspend': 'Suspend account',
      'block': 'Block account',
    },
  ),
};
