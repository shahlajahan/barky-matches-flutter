import 'package:flutter/material.dart';

class AdminRiskBadge extends StatelessWidget {
  final List<String>? riskFlags;
  final bool compact;

  const AdminRiskBadge({
    super.key,
    required this.riskFlags,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final count = riskFlags?.length ?? 0;

    if (count == 0) return const SizedBox.shrink();

    final config = _getRiskConfig(count);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: compact ? 14 : 16,
            color: config.textColor,
          ),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w600,
              color: config.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _RiskConfig _getRiskConfig(int count) {
    if (count == 1) {
      return _RiskConfig(
        label: "1 Risk",
        backgroundColor: const Color(0xFFFFF8E1),
        textColor: const Color(0xFFFF8F00),
      );
    }

    if (count <= 3) {
      return _RiskConfig(
        label: "$count Risks",
        backgroundColor: const Color(0xFFFFF3E0),
        textColor: const Color(0xFFEF6C00),
      );
    }

    return _RiskConfig(
      label: "$count Risks",
      backgroundColor: const Color(0xFFFFEBEE),
      textColor: const Color(0xFFC62828),
    );
  }
}

class _RiskConfig {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  _RiskConfig({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });
}