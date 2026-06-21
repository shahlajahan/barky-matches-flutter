import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AddServiceDetailPage extends StatefulWidget {
  final String businessId;
  final String serviceTitle;
  final String? serviceId;
  final Map<String, dynamic>? existingData;
  final bool openedAsRoute;

  const AddServiceDetailPage({
    super.key,
    required this.businessId,
    required this.serviceTitle,
    this.serviceId,
    this.existingData,
    this.openedAsRoute = false,
  });

  @override
  State<AddServiceDetailPage> createState() => _AddServiceDetailPageState();
}

class _AddServiceDetailPageState extends State<AddServiceDetailPage> {
  final _priceController = TextEditingController();

  String? _selectedDuration;

  bool _loading = false;

  // ✅ duration options حرفه‌ای
  final List<String> _durations = [
    "15 min",
    "30 min",
    "1 hour",
    "2 hours",
    "2–4 hours",
    "Half day",
    "Full day",
    "Custom",
  ];

  @override
  void initState() {
    super.initState();

    if (widget.existingData != null) {
      final data = widget.existingData!;

      _priceController.text = data['price'] != null
          ? data['price'].toString()
          : '';

      final rawDuration = data['duration'];

      if (rawDuration == null) {
        _selectedDuration = null;
      } else if (rawDuration is int) {
        // 🔥 تبدیل دیتای قدیمی
        _selectedDuration = "$rawDuration min";
      } else {
        _selectedDuration = rawDuration.toString();
      }
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final price = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    );

    setState(() => _loading = true);
    var shouldResetLoading = true;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'upsertService',
      );

      final res = await callable.call({
        "businessId": widget.businessId,
        "title": widget.serviceTitle,
        "price": price,
        "duration": _selectedDuration,
      });

      debugPrint("🔥 RESULT: ${res.data}");

      if (!mounted) return;

      shouldResetLoading = false;
      FocusManager.instance.primaryFocus?.unfocus();
      _closePage();
    } catch (e) {
      debugPrint("❌ ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (shouldResetLoading && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.serviceId != null;

    return Material(
      color: AppTheme.bg,
      child: SafeArea(
        child: Column(
          children: [
            /// HEADER
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      _closePage();
                    },
                  ),
                  Text(
                    isEdit ? "Edit Service" : widget.serviceTitle,
                    style: AppTheme.h2(),
                  ),
                ],
              ),
            ),

            /// BODY
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  /// PRICE (OPTIONAL)
                  _field(
                    "Price (₺) - optional",
                    _priceController,
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// DURATION (NEW SYSTEM)
                  Text("Duration", style: AppTheme.body()),
                  const SizedBox(height: 6),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedDuration,
                    items: _durations.map((e) {
                      return DropdownMenuItem(value: e, child: Text(e));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDuration = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Select duration",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// SAVE BUTTON
                  ElevatedButton(
                    onPressed: _loading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEdit ? "Update Service" : "Save Service"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    TextInputType? keyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.body()),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: keyboard,
          decoration: InputDecoration(
            hintText: "Optional",
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  void _closePage() {
    if (widget.openedAsRoute) {
      Navigator.of(context).pop();
    } else {
      context.read<AppState>().closeBusinessSubPage();
    }
  }
}
