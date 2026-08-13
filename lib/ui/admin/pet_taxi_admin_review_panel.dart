import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import 'admin_section.dart';

String _petTaxiDocumentName(AppLocalizations l10n, String key) {
  return switch (key) {
    'taxPlate' => l10n.petTaxiDocumentTaxPlate,
    'businessRegistration' => l10n.petTaxiDocumentBusinessRegistration,
    'vehicleRegistration' => l10n.petTaxiDocumentVehicleRegistration,
    'driverLicense' => l10n.petTaxiDocumentDriverLicense,
    'trafficInsurance' => l10n.petTaxiDocumentTrafficInsurance,
    _ => key,
  };
}

abstract class PetTaxiAdminApprovalApi {
  Future<void> reviewDocument({
    required String businessId,
    required String documentKey,
    required String action,
    String? reason,
  });

  Future<void> approveCompliance(String businessId);
  Future<void> activatePublication(String businessId);
}

class FirebasePetTaxiAdminApprovalApi implements PetTaxiAdminApprovalApi {
  HttpsCallable _callable(String name) =>
      FirebaseFunctions.instanceFor(region: 'europe-west3').httpsCallable(name);

  @override
  Future<void> reviewDocument({
    required String businessId,
    required String documentKey,
    required String action,
    String? reason,
  }) async {
    await _callable('reviewPetTaxiDocument').call({
      'businessId': businessId,
      'documentKey': documentKey,
      'action': action,
      'reason': reason,
    });
  }

  @override
  Future<void> approveCompliance(String businessId) async {
    await _callable(
      'approvePetTaxiCompliance',
    ).call({'businessId': businessId});
  }

  @override
  Future<void> activatePublication(String businessId) async {
    await _callable(
      'activatePetTaxiPublication',
    ).call({'businessId': businessId});
  }
}

class PetTaxiAdminReviewPanel extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> businessData;
  final PetTaxiAdminApprovalApi? api;

  const PetTaxiAdminReviewPanel({
    super.key,
    required this.businessId,
    required this.businessData,
    this.api,
  });

  @override
  State<PetTaxiAdminReviewPanel> createState() =>
      _PetTaxiAdminReviewPanelState();
}

class _PetTaxiAdminReviewPanelState extends State<PetTaxiAdminReviewPanel> {
  static const requiredDocuments = <String>[
    'taxPlate',
    'vehicleRegistration',
    'driverLicense',
    'trafficInsurance',
  ];
  static const complianceFlags = <String>[
    'petSafetyEquipmentConfirmed',
    'hygieneSanitationConfirmed',
    'driverLicenseValidConfirmed',
    'vehicleRegistrationConfirmed',
    'trafficInsuranceConfirmed',
    'taxResponsibilityConfirmed',
    'transportRulesConfirmed',
  ];

  bool _busy = false;
  bool _rejectDialogOpen = false;

  PetTaxiAdminApprovalApi get _api =>
      widget.api ?? FirebasePetTaxiAdminApprovalApi();

  Map<String, dynamic> get _taxi =>
      ((widget.businessData['sectorData'] as Map?)?['pet_taxi'] as Map?)
          ?.cast<String, dynamic>() ??
      {};

  Map<String, dynamic> get _documents =>
      (_taxi['documents'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _compliance =>
      (_taxi['compliance'] as Map?)?.cast<String, dynamic>() ?? {};

  String _documentStatus(String key) {
    final document = (_documents[key] as Map?)?.cast<String, dynamic>();
    return document?['status']?.toString() ?? 'missing';
  }

  bool _documentApproved(String key) {
    final document = (_documents[key] as Map?)?.cast<String, dynamic>();
    return document?['status'] == 'approved' && document?['verified'] == true;
  }

  String _documentName(BuildContext context, String key) {
    return _petTaxiDocumentName(AppLocalizations.of(context)!, key);
  }

  String _statusName(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context)!;
    return switch (status) {
      'pending_review' => l10n.petTaxiDocumentStatusPendingReview,
      'approved' => l10n.petTaxiDocumentStatusApproved,
      'rejected' => l10n.petTaxiDocumentStatusRejected,
      'missing' => l10n.petTaxiDocumentStatusMissing,
      _ => status,
    };
  }

  DateTime? _expiryDate(String key, Map<String, dynamic> document) {
    if (key != 'driverLicense' && key != 'trafficInsurance') return null;
    final field = key == 'driverLicense'
        ? 'driverLicenseExpiryDate'
        : 'trafficInsuranceExpiryDate';
    final raw = document[field] ?? document['expiryDate'];
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  bool _isExpired(DateTime expiry) {
    final today = DateTime.now();
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return expiryDay.isBefore(todayDay);
  }

  List<String> _complianceBlockers(BuildContext context) {
    final blockers = <String>[];
    if (widget.businessData['status'] != 'approved') {
      blockers.add('Root business is not approved');
    }
    if ((widget.businessData['verification'] as Map?)?['isVerified'] != true) {
      blockers.add('Root business verification is incomplete');
    }
    for (final key in requiredDocuments) {
      if (!_documentApproved(key)) {
        blockers.add('${_documentName(context, key)} is not approved');
      }
    }
    for (final key in complianceFlags) {
      if (_compliance[key] != true) blockers.add('$key is not confirmed');
    }
    return blockers;
  }

  List<String> _publicationBlockers(BuildContext context) {
    final blockers = [..._complianceBlockers(context)];
    if (_compliance['status'] != 'approved') {
      blockers.add('Pet Taxi compliance is not approved');
    }
    final sectors = (widget.businessData['sectors'] as List?) ?? const [];
    if (sectors.length != 1 || !sectors.contains('pet_taxi')) {
      blockers.add(
        'Multi-sector Pet Taxi publication requires architecture support',
      );
    }
    return blockers;
  }

  @override
  Widget build(BuildContext context) {
    final approvedCount = requiredDocuments.where(_documentApproved).length;
    final active = _taxi['isActive'] == true;
    final published =
        widget.businessData['published'] == true && _taxi['published'] == true;
    final complianceApproved = _compliance['status'] == 'approved';

    return AdminSection(
      title: 'Pet Taxi Approval & Publication',
      icon: Icons.local_taxi_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business approval: ${widget.businessData['status'] ?? 'unknown'}',
          ),
          Text(
            'Required documents: $approvedCount / ${requiredDocuments.length} approved',
          ),
          Text('Compliance: ${_compliance['status'] ?? 'missing'}'),
          Text('Pet Taxi active: ${active ? 'active' : 'inactive'}'),
          Text('Publication: ${published ? 'published' : 'unpublished'}'),
          const SizedBox(height: 12),
          ...requiredDocuments.map((key) => _documentTile(context, key)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed:
                    _busy ||
                        complianceApproved ||
                        _complianceBlockers(context).isNotEmpty
                    ? null
                    : _approveCompliance,
                child: const Text('Approve Pet Taxi compliance'),
              ),
              ElevatedButton(
                onPressed: _busy || _publicationBlockers(context).isNotEmpty
                    ? null
                    : _activatePublication,
                child: const Text('Activate & publish'),
              ),
            ],
          ),
          if (_publicationBlockers(context).isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Publication blockers:',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.orange.shade900,
              ),
            ),
            ..._publicationBlockers(
              context,
            ).map((blocker) => Text('• $blocker')),
          ],
        ],
      ),
    );
  }

  Widget _documentTile(BuildContext context, String key) {
    final document = (_documents[key] as Map?)?.cast<String, dynamic>() ?? {};
    final url = document['url']?.toString() ?? '';
    final status = _documentStatus(key);
    final reason = document['rejectionReason'] ?? document['rejectedReason'];
    final expiry = _expiryDate(key, document);
    final expired = expiry != null && _isExpired(expiry);
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _documentApproved(key)
                      ? Icons.check_circle
                      : Icons.pending_actions,
                  color: _documentApproved(key) ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _documentName(context, key),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Chip(
                        label: Text(_statusName(context, status)),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (document['verified'] == true)
                        Chip(
                          label: Text(l10n.verifiedLabel),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (expiry != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.event_outlined, size: 18),
                  Text(
                    l10n.petTaxiDocumentExpiryDate(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(expiry),
                    ),
                  ),
                  if (expired) ...[
                    Chip(
                      label: Text(l10n.petTaxiDocumentExpired),
                      avatar: const Icon(Icons.warning_amber, size: 16),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.red.shade50,
                    ),
                  ],
                ],
              ),
            ],
            if (reason != null && reason.toString().trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(reason.toString(), softWrap: true),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                spacing: 4,
                children: [
                  if (url.isNotEmpty)
                    IconButton(
                      tooltip: l10n.open,
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _openDocument(context, document),
                    ),
                  if (status == 'pending_review')
                    IconButton(
                      tooltip: l10n.approve,
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: _busy ? null : () => _review(key, 'approved'),
                    ),
                  if (status == 'pending_review')
                    IconButton(
                      tooltip: l10n.reject,
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: _busy || _rejectDialogOpen
                          ? null
                          : () => _reject(key),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(
    BuildContext context,
    Map<String, dynamic> document,
  ) async {
    final url = document['url']?.toString() ?? '';
    if (url.isEmpty) return;
    final contentType = document['contentType']?.toString().toLowerCase() ?? '';
    final fileName = document['fileName']?.toString().toLowerCase() ?? '';
    final isImage =
        contentType == 'image/jpeg' ||
        contentType == 'image/png' ||
        fileName.endsWith('.jpg') ||
        fileName.endsWith('.jpeg') ||
        fileName.endsWith('.png');
    if (!isImage) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (imageContext, error, stackTrace) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppLocalizations.of(
                    dialogContext,
                  )!.petTaxiDocumentUploadFailed,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _review(String key, String action, {String? reason}) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await _api.reviewDocument(
        businessId: widget.businessId,
        documentKey: key,
        action: action,
        reason: reason,
      );
      _message(l10n.petTaxiAdminActionCompleted);
    } on FirebaseFunctionsException catch (error) {
      _message(_callableErrorMessage(l10n, error));
    } catch (error, stackTrace) {
      debugPrint(
        'Unexpected Pet Taxi document review error: $error\n$stackTrace',
      );
      _message(l10n.petTaxiAdminErrorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(String key) async {
    if (!mounted || _busy || _rejectDialogOpen) return;
    _rejectDialogOpen = true;
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (_) => _PetTaxiRejectDialog(documentKey: key),
      );
      if (reason != null && mounted) {
        await _review(key, 'rejected', reason: reason);
      }
    } finally {
      _rejectDialogOpen = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _approveCompliance() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await _api.approveCompliance(widget.businessId);
      _message(l10n.petTaxiAdminActionCompleted);
    } on FirebaseFunctionsException catch (error) {
      _message(_callableErrorMessage(l10n, error));
    } catch (error, stackTrace) {
      debugPrint('Unexpected Pet Taxi compliance error: $error\n$stackTrace');
      _message(l10n.petTaxiAdminErrorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activatePublication() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await _api.activatePublication(widget.businessId);
      _message(l10n.petTaxiAdminActionCompleted);
    } on FirebaseFunctionsException catch (error) {
      _message(_callableErrorMessage(l10n, error));
    } catch (error, stackTrace) {
      debugPrint('Unexpected Pet Taxi publication error: $error\n$stackTrace');
      _message(l10n.petTaxiAdminErrorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _callableErrorMessage(
    AppLocalizations l10n,
    FirebaseFunctionsException error,
  ) {
    if (error.code == 'failed-precondition' &&
        error.message?.toLowerCase().contains('expired') == true) {
      return l10n.petTaxiDocumentExpiredMessage;
    }
    return switch (error.code) {
      'permission-denied' => l10n.petTaxiAdminErrorPermissionDenied,
      'unauthenticated' => l10n.petTaxiAdminErrorUnauthenticated,
      'not-found' => l10n.petTaxiAdminErrorNotFound,
      'invalid-argument' => l10n.petTaxiAdminErrorInvalidArgument,
      'already-exists' || 'aborted' => l10n.petTaxiAdminErrorAlreadyExists,
      'failed-precondition' => l10n.petTaxiAdminErrorFailedPrecondition,
      _ => l10n.petTaxiAdminErrorGeneric,
    };
  }
}

class _PetTaxiRejectDialog extends StatefulWidget {
  final String documentKey;

  const _PetTaxiRejectDialog({required this.documentKey});

  @override
  State<_PetTaxiRejectDialog> createState() => _PetTaxiRejectDialogState();
}

class _PetTaxiRejectDialogState extends State<_PetTaxiRejectDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        AppLocalizations.of(context)!.petTaxiRejectDocumentTitle(
          _petTaxiDocumentName(
            AppLocalizations.of(context)!,
            widget.documentKey,
          ),
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.reasonLabel,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = _controller.text.trim();
            if (reason.isNotEmpty) Navigator.pop(context, reason);
          },
          child: Text(AppLocalizations.of(context)!.reject),
        ),
      ],
    );
  }
}
