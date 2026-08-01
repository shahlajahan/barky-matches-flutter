import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

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
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

      final callable = functions.httpsCallable(
        'upsertService',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      debugPrint(
        '🔥 UPSERT SERVICE REQUEST → '
        'businessId=${widget.businessId}, '
        'title=${widget.serviceTitle}, '
        'price=$price (${price.runtimeType}), '
        'duration=$_selectedDuration (${_selectedDuration.runtimeType})',
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
    } on FirebaseFunctionsException catch (e, stackTrace) {
      debugPrint('❌ UPSERT FUNCTION CODE: ${e.code}');
      debugPrint('❌ UPSERT FUNCTION MESSAGE: ${e.message}');
      debugPrint('❌ UPSERT FUNCTION DETAILS: ${e.details}');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? AppLocalizations.of(context)!.serviceDetailsSaveFailed,
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ UPSERT UNEXPECTED ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.serviceDetailsSaveFailed),
        ),
      );
    } finally {
      if (shouldResetLoading && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.serviceId != null || widget.existingData != null;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Material(
      color: const Color(0xFFFFF9FA),
      child: SafeArea(
        child: Column(
          children: [
            _PageHeader(
              isEdit: isEdit,
              serviceTitle: widget.serviceTitle,
              onBack: () {
                FocusManager.instance.primaryFocus?.unfocus();
                _closePage();
              },
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth >= 760
                      ? 32.0
                      : 20.0;
                  return ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      24,
                      horizontalPadding,
                      32 + viewInsets.bottom,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ServiceIdentityCard(
                                serviceTitle: widget.serviceTitle,
                                isEdit: isEdit,
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: EdgeInsets.all(
                                  constraints.maxWidth < 420 ? 20 : 28,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFF0E5E9),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.055,
                                      ),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _PremiumFieldLabel(
                                      label: "Price",
                                      badge: "Optional",
                                    ),
                                    const SizedBox(height: 9),
                                    TextField(
                                      controller: _priceController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      style: AppTheme.body(
                                        size: 16,
                                        weight: FontWeight.w600,
                                      ),
                                      decoration: _fieldDecoration(
                                        hintText: "0.00",
                                        prefix: Text(
                                          "₺",
                                          style: AppTheme.body(
                                            color: AppTheme.card,
                                            size: 17,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.priceDeterminedAfterExamination,
                                      style: AppTheme.caption(
                                        color: const Color(0xFF75696E),
                                        size: 12.5,
                                      ).copyWith(height: 1.45),
                                    ),
                                    const SizedBox(height: 24),
                                    const _PremiumFieldLabel(
                                      label: "Estimated duration",
                                    ),
                                    const SizedBox(height: 9),
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedDuration,
                                      isExpanded: true,
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 24,
                                      ),
                                      menuMaxHeight: 320,
                                      items: _durations.map((duration) {
                                        return DropdownMenuItem(
                                          value: duration,
                                          child: Text(
                                            duration,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTheme.body(
                                              size: 15,
                                              weight: FontWeight.w500,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedDuration = val;
                                        });
                                      },
                                      decoration: _fieldDecoration(
                                        hintText: "Select duration",
                                        prefix: const Icon(
                                          Icons.schedule_rounded,
                                          color: AppTheme.card,
                                          size: 21,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const _InfoStrip(),
                                    const SizedBox(height: 28),
                                    _SaveButton(
                                      isEdit: isEdit,
                                      loading: _loading,
                                      onPressed: _save,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required Widget prefix,
  }) {
    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTheme.body(color: const Color(0xFF9A8E93), size: 15),
      prefixIcon: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, end: 12),
        child: Center(widthFactor: 1, child: prefix),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 54),
      filled: true,
      fillColor: const Color(0xFFFCFAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: border(const Color(0xFFE5DADF)),
      enabledBorder: border(const Color(0xFFE5DADF)),
      focusedBorder: border(AppTheme.card, width: 1.6),
      disabledBorder: border(const Color(0xFFEDE8EA)),
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

class _PageHeader extends StatelessWidget {
  final bool isEdit;
  final String serviceTitle;
  final VoidCallback onBack;

  const _PageHeader({
    required this.isEdit,
    required this.serviceTitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0E5E9))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Row(
            children: [
              Material(
                color: const Color(0xFFF8F1F4),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBack,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 22,
                      color: AppTheme.card,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isEdit ? "Edit service" : "Add service",
                      style: AppTheme.h1(size: 21),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      serviceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption(
                        color: const Color(0xFF75696E),
                        size: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceIdentityCard extends StatelessWidget {
  final String serviceTitle;
  final bool isEdit;

  const _ServiceIdentityCard({
    required this.serviceTitle,
    required this.isEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0D7E0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: AppTheme.card,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(serviceTitle, style: AppTheme.h3(size: 16)),
                    ),
                    if (isEdit) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.editing,
                          style: AppTheme.caption(
                            color: Colors.white,
                            size: 11,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  AppLocalizations.of(context)!.setPriceDurationDescription,
                  style: AppTheme.caption(
                    color: const Color(0xFF75696E),
                    size: 12.5,
                  ).copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumFieldLabel extends StatelessWidget {
  final String label;
  final String? badge;

  const _PremiumFieldLabel({required this.label, this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTheme.body(size: 14, weight: FontWeight.w600),
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3DB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge!,
              style: AppTheme.caption(
                color: const Color(0xFF8A5A00),
                size: 11,
                weight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE6E9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppTheme.card,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.serviceDetailsBeforeBooking,
              style: AppTheme.caption(
                color: const Color(0xFF655B60),
                size: 12.5,
              ).copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool isEdit;
  final bool loading;
  final VoidCallback onPressed;

  const _SaveButton({
    required this.isEdit,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.card,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.card.withValues(alpha: 0.55),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: loading
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Icon(isEdit ? Icons.save_outlined : Icons.add_rounded, size: 21),
        label: Text(
          loading
              ? (isEdit ? "Saving changes…" : "Adding service…")
              : (isEdit ? "Save changes" : "Add service"),
          style: AppTheme.button(color: Colors.white),
        ),
      ),
    );
  }
}
