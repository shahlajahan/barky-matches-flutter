import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'business_card_data.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barky_matches_fixed/ui/common/smart_media.dart';

class BusinessCard extends StatelessWidget {
  final BusinessCardData data;

  final VoidCallback? onTap;
  final VoidCallback? onCallTap;
  final VoidCallback? onWhatsAppTap;
  final VoidCallback? onDirectionsTap;
  final VoidCallback? onMessageTap;

  const BusinessCard({
    super.key,
    required this.data,
    this.onTap,
    this.onCallTap,
    this.onWhatsAppTap,
    this.onDirectionsTap,
    this.onMessageTap,
  });

  // ─────────────────────────────────────────────
  // 🕒 TODAY HOURS
  // ─────────────────────────────────────────────

  String _getTodayHours() {
    final hours = data.workingHours;

    if (hours == null || hours.isEmpty) {
      return '';
    }

    final weekday = DateTime.now().weekday;

    const keys = {
      1: 'monday',
      2: 'tuesday',
      3: 'wednesday',
      4: 'thursday',
      5: 'friday',
      6: 'saturday',
      7: 'sunday',
    };

    final key = keys[weekday];

    if (key == null) {
      return '';
    }

    final raw = hours[key];

    // 🔥 NEW STRUCTURE
    if (raw is Map<String, dynamic>) {
      final isOpen = raw['open'] == true;

      if (!isOpen) {
        return 'Closed';
      }

      final todayHours = raw['hours']?.toString().trim() ?? '';
      return todayHours;
    }

    // 🔥 OLD STRUCTURE
    if (raw is String) {
      return raw.trim();
    }

    // 🔥 LEGACY FALLBACK
    if (hours['hours'] is String) {
      return hours['hours'].toString().trim();
    }

    return '';
  }

  @override
Widget build(BuildContext context) {
  final todayHours = _getTodayHours();

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

          // 🔥 TOP SECTION
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Expanded(
                child: Text(
                  data.name,

                  style: AppTheme.h2().copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: const Color(0xFF9E1B4F),
                  ),
                ),
              ),

              if (_buildStatusBadge() != null) ...[
                const SizedBox(width: 6),
                _buildStatusBadge()!,
              ],

              if (data.is24h)
                _Badge(
                  text: '24/7',
                  color: AppTheme.success,
                ),

              if (data.isEmergency) ...[
                const SizedBox(width: 6),

                _Badge(
                  text: 'Emergency',
                  color: AppTheme.danger,
                ),
              ],

              // 🔥 TODAY HOURS
              if (todayHours.isNotEmpty) ...[
                const SizedBox(width: 6),

                _Badge(
                  text: todayHours,
                  color: Colors.black87,
                ),
              ],
            ],
          ),

          const SizedBox(height: 6),

          // 🔥 ADDRESS
          Text(
            _addressLine(),

            style: AppTheme.caption().copyWith(
              color: Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: 8),

          // 🔥 SPECIALTIES
          if (data.specialties.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,

              children: data.specialties
                  .take(3)
                  .map<Widget>(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),

                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF9E1B4F,
                        ).withOpacity(0.1),

                        borderRadius:
                            BorderRadius.circular(8),
                      ),

                      child: Text(
                        s,

                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9E1B4F),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),

          const SizedBox(height: 10),

          // 🔥 CTA + LOGO SECTION
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,

            children: [

              // 🔥 LEFT SIDE
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,

                  physics:
                      const BouncingScrollPhysics(),

                  child: Row(
                    children: [

                      _CtaButton(
                        icon: LucideIcons.phone,
                        enabled:
                            data.phone != null,
                        onTap: onCallTap,
                      ),

                      const SizedBox(width: 8),

                      _CtaButton(
                        icon:
                            LucideIcons.messageCircle,
                        enabled:
                            data.whatsapp != null,
                        onTap: onWhatsAppTap,
                      ),

                      const SizedBox(width: 8),

                      _CtaButton(
                        icon:
                            LucideIcons.messageSquare,
                        enabled:
                            onMessageTap != null,
                        onTap: onMessageTap,
                      ),

                      const SizedBox(width: 8),

                      _CtaButton(
                        icon:
                            LucideIcons.navigation,
                        enabled: true,
                        onTap: onDirectionsTap,
                      ),

                      const SizedBox(width: 8),

                      // 🔥 INSTAGRAM
                      if (data.instagram != null) ...[
                        _CtaButton(
                          icon:
                              LucideIcons.instagram,
                          enabled: true,

                          onTap: () {
                            launchUrl(
                              Uri.parse(
                                "https://instagram.com/${data.instagram}",
                              ),

                              mode: LaunchMode
                                  .externalApplication,
                            );
                          },
                        ),

                        const SizedBox(width: 8),
                      ],

                      // 🔥 WEBSITE
                      if (data.website != null)
                        _CtaButton(
                          icon: LucideIcons.globe,
                          enabled: true,

                          onTap: () {
                            final url =
                                data.website!
                                        .startsWith(
                                          'http',
                                        )
                                    ? data.website!
                                    : 'https://${data.website!}';

                            launchUrl(
                              Uri.parse(url),

                              mode: LaunchMode
                                  .externalApplication,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // 🔥 LOGO
              if (data.logoUrl != null &&
                  data.logoUrl!.isNotEmpty) ...[
                const SizedBox(width: 12),

                Container(
                  width: 64,
                  height: 64,

                  padding:
                      const EdgeInsets.all(6),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius:
                        BorderRadius.circular(14),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(0.06),

                        blurRadius: 8,

                        offset: const Offset(
                          0,
                          3,
                        ),
                      ),
                    ],
                  ),

                  child: SmartMedia(
                    url: data.logoUrl!,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

  String _addressLine() {
    if (data.distanceKm == null) {
      return data.address;
    }

    return '${data.address} • ${data.distanceKm!.toStringAsFixed(1)} km';
  }

  Widget? _buildStatusBadge() {
    // Suspended
    if (data.status == "suspended") {
      return _Badge(text: "Suspended", color: AppTheme.danger);
    }

    // Rejected
    if (data.status == "rejected") {
      return _Badge(text: "Rejected", color: AppTheme.danger);
    }

    // Pending
    if (data.status == "pending") {
      return _Badge(text: "Under Review", color: Colors.orange);
    }

    // Verified
    if (data.isVerified) {
      return _Badge(text: "Verified", color: AppTheme.success);
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

  const _CtaButton({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,

      borderRadius: BorderRadius.circular(8),

      child: Container(
        padding: const EdgeInsets.all(10),

        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFFFFC107)
              : Colors.grey.withOpacity(0.2),

          borderRadius: BorderRadius.circular(8),
        ),

        child: Icon(
          icon,
          size: 18,
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

  const _Badge({required this.text, required this.color});

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

        style: AppTheme.caption().copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),

      child: Text(label, style: AppTheme.caption()),
    );
  }
}
