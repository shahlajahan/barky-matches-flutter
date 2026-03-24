import 'package:flutter/material.dart';
import '../admin/admin_section.dart';

class BusinessLegalSection extends StatelessWidget {
  final Map<String, dynamic> data;

  const BusinessLegalSection({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final legal =
        (data['legal'] as Map?)?.cast<String, dynamic>() ?? {};
    final trust =
        (data['trust'] as Map?)?.cast<String, dynamic>() ?? {};
    final verification =
        (data['verification'] as Map?)?.cast<String, dynamic>() ?? {};

    final submittedTax = legal['taxNumber']?.toString();
    final submittedMersis = legal['mersisNumber']?.toString();

    final ocrData =
        (verification['ocr'] as Map?)?.cast<String, dynamic>() ?? {};

    final extractedTax = ocrData['extractedTaxNumber']?.toString();
    final extractedMersis = ocrData['extractedMersisNumber']?.toString();

    final riskFlags =
        (trust['riskFlags'] as List?)?.cast<String>() ?? [];

    return AdminSection(
      title: "Legal Information",
      icon: Icons.gavel_outlined,
      accentColor: riskFlags.isNotEmpty
          ? Colors.orange
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// 🔷 TAX NUMBER
          _ComparisonRow(
            label: "Tax Number",
            submitted: submittedTax,
            extracted: extractedTax,
          ),

          const SizedBox(height: 14),

          /// 🔷 MERSIS
          _ComparisonRow(
            label: "MERSIS Number",
            submitted: submittedMersis,
            extracted: extractedMersis,
          ),

          const SizedBox(height: 16),

          if (legal['disclaimerAcceptedAt'] != null)
            Row(
              children: const [
                Icon(Icons.check_circle, size: 16, color: Colors.green),
                SizedBox(width: 6),
                Text(
                  "Disclaimer accepted",
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String? submitted;
  final String? extracted;

  const _ComparisonRow({
    required this.label,
    required this.submitted,
    required this.extracted,
  });

  @override
  Widget build(BuildContext context) {
    final isMatch =
        submitted != null &&
        extracted != null &&
        submitted == extracted;

    final hasMismatch =
        submitted != null &&
        extracted != null &&
        submitted != extracted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),

        const SizedBox(height: 6),

        Row(
          children: [

            /// Submitted
            Expanded(
              child: _ValueBox(
                title: "Submitted",
                value: submitted,
                color: Colors.blueGrey.shade50,
              ),
            ),

            const SizedBox(width: 10),

            /// Extracted
            Expanded(
              child: _ValueBox(
                title: "OCR",
                value: extracted,
                color: isMatch
                    ? Colors.green.shade50
                    : hasMismatch
                        ? Colors.red.shade50
                        : Colors.grey.shade100,
              ),
            ),
          ],
        ),

        if (hasMismatch) ...[
          const SizedBox(height: 6),
          const Text(
            "⚠ Mismatch detected",
            style: TextStyle(
              fontSize: 12,
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _ValueBox extends StatelessWidget {
  final String title;
  final String? value;
  final Color color;

  const _ValueBox({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value ?? "—",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}