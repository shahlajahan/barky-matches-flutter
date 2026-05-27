import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/patients/vet_patient_detail_page.dart';

class VetPatientsPage extends StatefulWidget {
  final String businessId;

  const VetPatientsPage({super.key, required this.businessId});

  @override
  State<VetPatientsPage> createState() => _VetPatientsPageState();
}

class _VetPatientsPageState extends State<VetPatientsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _query = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Patients'),
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
              .collection('businesses')
              .doc(widget.businessId)
              .collection('patients')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _CenteredMessage(
                icon: LucideIcons.alertCircle,
                title: 'Patients unavailable',
                message: snapshot.error.toString(),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final patients = (snapshot.data?.docs ?? [])
                .map(
                  (doc) => _PatientRecord.fromDoc(doc.id, {
                    ...doc.data(),
                    'businessId': widget.businessId,
                  }),
                )
                .toList();

            patients.sort((a, b) {
              final aDate =
                  a.lastVisitAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate =
                  b.lastVisitAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });

            final filtered = patients.where((patient) {
              if (_query.isEmpty) return true;
              return patient.petName.toLowerCase().contains(_query) ||
                  patient.ownerName.toLowerCase().contains(_query) ||
                  patient.breed.toLowerCase().contains(_query);
            }).toList();

            final recentVisits = patients.where((patient) {
              final lastVisit = patient.lastVisitAt;
              if (lastVisit == null) return false;
              return DateTime.now().difference(lastVisit).inDays <= 30;
            }).length;

            final followUps = patients
                .where((patient) => patient.needsFollowUp)
                .length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(
                  icon: LucideIcons.heartPulse,
                  title: 'Patients',
                  subtitle: 'View pets and owner records',
                ),
                const SizedBox(height: 16),
                _SearchField(controller: _searchController),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Total Patients',
                        value: patients.length.toString(),
                        icon: LucideIcons.users,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Recent Visits',
                        value: recentVisits.toString(),
                        icon: LucideIcons.history,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SummaryCard(
                  label: 'Follow-ups',
                  value: followUps.toString(),
                  icon: LucideIcons.clipboardList,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Patient Records', style: AppTheme.h2()),
                    Text('${filtered.length} shown', style: AppTheme.caption()),
                  ],
                ),
                const SizedBox(height: 10),
                if (patients.isEmpty)
                  const _CenteredMessage(
                    icon: LucideIcons.folderOpen,
                    title: 'No patient records yet',
                    message:
                        'Patient profiles will appear here after they are added to this clinic.',
                  )
                else if (filtered.isEmpty)
                  const _CenteredMessage(
                    icon: LucideIcons.searchX,
                    title: 'No matching patients',
                    message: 'Try searching by pet, owner, or breed.',
                  )
                else
                  ...filtered.map((patient) => _PatientCard(patient: patient)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PatientRecord {
  final String id;
  final String businessId;
  final String petName;
  final String breed;
  final String ownerName;
  final String notes;
  final DateTime? lastVisitAt;
  final bool needsFollowUp;

  const _PatientRecord({
    required this.id,
    required this.petName,
    required this.breed,
    required this.ownerName,
    required this.notes,
    required this.lastVisitAt,
    required this.businessId,
    required this.needsFollowUp,
  });

  factory _PatientRecord.fromDoc(String id, Map<String, dynamic> data) {
    return _PatientRecord(
      id: id,
      petName: _readString(data, const [
        'petName',
        'name',
        'dogName',
        'patientName',
      ], 'Unnamed pet'),
      businessId: _readString(data, const ['businessId'], ''),
      breed: _readString(data, const [
        'breed',
        'petBreed',
        'dogBreed',
      ], 'Breed not set'),
      ownerName: _readString(data, const [
        'ownerName',
        'guardianName',
        'userName',
      ], 'Owner not set'),
      notes: _readString(data, const [
        'notes',
        'medicalNotes',
        'summary',
      ], 'No medical notes yet'),
      lastVisitAt:
          _readDate(data['lastVisitAt']) ??
          _readDate(data['updatedAt']) ??
          _readDate(data['createdAt']),
      needsFollowUp:
          data['needsFollowUp'] == true || data['followUpRequired'] == true,
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

class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search pet, owner, or breed',
        prefixIcon: const Icon(LucideIcons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: controller.clear,
                tooltip: 'Clear',
              ),
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

class _PatientCard extends StatelessWidget {
  final _PatientRecord patient;

  const _PatientCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),

      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VetPatientDetailPage(
              businessId: patient.businessId,
              patientId: patient.id,
            ),
          ),
        );
      },

      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.cardShadow(opacity: 0.07),
        ),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // PET ICON
            Container(
              width: 48,
              height: 48,

              decoration: BoxDecoration(
                color: AppTheme.card.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),

              child: const Icon(LucideIcons.heartPulse, color: AppTheme.card),
            ),

            const SizedBox(width: 12),

            // CONTENT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // TOP ROW
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          patient.petName,

                          style: AppTheme.h3(),

                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      if (patient.needsFollowUp) const SizedBox(width: 8),

                      if (patient.needsFollowUp)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),

                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),

                            borderRadius: BorderRadius.circular(999),
                          ),

                          child: Text(
                            'Follow-up',

                            style: AppTheme.caption(
                              color: Colors.orange.shade800,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),

                      const SizedBox(width: 8),

                      const Icon(
                        LucideIcons.chevronRight,
                        size: 18,
                        color: Colors.black38,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // BREED + OWNER
                  Text(
                    '${patient.breed} • ${patient.ownerName}',

                    style: AppTheme.caption(),

                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // NOTES
                  Text(
                    patient.notes,

                    style: AppTheme.body(size: 13),

                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 10),

                  // LAST VISIT
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.clock3,
                        size: 14,
                        color: Colors.black54,
                      ),

                      const SizedBox(width: 6),

                      Expanded(
                        child: Text(
                          patient.lastVisitAt == null
                              ? 'Last visit not recorded'
                              : 'Last visit: ${_formatDate(patient.lastVisitAt!)}',

                          style: AppTheme.caption(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _CenteredMessage({
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

DateTime? _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}
