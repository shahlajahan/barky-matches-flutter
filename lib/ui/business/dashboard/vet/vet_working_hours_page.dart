import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class VetWorkingHoursPage extends StatefulWidget {
  final String businessId;

  const VetWorkingHoursPage({
    super.key,
    required this.businessId,
  });

  @override
  State<VetWorkingHoursPage> createState() => _VetWorkingHoursPageState();
}

class _VetWorkingHoursPageState extends State<VetWorkingHoursPage> {
  bool _loading = true;
  bool _saving = false;

  final List<Map<String, dynamic>> _days = [
    {'key': 'monday', 'day': 'Monday', 'open': true, 'hours': '09:00 - 18:00'},
    {'key': 'tuesday', 'day': 'Tuesday', 'open': true, 'hours': '09:00 - 18:00'},
    {'key': 'wednesday', 'day': 'Wednesday', 'open': true, 'hours': '09:00 - 18:00'},
    {'key': 'thursday', 'day': 'Thursday', 'open': true, 'hours': '09:00 - 18:00'},
    {'key': 'friday', 'day': 'Friday', 'open': true, 'hours': '09:00 - 18:00'},
    {'key': 'saturday', 'day': 'Saturday', 'open': true, 'hours': '10:00 - 16:00'},
    {'key': 'sunday', 'day': 'Sunday', 'open': false, 'hours': 'Closed'},
  ];

  @override
  void initState() {
    super.initState();
    _loadWorkingHours();
  }

  Future<void> _loadWorkingHours() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .get();

      final data = doc.data() ?? {};
      final sectorData = (data['sectorData'] as Map<String, dynamic>?) ?? {};
      final vetData = (sectorData['vet'] as Map<String, dynamic>?) ??
          (sectorData['veterinarian'] as Map<String, dynamic>?) ??
          {};
      final workingHours =
          (vetData['workingHoursMap'] as Map<String, dynamic>?) ?? {};

      if (workingHours.isNotEmpty) {
        for (final day in _days) {
          final key = day['key'] as String;
          final saved = workingHours[key];

          if (saved is Map<String, dynamic>) {
            day['open'] = saved['open'] == true;
            day['hours'] = (saved['hours'] ?? day['hours']).toString();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Load working hours error: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Load error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveWorkingHours() async {
    if (_saving) return;

    setState(() => _saving = true);

    final workingHoursMap = <String, dynamic>{};

    for (final day in _days) {
      final key = day['key'] as String;

      workingHoursMap[key] = {
        'day': day['day'],
        'open': day['open'] == true,
        'hours': day['hours'],
      };
    }

    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .set({
        'sectorData': {
          'vet': {
            'workingHoursMap': workingHoursMap,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          'veterinarian': {
            'workingHoursMap': workingHoursMap,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Working hours saved')),
      );
    } catch (e, st) {
  debugPrint('❌❌❌ SAVE WORKING HOURS ERROR');
  debugPrint(e.toString());
  debugPrint(st.toString());

  if (e is FirebaseException) {
    debugPrint('🔥 FIREBASE CODE: ${e.code}');
    debugPrint('🔥 FIREBASE MESSAGE: ${e.message}');
    debugPrint('🔥 FIREBASE PLUGIN: ${e.plugin}');
  }

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Save error: $e')),
  );
} finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _toggleDay(Map<String, dynamic> day, bool value) {
    setState(() {
      day['open'] = value;

      if (!value) {
        day['hours'] = 'Closed';
      } else {
        if (day['hours'] == 'Closed') {
          day['hours'] = day['key'] == 'saturday'
              ? '10:00 - 16:00'
              : '09:00 - 18:00';
        }
      }
    });

    _saveWorkingHours();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Working Hours'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveWorkingHours,
            child: Text(
              _saving ? 'Saving...' : 'Save',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Clinic Working Hours',
                    style: AppTheme.h1(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Manage opening days and appointment availability',
                    style: AppTheme.body(),
                  ),
                  const SizedBox(height: 20),

                  ..._days.map(
                    (day) {
                      final isOpen = day['open'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: AppTheme.cardShadow(opacity: 0.06),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                day['day'].toString(),
                                style: AppTheme.h3(),
                              ),
                            ),
                            Text(
                              day['hours'].toString(),
                              style: AppTheme.body(),
                            ),
                            const SizedBox(width: 12),
                            Switch(
                              value: isOpen,
                              activeColor: AppTheme.card,
                              onChanged: (value) {
                                _toggleDay(day, value);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}