import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';

const int petTaxiDocumentMaxBytes = 25 * 1024 * 1024;

enum PetTaxiDocumentPickerError {
  permissionDenied,
  unsupportedFormat,
  tooLarge,
  unavailable,
}

class PetTaxiDocumentPickerException implements Exception {
  final PetTaxiDocumentPickerError kind;

  const PetTaxiDocumentPickerException(this.kind);
}

class PetTaxiPickedDocument {
  final String name;
  final int size;
  final Uint8List? bytes;
  final String? path;
  final String contentType;

  const PetTaxiPickedDocument({
    required this.name,
    required this.size,
    required this.bytes,
    required this.path,
    required this.contentType,
  });
}

String? petTaxiDocumentContentTypeFor(
  String fileName, {
  String? reportedMimeType,
}) {
  final extension = fileName.split('.').last.toLowerCase();
  final expected = switch (extension) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    _ => null,
  };
  if (expected == null) return null;
  final reported = reportedMimeType?.trim().toLowerCase();
  if (reported != null &&
      reported.isNotEmpty &&
      reported != expected &&
      !(expected == 'image/jpeg' && reported == 'image/jpg')) {
    return null;
  }
  return expected;
}

Future<PetTaxiPickedDocument?> pickPetTaxiDocument(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final choice = await showModalBottomSheet<_PetTaxiDocumentChoice>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(l10n.petTaxiUploadDocument),
            subtitle: Text(l10n.petTaxiSupportedDocumentFormats),
          ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.petTaxiTakePhoto),
              onTap: () =>
                  Navigator.pop(sheetContext, _PetTaxiDocumentChoice.camera),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.petTaxiChoosePhoto),
            onTap: () =>
                Navigator.pop(sheetContext, _PetTaxiDocumentChoice.photo),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(l10n.petTaxiChoosePdf),
            onTap: () =>
                Navigator.pop(sheetContext, _PetTaxiDocumentChoice.pdf),
          ),
          ListTile(
            title: Text(l10n.cancel),
            onTap: () => Navigator.pop(sheetContext),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return null;

  if (choice == _PetTaxiDocumentChoice.camera ||
      choice == _PetTaxiDocumentChoice.photo) {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: choice == _PetTaxiDocumentChoice.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
    } on PlatformException catch (error) {
      if (_isPermissionError(error)) {
        throw const PetTaxiDocumentPickerException(
          PetTaxiDocumentPickerError.permissionDenied,
        );
      }
      throw const PetTaxiDocumentPickerException(
        PetTaxiDocumentPickerError.unavailable,
      );
    }
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return _validate(
      name: picked.name,
      size: bytes.length,
      bytes: bytes,
      path: kIsWeb ? null : picked.path,
      reportedMimeType: _imageMimeType(picked.name),
    );
  }

  FilePickerResult? result;
  try {
    result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: kIsWeb,
    );
  } on PlatformException {
    throw const PetTaxiDocumentPickerException(
      PetTaxiDocumentPickerError.unavailable,
    );
  }
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  return _validate(
    name: file.name,
    size: file.size,
    bytes: file.bytes,
    path: file.path,
    // FilePicker 8 does not expose a MIME field on PlatformFile. The
    // extension is validated against the selected type and Storage rules
    // remain authoritative for the uploaded bytes/content type.
    reportedMimeType: null,
  );
}

bool _isPermissionError(PlatformException error) {
  return switch (error.code) {
    'camera_access_denied' ||
    'photo_access_denied' ||
    'photo_access_restricted' => true,
    _ => false,
  };
}

String? _imageMimeType(String name) {
  final extension = name.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    _ => null,
  };
}

PetTaxiPickedDocument _validate({
  required String name,
  required int size,
  required Uint8List? bytes,
  required String? path,
  required String? reportedMimeType,
}) {
  final contentType = petTaxiDocumentContentTypeFor(
    name,
    reportedMimeType: reportedMimeType,
  );
  if (contentType == null) {
    throw const PetTaxiDocumentPickerException(
      PetTaxiDocumentPickerError.unsupportedFormat,
    );
  }
  if (size > petTaxiDocumentMaxBytes) {
    throw const PetTaxiDocumentPickerException(
      PetTaxiDocumentPickerError.tooLarge,
    );
  }
  if (kIsWeb && (bytes == null || bytes.isEmpty)) {
    throw const PetTaxiDocumentPickerException(
      PetTaxiDocumentPickerError.unavailable,
    );
  }
  if (!kIsWeb && path == null && (bytes == null || bytes.isEmpty)) {
    throw const PetTaxiDocumentPickerException(
      PetTaxiDocumentPickerError.unavailable,
    );
  }
  return PetTaxiPickedDocument(
    name: name,
    size: size,
    bytes: bytes,
    path: path,
    contentType: contentType,
  );
}

enum _PetTaxiDocumentChoice { camera, photo, pdf }
