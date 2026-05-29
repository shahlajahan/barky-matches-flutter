import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barky_matches_fixed/ui/vet/vet_appointment_page.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/app_state.dart';

class VaccineNotificationPage extends StatefulWidget {
  final String businessId;
  final String patientId;
  final String vaccineId;
  final String? petId;

  const VaccineNotificationPage({
    super.key,
    required this.businessId,
    required this.patientId,
    required this.vaccineId,
    this.petId,
  });



  @override
State<VaccineNotificationPage> createState() =>
    _VaccineNotificationPageState();
}

class _VaccineNotificationPageState
    extends State<VaccineNotificationPage> {

late final Future<
DocumentSnapshot<Map<String,dynamic>>
> _vaccineFuture;

@override
void initState() {

  super.initState();

  _vaccineFuture =
      FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .collection('patients')
          .doc(widget.patientId)
          .collection('vaccines')
          .doc(widget.vaccineId)
          .get();
}

@override
Widget build(BuildContext context) {

  debugPrint(
 "💉 VaccineNotificationPage BUILD "
 "business=${widget.businessId} "
 "patient=${widget.patientId} "
 "vaccine=${widget.vaccineId}"
);

 

    return Container(
      color: const Color(0xFFFFF6F8),
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _vaccineFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF9E1B4F)),
            );
          }

          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.error_outline,
              title: 'Unable to open vaccine',
              body: snapshot.error.toString(),
            );
          }

          final doc = snapshot.data;
          final data = doc?.data();
          if (doc == null || !doc.exists || data == null) {
            return const _MessageState(
              icon: Icons.vaccines_outlined,
              title: 'Vaccine not found',
              body: 'This vaccine record is no longer available.',
            );
          }

          final name =
              _stringValue(data['name']) ??
              _stringValue(data['vaccineName']) ??
              'Vaccine';
          final notes = _stringValue(data['notes']);
          final status = _stringValue(data['status']) ?? 'upcoming';
          final dueDate = _readDate(data['date']);
          final nextDueDate = _readDate(data['nextDueDate']);
          final completedAt = _readDate(data['completedAt']);
          final recurrence = _intValue(
            data['recurrenceDays'] ?? data['intervalDays'],
          );
          final reminderEnabled = data['reminderEnabled'] != false;
          final shouldShowAppointmentButton =
    status.toLowerCase() != 'completed';
          final petName =
              _stringValue(data['petName']) ??
              _stringValue(data['dogName']) ??
              _stringValue(data['patientName']);
          final patientLabel =
              _stringValue(data['patientName']) ?? petName ?? 'Patient record';
          final clinicName =
              _stringValue(data['clinicName']) ??
              _stringValue(data['businessName']) ??
              _stringValue(data['vetName']) ??
              'Clinic record';
          final subtitle = nextDueDate != null
              ? 'Next due ${_formatDate(nextDueDate)}'
              : status == 'completed'
              ? 'Vaccination completed'
              : 'Vaccine notification';

          return ListView(
  padding: const EdgeInsets.fromLTRB(
    32,
    40,   // top spacing
    32,
    32,
  ),
  children: [
    Padding(
  padding: const EdgeInsets.only(
    left: 4,
    bottom: 28,
  ),
  child: Text(
    "Vaccine Details",
    style: GoogleFonts.poppins(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF23171D),
    ),
  ),
),


              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: const Color(0xFF9E1B4F),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 56,
                        width: 56,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF5A9E9B), Color(0xFF9E1B4F)],
                          ),
                        ),
                        child: const Icon(
                          Icons.vaccines,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _statusLine(status, nextDueDate),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          _infoChip('Status', _prettyStatus(status)),
                          _infoChip(
                            'Due',
                            dueDate == null ? 'Not set' : _formatDate(dueDate),
                          ),
                          _infoChip(
                            'Next',
                            nextDueDate == null
                                ? 'Not set'
                                : _formatDate(nextDueDate),
                          ),
                          _infoChip(
                            'Recurrence',
                            recurrence == null || recurrence <= 0
                                ? 'None'
                                : '${recurrence}d',
                          ),
                          _infoChip('Reminder', reminderEnabled ? 'On' : 'Off'),
                          _infoChip(
                            'Completed',
                            completedAt == null
                                ? 'No'
                                : _formatDate(completedAt),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(
  height: 24,
),

if (shouldShowAppointmentButton) ...[
  SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF9E1B4F),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      icon: const Icon(Icons.calendar_month),

      label: Text(
        "Book Appointment",
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),



      onPressed: () async {

  final businessSnap =
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .get();

  if (!context.mounted) return;

  if (!businessSnap.exists) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Clinic could not be loaded",
        ),
      ),
    );
    return;
  }

  final data = businessSnap.data()!;

  

final vet = BusinessCardData(

  id: businessSnap.id,

  name:
      data['displayName'] ??
      data['name'] ??
      'Vet',

  city:
      data['city'] ?? '',

  district:
      data['district'] ?? '',

  address:
      data['address'] ?? '',

  specialties:
      List<String>.from(
        data['specialties'] ?? [],
      ),

  services:
      data['services'] == null
          ? null
          : List<String>.from(
              data['services'],
            ),

  phone:
      data['phone'],

  whatsapp:
      data['whatsapp'],

  rating:
      (data['rating'] as num?)
          ?.toDouble(),

  reviewsCount:
      data['reviewsCount'],

  workingHours:
      data['workingHours'],

  description:
      data['description'],

  isPartner:
      data['isPartner'] == true,

  isVerified:
      data['isVerified'] == true,

  status:
      data['status'] ?? 'approved',

  is24h:
      data['is24h'] == true,

  isEmergency:
      data['emergencyService'] == true ||

      data['isEmergency'] == true,

  type:
      BusinessType.vet,

  instagram:
      data['instagram'],

  website:
      data['website'],

  logoUrl:
      data['logoUrl'],

  rawData:
      data,

  data:
      data,
);

  if (!context.mounted) return;

final appState =
    context.read<AppState>();

appState.closeNotifications();

appState.openBusinessAppointment(
  vet,

  selectedService: {

    "id": "vaccination",

    "title": name,

  },

);
},
    ),
  ),

  const SizedBox(height: 24),
],

_ContextSection(
                petName: petName,
                patientLabel: patientLabel,
                clinicName: clinicName,
              ),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _NotesCard(notes: notes),
              ],
            ],
          );
        },
      ),
    );
  }

  static String? _stringValue(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  static String _prettyStatus(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) return 'Upcoming';
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  static String _statusLine(String status, DateTime? nextDueDate) {
    if (status.toLowerCase() == 'completed') {
      return 'This vaccine has been marked complete.';
    }

    if (nextDueDate != null) {
      return 'Keep this vaccine on schedule for ongoing protection.';
    }

    return 'Review the vaccine record and follow up when needed.';
  }

  Widget _infoChip(String label, String? value) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
      ),
    );
  }
}

class _ContextSection extends StatelessWidget {
  final String? petName;
  final String patientLabel;
  final String clinicName;

  const _ContextSection({
    required this.petName,
    required this.patientLabel,
    required this.clinicName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
  'Related records',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF23171D),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (petName != null && petName!.isNotEmpty)
                _softChip(Icons.pets, petName!),
              _softChip(Icons.badge_outlined, patientLabel),
              _softChip(Icons.local_hospital_outlined, clinicName),
            ],
          ),
        ],
      ),
    );
  }

  Widget _softChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF9E1B4F).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF9E1B4F)),
          const SizedBox(width: 5),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF9E1B4F),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  final String notes;

  const _NotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Notes',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            notes,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15,
              height: 1.4,
              color: const Color(0xFF23171D),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: const Color(0xFF9E1B4F)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
