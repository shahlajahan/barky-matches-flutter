import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class AdoptionPetsTab extends StatelessWidget {
  final String businessId;

  const AdoptionPetsTab({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('adoption_pets')
          .orderBy('createdAt', descending: true)
          .snapshots(),

      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _EmptyState(businessId: businessId);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),

          itemCount: docs.length,

          itemBuilder: (context, index) {
            final doc = docs[index];

            final data = doc.data() as Map<String, dynamic>;

            final name = data['name'] ?? 'Unnamed Pet';

            final breed = data['breed'] ?? '-';

            final age = data['age'] ?? '-';

            final gender = data['gender'] ?? '-';

            final vaccinated = data['vaccinated'] == true;

            final sterilized = data['sterilized'] == true;

            final isActive = data['isActive'] != false;

            final imageUrl = data['imageUrl'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(18),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),

                    blurRadius: 12,

                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: Padding(
                padding: const EdgeInsets.all(14),

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    /// ================= IMAGE =================
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),

                      child: imageUrl.isEmpty
                          ? Container(
                              width: 92,
                              height: 92,

                              color: Colors.grey.shade200,

                              child: const Icon(LucideIcons.dog, size: 34),
                            )
                          : Image.network(
                              imageUrl,

                              width: 92,
                              height: 92,

                              fit: BoxFit.cover,
                            ),
                    ),

                    const SizedBox(width: 14),

                    /// ================= INFO =================
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,

                                  style: AppTheme.bodyMedium().copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),

                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.green.withOpacity(0.12)
                                      : Colors.red.withOpacity(0.12),

                                  borderRadius: BorderRadius.circular(999),
                                ),

                                child: Text(
                                  isActive ? 'ACTIVE' : 'INACTIVE',

                                  style: TextStyle(
                                    color: isActive ? Colors.green : Colors.red,

                                    fontWeight: FontWeight.w700,

                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          Text("Breed: $breed", style: AppTheme.caption()),

                          const SizedBox(height: 4),

                          Text("Age: $age", style: AppTheme.caption()),

                          const SizedBox(height: 4),

                          Text("Gender: $gender", style: AppTheme.caption()),

                          const SizedBox(height: 10),

                          Wrap(
                            spacing: 8,

                            runSpacing: 8,

                            children: [
                              _Tag(
                                text: vaccinated
                                    ? 'Vaccinated'
                                    : 'Not Vaccinated',
                                active: vaccinated,
                              ),

                              _Tag(
                                text: sterilized
                                    ? 'Sterilized'
                                    : 'Not Sterilized',
                                active: sterilized,
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    debugPrint("✏️ EDIT PET → ${doc.id}");
                                  },

                                  icon: const Icon(LucideIcons.edit3),

                                  label: const Text('Edit'),
                                ),
                              ),

                              const SizedBox(width: 10),

                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isActive
                                        ? Colors.red
                                        : Colors.green,
                                  ),

                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('businesses')
                                        .doc(businessId)
                                        .collection('adoption_pets')
                                        .doc(doc.id)
                                        .set({
                                          'isActive': !isActive,

                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        }, SetOptions(merge: true));
                                  },

                                  icon: Icon(
                                    isActive
                                        ? LucideIcons.eyeOff
                                        : LucideIcons.eye,
                                  ),

                                  label: Text(
                                    isActive ? 'Deactivate' : 'Activate',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  final bool active;

  const _Tag({required this.text, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

      decoration: BoxDecoration(
        color: active
            ? Colors.green.withOpacity(0.12)
            : Colors.grey.withOpacity(0.12),

        borderRadius: BorderRadius.circular(999),
      ),

      child: Text(
        text,

        style: TextStyle(
          color: active ? Colors.green : Colors.grey,

          fontSize: 11,

          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String businessId;

  const _EmptyState({required this.businessId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Container(
              width: 92,
              height: 92,

              decoration: BoxDecoration(
                color: const Color(0xFF9E1B4F).withOpacity(0.08),

                shape: BoxShape.circle,
              ),

              child: const Icon(
                LucideIcons.dog,

                size: 42,

                color: Color(0xFF9E1B4F),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'No Adoption Pets Yet',

              style: AppTheme.h2(weight: FontWeight.w700),
            ),

            const SizedBox(height: 8),

            Text(
              'Add pets that are available for adoption.',

              textAlign: TextAlign.center,

              style: AppTheme.body(color: AppTheme.muted),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () {
                debugPrint("➕ ADD ADOPTION PET");
              },

              icon: const Icon(LucideIcons.plus),

              label: const Text('Add Pet'),
            ),
          ],
        ),
      ),
    );
  }
}
