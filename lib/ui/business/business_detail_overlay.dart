import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'business_card_data.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';

// ✅ NEW imports (sector-based)
import 'sector_overlays/vet_overlay_content.dart';
import 'sector_overlays/adoption_overlay_content.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'pet_hotel/pet_hotel_details_page.dart';

enum _BusinessTab { info, services, action, contact }

class BusinessDetailOverlay extends StatefulWidget {
  final BusinessCardData data;

  final VoidCallback onClose;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onDirections;
  final VoidCallback? onOpenAppointment;

  const BusinessDetailOverlay({
    super.key,
    required this.data,
    required this.onClose,
    this.onCall,
    this.onWhatsApp,
    this.onDirections,
    this.onOpenAppointment,
  });

  @override
  State<BusinessDetailOverlay> createState() => _BusinessDetailOverlayState();
}

class _BusinessDetailOverlayState extends State<BusinessDetailOverlay> {
  late List<_BusinessTab> _tabs;
  late _BusinessTab _activeTab;

  @override
  void initState() {
    super.initState();
    _buildTabs();
  }

  @override
  void didUpdateWidget(covariant BusinessDetailOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.id != widget.data.id ||
        oldWidget.data.type != widget.data.type) {
      _buildTabs();
    }
  }

  void _buildTabs() {
    _tabs = [_BusinessTab.info, _BusinessTab.services];

    if (widget.data.type == BusinessType.vet ||
        widget.data.type == BusinessType.adoptionCenter ||
        widget.data.type == BusinessType.petHotel) {
      _tabs.add(_BusinessTab.action);
    }

    _tabs.add(_BusinessTab.contact);
    _activeTab = _tabs.first;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black54),
          ),
        ),
        Center(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF9E1B4F),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(),
                const SizedBox(height: 16),
                _buildTabsUI(),
                const SizedBox(height: 16),
                SizedBox(height: 120, child: _buildTabContent()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────
  // HEADER
  // ─────────────────────────────
  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.data.name,
          style: AppTheme.h2(
            color: Colors.white,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.data.district}, ${widget.data.city}'
          '${widget.data.distanceKm != null ? ' • ${widget.data.distanceKm!.toStringAsFixed(1)} km' : ''}',
          style: AppTheme.bodyMedium(color: Colors.white70),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (widget.data.is24h) _badge('24/7'),
            if (widget.data.isEmergency) _badge('Emergency'),
            if (widget.data.isVerified) _badge('Verified'),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────
  // TABS UI
  // ─────────────────────────────
  Widget _buildTabsUI() {
    return Row(
      children: _tabs.map((tab) {
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
                _tabTitle(tab),
                textAlign: TextAlign.center,
                style: AppTheme.caption(
                  color: active ? Colors.white : Colors.white70,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _tabTitle(_BusinessTab tab) {
    switch (tab) {
      case _BusinessTab.info:
        return 'Info';
      case _BusinessTab.services:
        return widget.data.type == BusinessType.adoptionCenter
            ? 'Process'
            : 'Services';
      case _BusinessTab.action:
        return widget.data.type == BusinessType.adoptionCenter
            ? 'Adoption'
            : 'Appointment';
      case _BusinessTab.contact:
        return 'Contact';
    }
  }

  // ─────────────────────────────
  // CONTENT RESOLVER 🔥
  // ─────────────────────────────
  Widget _buildTabContent() {
    switch (_activeTab) {
      case _BusinessTab.info:
        return _buildInfoContent();

      case _BusinessTab.services:
        return _buildServicesContent();

      case _BusinessTab.action:
        return _buildActionContent();

      case _BusinessTab.contact:
        return _contactRow();
    }
  }

  // ─────────────────────────────
  // 🔥 INFO (shared)
  // ─────────────────────────────
  Widget _buildInfoContent() {
    return _resolveSectorWidget(info: true);
  }

  Widget _buildServicesContent() {
    return _resolveSectorWidget(services: true);
  }

  Widget _buildActionContent() {
    return _resolveSectorWidget(action: true);
  }

  // ─────────────────────────────
  // 🔥 CORE RESOLVER (THE MAGIC)
  // ─────────────────────────────
  Widget _resolveSectorWidget({
    bool info = false,
    bool services = false,
    bool action = false,
  }) {
    switch (widget.data.type) {
      case BusinessType.vet:
        return VetOverlayContent(
          data: widget.data,
          showInfo: info,
          showServices: services,
          showAction: action,

          onOpenAppointment: widget.onOpenAppointment,

          onOpenFullProfile: () {
            final appState = context.read<AppState>();
            appState.closeBusinessDetails();
            appState.openVetDetails(widget.data);
          },

          onCall: widget.onCall,
          onWhatsApp: widget.onWhatsApp,
          onClose: widget.onClose,
        );

      case BusinessType.adoptionCenter:
        return AdoptionOverlayContent(
          data: widget.data,
          showInfo: info,
          showServices: services,
          showAction: action,
          onCall: widget.onCall,
          onWhatsApp: widget.onWhatsApp,
          onClose: widget.onClose,
        );
      case BusinessType.petHotel:
        return VetOverlayContent(
          data: widget.data,

          showInfo: info,
          showServices: services,
          showAction: action,

          onOpenAppointment: widget.onOpenAppointment,

          onOpenFullProfile: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PetHotelDetailsPage(
                  data: widget.data,

                  onCall: widget.onCall,
                  onWhatsApp: widget.onWhatsApp,
                  onDirections: widget.onDirections,

                  onOpenBooking: (service) {
                    widget.onOpenAppointment?.call();
                  },
                ),
              ),
            );
          },

          onCall: widget.onCall,
          onWhatsApp: widget.onWhatsApp,
          onClose: widget.onClose,
        );

      default:
        return const SizedBox();
    }
  }

  // ─────────────────────────────
  // CONTACT
  // ─────────────────────────────
  Widget _contactRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _cta(LucideIcons.phone, widget.onCall),
        _cta(LucideIcons.messageCircle, widget.onWhatsApp),
        _cta(LucideIcons.navigation, widget.onDirections),
        TextButton(
          onPressed: widget.onClose,
          child: Text('Close', style: AppTheme.caption(color: Colors.amber)),
        ),
      ],
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
      child: Text(text, style: AppTheme.caption(color: Colors.black)),
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
          color: enabled ? Colors.amber : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: enabled ? Colors.black : Colors.white38),
      ),
    );
  }
}
