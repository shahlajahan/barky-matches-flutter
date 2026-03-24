import 'package:flutter/material.dart';
import '../admin/admin_section.dart';

class BusinessContactSection extends StatelessWidget {
  final Map<String, dynamic> data;

  const BusinessContactSection({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final contact =
        (data['contact'] as Map?)?.cast<String, dynamic>() ?? {};

    final phone = contact['phone'];
    final whatsapp = contact['whatsapp'];
    final email = contact['email'];
    final instagram = contact['instagram'];
    final website = contact['website'];
    final city = contact['city'];
    final district = contact['district'];
    final address = contact['addressLine'];

    return AdminSection(
      title: "Contact Information",
      icon: Icons.contact_phone_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          _InfoRow(icon: Icons.phone, label: "Phone", value: phone),
          _InfoRow(icon: Icons.chat, label: "WhatsApp", value: whatsapp),
          _InfoRow(icon: Icons.email_outlined, label: "Email", value: email),
          _InfoRow(icon: Icons.camera_alt_outlined, label: "Instagram", value: instagram),
          _InfoRow(icon: Icons.language, label: "Website", value: website),

          const SizedBox(height: 16),

          const Divider(),

          const SizedBox(height: 12),

          _InfoRow(
            icon: Icons.location_on_outlined,
            label: "Location",
            value: [
              district,
              city,
            ]
                .where((e) => e != null && e.toString().isNotEmpty)
                .join(", "),
          ),

          _InfoRow(
            icon: Icons.home_outlined,
            label: "Address",
            value: address,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}