import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'business_card_data.dart';

class BusinessCard extends StatelessWidget {
  final BusinessCardData data;

  final VoidCallback? onTap;
  final VoidCallback? onCallTap;
  final VoidCallback? onWhatsAppTap;
  final VoidCallback? onDirectionsTap;

  const BusinessCard({
    super.key,
    required this.data,
    this.onTap,
    this.onCallTap,
    this.onWhatsAppTap,
    this.onDirectionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: AppTheme.cardShadow(),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Text(
        data.name,
        style: AppTheme.h2().copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    if (_buildStatusBadge() != null)
      _buildStatusBadge()!,

    if (data.is24h)
      _Badge(text: '24/7', color: AppTheme.success),

    if (data.isEmergency) ...[
      const SizedBox(width: 6),
      _Badge(text: 'Emergency', color: AppTheme.danger),
    ],
  ],
),
            const SizedBox(height: 6),
            Text(
              _addressLine(),
              style: AppTheme.caption(),
            ),
            const SizedBox(height: 8),
            if (data.specialties.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: data.specialties
    .map<Widget>((s) => _Chip(label: s))
    .toList(),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                _CtaButton(
                  icon: Icons.call,
                  enabled: data.phone != null,
                  onTap: onCallTap,
                ),
                const SizedBox(width: 8),
                _CtaButton(
                  icon: Icons.chat_bubble_outline,
                  enabled: data.whatsapp != null,
                  onTap: onWhatsAppTap,
                ),
                const SizedBox(width: 8),
                _CtaButton(
                  icon: Icons.directions,
                  enabled: true,
                  onTap: onDirectionsTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _addressLine() {
    if (data.distanceKm == null) {
      return data.address ?? '';
    }
    return '${data.address ?? ''} • ${data.distanceKm!.toStringAsFixed(1)} km';
  }
  Widget? _buildStatusBadge() {
  // Suspended
  if (data.status == "suspended") {
    return _Badge(
      text: "Suspended",
      color: AppTheme.danger,
    );
  }

  // Rejected
  if (data.status == "rejected") {
    return _Badge(
      text: "Rejected",
      color: AppTheme.danger,
    );
  }

  // Pending
  if (data.status == "pending") {
    return _Badge(
      text: "Under Review",
      color: Colors.orange,
    );
  }

  // Verified
  if (data.isVerified) {
    return _Badge(
      text: "Verified",
      color: AppTheme.success,
    );
  }

  return null;
}
}
  // ─────────────────────────────────────────────
// 🔘 CTA Button
// ─────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _CtaButton({
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.amber
              : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? Colors.black : Colors.grey,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 🏷 Badge
// ─────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 🏷 Specialty Chip
// ─────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
