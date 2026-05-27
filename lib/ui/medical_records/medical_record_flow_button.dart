import 'package:flutter/material.dart';

class MedicalRecordFlowButton extends StatelessWidget {
  final VoidCallback onTap;

  const MedicalRecordFlowButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(22),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),

        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F6),
                borderRadius: BorderRadius.circular(16),
              ),

              child: const Icon(
                Icons.medical_services_rounded,
                color: Color(0xFF9E1B4F),
              ),
            ),

            const SizedBox(width: 14),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'Medical Records',

                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),

                  SizedBox(height: 4),

                  Text(
                    'Vaccines, visits and treatments',

                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),

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
}
