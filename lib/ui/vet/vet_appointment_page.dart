import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../app_state.dart';
import '../../dog.dart';
import 'vet_card_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';

class VetAppointmentPage extends StatefulWidget {
  final BusinessCardData vet;

  const VetAppointmentPage({
    super.key,
    required this.vet,
  });

  @override
  State<VetAppointmentPage> createState() => _VetAppointmentPageState();
}

class _VetAppointmentPageState extends State<VetAppointmentPage> {
  // ─────────────────────────────
  // STATE
  // ─────────────────────────────
  String _appointmentType = 'Check-up';
  Dog? _selectedDog;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final TextEditingController _noteController = TextEditingController();
  bool _submitting = false;

  final List<String> _appointmentTypes = const [
    'Check-up',
    'Vaccination',
    'Emergency',
    'Other',
  ];

  bool get _isValid =>
      _selectedDog != null &&
      _selectedDate != null &&
      _selectedTime != null;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // ─────────────────────────────
  // UI
  // ─────────────────────────────
  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();


if (!appState.isUserProfileReady) {
  return const SizedBox.shrink();
}

final username = appState.username ?? 'User';


    return Scaffold(
      backgroundColor: AppTheme.bg,

      // ✅ FIXED & READABLE APPBAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // ❗️ SubPage → فقط AppState
           context.read<AppState>().closeBusinessAppointment();
          },
        ),
        title: Text(
          'Appointment • ${widget.vet.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _sectionTitle('Appointment Type'),
            _typeSelector(),

            const SizedBox(height: 20),

            _sectionTitle('Select Dog'),
            _dogSelector(),

            const SizedBox(height: 20),

            _sectionTitle('Date & Time'),
            _dateTimePicker(),

            const SizedBox(height: 20),

            _sectionTitle('Notes (optional)'),
            _notesField(),

            const SizedBox(height: 32),

            _submitButton(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────
  // WIDGETS
  // ─────────────────────────────

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: AppTheme.h2().copyWith(fontSize: 16),
    );
  }

  Widget _typeSelector() {
    return Wrap(
      spacing: 8,
      children: _appointmentTypes.map((type) {
        final active = _appointmentType == type;
        return ChoiceChip(
          label: Text(type),
          selected: active,
          selectedColor: Colors.amber,
          onSelected: (_) {
            setState(() => _appointmentType = type);
          },
        );
      }).toList(),
    );
  }

  Widget _dogSelector() {
    final dogs = context.watch<AppState>().myDogs;

    if (dogs.isEmpty) {
      return Text(
        'You have no dogs added yet.',
        style: AppTheme.caption(),
      );
    }

    return Column(
      children: dogs.map((dog) {
        final selected = _selectedDog?.id == dog.id;

        return GestureDetector(
          onTap: () {
            setState(() => _selectedDog = dog);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.amber.withOpacity(0.15)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? Colors.amber
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.pets,
                  color: selected ? Colors.amber : Colors.grey,
                ),
                const SizedBox(width: 10),
                Text(
                  dog.name,
                  style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _dateTimePicker() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _pickDate,
            child: Text(
              _selectedDate == null
                  ? 'Select Date'
                  : '${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day}',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: _pickTime,
            child: Text(
              _selectedTime == null
                  ? 'Select Time'
                  : _selectedTime!.format(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _notesField() {
    return TextField(
      controller: _noteController,
      maxLines: 3,
      decoration: const InputDecoration(
        hintText: 'Add a note for the clinic...',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: !_isValid || _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _submitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
                'Request Appointment',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  // ─────────────────────────────
  // ACTIONS
  // ─────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      initialDate: now,
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _submit() async {
  if (!_isValid) return;

  final appState = context.read<AppState>();
  final userId = appState.currentUserId;
  final username = appState.username; // ✅ فقط این

  if (userId == null || username == null || _selectedDog == null) return;

  setState(() => _submitting = true);

  try {
    final scheduledDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    await FirebaseFirestore.instance
        .collection('vet_appointments')
        .add({
      'userId': userId,
      'username': username, // ✅ دیگه Guest نمیاد

      'dogId': _selectedDog!.id,
      'dogName': _selectedDog!.name,

      'vetId': widget.vet.id,
      'vetName': widget.vet.name,
      'vetIsPartner': widget.vet.isPartner,

      'appointmentType': _appointmentType,
      'scheduledDateTime': Timestamp.fromDate(scheduledDateTime),
      'note': _noteController.text.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });


    if (!mounted) return;

    showDialog(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Request Sent 🐾'),
    content: const Text(
      'Your appointment request has been sent to the clinic.',
    ),
    actions: [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop(); // 👈 اول Dialog بسته شود

          Future.microtask(() {
            if (mounted) {
              context.read<AppState>().closeBusinessAppointment();
            }
          });
        },
        child: const Text('OK'),
      ),
    ],
  ),
);
  } catch (e) {
    debugPrint('❌ Appointment submit error: $e');
  } finally {
    if (mounted) {
      setState(() => _submitting = false);
    }
  }
}

}
