import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../admin/admin_section.dart';

class BusinessTrustSection extends StatefulWidget {
  final Map<String, dynamic> data;
  final String businessId;

  const BusinessTrustSection({
    super.key,
    required this.data,
    required this.businessId,
  });

  @override
  State<BusinessTrustSection> createState() =>
      _BusinessTrustSectionState();
}

class _BusinessTrustSectionState
    extends State<BusinessTrustSection> {

  late final TextEditingController _notesController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final trust =
        (widget.data['trust'] as Map?)?.cast<String, dynamic>() ?? {};

    _notesController = TextEditingController(
      text: trust['moderationNotes'] ?? "",
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trust =
        (widget.data['trust'] as Map?)?.cast<String, dynamic>() ?? {};

    final riskFlags =
        (trust['riskFlags'] as List?)?.cast<String>() ?? [];

    final reportCount = trust['reportCount'] ?? 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AdminSection(
        title: "Trust & Risk",
        icon: Icons.security_outlined,
        accentColor:
            riskFlags.isNotEmpty ? Colors.red : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 🔷 REPORT COUNT
            _MetricRow(
              label: "Reports",
              value: reportCount.toString(),
            ),

            const SizedBox(height: 12),

            /// 🔷 RISK FLAGS
            if (riskFlags.isNotEmpty) ...[
              const Text(
                "Risk Flags",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...riskFlags.map(
                (flag) => _RiskFlagTile(flag: flag),
              ),
            ] else
              const Text(
                "No risk flags",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),

            const SizedBox(height: 18),

            /// 🔷 MODERATION NOTES
            const Text(
              "Admin Notes",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Add internal moderation notes...",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: _isSaving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : TextButton(
                      onPressed: _saveNotes,
                      child: const Text("Save Notes"),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNotes() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    FocusScope.of(context).unfocus();

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('updateBusinessAdminNotes');

      await callable.call({
        "businessId": widget.businessId,
        "notes": _notesController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Admin notes saved ✅"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save failed: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _RiskFlagTile extends StatelessWidget {
  final String flag;

  const _RiskFlagTile({required this.flag});

  @override
  Widget build(BuildContext context) {
    final readable =
        flag.replaceAll("_", " ").toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Colors.red,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              readable,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}