import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/patients/vet_patient_detail_page.dart';

class MedicalRecordsPage extends StatelessWidget {
  const MedicalRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF6F8),

      appBar: AppBar(
        title: const Text('Medical Records'),
        backgroundColor: const Color(0xFFEC0B6A),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('dogs')
            .where('ownerId', isEqualTo: userId)
            .snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No pets found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),

            itemCount: docs.length,

            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final age = (data['age'] as num?)?.toInt() ?? 0;
              final reportCount = (data['reportCount'] as num?)?.toInt() ?? 0;
              final boostScore = (data['boostScore'] as num?)?.toInt() ?? 0;
              final latitude = (data['latitude'] as num?)?.toDouble();
              final longitude = (data['longitude'] as num?)?.toDouble();

              debugPrint(
                'FIELD TYPE: age=${data['age']?.runtimeType} '
                'reportCount=${data['reportCount']?.runtimeType} '
                'boostScore=${data['boostScore']?.runtimeType} '
                'latitude=${data['latitude']?.runtimeType} '
                'longitude=${data['longitude']?.runtimeType}',
              );
              debugPrint(
                'FIELD VALUE: age=${data['age']} '
                'reportCount=${data['reportCount']} '
                'boostScore=${data['boostScore']} '
                'latitude=${data['latitude']} '
                'longitude=${data['longitude']}',
              );

              final dog = Dog(
                id: docs[index].id,

                name: data['name'] ?? '',

                breed: data['breed'] ?? '',

                age: age,

                gender: data['gender'] ?? '',

                healthStatus: data['healthStatus'] ?? 'healthy',

                isNeutered: data['isNeutered'] ?? false,

                traits: List<String>.from(data['traits'] ?? []),

                imagePaths: List<String>.from(data['imagePaths'] ?? []),

                isAvailableForAdoption: data['isAvailableForAdoption'] ?? false,

                isOwner: data['isOwner'] ?? false,

                ownerId: data['ownerId'],

                description: data['description'],

                ownerGender: data['ownerGender'],

                latitude: latitude,

                longitude: longitude,

                reportCount: reportCount,

                isHidden: data['isHidden'] ?? false,

                moderationStatus: data['moderationStatus'] ?? 'active',

                ownerProfileVisible: data['ownerProfileVisible'] ?? true,

                dogProfileVisible: data['dogProfileVisible'] ?? true,

                isPremium: data['isPremium'] ?? false,

                isSponsored: data['isSponsored'] ?? false,

                boostScore: boostScore,

                sponsorshipType: data['sponsorshipType'] ?? '',

                petType: data['petType'] ?? 'dog',
              );

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (_) => VetPatientDetailPage(
                        businessId: 'owner_medical_record',

                        patientId: docs[index].id,

                        patientData: data,
                      ),
                    ),
                  );
                },

                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),

                  padding: const EdgeInsets.all(18),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius: BorderRadius.circular(22),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),

                        blurRadius: 12,

                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),

                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,

                        backgroundImage: dog.imagePaths.isNotEmpty
                            ? NetworkImage(dog.imagePaths.first)
                            : null,
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              dog.name,

                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              dog.breed,

                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),

                      const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
