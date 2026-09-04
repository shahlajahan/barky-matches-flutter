import 'dart:typed_data';

import 'package:barky_matches_fixed/services/compliance_evidence_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

/// Marketplace Revision 30 §J Slice 3 — seller evidence intake service.
///
/// Proves the client consumes the frozen Slice 2 backend and never invents,
/// widens or bypasses any part of it.

ComplianceEvidenceService serviceWith({
  Object? Function(String name, Map<String, dynamic> data)? onCall,
  List<String>? uploadedPaths,
  bool uploadThrows = false,
}) {
  return ComplianceEvidenceService(
    callableInvoker: (name, data) async {
      if (onCall == null) {
        return {
          'sessionId': 's-1',
          'objectPath': 'compliance_quarantine/biz-1/s-1/tok.pdf',
          'maxSizeBytes': complianceMaxUploadSizeBytes,
          'allowedMimeTypes': complianceAllowedMimeTypes,
          'status': 'upload_authorized',
        };
      }
      return onCall(name, data);
    },
    uploader: (path, bytes, contentType) async {
      if (uploadThrows) throw Exception('storage failure');
      uploadedPaths?.add(path);
    },
  );
}

final _pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 1, 2, 3]);

Future<ComplianceUploadSession> createDefault(
  ComplianceEvidenceService service, {
  SellerRelationship relationship = SellerRelationship.reseller,
  ComplianceDocumentType type = ComplianceDocumentType.purchaseInvoice,
  String key = 'attempt-1',
}) {
  return service.createUploadSession(
    businessId: 'biz-1',
    sellerRelationship: relationship,
    documentType: type,
    originalFilename: 'invoice.pdf',
    declaredMimeType: 'application/pdf',
    declaredSizeBytes: _pdf.length,
    clientIdempotencyKey: key,
  );
}

void main() {
  group('frozen evidence matrix', () {
    test('mirrors Revision 30 §D exactly, six rows with their minimums', () {
      expect(complianceIntakeEvidenceMatrix.length, 6);
      expect(
        complianceIntakeEvidenceMatrix[SellerRelationship.brandOwner]!.first,
        ComplianceDocumentType.trademarkEvidence,
      );
      expect(
        complianceIntakeEvidenceMatrix[SellerRelationship.manufacturer]!.first,
        ComplianceDocumentType.manufacturerEvidence,
      );
      expect(
        complianceIntakeEvidenceMatrix[SellerRelationship
                .authorizedDistributor]!
            .first,
        ComplianceDocumentType.dealershipDistributionAgreement,
      );
      expect(
        complianceIntakeEvidenceMatrix[SellerRelationship.authorizedDealer]!
            .first,
        ComplianceDocumentType.authorizationLetter,
      );
      expect(
        complianceIntakeEvidenceMatrix[SellerRelationship.importer]!.first,
        ComplianceDocumentType.importerEvidence,
      );
      expect(
        complianceIntakeEvidenceMatrix[SellerRelationship.reseller]!.first,
        ComplianceDocumentType.purchaseInvoice,
      );
      // Every relationship is covered; none is silently missing.
      for (final r in SellerRelationship.values) {
        expect(complianceIntakeEvidenceMatrix.containsKey(r), isTrue);
      }
    });

    test('the six wire values match the frozen SELLER_RELATIONSHIP enum', () {
      expect(SellerRelationship.values.map((r) => r.wireValue).toSet(), {
        'brand_owner',
        'manufacturer',
        'authorized_distributor',
        'authorized_dealer',
        'importer',
        'reseller',
      });
    });

    test(
      'category_compliance_evidence is in no row and is never selectable',
      () {
        for (final types in complianceIntakeEvidenceMatrix.values) {
          expect(
            types,
            isNot(contains(ComplianceDocumentType.categoryComplianceEvidence)),
          );
        }
        for (final r in SellerRelationship.values) {
          expect(
            selectableDocumentTypesFor(r),
            isNot(contains(ComplianceDocumentType.categoryComplianceEvidence)),
          );
        }
        expect(
          unresolvedPolicyDocumentTypes,
          contains(ComplianceDocumentType.categoryComplianceEvidence),
        );
      },
    );

    test(
      'the service refuses the unresolved type without calling the server',
      () async {
        var called = false;
        final service = serviceWith(
          onCall: (name, data) {
            called = true;
            return null;
          },
        );
        await expectLater(
          createDefault(
            service,
            type: ComplianceDocumentType.categoryComplianceEvidence,
          ),
          throwsA(
            isA<ComplianceEvidenceException>().having(
              (e) => e.kind,
              'kind',
              ComplianceEvidenceFailureKind.invalidSubmission,
            ),
          ),
        );
        expect(called, isFalse, reason: 'no session may be requested for it');
      },
    );

    test('the service refuses a pair the matrix does not list', () async {
      var called = false;
      final service = serviceWith(
        onCall: (name, data) {
          called = true;
          return null;
        },
      );
      await expectLater(
        createDefault(
          service,
          relationship: SellerRelationship.reseller,
          type: ComplianceDocumentType.trademarkEvidence,
        ),
        throwsA(isA<ComplianceEvidenceException>()),
      );
      expect(called, isFalse);
    });
  });

  group('session-bound upload', () {
    test(
      'the request carries exactly the fields the backend accepts',
      () async {
        Map<String, dynamic>? sent;
        String? calledName;
        final service = serviceWith(
          onCall: (name, data) {
            calledName = name;
            sent = data;
            return {
              'sessionId': 's-1',
              'objectPath': 'compliance_quarantine/biz-1/s-1/tok.pdf',
              'maxSizeBytes': complianceMaxUploadSizeBytes,
              'allowedMimeTypes': complianceAllowedMimeTypes,
              'status': 'upload_authorized',
            };
          },
        );
        await createDefault(service);
        expect(calledName, 'createComplianceUploadSession');
        expect(sent!.keys.toSet(), {
          'businessId',
          'originalFilename',
          'declaredMimeType',
          'declaredSizeBytes',
          'documentType',
          'sellerRelationship',
          'clientIdempotencyKey',
        });
        expect(sent!['sellerRelationship'], 'reseller');
        expect(sent!['documentType'], 'purchase_invoice');
        // The client never supplies a path, a generation or an owner.
        expect(sent!.containsKey('objectPath'), isFalse);
        expect(sent!.containsKey('marketplaceBusinessGenerationId'), isFalse);
        expect(sent!.containsKey('ownerUid'), isFalse);
      },
    );

    test(
      'the upload writes to the exact server-returned path, unmodified',
      () async {
        final uploaded = <String>[];
        final service = serviceWith(uploadedPaths: uploaded);
        final session = await createDefault(service);
        await service.uploadToSession(
          session: session,
          bytes: _pdf,
          contentType: 'application/pdf',
        );
        expect(uploaded, ['compliance_quarantine/biz-1/s-1/tok.pdf']);
        expect(uploaded.single, session.objectPath);
      },
    );

    test(
      'a malformed session response is never treated as a usable session',
      () async {
        for (final bad in <Object?>[
          null,
          'not-a-map',
          <String, dynamic>{},
          {'sessionId': 's-1'},
          {
            'sessionId': '',
            'objectPath': 'p',
            'maxSizeBytes': 1,
            'status': 'x',
            'allowedMimeTypes': <String>[],
          },
          {
            'sessionId': 's-1',
            'objectPath': '',
            'maxSizeBytes': 1,
            'status': 'x',
            'allowedMimeTypes': <String>[],
          },
        ]) {
          final service = serviceWith(onCall: (a, b) => bad);
          await expectLater(
            createDefault(service),
            throwsA(isA<ComplianceEvidenceException>()),
          );
        }
      },
    );

    test(
      'an oversize, empty or wrong-type payload is refused before upload',
      () async {
        final uploaded = <String>[];
        final service = serviceWith(uploadedPaths: uploaded);
        final session = await createDefault(service);

        await expectLater(
          service.uploadToSession(
            session: session,
            bytes: Uint8List(0),
            contentType: 'application/pdf',
          ),
          throwsA(isA<ComplianceEvidenceException>()),
        );
        await expectLater(
          service.uploadToSession(
            session: session,
            bytes: Uint8List(complianceMaxUploadSizeBytes + 1),
            contentType: 'application/pdf',
          ),
          throwsA(isA<ComplianceEvidenceException>()),
        );
        await expectLater(
          service.uploadToSession(
            session: session,
            bytes: _pdf,
            contentType: 'application/zip',
          ),
          throwsA(isA<ComplianceEvidenceException>()),
        );
        expect(uploaded, isEmpty, reason: 'nothing may reach Storage');
      },
    );

    test('a Storage failure maps to uploadFailed, not to success', () async {
      final service = serviceWith(uploadThrows: true);
      final session = await createDefault(service);
      await expectLater(
        service.uploadToSession(
          session: session,
          bytes: _pdf,
          contentType: 'application/pdf',
        ),
        throwsA(
          isA<ComplianceEvidenceException>().having(
            (e) => e.kind,
            'kind',
            ComplianceEvidenceFailureKind.uploadFailed,
          ),
        ),
      );
    });
  });

  group('failure mapping', () {
    Future<ComplianceEvidenceFailureKind> kindFor(
      String code, {
      String? message,
      Object? details,
    }) async {
      final service = serviceWith(
        onCall: (a, b) => throw FirebaseFunctionsException(
          code: code,
          message: message ?? 'x',
          details: details,
        ),
      );
      try {
        await createDefault(service);
        fail('expected a failure');
      } on ComplianceEvidenceException catch (e) {
        return e.kind;
      }
    }

    test('server codes map to the seller-facing kinds', () async {
      expect(
        await kindFor('unauthenticated'),
        ComplianceEvidenceFailureKind.unauthenticated,
      );
      expect(
        await kindFor('permission-denied'),
        ComplianceEvidenceFailureKind.permissionDenied,
      );
      expect(
        await kindFor('failed-precondition'),
        ComplianceEvidenceFailureKind.notEnabledForBusiness,
      );
      expect(
        await kindFor('already-exists'),
        ComplianceEvidenceFailureKind.sessionConflict,
      );
      expect(
        await kindFor('invalid-argument'),
        ComplianceEvidenceFailureKind.invalidSubmission,
      );
      expect(
        await kindFor('unavailable'),
        ComplianceEvidenceFailureKind.unavailableRetry,
      );
      expect(await kindFor('internal'), ComplianceEvidenceFailureKind.generic);
    });

    test(
      'the idempotency conflict is distinguished from the canary gate',
      () async {
        expect(
          await kindFor(
            'failed-precondition',
            message: 'idempotency_conflict: a different upload session exists',
          ),
          ComplianceEvidenceFailureKind.sessionConflict,
        );
      },
    );

    test('the unresolved-policy reason code is carried through', () async {
      expect(
        await kindFor(
          'failed-precondition',
          details: {'reasonCode': 'document_type_policy_unresolved'},
        ),
        ComplianceEvidenceFailureKind.documentTypePolicyUnresolved,
      );
    });
  });

  group('lifecycle mapping', () {
    test('every frozen session status maps to an honest stage', () {
      expect(
        stageForSessionStatus('upload_authorized'),
        ComplianceEvidenceStage.processing,
      );
      expect(
        stageForSessionStatus('uploaded'),
        ComplianceEvidenceStage.processing,
      );
      expect(
        stageForSessionStatus('validating'),
        ComplianceEvidenceStage.processing,
      );
      expect(
        stageForSessionStatus('scan_pending'),
        ComplianceEvidenceStage.processing,
      );
      expect(
        stageForSessionStatus('promotion_pending'),
        ComplianceEvidenceStage.processing,
      );
      expect(
        stageForSessionStatus('consumed'),
        ComplianceEvidenceStage.awaitingReview,
      );
      expect(
        stageForSessionStatus('infected'),
        ComplianceEvidenceStage.failedTerminal,
      );
      for (final s in [
        'expired',
        'cancelled',
        'validation_failed',
        'scan_failed',
      ]) {
        expect(
          stageForSessionStatus(s),
          ComplianceEvidenceStage.failedRetryable,
        );
      }
      expect(stageForSessionStatus(null), ComplianceEvidenceStage.idle);
      expect(
        stageForSessionStatus('unknown_future_state'),
        ComplianceEvidenceStage.idle,
      );
    });

    test('no stage means approved, verified, effective or publishable', () {
      // The vocabulary itself must not contain an approval concept: the
      // seller UI can only ever describe intake, never a review outcome.
      final names = ComplianceEvidenceStage.values.map((s) => s.name).join(' ');
      for (final forbidden in [
        'approv',
        'verified',
        'effective',
        'publish',
        'eligible',
        'active',
      ]) {
        expect(names.toLowerCase(), isNot(contains(forbidden)));
      }
      // `consumed` — the furthest intake can reach — is awaiting review.
      expect(
        stageForSessionStatus('consumed'),
        ComplianceEvidenceStage.awaitingReview,
      );
    });

    test('in-flight statuses are exactly the frozen non-terminal ones', () {
      expect(complianceInFlightSessionStatuses, {
        'upload_authorized',
        'uploaded',
        'validating',
        'scan_pending',
        'promotion_pending',
      });
      for (final terminal in [
        'consumed',
        'expired',
        'cancelled',
        'validation_failed',
        'scan_failed',
        'infected',
      ]) {
        expect(complianceInFlightSessionStatuses, isNot(contains(terminal)));
      }
    });
  });

  group('client limits match the backend', () {
    test('mime types, size and filename bounds are the frozen values', () {
      expect(complianceAllowedMimeTypes, [
        'application/pdf',
        'image/jpeg',
        'image/png',
      ]);
      expect(complianceMaxUploadSizeBytes, 15 * 1024 * 1024);
      expect(complianceMaxOriginalFilenameLength, 200);
    });

    test('each attempt key is distinct', () {
      final a = generateComplianceUploadIdempotencyKey();
      final b = generateComplianceUploadIdempotencyKey();
      expect(a, isNotEmpty);
      expect(a, isNot(equals(b)));
    });
  });
}
