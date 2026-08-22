import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/services/appointment_notification_contract.dart';

class AppointmentNotificationDisplay extends StatefulWidget {
  const AppointmentNotificationDisplay({
    super.key,
    required this.notificationId,
    required this.rawType,
    required this.title,
    required this.body,
    required this.builder,
    this.notificationData,
    this.resolveAvailability,
  });

  final String? notificationId;
  final String rawType;
  final String title;
  final String body;
  final Map<String, dynamic>? notificationData;
  final Widget Function(BuildContext context, String title, String body)
  builder;
  final Future<AppointmentNotificationAvailability> Function(
    String notificationId,
  )?
  resolveAvailability;

  @override
  State<AppointmentNotificationDisplay> createState() =>
      _AppointmentNotificationDisplayState();
}

class _AppointmentNotificationDisplayState
    extends State<AppointmentNotificationDisplay> {
  Future<AppointmentNotificationAvailability>? _availabilityFuture;

  @override
  Widget build(BuildContext context) {
    final rawCollection = widget.rawType.trim().toLowerCase();
    final explicitCollection = widget.notificationData?['appointmentCollection']
        ?.toString()
        .trim();
    final isAppointment =
        AppointmentNotificationContract.isAppointmentNotificationType(
          widget.rawType,
        ) ||
        AppointmentNotificationContract.supportedCollections.contains(
          rawCollection,
        ) ||
        AppointmentNotificationContract.supportedCollections.contains(
          explicitCollection,
        );

    if (!isAppointment) {
      return widget.builder(context, widget.title, widget.body);
    }

    final id = widget.notificationId?.trim();
    if (id == null || id.isEmpty) {
      return _unavailable(context);
    }

    return FutureBuilder<AppointmentNotificationAvailability>(
      future: _availabilityFuture ??= _resolveAvailability(id),
      builder: (context, snapshot) {
        switch (snapshot.data) {
          case AppointmentNotificationAvailability.available:
            return widget.builder(context, widget.title, widget.body);
          case AppointmentNotificationAvailability.missing:
          case AppointmentNotificationAvailability.malformed:
            return _unavailable(context);
          case AppointmentNotificationAvailability.unknown:
            return _checkFailed(context);
          case null:
            if (snapshot.hasError) {
              return _checkFailed(context);
            }
            return _checking(context);
        }
      },
    );
  }

  Future<AppointmentNotificationAvailability> _resolveAvailability(
    String notificationId,
  ) async {
    final injected = widget.resolveAvailability;
    if (injected != null) {
      return injected(notificationId);
    }

    final providedData = widget.notificationData;
    if (providedData != null) {
      return AppointmentNotificationContract.availability(
        FirebaseFirestore.instance,
        providedData,
      );
    }

    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .get();
    final data = snap.data();
    if (data == null) return AppointmentNotificationAvailability.malformed;

    return AppointmentNotificationContract.availability(
      FirebaseFirestore.instance,
      data,
    );
  }

  Widget _checking(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return widget.builder(
      context,
      l10n.appointmentTitle,
      l10n.appointmentAvailabilityChecking,
    );
  }

  Widget _checkFailed(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return widget.builder(
      context,
      l10n.appointmentTitle,
      l10n.appointmentAvailabilityCheckFailed,
    );
  }

  Widget _unavailable(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return widget.builder(
      context,
      l10n.appointmentTitle,
      l10n.appointmentNoLongerAvailable,
    );
  }
}
