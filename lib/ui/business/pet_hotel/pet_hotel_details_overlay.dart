import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import '../dashboard/pet_hotel/pet_hotel_reviews_tab.dart';

enum _PetHotelDetailsTab { overview, services, reviews, gallery }

class PetHotelDetailsOverlay extends StatefulWidget {
  final BusinessCardData data;
  final VoidCallback onClose;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onDirections;
  final ValueChanged<Map<String, dynamic>>? onOpenBooking;

  const PetHotelDetailsOverlay({
    super.key,
    required this.data,
    required this.onClose,
    this.onCall,
    this.onWhatsApp,
    this.onDirections,
    this.onOpenBooking,
  });

  @override
  State<PetHotelDetailsOverlay> createState() => _PetHotelDetailsOverlayState();
}

class _PetHotelDetailsOverlayState extends State<PetHotelDetailsOverlay> {
  _PetHotelDetailsTab _activeTab = _PetHotelDetailsTab.overview;

  Map<String, dynamic> get _hotelData {
    final rawData = widget.data.rawData ?? widget.data.data ?? {};
    final sectorData = Map<String, dynamic>.from(rawData['sectorData'] ?? {});
    return Map<String, dynamic>.from(
      sectorData['pet_hotel'] ??
          sectorData['hotel'] ??
          sectorData['petHotel'] ??
          {},
    );
  }

  List<Map<String, dynamic>> _fallbackServices() {
    final servicesData = _hotelData['services'];
    List<String> titles = [];

    if (servicesData is Map && servicesData['offeredServices'] is List) {
      titles = List<String>.from(servicesData['offeredServices']);
    } else if (servicesData is List) {
      titles = servicesData.map((item) => item.toString()).toList();
    } else if (widget.data.services != null) {
      titles = widget.data.services!;
    }

    if (titles.isEmpty) {
      titles = const ['Standard Room', 'VIP Room', 'Daily Care'];
    }

    return titles
        .where((title) => title.trim().isNotEmpty)
        .map(
          (title) => {
            'id': title.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
            'title': title,
            'price': null,
            'durationType': 'night',
          },
        )
        .toList();
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item?.toString() ?? '').toList();
    }
    final text = value?.toString() ?? '';
    return text.trim().isEmpty ? <String>[] : <String>[text];
  }

  List<String> _galleryImages() {
    final rawData = widget.data.rawData ?? widget.data.data ?? {};
    final profileContent = Map<String, dynamic>.from(
      _hotelData['profileContent'] ?? _hotelData['media'] ?? {},
    );

    final images = <String>[
      ..._stringList(rawData['images']),
      ..._stringList(rawData['clinicPhotoUrls']),
      ..._stringList(profileContent['clinicPhotoUrls']),
      ..._stringList(profileContent['photos']),
      ..._stringList(_hotelData['coverImage']),
      ..._stringList(widget.data.logoUrl),
    ];

    return images.where((url) => url.trim().isNotEmpty).toSet().toList();
  }

  double _servicePrice(Map<String, dynamic> service) {
    final raw = service['price'] ?? service['pricePerNight'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  int _maxCapacity() {
    final capacity = Map<String, dynamic>.from(_hotelData['capacity'] ?? {});
    final raw =
        capacity['maxCapacity'] ??
        _hotelData['maxCapacity'] ??
        (widget.data.rawData ?? {})['maxCapacity'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  List<String> _amenities() {
    final amenities = _hotelData['amenities'];
    if (amenities is List) {
      return amenities
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final features = Map<String, dynamic>.from(
      _hotelData['operationalDetails'] ?? {},
    );
    return features.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
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
        Positioned.fill(
          child: SafeArea(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      _header(),
                      _tabBar(),
                      Expanded(child: _tabContent()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      color: const Color(0xFF9E1B4F),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.data.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.h2(
                    color: Colors.white,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.data.district}, ${widget.data.city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption(color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: _PetHotelDetailsTab.values.map((tab) {
          final selected = _activeTab == tab;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? Colors.amber : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  _tabTitle(tab),
                  textAlign: TextAlign.center,
                  style: AppTheme.caption().copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.black87 : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _tabTitle(_PetHotelDetailsTab tab) {
    switch (tab) {
      case _PetHotelDetailsTab.overview:
        return 'Overview';
      case _PetHotelDetailsTab.services:
        return 'Services';
      case _PetHotelDetailsTab.reviews:
        return 'Reviews';
      case _PetHotelDetailsTab.gallery:
        return 'Gallery';
    }
  }

  Widget _tabContent() {
    switch (_activeTab) {
      case _PetHotelDetailsTab.overview:
        return _overview();
      case _PetHotelDetailsTab.services:
        return _services();
      case _PetHotelDetailsTab.reviews:
        return _reviews();
      case _PetHotelDetailsTab.gallery:
        return _gallery();
    }
  }

  Widget _overview() {
    final amenities = _amenities();
    final maxCapacity = _maxCapacity();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if ((widget.data.description ?? '').trim().isNotEmpty) ...[
          Text(widget.data.description!, style: AppTheme.body()),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            if (maxCapacity > 0)
              Expanded(
                child: _infoTile(
                  LucideIcons.hotel,
                  'Capacity',
                  '$maxCapacity pets',
                ),
              ),
            if (maxCapacity > 0) const SizedBox(width: 10),
            Expanded(
              child: _infoTile(
                LucideIcons.mapPin,
                'Location',
                [
                  widget.data.district,
                  widget.data.city,
                ].where((item) => item.trim().isNotEmpty).join(', '),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (amenities.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: amenities
                .map(
                  (item) =>
                      Chip(label: Text(item), backgroundColor: Colors.white),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            _contactButton(LucideIcons.phone, widget.onCall),
            const SizedBox(width: 10),
            _contactButton(LucideIcons.messageCircle, widget.onWhatsApp),
            const SizedBox(width: 10),
            _contactButton(LucideIcons.navigation, widget.onDirections),
          ],
        ),
      ],
    );
  }

  Widget _services() {
    final stream = FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.data.id)
        .collection('services')
        .orderBy('sortOrder')
        .snapshots()
        .handleError((e) {
          debugPrint(
            '🔥 FIRESTORE STREAM ERROR => businesses/${widget.data.id}/services :: $e',
          );
        });
    debugPrint('🔥 LISTENING PATH => businesses/${widget.data.id}/services');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final services = <Map<String, dynamic>>[];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          services.addAll(
            snapshot.data!.docs
                .map((doc) => {...doc.data(), 'id': doc.id})
                .where((service) => service['isActive'] != false),
          );
        } else {
          services.addAll(_fallbackServices());
        }

        if (services.isEmpty) {
          return const Center(child: Text('No services available'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: services.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final service = services[index];
            final title = service['title']?.toString() ?? '';
            final price = _servicePrice(service);
            final description = service['description']?.toString() ?? '';

            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: widget.onOpenBooking == null
                    ? null
                    : () => widget.onOpenBooking!(service),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.hotel, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTheme.body().copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (description.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.caption(color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (price > 0)
                        Text(
                          '₺${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
                          style: AppTheme.body().copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _reviews() {
    return PetHotelReviewsTab(businessId: widget.data.id);
  }

  Widget _gallery() {
    final images = _galleryImages();
    if (images.isEmpty) {
      return const Center(child: Text('No gallery images yet'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            images[index],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.white,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        );
      },
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9E1B4F)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.caption(color: AppTheme.muted)),
                Text(
                  value.isEmpty ? '-' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption().copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactButton(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? Colors.amber : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Icon(icon, color: enabled ? Colors.black : Colors.grey),
      ),
    );
  }
}
