import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/dog.dart';

class MedicalRecordPetCard extends StatelessWidget {
  final Dog dog;

  final int vaccineCount;

  final VoidCallback onTap;

  const MedicalRecordPetCard({
    super.key,
    required this.dog,
    required this.vaccineCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        margin: const EdgeInsets.only(bottom: 16),

        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(22),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),

              blurRadius: 12,

              offset: const Offset(0, 6),
            ),
          ],
        ),

        child: Row(
          children: [
            CircleAvatar(
              radius: 32,

              backgroundColor: const Color(0xFFFFF1F6),

              backgroundImage: dog.imagePaths.isNotEmpty
                  ? NetworkImage(dog.imagePaths.first)
                  : null,

              child: dog.imagePaths.isEmpty
                  ? const Icon(Icons.pets_rounded, color: Color(0xFF9E1B4F))
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

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,

                    children: [
                      _chip('${dog.age}y'),

                      _chip(dog.gender),

                      _chip(
                        '$vaccineCount vaccines',
                        icon: Icons.vaccines_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Colors.black45,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F6),

        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: const Color(0xFF9E1B4F)),

            const SizedBox(width: 4),
          ],

          Text(
            text,

            style: const TextStyle(
              color: Color(0xFF9E1B4F),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
