import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:barky_matches_fixed/services/marketplace_invoice_service.dart';

class MarketplaceInvoicePanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final String collectionName;
  final String transactionId;
  final bool businessActions;
  final bool userActions;
  final bool compact;

  const MarketplaceInvoicePanel({
    super.key,
    required this.data,
    required this.collectionName,
    required this.transactionId,
    this.businessActions = false,
    this.userActions = false,
    this.compact = false,
  });

  @override
  State<MarketplaceInvoicePanel> createState() =>
      _MarketplaceInvoicePanelState();
}

class _MarketplaceInvoicePanelState extends State<MarketplaceInvoicePanel> {
  final _service = MarketplaceInvoiceService();
  final _invoiceNumberController = TextEditingController();
  final _invoiceDateController = TextEditingController();
  final _noteController = TextEditingController();
  final _rejectionReasonController = TextEditingController();

  String _invoiceSystem = 'eArsiv';
  String _invoiceType = 'individual';
  bool _uploading = false;
  bool _reviewing = false;

  @override
  void initState() {
    super.initState();
    final invoice = _invoice;
    _invoiceNumberController.text =
        (invoice['invoiceNumber'] ?? widget.data['invoiceNumber'] ?? '')
            .toString();
    _invoiceDateController.text =
        (invoice['invoiceDate'] ?? widget.data['invoiceDate'] ?? '')
            .toString()
            .split('T')
            .first;
    final system =
        (invoice['invoiceSystem'] ?? widget.data['invoiceSystem'] ?? '')
            .toString();
    if (system.isNotEmpty) _invoiceSystem = system;
    final type = (invoice['invoiceType'] ?? widget.data['invoiceType'] ?? '')
        .toString();
    if (type.isNotEmpty) _invoiceType = type;
    _noteController.text = (invoice['note'] ?? '').toString();
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _invoiceDateController.dispose();
    _noteController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _invoice => _asMap(widget.data['invoice']);

  String get _status =>
      (_invoice['status'] ??
              _asMap(widget.data['documents'])['invoiceStatus'] ??
              widget.data['invoiceStatus'] ??
              'pending_upload')
          .toString()
          .toLowerCase();

  String get _invoiceUrl =>
      (_invoice['invoiceUrl'] ??
              _invoice['pdfUrl'] ??
              widget.data['invoiceUrl'] ??
              '')
          .toString();

  bool get _hasInvoiceFile => _invoiceUrl.trim().isNotEmpty;

  Future<void> _pickDate() async {
    final parsed = DateTime.tryParse(_invoiceDateController.text);
    final selected = await showDatePicker(
      context: context,
      initialDate: parsed ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    _invoiceDateController.text = DateFormat('yyyy-MM-dd').format(selected);
  }

  Future<void> _upload() async {
    if (_uploading) return;
    if (_invoiceNumberController.text.trim().isEmpty ||
        _invoiceDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice number and date are required')),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      await _service.uploadInvoice(
        collectionName: widget.collectionName,
        transactionId: widget.transactionId,
        invoiceNumber: _invoiceNumberController.text,
        invoiceDate: _invoiceDateController.text,
        invoiceSystem: _invoiceSystem,
        invoiceType: _invoiceType,
        note: _noteController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice uploaded successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invoice upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _review(String status) async {
    if (_reviewing) return;
    setState(() => _reviewing = true);
    try {
      await _service.reviewInvoice(
        collectionName: widget.collectionName,
        transactionId: widget.transactionId,
        status: status,
        rejectionReason: _rejectionReasonController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invoice $status')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invoice review failed: $e')));
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Future<void> _openInvoice() async {
    final uri = Uri.tryParse(_invoiceUrl);
    if (uri == null) return;
    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot open invoice file')));
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final invoiceNumber =
        (_invoice['invoiceNumber'] ?? widget.data['invoiceNumber'] ?? '-')
            .toString();
    final invoiceDate =
        (_invoice['invoiceDate'] ?? widget.data['invoiceDate'] ?? '-')
            .toString()
            .split('T')
            .first;
    final invoiceSystem =
        (_invoice['invoiceSystem'] ?? widget.data['invoiceSystem'] ?? '-')
            .toString();
    final fileName =
        (_invoice['invoiceFileName'] ?? widget.data['invoiceFileName'] ?? '')
            .toString();
    final deadline =
        (_invoice['uploadDeadlineAt'] ??
                _asMap(widget.data['deadlines'])['invoiceUploadDeadlineAt'] ??
                widget.data['invoiceDeadline'] ??
                '')
            .toString();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: widget.compact ? 8 : 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invoice', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _meta('Status', _label(_status)),
          if (deadline.isNotEmpty) _meta('Deadline', _formatDate(deadline)),
          _meta('System', invoiceSystem),
          _meta('Number', invoiceNumber),
          _meta('Date', invoiceDate),
          if (fileName.isNotEmpty) _meta('File', fileName),
          if (_hasInvoiceFile) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openInvoice,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open invoice'),
            ),
          ],
          if (widget.businessActions && !_hasInvoiceFile) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _invoiceNumberController,
              decoration: const InputDecoration(
                labelText: 'Invoice number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _invoiceDateController,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'Invoice date',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _invoiceSystem,
              decoration: const InputDecoration(
                labelText: 'Invoice system',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'eArsiv', child: Text('e-Arsiv')),
                DropdownMenuItem(value: 'eFatura', child: Text('e-Fatura')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _invoiceSystem = value);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _invoiceType,
              decoration: const InputDecoration(
                labelText: 'Invoice type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'individual',
                  child: Text('Individual'),
                ),
                DropdownMenuItem(value: 'company', child: Text('Company')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _invoiceType = value);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_uploading ? 'Uploading' : 'Upload invoice'),
              ),
            ),
          ],
          if (widget.userActions &&
              _hasInvoiceFile &&
              (_status == 'issued' ||
                  _status == 'uploaded_valid' ||
                  _status == 'uploaded_with_issues')) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _rejectionReasonController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rejection reason optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _reviewing ? null : () => _review('approved'),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reviewing ? null : () => _review('rejected'),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal());
  }

  String _label(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}
