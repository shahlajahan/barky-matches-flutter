import 'package:flutter/material.dart';

import '../models/appointment_status.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class AppointmentStatusCard extends StatelessWidget {
  const AppointmentStatusCard({
    super.key,
    required this.status,
    required this.onTap,
  });

  final AppointmentStatus status;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _icon(status.type),
                  color: _color(status.type),
                  size: 26,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
  AppLocalizations.of(context)!.appointmentsCount(
    status.count,
  ),
  style: theme.textTheme.bodySmall?.copyWith(
    color: Colors.grey,
  ),
),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(AppointmentStatusType type) {
    switch (type) {
      case AppointmentStatusType.pending:
        return Icons.schedule;

      case AppointmentStatusType.approved:
        return Icons.check_circle;

      case AppointmentStatusType.completed:
        return Icons.task_alt;

      case AppointmentStatusType.cancelled:
        return Icons.cancel;
    }
  }

  Color _color(AppointmentStatusType type) {
    switch (type) {
      case AppointmentStatusType.pending:
        return Colors.orange;

      case AppointmentStatusType.approved:
        return Colors.green;

      case AppointmentStatusType.completed:
        return Colors.blue;

      case AppointmentStatusType.cancelled:
        return Colors.red;
    }
  }
}