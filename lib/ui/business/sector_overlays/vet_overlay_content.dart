import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';
import '../business_card_data.dart';
import '../../vet/suggest_clinic_sheet.dart';
import 'package:lucide_icons/lucide_icons.dart';

class VetOverlayContent extends StatelessWidget {
  final BusinessCardData data;

  final bool showInfo;
  final bool showServices;
  final bool showAction;

  final VoidCallback? onOpenAppointment;
  final VoidCallback? onOpenFullProfile; // 🔥 NEW
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onClose;

  const VetOverlayContent({
    super.key,
    required this.data,
    required this.showInfo,
    required this.showServices,
    required this.showAction,
    this.onOpenAppointment,
    this.onOpenFullProfile, // 🔥 NEW
    this.onCall,
    this.onWhatsApp,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (showInfo) return _buildInfo();
    if (showServices) return _buildServices();
    if (showAction) return _buildAction(context);

    return const SizedBox();
  }

  // ─────────────────────────────
  // INFO
  // ─────────────────────────────
  Widget _buildInfo() {
    final about =
        (data.description != null && data.description!.trim().isNotEmpty)
        ? data.description!.trim()
        : data.type == BusinessType.groomer
 ? "No groomer description available."
 : "No clinic description available.";

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.rating != null) ...[
            Row(
              children: [
                const Icon(LucideIcons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${data.rating}',
                  style: AppTheme.bodyMedium(
                    color: Colors.white,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                if (data.reviewsCount != null)
                  Text(
                    ' (${data.reviewsCount} reviews)',
                    style: AppTheme.caption(color: Colors.white70),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          Text(
            data.type == BusinessType.groomer
   ? "About Groomer"
   : "About",
            style: AppTheme.bodyMedium(
              color: Colors.white,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            about,
            style: AppTheme.caption(
              color: Colors.white70,
            ).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────
  // SERVICES
  // ─────────────────────────────
  Widget _buildServices() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(data.id)
          .collection('services')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text(
            'Services could not be loaded.',
            style: AppTheme.caption(color: Colors.white70),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Text(
            "No services provided.",
            style: AppTheme.caption(color: Colors.white70),
          );
        }

        return ListView(
          padding: EdgeInsets.zero,
          children: docs.map((doc) {
            final service = doc.data();
            return _serviceRow(service);
          }).toList(),
        );
      },
    );
  }

  Widget _serviceRow(Map<String, dynamic> service) {
    final title = (service['title'] ?? '').toString().trim();
    final price = service['price'];
    final duration = service['duration'] ?? service['durationMin'];
    final description = (service['description'] ?? '').toString().trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.check, color: Colors.amber, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Service' : title,
                  style: AppTheme.bodyMedium(
                    color: Colors.white,
                  ).copyWith(height: 1.4),
                ),
                if (price != null || duration != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (price != null) '₺$price',
                      if (duration != null) duration.toString(),
                    ].join(' • '),
                    style: AppTheme.caption(color: Colors.white70),
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: AppTheme.caption(color: Colors.white60),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────
  // ACTION (Appointment)
  // ─────────────────────────────
  Widget _buildAction(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.isPartner

? 'Book an Appointment'

: data.type == BusinessType.groomer

    ? 'This groomer is not yet a partner.'

    : 'This clinic is not yet a partner.',
            style: AppTheme.bodyMedium(
              color: Colors.white,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            data.isPartner
    ? data.type == BusinessType.groomer
        ? 'This groomer accepts appointments via PetSopu.'
        : 'This clinic accepts appointments via PetSopu.'
                : data.type == BusinessType.groomer

? 'You can invite this groomer to join PetSopu.'

: 'You can request this clinic to join PetSopu.',
            style: AppTheme.caption(
              color: Colors.white70,
            ).copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          GestureDetector(
           onTap: () {

  if (data.isPartner) {

    if (data.type == BusinessType.groomer) {

   onOpenFullProfile?.call();

   return;
}

    onOpenFullProfile?.call();

  } else {

    onClose?.call();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SuggestClinicSheet(
        vetName: data.name,
      ),
    );
  }
},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Request Appointment",
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium(
                  color: Colors.black,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
