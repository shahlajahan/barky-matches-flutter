import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

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
    if (kDebugMode) {
      debugPrint('📊 Analytics Event -> $name');
      debugPrint('📊 Params -> $parameters');
    }

    await _analytics.logEvent(
      name: name,
      parameters: parameters,
    );

    if (kDebugMode) debugPrint('✅ Analytics Sent');
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('❌ Analytics Error: $e');
      debugPrint('$st');
    }
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
  // ===========================================================================
// Veterinary
// ===========================================================================

static Future<void> vetProfileViewed({
  required String vetId,
}) async {
  await logEvent(
    AnalyticsEvents.vetProfileViewed,
    parameters: {
      AnalyticsParameters.vetId: vetId,
    },
  );
}

static Future<void> vetBookingStarted({
  required String vetId,
  String? appointmentType,
  double? price,
}) async {
  await logEvent(
    AnalyticsEvents.vetBookingStarted,
    parameters: {
      AnalyticsParameters.vetId: vetId,
      if (appointmentType != null)
        AnalyticsParameters.appointmentType: appointmentType,
      if (price != null)
        AnalyticsParameters.price: price,
    },
  );
}

static Future<void> vetBookingCompleted({
  required String vetId,
  String? appointmentType,
  double? price,
}) async {
  await logEvent(
    AnalyticsEvents.vetBookingCompleted,
    parameters: {
      AnalyticsParameters.vetId: vetId,
      if (appointmentType != null)
        AnalyticsParameters.appointmentType: appointmentType,
      if (price != null)
        AnalyticsParameters.price: price,
    },
  );
}

static Future<void> vetBookingCancelled({
  required String vetId,
}) async {
  await logEvent(
    AnalyticsEvents.vetBookingCancelled,
    parameters: {
      AnalyticsParameters.vetId: vetId,
    },
  );
}

static Future<void> vetReviewAdded({
  required String vetId,
  required double rating,
}) async {
  await logEvent(
    AnalyticsEvents.vetReviewAdded,
    parameters: {
      AnalyticsParameters.vetId: vetId,
      AnalyticsParameters.rating: rating,
    },
  );
}

// ===========================================================================
// Grooming
// ===========================================================================

static Future<void> groomingProfileViewed({
  required String groomerId,
}) async {
  await logEvent(
    AnalyticsEvents.groomingProfileViewed,
    parameters: {
      AnalyticsParameters.businessId: groomerId,
    },
  );
}

static Future<void> groomingBookingStarted({
  required String groomerId,
  String? appointmentType,
  double? price,
}) async {
  await logEvent(
    AnalyticsEvents.groomingBookingStarted,
    parameters: {
      AnalyticsParameters.businessId: groomerId,
      if (appointmentType != null)
        AnalyticsParameters.appointmentType: appointmentType,
      if (price != null)
        AnalyticsParameters.price: price,
    },
  );
}

static Future<void> groomingBookingCompleted({
  required String groomerId,
  String? appointmentType,
  double? price,
}) async {
  await logEvent(
    AnalyticsEvents.groomingBookingCompleted,
    parameters: {
      AnalyticsParameters.businessId: groomerId,
      if (appointmentType != null)
        AnalyticsParameters.appointmentType: appointmentType,
      if (price != null)
        AnalyticsParameters.price: price,
    },
  );
}

static Future<void> groomingReviewAdded({
  required String groomerId,
  required double rating,
}) async {
  await logEvent(
    AnalyticsEvents.groomingReviewAdded,
    parameters: {
      AnalyticsParameters.businessId: groomerId,
      AnalyticsParameters.rating: rating,
    },
  );
}

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
