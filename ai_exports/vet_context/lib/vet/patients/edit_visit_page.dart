import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class EditVisitPage extends StatefulWidget {
  final String businessId;
  final String patientId;
  final String? visitId;
  final Map<String, dynamic>? initialData;

  const EditVisitPage({
    super.key,
    required this.businessId,
    required this.patientId,
    this.visitId,
    this.initialData,
  });

  @override
  State<EditVisitPage> createState() => _EditVisitPageState();
}

class _EditVisitPageState extends State<EditVisitPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _medicalNotesController = TextEditingController();
  final _prescriptionController = TextEditingController();

  DateTime? _followUpDate;
  bool _saving = false;

  bool get _isEditing => widget.visitId != null && widget.visitId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? {};
    _titleController.text = _readString(data, const ['title']);
    _descriptionController.text = _readString(data, const [
      'description',
      'summary',
    ]);
    _medicalNotesController.text = _readString(data, const [
      'medicalNotes',
      'diagnosis',
    ]);
    _prescriptionController.text = _readString(data, const [
      'prescription',
      'treatment',
    ]);
    _followUpDate = _readDate(data['followUpDate']);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _medicalNotesController.dispose();
    _prescriptionController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _visitsRef => FirebaseFirestore
      .instance
      .collection('businesses')
      .doc(widget.businessId)
      .collection('patients')
      .doc(widget.patientId)
      .collection('visits');

  DocumentReference<Map<String, dynamic>> get _patientRef => FirebaseFirestore
      .instance
      .collection('businesses')
      .doc(widget.businessId)
      .collection('patients')
      .doc(widget.patientId);

  Future<void> _pickFollowUpDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (!mounted || picked == null) return;
    setState(() => _followUpDate = picked);
  }

  Future<void> _saveVisit() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    debugPrint('🩺 SAVE VISIT START');
    setState(() => _saving = true);

    try {
      final payload = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'summary': _descriptionController.text.trim(),
        'medicalNotes': _medicalNotesController.text.trim(),
        'diagnosis': _medicalNotesController.text.trim(),
        'prescription': _prescriptionController.text.trim(),
        'treatment': _prescriptionController.text.trim(),
        'followUpRequired': _followUpDate != null,
        'followUpDate': _followUpDate == null
            ? null
            : Timestamp.fromDate(_followUpDate!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final patientData = await _loadPatientMirrorData();

      if (_isEditing) {
        final visitId = widget.visitId!;
        await _visitsRef.doc(visitId).set(payload, SetOptions(merge: true));
        await _mirrorDogVisitUpdate(
          patientData: patientData,
          visitId: visitId,
          data: payload,
        );
        debugPrint('🩺 VISIT UPDATED');
      } else {
        final visitRef = _visitsRef.doc();
        final createPayload = {
          ...payload,
          'visitDate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        await visitRef.set(createPayload);
        await _mirrorDogVisitSet(
          patientData: patientData,
          visitId: visitRef.id,
          data: createPayload,
        );
        debugPrint('🩺 VISIT CREATED');
      }

      debugPrint('🩺 VISIT SAVE SUCCESS');

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('🩺 VISIT SAVE ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save visit: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteVisit() async {
    if (!_isEditing || _saving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Visit'),
          content: const Text('Delete this visit from the medical record?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _saving = true);

    try {
      final patientData = await _loadPatientMirrorData();
      await _visitsRef.doc(widget.visitId).delete();
      await _mirrorDogVisitDelete(
        patientData: patientData,
        visitId: widget.visitId!,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('🩺 VISIT DELETE ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete visit: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Map<String, dynamic>> _loadPatientMirrorData() async {
    final patientSnap = await _patientRef.get();
    final data = patientSnap.data() ?? {};
    final ownerId =
        _stringOrNull(data['petOwnerUid']) ??
        _stringOrNull(data['petOwnerId']) ??
        _stringOrNull(data['requesterUserId']) ??
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

  DocumentReference<Map<String, dynamic>>? _dogVisitRef({
    required Map<String, dynamic> patientData,
    required String visitId,
  }) {
    final petId = _stringOrNull(patientData['petId']);

    if (petId == null) {
      debugPrint('🩺 DOG VISIT MIRROR SKIPPED → missing petId');
      return null;
    }

    return FirebaseFirestore.instance
        .collection('dogs')
        .doc(petId)
        .collection('visits')
        .doc(visitId);
  }

  Map<String, dynamic> _dogVisitMirrorMetadata(
    Map<String, dynamic> patientData,
  ) {
    return {
      'businessId': widget.businessId,
      'patientId': widget.patientId,
      'ownerId': patientData['ownerId'],
      'createdByBusinessId': widget.businessId,
      'createdByVetId': FirebaseAuth.instance.currentUser?.uid,
    };
  }

  Future<void> _mirrorDogVisitSet({
    required Map<String, dynamic> patientData,
    required String visitId,
    required Map<String, dynamic> data,
  }) async {
    final mirrorRef = _dogVisitRef(patientData: patientData, visitId: visitId);
    if (mirrorRef == null) return;

    try {
      await mirrorRef.set({
        ...data,
        ..._dogVisitMirrorMetadata(patientData),
      }, SetOptions(merge: true));
      debugPrint('🩺 DOG VISIT MIRROR CREATED');
    } catch (e) {
      debugPrint('❌ DOG VISIT MIRROR ERROR: $e');
    }
  }

  Future<void> _mirrorDogVisitUpdate({
    required Map<String, dynamic> patientData,
    required String visitId,
    required Map<String, dynamic> data,
  }) async {
    final mirrorRef = _dogVisitRef(patientData: patientData, visitId: visitId);
    if (mirrorRef == null) return;

    try {
      await mirrorRef.set({
        ...data,
        ..._dogVisitMirrorMetadata(patientData),
      }, SetOptions(merge: true));
      debugPrint('🩺 DOG VISIT MIRROR UPDATED');
    } catch (e) {
      debugPrint('❌ DOG VISIT MIRROR ERROR: $e');
    }
  }

  Future<void> _mirrorDogVisitDelete({
    required Map<String, dynamic> patientData,
    required String visitId,
  }) async {
    final mirrorRef = _dogVisitRef(patientData: patientData, visitId: visitId);
    if (mirrorRef == null) return;

    try {
      await mirrorRef.delete();
      debugPrint('🩺 DOG VISIT MIRROR DELETED');
    } catch (e) {
      debugPrint('❌ DOG VISIT MIRROR ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_isEditing ? 'Edit Visit' : 'New Visit'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete visit',
              onPressed: _saving ? null : _deleteVisit,
              icon: const Icon(LucideIcons.trash2),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(
                children: [
                  _field(
                    controller: _titleController,
                    label: 'Visit Title',
                    icon: LucideIcons.stethoscope,
                    required: true,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _descriptionController,
                    label: 'Description',
                    icon: LucideIcons.fileText,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _medicalNotesController,
                    label: 'Medical Notes',
                    icon: LucideIcons.clipboardList,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _prescriptionController,
                    label: 'Prescription',
                    icon: LucideIcons.pill,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _pickFollowUpDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.calendar,
                            color: AppTheme.card,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _followUpDate == null
                                  ? 'Follow-up Date'
                                  : _formatDate(_followUpDate!),
                              style: AppTheme.body(
                                color: _followUpDate == null
                                    ? AppTheme.muted
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (_followUpDate != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                setState(() => _followUpDate = null);
                              },
                              icon: const Icon(LucideIcons.x, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveVisit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.card,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.save, size: 19),
                  label: Text(_saving ? 'Saving...' : 'Save Visit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.cardShadow(opacity: 0.06),
      ),
      child: Column(children: children),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? '$label is required'
                : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.card, size: 20),
        filled: true,
        fillColor: AppTheme.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

String _readString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return '';
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
