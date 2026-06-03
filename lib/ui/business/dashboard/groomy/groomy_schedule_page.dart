import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class GroomySchedulePage extends StatefulWidget {
  final String businessId;

  const GroomySchedulePage({super.key, required this.businessId});

  @override
  State<GroomySchedulePage> createState() => _GroomySchedulePageState();
}

class _GroomySchedulePageState extends State<GroomySchedulePage> {
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
        title: const Text('Salon Schedule'),

        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),

          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('groomy_appointments')
            .where('businessId', isEqualTo: widget.businessId)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _message(
              icon: LucideIcons.alertCircle,

              title: 'Schedule unavailable',

              text: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final appointments = (snapshot.data?.docs ?? [])
              .map((e) => GroomyAppointment.fromDoc(e.id, e.data()))
              .toList();

          appointments.sort((a, b) {
            if (a.scheduledAt == null && b.scheduledAt == null) {
              return 0;
            }

            if (a.scheduledAt == null) {
              return 1;
            }

            if (b.scheduledAt == null) {
              return -1;
            }

            return a.scheduledAt!.compareTo(b.scheduledAt!);
          });

          final today = DateTime.now();

          final todayCount = appointments.where((e) {
            return _sameDay(e.scheduledAt, today);
          }).length;

          final pendingCount = appointments.where((e) {
            return e.status.toLowerCase() == 'pending';
          }).length;

          final confirmedCount = appointments.where((e) {
            final s = e.status.toLowerCase();

            return s == 'confirmed' || s == 'confirmed_paid';
          }).length;

          final completedCount = appointments.where((e) {
            return e.status.toLowerCase() == 'completed';
          }).length;

          final selected = appointments.where((e) {
            return _sameDay(e.scheduledAt, _selectedDate);
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),

            children: [
              _header(),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _summary(
                      'Today',
                      todayCount.toString(),
                      LucideIcons.calendar,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _summary(
                      'Pending',
                      pendingCount.toString(),
                      LucideIcons.clock,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _summary(
                      'Confirmed',
                      confirmedCount.toString(),
                      LucideIcons.checkCircle,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _summary(
                      'Completed',
                      completedCount.toString(),
                      LucideIcons.badgeCheck,
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

                  separatorBuilder: (_, __) => const SizedBox(width: 10),

                  itemBuilder: (_, index) {
                    final date = _visibleDates[index];

                    final selected = _sameDay(date, _selectedDate);

                    return _dateChip(date, selected);
                  },
                ),
              ),

              const SizedBox(height: 20),

              if (selected.isEmpty)
                _message(
                  icon: LucideIcons.calendarX,

                  title: 'No appointments',

                  text: 'No grooming appointments',
                )
              else
                ...selected.map((e) => appointmentCard(e)),
            ],
          );
        },
      ),
    );
  }

  bool _sameDay(DateTime? a, DateTime b) {
    if (a == null) return false;

    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: AppTheme.card,

        borderRadius: BorderRadius.circular(22),
      ),

      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,

            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),

              borderRadius: BorderRadius.circular(16),
            ),

            child: const Icon(LucideIcons.scissors, color: Colors.white),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text('Salon Schedule', style: AppTheme.h2(color: Colors.white)),

                Text(
                  'Manage grooming appointments',

                  style: AppTheme.caption(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        children: [
          Icon(icon),

          const SizedBox(height: 6),

          Text(value, style: AppTheme.h2()),

          Text(label, style: AppTheme.caption()),
        ],
      ),
    );
  }

  Widget _dateChip(DateTime date, bool selected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
      },

      child: Container(
        width: 68,

        decoration: BoxDecoration(
          color: selected ? AppTheme.card : Colors.white,

          borderRadius: BorderRadius.circular(18),
        ),

        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [Text("${date.day}"), Text("${date.month}/${date.day}")],
          ),
        ),
      ),
    );
  }

  Widget appointmentCard(GroomyAppointment a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          const Icon(LucideIcons.scissors),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(a.petName, style: AppTheme.h3()),

                Text("${a.ownerName} • ${a.serviceName}"),

                Text("${a.amount ?? 0} TRY"),
              ],
            ),
          ),

          Text(a.status),
        ],
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),

      child: Column(children: [Icon(icon), Text(title), Text(text)]),
    );
  }
}

class GroomyAppointment {
  final String id;

  final String petName;

  final String ownerName;

  final String serviceName;

  final String status;

  final DateTime? scheduledAt;

  final num? amount;

  GroomyAppointment({
    required this.id,
    required this.petName,
    required this.ownerName,
    required this.serviceName,
    required this.status,
    required this.scheduledAt,
    required this.amount,
  });

  factory GroomyAppointment.fromDoc(String id, Map<String, dynamic> data) {
    return GroomyAppointment(
      id: id,

      petName: data['petName'] ?? 'Unnamed Pet',

      ownerName: data['ownerName'] ?? 'Unknown Owner',

      serviceName: data['serviceTitle'] ?? 'Grooming Service',

      status: data['status'] ?? 'pending',

      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate(),

      amount: data['paymentAmount'] ?? data['finalPrice'] ?? data['price'],
    );
  }
}
