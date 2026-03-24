import 'package:flutter/material.dart';
import '../models/moderation_case.dart';

class ModerationCaseCard extends StatelessWidget {
  final ModerationCase c;
  final VoidCallback onTap;

  const ModerationCaseCard({
    super.key,
    required this.c,
    required this.onTap,
  });

  Color _riskColor() {
    if (c.riskScore >= 25) return Colors.red;
    if (c.riskScore >= 15) return Colors.orange;
    if (c.riskScore >= 10) return Colors.amber;
    return Colors.green;
  }

  IconData _icon() {
    switch (c.type) {
      case "dog":
        return Icons.pets;
      case "business":
        return Icons.store;
      case "user":
        return Icons.person;
      case "chat":
        return Icons.chat;
      default:
        return Icons.flag;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: ListTile(
        leading: Icon(
          _icon(),
          color: _riskColor(),
        ),
        title: Text("${c.type} • ${c.targetId}"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Reports: ${c.reportCount}"),
            Text("Risk Score: ${c.riskScore}"),
            if (c.summary != null) Text(c.summary!),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}