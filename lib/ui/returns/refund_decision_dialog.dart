import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../services/order_return_service.dart';

enum RefundDecisionType { full, partial, rejected }

class RefundDecisionInput {
  final RefundDecisionType type;
  final double amount;
  final String reasonCode;
  final String sellerNotes;
  final String buyerExplanation;

  const RefundDecisionInput({
    required this.type,
    required this.amount,
    required this.reasonCode,
    required this.sellerNotes,
    required this.buyerExplanation,
  });
}

Future<RefundDecisionInput?> showRefundDecisionDialog({
  required BuildContext context,
  required RefundPolicyAmounts amounts,
}) {
  return showDialog<RefundDecisionInput>(
    context: context,
    builder: (_) => _RefundDecisionDialog(amounts: amounts),
  );
}

class _RefundDecisionDialog extends StatefulWidget {
  final RefundPolicyAmounts amounts;

  const _RefundDecisionDialog({required this.amounts});

  @override
  State<_RefundDecisionDialog> createState() => _RefundDecisionDialogState();
}

class _RefundDecisionDialogState extends State<_RefundDecisionDialog> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _buyerExplanationController = TextEditingController();

  RefundDecisionType _type = RefundDecisionType.full;
  String? _reasonCode;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.amounts.fullEligibleAmount.toStringAsFixed(
      2,
    );
    _amountController.addListener(_refresh);
    _notesController.addListener(_refresh);
    _buyerExplanationController.addListener(_refresh);
  }

  @override
  void dispose() {
    _amountController
      ..removeListener(_refresh)
      ..dispose();
    _notesController
      ..removeListener(_refresh)
      ..dispose();
    _buyerExplanationController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  double get _refundAmount {
    if (_type == RefundDecisionType.full) {
      return widget.amounts.fullEligibleAmount;
    }
    if (_type == RefundDecisionType.rejected) return 0;
    return double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
  }

  bool get _isValid {
    if (_reasonCode == null) return false;
    final notesRequired =
        _type == RefundDecisionType.partial ||
        _type == RefundDecisionType.rejected ||
        _reasonCode == 'other';
    if (notesRequired && _notesController.text.trim().isEmpty) return false;
    if (_type == RefundDecisionType.rejected &&
        _buyerExplanationController.text.trim().isEmpty) {
      return false;
    }
    if (_type == RefundDecisionType.partial) {
      return _refundAmount > 0 &&
          _refundAmount <= widget.amounts.partialEligibleAmount;
    }
    return _type == RefundDecisionType.rejected || _refundAmount > 0;
  }

  void _selectType(RefundDecisionType value) {
    setState(() {
      _type = value;
      _amountController.text = switch (value) {
        RefundDecisionType.full =>
          widget.amounts.fullEligibleAmount.toStringAsFixed(2),
        RefundDecisionType.partial => '',
        RefundDecisionType.rejected => '0.00',
      };
    });
  }

  String _reasonLabel(AppLocalizations l10n, String code) {
    return switch (code) {
      'item_returned_damaged' => l10n.refundReasonItemReturnedDamaged,
      'missing_accessories' => l10n.refundReasonMissingAccessories,
      'customer_caused_damage' => l10n.refundReasonCustomerCausedDamage,
      'restocking_fee' => l10n.refundReasonRestockingFee,
      'partial_return' => l10n.refundReasonPartialReturn,
      'seller_mistake' => l10n.refundReasonSellerMistake,
      'wrong_item' => l10n.refundReasonWrongItem,
      'defective_product' => l10n.refundReasonDefectiveProduct,
      'item_never_delivered' => l10n.refundReasonItemNeverDelivered,
      _ => l10n.refundReasonOther,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currency = NumberFormat.currency(
      locale: Localizations.localeOf(context).toLanguageTag(),
      symbol: 'TRY',
      decimalDigits: 2,
    );
    final difference = (widget.amounts.originalOrderAmount - _refundAmount)
        .clamp(0, double.infinity);
    final reason = _reasonCode == null
        ? l10n.refundReasonNotSelected
        : _reasonLabel(l10n, _reasonCode!);

    return AlertDialog(
      title: Text(l10n.refundDecisionTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DecisionOption(
                selected: _type == RefundDecisionType.full,
                icon: Icons.replay_circle_filled_rounded,
                title: l10n.refundDecisionFullTitle,
                description: l10n.refundDecisionFullDescription,
                supportingText: l10n.refundDecisionFullRecommended,
                onTap: () => _selectType(RefundDecisionType.full),
              ),
              const SizedBox(height: 8),
              _DecisionOption(
                selected: _type == RefundDecisionType.partial,
                icon: Icons.pie_chart_rounded,
                title: l10n.refundDecisionPartialTitle,
                description: l10n.refundDecisionPartialDescription,
                onTap: () => _selectType(RefundDecisionType.partial),
              ),
              const SizedBox(height: 8),
              _DecisionOption(
                selected: _type == RefundDecisionType.rejected,
                icon: Icons.block_rounded,
                title: l10n.refundDecisionRejectTitle,
                description: l10n.refundDecisionRejectDescription,
                onTap: () => _selectType(RefundDecisionType.rejected),
              ),
              const SizedBox(height: 16),
              if (_type == RefundDecisionType.partial) ...[
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.refundPartialAmountLabel,
                    helperText: l10n.refundMaximumEligible(
                      currency.format(widget.amounts.partialEligibleAmount),
                    ),
                    errorText:
                        _amountController.text.isNotEmpty &&
                            (_refundAmount <= 0 ||
                                _refundAmount >
                                    widget.amounts.partialEligibleAmount)
                        ? l10n.refundAmountValidationError
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                initialValue: _reasonCode,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.refundDecisionReasonLabel,
                ),
                items:
                    const [
                          'item_returned_damaged',
                          'missing_accessories',
                          'customer_caused_damage',
                          'restocking_fee',
                          'partial_return',
                          'seller_mistake',
                          'wrong_item',
                          'defective_product',
                          'item_never_delivered',
                          'other',
                        ]
                        .map(
                          (code) => DropdownMenuItem(
                            value: code,
                            child: Text(_reasonLabel(l10n, code)),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _reasonCode = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.refundSellerNotesLabel,
                  helperText:
                      _type == RefundDecisionType.full && _reasonCode != 'other'
                      ? l10n.refundNotesOptional
                      : l10n.refundNotesRequired,
                ),
              ),
              if (_type == RefundDecisionType.rejected) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _buyerExplanationController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.refundBuyerExplanationLabel,
                    helperText: l10n.refundBuyerExplanationHelper,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: l10n.refundOriginalOrderLabel,
                        value: currency.format(
                          widget.amounts.originalOrderAmount,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        label: l10n.refundSummaryRefundLabel,
                        value: currency.format(_refundAmount),
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        label: l10n.refundDifferenceLabel,
                        value: currency.format(difference),
                      ),
                      const Divider(height: 24),
                      _SummaryRow(
                        label: l10n.refundDecisionReasonLabel,
                        value: reason,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isValid
              ? () => Navigator.pop(
                  context,
                  RefundDecisionInput(
                    type: _type,
                    amount: _refundAmount,
                    reasonCode: _reasonCode!,
                    sellerNotes: _notesController.text.trim(),
                    buyerExplanation: _type == RefundDecisionType.rejected
                        ? _buyerExplanationController.text.trim()
                        : _notesController.text.trim(),
                  ),
                )
              : null,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

class _DecisionOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final String? supportingText;
  final VoidCallback onTap;

  const _DecisionOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    this.supportingText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              Icon(icon, color: selected ? colors.primary : colors.onSurface),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(description),
                    if (supportingText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        supportingText!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
