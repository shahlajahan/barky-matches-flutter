import 'package:flutter/material.dart';
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
            "About",
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
    if (data.services == null || data.services!.isEmpty) {
      return Text(
        "No services provided.",
        style: AppTheme.caption(color: Colors.white70),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: data.services!
          .map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      LucideIcons.check,
                      color: Colors.amber,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s,
                      style: AppTheme.bodyMedium(
                        color: Colors.white,
                      ).copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
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
                : 'This clinic is not yet a partner.',
            style: AppTheme.bodyMedium(
              color: Colors.white,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            data.isPartner
                ? 'This clinic accepts appointments via PetSopu.'
                : 'You can request this clinic to join PetSopu.',
            style: AppTheme.caption(
              color: Colors.white70,
            ).copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              if (data.isPartner) {
 onOpenFullProfile?.call();
} else {
                onClose?.call();

                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => SuggestClinicSheet(vetName: data.name),
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
