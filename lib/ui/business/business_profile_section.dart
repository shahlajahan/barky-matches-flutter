import 'package:flutter/material.dart';
import '../admin/admin_section.dart';

class BusinessProfileSection extends StatelessWidget {
  final Map<String, dynamic> data;

  const BusinessProfileSection({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final profile =
        (data['profile'] as Map?)?.cast<String, dynamic>() ?? {};

    final logoUrl = profile['logoUrl'];
    final coverUrl = profile['coverUrl'];
    final displayName = profile['displayName'] ?? "Unnamed Business";
    final description = profile['description'] ?? "";

    return AdminSection(
      title: "Profile",
      icon: Icons.business_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// 🔷 COVER IMAGE
          if (coverUrl != null && coverUrl.toString().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                coverUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          if (coverUrl != null && coverUrl.toString().isNotEmpty)
            const SizedBox(height: 12),

          /// 🔷 LOGO + NAME
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (logoUrl != null && logoUrl.toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    logoUrl,
                    height: 60,
                    width: 60,
                    fit: BoxFit.cover,
                  ),
                ),

              if (logoUrl != null && logoUrl.toString().isNotEmpty)
                const SizedBox(width: 12),

              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          if (description.toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }
}