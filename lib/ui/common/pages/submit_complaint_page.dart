import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SubmitComplaintPage extends StatefulWidget {
  final String targetType;
  final String targetId;

  const SubmitComplaintPage({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  @override
  State<SubmitComplaintPage> createState() => _SubmitComplaintPageState();
}

class _SubmitComplaintPageState extends State<SubmitComplaintPage> {

  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = "harassment";
  bool _loading = false;

  final List<String> _categories = [
    "harassment",
    "abuse",
    "scam",
    "spam",
    "impersonation",
    "fakeListing",
    "paymentDispute",
    "safetyRisk",
    "inappropriateContent",
    "fraud",
    "other",
  ];

  Future<void> _submitComplaint() async {

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Submit Complaint"),
          content: const Text(
              "Are you sure you want to submit this complaint?"),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context, false),
            ),
            ElevatedButton(
              child: const Text("Submit"),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _loading = true;
    });

    try {

      final functions =
          FirebaseFunctions.instanceFor(region: 'europe-west3');

      final callable = functions.httpsCallable('createComplaint');

      await callable.call({
        "targetType": widget.targetType,
        "targetId": widget.targetId,
        "category": _selectedCategory,
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Complaint submitted successfully"),
        ),
      );

      Navigator.pop(context);

    }

    on FirebaseFunctionsException catch (e) {

      debugPrint("❌ Complaint error: ${e.code} ${e.message}");

      String message = "Failed to submit complaint";

      if (e.code == "already-exists") {
        message = "You already have an open complaint for this item.";
      }

      if (e.code == "unauthenticated") {
        message = "Please login first.";
      }

      if (e.code == "invalid-argument") {
        message = "Invalid complaint data.";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }

    }

    catch (e) {

      debugPrint("❌ Unknown complaint error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unexpected error"),
          ),
        );
      }

    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Submit Complaint"),
        backgroundColor: Colors.pink,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Form(
          key: _formKey,

          child: Column(
            children: [

              /// CATEGORY
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 16),

              /// TITLE
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Title required";
                  }
                  if (value.length < 3) {
                    return "Title too short";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              /// DESCRIPTION
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Description required";
                  }
                  if (value.length < 5) {
                    return "Description too short";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              /// SUBMIT BUTTON
              SizedBox(
                width: double.infinity,

                child: ElevatedButton(

                  onPressed: _loading ? null : _submitComplaint,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                  ),

                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Submit Complaint",
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}