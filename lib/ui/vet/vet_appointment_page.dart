import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../app_state.dart';
import '../../dog.dart';
import 'vet_card_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_functions/cloud_functions.dart';

class VetAppointmentPage extends StatefulWidget {
  final BusinessCardData vet;
  final Map<String, dynamic>? selectedService;

  const VetAppointmentPage({
  super.key,
  required this.vet,
  this.selectedService, // 🔥 NEW
});

  @override
  State<VetAppointmentPage> createState() => _VetAppointmentPageState();
}

class _VetAppointmentPageState extends State<VetAppointmentPage> {
  // ─────────────────────────────
  // STATE
  // ─────────────────────────────
 
  Dog? _selectedDog;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final TextEditingController _noteController = TextEditingController();
  bool _submitting = false;

  Map<String, dynamic>? _selectedServiceLocal;

  bool get _isValid =>
    _selectedDog != null &&
    _selectedDate != null &&
    _selectedTime != null &&
    _selectedServiceLocal != null; // 🔥 این خط جدید

    late final Stream<QuerySnapshot> _servicesStream;


  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

@override
void initState() {
  super.initState();

  _selectedServiceLocal = widget.selectedService;

  _servicesStream = FirebaseFirestore.instance
      .collection('businesses')
      .doc(widget.vet.id)
      .collection('services')
      .orderBy('sortOrder')
      .snapshots();
}

Widget _serviceSelector() {
  return StreamBuilder<QuerySnapshot>(
    stream: _servicesStream, // ✅ مهم: از initState میاد
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        );
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return SizedBox(
          height: 60,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "No services available",
              style: AppTheme.caption(),
            ),
          ),
        );
      }

      final docs = snapshot.data!.docs;

      /// 🔥 AUTO SELECT FIRST SERVICE (SAFE - بدون loop)
      if (_selectedServiceLocal == null && docs.isNotEmpty) {
  _selectedServiceLocal = {
    ...docs.first.data() as Map<String, dynamic>,
    'id': docs.first.id,
  };
}

      return SizedBox(
        height: 70, // ✅ کمتر → overflow رفع
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final service = {
              ...data,
              'id': doc.id,
            };

            final isSelected =
                _selectedServiceLocal?['id'] == service['id'];

            return GestureDetector(
              onTap: () {
                if (isSelected) return; // ✅ جلوگیری از rebuild اضافی

                setState(() {
                  _selectedServiceLocal = service;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.amber : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? Colors.amber
                        : Colors.grey.shade300,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),

                /// ❌ Column overflow داشت
                /// ✅ Row + Flexible = حل کامل
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data['title'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(width: 6),

                    Text(
                      "${data['durationMin'] ?? 30}m",
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.black87
                            : Colors.grey,
                      ),
                    ),

                    /// 💰 price
                    if (data['price'] != null && data['price'] > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        "${data['price']}₺",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
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

  return Material( // 👈 خیلی مهم
    color: AppTheme.bg,
    child: SafeArea(
      child: Column(
        children: [

          /// 🔙 HEADER (به جای AppBar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    context.read<AppState>().closeBusinessAppointment();
                  },
                ),
                Expanded(
                  child: Text(
                    'Appointment • ${widget.vet.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// 👇 BODY
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _sectionTitle('Select Service'),
const SizedBox(height: 8),
_serviceSelector(),

                const SizedBox(height: 20),

                _sectionTitle('Select Pet'),
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

  

  Widget _dogSelector() {
    final dogs = context.read<AppState>().myDogs;

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
                Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      "${dog.name} • ${dog.petType ?? 'dog'}",
      style: TextStyle(
        fontWeight: selected ? FontWeight.bold : FontWeight.w600,
      ),
    ),
    const SizedBox(height: 2),
    Text(
      "${dog.breed} • ${dog.age}y",
      style: const TextStyle(
        fontSize: 12,
        color: Colors.grey,
      ),
    ),
  ],
)
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
  debugPrint("🚀 SUBMIT CLICKED");

  if (!_isValid || _submitting) return;

  final appState = context.read<AppState>();
  final userId = appState.currentUserId;
  final selectedService = _selectedServiceLocal;

  if (userId == null || _selectedDog == null) {
    debugPrint("❌ Missing user or dog");
    return;
  }

  setState(() => _submitting = true);

  try {
    final scheduledDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    /// 🔥 CALL CLOUD FUNCTION (به‌جای Firestore مستقیم)
    await FirebaseFunctions.instanceFor(region: 'europe-west3')
        .httpsCallable('createVetAppointment')
        .call({
      'petId': _selectedDog!.id,
'petName': _selectedDog!.name,
'petType': _selectedDog!.petType,

'petBreed': _selectedDog!.breed,
'petAge': _selectedDog!.age,

      'businessId': widget.vet.id,
      'businessName': widget.vet.name,

      

'serviceId': selectedService?['id'],
'serviceTitle': selectedService?['title'],
'price': selectedService?['price'],
'durationMin': selectedService?['durationMin'],

      'scheduledAt': scheduledDateTime.toIso8601String(),
      'note': _noteController.text.trim(),
    });

    debugPrint("✅ FUNCTION SUCCESS");

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
  Navigator.of(context).pop(); // فقط dialog بسته میشه

  context.read<AppState>().closeBusinessAppointment(); // صفحه appointment بسته میشه
},
            child: const Text('OK'),
          ),
        ],
      ),
    );
  } catch (e) {
  debugPrint('❌ Appointment submit error: $e');

  String message = "Something went wrong";

  if (e is FirebaseFunctionsException) {
    switch (e.code) {

      case 'already-exists':
        message = "You already have a booking at this time. Please choose another time.";
        break;

      case 'invalid-argument':
        message = "Invalid booking data. Please try again.";
        break;

      default:
        message = e.message ?? message;
    }
  }

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
}
Widget _buildServiceBox(Map<String, dynamic> service) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Row(
      children: [
        const Icon(Icons.medical_services, color: Colors.amber),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service['title'] ?? 'Service',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                "${service['durationMin'] ?? 30} min",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        if (service['price'] != null)
          Text(
            "${service['price']} ₺",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
      ],
    ),
  );
}
}
