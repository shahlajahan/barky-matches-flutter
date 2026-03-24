import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ReportButton extends StatelessWidget {
  final String type;
  final String targetId;
  final String targetOwnerId;

  const ReportButton({
    super.key,
    required this.type,
    required this.targetId,
    required this.targetOwnerId,
  });

  Future<void> _openReportDialog(BuildContext context) async {

    String? selectedReason;
    final messageController = TextEditingController();

    final reasons = {
      "spam": "Spam",
      "abuse": "Abuse / Harassment",
      "scam": "Scam",
      "fake_profile": "Fake Profile",
      "animal_safety": "Animal Safety",
      "other": "Other"
    };

    await showDialog(
      context: context,
      builder: (context) {

        return AlertDialog(
          title: const Text("Report"),

          content: StatefulBuilder(
            builder: (context, setState) {

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  DropdownButtonFormField<String>(
                    hint: const Text("Select reason"),
                    value: selectedReason,
                    items: reasons.entries.map((e) {
                      return DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedReason = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: messageController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Additional details (optional)",
                      border: OutlineInputBorder(),
                    ),
                  ),

                ],
              );
            },
          ),

          actions: [

            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),

            ElevatedButton(
              child: const Text("Submit"),
              onPressed: () async {

                if (selectedReason == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please select a reason"),
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                await _submitReport(
                  context,
                  selectedReason!,
                  messageController.text,
                );
              },
            ),

          ],
        );
      },
    );
  }

  Future<void> _submitReport(
  BuildContext context,
  String reasonCode,
  String message,
) async {

  final messenger = ScaffoldMessenger.of(context);

  try {

    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west3',
    ).httpsCallable('createReport');

    await callable.call({

      "type": type,
      "targetId": targetId,
      "targetOwnerId": targetOwnerId,
      "reasonCode": reasonCode,
      "reasonText": reasonCode,
      "message": message,

    });

    messenger.showSnackBar(
      const SnackBar(
        content: Text("Report submitted"),
      ),
    );

  } on FirebaseFunctionsException catch (e) {

    if (e.code == "already-exists") {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("You already reported this item"),
        ),
      );
      return;
    }

    if (e.code == "resource-exhausted") {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Too many reports. Try again later."),
        ),
      );
      return;
    }

    if (e.code == "unauthenticated") {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Please login first"),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text("Report failed: ${e.message}"),
      ),
    );

  } catch (_) {

    messenger.showSnackBar(
      const SnackBar(
        content: Text("Unexpected error"),
      ),
    );

  }
}

  @override
  Widget build(BuildContext context) {

    return IconButton(
      icon: const Icon(Icons.flag_outlined),
      tooltip: "Report",
      onPressed: () {
        _openReportDialog(context);
      },
    );
  }
}