import 'package:flutter/material.dart';
import '../admin/admin_status_badge.dart';
import '../admin/admin_risk_badge.dart';

class BusinessHeader extends StatelessWidget {
  final Map<String, dynamic> data;

  const BusinessHeader({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final profile =
        (data['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final contact =
        (data['contact'] as Map?)?.cast<String, dynamic>() ?? {};
    final trust =
        (data['trust'] as Map?)?.cast<String, dynamic>() ?? {};
    final verification =
        (data['verification'] as Map?)?.cast<String, dynamic>() ?? {};

    final displayName = profile['displayName'] ?? "Unnamed Business";
    final type = data['type'] ?? "";
    final status = data['status'] ?? "pending";

    final city = contact['city'] ?? "";
    final district = contact['district'] ?? "";

    final riskFlags =
        (trust['riskFlags'] as List?)?.cast<String>() ?? [];

    final isVerified = verification['isVerified'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// 🔷 TITLE ROW
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 8),

            _BusinessTypeBadge(type: type),
          ],
        ),

        const SizedBox(height: 12),

        /// 🔷 STATUS ROW
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            AdminStatusBadge(status: status),

            _VerificationBadge(isVerified: isVerified),

            AdminRiskBadge(riskFlags: riskFlags),
          ],
        ),

        const SizedBox(height: 14),

        /// 🔷 META ROW
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 16),
            const SizedBox(width: 4),
            Text(
              [district, city]
                  .where((e) => e.toString().isNotEmpty)
                  .join(", "),
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BusinessTypeBadge extends StatelessWidget {
  final String type;

  const _BusinessTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1565C0),
        ),
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final bool isVerified;

  const _VerificationBadge({required this.isVerified});

  @override
  Widget build(BuildContext context) {
    if (!isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E5F5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Text(
          "Basic",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6A1B9A),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Text(
        "Verified",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2E7D32),
        ),
      ),
    );
  }
}