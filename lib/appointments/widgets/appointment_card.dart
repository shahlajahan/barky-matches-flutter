import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appointment_item.dart';

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.item,
  });

  final AppointmentItem item;

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
        onTap: () {
          // TODO:
          // Open Appointment Details
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [

              Row(
                children: [

                  Expanded(
                    child: Text(
                      item.businessName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Text(
                    '${item.price.toStringAsFixed(0)} ₺',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                item.petName,
                style: theme.textTheme.bodyLarge,
              ),

              const SizedBox(height: 6),

              Text(
                item.petType,
                style: theme.textTheme.bodySmall,
              ),

              const SizedBox(height: 14),

              Row(
                children: [

                  const Icon(
                    Icons.schedule,
                    size: 18,
                    color: Colors.grey,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      _formatDate(item.appointmentDate),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }

    return DateFormat(
      'dd MMM yyyy • HH:mm',
    ).format(date);
  }
}