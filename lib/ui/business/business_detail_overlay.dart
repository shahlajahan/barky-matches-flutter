import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'business_card_data.dart';
import '../vet/suggest_clinic_sheet.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';

enum _BusinessTab { info, services, action, contact }

class BusinessDetailOverlay extends StatefulWidget {
  final BusinessCardData data;

  final VoidCallback onClose;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onDirections;

  /// فقط برای Vet معنی دارد
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
    _rebuildTabs();
  }

  @override
  void didUpdateWidget(covariant BusinessDetailOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // وقتی business عوض شد، تب‌ها و activeTab باید ریست شوند
    if (oldWidget.data.id != widget.data.id || oldWidget.data.type != widget.data.type) {
      _rebuildTabs();
    }
  }

  void _rebuildTabs() {
    _tabs = [
      _BusinessTab.info,
      _BusinessTab.services,
    ];

    // ✅ Vet و AdoptionCenter هر دو یک تب action دارند (ولی محتوا فرق می‌کند)
    if (widget.data.type == BusinessType.vet || widget.data.type == BusinessType.adoptionCenter) {
      _tabs.add(_BusinessTab.action);
    }

    _tabs.add(_BusinessTab.contact);
    _activeTab = _tabs.first;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ⛔️ فقط بک‌گراند close می‌کند
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black54),
          ),
        ),

        // ✅ کارت وسط
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
  // HEADER
  // ─────────────────────────────
  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.data.name, style: AppTheme.h2(color: Colors.white)),
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
            if (widget.data.isVerified) _badge('Verified'),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────
  // TABS
  // ─────────────────────────────
  Widget _buildTabs() {
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
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
        return widget.data.type == BusinessType.adoptionCenter ? 'Process' : 'Services';

      case _BusinessTab.action:
        return widget.data.type == BusinessType.adoptionCenter ? 'Adoption' : 'Appointment';

      case _BusinessTab.contact:
        return 'Contact';
    }
  }

  // ─────────────────────────────
  // CONTENT
  // ─────────────────────────────
  Widget _buildTabContent() {
    switch (_activeTab) {
      case _BusinessTab.info:
        return _infoTab();

      case _BusinessTab.services:
        return _servicesTab();

      case _BusinessTab.action:
        return _actionTab();

      case _BusinessTab.contact:
        return _contactTab();
    }
  }

  Widget _infoTab() {
    final isAdoption = widget.data.type == BusinessType.adoptionCenter;

    final about = widget.data.description?.trim();
    final hasAbout = about != null && about.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.data.rating != null) ...[
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text('${widget.data.rating}', style: AppTheme.h2(color: Colors.white)),
              if (widget.data.reviewsCount != null)
                Text(' (${widget.data.reviewsCount} reviews)', style: AppTheme.caption(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 12),
        ],

        if (widget.data.workingHours != null) ...[
          _sectionTitle(isAdoption ? 'Visiting Hours' : 'Working Hours'),
          const SizedBox(height: 6),
          ...widget.data.workingHours!.entries.map(
            (e) => Text('${e.key}: ${e.value}', style: AppTheme.caption(color: Colors.white70)),
          ),
          const SizedBox(height: 12),
        ],

        _sectionTitle(isAdoption ? 'About This Center' : 'About'),
        const SizedBox(height: 6),
        Text(
          hasAbout
              ? about!
              : (isAdoption
                  ? 'This is an adoption center listed on BarkyMatches. Contact them to learn requirements and available dogs.'
                  : 'No description provided.'),
          style: AppTheme.caption(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _servicesTab() {
    // 🐾 Adoption center process
    if (widget.data.type == BusinessType.adoptionCenter) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _processStep('1. Contact the center'),
          _processStep('2. Share your adoption details'),
          _processStep('3. Meet the dog'),
          _processStep('4. Approval & handover'),
        ],
      );
    }

    // Vet normal services
    if (widget.data.services == null || widget.data.services!.isEmpty) {
      return Text('No services provided.', style: AppTheme.caption(color: Colors.white70));
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
                  Expanded(child: Text(s, style: AppTheme.caption(color: Colors.white))),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _actionTab() {
  if (widget.data.type == BusinessType.adoptionCenter) {
    final hasWhatsApp = widget.onWhatsApp != null;
    final hasCall = widget.onCall != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Start Adoption', style: AppTheme.h2(color: Colors.white)),
        const SizedBox(height: 8),
        Text(
          'Use WhatsApp or call to start the adoption process.',
          style: AppTheme.caption(color: Colors.white70),
        ),
        const SizedBox(height: 16),

        // 🔥 دکمه جدید
        GestureDetector(
  onTap: () {
    // اول صفحه center dogs رو باز کن
    context.read<AppState>().openCenterDogs(widget.data.id);

    // بعد overlay رو ببند
    widget.onClose();
  },
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 14),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Text(
      'View Available Dogs',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFF9E1B4F),
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
  ),
),

        // 🟡 دکمه قبلی تماس
        GestureDetector(
          onTap: hasWhatsApp
              ? widget.onWhatsApp
              : (hasCall ? widget.onCall : null),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              hasWhatsApp
                  ? 'Message on WhatsApp'
                  : (hasCall ? 'Call the Center' : 'No contact info'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }


    // 🩺 Vet action
if (widget.data.type == BusinessType.vet) {
  final isPartner = widget.data.isPartner;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        isPartner
            ? 'Book an Appointment'
            : 'This clinic is not yet a BarkyMatches partner.',
        style: AppTheme.h2(color: Colors.white),
      ),
      const SizedBox(height: 8),
      Text(
        isPartner
            ? 'This clinic accepts appointments via BarkyMatches.'
            : 'You can suggest this clinic to join BarkyMatches.',
        style: AppTheme.caption(color: Colors.white70),
      ),
      const SizedBox(height: 16),

      GestureDetector(
        onTap: () {
          if (isPartner) {
            // ✅ partner → برو appointment
            widget.onClose();
            widget.onOpenAppointment?.call();
          } else {
            // ❌ not partner → Suggest Clinic
            widget.onClose();

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
          child: Text(
            'Request Appointment', // همون متن قبلی
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    ],
  );
}

    return const SizedBox();
  }

  Widget _contactTab() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _cta(Icons.call, widget.onCall),
        _cta(Icons.chat_bubble_outline, widget.onWhatsApp),
        _cta(Icons.directions, widget.onDirections),
        TextButton(
          onPressed: widget.onClose,
          child: const Text('Close', style: TextStyle(color: Colors.amber)),
        ),
      ],
    );
  }

  // ─────────────────────────────
  // UI helpers
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

  Widget _processStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTheme.caption(color: Colors.white))),
        ],
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