import 'package:flutter/material.dart';

class AdminStatusBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const AdminStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final config = _getStatusConfig(normalized);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: compact ? 11 : 13,
          fontWeight: FontWeight.w600,
          color: config.textColor,
        ),
      ),
    );
  }

  _StatusConfig _getStatusConfig(String status) {
    switch (status) {
      case "pending":
        return _StatusConfig(
          label: "Pending",
          backgroundColor: const Color(0xFFFFF3E0),
          textColor: const Color(0xFFEF6C00),
        );

      case "approved":
        return _StatusConfig(
          label: "Approved",
          backgroundColor: const Color(0xFFE8F5E9),
          textColor: const Color(0xFF2E7D32),
        );

      case "rejected":
        return _StatusConfig(
          label: "Rejected",
          backgroundColor: const Color(0xFFFFEBEE),
          textColor: const Color(0xFFC62828),
        );

      case "suspended":
        return _StatusConfig(
          label: "Suspended",
          backgroundColor: const Color(0xFFE0E0E0),
          textColor: const Color(0xFF424242),
        );

      case "active":
        return _StatusConfig(
          label: "Active",
          backgroundColor: const Color(0xFFE3F2FD),
          textColor: const Color(0xFF1565C0),
        );

      case "expired":
        return _StatusConfig(
          label: "Expired",
          backgroundColor: const Color(0xFFFFEBEE),
          textColor: const Color(0xFFD32F2F),
        );

      case "draft":
        return _StatusConfig(
          label: "Draft",
          backgroundColor: const Color(0xFFF3E5F5),
          textColor: const Color(0xFF6A1B9A),
        );

      default:
        return _StatusConfig(
          label: status,
          backgroundColor: const Color(0xFFE0E0E0),
          textColor: const Color(0xFF424242),
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  _StatusConfig({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });
}