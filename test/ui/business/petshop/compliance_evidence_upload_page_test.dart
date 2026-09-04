import 'dart:async';
import 'dart:typed_data';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/services/compliance_evidence_service.dart';
import 'package:barky_matches_fixed/ui/business/petshop/compliance_evidence_upload_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Marketplace Revision 30 §J Slice 3 — seller evidence upload UI.
///
/// Everything here is driven through the real widget with injected seams; no
/// production Firebase, Functions or Storage is touched.

class _FakeService extends ComplianceEvidenceService {
  _FakeService({this.onCreate, this.statusStream, this.failWith})
    : super(
        callableInvoker: (a, b) async => null,
        uploader: (a, b, c) async {},
      );

  final Future<ComplianceUploadSession> Function(Map<String, Object?> args)?
  onCreate;
  final Stream<String?>? statusStream;
  final ComplianceEvidenceFailureKind? failWith;

  int createCalls = 0;
  int uploadCalls = 0;
  final List<String> uploadedPaths = [];
  final List<String> idempotencyKeys = [];
  final List<String> documentTypes = [];
  final List<String> relationships = [];
  final List<String> businessIds = [];

  @override
  Future<ComplianceUploadSession> createUploadSession({
    required String businessId,
    required SellerRelationship sellerRelationship,
    required ComplianceDocumentType documentType,
    required String originalFilename,
    required String declaredMimeType,
    required int declaredSizeBytes,
    required String clientIdempotencyKey,
  }) async {
    createCalls += 1;
    idempotencyKeys.add(clientIdempotencyKey);
    documentTypes.add(documentType.wireValue);
    relationships.add(sellerRelationship.wireValue);
    businessIds.add(businessId);
    if (failWith != null) throw ComplianceEvidenceException(failWith!);
    if (onCreate != null) {
      return onCreate!({'businessId': businessId});
    }
    return const ComplianceUploadSession(
      sessionId: 's-1',
      objectPath: 'compliance_quarantine/biz-1/s-1/tok.pdf',
      maxSizeBytes: complianceMaxUploadSizeBytes,
      allowedMimeTypes: complianceAllowedMimeTypes,
      status: 'upload_authorized',
    );
  }

  @override
  Future<void> uploadToSession({
    required ComplianceUploadSession session,
    required Uint8List bytes,
    required String contentType,
  }) async {
    uploadCalls += 1;
    uploadedPaths.add(session.objectPath);
  }

  @override
  Stream<String?> watchLatestSessionStatus(String businessId) {
    return statusStream ?? Stream<String?>.value(null);
  }
}

final _bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 1, 2, 3]);

Future<void> pumpPage(
  WidgetTester tester, {
  required ComplianceEvidenceService service,
  CompliancePickFile? pickFile,
  Locale locale = const Locale('en'),
  String businessId = 'biz-1',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ComplianceEvidenceUploadPage(
        businessId: businessId,
        service: service,
        pickFile:
            pickFile ??
            () async => (
              filename: 'invoice.pdf',
              mimeType: 'application/pdf',
              bytes: _bytes,
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> selectRelationship(
  WidgetTester tester,
  SellerRelationship relationship,
) async {
  await tester.tap(
    find.byKey(const Key('complianceEvidenceRelationshipDropdown')),
  );
  await tester.pumpAndSettle();
  final label = switch (relationship) {
    SellerRelationship.brandOwner => 'Brand owner',
    SellerRelationship.manufacturer => 'Manufacturer',
    SellerRelationship.authorizedDistributor => 'Authorized distributor',
    SellerRelationship.authorizedDealer => 'Authorized dealer',
    SellerRelationship.importer => 'Importer',
    SellerRelationship.reseller => 'Reseller',
  };
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> selectFirstDocumentType(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('complianceEvidenceDocumentTypeDropdown')),
  );
  await tester.pumpAndSettle();
  // The last match is the one inside the opened menu.
  final items = find.byType(DropdownMenuItem<ComplianceDocumentType>);
  expect(items, findsWidgets);
  await tester.tap(items.last, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the "submission is not approval" notice is always visible', (
    tester,
  ) async {
    await pumpPage(tester, service: _FakeService());
    expect(
      find.byKey(const Key('complianceEvidenceNotApprovalNotice')),
      findsOneWidget,
    );
    expect(
      find.textContaining('not approval'),
      findsOneWidget,
      reason: 'the notice must state it plainly, not imply it',
    );
    // Present before any selection is made, not gated behind success.
    expect(
      find.byKey(const Key('complianceEvidencePrivacyNotice')),
      findsOneWidget,
    );
  });

  testWidgets('only the frozen matrix types are offered for a relationship', (
    tester,
  ) async {
    for (final entry in complianceIntakeEvidenceMatrix.entries) {
      final service = _FakeService();
      await pumpPage(tester, service: service);
      await selectRelationship(tester, entry.key);

      await tester.tap(
        find.byKey(const Key('complianceEvidenceDocumentTypeDropdown')),
      );
      await tester.pumpAndSettle();

      final items = tester
          .widgetList<DropdownMenuItem<ComplianceDocumentType>>(
            find.byType(DropdownMenuItem<ComplianceDocumentType>),
          )
          .map((w) => w.value)
          .whereType<ComplianceDocumentType>()
          .toSet();

      expect(
        items,
        entry.value.toSet(),
        reason: '${entry.key.wireValue} must offer exactly its frozen row',
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'category_compliance_evidence is never rendered or selectable, for any relationship',
    (tester) async {
      for (final relationship in SellerRelationship.values) {
        final service = _FakeService();
        await pumpPage(tester, service: service);
        await selectRelationship(tester, relationship);
        await tester.tap(
          find.byKey(const Key('complianceEvidenceDocumentTypeDropdown')),
        );
        await tester.pumpAndSettle();

        final values = tester
            .widgetList<DropdownMenuItem<ComplianceDocumentType>>(
              find.byType(DropdownMenuItem<ComplianceDocumentType>),
            )
            .map((w) => w.value);
        expect(
          values,
          isNot(contains(ComplianceDocumentType.categoryComplianceEvidence)),
          reason: 'the unresolved policy type must never appear in a picker',
        );
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('upload cannot begin without a relationship, type and file', (
    tester,
  ) async {
    final service = _FakeService();
    await pumpPage(tester, service: service);

    final submit = find.byKey(const Key('complianceEvidenceSubmitButton'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await selectRelationship(tester, SellerRelationship.reseller);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await selectFirstDocumentType(tester);
    expect(
      tester.widget<FilledButton>(submit).onPressed,
      isNull,
      reason: 'no file chosen yet',
    );

    await tester.tap(find.byKey(const Key('complianceEvidencePickButton')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    expect(service.createCalls, 0, reason: 'nothing was requested yet');
    expect(service.uploadCalls, 0);
  });

  testWidgets(
    'a successful submission requests one session and writes the exact path',
    (tester) async {
      final service = _FakeService();
      await pumpPage(tester, service: service);
      await selectRelationship(tester, SellerRelationship.reseller);
      await selectFirstDocumentType(tester);
      await tester.tap(find.byKey(const Key('complianceEvidencePickButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('complianceEvidenceSubmitButton')));
      await tester.pumpAndSettle();

      expect(service.createCalls, 1);
      expect(service.uploadCalls, 1);
      expect(service.uploadedPaths, [
        'compliance_quarantine/biz-1/s-1/tok.pdf',
      ]);
      expect(service.businessIds, ['biz-1']);
      expect(service.relationships, ['reseller']);
    },
  );

  testWidgets('repeated taps create exactly one session and one upload', (
    tester,
  ) async {
    final gate = Completer<void>();
    final service = _FakeService(
      onCreate: (_) async {
        await gate.future;
        return const ComplianceUploadSession(
          sessionId: 's-1',
          objectPath: 'compliance_quarantine/biz-1/s-1/tok.pdf',
          maxSizeBytes: complianceMaxUploadSizeBytes,
          allowedMimeTypes: complianceAllowedMimeTypes,
          status: 'upload_authorized',
        );
      },
    );
    await pumpPage(tester, service: service);
    await selectRelationship(tester, SellerRelationship.reseller);
    await selectFirstDocumentType(tester);
    await tester.tap(find.byKey(const Key('complianceEvidencePickButton')));
    await tester.pumpAndSettle();

    final submit = find.byKey(const Key('complianceEvidenceSubmitButton'));
    // Three taps in the SAME frame, with no pump between them. This is the
    // race the `_submitting` latch exists for: without a rebuild in between,
    // the button's onPressed is still non-null on the second and third tap,
    // so the handler really is entered three times and only the latch — set
    // synchronously before the first await — can stop it. Pumping between
    // taps would instead test the far weaker "a disabled button ignores a
    // tap", which a removed latch would still pass.
    await tester.tap(submit);
    await tester.tap(submit, warnIfMissed: false);
    await tester.tap(submit, warnIfMissed: false);
    await tester.pump();

    gate.complete();
    await tester.pumpAndSettle();

    expect(service.createCalls, 1, reason: 'no duplicate session');
    expect(service.uploadCalls, 1, reason: 'no duplicate upload');
  });

  testWidgets('a rebuild during submission does not start a second session', (
    tester,
  ) async {
    final gate = Completer<void>();
    final service = _FakeService(
      onCreate: (_) async {
        await gate.future;
        return const ComplianceUploadSession(
          sessionId: 's-1',
          objectPath: 'compliance_quarantine/biz-1/s-1/tok.pdf',
          maxSizeBytes: complianceMaxUploadSizeBytes,
          allowedMimeTypes: complianceAllowedMimeTypes,
          status: 'upload_authorized',
        );
      },
    );
    await pumpPage(tester, service: service);
    await selectRelationship(tester, SellerRelationship.reseller);
    await selectFirstDocumentType(tester);
    await tester.tap(find.byKey(const Key('complianceEvidencePickButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('complianceEvidenceSubmitButton')));
    await tester.pump();

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    gate.complete();
    await tester.pumpAndSettle();

    expect(service.createCalls, 1);
  });

  testWidgets('an in-flight server session suppresses a new upload', (
    tester,
  ) async {
    for (final status in complianceInFlightSessionStatuses) {
      final service = _FakeService(statusStream: Stream<String?>.value(status));
      await pumpPage(tester, service: service);

      // Every input is frozen while a session is open — including the
      // relationship dropdown, so the seller cannot even begin composing a
      // second submission.
      expect(
        tester
            .widget<DropdownButtonFormField<SellerRelationship>>(
              find.byKey(const Key('complianceEvidenceRelationshipDropdown')),
            )
            .onChanged,
        isNull,
        reason: '$status must freeze the relationship input',
      );

      // The pick button and the submit button are both disabled while the
      // server still holds a session open — the blind re-upload §I forbids.
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('complianceEvidencePickButton')),
            )
            .onPressed,
        isNull,
        reason: '$status must suppress a new pick',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('complianceEvidenceSubmitButton')),
            )
            .onPressed,
        isNull,
        reason: '$status must suppress a new submission',
      );
      expect(
        find.byKey(const Key('complianceEvidenceInProgressNotice')),
        findsOneWidget,
      );
      expect(service.createCalls, 0);
    }
  });

  testWidgets('state is restored from the server after navigation', (
    tester,
  ) async {
    // A fresh mount with an already-processing session shows processing,
    // not idle — this is what survives navigation and an app restart.
    final service = _FakeService(
      statusStream: Stream<String?>.value('scan_pending'),
    );
    await pumpPage(tester, service: service);
    expect(
      find.byKey(const Key('complianceEvidenceStageText')),
      findsOneWidget,
    );
    expect(find.textContaining('being checked'), findsOneWidget);
  });

  testWidgets(
    'a consumed session reads as awaiting review, never as approved',
    (tester) async {
      final service = _FakeService(
        statusStream: Stream<String?>.value('consumed'),
      );
      await pumpPage(tester, service: service);
      expect(find.textContaining('waiting for review'), findsOneWidget);

      // Scoped to the STATE text specifically. A whole-page scan would match
      // the not-approval notice itself, which legitimately contains the word
      // "published" while saying the opposite — the state label is what must
      // never claim an outcome intake cannot produce.
      final stageText = tester
          .widget<Text>(find.byKey(const Key('complianceEvidenceStageText')))
          .data!
          .toLowerCase();
      for (final forbidden in [
        'approved',
        'verified',
        'published',
        'effective',
        'eligible',
        'live',
      ]) {
        expect(
          stageText,
          isNot(contains(forbidden)),
          reason: 'the state label must never claim "$forbidden"',
        );
      }

      // And no affordance exists anywhere on this screen to approve, review
      // or publish: Slice 3 adds no admin or publication control.
      expect(find.textContaining('Approve'), findsNothing);
      expect(find.textContaining('Publish'), findsNothing);
      expect(find.textContaining('Review document'), findsNothing);
    },
  );

  testWidgets('an infected session is terminal, not retry-eligible', (
    tester,
  ) async {
    final service = _FakeService(
      statusStream: Stream<String?>.value('infected'),
    );
    await pumpPage(tester, service: service);
    expect(find.textContaining('security check'), findsOneWidget);
  });

  testWidgets('a retryable failure is shown and the flow stays usable', (
    tester,
  ) async {
    final service = _FakeService(
      statusStream: Stream<String?>.value('scan_failed'),
    );
    await pumpPage(tester, service: service);
    expect(find.textContaining('try again'), findsOneWidget);
    // Not in flight, so the seller may start a fresh attempt.
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('complianceEvidencePickButton')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'a permission failure shows a neutral message with no internals',
    (tester) async {
      final service = _FakeService(
        failWith: ComplianceEvidenceFailureKind.permissionDenied,
      );
      await pumpPage(tester, service: service);
      await selectRelationship(tester, SellerRelationship.reseller);
      await selectFirstDocumentType(tester);
      await tester.tap(find.byKey(const Key('complianceEvidencePickButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('complianceEvidenceSubmitButton')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('complianceEvidenceFailureText')),
        findsOneWidget,
      );
      // No object path, session id, bucket, owner uid, scanner or generation
      // detail may reach the seller.
      for (final leak in [
        'compliance_quarantine',
        'compliance_docs',
        's-1',
        'ownerUid',
        'generation',
        'clamav',
        'scanner',
        'bucket',
        'not the owner',
        'Business not found',
      ]) {
        expect(
          find.textContaining(leak),
          findsNothing,
          reason: '"$leak" must never be shown to a seller',
        );
      }
    },
  );

  testWidgets(
    'the canary denial reads as "not available yet", not as an error about ownership',
    (tester) async {
      final service = _FakeService(
        failWith: ComplianceEvidenceFailureKind.notEnabledForBusiness,
      );
      await pumpPage(tester, service: service);
      await selectRelationship(tester, SellerRelationship.reseller);
      await selectFirstDocumentType(tester);
      await tester.tap(find.byKey(const Key('complianceEvidencePickButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('complianceEvidenceSubmitButton')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('not available for this business yet'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'changing relationship clears a now-impermissible document type',
    (tester) async {
      final service = _FakeService();
      await pumpPage(tester, service: service);
      // reseller -> purchase_invoice, which brand_owner does not list.
      await selectRelationship(tester, SellerRelationship.reseller);
      await selectFirstDocumentType(tester);
      await selectRelationship(tester, SellerRelationship.brandOwner);

      final dropdown = tester
          .widget<DropdownButtonFormField<ComplianceDocumentType>>(
            find.byKey(const Key('complianceEvidenceDocumentTypeDropdown')),
          );
      expect(
        dropdown.initialValue,
        isNull,
        reason: 'a pair the new relationship forbids must not carry forward',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('complianceEvidenceSubmitButton')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('the business scope is exactly the one supplied, never another', (
    tester,
  ) async {
    final service = _FakeService();
    await pumpPage(tester, service: service, businessId: 'biz-OTHER');
    await selectRelationship(tester, SellerRelationship.importer);
    await selectFirstDocumentType(tester);
    await tester.tap(find.byKey(const Key('complianceEvidencePickButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('complianceEvidenceSubmitButton')));
    await tester.pumpAndSettle();
    expect(service.businessIds, ['biz-OTHER']);
  });

  testWidgets('renders in all four supported locales', (tester) async {
    for (final locale in [
      const Locale('en'),
      const Locale('tr'),
      const Locale('fa'),
      const Locale('ru'),
    ]) {
      final service = _FakeService();
      await pumpPage(tester, service: service, locale: locale);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('complianceEvidenceNotApprovalNotice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('complianceEvidencePrivacyNotice')),
        findsOneWidget,
      );
    }
  });
}
