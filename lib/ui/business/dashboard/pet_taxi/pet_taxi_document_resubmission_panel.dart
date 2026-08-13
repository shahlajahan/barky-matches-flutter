import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/services/pet_taxi_document_picker.dart';

Map<String, dynamic> buildPetTaxiReplacementDocument({
  required String documentKey,
  required String url,
  required String storagePath,
  required String fileName,
  required String contentType,
  DateTime? expiryDate,
}) {
  final document = <String, dynamic>{
    'url': url,
    'storagePath': storagePath,
    'fileName': fileName,
    'contentType': contentType,
  };
  if (documentKey == 'driverLicense') {
    if (expiryDate == null) {
      throw ArgumentError('Driver license expiry is required');
    }
    document['driverLicenseExpiryDate'] = expiryDate.toIso8601String();
  } else if (documentKey == 'trafficInsurance') {
    if (expiryDate == null) {
      throw ArgumentError('Traffic insurance expiry is required');
    }
    document['trafficInsuranceExpiryDate'] = expiryDate.toIso8601String();
  }
  return document;
}

class PetTaxiDocumentResubmissionPanel extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  const PetTaxiDocumentResubmissionPanel({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  State<PetTaxiDocumentResubmissionPanel> createState() =>
      _PetTaxiDocumentResubmissionPanelState();
}

class _PetTaxiDocumentResubmissionPanelState
    extends State<PetTaxiDocumentResubmissionPanel> {
  static const requiredDocuments = <String>[
    'taxPlate',
    'vehicleRegistration',
    'driverLicense',
    'trafficInsurance',
  ];
  bool _busy = false;
  final Map<String, DateTime?> _expiryDates = {};

  bool _requiresExpiry(String documentKey) =>
      documentKey == 'driverLicense' || documentKey == 'trafficInsurance';

  String _expiryLabel(BuildContext context, String documentKey) {
    final l10n = AppLocalizations.of(context)!;
    return documentKey == 'driverLicense'
        ? l10n.petTaxiReplacementExpiryDateDriverLicense
        : l10n.petTaxiReplacementExpiryDateTrafficInsurance;
  }

  String _documentName(BuildContext context, String documentKey) {
    final l10n = AppLocalizations.of(context)!;
    return switch (documentKey) {
      'taxPlate' => l10n.petTaxiDocumentTaxPlate,
      'businessRegistration' => l10n.petTaxiDocumentBusinessRegistration,
      'vehicleRegistration' => l10n.petTaxiDocumentVehicleRegistration,
      'driverLicense' => l10n.petTaxiDocumentDriverLicense,
      'trafficInsurance' => l10n.petTaxiDocumentTrafficInsurance,
      _ => documentKey,
    };
  }

  Map<String, dynamic> get _taxi =>
      ((widget.businessData['sectorData'] as Map?)?['pet_taxi'] as Map?)
          ?.cast<String, dynamic>() ??
      {};

  Map<String, dynamic> get _documents =>
      (_taxi['documents'] as Map?)?.cast<String, dynamic>() ?? {};

  List<String> get _rejectedDocuments => requiredDocuments.where((key) {
    final doc = (_documents[key] as Map?)?.cast<String, dynamic>() ?? {};
    return doc['status'] == 'rejected';
  }).toList();

  @override
  Widget build(BuildContext context) {
    if (_rejectedDocuments.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(
                context,
              )!.petTaxiDocumentsRequiringReplacement,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._rejectedDocuments.map(
              (key) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_documentName(context, key)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ((_documents[key] as Map?)?['rejectionReason'] ??
                              (_documents[key] as Map?)?['rejectedReason'] ??
                              AppLocalizations.of(context)!.petTaxiRejected)
                          .toString(),
                    ),
                    if (_requiresExpiry(key)) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _pickExpiryDate(key),
                        child: Text(
                          _expiryDates[key] == null
                              ? _expiryLabel(context, key)
                              : '${_expiryLabel(context, key)}: ${_dateText(_expiryDates[key]!)}',
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: TextButton(
                  onPressed: _busy ? null : () => _replace(key),
                  child: Text(
                    AppLocalizations.of(context)!.petTaxiReplaceDocument,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateText(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<bool> _pickExpiryDate(String documentKey) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _expiryDates[documentKey] ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 20, now.month, now.day),
    );
    if (selected == null || !mounted) return false;
    setState(() => _expiryDates[documentKey] = selected);
    return true;
  }

  Future<void> _replace(String documentKey) async {
    if (_busy) return;
    DateTime? expiryDate;
    if (_requiresExpiry(documentKey)) {
      expiryDate = _expiryDates[documentKey];
      if (expiryDate == null) {
        final selected = await _pickExpiryDate(documentKey);
        if (!selected || !mounted) return;
        expiryDate = _expiryDates[documentKey];
      }
      if (expiryDate == null) return;
    }
    PetTaxiPickedDocument? picked;
    try {
      picked = await pickPetTaxiDocument(context);
    } on PetTaxiDocumentPickerException catch (error) {
      if (mounted) _snack(_pickerErrorMessage(error.kind));
      return;
    }
    if (picked == null || !mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final extension = picked.name.split('.').last.toLowerCase();
    final ref = FirebaseStorage.instance.ref().child(
      'business_sector_docs/${user.uid}/pet_taxi/$documentKey/${DateTime.now().millisecondsSinceEpoch}.$extension',
    );

    setState(() => _busy = true);
    try {
      if (picked.bytes != null) {
        final bytes = picked.bytes!;
        await ref.putData(
          bytes,
          SettableMetadata(contentType: picked.contentType),
        );
      } else {
        final path = picked.path;
        if (path == null || path.isEmpty) {
          throw StateError('File path is missing');
        }
        await ref.putFile(
          File(path),
          SettableMetadata(contentType: picked.contentType),
        );
      }
      final url = await ref.getDownloadURL();
      final document = buildPetTaxiReplacementDocument(
        documentKey: documentKey,
        url: url,
        storagePath: ref.fullPath,
        fileName: picked.name,
        contentType: picked.contentType,
        expiryDate: expiryDate,
      );
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('resubmitPetTaxiDocument').call({
        'businessId': widget.businessId,
        'documentKey': documentKey,
        'document': document,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.petTaxiReplacementSubmitted,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _snack(AppLocalizations.of(context)!.petTaxiDocumentUploadFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _pickerErrorMessage(PetTaxiDocumentPickerError error) {
    final l10n = AppLocalizations.of(context)!;
    return switch (error) {
      PetTaxiDocumentPickerError.permissionDenied =>
        l10n.petTaxiDocumentPermissionDenied,
      PetTaxiDocumentPickerError.unsupportedFormat =>
        l10n.petTaxiUnsupportedDocumentFormat,
      PetTaxiDocumentPickerError.tooLarge => l10n.petTaxiDocumentTooLarge,
      PetTaxiDocumentPickerError.unavailable =>
        l10n.petTaxiDocumentUploadFailed,
    };
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
