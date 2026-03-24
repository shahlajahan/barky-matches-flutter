import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'vet_card_data.dart';
import 'suggest_clinic_sheet.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';


class VetDetailOverlay extends StatefulWidget {

final BusinessCardData data;
  final VoidCallback onClose;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onDirections;
  final double? rating;        // 4.6
  final int? reviewsCount;     // 128
  final VoidCallback? onOpenAppointment;



  const VetDetailOverlay({
    super.key,
    required this.data,
    required this.onClose,
    this.onCall,
    this.onWhatsApp,
    this.onDirections,
    this.onOpenAppointment,
    this.rating,
    this.reviewsCount,

  });

  @override
  State<VetDetailOverlay> createState() => _VetDetailOverlayState();
}


enum _VetDetailTab { info, services, appointment, contact }


class _VetDetailOverlayState extends State<VetDetailOverlay> {
  _VetDetailTab _activeTab = _VetDetailTab.info;



  @override
Widget build(BuildContext context) {
  return Stack(
    children: [
      // ─────────────────────────────
      // ⛔️ Background (فقط این close می‌کند)
      // ─────────────────────────────
      Positioned.fill(
        child: GestureDetector(
          onTap: widget.onClose,
          child: Container(
            color: Colors.black54,
          ),
        ),
      ),

      // ─────────────────────────────
      // 🩺 Overlay Card (کلیک‌ها آزاد)
      // ─────────────────────────────
      Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF9E1B4F),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(),

                if (widget.data.rating != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.data.rating}',
                        style: AppTheme.caption(color: Colors.white),
                      ),
                      if (widget.data.reviewsCount != null)
                        Text(
                          ' (${widget.data.reviewsCount} reviews)',
                          style:
                              AppTheme.caption(color: Colors.white70),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                _buildTabs(),
                const SizedBox(height: 16),
                _buildTabContent(),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

  // ─────────────────────────────

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.data.name,
          style: AppTheme.h2(color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.data.district}, ${widget.data.city}'
          '${widget.data.distanceKm != null ? ' • ${widget.data.distanceKm!.toStringAsFixed(1)} km' : ''}',
          style: AppTheme.caption(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (widget.data.is24h) _badge('24/7'),
            if (widget.data.isEmergency) _badge('Emergency'),
          ],
        ),
      ],
    );
  }

  Widget _ctaRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _cta(Icons.call, widget.onCall),
        _cta(Icons.chat_bubble_outline, widget.onWhatsApp),
        _cta(Icons.directions,widget. onDirections),
        TextButton(
          onPressed: widget.onClose,
          child: const Text(
            'Close',
            style: TextStyle(color: Colors.amber),
          ),
        ),
      ],
    );
  }

Widget _buildTabs() {
  return Row(
    children: [
      _tabButton('Info', _VetDetailTab.info),
      _tabButton('Services', _VetDetailTab.services),
      _tabButton('Appointment', _VetDetailTab.appointment),
      _tabButton('Contact', _VetDetailTab.contact),
    ],
  );
}

Widget _tabButton(String label, _VetDetailTab tab) {
  final active = _activeTab == tab;
  return Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? Colors.amber : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  softWrap: false,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}


  // ─────────────────────────────

  Widget _sectionTitle(String text) {
  return Text(
    text,
    style: AppTheme.h2().copyWith(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  );
}


  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: AppTheme.caption(color: Colors.white),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTheme.caption(color: Colors.black),
      ),
    );
  }

  Widget _cta(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.amber
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.black : Colors.white38,
        ),
      ),
    );
  }
Widget _buildTabContent() {
  switch (_activeTab) {
    case _VetDetailTab.info:
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ⭐ Rating
      if (widget.data.rating != null) Row(
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 18),
          const SizedBox(width: 4),
          Text(
            '${widget.data.rating}',
            style: AppTheme.h2(color: Colors.white),
          ),
          if (widget.data.reviewsCount != null)
            Text(
              ' (${widget.data.reviewsCount} reviews)',
              style: AppTheme.caption(color: Colors.white70),
            ),
        ],
      ),

      const SizedBox(height: 12),

      // 🕒 Working hours
      if (widget.data.workingHours != null) ...[
        _sectionTitle('Working Hours'),
        const SizedBox(height: 6),
        ...widget.data.workingHours!.entries.map(
          (e) => Text(
            '${e.key}: ${e.value}',
            style: AppTheme.caption(color: Colors.white70),
          ),
        ),
      ],

      const SizedBox(height: 12),

      // 📝 Description
      if (widget.data.description != null) ...[
        _sectionTitle('About'),
        const SizedBox(height: 6),
        Text(
          widget.data.description!,
          style: AppTheme.caption(color: Colors.white70),
        ),
      ],
    ],
  );


     case _VetDetailTab.appointment:
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.data.isPartner
            ? 'Book an Appointment'
            : 'This clinic is not yet a BarkyMatches partner.',
        style: AppTheme.h2(color: Colors.white),
      ),
      const SizedBox(height: 8),
      Text(
        widget.data.isPartner
            ? 'This clinic accepts appointments via BarkyMatches.'
            : 'You can request this clinic to join BarkyMatches.',
        style: AppTheme.caption(color: Colors.white70),
      ),
      const SizedBox(height: 16),

      // ✅ فقط همین دکمه
      GestureDetector(
        onTap: () {
  if (widget.data.isPartner) {
    // ✅ partner → برو full page appointment
    widget.onClose(); // overlay بسته شود
    widget.onOpenAppointment?.call();
  } else {
    // ❌ partner نیست → Suggest Clinic Sheet
    widget.onClose(); // اول overlay بسته شود

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SuggestClinicSheet(
        vetName: widget.data.name,
      ),
    );
  }
},

        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.amber,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Request Appointment',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    ],
  );


  
    case _VetDetailTab.services:
  if (widget.data.services == null || widget.data.services!.isEmpty) {
    return Text(
      'No detailed services provided.',
      style: AppTheme.caption(color: Colors.white70),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: widget.data.services!
        .map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.check, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s,
                    style: AppTheme.caption(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );


    case _VetDetailTab.contact:
      return _ctaRow();
  }
}
}

