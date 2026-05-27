import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/patients/edit_visit_page.dart';
import 'package:barky_matches_fixed/constants/vaccine_catalog.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/patients/edit_medical_profile_page.dart';

class PetVaccineRecord {
  final String id;
  final String name;
  final String? catalogId;
  final List<String> petTypes;
  final String? notes;
  final DateTime? date;
  final DateTime? nextDueDate;
  final String? vetId;
  final String? vetName;
  final String status;
  final int? recurrenceDays;
  final bool reminderEnabled;

  final DateTime? completedAt;

  PetVaccineRecord({
    required this.id,
    required this.name,
    this.catalogId,
    this.petTypes = const [],
    this.notes,
    this.date,
    this.nextDueDate,
    this.vetId,
    this.vetName,
    this.status = 'upcoming',
    this.recurrenceDays,
    this.reminderEnabled = true,

    this.completedAt,
  });

  factory PetVaccineRecord.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final petTypesRaw = data['petTypes'];
    final recurrenceRaw = data['recurrenceDays'] ?? data['intervalDays'];

    return PetVaccineRecord(
      id: doc.id,
      name: data['name'] ?? '',
      catalogId: data['catalogId']?.toString(),
      petTypes: petTypesRaw is List
          ? petTypesRaw.map((e) => e.toString()).toList()
          : const [],
      notes: data['notes'],

      date: data['date'] != null ? (data['date'] as Timestamp).toDate() : null,

      nextDueDate: data['nextDueDate'] != null
          ? (data['nextDueDate'] as Timestamp).toDate()
          : null,

      vetId: data['vetId'],
      vetName: data['vetName'],
      status: data['status'] ?? 'upcoming',
      recurrenceDays: recurrenceRaw is int
          ? recurrenceRaw
          : int.tryParse(recurrenceRaw?.toString() ?? ''),
      reminderEnabled: data['reminderEnabled'] != false,

      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class VetPatientDetailPage extends StatefulWidget {
  final String businessId;
  final String patientId;
  final Map<String, dynamic>? patientData;

  const VetPatientDetailPage({
    super.key,
    required this.businessId,
    required this.patientId,
    this.patientData,
  });

  @override
  State<VetPatientDetailPage> createState() => _VetPatientDetailPageState();
}

class _VetPatientDetailPageState extends State<VetPatientDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<PetVaccineRecord> _vaccines = [];

  bool _loadingVaccines = false;

  final _vaccineNameController = TextEditingController();

  final _vaccineNotesController = TextEditingController();

  DateTime? _vaccineDate;
  DateTime? _nextDueDate;
  bool _vaccineReminderEnabled = true;

  bool get _isOwnerView => widget.businessId == 'owner_medical_record';

  // TODO: medications should be stored in patients/{patientId}/medications
  // TODO: lab results should be stored in patients/{patientId}/lab_results
  // TODO: documents/xray/pdf should be stored in patients/{patientId}/documents

  VaccineCatalogItem? selectedCatalogItem;

  @override
  void initState() {
    super.initState();
    _loadVaccines();

    _tabController = TabController(length: 4, vsync: this);

    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _openAddVaccineDialog() async {
    _vaccineNameController.clear();
    _vaccineNotesController.clear();
    selectedCatalogItem = null;
    _vaccineDate = DateTime.now();
    _nextDueDate = null;
    _vaccineReminderEnabled = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate({
              required DateTime? initialDate,
              required DateTime firstDate,
              required ValueChanged<DateTime> onPicked,
            }) async {
              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate ?? DateTime.now(),
                firstDate: firstDate,
                lastDate: DateTime(2035),
              );

              if (picked == null || !context.mounted) return;
              setModalState(() => onPicked(picked));
            }

            Widget datePickerTile({
              required String label,
              required String emptyText,
              required DateTime? value,
              required VoidCallback onTap,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTheme.body(weight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onTap,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.calendar,
                            color: AppTheme.card,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              value == null ? emptyText : _formatDate(value),
                              style: AppTheme.body(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.82,
                  minChildSize: 0.45,
                  maxChildSize: 0.95,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 42,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text('Add Vaccine', style: AppTheme.h2()),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<VaccineCatalogItem>(
                              initialValue: selectedCatalogItem,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Vaccine',
                                filled: true,
                                fillColor: AppTheme.bg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: VaccineCatalog.byPetType('dog').map((
                                item,
                              ) {
                                return DropdownMenuItem(
                                  value: item,
                                  child: Text(
                                    item.localizedName('en'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setModalState(() {
                                  selectedCatalogItem = value;

                                  if (value != null) {
                                    _vaccineNameController.text = value
                                        .localizedName('en');
                                    final baseDate =
                                        _vaccineDate ?? DateTime.now();
                                    _nextDueDate = baseDate.add(
                                      Duration(days: value.defaultIntervalDays),
                                    );
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _vaccineNotesController,
                              maxLines: 3,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: 'Notes',
                                filled: true,
                                fillColor: AppTheme.bg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            datePickerTile(
                              label: 'Vaccine Date',
                              emptyText: 'Select vaccine date',
                              value: _vaccineDate,
                              onTap: () {
                                pickDate(
                                  initialDate: _vaccineDate,
                                  firstDate: DateTime(2020),
                                  onPicked: (date) {
                                    _vaccineDate = date;
                                    if (selectedCatalogItem != null) {
                                      _nextDueDate = date.add(
                                        Duration(
                                          days: selectedCatalogItem!
                                              .defaultIntervalDays,
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            datePickerTile(
                              label: 'Next Due Date',
                              emptyText: 'Select next due date',
                              value: _nextDueDate,
                              onTap: () {
                                pickDate(
                                  initialDate: _nextDueDate,
                                  firstDate: DateTime.now(),
                                  onPicked: (date) {
                                    _nextDueDate = date;
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.bg,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _vaccineReminderEnabled,
                                activeThumbColor: AppTheme.card,
                                title: Text(
                                  'Reminder',
                                  style: AppTheme.body(weight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  'Notify before the next due date',
                                  style: AppTheme.caption(),
                                ),
                                onChanged: (value) {
                                  setModalState(() {
                                    _vaccineReminderEnabled = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.card,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () async {
                                  await _saveVaccine();

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                                child: const Text('Save Vaccine'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveVaccine() async {
    try {
      debugPrint('💉 SAVE VACCINE START');

      final patientRef = FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .collection('patients')
          .doc(widget.patientId);
      final patientData = await _loadPatientMirrorData(patientRef);
      final vaccineRef = patientRef.collection('vaccines').doc();
      final vaccineData = {
        'name':
            selectedCatalogItem?.localizedName('en') ??
            _vaccineNameController.text.trim(),
        'catalogId': selectedCatalogItem?.id,
        'petTypes': selectedCatalogItem?.petTypes ?? [],
        'frequencyType': selectedCatalogItem?.frequencyType,
        'intervalDays': selectedCatalogItem?.defaultIntervalDays,
        'notes': _vaccineNotesController.text.trim(),
        'date': Timestamp.fromDate(_vaccineDate ?? DateTime.now()),
        'nextDueDate': _nextDueDate != null
            ? Timestamp.fromDate(_nextDueDate!)
            : null,
        'reminderEnabled': _vaccineReminderEnabled,
        'status': 'upcoming',
        'completedAt': null,
        'businessId': widget.businessId,
        'patientId': widget.patientId,
        'ownerId': patientData['ownerId'],
        'createdByBusinessId': widget.businessId,
        'createdByVetId': _currentVetId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await vaccineRef.set(vaccineData);

      await _mirrorDogVaccineSet(
        patientData: patientData,
        vaccineId: vaccineRef.id,
        data: vaccineData,
        successLog: '💉 DOG VACCINE MIRROR CREATED',
      );

      debugPrint('💉 VACCINE SAVE SUCCESS');

      await _loadVaccines();
    } catch (e) {
      debugPrint('❌ SAVE VACCINE ERROR: $e');
    }
  }

  Future<void> _loadVaccines() async {
    try {
      setState(() {
        _loadingVaccines = true;
      });

      final snapshot = await _patientRef
          .collection('vaccines')
          .orderBy('date', descending: true)
          .get();

      final vaccines = snapshot.docs
          .map((e) => PetVaccineRecord.fromDoc(e))
          .toList();

      if (!mounted) return;

      setState(() {
        _vaccines = vaccines;
        _loadingVaccines = false;
      });

      debugPrint('💉 VACCINES LOADED → ${vaccines.length}');
    } catch (e) {
      debugPrint('❌ LOAD VACCINES ERROR: $e');

      if (!mounted) return;

      setState(() {
        _loadingVaccines = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();

    _vaccineNameController.dispose();
    _vaccineNotesController.dispose();

    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _patientRef {
    if (widget.businessId == 'owner_medical_record') {
      return FirebaseFirestore.instance
          .collection('dogs')
          .doc(widget.patientId);
    }

    return FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.businessId)
        .collection('patients')
        .doc(widget.patientId);
  }

  Future<void> _openEditVisit({
    String? visitId,
    Map<String, dynamic>? visitData,
  }) async {
    debugPrint('🩺 OPEN EDIT VISIT');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditVisitPage(
          businessId: widget.businessId,
          patientId: widget.patientId,
          visitId: visitId,
          initialData: visitData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,

      floatingActionButton: !_isOwnerView && _tabController.index == 2
          ? FloatingActionButton(
              backgroundColor: AppTheme.card,

              onPressed: () async {
                await _openAddVaccineDialog();
              },

              child: const Icon(LucideIcons.plus, color: Colors.white),
            )
          : null,

      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _patientRef.snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();

          if (data == null) {
            return const Center(child: Text('Patient not found'));
          }

          final petName = _readPetName(data);

          final breed = data['breed'] ?? 'Breed not set';

          final ownerName = data['ownerName'] ?? 'Owner';

          final notes = data['notes'] ?? '';

          return Column(
            children: [
              // HEADER
              Container(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),

                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),

                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },

                          child: const Icon(
                            LucideIcons.arrowLeft,
                            color: Colors.white,
                          ),
                        ),

                        const Spacer(),

                        if (!_isOwnerView)
                          GestureDetector(
                            onTap: () async {
                              // BASIC TAB
                              if (_tabController.index == 0) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditMedicalProfilePage(
                                      businessId: widget.businessId,
                                      patientId: widget.patientId,
                                      initialData: data,
                                    ),
                                  ),
                                );

                                return;
                              }

                              // VISITS TAB
                              if (_tabController.index == 1) {
                                await _openEditVisit();
                                return;
                              }

                              // VACCINES TAB
                              if (_tabController.index == 2) {
                                await _openAddVaccineDialog();
                                return;
                              }

                              // NOTES TAB
                              if (_tabController.index == 3) {
                                await _openEditMedicalNotesDialog(
                                  currentNotes: notes,
                                );

                                return;
                              }
                            },

                            child: const Icon(
                              LucideIcons.edit2,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Container(
                      width: 82,
                      height: 82,

                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),

                        shape: BoxShape.circle,
                      ),

                      child: const Icon(
                        LucideIcons.heartPulse,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(petName, style: AppTheme.h1(color: Colors.white)),

                    const SizedBox(height: 6),

                    Text(
                      '$breed • $ownerName',
                      style: AppTheme.caption(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      height: 50,

                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),

                        borderRadius: BorderRadius.circular(18),
                      ),

                      child: TabBar(
                        controller: _tabController,

                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),

                        labelColor: AppTheme.card,
                        unselectedLabelColor: Colors.white,

                        dividerColor: Colors.transparent,

                        tabs: const [
                          Tab(text: 'Basic'),
                          Tab(text: 'Visits'),
                          Tab(text: 'Vaccines'),
                          Tab(text: 'Notes'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,

                  children: [
                    // BASIC
                    ListView(
                      padding: const EdgeInsets.all(16),

                      children: [
                        _InfoCard(
                          title: 'Pet Information',
                          children: [
                            _InfoRow(label: 'Pet Name', value: petName),

                            _InfoRow(
                              label: 'Species',
                              value: data['petType'] ?? 'Dog',
                            ),

                            _InfoRow(label: 'Breed', value: breed),

                            _InfoRow(
                              label: 'Gender',
                              value: data['gender'] ?? '-',
                            ),

                            _InfoRow(
                              label: 'Age',
                              value: '${data['age'] ?? '-'}',
                            ),

                            _InfoRow(
                              label: 'Weight',
                              value: data['weight']?.toString() ?? '-',
                            ),

                            _InfoRow(
                              label: 'Microchip',
                              value: data['microchipNumber'] ?? '-',
                            ),

                            _InfoRow(
                              label: 'Blood Type',
                              value: data['bloodType'] ?? '-',
                            ),

                            _InfoRow(
                              label: 'Allergies',
                              value: data['allergies'] ?? '-',
                            ),

                            _InfoRow(
                              label: 'Chronic Diseases',
                              value: data['chronicDiseases'] ?? '-',
                            ),

                            _InfoRow(label: 'Owner', value: ownerName),

                            _InfoRow(
                              label: 'Last Medical Update',
                              value: _formatTimestamp(
                                data['medicalProfileUpdatedAt'],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // VISITS
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _patientRef
                          .collection('visits')
                          .orderBy('visitDate', descending: true)
                          .snapshots(),

                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snapshot.data!.docs;

                        if (docs.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.all(16),

                            children: const [
                              _EmptyState(
                                icon: LucideIcons.clipboardList,
                                title: 'No visits yet',
                                subtitle:
                                    'Medical visit history will appear here.',
                              ),
                            ],
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),

                          itemCount: docs.length,

                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),

                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final visitId = docs[index].id;

                            final title = data['title'] ?? 'Visit';

                            final summary =
                                data['description'] ?? data['summary'] ?? '';

                            final diagnosis =
                                data['medicalNotes'] ?? data['diagnosis'] ?? '';

                            final treatment =
                                data['prescription'] ?? data['treatment'] ?? '';

                            final followUp =
                                data['followUpRequired'] == true ||
                                data['followUpDate'] != null;

                            final visitDate = data['visitDate'] is Timestamp
                                ? (data['visitDate'] as Timestamp).toDate()
                                : null;

                            return Container(
                              padding: const EdgeInsets.all(18),

                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),

                                boxShadow: AppTheme.cardShadow(opacity: 0.06),
                              ),

                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,

                                        decoration: BoxDecoration(
                                          color: AppTheme.card.withValues(
                                            alpha: 0.1,
                                          ),

                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),

                                        child: const Icon(
                                          LucideIcons.stethoscope,
                                          color: AppTheme.card,
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,

                                          children: [
                                            Text(title, style: AppTheme.h3()),

                                            const SizedBox(height: 4),

                                            Text(
                                              visitDate == null
                                                  ? 'Date not recorded'
                                                  : _formatDate(visitDate),

                                              style: AppTheme.caption(),
                                            ),
                                          ],
                                        ),
                                      ),

                                      if (followUp)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),

                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(
                                              alpha: 0.12,
                                            ),

                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),

                                          child: Text(
                                            'Follow-up',

                                            style: AppTheme.caption(
                                              color: Colors.orange.shade800,

                                              weight: FontWeight.w700,
                                            ),
                                          ),
                                        ),

                                      if (!_isOwnerView)
                                        IconButton(
                                          tooltip: 'Edit visit',
                                          onPressed: () => _openEditVisit(
                                            visitId: visitId,
                                            visitData: data,
                                          ),
                                          icon: const Icon(
                                            LucideIcons.edit2,
                                            color: AppTheme.card,
                                            size: 19,
                                          ),
                                        ),
                                    ],
                                  ),

                                  if (summary.isNotEmpty) ...[
                                    const SizedBox(height: 16),

                                    Text(summary, style: AppTheme.body()),
                                  ],

                                  if (diagnosis.isNotEmpty) ...[
                                    const SizedBox(height: 16),

                                    _MedicalSection(
                                      title: 'Diagnosis',
                                      value: diagnosis,
                                    ),
                                  ],

                                  if (treatment.isNotEmpty) ...[
                                    const SizedBox(height: 12),

                                    _MedicalSection(
                                      title: 'Treatment',
                                      value: treatment,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // VACCINES
                    _buildVaccinesTab(),

                    // NOTES
                    ListView(
                      padding: const EdgeInsets.all(16),

                      children: [
                        _InfoCard(
                          title: 'Medical Notes',
                          children: [
                            Text(
                              notes.isEmpty ? 'No medical notes yet' : notes,

                              style: AppTheme.body(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditMedicalNotesDialog({
    required String currentNotes,
  }) async {
    final controller = TextEditingController(text: currentNotes);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),

          child: Container(
            padding: const EdgeInsets.all(20),

            decoration: const BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text('Edit Medical Notes', style: AppTheme.h2()),

                const SizedBox(height: 20),

                TextField(
                  controller: controller,
                  maxLines: 8,

                  decoration: InputDecoration(
                    hintText: 'Medical notes',

                    filled: true,
                    fillColor: AppTheme.bg,

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),

                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 54,

                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.card,

                      foregroundColor: Colors.white,
                    ),

                    onPressed: () async {
                      await _patientRef.update({
                        'notes': controller.text.trim(),

                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },

                    child: const Text('Save Notes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVaccinesTab() {
    if (_loadingVaccines) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_vaccines.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _EmptyState(
            icon: LucideIcons.syringe,
            title: 'No vaccines yet',
            subtitle: 'Vaccination records will appear here.',
          ),
        ],
      );
    }

    final upcoming = <PetVaccineRecord>[];
    final completed = <PetVaccineRecord>[];
    final overdue = <PetVaccineRecord>[];

    for (final vaccine in _vaccines) {
      final status = _getVaccineStatus(vaccine);

      if (status == 'completed') {
        completed.add(vaccine);
      } else if (status == 'overdue') {
        overdue.add(vaccine);
      } else {
        upcoming.add(vaccine);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._buildVaccineSection('Upcoming Vaccines', upcoming),
        ..._buildVaccineSection('Completed Vaccines', completed),
        ..._buildVaccineSection('Overdue Vaccines', overdue),
      ],
    );
  }

  List<Widget> _buildVaccineSection(
    String title,
    List<PetVaccineRecord> vaccines,
  ) {
    if (vaccines.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 10, top: 4),
        child: Text(title, style: AppTheme.h3()),
      ),
      ...vaccines.map(
        (vaccine) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildVaccineCard(vaccine),
        ),
      ),
      const SizedBox(height: 4),
    ];
  }

  Widget _buildVaccineCard(PetVaccineRecord vaccine) {
    final status = _getVaccineStatus(vaccine);
    final isCompleted = status == 'completed';
    final isOverdue = status == 'overdue';
    final isDueToday = _isDueToday(vaccine);

    if (isOverdue) {
      debugPrint('💉 OVERDUE DETECTED vaccineId=${vaccine.id}');
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.cardShadow(opacity: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.card.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(LucideIcons.syringe, color: AppTheme.card),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vaccine.name, style: AppTheme.h3()),
                    const SizedBox(height: 4),
                    Text(
                      vaccine.date == null
                          ? 'Date not recorded'
                          : _formatDate(vaccine.date!),
                      style: AppTheme.caption(),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (isCompleted)
                          _buildVaccineStatusChip(
                            label: 'Completed',
                            color: Colors.green,
                          )
                        else if (isOverdue)
                          _buildVaccineStatusChip(
                            label: 'Overdue',
                            color: Colors.red,
                          )
                        else if (isDueToday)
                          _buildVaccineStatusChip(
                            label: 'Due Today',
                            color: Colors.blue,
                          )
                        else
                          _buildVaccineStatusChip(
                            label: 'Upcoming',
                            color: Colors.orange,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!_isOwnerView)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isCompleted)
                      _CompleteVaccineButton(
                        onTap: () => _completeVaccine(vaccine.id),
                      ),

                    if (!isCompleted) const SizedBox(height: 4),

                    IconButton(
                      tooltip: 'Edit vaccine',
                      onPressed: () async {
                        await _openEditVaccineDialog(vaccine);
                      },
                      icon: const Icon(
                        LucideIcons.edit2,
                        color: AppTheme.card,
                        size: 19,
                      ),
                    ),

                    IconButton(
                      tooltip: 'Delete vaccine',
                      onPressed: () async {
                        await _deleteVaccine(vaccine.id);
                      },
                      icon: const Icon(
                        LucideIcons.trash2,
                        color: Colors.red,
                        size: 18,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (vaccine.notes != null && vaccine.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(vaccine.notes!, style: AppTheme.body()),
          ],
          if (vaccine.nextDueDate != null) ...[
            const SizedBox(height: 16),
            _MedicalSection(
              title: 'Next Due Date',
              value: _formatDate(vaccine.nextDueDate!),
            ),
          ],
          if (vaccine.completedAt != null) ...[
            const SizedBox(height: 16),
            _MedicalSection(
              title: 'Completed At',
              value: _formatDate(vaccine.completedAt!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVaccineStatusChip({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _completeVaccine(String vaccineId) async {
    try {
      debugPrint('💉 COMPLETE VACCINE START');

      final patientRef = FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .collection('patients')
          .doc(widget.patientId);
      final patientData = await _loadPatientMirrorData(patientRef);
      final vaccineRef = patientRef.collection('vaccines').doc(vaccineId);
      final vaccineSnap = await vaccineRef.get();

      if (!vaccineSnap.exists) {
        debugPrint('❌ COMPLETE ERROR: vaccine not found $vaccineId');
        return;
      }

      final vaccineData = vaccineSnap.data() ?? {};
      final vaccineName =
          vaccineData['name']?.toString().trim().isNotEmpty == true
          ? vaccineData['name'].toString().trim()
          : 'Vaccine';
      final completedAt = DateTime.now();

      final completedUpdate = {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await vaccineRef.update(completedUpdate);

      await _mirrorDogVaccineUpdate(
        patientData: patientData,
        vaccineId: vaccineId,
        data: completedUpdate,
        successLog: '💉 DOG VACCINE MIRROR COMPLETED',
      );

      await _createNextRecurringVaccineIfNeeded(
        patientRef: patientRef,
        patientData: patientData,
        vaccineId: vaccineId,
        vaccineData: vaccineData,
        vaccineName: vaccineName,
        completedAt: completedAt,
      );

      await patientRef.collection('timeline').add({
        'type': 'vaccine_completed',
        'vaccineName': vaccineName,
        'vaccineId': vaccineId,
        'completedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('💉 TIMELINE EVENT CREATED');

      await _createVaccineCompletedNotification(
        patientRef: patientRef,
        vaccineId: vaccineId,
        vaccineName: vaccineName,
      );

      debugPrint('💉 COMPLETE SUCCESS');

      await _loadVaccines();
    } catch (e) {
      debugPrint('❌ COMPLETE ERROR: $e');
    }
  }

  Future<void> _createNextRecurringVaccineIfNeeded({
    required DocumentReference<Map<String, dynamic>> patientRef,
    required Map<String, dynamic> patientData,
    required String vaccineId,
    required Map<String, dynamic> vaccineData,
    required String vaccineName,
    required DateTime completedAt,
  }) async {
    final recurrenceRaw =
        vaccineData['recurrenceDays'] ?? vaccineData['intervalDays'];
    final recurrenceDays = recurrenceRaw is int
        ? recurrenceRaw
        : int.tryParse(recurrenceRaw?.toString() ?? '');

    if (recurrenceDays == null || recurrenceDays <= 0) return;

    final nextVaccineRef = patientRef
        .collection('vaccines')
        .doc('auto_next_$vaccineId');
    final existing = await nextVaccineRef.get();

    if (existing.exists) return;

    final nextVaccineData = {
      'name': vaccineName,
      'catalogId': vaccineData['catalogId'],
      'petTypes': vaccineData['petTypes'] is List
          ? List<dynamic>.from(vaccineData['petTypes'] as List)
          : [],
      'petType': vaccineData['petType'],
      'frequencyType': vaccineData['frequencyType'],
      'intervalDays': recurrenceDays,
      'recurrenceDays': recurrenceDays,
      'notes': vaccineData['notes']?.toString() ?? '',
      'date': Timestamp.fromDate(completedAt),
      'nextDueDate': Timestamp.fromDate(
        completedAt.add(Duration(days: recurrenceDays)),
      ),
      'reminderEnabled': vaccineData['reminderEnabled'] != false,
      'status': 'upcoming',
      'completedAt': null,
      'businessId': widget.businessId,
      'patientId': widget.patientId,
      'ownerId': patientData['ownerId'],
      'createdByBusinessId': widget.businessId,
      'createdByVetId': _currentVetId,
      'autoCreatedFromVaccineId': vaccineId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await nextVaccineRef.set(nextVaccineData);

    await _mirrorDogVaccineSet(
      patientData: patientData,
      vaccineId: nextVaccineRef.id,
      data: nextVaccineData,
      successLog: '💉 DOG VACCINE MIRROR CREATED',
    );

    debugPrint('💉 AUTO NEXT VACCINE CREATED');
  }

  Future<void> _createVaccineCompletedNotification({
    required DocumentReference<Map<String, dynamic>> patientRef,
    required String vaccineId,
    required String vaccineName,
  }) async {
    final patientSnap = await patientRef.get();
    final patientData = patientSnap.data() ?? {};
    final ownerId =
        patientData['ownerId']?.toString() ??
        patientData['userId']?.toString() ??
        patientData['clientUserId']?.toString();

    if (ownerId == null || ownerId.trim().isEmpty) return;

    final body = '$vaccineName vaccine has been completed.';

    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': ownerId,
      'recipientUserId': ownerId,
      'type': 'vaccine_completed',
      'title': 'Vaccination Completed',
      'body': body,
      'businessId': widget.businessId,
      'patientId': widget.patientId,
      'vaccineId': vaccineId,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
    debugPrint('💉 OWNER NOTIFICATION CREATED');

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .get();
    final token = userSnap.data()?['fcmToken']?.toString();

    if (token != null && token.isNotEmpty) {
      try {
        await FirebaseFunctions.instanceFor(
          region: 'europe-west3',
        ).httpsCallable('sendVaccineCompletedPush').call({
          'ownerId': ownerId,
          'vaccineName': vaccineName,
          'businessId': widget.businessId,
          'patientId': widget.patientId,
          'vaccineId': vaccineId,
        });
        debugPrint('💉 PUSH SENT');
      } catch (e) {
        debugPrint('❌ VACCINE PUSH ERROR: $e');
      }
    }
  }

  Future<void> _deleteVaccine(String vaccineId) async {
    try {
      debugPrint('💉 DELETE VACCINE START');

      final confirm =
          await showDialog<bool>(
            context: context,

            builder: (context) {
              return AlertDialog(
                title: const Text('Delete Vaccine'),

                content: const Text(
                  'Are you sure you want to delete this vaccine record?',
                ),

                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                    },

                    child: const Text('Cancel'),
                  ),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                    },

                    child: const Text('Delete'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!confirm) return;

      final patientRef = FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .collection('patients')
          .doc(widget.patientId);
      final patientData = await _loadPatientMirrorData(patientRef);

      await patientRef.collection('vaccines').doc(vaccineId).delete();

      await _mirrorDogVaccineDelete(
        patientData: patientData,
        vaccineId: vaccineId,
      );

      debugPrint('💉 DELETE SUCCESS');

      await _loadVaccines();
    } catch (e) {
      debugPrint('❌ DELETE VACCINE ERROR: $e');
    }
  }

  Future<void> _openEditVaccineDialog(PetVaccineRecord vaccine) async {
    _vaccineNameController.text = vaccine.name;

    _vaccineNotesController.text = vaccine.notes ?? '';

    _vaccineDate = vaccine.date;
    _nextDueDate = vaccine.nextDueDate;

    await showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),

          decoration: const BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text('Edit Vaccine', style: AppTheme.h2()),

              const SizedBox(height: 20),

              TextField(
                controller: _vaccineNameController,

                decoration: InputDecoration(
                  hintText: 'Vaccine name',

                  filled: true,
                  fillColor: AppTheme.bg,

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),

                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextField(
                controller: _vaccineNotesController,

                maxLines: 3,

                decoration: InputDecoration(
                  hintText: 'Notes',

                  filled: true,
                  fillColor: AppTheme.bg,

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),

                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,

                child: ElevatedButton(
                  onPressed: () async {
                    await _updateVaccine(vaccine.id);

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },

                  child: const Text('Update Vaccine'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateVaccine(String vaccineId) async {
    try {
      debugPrint('💉 UPDATE VACCINE START');

      final patientRef = FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .collection('patients')
          .doc(widget.patientId);
      final patientData = await _loadPatientMirrorData(patientRef);
      final updateData = {
        'name': _vaccineNameController.text.trim(),
        'notes': _vaccineNotesController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await patientRef.collection('vaccines').doc(vaccineId).update(updateData);

      await _mirrorDogVaccineUpdate(
        patientData: patientData,
        vaccineId: vaccineId,
        data: updateData,
        successLog: '💉 DOG VACCINE MIRROR UPDATED',
      );

      debugPrint('💉 VACCINE UPDATE SUCCESS');

      await _loadVaccines();
    } catch (e) {
      debugPrint('❌ UPDATE VACCINE ERROR: $e');
    }
  }

  String? get _currentVetId => FirebaseAuth.instance.currentUser?.uid;

  Future<Map<String, dynamic>> _loadPatientMirrorData(
    DocumentReference<Map<String, dynamic>> patientRef,
  ) async {
    final patientSnap = await patientRef.get();
    final data = patientSnap.data() ?? {};
    final ownerId =
        _stringOrNull(data['ownerId']) ??
        _stringOrNull(data['userId']) ??
        _stringOrNull(data['clientUserId']);

    return {...data, 'petId': _stringOrNull(data['petId']), 'ownerId': ownerId};
  }

  String? _stringOrNull(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  DocumentReference<Map<String, dynamic>>? _dogVaccineRef({
    required Map<String, dynamic> patientData,
    required String vaccineId,
  }) {
    final petId = _stringOrNull(patientData['petId']);

    if (petId == null) {
      debugPrint('💉 DOG MIRROR SKIPPED → missing petId');
      return null;
    }

    return FirebaseFirestore.instance
        .collection('dogs')
        .doc(petId)
        .collection('vaccines')
        .doc(vaccineId);
  }

  Map<String, dynamic> _dogMirrorMetadata(Map<String, dynamic> patientData) {
    return {
      'businessId': widget.businessId,
      'patientId': widget.patientId,
      'ownerId': patientData['ownerId'],
      'createdByBusinessId': widget.businessId,
      'createdByVetId': _currentVetId,
    };
  }

  Future<void> _mirrorDogVaccineSet({
    required Map<String, dynamic> patientData,
    required String vaccineId,
    required Map<String, dynamic> data,
    required String successLog,
  }) async {
    final mirrorRef = _dogVaccineRef(
      patientData: patientData,
      vaccineId: vaccineId,
    );

    if (mirrorRef == null) return;

    try {
      await mirrorRef.set({
        ...data,
        ..._dogMirrorMetadata(patientData),
      }, SetOptions(merge: true));
      debugPrint(successLog);
    } catch (e) {
      debugPrint('❌ DOG VACCINE MIRROR ERROR: $e');
    }
  }

  Future<void> _mirrorDogVaccineUpdate({
    required Map<String, dynamic> patientData,
    required String vaccineId,
    required Map<String, dynamic> data,
    required String successLog,
  }) async {
    final mirrorRef = _dogVaccineRef(
      patientData: patientData,
      vaccineId: vaccineId,
    );

    if (mirrorRef == null) return;

    try {
      await mirrorRef.set({
        ...data,
        ..._dogMirrorMetadata(patientData),
      }, SetOptions(merge: true));
      debugPrint(successLog);
    } catch (e) {
      debugPrint('❌ DOG VACCINE MIRROR ERROR: $e');
    }
  }

  Future<void> _mirrorDogVaccineDelete({
    required Map<String, dynamic> patientData,
    required String vaccineId,
  }) async {
    final mirrorRef = _dogVaccineRef(
      patientData: patientData,
      vaccineId: vaccineId,
    );

    if (mirrorRef == null) return;

    try {
      await mirrorRef.delete();
      debugPrint('💉 DOG VACCINE MIRROR DELETED');
    } catch (e) {
      debugPrint('❌ DOG VACCINE MIRROR ERROR: $e');
    }
  }
}

class _CompleteVaccineButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CompleteVaccineButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50),
          borderRadius: BorderRadius.circular(100),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.check, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Text(
              'Complete Vaccine',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.cardShadow(opacity: 0.06),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(title, style: AppTheme.h3()),

          const SizedBox(height: 16),

          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),

      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTheme.caption())),

          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTheme.body(weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),

      child: Column(
        children: [
          Icon(icon, size: 40, color: AppTheme.card),

          const SizedBox(height: 14),

          Text(title, style: AppTheme.h3()),

          const SizedBox(height: 8),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTheme.caption(),
          ),
        ],
      ),
    );
  }
}

String _getVaccineStatus(PetVaccineRecord vaccine) {
  if (vaccine.status == 'completed') {
    return 'completed';
  }

  final nextDue = vaccine.nextDueDate;

  if (nextDue == null) {
    return 'upcoming';
  }

  final today = _dateOnly(DateTime.now());
  final dueDate = _dateOnly(nextDue);

  if (dueDate.isBefore(today)) {
    return 'overdue';
  }

  return 'upcoming';
}

bool _isDueToday(PetVaccineRecord vaccine) {
  if (vaccine.status == 'completed' || vaccine.nextDueDate == null) {
    return false;
  }

  return _dateOnly(vaccine.nextDueDate!) == _dateOnly(DateTime.now());
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

String _formatTimestamp(dynamic value) {
  DateTime? date;

  if (value is Timestamp) {
    date = value.toDate();
  } else if (value is DateTime) {
    date = value;
  }

  if (date == null) return '-';

  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _readPetName(Map<String, dynamic> data) {
  final value = data['petName'] ?? data['name'] ?? 'Unnamed pet';
  final text = value.toString().trim();
  return text.isEmpty ? 'Unnamed pet' : text;
}

class _MedicalSection extends StatelessWidget {
  final String title;
  final String value;

  const _MedicalSection({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          title,

          style: AppTheme.caption(
            weight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 6),

        Container(
          width: double.infinity,

          padding: const EdgeInsets.all(14),

          decoration: BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.circular(16),
          ),

          child: Text(value, style: AppTheme.body(size: 13)),
        ),
      ],
    );
  }
}
