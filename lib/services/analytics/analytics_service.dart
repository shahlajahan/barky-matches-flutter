import 'package:firebase_analytics/firebase_analytics.dart';

import 'analytics_events.dart';
import 'analytics_parameters.dart';

class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static FirebaseAnalytics get instance => _analytics;

  /// Generic event logger.
  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (_) {
      // Analytics should never crash the app.
    }
  }

  // ===========================================================================
  // Authentication
  // ===========================================================================

  static Future<void> userLogin() async {
    await logEvent(AnalyticsEvents.userLogin);
  }

  static Future<void> userSignup() async {
    await logEvent(AnalyticsEvents.userSignup);
  }

  static Future<void> userLogout() async {
    await logEvent(AnalyticsEvents.userLogout);
  }

  static Future<void> guestModeEntered() async {
    await logEvent(AnalyticsEvents.guestModeEntered);
  }

  static Future<void> emailVerified() async {
    await logEvent(AnalyticsEvents.emailVerified);
  }

  // ===========================================================================
// Pet Profile
// ===========================================================================

static Future<void> petCreated({
  required String petType,
  required String breed,
  required int age,
  required String gender,
}) async {
  await logEvent(
    AnalyticsEvents.petCreated,
    parameters: {
      AnalyticsParameters.petType: petType,
      AnalyticsParameters.breed: breed,
      AnalyticsParameters.age: age,
      AnalyticsParameters.gender: gender,
    },
  );
}

static Future<void> petUpdated({
  required String petType,
  required String breed,
  required int age,
  required String gender,
}) async {
  await logEvent(
    AnalyticsEvents.petUpdated,
    parameters: {
      AnalyticsParameters.petType: petType,
      AnalyticsParameters.breed: breed,
      AnalyticsParameters.age: age,
      AnalyticsParameters.gender: gender,
    },
  );
}

static Future<void> petDeleted({
  required String petType,
}) async {
  await logEvent(
    AnalyticsEvents.petDeleted,
    parameters: {
      AnalyticsParameters.petType: petType,
    },
  );
}

static Future<void> petAvatarChanged({
  required String petType,
}) async {
  await logEvent(
    AnalyticsEvents.petAvatarChanged,
    parameters: {
      AnalyticsParameters.petType: petType,
    },
  );
}
  // TODO: pet analytics wrappers

  // ===========================================================================
  // Veterinary
  // ===========================================================================

  // TODO: veterinary analytics wrappers

  // ===========================================================================
  // Grooming
  // ===========================================================================

  // TODO: grooming analytics wrappers

  // ===========================================================================
  // Pet Hotel
  // ===========================================================================

  // TODO: hotel analytics wrappers

  // ===========================================================================
  // Pet Taxi
  // ===========================================================================

  // TODO: taxi analytics wrappers

  // ===========================================================================
  // Adoption
  // ===========================================================================

  // TODO: adoption analytics wrappers

  // ===========================================================================
  // Petplore
  // ===========================================================================

  // TODO: social analytics wrappers

  // ===========================================================================
  // Lost & Found
  // ===========================================================================

  // TODO: lost & found analytics wrappers

  // ===========================================================================
  // Chat
  // ===========================================================================

  // TODO: chat analytics wrappers

  // ===========================================================================
  // Payment
  // ===========================================================================

  // TODO: payment analytics wrappers

  // ===========================================================================
  // Subscription
  // ===========================================================================

  // TODO: subscription analytics wrappers

  // ===========================================================================
  // Business Dashboard
  // ===========================================================================

  // TODO: dashboard analytics wrappers

  // ===========================================================================
  // Notifications
  // ===========================================================================

  // TODO: notification analytics wrappers

  // ===========================================================================
  // Search
  // ===========================================================================

  // TODO: search analytics wrappers

  // ===========================================================================
  // Maps
  // ===========================================================================

  // TODO: maps analytics wrappers

  // ===========================================================================
  // Errors
  // ===========================================================================

  // TODO: error analytics wrappers

  // ===========================================================================
  // Engagement
  // ===========================================================================

  // TODO: engagement analytics wrappers
}