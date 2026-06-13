// lib/ui/business/adoption_center/adoption_center_details_overlay.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/dog_card.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';

enum _AdoptionCenterDetailsTab { overview, pets, reviews, gallery }

class AdoptionCenterDetailsOverlay extends StatefulWidget {
  final BusinessCardData data;

  final VoidCallback onClose;

  final VoidCallback? onCall;

  final VoidCallback? onWhatsApp;

  final VoidCallback? onDirections;

  final ValueChanged<Map<String, dynamic>>? onOpenPet;

  const AdoptionCenterDetailsOverlay({
    super.key,
    required this.data,
    required this.onClose,
    this.onCall,
    this.onWhatsApp,
    this.onDirections,
    this.onOpenPet,
  });

  @override
  State<AdoptionCenterDetailsOverlay> createState() =>
      _AdoptionCenterDetailsOverlayState();
}

class _AdoptionCenterDetailsOverlayState
    extends State<AdoptionCenterDetailsOverlay> {
  _AdoptionCenterDetailsTab _activeTab = _AdoptionCenterDetailsTab.overview;

  // =====================================================
  // FALLBACK PETS
  // =====================================================

  List<Map<String, dynamic>> _fallbackPets() {
    final rawData = widget.data.rawData ?? widget.data.data ?? {};

    final sectorData = Map<String, dynamic>.from(rawData['sectorData'] ?? {});

    final adoptionData = Map<String, dynamic>.from(
      sectorData['adoptionCenter'] ?? sectorData['adoption_center'] ?? {},
    );

    final servicesData = adoptionData['services'];

    List<String> titles = [];

    if (servicesData is Map && servicesData['offeredServices'] is List) {
      titles = List<String>.from(servicesData['offeredServices']);
    } else if (servicesData is List) {
      titles = servicesData.map((item) => item.toString()).toList();
    }

    return titles
        .where((title) => title.trim().isNotEmpty)
        .map(
          (title) => {
            'id': title.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),

            'title': title,

            'breed': '',

            'age': '',

            'gender': '',

            'price': null,
          },
        )
        .toList();
  }

  // =====================================================
  // GALLERY
  // =====================================================

  List<String> _galleryImages() {
    final rawData = widget.data.rawData ?? widget.data.data ?? {};

    final sectorData = Map<String, dynamic>.from(rawData['sectorData'] ?? {});

    final adoptionData = Map<String, dynamic>.from(
      sectorData['adoptionCenter'] ?? sectorData['adoption_center'] ?? {},
    );

    final profileContent = Map<String, dynamic>.from(
      adoptionData['profileContent'] ?? adoptionData['media'] ?? {},
    );

    final images = <String>[
      ..._stringList(rawData['images']),

      ..._stringList(rawData['clinicPhotoUrls']),

      ..._stringList(profileContent['photoUrls']),

      ..._stringList(profileContent['photos']),

      ..._stringList(adoptionData['coverImage']),

      ..._stringList(widget.data.logoUrl),
    ];

    return images.where((url) => url.trim().isNotEmpty).toSet().toList();
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item?.toString() ?? '').toList();
    }

    final text = value?.toString() ?? '';

    return text.trim().isEmpty ? <String>[] : <String>[text];
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

  // =====================================================
  // HEADER
  // =====================================================

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

  // =====================================================
  // TAB BAR
  // =====================================================

  Widget _tabBar() {
    return Container(
      color: Colors.white,

      child: Row(
        children: _AdoptionCenterDetailsTab.values.map((tab) {
          final selected = _activeTab == tab;

          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeTab = tab;
                });
              },

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

  String _tabTitle(_AdoptionCenterDetailsTab tab) {
    switch (tab) {
      case _AdoptionCenterDetailsTab.overview:
        return 'Overview';

      case _AdoptionCenterDetailsTab.pets:
        return 'Pets';

      case _AdoptionCenterDetailsTab.reviews:
        return 'Reviews';

      case _AdoptionCenterDetailsTab.gallery:
        return 'Gallery';
    }
  }

  Widget _tabContent() {
    switch (_activeTab) {
      case _AdoptionCenterDetailsTab.overview:
        return _overview();

      case _AdoptionCenterDetailsTab.pets:
        return _pets();

      case _AdoptionCenterDetailsTab.reviews:
        return _reviews();

      case _AdoptionCenterDetailsTab.gallery:
        return _gallery();
    }
  }

  // =====================================================
  // OVERVIEW
  // =====================================================

  Widget _overview() {
    final specialties = widget.data.specialties.isNotEmpty
        ? widget.data.specialties
        : widget.data.services ?? const <String>[];

    return ListView(
      padding: const EdgeInsets.all(16),

      children: [
        if ((widget.data.description ?? '').trim().isNotEmpty) ...[
          Text(widget.data.description!, style: AppTheme.body()),

          const SizedBox(height: 16),
        ],

        if (specialties.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,

            children: specialties
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

  // =====================================================
  // PETS
  // =====================================================

  Dog _dogFromAdoptionPet(Map<String, dynamic> pet) {
    final coverImageUrl = (pet['coverImageUrl'] ?? '').toString().trim();
    final gallery = pet['gallery'] is List
        ? List<String>.from(
            (pet['gallery'] as List).map((item) => item?.toString() ?? ''),
          ).where((url) => url.trim().isNotEmpty).toList()
        : <String>[];
    final imagePaths = <String>[
      if (coverImageUrl.isNotEmpty) coverImageUrl else ...gallery,
    ];
    final ageMonthsRaw = pet['ageMonths'];
    final ageMonths = ageMonthsRaw is num
        ? ageMonthsRaw.toDouble()
        : double.tryParse(ageMonthsRaw?.toString() ?? '') ?? 0;

    return Dog(
      id: (pet['id'] ?? '').toString(),
      ownerId: (pet['businessId'] ?? widget.data.id).toString(),
      name: (pet['name'] ?? '').toString(),
      breed: (pet['breed'] ?? '').toString(),
      gender: (pet['gender'] ?? '').toString(),
      age: (ageMonths / 12).round(),
      imagePaths: imagePaths,
      isAvailableForAdoption: true,
      healthStatus: (pet['healthStatus'] ?? '').toString(),
      isNeutered: pet['isNeutered'] == true,
      description: (pet['description'] ?? '').toString(),
      traits: const [],
      isOwner: false,
      petType: (pet['species'] ?? 'dog').toString(),
    );
  }

  Widget _pets() {
    final businessId = widget.data.id;
    print("DETAIL PET QUERY businessId=$businessId");

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('adoption_pets')
          .where('businessId', isEqualTo: businessId)
          .snapshots(),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        print("DETAIL PET COUNT=${snapshot.data?.docs.length ?? 0}");

        final dogs = <Dog>[];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          dogs.addAll(
            snapshot.data!.docs
                .map((doc) {
                  final data = doc.data();

                  return {...data, 'id': doc.id};
                })
                .where(
 (pet) =>

     pet['isActive'] != false &&

     (pet['status'] ?? 'available')
         == 'available'
)
                .map(_dogFromAdoptionPet),
          );
        } else {
          dogs.addAll(_fallbackPets().map(_dogFromAdoptionPet));
        }

        if (dogs.isEmpty) {
          return const Center(child: Text('No pets available'));
        }

        for(final d in snapshot.data!.docs){

  final data = d.data();

  print(
    "PET "
    "${d.id} "
    "active=${data['isActive']} "
    "available=${data['isAvailableForAdoption']}"
  );

}

        final appState = context.read<AppState>();
        final currentUserId = appState.currentUserId ?? '';

        return ListView.separated(
          padding: const EdgeInsets.all(16),

          itemCount: dogs.length,

          separatorBuilder: (_, __) => const SizedBox(height: 10),

          itemBuilder: (context, index) {
            final dog = dogs[index];

            return DogCard(
              mode: DogCardMode.compact,
              dog: dog,
              allDogs: dogs,
              currentUserId: currentUserId,
              favoriteDogs: appState.favoriteDogs,
              onToggleFavorite: appState.toggleFavorite,
              likers: appState.dogLikes[dog.id] ?? [],
              enableChat: false,
              enablePlaydate: false,
              enableEdit: false,
              enableNavigation: false,
              onCardTap: () {
                print("ADOPTION PET CARD TAP");
                print("OPEN ADOPTION PET DETAIL");
                print("DOG CARD FLOW REUSED");
                final appState = context.read<AppState>();
                appState.closeBusinessDetails();
                appState.openAdoptionDogOverlay(dog.id, dog: dog);
              },
            );
          },
        );
      },
    );
  }

  // =====================================================
  // REVIEWS
  // =====================================================

  Widget _reviews() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('businessId', isEqualTo: widget.data.id)
          .snapshots(),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text('No reviews yet'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),

          itemCount: docs.length,

          separatorBuilder: (_, __) => const SizedBox(height: 10),

          itemBuilder: (context, index) {
            final review = docs[index].data();

            final rating = review['rating']?.toString() ?? '-';

            final text = review['text']?.toString() ?? '';

            return Container(
              padding: const EdgeInsets.all(14),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(14),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text('Rating $rating', style: AppTheme.caption()),

                  if (text.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),

                    Text(text, style: AppTheme.body()),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =====================================================
  // GALLERY
  // =====================================================

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

  // =====================================================
  // CONTACT BUTTON
  // =====================================================

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
