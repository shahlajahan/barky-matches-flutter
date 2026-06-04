import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class MarketplaceInvoiceService {
  MarketplaceInvoiceService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<void> uploadInvoice({
    required String collectionName,
    required String transactionId,
    required String invoiceNumber,
    required String invoiceDate,
    required String invoiceSystem,
    required String invoiceType,
    String? note,
  }) async {
    debugPrint(
      'MARKETPLACE INVOICE UPLOAD START collection=$collectionName '
      'transactionId=$transactionId',
    );

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null) return;

    final file = result.files.first;
    Uint8List? fileBytes = file.bytes;

    if (fileBytes == null && file.path != null) {
      fileBytes = await File(file.path!).readAsBytes();
    }

    if (fileBytes == null || fileBytes.isEmpty) {
      throw Exception('File is empty');
    }
    if (fileBytes.length > 5 * 1024 * 1024) {
      throw Exception('File too large');
    }

    final response = await _functions
        .httpsCallable('uploadInvoiceAndValidate')
        .call(<String, dynamic>{
          'collectionName': collectionName,
          'transactionId': transactionId,
          'fileBytes': fileBytes,
          'fileName': file.name,
          'invoiceNumber': invoiceNumber.trim(),
          'invoiceDate': invoiceDate.trim(),
          'invoiceSystem': invoiceSystem.trim(),
          'invoiceType': invoiceType.trim(),
          'note': note?.trim(),
        });

    final data = response.data;
    final invoiceUrl = data is Map ? data['pdfUrl']?.toString() : null;
    debugPrint('MARKETPLACE INVOICE FILE URL $invoiceUrl');
    debugPrint(
      'MARKETPLACE INVOICE UPLOAD SUCCESS collection=$collectionName '
      'transactionId=$transactionId',
    );
  }

  Future<void> reviewInvoice({
    required String collectionName,
    required String transactionId,
    required String status,
    String? rejectionReason,
  }) async {
    await _functions.httpsCallable('markMarketplaceInvoiceStatus').call({
      'collectionName': collectionName,
      'transactionId': transactionId,
      'status': status,
      'rejectionReason': rejectionReason?.trim(),
    });
  }
}
