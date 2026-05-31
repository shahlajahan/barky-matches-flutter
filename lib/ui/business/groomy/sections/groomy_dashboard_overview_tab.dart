import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

import 'package:barky_matches_fixed/ui/business/groomy/edit_groomy_profile_page.dart';

class GroomyDashboardOverviewTab extends StatelessWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  const GroomyDashboardOverviewTab({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

_buildProfileSection(context),

const SizedBox(height:20),

_buildRevenueCard(context),

const SizedBox(height:20),

_buildStatsSection(context),

const SizedBox(height:20),

_buildAppointmentsSection(context),

],
      ),
    );
  }

  Widget _buildRevenueCard(BuildContext context) {
    if (kDebugMode) {
      debugPrint(
        '💰 GROOMY REVENUE QUERY → authUid=${FirebaseAuth.instance.currentUser?.uid ?? "NULL"} '
        'businessId=$businessId path=groomy_appointments where businessId==$businessId',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groomy_appointments')
          .where('businessId', isEqualTo: businessId)
          .snapshots(includeMetadataChanges: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint(
              '💰 GROOMY REVENUE ERROR → businessId=$businessId error=${snapshot.error}',
            );
          }
          return _emptyBox('Revenue error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final paidDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          return status == 'completed' || status == 'confirmed_paid';
        }).toList();

        if (paidDocs.isEmpty) {

 return const SizedBox.shrink();

}

        double netRevenue = 0;
        double grossSales = 0;
        double commissionTotal = 0;
        double penaltyTotal = 0;

        final appointmentCount = paidDocs.length;

final averageTicket =
appointmentCount == 0
? 0.0
: grossSales / appointmentCount;

        for (final doc in paidDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final rawAmount =
              data['paymentAmount'] ??
              data['finalPrice'] ??
              data['servicePrice'] ??
              data['price'] ??
              data['totalPrice'] ??
              0;
          final amount = rawAmount is num
              ? rawAmount.toDouble()
              : double.tryParse(rawAmount.toString()) ?? 0;

          netRevenue += amount;
          grossSales += amount;

          if (kDebugMode) {
            debugPrint('💸 GROOMY APPOINTMENT ${doc.id} → amount=$amount');
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF9E1B4F),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Net Revenue',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                '₺${netRevenue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'After platform commission',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 12),
              _row('Gross Sales', grossSales),

_row('Platform Fee', -commissionTotal),

_row('Adjustments', -penaltyTotal),

const SizedBox(height: 14),

Row(
 children: [

   _revenueKpi(
     label: 'Paid Appointments',
     value: appointmentCount.toString(),
   ),

   const SizedBox(width:10),

   _revenueKpi(
     label: 'Average Ticket',
     value:
      '₺${averageTicket.toStringAsFixed(0)}',
   ),

 ],
),
            ],
          ),
        );
      },
    );
  }

  Widget _revenueKpi({
 required String label,
 required String value,
}) {

 return Expanded(
   child: Container(
     padding: const EdgeInsets.all(12),

     decoration: BoxDecoration(
       color: Colors.white.withValues(alpha: 0.10),

       borderRadius: BorderRadius.circular(12),

       border: Border.all(
         color: Colors.white.withValues(alpha: 0.10),
       ),
     ),

     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,

       children: [

         Text(
           value,

           style: const TextStyle(
             color: Colors.white,
             fontSize: 18,
             fontWeight: FontWeight.w800,
           ),
         ),

         const SizedBox(height: 3),

         Text(
           label,

           style: const TextStyle(
             color: Colors.white60,
             fontSize: 12,
             fontWeight: FontWeight.w600,
           ),
         ),
       ],
     ),
   ),
 );

}

  Widget _buildProfileSection(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyBox('Profile error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final profile = Map<String, dynamic>.from(data['profile'] ?? {});
        final contact = Map<String, dynamic>.from(data['contact'] ?? {});
        final sectorData = Map<String, dynamic>.from(data['sectorData'] ?? {});
        final groomyData = Map<String, dynamic>.from(
          sectorData['groomy'] ?? sectorData['groomer'] ?? {},
        );
        final groomyProfile = Map<String, dynamic>.from(
          groomyData['profile'] ?? {},
        );

        final name =
            (profile['displayName'] ??
                    profile['businessName'] ??
                    groomyData['salonName'] ??
                    groomyData['businessName'] ??
                    'Groomy Salon')
                .toString();
        final bio =
            (profile['bio'] ??
                    profile['description'] ??
                    groomyProfile['bio'] ??
                    groomyData['description'] ??
                    '')
                .toString();
        final phone = (contact['phone'] ?? '').toString();
        final email = (contact['email'] ?? '').toString();
        final city = (contact['city'] ?? '').toString();
        final district = (contact['district'] ?? '').toString();
        final chips = <String>[
          if (phone.isNotEmpty) 'Phone: $phone',
          if (email.isNotEmpty) 'Email: $email',
          if (city.isNotEmpty || district.isNotEmpty)
            'Location: ${[city, district].where((e) => e.isNotEmpty).join(' / ')}',
          'Groomy',
        ];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Salon Profile', style: AppTheme.h2())),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EditGroomyProfilePage(businessId: businessId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(name, style: AppTheme.h3(weight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                bio.isNotEmpty ? bio : 'No description yet',
                style: AppTheme.body(
                  color: bio.isNotEmpty ? AppTheme.textDark : AppTheme.muted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips.map(_chip).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groomy_appointments')
          .where('businessId', isEqualTo: businessId)
          .snapshots(),
      builder: (context, appointmentsSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('businesses')
              .doc(businessId)
              .collection('services')
              .snapshots(),
          builder: (context, servicesSnapshot) {
            if (appointmentsSnapshot.hasError) {
              return _emptyBox('Stats error: ${appointmentsSnapshot.error}');
            }

            if (appointmentsSnapshot.connectionState ==
                    ConnectionState.waiting ||
                servicesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final appointments = appointmentsSnapshot.data?.docs ?? [];
            final services = servicesSnapshot.data?.docs ?? [];
            final now = DateTime.now();

            final todayAppointments = appointments.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = data['scheduledAt'];
              if (ts is! Timestamp) return false;
              final date = ts.toDate();
              return date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
            }).length;

            final pendingAppointments = appointments.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return (data['status'] ?? '').toString().toLowerCase() ==
                  'pending';
            }).length;

            final completedAppointments = appointments.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = (data['status'] ?? '').toString().toLowerCase();
              return status == 'completed' || status == 'confirmed_paid';
            }).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stats', style: AppTheme.h2()),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statBox('Total Services', services.length.toString()),
                    const SizedBox(width: 10),
                    _statBox(
                      'Today',
                      todayAppointments.toString(),
                      color: const Color(0xFF9E1B4F),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statBox(
                      'Pending',
                      pendingAppointments.toString(),
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    _statBox(
                      'Completed',
                      completedAppointments.toString(),
                      color: Colors.green,
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAppointmentsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent Appointments', style: AppTheme.h2()),
                  const SizedBox(height: 4),
                  Text(
                    'Latest grooming requests and sessions',
                    style: AppTheme.caption(color: AppTheme.muted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: Open Groomy appointments tab/detail navigation.
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('groomy_appointments')
              .where('businessId', isEqualTo: businessId)
              .orderBy('scheduledAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Appointment error: ${snapshot.error}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.calendar, color: Colors.black38),
                    const SizedBox(width: 10),
                    Text(
                      'No grooming appointments yet',
                      style: AppTheme.body(color: AppTheme.muted),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _appointmentCard(context, doc.id, data);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _appointmentCard(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) {
    final status = (data['status'] ?? 'pending').toString();
    final statusLabel = status.replaceAll('_', ' ');
    final rawAmount =
        data['paymentAmount'] ??
        data['finalPrice'] ??
        data['servicePrice'] ??
        data['price'] ??
        data['totalPrice'] ??
        0;
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount.toString()) ?? 0;
    final services = data['services'] is List
        ? data['services'] as List
        : data['serviceIds'] is List
        ? data['serviceIds'] as List
        : data['serviceTitle'] != null
        ? [data['serviceTitle']]
        : const [];
    final ts = data['scheduledAt'];
    final date = ts is Timestamp ? ts.toDate() : null;
    final dateLabel = date == null
        ? '-'
        : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF9E1B4F).withOpacity(0.10)),
        boxShadow: AppTheme.cardShadow(opacity: 0.06),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            // TODO: Open Groomy appointment detail page when available.
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9E1B4F).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.scissors,
                    color: Color(0xFF9E1B4F),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appointment #${id.length > 6 ? id.substring(0, 6) : id}',
                        style: AppTheme.body(
                          color: AppTheme.textDark,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _statusPill(status),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${services.length} service${services.length == 1 ? '' : 's'}',
                              style: AppTheme.caption(color: AppTheme.muted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$dateLabel • ₺${amount.toStringAsFixed(0)}',
                        style: AppTheme.caption(color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      statusLabel,
                      style: AppTheme.caption(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 8),
                    const Icon(Icons.chevron_right, color: Colors.black38),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String title, double value) {
    final isNegative = value < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          Text(
            '${isNegative ? '-' : ''}₺${value.abs().toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String title, String value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF9E1B4F).withOpacity(0.2)),
          boxShadow: AppTheme.cardShadow(opacity: 0.08),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTheme.h2(
                color: color ?? AppTheme.textDark,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center, style: AppTheme.caption()),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'confirmed_paid':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      case 'rejected':
      case 'cancelled_by_user':
      case 'cancelled_by_business':
        return Colors.red;
      case 'awaiting_payment':
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _emptyBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Colors.black12),
      ),
      child: Text(text, style: AppTheme.body(color: AppTheme.muted)),
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
        style: AppTheme.caption(color: const Color(0xFF9E1B4F)),
      ),
    );
  }
}
