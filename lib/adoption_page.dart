import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dog.dart';
import 'dog_card.dart';
import 'app_state.dart';
import 'theme/app_theme.dart';
import 'models/adoption_center.dart';

import 'ui/business/business_card_data.dart';
import 'ui/business/business_card.dart';
import 'ui/business/business_detail_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:barky_matches_fixed/ui/adoption/adoption_request_sheet.dart';
import 'package:barky_matches_fixed/core/firestore_paths.dart';

enum AdoptionViewType { centers, dogs }

class AdoptionPage extends StatefulWidget {
  final List<Dog>? dogs;
  final List<Dog>? favoriteDogs;
  final Function(Dog)? onToggleFavorite;
  

  const AdoptionPage({
    super.key,
    this.dogs,
    this.favoriteDogs,
    this.onToggleFavorite,
  });

  @override
  State<AdoptionPage> createState() => _AdoptionPageState();
}
class _AdoptionPageState extends State<AdoptionPage> {
  late String _currentUserId;
  AdoptionViewType _selectedView = AdoptionViewType.centers;
  List<Dog> _adoptionDogs = [];
  String? _adoptionOwnerId;
bool _loading = true;
bool _isFirstLoad = true;
  @override
void initState() {
  super.initState();

  Future.microtask(() async {
  _loadCurrentUserId();

  await Future.delayed(const Duration(milliseconds: 500));

  if (!mounted) return;

  setState(() {
    _loading = false;
    _isFirstLoad = false;
  });
});
}
  void _loadCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    _currentUserId = user?.uid ?? 'default_user';
  }

  // ================================
  // 🔘 Toggle
  // ================================

  Widget _buildToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildToggleItem(
            label: "Adoption Centers",
            isSelected: _selectedView == AdoptionViewType.centers,
            onTap: () {
              setState(() {
                _selectedView = AdoptionViewType.centers;
              });
            },
          ),
          _buildToggleItem(
            label: "Dogs",
            isSelected: _selectedView == AdoptionViewType.dogs,
            onTap: () {
              setState(() {
                _selectedView = AdoptionViewType.dogs;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.pink : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================================
  // 🏢 Centers Section (placeholder)
  // ================================

  Widget _buildCentersSection() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('businesses')
        .where('type', isEqualTo: 'adoption_center')
        .where('status', isEqualTo: 'approved')
        .orderBy('updatedAt', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const Center(
          child: Text("No adoption centers available"),
        );
      }

      final appState = context.read<AppState>();

      final businesses = snapshot.data!.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        final profile = (data['profile'] as Map?)?.cast<String, dynamic>() ?? {};
        final contact = (data['contact'] as Map?)?.cast<String, dynamic>() ?? {};
        final verification =
    (data['verification'] as Map?)?.cast<String, dynamic>() ?? {};

final status = (data['status'] ?? 'approved') as String;

final isVerified = verification['isVerified'] == true;

        return BusinessCardData(
  id: doc.id,
  name: (profile['displayName'] ?? '') as String,
  city: (contact['city'] ?? '') as String,
  district: (contact['district'] ?? '') as String,
  address: '${contact['district'] ?? ''}, ${contact['city'] ?? ''}',
  specialties: const [],
  description: profile['description'] as String?,

  phone: contact['phone'] as String?,
  whatsapp: contact['whatsapp'] as String?,

  services: null,
  rating: (profile['rating'] as num?)?.toDouble(),
  reviewsCount: (profile['reviewCount'] as num?)?.toInt(),
  workingHours: null,
  distanceKm: null,

  isPartner: false,
  isVerified: isVerified,
status: status,
  isEmergency: false,
  type: BusinessType.adoptionCenter,
);
      }).toList();

      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: businesses.length,
        itemBuilder: (context, index) {
          final business = businesses[index];

          return BusinessCard(
            data: business,
            onTap: () => appState.openBusinessDetails(business),
            onCallTap: business.phone != null
                ? () async {
                    final phone = business.phone!.replaceAll(RegExp(r'[^0-9+]'), '');
                    final uri = Uri(scheme: 'tel', path: phone);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  }
                : null,
            onWhatsAppTap: business.whatsapp != null
                ? () async {
                    String normalizeTR(String raw) {
                      var p = raw.replaceAll(RegExp(r'[^0-9]'), '');
                      if (p.startsWith('0')) p = p.substring(1);
                      if (p.startsWith('90')) return p;
                      return '90$p';
                    }

                    final phone = normalizeTR(business.whatsapp!);
                    final uri = Uri.parse('https://wa.me/$phone');

                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                : null,
            onDirectionsTap: () async {
              final query = Uri.encodeComponent('${business.district ?? ''}, ${business.city ?? ''}');
              final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          );
        },
      );
    },
  );
}

  // ================================
  // 🐶 Dogs Section (Firestore Stream)
  // ================================

  Widget _buildDogsSection() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('dogs')
        .where('isAvailableForAdoption', isEqualTo: true)
        .where('isHidden', isEqualTo: false)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const Center(
          child: Text("No dogs available for adoption"),
        );
      }

      final appState = context.read<AppState>();
      final currentUserId = appState.currentUserId ?? '';

      final dogs = snapshot.data!.docs
          .map((doc) => Dog.fromFirestore(doc))
          .where((dog) => dog.ownerId != currentUserId)
          .toList();

      _adoptionDogs = dogs;

      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: dogs.length,
        itemBuilder: (context, index) {
          final dog = dogs[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DogCard(
  dog: dog,
  mode: DogCardMode.compact,
  allDogs: dogs,
  currentUserId: currentUserId,
  favoriteDogs: appState.favoriteDogs,
  onToggleFavorite: appState.toggleFavorite,
  likers: appState.dogLikes[dog.id] ?? [],
  enableChat: false,
  enableEdit: false,
  enablePlaydate: false,

  onCardTap: () {
    context.read<AppState>().openAdoptionDogOverlay(dog.id);
  },
),
          );
        },
      );
    },
  );
}

void _openDogPreview(BuildContext context, Dog dog) {
  final appState = context.read<AppState>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF9E1B4F),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: DogCard(
              dog: dog,
              mode: DogCardMode.adoption,   // 👈 این مهمه
              allDogs: _adoptionDogs,
              currentUserId: appState.currentUserId ?? '',
              favoriteDogs: appState.favoriteDogs,
              onToggleFavorite: appState.toggleFavorite,
              likers: appState.dogLikes[dog.id] ?? [],
              enableChat: false,
              enableEdit: false,
              enablePlaydate: false,
              onAdopt: () {
                Navigator.pop(context);

                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (_) => AdoptionRequestSheet(
                    targetType: "dog",
                    targetId: dog.id,
                    targetOwnerId: dog.ownerId ?? '',
                    dogName: dog.name,
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

  Future<void> _seedCentersIfEmpty() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('adoption_centers')
      .limit(1)
      .get();

  if (snapshot.docs.isNotEmpty) return;

  final centers = [
  {
    "name": "Kurtaran Ev",
    "description": "Büyük yaşam alanı, yüz yüze görüşme şart.",
    "city": "Istanbul",
    "district": "Hadımköy",
    "instagram": "kurtaranev",
    "website": "https://kurtaranev.org",
    "phone": "5466577827",        // ✅ اضافه شد
    "whatsapp": "5466577827",     // ✅ اضافه شد
    "isFeatured": true,
    "centerType": "ngo",
  },
  {
    "name": "SemtPati Vakfı",
    "description": "Barınaklardan sahiplendirme.",
    "city": "Istanbul",
    "district": "Kadıköy",        // بهتره district هم داشته باشه
    "instagram": "semtpati",
    "website": "https://semtpati.org",
    "phone": "5466577827",        // ✅ اضافه شد
    "whatsapp": "5466577827",     // ✅ اضافه شد
    "isFeatured": true,
    "centerType": "ngo",
  },
  {
    "name": "hayvansahiplendirme2025",
    "instagram": "hayvansahiplendirme2025",
    "whatsapp": "05326596173",
    "phone": "05326596173",       // ✅ اینم کامل کن
    "isFeatured": false,
    "centerType": "instagram",
  },
];

  for (var center in centers) {
    await FirebaseFirestore.instance
        .collection('adoption_centers')
        .add(center);
  }
}

  // ================================
  // 🏗 Build
  // ================================

  @override
Widget build(BuildContext context) {
  final appState = context.watch<AppState>();
  if (_loading || _isFirstLoad) {
  return _buildSkeleton();
}

  // 🐶 DOG OVERLAY (جدید)
  if (appState.adoptionDogOverlayId != null) {
    final dog = _adoptionDogs.firstWhere(
      (d) => d.id == appState.adoptionDogOverlayId,
    );

    return _AdoptionDogOverlay(
      dog: dog,
    );
  }

  // 👤 OWNER OVERLAY (فعلی تو)
  if (_adoptionOwnerId != null) {
    return _AdoptionOwnerOverlay(
      ownerId: _adoptionOwnerId!,
      onClose: () {
        setState(() {
          _adoptionOwnerId = null;
        });
      },
    );
  }

  if (appState.centerDogsId != null) {
    return _CenterDogsSubPage(
      centerId: appState.centerDogsId!,
    );
  }

  // 🧱 MAIN PAGE
  return SafeArea(
    top: false,
    child: Stack(
      children: [
        Container(
          color: AppTheme.bg,
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildToggle(),
              Expanded(
                child: _selectedView == AdoptionViewType.centers
                    ? _buildCentersSection()
                    : _buildDogsSection(),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
Widget _buildSkeleton() {
  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 4,
    itemBuilder: (_, __) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [

            // image placeholder
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            const SizedBox(width: 12),

            // text placeholder
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Container(
                    height: 14,
                    width: 120,
                    color: Colors.grey.shade300,
                  ),

                  const SizedBox(height: 8),

                  Container(
                    height: 12,
                    width: 80,
                    color: Colors.grey.shade300,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
}

class _AdoptionOwnerOverlay extends StatelessWidget {
  final String ownerId;
  final VoidCallback onClose;

  const _AdoptionOwnerOverlay({
    required this.ownerId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dogs')
          .where('isAvailableForAdoption', isEqualTo: true)
          .where('ownerId', isEqualTo: ownerId)
          .snapshots(),
      builder: (context, snapshot) {
        final dogs = snapshot.data?.docs
                .map((doc) => Dog.fromFirestore(doc))
                .toList() ??
            [];

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onClose,
                child: Container(color: Colors.black54),
              ),
            ),
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
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white),
                            onPressed: onClose,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Available for Adoption",
                            style: AppTheme.h2(
                                color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...dogs.map(
  (dog) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      children: [
        DogCard(
          dog: dog,
          mode: DogCardMode.compact,
          allDogs: dogs,
          currentUserId: appState.currentUserId ?? '',
          favoriteDogs: appState.favoriteDogs,
          onToggleFavorite: appState.toggleFavorite,
          likers: appState.dogLikes[dog.id] ?? [],
          enableEdit: false,
          enablePlaydate: false,
          enableChat: false,
        ),

        const SizedBox(height: 8),

        /// ✅ CTA رسمی
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AdoptionRequestSheet(
                  targetType: "dog",
                  targetId: dog.id,
                  targetOwnerId: dog.ownerId ?? '',
                  dogName: dog.name,
                ),
              );
            },
            child: const Text("Send Adoption Request"),
          ),
        ),
      ],
    ),
  ),
),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openAdoptionRequestSheet(BuildContext context, Dog dog) {
  final messageController = TextEditingController();
  final phoneController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Adoption Request",
              style: AppTheme.h2(),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: "Your Phone",
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Why do you want to adopt?",
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final user =
                      FirebaseAuth.instance.currentUser;

                  if (user == null) return;

                  await FirebaseFirestore.instance
                      .collection('adoption_requests')
                      .add({
                    "dogId": dog.id,
                    "dogName": dog.name,
                    "ownerId": dog.ownerId,
                    "requesterId": user.uid,
                    "requesterPhone":
                        phoneController.text.trim(),
                    "message":
                        messageController.text.trim(),
                    "status": "pending",
                    "createdAt":
                        FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content:
                          Text("Request sent successfully"),
                    ),
                  );
                },
                child: const Text("Send Request"),
              ),
            ),
          ],
        ),
      );
    },
  );
}
}

class _AdoptionDogOverlay extends StatelessWidget {
  final Dog dog;

  const _AdoptionDogOverlay({
    required this.dog,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Stack(
      children: [
        // ⛔️ Dim background
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              context.read<AppState>().closeAdoptionDogOverlay();
            },
            child: Container(
              color: Colors.black54,
            ),
          ),
        ),

        // 🐶 Center Card
        Center(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF9E1B4F), // 🔥 دقیقاً مثل Playmate
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // 🔹 Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          context.read<AppState>().closeAdoptionDogOverlay();
                        },
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Available for Adoption",
                        style: AppTheme.h2(color: Colors.white),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 🐶 Dog Card (همان style playdate)
                  DogCard(
                    dog: dog,
                    mode: DogCardMode.playdate,
                    allDogs: const [],
                    currentUserId: appState.currentUserId ?? '',
                    favoriteDogs: appState.favoriteDogs,
                    onToggleFavorite: (d) =>
                        appState.toggleFavorite(d),
                    likers: appState.dogLikes[dog.id] ?? [],
                    enableEdit: false,
                  ),

                  const SizedBox(height: 20),

                  // 🟡 CTA
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        // اینجا Professional 4-step request باز می‌شود
                        context.read<AppState>()
                            .closeAdoptionDogOverlay();

                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          builder: (_) => AdoptionRequestSheet(
                            targetType: "dog",
                            targetId: dog.id,
                            targetOwnerId:
                                dog.ownerId ?? '',
                            dogName: dog.name,
                          ),
                        );
                      },
                      child: const Text(
                        "Send Adoption Request",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CenterDogsSubPage extends StatelessWidget {
  final String centerId;

  const _CenterDogsSubPage({
    required this.centerId,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 16),

          // 🔙 Header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  context.read<AppState>().closeCenterDogs();
                },
              ),
              const Text(
                'Available Dogs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('dogs')
                  .where('isAvailableForAdoption', isEqualTo: true)
                  .where('centerId', isEqualTo: centerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final dogs = snapshot.data!.docs
                    .map((doc) => Dog.fromFirestore(doc))
                    .toList();

                if (dogs.isEmpty) {
                  return const Center(
                    child: Text('No dogs available in this center'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dogs.length,
                  itemBuilder: (context, index) {
                    final dog = dogs[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DogCard(
                        dog: dog,
                        mode: DogCardMode.compact,
                        allDogs: dogs,
                        currentUserId: appState.currentUserId ?? '',
                        favoriteDogs: appState.favoriteDogs,
                        onToggleFavorite: appState.toggleFavorite,
                        likers: appState.dogLikes[dog.id] ?? [],
                        enableChat: false,
                        enableEdit: false,
                        enablePlaydate: false,
                        onCardTap: () {
                          context.read<AppState>()
                              .openAdoptionDogOverlay(dog.id);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}