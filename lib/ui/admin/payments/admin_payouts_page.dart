import 'dart:convert';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/admin/payments/payout_operations_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:barky_matches_fixed/ui/admin/pages/business_admin_detail_page.dart';
import 'package:barky_matches_fixed/ui/admin/payments/payout_download.dart';
import 'package:barky_matches_fixed/ui/orders/order_detail_page.dart';

String _firebaseErrorCode(Object? error) {
  if (error is FirebaseException) return error.code;
  return 'unknown';
}

class AdminPayoutsPage extends StatefulWidget {
  const AdminPayoutsPage({super.key});

  @override
  State<AdminPayoutsPage> createState() => _AdminPayoutsPageState();
}

class _AdminPayoutsPageState extends State<AdminPayoutsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  final _selectedAggregateKeys = <String>{};
  String _query = '';
  PayoutDatePreset? _datePreset;
  DateTimeRange? _customDateRange;
  bool? _validBank;
  String? _payoutStatusFilter;
  String? _settlementStatusFilter;
  String? _sellerFilter;
  String? _bankFilter;
  double? _minimumAmount;
  double? _maximumAmount;
  bool? _includedInBatch;
  bool _busy = false;
  int _lastTabIndex = 0;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-west3');

  Future<void> _refreshProjection() async {
    try {
      for (var page = 0; page < 10; page++) {
        final response = await _functions
            .httpsCallable('refreshPayoutIndexEnrichment')
            .call();
        final data = Map<String, dynamic>.from(response.data as Map);
        if (data['hasMore'] != true) break;
      }
    } catch (_) {
      // Existing projections remain readable; a later authorized visit
      // retries this deterministic enrichment.
    }
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _tabs.addListener(_handleTabChanged);
    _refreshProjection();
  }

  void _handleTabChanged() {
    if (_tabs.index == _lastTabIndex || !mounted) return;
    _lastTabIndex = _tabs.index;
    _search.clear();
    setState(() {
      _query = '';
      _datePreset = null;
      _customDateRange = null;
      _validBank = null;
      _payoutStatusFilter = null;
      _settlementStatusFilter = null;
      _sellerFilter = null;
      _bankFilter = null;
      _minimumAmount = null;
      _maximumAmount = null;
      _includedInBatch = null;
    });
  }

  @override
  void dispose() {
    _tabs.removeListener(_handleTabChanged);
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  DateTimeRange? _presetRange(PayoutDatePreset? preset) {
    if (preset == PayoutDatePreset.custom) return _customDateRange;
    if (preset == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case PayoutDatePreset.today:
        return DateTimeRange(
          start: today,
          end: today.add(const Duration(days: 1, microseconds: -1)),
        );
      case PayoutDatePreset.yesterday:
        final start = today.subtract(const Duration(days: 1));
        return DateTimeRange(
          start: start,
          end: today.subtract(const Duration(microseconds: 1)),
        );
      case PayoutDatePreset.thisWeek:
        final start = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(
          start: start,
          end: today.add(const Duration(days: 1, microseconds: -1)),
        );
      case PayoutDatePreset.lastWeek:
        final thisWeek = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(
          start: thisWeek.subtract(const Duration(days: 7)),
          end: thisWeek.subtract(const Duration(microseconds: 1)),
        );
      case PayoutDatePreset.thisMonth:
        return DateTimeRange(
          start: DateTime(today.year, today.month),
          end: DateTime(
            today.year,
            today.month + 1,
          ).subtract(const Duration(microseconds: 1)),
        );
      case PayoutDatePreset.custom:
        return null;
    }
  }

  Future<void> _selectDatePreset(PayoutDatePreset? preset) async {
    if (preset != PayoutDatePreset.custom) {
      setState(() => _datePreset = preset);
      return;
    }
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customDateRange,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _datePreset = preset;
      _customDateRange = DateTimeRange(
        start: DateTime(
          selected.start.year,
          selected.start.month,
          selected.start.day,
        ),
        end: DateTime(
          selected.end.year,
          selected.end.month,
          selected.end.day,
          23,
          59,
          59,
          999,
        ),
      );
    });
  }

  List<PayoutOperationRecord> _filtered(List<PayoutOperationRecord> records) {
    final range = _presetRange(_datePreset);
    return filterPayoutRecords(
      records: records,
      query: _query,
      payoutStatus: _payoutStatusFilter,
      settlementStatus: _settlementStatusFilter,
      seller: _sellerFilter?.trim().isEmpty == true ? null : _sellerFilter,
      bank: _bankFilter?.trim().isEmpty == true ? null : _bankFilter,
      validBank: _validBank,
      minimumAmount: _minimumAmount,
      maximumAmount: _maximumAmount,
      includedInBatch: _includedInBatch,
      start: range?.start,
      end: range?.end,
    );
  }

  Future<void> _createBatch(List<SellerPayoutAggregate> aggregates) async {
    final selected = aggregates
        .where((aggregate) => _selectedAggregateKeys.contains(aggregate.key))
        .toList();
    if (selected.isEmpty) return;
    setState(() => _busy = true);
    try {
      final result = await _functions.httpsCallable('createPayoutBatch').call({
        'payoutIndexIds': selected
            .expand((aggregate) => aggregate.payoutIndexIds)
            .toList(),
      });
      if (!mounted) return;
      _selectedAggregateKeys.clear();
      final data = Map<String, dynamic>.from(result.data as Map);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.payoutBatchCreated(data['batchNumber'].toString()),
          ),
        ),
      );
      _tabs.animateTo(1);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.payoutOperationFailed(message ?? ''),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: Text(l10n.payoutManagement),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(text: l10n.financeOverviewTab),
            Tab(text: l10n.payoutEligibleTab),
            Tab(text: l10n.financeWaitingTab),
            Tab(text: l10n.payoutBatchesTab),
            Tab(text: l10n.paidStatusLabel),
            Tab(text: l10n.payoutExceptionsTab),
          ],
        ),
      ),
      body: Column(
        children: [
          _OperationsToolbar(
            controller: _search,
            onExport: _showFinanceReportDialog,
            preset: _datePreset,
            validBank: _validBank,
            onSearch: (value) => setState(() => _query = value.trim()),
            onPreset: _selectDatePreset,
            onValidBank: (value) => setState(() => _validBank = value),
            payoutStatus: _payoutStatusFilter,
            settlementStatus: _settlementStatusFilter,
            includedInBatch: _includedInBatch,
            onPayoutStatus: (value) =>
                setState(() => _payoutStatusFilter = value),
            onSettlementStatus: (value) =>
                setState(() => _settlementStatusFilter = value),
            onIncludedInBatch: (value) =>
                setState(() => _includedInBatch = value),
            onSeller: (value) => setState(() => _sellerFilter = value),
            onBank: (value) => setState(() => _bankFilter = value),
            onMinimumAmount: (value) =>
                setState(() => _minimumAmount = double.tryParse(value)),
            onMaximumAmount: (value) =>
                setState(() => _maximumAmount = double.tryParse(value)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('payoutIndex')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint(
                    '[FinanceOps] payoutIndex query failed: '
                    'collection=payoutIndex code=${_firebaseErrorCode(snapshot.error)} '
                    'error=${snapshot.error}',
                  );
                  return Center(child: Text(l10n.payoutLoadFailed));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final records = _filtered(
                  snapshot.data!.docs
                      .map(
                        (doc) => PayoutOperationRecord.fromFirestore(
                          doc.id,
                          doc.data(),
                        ),
                      )
                      .toList(),
                );
                return TabBarView(
                  controller: _tabs,
                  children: [
                    const _FinanceOverviewTab(),
                    _buildEligible(records),
                    _buildWaiting(records),
                    const _PayoutBatchesTab(),
                    _buildPaid(records),
                    _buildExceptions(records),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFinanceReportDialog() async {
    final filters = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _FinanceReportConfigDialog(),
    );
    if (!mounted || filters == null) return;
    setState(() => _busy = true);
    try {
      final response = await _functions
          .httpsCallable('generateFinancePayablesReport')
          .call({'filters': filters, 'fullIban': true});
      if (!mounted) return;
      await _showFinanceReportFiles(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_financeReportErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showFinanceReportFiles(Map<String, dynamic> data) async {
    final files = (data['files'] as List? ?? [])
        .map((file) => Map<String, dynamic>.from(file as Map))
        .toList();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Generated Finance Reports'),
        content: SizedBox(
          width: 640,
          child: files.isEmpty
              ? const Text('No report files were generated.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: files.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return _FinanceReportFileTile(
                      file: file,
                      onDownload: _storageActionAvailable(file)
                          ? () => _runFinanceReportAction(
                              () => _downloadFinanceReport(file),
                            )
                          : null,
                      onShare: kIsWeb || !_storageActionAvailable(file)
                          ? null
                          : () => _runFinanceReportAction(
                              () => _shareFinanceReport(file),
                            ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _refreshFinanceReportUrl(
    Map<String, dynamic> file,
  ) async {
    final response = await _functions
        .httpsCallable('downloadFinancePayablesReport')
        .call({
          'reportId': file['reportId'],
          'language': file['language'],
        });
    return Map<String, dynamic>.from(response.data as Map);
  }

  bool _storageActionAvailable(Map<String, dynamic> file) {
    return file['storageReady'] != false &&
        (file['storagePath'] ?? '').toString().trim().isNotEmpty;
  }

  String _financeReportErrorMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      final details = error.details is Map
          ? Map<String, dynamic>.from(error.details as Map)
          : const <String, dynamic>{};
      switch (details['code']) {
        case 'STORAGE_BILLING_DISABLED':
          return 'Finance report storage is unavailable because billing is disabled.';
        case 'STORAGE_OBJECT_MISSING':
          return 'This report file is no longer available.';
        case 'STORAGE_PERMISSION_DENIED':
          return 'You do not have permission to access this report file.';
        case 'STORAGE_INVALID_PATH':
          return 'The report file path is invalid.';
        case 'STORAGE_SIGNED_URL_FAILED':
          return 'A secure report download link could not be created. Please retry.';
        case 'FINANCE_REPORT_METADATA_MISSING':
          return 'The report file metadata is incomplete. Regenerate the report.';
        case 'FINANCE_REPORT_FULL_IBAN_REQUIRES_OPERATE':
          return 'You can view Finance reports, but this report contains unmasked bank information and requires Finance Operations permission.';
        case 'FINANCE_AUTHORIZATION_UNRESOLVED':
          return 'Your Admin permissions could not be resolved. Sign out and sign in again.';
        case 'FINANCE_REPORT_TEMPORARY_FALLBACK_SIZE_LIMIT':
          return 'This report is too large for temporary download. Please retry after Storage service access is restored.';
      }
      return error.message ?? 'Finance report file access failed.';
    }
    return 'Finance report file access failed: $error';
  }

  Future<void> _runFinanceReportAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_financeReportErrorMessage(error))),
      );
    }
  }

  Future<void> _downloadFinanceReport(Map<String, dynamic> file) async {
    final fresh = await _refreshFinanceReportUrl(file);
    final name = (fresh['fileName'] ?? file['fileName'] ?? 'finance_report.xlsx')
        .toString();
    String? saved;
    final inlineBytes = _inlineFinanceReportBytes(fresh);
    if (inlineBytes != null) {
      saved = await downloadPayoutBytes(
        bytes: inlineBytes,
        fileName: name,
        contentType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } else if (kIsWeb) {
      final url = (fresh['url'] ?? '').toString();
      if (url.isEmpty) throw StateError('Finance report URL is missing.');
      saved = await downloadPayoutUrl(url: url, fileName: name);
    } else {
      final url = (fresh['url'] ?? '').toString();
      if (url.isEmpty) throw StateError('Finance report URL is missing.');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Finance report download failed (${response.statusCode}).');
      }
      saved = await downloadPayoutBytes(
        bytes: response.bodyBytes,
        fileName: name,
        contentType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saved == null ? 'Browser download started.' : 'Saved to $saved')),
    );
  }

  Future<void> _shareFinanceReport(Map<String, dynamic> file) async {
    final fresh = await _refreshFinanceReportUrl(file);
    final name = (fresh['fileName'] ?? file['fileName'] ?? 'finance_report.xlsx')
        .toString();
    final inlineBytes = _inlineFinanceReportBytes(fresh);
    final bytes = inlineBytes ?? await _downloadFinanceReportUrlBytes(fresh);
    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        name: name,
      ),
    ]);
  }

  Uint8List? _inlineFinanceReportBytes(Map<String, dynamic> response) {
    if (response['deliveryMode'] != 'inline_base64') return null;
    final encoded = (response['bytesBase64'] ?? '').toString();
    if (encoded.isEmpty) throw StateError('Finance report bytes are missing.');
    return Uint8List.fromList(base64Decode(encoded));
  }

  Future<Uint8List> _downloadFinanceReportUrlBytes(
    Map<String, dynamic> response,
  ) async {
    final url = (response['url'] ?? '').toString();
    if (url.isEmpty) throw StateError('Finance report URL is missing.');
    final downloaded = await http.get(Uri.parse(url));
    if (downloaded.statusCode < 200 || downloaded.statusCode >= 300) {
      throw StateError(
        'Finance report download failed (${downloaded.statusCode}).',
      );
    }
    return downloaded.bodyBytes;
  }

  Widget _buildEligible(List<PayoutOperationRecord> records) {
    final l10n = AppLocalizations.of(context)!;
    final aggregates = aggregateSellerPayouts(
      records.where(
        (record) =>
            record.eligibilityStatus == 'eligible' &&
            record.commissionDataQuality == 'verified_snapshot' &&
            record.batchId.isEmpty &&
            !record.sourceStatus.contains('refund') &&
            !record.sourceStatus.contains('cancel'),
      ),
    ).where((aggregate) => aggregate.isValid).toList();
    final waitingAggregates = aggregateSellerPayouts(
      records.where(
        (record) =>
            record.eligibilityStatus == 'waiting_period' &&
            record.commissionDataQuality == 'verified_snapshot' &&
            record.settlementStatus == 'completed' &&
            !record.sourceStatus.contains('refund') &&
            !record.sourceStatus.contains('cancel') &&
            !const {'reversed', 'voided'}.contains(record.sourceStatus),
      ),
    );
    final waitingAmount = waitingAggregates.fold<double>(
      0,
      (total, aggregate) => total + aggregate.netTotal,
    );
    final nextEligibleDate = waitingAggregates
        .expand((aggregate) => aggregate.records)
        .map((record) => record.eligibilityDate)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (current, date) =>
              current == null || date.isBefore(current) ? date : current,
        );
    final nextEligibleSellers = nextEligibleDate == null
        ? 0
        : waitingAggregates
              .where(
                (aggregate) => aggregate.records.any(
                  (record) =>
                      record.eligibilityDate?.year == nextEligibleDate.year &&
                      record.eligibilityDate?.month == nextEligibleDate.month &&
                      record.eligibilityDate?.day == nextEligibleDate.day,
                ),
              )
              .length;
    final disabledReason = _selectedAggregateKeys.isEmpty
        ? aggregates.isEmpty
              ? 'No valid eligible sellers are available. Records may be waiting, blocked, batched, or require repair.'
              : 'Select at least one seller to create a batch.'
        : null;
    final selectable = aggregates;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
            children: [
              Checkbox(
                value:
                    selectable.isNotEmpty &&
                    selectable.every(
                      (aggregate) =>
                          _selectedAggregateKeys.contains(aggregate.key),
                    ),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedAggregateKeys.addAll(
                        selectable.map((aggregate) => aggregate.key),
                      );
                    } else {
                      _selectedAggregateKeys.clear();
                    }
                  });
                },
              ),
              Expanded(
                child: Text(
                  l10n.payoutSelectAllEligible,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: _busy || _selectedAggregateKeys.isEmpty
                    ? null
                    : () => _createBatch(aggregates),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.inventory_2_outlined),
                label: Text(l10n.payoutCreateBatch),
              ),
            ],
          ),
        ),
        if (disabledReason != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                disabledReason,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        Expanded(
          child: aggregates.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _EligibleEmptySummary(
                      eligibleSellerCount: aggregates.length,
                      waitingSellerCount: waitingAggregates.length,
                      waitingAmount: waitingAmount,
                      currency: waitingAggregates.isEmpty
                          ? 'TRY'
                          : waitingAggregates.first.currency,
                      nextEligibleDate: nextEligibleDate,
                      nextEligibleSellerCount: nextEligibleSellers,
                      onViewWaiting: () => _tabs.animateTo(2),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  itemCount: aggregates.length,
                  itemBuilder: (context, index) {
                    final aggregate = aggregates[index];
                    return _SellerAggregateCard(
                      aggregate: aggregate,
                      selected: _selectedAggregateKeys.contains(aggregate.key),
                      onSelected: aggregate.isValid
                          ? (selected) => setState(() {
                              if (selected) {
                                _selectedAggregateKeys.add(aggregate.key);
                              } else {
                                _selectedAggregateKeys.remove(aggregate.key);
                              }
                            })
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWaiting(List<PayoutOperationRecord> records) {
    final waiting = aggregateSellerPayouts(
      records.where(
        (record) =>
            record.eligibilityStatus == 'waiting_period' &&
            record.commissionDataQuality == 'verified_snapshot' &&
            record.settlementStatus == 'completed' &&
            !record.sourceStatus.contains('refund') &&
            !record.sourceStatus.contains('cancel') &&
            !const {'reversed', 'voided'}.contains(record.sourceStatus),
      ),
    );
    if (waiting.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noPayoutsFound));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: waiting.length,
      itemBuilder: (context, index) =>
          _WaitingSellerCard(aggregate: waiting[index]),
    );
  }

  Widget _buildPaid(List<PayoutOperationRecord> records) {
    final aggregates = aggregateSellerPayouts(
      records.where(
        (record) =>
            record.payoutStatus == 'paid' &&
            record.commissionDataQuality == 'verified_snapshot',
      ),
    );
    if (aggregates.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noPayoutsFound));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: aggregates
          .map(
            (aggregate) => _SellerAggregateCard(
              aggregate: aggregate,
              selected: false,
              onSelected: null,
            ),
          )
          .toList(),
    );
  }

  Widget _buildExceptions(List<PayoutOperationRecord> records) {
    final exceptions = records
        .where(
          (record) =>
              record.commissionDataQuality != 'verified_snapshot' ||
              (record.payoutStatus != 'paid' &&
                  record
                      .validationReasons(
                        allowedBatchId: record.batchId.isEmpty
                            ? null
                            : record.batchId,
                      )
                      .isNotEmpty) ||
              const {'hold', 'recovery_required'}.contains(record.payoutStatus),
        )
        .toList();
    if (exceptions.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.payoutNoExceptions),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: exceptions
          .map((record) => _ExceptionCard(record: record))
          .toList(),
    );
  }
}

class _FinanceOverviewTab extends StatelessWidget {
  const _FinanceOverviewTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('financeOperations')
          .doc('overview')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data() ?? const <String, dynamic>{};
        final available =
            (data['available'] as Map?)?.cast<String, dynamic>() ?? const {};
        final waiting =
            (data['waiting'] as Map?)?.cast<String, dynamic>() ?? const {};
        final blocked =
            (data['blocked'] as Map?)?.cast<String, dynamic>() ?? const {};
        final metrics = <(String, Object?, IconData)>[
          (
            l10n.financeEligibleSellers,
            data['eligibleSellerCount'] ?? 0,
            Icons.storefront_outlined,
          ),
          (
            l10n.financeEligibleRecords,
            available['count'] ?? 0,
            Icons.receipt_long_outlined,
          ),
          (
            l10n.payoutNetPayable,
            available['amount'] ?? 0,
            Icons.account_balance_wallet_outlined,
          ),
          (
            l10n.financeWaitingSellers,
            data['waitingSellerCount'] ?? 0,
            Icons.hourglass_top_outlined,
          ),
          (
            l10n.financeWaitingRecords,
            waiting['count'] ?? 0,
            Icons.schedule_outlined,
          ),
          (
            l10n.financeWaitingAmount,
            waiting['amount'] ?? 0,
            Icons.timelapse_outlined,
          ),
          (
            l10n.financeBlockedRecords,
            blocked['count'] ?? 0,
            Icons.block_outlined,
          ),
          (
            l10n.financeExceptionCount,
            data['exceptionCount'] ?? 0,
            Icons.warning_amber_outlined,
          ),
          (
            l10n.financeTodaySales,
            data['todaySales'] ?? 0,
            Icons.point_of_sale_outlined,
          ),
          (
            l10n.financeTodayCommission,
            data['todayCommission'] ?? 0,
            Icons.percent_outlined,
          ),
          (
            l10n.financeTodayRefunds,
            data['todayRefunds'] ?? 0,
            Icons.undo_outlined,
          ),
          (
            l10n.financeTodayEligible,
            data['todayEligible'] ?? 0,
            Icons.event_available_outlined,
          ),
          (
            l10n.financeTodayPaid,
            data['todayPaid'] ?? 0,
            Icons.payments_outlined,
          ),
          (
            l10n.financeOutstandingLiability,
            data['outstandingLiability'] ?? 0,
            Icons.account_balance_outlined,
          ),
          (
            l10n.financeMonthlyPlatformRevenue,
            data['monthlyPlatformRevenue'] ?? 0,
            Icons.trending_up_outlined,
          ),
          (
            l10n.financeTomorrowEligible,
            data['tomorrowBecomingEligible'] ?? 0,
            Icons.today_outlined,
          ),
          (
            l10n.financeNext7Days,
            data['next7DaysBecomingEligible'] ?? 0,
            Icons.date_range_outlined,
          ),
          (
            l10n.financeNext30Days,
            data['next30DaysBecomingEligible'] ?? 0,
            Icons.calendar_month_outlined,
          ),
          (
            l10n.financeEstimatedPayable,
            data['estimatedPayable'] ?? 0,
            Icons.query_stats_outlined,
          ),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700
                ? 3
                : constraints.maxWidth >= 420
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: metrics.map((metric) {
                    final (label, value, icon) = metric;
                    return SizedBox(
                      width: width,
                      child: Card(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 128),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, color: const Color(0xFF9E1B4F)),
                                const SizedBox(height: 14),
                                Text(
                                  value.toString(),
                                  style: const TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _EligibleEmptySummary extends StatelessWidget {
  const _EligibleEmptySummary({
    required this.eligibleSellerCount,
    required this.waitingSellerCount,
    required this.waitingAmount,
    required this.currency,
    required this.nextEligibleDate,
    required this.nextEligibleSellerCount,
    required this.onViewWaiting,
  });

  final int eligibleSellerCount;
  final int waitingSellerCount;
  final double waitingAmount;
  final String currency;
  final DateTime? nextEligibleDate;
  final int nextEligibleSellerCount;
  final VoidCallback onViewWaiting;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No eligible sellers right now',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Metric(
                  label: 'Eligible sellers',
                  value: '$eligibleSellerCount',
                ),
                _Metric(label: 'Waiting sellers', value: '$waitingSellerCount'),
                _Metric(
                  label: 'Total waiting amount',
                  value: '${waitingAmount.toStringAsFixed(2)} $currency',
                ),
                _Metric(
                  label: 'Next eligible payout date',
                  value: nextEligibleDate == null
                      ? '—'
                      : DateFormat('yyyy-MM-dd').format(nextEligibleDate!),
                ),
                _Metric(
                  label: 'Next sellers becoming eligible',
                  value: '$nextEligibleSellerCount',
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onViewWaiting,
              icon: const Icon(Icons.hourglass_top_outlined),
              label: const Text('View Waiting Sellers'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingSellerCard extends StatelessWidget {
  const _WaitingSellerCard({required this.aggregate});

  final SellerPayoutAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final eligibilityDates =
        aggregate.records
            .map((record) => record.eligibilityDate)
            .whereType<DateTime>()
            .toList()
          ..sort();
    final paymentDates =
        aggregate.records
            .map((record) => record.successfulPaymentAt)
            .whereType<DateTime>()
            .toList()
          ..sort();
    final nextDate = eligibilityDates.isEmpty ? null : eligibilityDates.first;
    final oldestPayment = paymentDates.isEmpty ? null : paymentDates.first;
    final nextDayRecords = nextDate == null
        ? const <PayoutOperationRecord>[]
        : aggregate.records
              .where(
                (record) =>
                    record.eligibilityDate?.year == nextDate.year &&
                    record.eligibilityDate?.month == nextDate.month &&
                    record.eligibilityDate?.day == nextDate.day,
              )
              .toList();
    final nextAmount = nextDayRecords.fold<double>(
      0,
      (total, record) => total + record.netAmount,
    );
    final daysRemaining = nextDate == null
        ? 0
        : (nextDate.difference(DateTime.now()).inHours / 24).ceil().clamp(
            0,
            21,
          );
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          aggregate.businessName.isEmpty
              ? l10n.payoutUnknownSeller
              : aggregate.businessName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${aggregate.sector} • ${maskIban(aggregate.iban)}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(
                label: l10n.financeWaitingAmount,
                value:
                    '${aggregate.netTotal.toStringAsFixed(2)} ${aggregate.currency}',
              ),
              _Metric(
                label: l10n.payoutIncludedOrders,
                value: aggregate.records.length.toString(),
              ),
              _Metric(
                label: l10n.financeNextEligibilityDate,
                value: nextDate == null ? '—' : dateFormat.format(nextDate),
              ),
              _Metric(
                label: l10n.financeDaysRemaining,
                value: daysRemaining.toString(),
              ),
              _Metric(
                label: l10n.financeOldestWaitingRecord,
                value: oldestPayment == null
                    ? '—'
                    : dateFormat.format(oldestPayment),
              ),
              _Metric(
                label: l10n.financeAmountEligibleNext,
                value: '${nextAmount.toStringAsFixed(2)} ${aggregate.currency}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final record in aggregate.records)
            ListTile(
              dense: true,
              title: Text(
                record.orderNumber.isEmpty
                    ? _sourceReference(record, l10n)
                    : record.orderNumber,
              ),
              subtitle: Text(
                record.eligibilityDate == null
                    ? l10n.payoutBlocked
                    : dateFormat.format(record.eligibilityDate!),
              ),
              trailing: record.commissionDataQuality == 'verified_snapshot'
                  ? Text(
                      '${record.netAmount.toStringAsFixed(2)} ${record.currency}',
                    )
                  : Text(
                      '${l10n.payoutCustomerPaid}: '
                      '${record.grossAmount.toStringAsFixed(2)} ${record.currency}\n'
                      '${l10n.payoutCommissionUnknown}\n'
                      '${l10n.payoutSellerNetNotCalculated}',
                      textAlign: TextAlign.end,
                    ),
            ),
        ],
      ),
    );
  }
}

class _OperationsToolbar extends StatefulWidget {
  const _OperationsToolbar({
    required this.controller,
    required this.onExport,
    required this.preset,
    required this.validBank,
    required this.onSearch,
    required this.onPreset,
    required this.onValidBank,
    required this.payoutStatus,
    required this.settlementStatus,
    required this.includedInBatch,
    required this.onPayoutStatus,
    required this.onSettlementStatus,
    required this.onIncludedInBatch,
    required this.onSeller,
    required this.onBank,
    required this.onMinimumAmount,
    required this.onMaximumAmount,
  });

  final TextEditingController controller;
  final VoidCallback onExport;
  final PayoutDatePreset? preset;
  final bool? validBank;
  final ValueChanged<String> onSearch;
  final ValueChanged<PayoutDatePreset?> onPreset;
  final ValueChanged<bool?> onValidBank;
  final String? payoutStatus;
  final String? settlementStatus;
  final bool? includedInBatch;
  final ValueChanged<String?> onPayoutStatus;
  final ValueChanged<String?> onSettlementStatus;
  final ValueChanged<bool?> onIncludedInBatch;
  final ValueChanged<String> onSeller;
  final ValueChanged<String> onBank;
  final ValueChanged<String> onMinimumAmount;
  final ValueChanged<String> onMaximumAmount;

  @override
  State<_OperationsToolbar> createState() => _OperationsToolbarState();
}

class _OperationsToolbarState extends State<_OperationsToolbar> {
  bool _filtersExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 360,
              child: TextField(
                controller: widget.controller,
                onChanged: widget.onSearch,
                decoration: InputDecoration(
                  hintText: l10n.searchPayoutsHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: widget.controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            widget.controller.clear();
                            widget.onSearch('');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: l10n.payoutDateFilter,
              onPressed: () =>
                  setState(() => _filtersExpanded = !_filtersExpanded),
              icon: Icon(
                _filtersExpanded ? Icons.filter_alt_off : Icons.filter_alt,
              ),
            ),
            FilledButton.icon(
              onPressed: widget.onExport,
              icon: const Icon(Icons.description_outlined),
              label: const Text('Export Finance Report'),
            ),
            if (_filtersExpanded) ...[
              DropdownButton<PayoutDatePreset?>(
                value: widget.preset,
                hint: Text(l10n.payoutDateFilter),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.allFilterLabel),
                  ),
                  DropdownMenuItem(
                    value: PayoutDatePreset.today,
                    child: Text(l10n.payoutToday),
                  ),
                  DropdownMenuItem(
                    value: PayoutDatePreset.yesterday,
                    child: Text(l10n.payoutYesterday),
                  ),
                  DropdownMenuItem(
                    value: PayoutDatePreset.thisWeek,
                    child: Text(l10n.payoutThisWeek),
                  ),
                  DropdownMenuItem(
                    value: PayoutDatePreset.lastWeek,
                    child: Text(l10n.payoutLastWeek),
                  ),
                  DropdownMenuItem(
                    value: PayoutDatePreset.thisMonth,
                    child: Text(l10n.payoutThisMonth),
                  ),
                  DropdownMenuItem(
                    value: PayoutDatePreset.custom,
                    child: Text(l10n.payoutCustomRange),
                  ),
                ],
                onChanged: widget.onPreset,
              ),
              FilterChip(
                label: Text(l10n.payoutValidBankOnly),
                selected: widget.validBank == true,
                onSelected: (selected) =>
                    widget.onValidBank(selected ? true : null),
              ),
              DropdownButton<String?>(
                value: widget.payoutStatus,
                hint: Text(l10n.payoutStatusFilter),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.allFilterLabel),
                  ),
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text(l10n.pendingStatusLabel),
                  ),
                  DropdownMenuItem(
                    value: 'ready',
                    child: Text(l10n.readyLabel),
                  ),
                  DropdownMenuItem(
                    value: 'paid',
                    child: Text(l10n.paidStatusLabel),
                  ),
                  DropdownMenuItem(
                    value: 'hold',
                    child: Text(l10n.payoutBlocked),
                  ),
                ],
                onChanged: widget.onPayoutStatus,
              ),
              DropdownButton<String?>(
                value: widget.settlementStatus,
                hint: Text(l10n.payoutSettlementFilter),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.allFilterLabel),
                  ),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text(l10n.completedStatusLabel),
                  ),
                  DropdownMenuItem(
                    value: 'processing',
                    child: Text(l10n.myOrdersProcessingStatus),
                  ),
                  DropdownMenuItem(
                    value: 'blocked',
                    child: Text(l10n.payoutBlocked),
                  ),
                ],
                onChanged: widget.onSettlementStatus,
              ),
              DropdownButton<bool?>(
                value: widget.includedInBatch,
                hint: Text(l10n.payoutBatchFilter),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.allFilterLabel),
                  ),
                  DropdownMenuItem(
                    value: true,
                    child: Text(l10n.payoutIncludedInBatch),
                  ),
                  DropdownMenuItem(
                    value: false,
                    child: Text(l10n.payoutNotIncludedInBatch),
                  ),
                ],
                onChanged: widget.onIncludedInBatch,
              ),
              _CompactFilterField(
                label: l10n.payoutSellerFilter,
                onChanged: widget.onSeller,
              ),
              _CompactFilterField(
                label: l10n.payoutBankFilter,
                onChanged: widget.onBank,
              ),
              _CompactFilterField(
                label: l10n.payoutMinimumAmount,
                numeric: true,
                onChanged: widget.onMinimumAmount,
              ),
              _CompactFilterField(
                label: l10n.payoutMaximumAmount,
                numeric: true,
                onChanged: widget.onMaximumAmount,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactFilterField extends StatelessWidget {
  const _CompactFilterField({
    required this.label,
    required this.onChanged,
    this.numeric = false,
  });

  final String label;
  final ValueChanged<String> onChanged;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: TextField(
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _SellerAggregateCard extends StatelessWidget {
  const _SellerAggregateCard({
    required this.aggregate,
    required this.selected,
    required this.onSelected,
  });

  final SellerPayoutAggregate aggregate;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  String _date(DateTime? value) =>
      value == null ? '—' : DateFormat('yyyy-MM-dd').format(value);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = aggregate.businessName.isNotEmpty
        ? aggregate.businessName
        : aggregate.legalBusinessName.isNotEmpty
        ? aggregate.legalBusinessName
        : l10n.payoutUnknownSeller;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Checkbox(
          value: selected,
          onChanged: onSelected == null
              ? null
              : (value) => onSelected!(value == true),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            _ValidationBadge(valid: aggregate.isValid),
          ],
        ),
        subtitle: Text(
          '${aggregate.businessId} • ${maskIban(aggregate.iban)} • ${aggregate.bankName.isEmpty ? l10n.payoutBankMissing : aggregate.bankName}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(
                label: l10n.payoutIncludedOrders,
                value: aggregate.records.length.toString(),
              ),
              _Metric(
                label: l10n.payoutPeriod,
                value:
                    '${_date(aggregate.earliestDate)} – ${_date(aggregate.latestDate)}',
              ),
              _Metric(
                label: l10n.payoutGrossTotal,
                value:
                    '${aggregate.grossTotal.toStringAsFixed(2)} ${aggregate.currency}',
              ),
              _Metric(
                label: l10n.payoutCommissionTotal,
                value:
                    '${aggregate.commissionTotal.toStringAsFixed(2)} ${aggregate.currency}',
              ),
              _Metric(
                label: l10n.payoutNetPayable,
                value:
                    '${aggregate.netTotal.toStringAsFixed(2)} ${aggregate.currency}',
                emphasize: true,
              ),
            ],
          ),
          if (!aggregate.isValid) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                aggregate.validationReasons
                    .map((reason) => _reasonLabel(reason, l10n))
                    .join(' • '),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Divider(height: 24),
          ...aggregate.records.map(
            (record) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_outlined, size: 20),
              title: Text(
                record.orderNumber.isNotEmpty
                    ? record.orderNumber
                    : _sourceReference(record, l10n),
              ),
              subtitle: Text(
                record.commissionDataQuality == 'verified_snapshot'
                    ? '${l10n.payoutValid} • ${record.normalizedFinancialStatus}'
                    : '${l10n.payoutCommissionUnknown} • ${l10n.payoutBlocked}',
              ),
              trailing: SizedBox(
                width: 230,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _SmallValue(
                      label: 'Customer Paid',
                      value: _money(record.grossAmount, record.currency),
                    ),
                    _SmallValue(
                      label: 'Commission',
                      value: _money(record.commissionAmount, record.currency),
                    ),
                    _SmallValue(
                      label: 'Seller Net',
                      value: record.commissionDataQuality == 'verified_snapshot'
                          ? _money(record.netAmount, record.currency)
                          : 'NOT CALCULATED',
                    ),
                    _SmallValue(
                      label: 'Waiting Days',
                      value: '${record.waitingDays}',
                    ),
                    _SmallValue(
                      label: 'Eligibility',
                      value: _formatDateValue(record.eligibilityDate),
                    ),
                    _SmallValue(
                      label: 'Settlement',
                      value: record.settlementStatus,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutBatchesTab extends StatelessWidget {
  const _PayoutBatchesTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('payoutBatches')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            '[FinanceOps] payoutBatches query failed: '
            'collection=payoutBatches orderBy=createdAt code=${_firebaseErrorCode(snapshot.error)} '
            'error=${snapshot.error}',
          );
          return Center(child: Text(l10n.payoutLoadFailed));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return Center(child: Text(l10n.payoutNoBatches));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs
              .map((doc) => _BatchCard(batchId: doc.id, data: doc.data()))
              .toList(),
        );
      },
    );
  }
}

class _BatchCard extends StatefulWidget {
  const _BatchCard({required this.batchId, required this.data});

  final String batchId;
  final Map<String, dynamic> data;

  @override
  State<_BatchCard> createState() => _BatchCardState();
}

class _BatchCardState extends State<_BatchCard> {
  bool _busy = false;

  Future<void> _transition(
    String callable, {
    Map<String, dynamic> data = const {},
  }) async {
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable(callable).call({'batchId': widget.batchId, ...data});
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.payoutOperationFailed(error.message ?? ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final notes = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.financeRejectBatch),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: l10n.note),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (notes != null) {
      await _transition('rejectPayoutBatch', data: {'approvalNotes': notes});
    }
  }

  Future<void> _cancel() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.cancel),
          content: TextField(
            controller: controller,
            maxLines: 2,
            decoration: InputDecoration(labelText: l10n.note),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (reason != null) {
      await _transition('cancelPayoutBatch', data: {'reason': reason});
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final status = (widget.data['status'] ?? '').toString();
      final callable = status == 'approved'
          ? 'exportPayoutBatch'
          : 'downloadPayoutBatchExport';
      final response = await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable(callable).call({'batchId': widget.batchId});
      final data = Map<String, dynamic>.from(response.data as Map);
      if (!mounted) return;
      await _showExportDialog(data, generated: callable == 'exportPayoutBatch');
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.payoutOperationFailed(error.message ?? ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _regenerateExport() async {
    setState(() => _busy = true);
    try {
      final response = await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('exportPayoutBatch').call({'batchId': widget.batchId});
      final data = Map<String, dynamic>.from(response.data as Map);
      if (!mounted) return;
      await _showExportDialog(data, generated: true);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.payoutOperationFailed(error.message ?? ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadExport({required Map<String, dynamic> data}) async {
    final fileName = (data['fileName'] ?? 'payout_batch.xlsx').toString();
    final url = (data['downloadUrl'] ?? '').toString();
    if (url.isEmpty) throw StateError('Export download URL is missing.');
    String? path;
    if (kIsWeb) {
      path = await downloadPayoutUrl(url: url, fileName: fileName);
    } else {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Export download failed (${response.statusCode}).');
      }
      path = await downloadPayoutBytes(
        bytes: response.bodyBytes,
        fileName: fileName,
        contentType:
            (data['contentType'] ??
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
                .toString(),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null ? 'Browser download started.' : 'Saved to $path',
        ),
      ),
    );
  }

  Future<void> _shareExport(Map<String, dynamic> data) async {
    final url = (data['downloadUrl'] ?? '').toString();
    final fileName = (data['fileName'] ?? 'payout_batch.xlsx').toString();
    if (url.isEmpty) throw StateError('Export download URL is missing.');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Export download failed (${response.statusCode}).');
    }
    await Share.shareXFiles([
      XFile.fromData(
        response.bodyBytes,
        mimeType: data['contentType'],
        name: fileName,
      ),
    ]);
  }

  Future<void> _runExportAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export operation failed: $error')),
      );
    }
  }

  Future<void> _showExportDialog(
    Map<String, dynamic> data, {
    required bool generated,
  }) async {
    final generatedAt = widget.data['exportedAt'] ?? data['generatedAt'];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Generated XLSX'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ExportDetail(label: 'File', value: '${data['fileName'] ?? '—'}'),
              _ExportDetail(
                label: 'File size',
                value: '${data['byteLength'] ?? '—'} bytes',
              ),
              _ExportDetail(
                label: 'Generation time',
                value: _formatDateValue(generatedAt ?? DateTime.now()),
              ),
              _ExportDetail(
                label: 'Storage path',
                value:
                    (data['storagePath'] ??
                            widget.data['exportStoragePath'] ??
                            '—')
                        .toString(),
              ),
              _ExportDetail(
                label: 'Generated by',
                value: (data['generatedBy'] ?? widget.data['exportedBy'] ?? '—')
                    .toString(),
              ),
              _ExportDetail(
                label: 'Download URL',
                value: (data['downloadUrl'] ?? '—').toString(),
              ),
              if (generated)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'The batch is now exported and ready for processing.',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (generated)
            OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _regenerateExport();
              },
              child: const Text('Regenerate'),
            ),
          if (!kIsWeb)
            TextButton(
              onPressed: () => _runExportAction(() => _shareExport(data)),
              child: const Text('Share'),
            ),
          FilledButton.icon(
            onPressed: () =>
                _runExportAction(() => _downloadExport(data: data)),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download XLSX'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _preview() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('payoutBatches')
        .doc(widget.batchId)
        .collection('items')
        .get();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Preview ${widget.data['batchNumber'] ?? widget.batchId}'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              children: snapshot.docs
                  .map((doc) => _PreviewSellerCard(data: doc.data()))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _auditHistory() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('financialEvents')
        .where('sourceCollection', isEqualTo: 'payoutBatches')
        .where('sourceDocument', isEqualTo: widget.batchId)
        .limit(100)
        .get();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Audit History'),
        content: SizedBox(
          width: 620,
          child: snapshot.docs.isEmpty
              ? const Text('No audit events found.')
              : ListView(
                  shrinkWrap: true,
                  children: snapshot.docs.map((doc) {
                    final data = doc.data();
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text((data['eventType'] ?? 'event').toString()),
                      subtitle: Text(
                        '${data['previousState'] ?? '—'} → ${data['newState'] ?? '—'}\n'
                        '${data['reason'] ?? ''}',
                      ),
                      trailing: Text(_formatDateValue(data['occurredAt'])),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _markWholePaid() async {
    final controller = TextEditingController();
    final reference = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.markPaid),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: l10n.bankTransferReference),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (reference == null) return;
    await _transition(
      'markPayoutBatchPaid',
      data: {
        'paymentReference': reference,
        'paymentDate': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = (widget.data['status'] ?? '').toString();
    Widget? action;
    if (_busy) {
      action = const CircularProgressIndicator();
    } else if (status == 'draft') {
      action = Wrap(
        spacing: 6,
        children: [
          OutlinedButton(onPressed: _cancel, child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => _transition('submitPayoutBatchForReview'),
            child: Text(l10n.financeSendForReview),
          ),
        ],
      );
    } else if (status == 'finance_review') {
      action = Wrap(
        spacing: 6,
        children: [
          TextButton(onPressed: _reject, child: Text(l10n.financeRejectBatch)),
          FilledButton(
            onPressed: () => _transition('approvePayoutBatch'),
            child: Text(l10n.financeApproveBatch),
          ),
        ],
      );
    } else if (status == 'approved') {
      action = Wrap(
        spacing: 6,
        children: [
          OutlinedButton.icon(
            onPressed: _preview,
            icon: const Icon(Icons.preview_outlined),
            label: const Text('Preview'),
          ),
          FilledButton.icon(
            onPressed: _export,
            icon: const Icon(Icons.file_download_outlined),
            label: Text(l10n.payoutExportXlsx),
          ),
        ],
      );
    } else if (const {
      'exported',
      'processing',
      'partially_paid',
      'failed',
      'paid',
    }.contains(status)) {
      action = Wrap(
        spacing: 6,
        children: [
          IconButton(
            tooltip: l10n.payoutExportXlsx,
            onPressed: _export,
            icon: const Icon(Icons.download_outlined),
          ),
          if (status == 'exported')
            FilledButton(
              onPressed: () => _transition('markPayoutBatchProcessing'),
              child: Text(l10n.financeStartProcessing),
            ),
          if (const {'processing', 'partially_paid'}.contains(status))
            FilledButton(onPressed: _markWholePaid, child: Text(l10n.markPaid)),
        ],
      );
    } else if (status == 'paid') {
      action = const Icon(Icons.check_circle, color: Colors.green);
    }
    final createdAt = _formatDateValue(widget.data['createdAt']);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          (widget.data['batchNumber'] ?? widget.batchId).toString(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '$status • ${widget.data['sellerCount'] ?? 0} ${l10n.payoutSellers} • ${widget.data['netTotal'] ?? 0} ${widget.data['currency'] ?? 'TRY'}',
        ),
        trailing: action,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _Metric(label: 'Created At', value: createdAt),
                    _Metric(
                      label: 'Created By',
                      value:
                          (widget.data['createdBy'] ??
                                  widget.data['adminUid'] ??
                                  '—')
                              .toString(),
                    ),
                    _Metric(
                      label: 'Seller Count',
                      value: '${widget.data['sellerCount'] ?? 0}',
                    ),
                    _Metric(
                      label: 'Order Count',
                      value:
                          '${widget.data['payoutRecordCount'] ?? widget.data['orderCount'] ?? 0}',
                    ),
                    _Metric(
                      label: 'Gross',
                      value:
                          '${widget.data['grossTotal'] ?? 0} ${widget.data['currency'] ?? 'TRY'}',
                    ),
                    _Metric(
                      label: 'Commission',
                      value:
                          '${widget.data['commissionTotal'] ?? 0} ${widget.data['currency'] ?? 'TRY'}',
                    ),
                    _Metric(
                      label: 'Net',
                      value:
                          '${widget.data['netTotal'] ?? 0} ${widget.data['currency'] ?? 'TRY'}',
                      emphasize: true,
                    ),
                    _Metric(
                      label: 'Currency',
                      value: '${widget.data['currency'] ?? 'TRY'}',
                    ),
                    _Metric(label: 'Status', value: status),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _preview,
                      icon: const Icon(Icons.preview_outlined),
                      label: const Text('Preview'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _auditHistory,
                      icon: const Icon(Icons.history),
                      label: const Text('Audit History'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('payoutBatches')
                .doc(widget.batchId)
                .collection('items')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              return Column(
                children: snapshot.data!.docs
                    .map(
                      (doc) => _BatchItemTile(
                        batchId: widget.batchId,
                        itemId: doc.id,
                        data: doc.data(),
                        batchStatus: status,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BatchItemTile extends StatelessWidget {
  const _BatchItemTile({
    required this.batchId,
    required this.itemId,
    required this.data,
    required this.batchStatus,
  });

  final String batchId;
  final String itemId;
  final Map<String, dynamic> data;
  final String batchStatus;

  Future<void> _markPaid(BuildContext context) async {
    final referenceController = TextEditingController();
    final noteController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.confirmPayout),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText((data['iban'] ?? '').toString()),
              TextField(
                controller: referenceController,
                decoration: InputDecoration(
                  labelText: l10n.bankTransferReference,
                ),
              ),
              TextField(
                controller: noteController,
                decoration: InputDecoration(labelText: l10n.note),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (referenceController.text.trim().isEmpty) return;
                Navigator.pop(context, {
                  'reference': referenceController.text.trim(),
                  'note': noteController.text.trim(),
                });
              },
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
    if (result == null || !context.mounted) return;
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('markPayoutBatchItemPaid').call({
        'batchId': batchId,
        'itemId': itemId,
        'paymentReference': result['reference'],
        'note': result['note'],
        'paymentDate': DateTime.now().toIso8601String(),
      });
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.payoutOperationFailed(error.message ?? ''),
          ),
        ),
      );
    }
  }

  Future<void> _markFailed(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.financeMarkFailed),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.financeFailureReason),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (reason == null || !context.mounted) return;
    await FirebaseFunctions.instanceFor(region: 'europe-west3')
        .httpsCallable('markPayoutBatchItemFailed')
        .call({'batchId': batchId, 'itemId': itemId, 'failureReason': reason});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = (data['status'] ?? '').toString();
    return ListTile(
      title: Text(
        (data['businessName'] ?? data['legalBusinessName'] ?? '').toString(),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${maskIban((data['iban'] ?? '').toString())} • ${data['bankName'] ?? ''} • ${data['payoutCount'] ?? 0} ${l10n.payoutIncludedOrders}',
      ),
      trailing: status == 'paid'
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                Text((data['paymentReference'] ?? '').toString()),
              ],
            )
          : Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed:
                      const {
                        'exported',
                        'processing',
                        'partially_paid',
                        'failed',
                      }.contains(batchStatus)
                      ? () => _markFailed(context)
                      : null,
                  child: Text(l10n.financeMarkFailed),
                ),
                FilledButton(
                  onPressed:
                      const {
                        'exported',
                        'processing',
                        'partially_paid',
                        'failed',
                      }.contains(batchStatus)
                      ? () => _markPaid(context)
                      : null,
                  child: Text(l10n.markPaid),
                ),
              ],
            ),
    );
  }
}

class _ExceptionCard extends StatelessWidget {
  const _ExceptionCard({required this.record});

  final PayoutOperationRecord record;

  Future<void> _retrySettlement(BuildContext context) async {
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('retrySettlement').call({
        'sector': record.sector,
        'payableId': record.sourceDocumentId,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settlement retry requested.')),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Settlement retry failed.')),
      );
    }
  }

  void _openSnapshot(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Financial Snapshot'),
        content: SelectableText(
          const JsonEncoder.withIndent('  ').convert({
            'sourceCollection': record.sourceCollection,
            'sourceDocumentId': record.sourceDocumentId,
            'customerPaid': record.grossAmount,
            'commission': record.commissionAmount,
            'sellerNet': record.commissionDataQuality == 'verified_snapshot'
                ? record.netAmount
                : 'NOT CALCULATED',
            'commissionDataQuality': record.commissionDataQuality,
            'financialStatus': record.financialStatus,
            'settlementStatus': record.settlementStatus,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reasons = record.validationReasons();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    record.businessName.isNotEmpty
                        ? record.businessName
                        : l10n.payoutUnknownSeller,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(record.settlementStatus.toUpperCase()),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric(
                  label: 'Customer Paid',
                  value: _money(record.grossAmount, record.currency),
                ),
                _Metric(
                  label: 'Commission',
                  value: record.commissionDataQuality == 'verified_snapshot'
                      ? _money(record.commissionAmount, record.currency)
                      : 'UNKNOWN',
                ),
                _Metric(
                  label: 'Seller Net',
                  value: record.commissionDataQuality == 'verified_snapshot'
                      ? _money(record.netAmount, record.currency)
                      : 'NOT CALCULATED',
                ),
                _Metric(label: 'Settlement', value: 'BLOCKED'),
                _Metric(
                  label: 'Reason',
                  value: reasons.map((e) => _reasonLabel(e, l10n)).join(', '),
                ),
                _Metric(
                  label: 'Required Action',
                  value: 'Repair financial snapshot',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: record.sourceCollection == 'sellerOrders'
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailPage(
                              sellerOrderId: record.sourceDocumentId,
                            ),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Open Order'),
                ),
                OutlinedButton.icon(
                  onPressed: record.businessId.isEmpty
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BusinessAdminDetailPage(
                              businessId: record.businessId,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Open Seller'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openSnapshot(context),
                  icon: const Icon(Icons.account_balance_outlined),
                  label: const Text('Open Financial Snapshot'),
                ),
                FilledButton.icon(
                  onPressed:
                      record.sourceDocumentId.isEmpty || record.sector.isEmpty
                      ? null
                      : () => _retrySettlement(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Settlement'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${record.sourceCollection}/${record.sourceDocumentId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasize
            ? Theme.of(context).colorScheme.primaryContainer
            : const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SmallValue extends StatelessWidget {
  const _SmallValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    );
  }
}

class _ExportDetail extends StatelessWidget {
  const _ExportDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SelectableText('$label: $value'),
    );
  }
}

class _PreviewSellerCard extends StatelessWidget {
  const _PreviewSellerCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final warnings =
        (data['validationReasons'] as List?)
            ?.map((value) => value.toString())
            .toList() ??
        const <String>[];
    final currency = (data['currency'] ?? 'TRY').toString();
    final included =
        (data['payoutCount'] ?? (data['payoutIndexIds'] as List?)?.length ?? 0)
            .toString();
    final excluded = (data['excludedOrderCount'] ?? 0).toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (data['businessName'] ?? data['businessId'] ?? 'Seller')
                  .toString(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric(
                  label: 'Customer Paid',
                  value: '${data['grossTotal'] ?? 0} $currency',
                ),
                _Metric(
                  label: 'Platform Commission',
                  value: '${data['commissionTotal'] ?? 0} $currency',
                ),
                _Metric(
                  label: 'Seller Net',
                  value: '${data['netTotal'] ?? 0} $currency',
                ),
                _Metric(
                  label: 'Waiting Period',
                  value: _formatDateValue(data['periodStart']),
                ),
                _Metric(label: 'Included Orders', value: included),
                _Metric(label: 'Excluded Orders', value: excluded),
                _Metric(
                  label: 'Commission Unknown',
                  value: warnings.contains('commission_unknown') ? 'YES' : 'NO',
                ),
                _Metric(
                  label: 'Warnings',
                  value: warnings.isEmpty ? 'None' : warnings.join(', '),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationBadge extends StatelessWidget {
  const _ValidationBadge({required this.valid});

  final bool valid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Chip(
      avatar: Icon(
        valid ? Icons.check_circle : Icons.error_outline,
        size: 16,
        color: valid ? Colors.green : Colors.red,
      ),
      label: Text(valid ? l10n.payoutValid : l10n.payoutBlocked),
      visualDensity: VisualDensity.compact,
    );
  }
}

String _reasonLabel(String reason, AppLocalizations l10n) {
  return switch (reason) {
    'missing_business' => l10n.payoutMissingBusiness,
    'missing_account_holder' => l10n.payoutMissingAccountHolder,
    'missing_iban' => l10n.payoutMissingIban,
    'invalid_iban' => l10n.payoutInvalidIban,
    'missing_bank_name' => l10n.payoutMissingBankName,
    'non_positive_amount' => l10n.payoutNonPositiveAmount,
    'settlement_incomplete' => l10n.payoutSettlementIncomplete,
    'refunded_or_cancelled' => l10n.payoutRefundedOrCancelled,
    'already_batched' => l10n.payoutAlreadyBatched,
    'already_paid' => l10n.payoutAlreadyPaid,
    'payout_blocked' => l10n.payoutBlocked,
    'on_hold' => l10n.payoutBlocked,
    'eligibility_blocked' => l10n.payoutBlocked,
    'waiting_period' => l10n.financeWaitingTab,
    'not_eligible' => l10n.payoutIneligible,
    'unsupported_currency' => l10n.payoutUnsupportedCurrency,
    'commission_unknown' => l10n.payoutCommissionUnknown,
    _ => l10n.payoutIneligible,
  };
}

String _money(double value, String currency) =>
    '${value.toStringAsFixed(2)} $currency';

String _formatDateValue(Object? value) {
  if (value is Timestamp) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toDate());
  }
  if (value is DateTime) return DateFormat('yyyy-MM-dd HH:mm').format(value);
  if (value == null || value is Map || value.toString().trim().isEmpty) {
    return '—';
  }
  final parsed = DateTime.tryParse(value.toString());
  return parsed == null
      ? value.toString()
      : DateFormat('yyyy-MM-dd HH:mm').format(parsed);
}

bool _hasValidDateValue(Object? value) {
  if (value is Timestamp) return true;
  if (value is DateTime) return true;
  if (value == null || value is Map) return false;
  return DateTime.tryParse(value.toString()) != null;
}

String _sourceReference(PayoutOperationRecord record, AppLocalizations l10n) {
  final prefix = switch (record.sourceCollection) {
    'sellerOrders' => l10n.sellerFinanceOrders,
    'vet_appointments' ||
    'groomy_appointments' => l10n.sellerFinanceAppointments,
    'hotel_bookings' => l10n.sellerFinanceBookings,
    'pet_taxi_bookings' => l10n.sellerFinanceRides,
    _ => l10n.payoutPeriod,
  };
  return prefix;
}

class _FinanceReportConfigDialog extends StatefulWidget {
  const _FinanceReportConfigDialog();

  @override
  State<_FinanceReportConfigDialog> createState() =>
      _FinanceReportConfigDialogState();
}

class _FinanceReportConfigDialogState
    extends State<_FinanceReportConfigDialog> {
  static const _statusOptions = <String>[
    'waiting',
    'eligible',
    'blocked',
    'requires_repair',
    'batched',
    'processing',
    'paid',
    'refunded',
    'cancelled',
  ];

  final _sellerController = TextEditingController();
  final _selectedStatuses = <String>{..._statusOptions};
  String _dateRange = 'all';
  DateTimeRange? _customRange;
  String _sector = 'all';
  String _currency = 'all';
  String _language = 'both';
  String _documentType = 'both';

  @override
  void dispose() {
    _sellerController.dispose();
    super.dispose();
  }

  Future<void> _chooseDateRange() async {
    final now = DateTime.now();
    DateTimeRange? range;
    if (_dateRange == 'today') {
      range = DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    } else if (_dateRange == 'week') {
      final start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      range = DateTimeRange(start: start, end: now);
    } else if (_dateRange == 'month') {
      range = DateTimeRange(start: DateTime(now.year, now.month), end: now);
    } else if (_dateRange == 'custom') {
      range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: now.add(const Duration(days: 1)),
        initialDateRange: _customRange,
      );
    }
    if (!mounted) return;
    setState(() => _customRange = range);
  }

  void _submit() {
    DateTime? start;
    DateTime? end;
    if (_dateRange == 'today' || _dateRange == 'week' || _dateRange == 'month' || _dateRange == 'custom') {
      if (_customRange != null) {
        start = _customRange!.start;
        end = _customRange!.end;
      } else if (_dateRange == 'today' || _dateRange == 'week' || _dateRange == 'month') {
        _chooseDateRange();
        return;
      }
    }
    Navigator.pop(context, {
      'statuses': _selectedStatuses.toList(),
      'sectors': _sector == 'all' ? <String>[] : [_sector],
      'businessId': _sellerController.text.trim(),
      'currency': _currency,
      'languages': _language == 'both' ? ['tr', 'en'] : [_language],
      'documentTypes': _documentType == 'both'
          ? ['accountant', 'internal']
          : [_documentType],
      'start': start?.toIso8601String(),
      'end': end?.toIso8601String(),
      'dateRangeLabel': _dateRange,
      'filtersLabel': 'statuses=${_selectedStatuses.length}, sector=$_sector',
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Finance Report'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _dateRange,
                decoration: const InputDecoration(labelText: 'Date range'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All records')),
                  DropdownMenuItem(value: 'today', child: Text('Today')),
                  DropdownMenuItem(value: 'week', child: Text('This week')),
                  DropdownMenuItem(value: 'month', child: Text('This month')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom range')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _dateRange = value);
                  if (value != 'all') _chooseDateRange();
                },
              ),
              const SizedBox(height: 12),
              const Text('Statuses'),
              Wrap(
                spacing: 6,
                children: _statusOptions
                    .map(
                      (status) => FilterChip(
                        label: Text(status.replaceAll('_', ' ')),
                        selected: _selectedStatuses.contains(status),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _selectedStatuses.add(status);
                          } else {
                            _selectedStatuses.remove(status);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
              DropdownButtonFormField<String>(
                initialValue: _sector,
                decoration: const InputDecoration(labelText: 'Sector'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All sectors')),
                  DropdownMenuItem(value: 'petshop', child: Text('Pet Shop')),
                  DropdownMenuItem(value: 'vet', child: Text('Vet')),
                  DropdownMenuItem(value: 'groomy', child: Text('Groomy')),
                  DropdownMenuItem(value: 'hotel', child: Text('Hotel')),
                  DropdownMenuItem(value: 'taxi', child: Text('Taxi')),
                ],
                onChanged: (value) => setState(() => _sector = value ?? 'all'),
              ),
              TextField(
                controller: _sellerController,
                decoration: const InputDecoration(
                  labelText: 'Seller business ID (optional)',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All currencies')),
                  DropdownMenuItem(value: 'TRY', child: Text('TRY')),
                ],
                onChanged: (value) => setState(() => _currency = value ?? 'all'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: const InputDecoration(labelText: 'Report language'),
                items: const [
                  DropdownMenuItem(value: 'tr', child: Text('Turkish')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'both', child: Text('Both')),
                ],
                onChanged: (value) => setState(() => _language = value ?? 'both'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _documentType,
                decoration: const InputDecoration(labelText: 'Document type'),
                items: const [
                  DropdownMenuItem(value: 'accountant', child: Text('Accountant Copy')),
                  DropdownMenuItem(value: 'internal', child: Text('Internal Records Copy')),
                  DropdownMenuItem(value: 'both', child: Text('Both')),
                ],
                onChanged: (value) => setState(() => _documentType = value ?? 'both'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Generate Reports'),
        ),
      ],
    );
  }
}

class _FinanceReportFileTile extends StatelessWidget {
  const _FinanceReportFileTile({
    required this.file,
    required this.onDownload,
    required this.onShare,
  });

  final Map<String, dynamic> file;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final language = '${file['language'] ?? ''}'.toLowerCase();
    final isTurkish = language == 'tr';
    final generatedAt = file['generatedAt'];
    final generatedAtText = _hasValidDateValue(generatedAt)
        ? _formatDateValue(generatedAt)
        : (isTurkish
              ? 'Oluşturulma zamanı mevcut değil'
              : 'Generation time unavailable');
    final size = int.tryParse('${file['fileSize'] ?? 0}') ?? 0;
    final reportTitle = isTurkish
        ? 'Türkçe Muhasebe Kopyası'
        : 'English Internal Records Copy';
    return ListTile(
      leading: const Icon(Icons.table_chart_outlined),
      title: Text(reportTitle),
      subtitle: Text(
        '${file['fileName'] ?? 'Finance report'}\n'
        '${file['language'] ?? ''} • ${(size / 1024).toStringAsFixed(1)} KB\n'
        '${isTurkish ? 'Oluşturulma zamanı' : 'Generated at'}: $generatedAtText',
      ),
      isThreeLine: true,
      trailing: Wrap(
        spacing: 4,
        children: [
          if (onShare != null)
            IconButton(
              tooltip: 'Share',
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined),
            ),
          IconButton(
            tooltip: 'Download',
            onPressed: onDownload,
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      onTap: () => showDialog<void>(
        context: context,
        builder: (detailsContext) => AlertDialog(
          title: Text(isTurkish ? 'Teknik ayrıntılar' : 'Technical details'),
          content: SelectableText(
            '${isTurkish ? 'Depolama yolu' : 'Storage path'}: ${file['storagePath'] ?? '—'}\n'
            '${isTurkish ? 'Denetim özeti' : 'Checksum'}: ${file['checksum'] ?? '—'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(detailsContext),
              child: Text(isTurkish ? 'Kapat' : 'Close'),
            ),
          ],
        ),
      ),
    );
  }
}
