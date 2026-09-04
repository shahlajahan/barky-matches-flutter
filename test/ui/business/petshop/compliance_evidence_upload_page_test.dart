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
  _FakeService({
    this.onCreate,
    this.statusStream,
    this.failWith,
    this.consumedDocumentId,
    this.declaredRelationship,
    this.documentStatusStream,
    this.submitFailsWith,
  }) : super(
         callableInvoker: (a, b) async => null,
         uploader: (a, b, c) async {},
       );

  final Future<ComplianceUploadSession> Function(Map<String, Object?> args)?
  onCreate;
  final Stream<String?>? statusStream;
  final ComplianceEvidenceFailureKind? failWith;

  /// The canonical promoted document id the session reports, and the
  /// document's own status — the two records the corrected page reads.
  final String? consumedDocumentId;
  final SellerRelationship? declaredRelationship;
  final Stream<String?>? documentStatusStream;
  final ComplianceEvidenceFailureKind? submitFailsWith;

  int submitCalls = 0;
  final List<String> submittedDocumentIds = [];
  final List<String> submittedRelationships = [];
  final List<DateTime> submittedValidUntils = [];

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
  Stream<ComplianceSessionSnapshot> watchLatestSession(String businessId) {
    final statuses = statusStream ?? Stream<String?>.value(null);
    return statuses.map(
      // Faithful to the server: `consumedByDocumentId` is written only in
      // the promotion transaction, so it exists only once the session is
      // `consumed`. A fake that always reported it would let tests pass on
      // an id the real backend would not yet have written.
      (status) => ComplianceSessionSnapshot(
        status: status,
        documentId: status == 'consumed' ? consumedDocumentId : null,
        declaredSellerRelationship: declaredRelationship,
      ),
    );
  }

  @override
  Stream<String?> watchDocumentStatus(String documentId) {
    return documentStatusStream ?? Stream<String?>.value(null);
  }

  @override
  Future<String> submitDocumentForReview({
    required String documentId,
    required SellerRelationship sellerRelationship,
    required DateTime validUntil,
    DateTime? issuedAt,
    DateTime? validFrom,
  }) async {
    submitCalls += 1;
    submittedDocumentIds.add(documentId);
    submittedRelationships.add(sellerRelationship.wireValue);
    submittedValidUntils.add(validUntil);
    if (submitFailsWith != null) {
      throw ComplianceEvidenceException(submitFailsWith!);
    }
    return 'pending_review';
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
        // A UniqueKey per pump. Without it Flutter reuses the existing State
        // across pumpWidget calls in the same test, so a second scenario
        // would silently keep the first scenario's streams and assert
        // nothing. This bit once already.
        key: UniqueKey(),
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

/// The page is a lazily-built ListView, so a widget below the fold is not in
/// the tree until it is scrolled into range. Assertions about late content
/// must build it first rather than silently finding nothing.
Future<void> revealAll(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -600));
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
    'a consumed session reads as awaiting the seller own submission, never as awaiting review',
    (tester) async {
      // THE CORRECTED DEFECT. `consumed` is a SESSION status: the upload
      // session was spent and a document now exists at `clean`. Nobody has
      // been asked to review it. Showing "waiting for review" here told the
      // seller their work was finished while they still had to submit.
      final service = _FakeService(
        statusStream: Stream<String?>.value('consumed'),
        consumedDocumentId: 'doc-1',
        documentStatusStream: Stream<String?>.value('clean'),
      );
      await pumpPage(tester, service: service);
      await revealAll(tester);
      expect(find.textContaining('send it for review'), findsOneWidget);
      expect(find.textContaining('waiting for review'), findsNothing);

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
        'waiting for review',
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

  _defect1Tests();
  _defect2Tests();

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

// ---------------------------------------------------------------------------
// Slice 3 corrective audit — Defect 1: the clean -> pending_review submission
// ---------------------------------------------------------------------------

Future<void> _reachAwaitingSubmission(
  WidgetTester tester,
  _FakeService service,
) async {
  // No dropdown interaction: at awaitingSubmission every input is correctly
  // frozen, and the relationship comes from the session record the server
  // wrote at intake — which is also the only source that survives a restart.
  await pumpPage(tester, service: service);
  await revealAll(tester);
}

void _defect1Tests() {
  testWidgets('a successful upload alone can never show "waiting for review"', (
    tester,
  ) async {
    // The session is consumed and the document exists — but at `clean`. This
    // is exactly the end state a successful upload reaches on its own.
    final service = _FakeService(
      statusStream: Stream<String?>.value('consumed'),
      consumedDocumentId: 'doc-1',
      documentStatusStream: Stream<String?>.value('clean'),
    );
    await pumpPage(tester, service: service);
    await revealAll(tester);
    expect(find.textContaining('waiting for review'), findsNothing);
    expect(service.submitCalls, 0, reason: 'submission is the seller\'s act');
  });

  testWidgets('pending_review copy appears only once the document says so', (
    tester,
  ) async {
    final service = _FakeService(
      statusStream: Stream<String?>.value('consumed'),
      consumedDocumentId: 'doc-1',
      documentStatusStream: Stream<String?>.value('pending_review'),
    );
    await pumpPage(tester, service: service);
    await revealAll(tester);
    expect(find.textContaining('waiting for review'), findsOneWidget);
    // And once it is under review the seller has nothing left to submit.
    expect(
      find.byKey(const Key('complianceEvidenceSubmitForReviewButton')),
      findsNothing,
    );
  });

  testWidgets(
    'submission uses the canonical consumedByDocumentId and fires exactly once',
    (tester) async {
      final service = _FakeService(
        statusStream: Stream<String?>.value('consumed'),
        consumedDocumentId: 'canonical-doc-42',
        declaredRelationship: SellerRelationship.reseller,
        documentStatusStream: Stream<String?>.value('clean'),
      );
      await _reachAwaitingSubmission(tester, service);

      await tester.tap(
        find.byKey(const Key('complianceEvidenceValidUntilButton')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await revealAll(tester);

      final submit = find.byKey(
        const Key('complianceEvidenceSubmitForReviewButton'),
      );
      // Three taps in the same frame — the latch, not a rebuild, must stop
      // the second and third.
      await tester.tap(submit);
      await tester.tap(submit, warnIfMissed: false);
      await tester.tap(submit, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(service.submitCalls, 1);
      expect(service.submittedDocumentIds, ['canonical-doc-42']);
      expect(service.submittedRelationships, ['reseller']);
      expect(service.submittedValidUntils.length, 1);
    },
  );

  testWidgets(
    'submission uses the relationship the SERVER recorded, not a stale local choice',
    (tester) async {
      // The seller picks `reseller` while the screen is fresh, then the
      // session arrives declaring `importer` — the relationship the upload
      // was actually authorized under. The document must be submitted under
      // the server's value: it is the one the intake matrix was checked
      // against, and the only one that survives a restart.
      final controller = StreamController<String?>();
      final service = _FakeService(
        statusStream: controller.stream,
        consumedDocumentId: 'doc-9',
        declaredRelationship: SellerRelationship.importer,
        documentStatusStream: Stream<String?>.value('clean'),
      );
      await pumpPage(tester, service: service);
      controller.add(null);
      await tester.pumpAndSettle();

      await selectRelationship(tester, SellerRelationship.reseller);

      controller.add('consumed');
      await tester.pumpAndSettle();
      await revealAll(tester);

      await tester.tap(
        find.byKey(const Key('complianceEvidenceValidUntilButton')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await revealAll(tester);
      await tester.tap(
        find.byKey(const Key('complianceEvidenceSubmitForReviewButton')),
      );
      await tester.pumpAndSettle();

      expect(service.submitCalls, 1);
      expect(service.submittedRelationships, ['importer']);
      await controller.close();
    },
  );

  testWidgets('submission is impossible before promotion names a document', (
    tester,
  ) async {
    // Session consumed but no consumedByDocumentId yet: nothing to submit,
    // and the client must not invent or compose an id.
    final service = _FakeService(
      statusStream: Stream<String?>.value('consumed'),
      consumedDocumentId: null,
    );
    await _reachAwaitingSubmission(tester, service);
    final submit = find.byKey(
      const Key('complianceEvidenceSubmitForReviewButton'),
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(service.submitCalls, 0);
  });

  testWidgets('a failed submission never displays pending_review', (
    tester,
  ) async {
    final service = _FakeService(
      statusStream: Stream<String?>.value('consumed'),
      consumedDocumentId: 'doc-1',
      declaredRelationship: SellerRelationship.reseller,
      documentStatusStream: Stream<String?>.value('clean'),
      submitFailsWith: ComplianceEvidenceFailureKind.unavailableRetry,
    );
    await _reachAwaitingSubmission(tester, service);
    await tester.tap(
      find.byKey(const Key('complianceEvidenceValidUntilButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await revealAll(tester);
    await tester.tap(
      find.byKey(const Key('complianceEvidenceSubmitForReviewButton')),
    );
    await tester.pumpAndSettle();
    await revealAll(tester);

    expect(service.submitCalls, 1);
    expect(find.textContaining('waiting for review'), findsNothing);
    expect(
      find.byKey(const Key('complianceEvidenceFailureText')),
      findsOneWidget,
    );
  });

  testWidgets('a retry after a failure does not double-submit', (tester) async {
    final service = _FakeService(
      statusStream: Stream<String?>.value('consumed'),
      consumedDocumentId: 'doc-1',
      declaredRelationship: SellerRelationship.reseller,
      documentStatusStream: Stream<String?>.value('clean'),
      submitFailsWith: ComplianceEvidenceFailureKind.unavailableRetry,
    );
    await _reachAwaitingSubmission(tester, service);
    await tester.tap(
      find.byKey(const Key('complianceEvidenceValidUntilButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await revealAll(tester);

    final submit = find.byKey(
      const Key('complianceEvidenceSubmitForReviewButton'),
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();
    await revealAll(tester);
    // A deliberate retry is one more call, never two, and always the same id.
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(service.submitCalls, 2);
    expect(service.submittedDocumentIds, ['doc-1', 'doc-1']);
  });
}

// ---------------------------------------------------------------------------
// Slice 3 corrective audit — Defect 2: unknown status fails closed
// ---------------------------------------------------------------------------

void _defect2Tests() {
  testWidgets('an unrecognized SESSION status disables every upload control', (
    tester,
  ) async {
    for (final status in [
      'a_status_from_a_future_release',
      complianceUnrecognizedStatus,
      '',
    ]) {
      final service = _FakeService(statusStream: Stream<String?>.value(status));
      await pumpPage(tester, service: service);

      expect(
        tester
            .widget<DropdownButtonFormField<SellerRelationship>>(
              find.byKey(const Key('complianceEvidenceRelationshipDropdown')),
            )
            .onChanged,
        isNull,
        reason: '"$status" must not permit choosing a relationship',
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('complianceEvidencePickButton')),
            )
            .onPressed,
        isNull,
        reason: '"$status" must not permit picking a file',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('complianceEvidenceSubmitButton')),
            )
            .onPressed,
        isNull,
        reason: '"$status" must not permit uploading',
      );
      expect(service.createCalls, 0);
    }
  });

  testWidgets('an unrecognized DOCUMENT status disables submit and retry', (
    tester,
  ) async {
    for (final status in [
      'brand_new_review_state',
      complianceUnrecognizedStatus,
    ]) {
      final service = _FakeService(
        statusStream: Stream<String?>.value('consumed'),
        consumedDocumentId: 'doc-1',
        documentStatusStream: Stream<String?>.value(status),
      );
      await pumpPage(tester, service: service);
      await revealAll(tester);

      // No submit affordance at all in a state the client cannot interpret.
      expect(
        find.byKey(const Key('complianceEvidenceSubmitForReviewButton')),
        findsNothing,
        reason: '"$status" must not expose a submit control',
      );
      // And no new upload either.
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('complianceEvidencePickButton')),
            )
            .onPressed,
        isNull,
      );
      expect(service.submitCalls, 0);
    }
  });

  testWidgets('an unknown state shows a generic message that leaks nothing', (
    tester,
  ) async {
    final service = _FakeService(
      statusStream: Stream<String?>.value('some_unmapped_state'),
    );
    await pumpPage(tester, service: service);
    await revealAll(tester);
    expect(
      find.textContaining('could not read the current state'),
      findsOneWidget,
    );
    for (final leak in [
      'some_unmapped_state',
      'compliance_quarantine',
      'complianceUploadSessions',
      'doc-1',
      'businessId',
    ]) {
      expect(
        find.textContaining(leak),
        findsNothing,
        reason: '"$leak" must never be shown to a seller',
      );
    }
  });

  testWidgets('only the enumerated stages ever enable an operation', (
    tester,
  ) async {
    // Exhaustive over the frozen vocabulary plus deliberately bogus values.
    const everySessionStatus = [
      'upload_authorized',
      'uploaded',
      'validating',
      'scan_pending',
      'promotion_pending',
      'consumed',
      'expired',
      'cancelled',
      'validation_failed',
      'scan_failed',
      'infected',
      'created',
      'totally_made_up',
    ];
    for (final status in everySessionStatus) {
      final service = _FakeService(statusStream: Stream<String?>.value(status));
      await pumpPage(tester, service: service);
      final pickEnabled =
          tester
              .widget<OutlinedButton>(
                find.byKey(const Key('complianceEvidencePickButton')),
              )
              .onPressed !=
          null;
      final shouldBeEnabled = complianceUploadEnabledStages.contains(
        stageForSessionStatus(status),
      );
      expect(
        pickEnabled,
        shouldBeEnabled,
        reason:
            '"$status" -> ${stageForSessionStatus(status)}: enablement must '
            'follow the positive allowlist exactly',
      );
    }
  });

  testWidgets('a fresh business with no session at all can still upload', (
    tester,
  ) async {
    // The one case null legitimately means "nothing has happened yet". If
    // fail-closed handling swallowed this too, the feature would be unusable.
    final service = _FakeService(statusStream: Stream<String?>.value(null));
    await pumpPage(tester, service: service);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('complianceEvidencePickButton')),
          )
          .onPressed,
      isNotNull,
    );
  });
}
