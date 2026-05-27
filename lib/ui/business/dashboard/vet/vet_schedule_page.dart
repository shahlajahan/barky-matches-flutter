import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class VetSchedulePage extends StatefulWidget {
  final String businessId;

  const VetSchedulePage({super.key, required this.businessId});

  @override
  State<VetSchedulePage> createState() => _VetSchedulePageState();
}

class _VetSchedulePageState extends State<VetSchedulePage> {
  late DateTime _selectedDate;
  late List<DateTime> _visibleDates;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day);
    _visibleDates = List.generate(
      7,
      (index) => _selectedDate.add(Duration(days: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Clinic Schedule'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('vet_appointments')
              .where('businessId', isEqualTo: widget.businessId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _PageMessage(
                icon: LucideIcons.alertCircle,
                title: 'Schedule unavailable',
                message: snapshot.error.toString(),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final appointments = (snapshot.data?.docs ?? [])
                .map((doc) => _VetAppointment.fromDoc(doc.id, doc.data()))
                .toList();

            appointments.sort((a, b) {
              final aDate = a.scheduledAt;
              final bDate = b.scheduledAt;
              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return aDate.compareTo(bDate);
            });

            final today = DateTime.now();
            final todayCount = appointments
                .where((item) => _isSameDay(item.scheduledAt, today))
                .length;
            final pendingCount = appointments
                .where((item) => item.status.toLowerCase() == 'pending')
                .length;
            final confirmedCount = appointments.where((item) {
              final status = item.status.toLowerCase();
              return status == 'confirmed' || status == 'confirmed_paid';
            }).length;
            final completedCount = appointments
                .where((item) => item.status.toLowerCase() == 'completed')
                .length;

            final selectedAppointments = appointments
                .where((item) => _isSameDay(item.scheduledAt, _selectedDate))
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(
                  icon: LucideIcons.calendarDays,
                  title: 'Clinic Schedule',
                  subtitle: 'Manage daily appointments and clinic availability',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Today',
                        value: todayCount.toString(),
                        icon: LucideIcons.calendar,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Pending',
                        value: pendingCount.toString(),
                        icon: LucideIcons.clock,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Confirmed',
                        value: confirmedCount.toString(),
                        icon: LucideIcons.checkCircle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Completed',
                        value: completedCount.toString(),
                        icon: LucideIcons.badgeCheck,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Select Date', style: AppTheme.h2()),
                const SizedBox(height: 10),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _visibleDates.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final date = _visibleDates[index];
                      final selected = _isSameDay(date, _selectedDate);
                      return _DateChip(
                        date: date,
                        selected: selected,
                        onTap: () {
                          setState(() {
                            _selectedDate = date;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Appointments', style: AppTheme.h2()),
                    Text(
                      '${selectedAppointments.length} total',
                      style: AppTheme.caption(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (selectedAppointments.isEmpty)
                  const _PageMessage(
                    icon: LucideIcons.calendarX,
                    title: 'No appointments',
                    message: 'There are no appointments for this date yet.',
                  )
                else
                  ...selectedAppointments.map(
                    (appointment) => _AppointmentCard(appointment: appointment),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _isSameDay(DateTime? first, DateTime second) {
    if (first == null) return false;
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _VetAppointment {
  final String id;
  final String petName;
  final String ownerName;
  final String serviceName;
  final String status;
  final DateTime? scheduledAt;
  final num? amount;

  const _VetAppointment({
    required this.id,
    required this.petName,
    required this.ownerName,
    required this.serviceName,
    required this.status,
    required this.scheduledAt,
    required this.amount,
  });

  factory _VetAppointment.fromDoc(String id, Map<String, dynamic> data) {
    final financial = _asMap(data['financial']);
    final pricing = _asMap(data['pricing']);
    final service = _asMap(data['service']);

    return _VetAppointment(
      id: id,
      petName: _readString(data, const [
        'petName',
        'dogName',
        'patientName',
        'animalName',
      ], 'Unnamed pet'),
      ownerName: _readString(data, const [
        'ownerName',
        'userName',
        'customerName',
      ], 'Owner not set'),
      serviceName: _readString(data, const [
        'serviceName',
        'serviceTitle',
        'appointmentType',
      ], _readString(service, const ['title', 'name'], 'Veterinary visit')),
      status: _readString(data, const ['status'], 'pending'),
      scheduledAt:
          _readDate(data['scheduledAt']) ??
          _readDate(data['scheduledDateTime']) ??
          _readDate(data['appointmentAt']) ??
          _readDate(data['date']),
      amount:
          _readNum(financial['vetNetAmount']) ??
          _readNum(financial['grossAmount']) ??
          _readNum(pricing['total']) ??
          _readNum(data['price']) ??
          _readNum(data['totalAmount']),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HeaderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.cardShadow(opacity: 0.12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.h2(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTheme.caption(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow(opacity: 0.07),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 20, color: AppTheme.card),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTheme.h2()),
                Text(label, style: AppTheme.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  const _DateChip({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.card : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppTheme.card
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: selected ? AppTheme.cardShadow(opacity: 0.12) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekdays[date.weekday - 1],
              style: AppTheme.caption(
                color: selected ? Colors.white70 : AppTheme.muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              date.day.toString(),
              style: AppTheme.h3(
                color: selected ? Colors.white : AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final _VetAppointment appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow(opacity: 0.07),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.card.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(LucideIcons.stethoscope, color: AppTheme.card),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.petName,
                  style: AppTheme.h3(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${appointment.ownerName} • ${appointment.serviceName}',
                  style: AppTheme.caption(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  _formatAppointmentMeta(appointment),
                  style: AppTheme.caption(color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusChip(status: appointment.status),
        ],
      ),
    );
  }

  String _formatAppointmentMeta(_VetAppointment appointment) {
    final time = appointment.scheduledAt == null
        ? 'Time not set'
        : _formatTime(appointment.scheduledAt!);
    final amount = appointment.amount == null
        ? ''
        : ' • ${appointment.amount!.toStringAsFixed(0)} TRY';
    return '$time$amount';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label(status),
        style: AppTheme.caption(color: color, weight: FontWeight.w700),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'confirmed_paid':
        return Colors.green;
      case 'confirmed':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return AppTheme.card;
    }
  }

  String _label(String value) {
    if (value.trim().isEmpty) return 'Pending';
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _PageMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _PageMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow(opacity: 0.06),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: AppTheme.card),
          const SizedBox(height: 12),
          Text(title, style: AppTheme.h3(), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: AppTheme.caption(), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _readString(
  Map<String, dynamic> data,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return fallback;
}

num? _readNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

DateTime? _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
