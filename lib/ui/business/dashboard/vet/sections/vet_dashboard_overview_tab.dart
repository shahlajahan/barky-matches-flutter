import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/vet/add_services_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/add_service_detail_page.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

class VetDashboardOverviewTab extends StatelessWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  const VetDashboardOverviewTab({
    super.key,
    required this.businessId,
    required this.businessData,
  });



  @override
Widget build(BuildContext context) {
  final stats = Map<String, dynamic>.from(businessData['stats'] ?? {});
  final profile = Map<String, dynamic>.from(businessData['profile'] ?? {});
  final contact = Map<String, dynamic>.from(businessData['contact'] ?? {});

  return ListView(
    padding: const EdgeInsets.all(16),
    children: [
      /// ================= PROFILE (ONLY ONCE) =================
      _SectionTitle("Clinic Profile"),
      const SizedBox(height: 10),
      _profileCard(context, profile, contact),

      const SizedBox(height: 20),

      /// ================= KPI =================
      

      /// ================= APPOINTMENTS =================
     _SectionTitle("Recent Appointments"),
const SizedBox(height: 10),

StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
  .collection('vet_appointments')
  .where('businessId', isEqualTo: businessId)
  .orderBy('scheduledAt', descending: true)
      .snapshots(),
  builder: (context, snapshot) {
    debugPrint("🟡 APPOINTMENT STREAM BUILD");
    debugPrint("🟡 businessId = $businessId");
    debugPrint("🟡 state = ${snapshot.connectionState}");
    debugPrint("🟡 hasData = ${snapshot.hasData}");
    debugPrint("🟡 hasError = ${snapshot.hasError}");
    debugPrint("🟡 error = ${snapshot.error}");
    debugPrint("🟡 docs = ${snapshot.data?.docs.length}");

    if (snapshot.hasError) {
      return _emptyBox("Appointment error: ${snapshot.error}");
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return _emptyBox("Loading appointments...");
    }

    if (!snapshot.hasData) {
      return _emptyBox("No appointment data");
    }

   final docs = snapshot.data!.docs.toList(); // 🔥 مهم (mutable)
int total = docs.length;

int pendingCount = docs.where((d) {
  final data = d.data() as Map<String, dynamic>;
  return data['status'] == 'pending';
}).length;

int confirmedCount = docs.where((d) {
  final data = d.data() as Map<String, dynamic>;
  return data['status'] == 'confirmed';
}).length;

int completedCount = docs.where((d) {
  final data = d.data() as Map<String, dynamic>;
  return data['status'] == 'completed';
}).length;
final limitedDocs = docs.take(3).toList();
// 🔥 SORT حرفه‌ای (pending اول + جدیدترین بالا)
docs.sort((a, b) {
  final aData = a.data() as Map<String, dynamic>;
  final bData = b.data() as Map<String, dynamic>;

  final aStatus = aData['status'] ?? '';
  final bStatus = bData['status'] ?? '';

  // ✅ pending بیاد بالا
  if (aStatus == 'pending' && bStatus != 'pending') return -1;
  if (aStatus != 'pending' && bStatus == 'pending') return 1;

  // ✅ بعدش بر اساس زمان
  final aTs = aData['scheduledAt'] ?? aData['scheduledDateTime'];
final bTs = bData['scheduledAt'] ?? bData['scheduledDateTime'];

final aTime = aTs is Timestamp ? aTs.toDate() : null;
final bTime = bTs is Timestamp ? bTs.toDate() : null;

  if (aTime == null || bTime == null) return 0;

  return bTime.compareTo(aTime); // newest first
});

    if (docs.isEmpty) {
      return _emptyBox("No appointments yet");
    }

    // 🔥 1. جدا کردن pending

final pending = docs.where((d) {
  final data = d.data() as Map<String, dynamic>;
  return data['status'] == 'pending';
}).take(3).toList();



return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    /// ================= KPI (NEW) =================
    Row(
      children: [
        _KpiCard(
          title: "Total",
          value: "$total",
          icon: LucideIcons.calendar,
        ),
        const SizedBox(width: 10),
        _KpiCard(
          title: "Pending",
          value: "$pendingCount",
          icon: LucideIcons.clock,
        ),
      ],
    ),

    const SizedBox(height: 10),

    Row(
      children: [
        _KpiCard(
          title: "Confirmed",
          value: "$confirmedCount",
          icon: LucideIcons.checkCircle,
        ),
        const SizedBox(width: 10),
        _KpiCard(
          title: "Completed",
          value: "$completedCount",
          icon: LucideIcons.check,
        ),
      ],
    ),

    const SizedBox(height: 20),

    /// ================= PENDING =================
    _SectionTitle("Pending Requests"),
    const SizedBox(height: 8),

    if (pending.isEmpty)
      _emptyBox("No pending requests")
    else
      ...pending.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _appointmentItem(context, doc.id, data);
      }),

    Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Open Appointments tab from top"),
            ),
          );
        },
        child: const Text("View all appointments"),
      ),
    ),
  ],
);
  },
),


      /// ================= SERVICES =================
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SectionTitle("Services"),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
  context.read<AppState>().openAddService();
},
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text("Add"),
          ),
        ],
      ),

      const SizedBox(height: 10),
      _emptyBox("No services added"),

      const SizedBox(height: 24),

      /// ================= QUICK ACTIONS =================
      _SectionTitle("Quick Actions"),
      const SizedBox(height: 10),

      Row(
        children: [
          _actionBtn(
  "Schedule",
  LucideIcons.calendar,
  onTap: () {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Schedule page coming next")),
    );
  },
),
          const SizedBox(width: 10),
          _actionBtn(
  "Patients",
  LucideIcons.users,
  onTap: () {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Patients page coming next")),
    );
  },
),
const SizedBox(width: 10),
_actionBtn(
  "Settings",
  LucideIcons.settings,
  onTap: () {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Settings page coming next")),
    );
  },
),
        ],
      ),

      /// ================= SERVICES LIST =================
_SectionTitle("Your Services"),
const SizedBox(height: 10),

StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('businesses')
      .doc(businessId)
      .collection('services')
      .orderBy('createdAt', descending: true)
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final docs = snapshot.data!.docs;

    if (docs.isEmpty) {
      return _emptyBox("No services yet");
    }



 final newServices = docs
    .map((e) => (e.data() as Map)['title'] as String)
    .toList();

final appState = context.read<AppState>();

// 🔥 فقط اگر تغییر کرده update کن
if (!listEquals(appState.existingServices, newServices)) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      appState.setExistingServices(newServices);
    }
  });
}
    return Column(
      children: docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _serviceItem(context, doc.id, data);
      }).toList(),
    );
  },
),
    ],
  );
}

Widget _serviceItem(
  BuildContext context,
  String id,
  Map<String, dynamic> data,
) {
  // 🔥 اینجا درستشه
  final price = data['price']?.toString();
final duration = data['duration']?.toString();

  String priceText;
  if (price == null) {
    priceText = "Price on request";
  } else {
    priceText = "₺$price";
  }

  String durationText;
  if (duration == null || duration.toString().isEmpty) {
    durationText = "Flexible duration";
  } else {
    durationText = duration.toString();
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Row(
          children: [
            Expanded(
              child: Text(
  data['title']?.toString() ?? '',
)
            ),
            GestureDetector(
              onTap: () {
  context.read<AppState>().openAddServiceDetail(
    data['title']?.toString() ?? '',
    serviceId: id,
    existingData: data,
  );
},
              child: const Icon(LucideIcons.edit2, size: 18),
            ),
            const SizedBox(width: 12),
            GestureDetector(
             onTap: () => _deleteService(context, businessId, id),
              child: const Icon(LucideIcons.trash2, size: 18),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // ✅ اینجا فقط Text
        Text(
          "$priceText • $durationText",
          style: AppTheme.body(color: AppTheme.muted),
        ),
      ],
    ),
  );
}

Widget _appointmentItem(
  BuildContext context,
  String id,
  Map<String, dynamic> data,
) {

  debugPrint("🧩 RENDER: ${data['dogName']} - ${data['status']}");
  final status = data['status'] ?? 'pending';

  final petName = data['petName'] ?? data['dogName'] ?? '';
final petType = data['petType'] ?? 'dog';
final petBreed = data['petBreed'] ?? '-';
final petAge = data['petAge'] ?? '-';
  final username = data['username'] ?? '';

  // 🔥 SERVICE (پشتیبانی از هر دو ساختار)
String serviceTitle = '';
String price = '';

if (data['service'] != null) {
  final service = data['service'] as Map<String, dynamic>;
  serviceTitle = service['title'] ?? '';
  price = service['price']?.toString() ?? '';
} else {
  serviceTitle = data['serviceTitle'] ?? '';
  price = data['price']?.toString() ?? '';
}

// 🔥 TIME (پشتیبانی از هر دو)
final ts =
    data['scheduledDateTime'] ??
    data['scheduledAt'];

final dt = ts is Timestamp ? ts.toDate() : null;

 

  String dateText = '';
  if (dt != null) {
    dateText =
        "${dt.year}-${dt.month}-${dt.day} • ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Color statusColor;
  switch (status) {
    case 'confirmed':
      statusColor = Colors.green;
      break;
    case 'rejected':
      statusColor = Colors.red;
      break;
    case 'completed':
      statusColor = Colors.blue;
      break;
    default:
      statusColor = Colors.orange;
  }

  return Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.black12),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      /// HEADER
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$petName • $petType",
                  style: AppTheme.bodyMedium()
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  "Breed: $petBreed",
                  style: AppTheme.caption(),
                ),
                Text(
                  "Age: $petAge",
                  style: AppTheme.caption(),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),

      const SizedBox(height: 8),

      /// SERVICE
      Text(
        "$serviceTitle • ₺$price",
        style: AppTheme.body(color: AppTheme.muted),
      ),

      const SizedBox(height: 4),

      /// DATE
      Text(
        dateText,
        style: AppTheme.caption(),
      ),

      const SizedBox(height: 10),

      /// ACTIONS
      if (status == 'pending')
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateAppointmentStatus(
  context,
  id,
  'confirmed',
),
                child: const Text("Accept"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateAppointmentStatus(
  context,
  id,
  'rejected',
),
                child: const Text("Reject"),
              ),
            ),
          ],
        )
      else
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            "Already ${status.toUpperCase()}",
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
    ],
  ),
);
}

Future<void> _updateAppointmentStatus(
  BuildContext context,
  String id,
  String newStatus,
) async {
  try {
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west3',
    ).httpsCallable('updateVetAppointmentStatus');

    await callable.call({
      'appointmentId': id,
      'newStatus': newStatus,
    });

    debugPrint("✅ FUNCTION CALLED → $newStatus");

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus == 'confirmed'
              ? "Appointment accepted"
              : "Appointment rejected",
        ),
      ),
    );
  } catch (e) {
    debugPrint("❌ FUNCTION ERROR: $e");

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Update failed: $e")),
    );
  }
}
Future<void> _deleteService(
  BuildContext context,
  String businessId,
  String id,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Delete Service"),
      content: const Text("Are you sure you want to delete this service?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Delete"),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('services')
        .doc(id)
        .delete();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Service deleted")),
    );
  } catch (e) {
    debugPrint('❌ deleteService error: $e');

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Delete failed")),
    );
  }
}

Widget _profileCard(
  BuildContext context,
  Map<String, dynamic> profile,
  Map<String, dynamic> contact,
) {
  final name = profile['displayName'] ?? 'Clinic';

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: AppTheme.h3(weight: FontWeight.w800),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Edit profile coming soon"),
    ),
  );
},
              icon: const Icon(LucideIcons.edit2, size: 18),
              label: const Text("Edit"),
            )
          ],
        ),

        const SizedBox(height: 10),

        Text(
          profile['bio'] ?? "No description yet",
          style: AppTheme.body(color: AppTheme.muted),
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip("📞 ${contact['phone'] ?? '-'}"),
            _chip("📍 ${contact['city'] ?? '-'}"),
            _chip("📍 ${contact['district'] ?? '-'}"),
          ],
        ),
      ],
    ),
  );
}

  /// ================= UI HELPERS =================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black12),
      boxShadow: AppTheme.cardShadow(opacity: 0.06),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Text(
        text,
        style: AppTheme.body(color: AppTheme.muted),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF9E1B4F).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: AppTheme.caption(
          color: const Color(0xFF9E1B4F),
        ),
      ),
    );
  }
}

/// ================= COMPONENTS =================

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTheme.h2(),
    );
  }
  
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF9E1B4F).withOpacity(0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF9E1B4F)),
            const SizedBox(height: 8),
            Text(value, style: AppTheme.h2(weight: FontWeight.w800)),
            Text(title, style: AppTheme.caption()),
          ],
        ),
      ),
    );
  }
}

class _actionBtn extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  const _actionBtn(this.text, this.icon, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF9E1B4F)),
              const SizedBox(height: 6),
              Text(text),
            ],
          ),
        ),
      ),
    );
  }
}