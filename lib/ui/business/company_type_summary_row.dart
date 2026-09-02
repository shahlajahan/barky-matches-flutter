import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// The company-type summary row shown on the registration agreement step.
///
/// Extracted from `business_register_page.dart` so the exact production
/// widget can be laid out under test at real device widths, locales and
/// text scales — the previous inline `Row` could only be exercised by
/// mounting the entire multi-step registration page.
///
/// Layout contract: the value text is unbounded in length. The localized
/// limited-company labels are long in every locale (the English variant
/// carries a parenthetical gloss, and the Russian variant is longer still),
/// and they grow further with a larger text scale. The original row placed
/// a `Spacer()` before a bare `Text`, leaving the value with no width
/// constraint at all, so at ordinary iPhone widths it overflowed to the
/// right ("RIGHT OVERFLOWED BY ...") and ran past the card edge.
///
/// Both text children are constrained and allowed to wrap instead: the
/// label may shrink via [Flexible], and the value takes the remaining
/// width via [Expanded], wrapping onto further lines rather than
/// overflowing. No font size is reduced, so text scaling and accessibility
/// are preserved, and `Row` with `TextAlign.end` remains
/// direction-aware for Persian RTL.
class CompanyTypeSummaryRow extends StatelessWidget {
  const CompanyTypeSummaryRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.building2, size: 18, color: Color(0xFF9E1B4F)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
