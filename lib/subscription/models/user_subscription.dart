import 'package:cloud_firestore/cloud_firestore.dart';

import 'subscription_plan.dart';
import 'subscription_status.dart';
import 'subscription_source.dart';

class UserSubscription {
  final SubscriptionPlan plan;
  final SubscriptionStatus status;

  final DateTime? startedAt;
  final DateTime? expiresAt;

  final bool autoRenew;

  final SubscriptionSource source;

  final DateTime? lastUpdatedAt;

  const UserSubscription({
    required this.plan,
    required this.status,
    this.startedAt,
    this.expiresAt,
    required this.autoRenew,
    required this.source,
    this.lastUpdatedAt,
  });

  /// Default free subscription
  factory UserSubscription.normal() {
    return const UserSubscription(
      plan: SubscriptionPlan.normal,
      status: SubscriptionStatus.active,
      autoRenew: false,
      source: SubscriptionSource.free,
    );
  }

  /// Parse Firestore subscription map
  factory UserSubscription.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return UserSubscription.normal();
    }

    final plan =
        SubscriptionPlan.fromString(data['plan'] as String?);

    final status =
        SubscriptionStatus.fromString(data['status'] as String?);

    final source =
        SubscriptionSource.fromString(data['source'] as String?);

    return UserSubscription(
      plan: plan,
      status: status,
      startedAt: _parseTimestamp(data['startedAt']),
      expiresAt: _parseTimestamp(data['expiresAt']),
      autoRenew: data['autoRenew'] ?? false,
      source: source,
      lastUpdatedAt: _parseTimestamp(data['lastUpdatedAt']),
    );
  }

  /// Convert model → Firestore
  Map<String, dynamic> toMap() {
    return {
      'plan': plan.toFirestore(),
      'status': status.toFirestore(),
      'startedAt': startedAt,
      'expiresAt': expiresAt,
      'autoRenew': autoRenew,
      'source': source.toFirestore(),
      'lastUpdatedAt': lastUpdatedAt,
    };
  }

  /// Parse Firestore Timestamp safely
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  /// Subscription active state
  bool get isActive {
    return status == SubscriptionStatus.active;
  }

  /// Premium plan
  bool get isPremium {
    return plan == SubscriptionPlan.premium;
  }

  /// Gold plan
  bool get isGold {
    return plan == SubscriptionPlan.gold;
  }

  /// Paid plan
  bool get isPaid {
    return plan.isPaid;
  }

  /// Expiration check
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Copy helper
  UserSubscription copyWith({
    SubscriptionPlan? plan,
    SubscriptionStatus? status,
    DateTime? startedAt,
    DateTime? expiresAt,
    bool? autoRenew,
    SubscriptionSource? source,
    DateTime? lastUpdatedAt,
  }) {
    return UserSubscription(
      plan: plan ?? this.plan,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      autoRenew: autoRenew ?? this.autoRenew,
      source: source ?? this.source,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}