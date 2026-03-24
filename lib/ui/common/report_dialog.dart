import 'package:flutter/material.dart';
import '../../services/report_service.dart';

class ReportDialog extends StatefulWidget {
  final String type;
  final String targetId;

  const ReportDialog({
    super.key,
    required this.type,
    required this.targetId,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String _reason = "spam";
  final TextEditingController _messageController = TextEditingController();
  bool _loading = false;

  final reasons = [
    "spam",
    "scam",
    "abuse",
    "fake",
    "other",
  ];

  Future<void> _submit() async {
    setState(() {
      _loading = true;
    });

    await ReportService.submitReport(
      type: widget.type,
      targetId: widget.targetId,
      reason: _reason,
      message: _messageController.text,
    );

    if (mounted) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report submitted")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Report"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          DropdownButtonFormField<String>(
            value: _reason,
            items: reasons
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _reason = v;
                });
              }
            },
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Optional description",
            ),
          ),
        ],
      ),
      actions: [

        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("Cancel"),
        ),

        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: const Text("Submit"),
        ),
      ],
    );
  }
}