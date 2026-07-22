import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import 'vet_revenue_model.dart';

enum _RevenueSort { date, gross, commission, net }

class VetRevenueTable extends StatefulWidget {
  const VetRevenueTable({super.key, required this.transactions});

  final List<VetRevenueTransaction> transactions;

  @override
  State<VetRevenueTable> createState() => _VetRevenueTableState();
}

class _VetRevenueTableState extends State<VetRevenueTable> {
  static const _pageSize = 12;
  final _searchController = TextEditingController();
  String _query = '';
  String _paymentFilter = 'all';
  _RevenueSort _sort = _RevenueSort.date;
  bool _ascending = false;
  int _page = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final filtered = _filteredTransactions();
    final pageCount = (filtered.length / _pageSize).ceil();
    if (_page >= pageCount && pageCount > 0) _page = pageCount - 1;
    final start = _page * _pageSize;
    final rows = filtered.skip(start).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() {
                  _query = value.trim().toLowerCase();
                  _page = 0;
                }),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.vetRevenueSearchHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
            ),
            DropdownButton<String>(
              value: _paymentFilter,
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(l10n.vetRevenueAllPayments),
                ),
                DropdownMenuItem(
                  value: 'paid',
                  child: Text(l10n.vetRevenuePaid),
                ),
                DropdownMenuItem(
                  value: 'pending',
                  child: Text(l10n.vetRevenuePending),
                ),
                DropdownMenuItem(
                  value: 'refunded',
                  child: Text(l10n.vetRevenueRefunded),
                ),
                DropdownMenuItem(
                  value: 'expired',
                  child: Text(l10n.vetRevenueExpired),
                ),
                DropdownMenuItem(
                  value: 'missing',
                  child: Text(l10n.vetRevenueMissingFinancial),
                ),
              ],
              onChanged: (value) => setState(() {
                _paymentFilter = value ?? 'all';
                _page = 0;
              }),
            ),
            DropdownButton<_RevenueSort>(
              value: _sort,
              items: [
                DropdownMenuItem(
                  value: _RevenueSort.date,
                  child: Text(l10n.vetRevenueSortDate),
                ),
                DropdownMenuItem(
                  value: _RevenueSort.gross,
                  child: Text(l10n.vetRevenueGross),
                ),
                DropdownMenuItem(
                  value: _RevenueSort.commission,
                  child: Text(l10n.vetRevenueCommission),
                ),
                DropdownMenuItem(
                  value: _RevenueSort.net,
                  child: Text(l10n.vetRevenueNet),
                ),
              ],
              onChanged: (value) => setState(() {
                _sort = value ?? _RevenueSort.date;
                _page = 0;
              }),
            ),
            IconButton(
              tooltip: l10n.vetRevenueSortDirection,
              onPressed: () => setState(() => _ascending = !_ascending),
              icon: Icon(
                _ascending ? Icons.arrow_upward : Icons.arrow_downward,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text(l10n.vetRevenueNoMatchingTransactions)),
          )
        else
          Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF7F3F5),
                ),
                columns: [
                  DataColumn(label: Text(l10n.vetRevenueDate)),
                  DataColumn(label: Text(l10n.vetRevenueCustomer)),
                  DataColumn(label: Text(l10n.vetRevenuePet)),
                  DataColumn(label: Text(l10n.vetRevenueService)),
                  DataColumn(label: Text(l10n.vetRevenueGross)),
                  DataColumn(label: Text(l10n.vetRevenueCommission)),
                  DataColumn(label: Text(l10n.vetRevenueNet)),
                  DataColumn(label: Text(l10n.vetRevenuePayment)),
                  DataColumn(label: Text(l10n.vetRevenueSettlement)),
                  DataColumn(label: Text(l10n.vetRevenueInvoice)),
                  DataColumn(label: Text(l10n.vetRevenueTransactionReference)),
                ],
                rows: [
                  for (final transaction in rows)
                    _row(transaction, locale, l10n),
                ],
              ),
            ),
          ),
        if (pageCount > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(l10n.vetRevenuePageOf(_page + 1, pageCount)),
              IconButton(
                onPressed: _page + 1 < pageCount
                    ? () => setState(() => _page++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    );
  }

  DataRow _row(
    VetRevenueTransaction transaction,
    String locale,
    AppLocalizations l10n,
  ) {
    String money(double? value) {
      if (value == null) return '—';
      return NumberFormat.currency(
        locale: locale,
        symbol: transaction.currency == 'TRY'
            ? '₺'
            : '${transaction.currency} ',
        decimalDigits: 2,
      ).format(value);
    }

    final date = transaction.eventDate == null
        ? '—'
        : DateFormat.yMMMd(locale).format(transaction.eventDate!);
    return DataRow(
      cells: [
        DataCell(Text(date)),
        DataCell(Text(_fallback(transaction.customerName))),
        DataCell(Text(_fallback(transaction.petName))),
        DataCell(Text(_fallback(transaction.serviceTitle))),
        DataCell(Text(money(transaction.grossAmount))),
        DataCell(Text(money(transaction.commissionAmount))),
        DataCell(Text(money(transaction.businessNetAmount))),
        DataCell(Text(_statusLabel(transaction, l10n))),
        DataCell(Text(_fallback(transaction.settlementStatus))),
        DataCell(Text(_fallback(transaction.invoiceStatus))),
        DataCell(SelectableText(_fallback(transaction.paymentTransactionId))),
      ],
    );
  }

  String _fallback(String value) => value.isEmpty ? '—' : value;

  String _statusLabel(
    VetRevenueTransaction transaction,
    AppLocalizations l10n,
  ) => switch (transaction.status) {
    VetRevenueStatus.recognizedPaid => l10n.vetRevenuePaid,
    VetRevenueStatus.pending => l10n.vetRevenuePending,
    VetRevenueStatus.refunded => l10n.vetRevenueRefunded,
    VetRevenueStatus.expired => l10n.vetRevenueExpired,
    VetRevenueStatus.financialDataMissing => l10n.vetRevenueMissingFinancial,
    VetRevenueStatus.other => _fallback(transaction.paymentStatus),
  };

  List<VetRevenueTransaction> _filteredTransactions() {
    final result = widget.transactions.where((transaction) {
      final searchable = [
        transaction.customerName,
        transaction.petName,
        transaction.serviceTitle,
        transaction.appointmentId,
        transaction.paymentTransactionId,
      ].join(' ').toLowerCase();
      if (_query.isNotEmpty && !searchable.contains(_query)) return false;
      return switch (_paymentFilter) {
        'paid' => transaction.status == VetRevenueStatus.recognizedPaid,
        'pending' => transaction.status == VetRevenueStatus.pending,
        'refunded' => transaction.status == VetRevenueStatus.refunded,
        'expired' => transaction.status == VetRevenueStatus.expired,
        'missing' =>
          transaction.status == VetRevenueStatus.financialDataMissing,
        _ => true,
      };
    }).toList();

    double amount(VetRevenueTransaction item) => switch (_sort) {
      _RevenueSort.gross => item.grossAmount ?? double.negativeInfinity,
      _RevenueSort.commission =>
        item.commissionAmount ?? double.negativeInfinity,
      _RevenueSort.net => item.businessNetAmount ?? double.negativeInfinity,
      _RevenueSort.date => 0,
    };
    result.sort((a, b) {
      final comparison = _sort == _RevenueSort.date
          ? (a.eventDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              b.eventDate ?? DateTime.fromMillisecondsSinceEpoch(0),
            )
          : amount(a).compareTo(amount(b));
      return _ascending ? comparison : -comparison;
    });
    return result;
  }
}
