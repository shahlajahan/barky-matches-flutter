import 'dart:async';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/services/compliance_review_service.dart';
import 'package:barky_matches_fixed/ui/admin/pages/compliance_evidence_review_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Marketplace Revision 30 §J Slice 4 (Phase B) — admin evidence review UI.

class _FakeReviewService extends ComplianceReviewService {
  _FakeReviewService({
    this.documentStream,
    this.queueStream,
    this.grant,
    this.evidenceFailsWith,
    this.decisionFailsWith,
  }) : super(callableInvoker: (a, b) async => null);

  final Stream<ComplianceReviewItem?>? documentStream;
  final Stream<List<ComplianceReviewItem>>? queueStream;
  final ComplianceEvidenceGrant? grant;
  final ComplianceReviewFailureKind? evidenceFailsWith;
  final ComplianceReviewFailureKind? decisionFailsWith;

  int evidenceCalls = 0;
  int approveCalls = 0;
  int rejectCalls = 0;
  final List<String> rejectionReasons = [];

  @override
  Stream<List<ComplianceReviewItem>> watchPendingReview({int limit = 25}) =>
      queueStream ?? Stream.value(const []);

  @override
  Stream<ComplianceReviewItem?> watchDocument(String documentId) =>
      documentStream ?? Stream.value(null);

  @override
  Future<ComplianceEvidenceGrant> requestEvidence(String documentId) async {
    evidenceCalls += 1;
    if (evidenceFailsWith != null) {
      throw ComplianceReviewException(evidenceFailsWith!);
    }
    return grant ??
        ComplianceEvidenceGrant(
          documentId: documentId,
          downloadUrl: 'https://signed.example/object?X-Goog-Signature=abc',
          contentType: 'image/png',
          sizeBytes: 1234,
          contentHash: 'hash-1',
          expiresAtMs: DateTime.now().millisecondsSinceEpoch + 90000,
        );
  }

  @override
  Future<ComplianceDocumentStatus> approve(String documentId) async {
    approveCalls += 1;
    if (decisionFailsWith != null) {
      throw ComplianceReviewException(decisionFailsWith!);
    }
    return ComplianceDocumentStatus.approved;
  }

  @override
  Future<ComplianceDocumentStatus> reject({
    required String documentId,
    required String rejectionReason,
  }) async {
    rejectCalls += 1;
    rejectionReasons.add(rejectionReason);
    if (rejectionReason.trim().isEmpty) {
      throw const ComplianceReviewException(
        ComplianceReviewFailureKind.invalidInput,
      );
    }
    if (decisionFailsWith != null) {
      throw ComplianceReviewException(decisionFailsWith!);
    }
    return ComplianceDocumentStatus.rejected;
  }
}

ComplianceReviewItem _item({
  String documentId = 'doc-1',
  String status = 'pending_review',
}) {
  return ComplianceReviewItem.fromSnapshot(documentId, {
    'businessId': 'biz-1',
    'documentType': 'purchase_invoice',
    'sellerRelationship': 'reseller',
    'status': status,
    'contentHash': 'hash-1',
    'sizeBytes': 1234,
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required _FakeReviewService service,
  ComplianceEvidenceOpener? opener,
  DateTime Function()? now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ComplianceEvidenceReviewDetailPage(
        key: UniqueKey(),
        documentId: 'doc-1',
        service: service,
        opener: opener ?? (url) async => true,
        now: now,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The detail page is a lazily-built ListView, so controls below the fold are
/// not in the tree until scrolled into range. Assertions about them must build
/// them first rather than silently finding nothing.
Future<void> _revealAll(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -800));
  await tester.pumpAndSettle();
}

Future<void> _loadAndView(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('complianceReviewLoadEvidenceButton')));
  await tester.pumpAndSettle();
  await _revealAll(tester);
}

void main() {
  group('service contract', () {
    test('only pending_review is decidable; unknown is never actionable', () {
      expect(complianceDecidableStatuses, {
        ComplianceDocumentStatus.pendingReview,
      });
      expect(_item(status: 'pending_review').isDecidable, isTrue);
      for (final s in [
        'clean',
        'approved',
        'rejected',
        'revoked',
        'expired',
        'superseded',
        'a_future_state',
        '',
      ]) {
        expect(
          _item(status: s).isDecidable,
          isFalse,
          reason: '$s must not be actionable',
        );
      }
    });

    test('an unrecognized status parses to null, never to a default', () {
      expect(
        complianceDocumentStatusFromWire('pending_review'),
        ComplianceDocumentStatus.pendingReview,
      );
      for (final bad in <Object?>[
        null,
        '',
        'PENDING_REVIEW',
        'future',
        7,
        {},
      ]) {
        expect(complianceDocumentStatusFromWire(bad), isNull);
      }
    });

    test(
      'approve sends no rejectionReason; reject requires a non-blank one',
      () async {
        Map<String, dynamic>? sent;
        final service = ComplianceReviewService(
          callableInvoker: (name, data) async {
            sent = data;
            return {
              'documentId': 'doc-1',
              'status': name.contains('review') ? 'approved' : 'x',
            };
          },
        );
        await service.approve('doc-1');
        expect(sent!.containsKey('rejectionReason'), isFalse);
        expect(sent!['decision'], 'approve');

        for (final blank in ['', '   ', '\n\t']) {
          await expectLater(
            service.reject(documentId: 'doc-1', rejectionReason: blank),
            throwsA(
              isA<ComplianceReviewException>().having(
                (e) => e.kind,
                'kind',
                ComplianceReviewFailureKind.invalidInput,
              ),
            ),
          );
        }
      },
    );

    test(
      'a response that does not name a final status is not success',
      () async {
        for (final bad in <Object?>[
          null,
          'x',
          <String, dynamic>{},
          {'status': 'pending_review'},
          {'status': 'clean'},
          {'status': 'weird'},
        ]) {
          final service = ComplianceReviewService(
            callableInvoker: (a, b) async => bad,
          );
          await expectLater(
            service.approve('doc-1'),
            throwsA(isA<ComplianceReviewException>()),
          );
        }
      },
    );

    test(
      'a failed-precondition maps to a stale decision, not a retry',
      () async {
        final service = ComplianceReviewService(
          callableInvoker: (a, b) async => throw FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'Cannot move a document from "approved" to "approved"',
          ),
        );
        await expectLater(
          service.approve('doc-1'),
          throwsA(
            isA<ComplianceReviewException>().having(
              (e) => e.kind,
              'kind',
              ComplianceReviewFailureKind.staleDecision,
            ),
          ),
        );
      },
    );

    test('the evidence grant refuses malformed or unsupported payloads', () {
      expect(ComplianceEvidenceGrant.tryParse(null), isNull);
      expect(ComplianceEvidenceGrant.tryParse({'documentId': 'd'}), isNull);
      final pdf = ComplianceEvidenceGrant.tryParse({
        'documentId': 'd',
        'downloadUrl': 'u',
        'contentType': 'application/pdf',
        'sizeBytes': 1,
        'contentHash': 'h',
        'expiresAtMs': 1,
      })!;
      expect(pdf.isSupported, isTrue);
      expect(
        pdf.canRenderInline,
        isFalse,
        reason: 'PDF is never rendered inline',
      );
      final html = ComplianceEvidenceGrant.tryParse({
        'documentId': 'd',
        'downloadUrl': 'u',
        'contentType': 'text/html',
        'sizeBytes': 1,
        'contentHash': 'h',
        'expiresAtMs': 1,
      })!;
      expect(html.isSupported, isFalse);
      expect(html.canRenderInline, isFalse);
    });

    test(
      'the queue query filters server-side and excludes every other state',
      () async {
        final fake = FakeFirebaseFirestore();
        for (final entry in {
          'p1': 'pending_review',
          'p2': 'pending_review',
          'c1': 'clean',
          'a1': 'approved',
          'r1': 'rejected',
          'x1': 'a_future_state',
        }.entries) {
          await fake.collection('complianceDocuments').doc(entry.key).set({
            'businessId': 'biz-1',
            'status': entry.value,
            'uploadedAt': Timestamp.fromMillisecondsSinceEpoch(1000),
          });
        }
        final service = ComplianceReviewService(
          firestore: fake,
          callableInvoker: (a, b) async => null,
        );
        final rows = await service.watchPendingReview().first;
        expect(rows.map((r) => r.documentId).toSet(), {'p1', 'p2'});
        // The filter lives in the QUERY, not in a wider client-side read.
        final snap = await service.pendingReviewQuery().get();
        expect(snap.docs.length, 2);
        for (final r in rows) {
          expect(r.isDecidable, isTrue);
        }
      },
    );
  });

  group('review screen', () {
    testWidgets('the document-only approval scope is always stated', (
      tester,
    ) async {
      final service = _FakeReviewService(documentStream: Stream.value(_item()));
      await _pumpDetail(tester, service: service);
      expect(
        find.byKey(const Key('complianceReviewScopeNotice')),
        findsOneWidget,
      );
      expect(
        find.textContaining('does not publish, activate or classify'),
        findsOneWidget,
      );
    });

    testWidgets('approval is disabled until evidence is retrieved and viewed', (
      tester,
    ) async {
      final service = _FakeReviewService(documentStream: Stream.value(_item()));
      await _pumpDetail(tester, service: service);
      await _revealAll(tester);

      final approve = find.byKey(const Key('complianceReviewApproveButton'));
      expect(tester.widget<FilledButton>(approve).onPressed, isNull);
      expect(
        find.byKey(const Key('complianceReviewMustViewNotice')),
        findsOneWidget,
      );
      expect(service.approveCalls, 0);

      await _loadAndView(tester);
      expect(service.evidenceCalls, 1);
      expect(tester.widget<FilledButton>(approve).onPressed, isNotNull);
    });

    testWidgets('a PDF requires an explicit open before approval unlocks', (
      tester,
    ) async {
      var opened = false;
      final service = _FakeReviewService(
        documentStream: Stream.value(_item()),
        grant: ComplianceEvidenceGrant(
          documentId: 'doc-1',
          downloadUrl: 'https://signed.example/o?X-Goog-Signature=abc',
          contentType: 'application/pdf',
          sizeBytes: 10,
          contentHash: 'h',
          expiresAtMs: DateTime.now().millisecondsSinceEpoch + 90000,
        ),
      );
      await _pumpDetail(
        tester,
        service: service,
        opener: (url) async {
          opened = true;
          return true;
        },
      );
      await _loadAndView(tester);

      // Retrieved, but not yet seen: still locked.
      final approve = find.byKey(const Key('complianceReviewApproveButton'));
      expect(tester.widget<FilledButton>(approve).onPressed, isNull);
      expect(
        find.byKey(const Key('complianceReviewInlineImage')),
        findsNothing,
        reason: 'a PDF must never be rendered inline',
      );

      await tester.tap(
        find.byKey(const Key('complianceReviewOpenExternallyButton')),
      );
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      expect(tester.widget<FilledButton>(approve).onPressed, isNotNull);
    });

    testWidgets('an expired grant disables approval again', (tester) async {
      final past = DateTime.now().millisecondsSinceEpoch - 1000;
      final service = _FakeReviewService(
        documentStream: Stream.value(_item()),
        grant: ComplianceEvidenceGrant(
          documentId: 'doc-1',
          downloadUrl: 'https://signed.example/o',
          contentType: 'image/png',
          sizeBytes: 10,
          contentHash: 'h',
          expiresAtMs: past,
        ),
      );
      await _pumpDetail(tester, service: service);
      await _loadAndView(tester);
      expect(
        find.byKey(const Key('complianceReviewEvidenceExpired')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('complianceReviewApproveButton')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('a failed retrieval disables approval and says so', (
      tester,
    ) async {
      final service = _FakeReviewService(
        documentStream: Stream.value(_item()),
        evidenceFailsWith: ComplianceReviewFailureKind.evidenceUnavailable,
      );
      await _pumpDetail(tester, service: service);
      await _loadAndView(tester);
      expect(
        find.byKey(const Key('complianceReviewFailureText')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('complianceReviewApproveButton')),
            )
            .onPressed,
        isNull,
      );
      expect(service.approveCalls, 0);
    });

    testWidgets('an unsupported content type is refused and never actionable', (
      tester,
    ) async {
      final service = _FakeReviewService(
        documentStream: Stream.value(_item()),
        grant: ComplianceEvidenceGrant(
          documentId: 'doc-1',
          downloadUrl: 'https://signed.example/o',
          contentType: 'text/html',
          sizeBytes: 10,
          contentHash: 'h',
          expiresAtMs: DateTime.now().millisecondsSinceEpoch + 90000,
        ),
      );
      await _pumpDetail(tester, service: service);
      await _loadAndView(tester);
      expect(
        find.byKey(const Key('complianceReviewUnsupported')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('complianceReviewInlineImage')),
        findsNothing,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('complianceReviewApproveButton')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('every non-pending status disables all decision controls', (
      tester,
    ) async {
      for (final status in [
        'clean',
        'approved',
        'rejected',
        'revoked',
        'expired',
        'superseded',
        'a_future_state',
        '',
      ]) {
        final service = _FakeReviewService(
          documentStream: Stream.value(_item(status: status)),
        );
        await _pumpDetail(tester, service: service);
        await _revealAll(tester);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('complianceReviewApproveButton')),
              )
              .onPressed,
          isNull,
          reason: '$status must not be approvable',
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const Key('complianceReviewLoadEvidenceButton')),
              )
              .onPressed,
          isNull,
          reason: '$status must not even permit fetching evidence',
        );
        expect(service.evidenceCalls, 0);
      }
    });

    testWidgets('an unknown status is labelled as unrecognised', (
      tester,
    ) async {
      final service = _FakeReviewService(
        documentStream: Stream.value(_item(status: 'a_future_state')),
      );
      await _pumpDetail(tester, service: service);
      expect(find.textContaining('does not recognise'), findsOneWidget);
    });

    testWidgets('rejection is blocked on a blank or whitespace reason', (
      tester,
    ) async {
      final service = _FakeReviewService(documentStream: Stream.value(_item()));
      await _pumpDetail(tester, service: service);
      await _loadAndView(tester);

      for (final blank in ['', '   ']) {
        await tester.enterText(
          find.byKey(const Key('complianceReviewRejectionReasonField')),
          blank,
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('complianceReviewRejectButton')));
        await tester.pumpAndSettle();
        expect(
          service.rejectCalls,
          0,
          reason: 'no blank reason may reach the server',
        );
        expect(
          find.byKey(const Key('complianceReviewFailureText')),
          findsOneWidget,
        );
      }
    });

    testWidgets('a valid rejection reaches the callable exactly once', (
      tester,
    ) async {
      final service = _FakeReviewService(documentStream: Stream.value(_item()));
      await _pumpDetail(tester, service: service);
      await _loadAndView(tester);
      await tester.enterText(
        find.byKey(const Key('complianceReviewRejectionReasonField')),
        'invoice does not name the product',
      );
      await tester.pump();

      final reject = find.byKey(const Key('complianceReviewRejectButton'));
      await tester.tap(reject);
      await tester.tap(reject, warnIfMissed: false);
      await tester.tap(reject, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(service.rejectCalls, 1);
      expect(service.rejectionReasons, ['invoice does not name the product']);
    });

    testWidgets('rapid approve taps produce exactly one decision', (
      tester,
    ) async {
      final gate = Completer<void>();
      final service = _SlowApproveService(gate, Stream.value(_item()));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ComplianceEvidenceReviewDetailPage(
            key: UniqueKey(),
            documentId: 'doc-1',
            service: service,
            opener: (url) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _loadAndView(tester);

      final approve = find.byKey(const Key('complianceReviewApproveButton'));
      await tester.tap(approve);
      await tester.tap(approve, warnIfMissed: false);
      await tester.tap(approve, warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(service.approveCalls, 1);
    });

    testWidgets('the UI never optimistically shows a final decision', (
      tester,
    ) async {
      // The server accepted the approval, but the document record still says
      // pending_review. The screen must keep showing pending_review.
      final service = _FakeReviewService(documentStream: Stream.value(_item()));
      await _pumpDetail(tester, service: service);
      await _loadAndView(tester);
      await tester.tap(find.byKey(const Key('complianceReviewApproveButton')));
      await tester.pumpAndSettle();

      expect(service.approveCalls, 1);
      final statusText = tester
          .widget<Text>(find.byKey(const Key('complianceReviewStatusText')))
          .data!;
      expect(statusText, contains('Waiting for review'));
      expect(statusText.toLowerCase(), isNot(contains('approved')));
    });

    testWidgets('a stale decision surfaces and defers to canonical state', (
      tester,
    ) async {
      final service = _FakeReviewService(
        documentStream: Stream.value(_item()),
        decisionFailsWith: ComplianceReviewFailureKind.staleDecision,
      );
      await _pumpDetail(tester, service: service);
      await _loadAndView(tester);
      await tester.tap(find.byKey(const Key('complianceReviewApproveButton')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('complianceReviewStaleNotice')),
        findsOneWidget,
      );
      expect(find.textContaining('already decided'), findsWidgets);
    });

    testWidgets('no signed URL or path appears in visible text', (
      tester,
    ) async {
      final service = _FakeReviewService(documentStream: Stream.value(_item()));
      await _pumpDetail(tester, service: service);
      await _loadAndView(tester);
      final visible = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');
      for (final leak in [
        'https://signed.example',
        'X-Goog-Signature',
        'compliance_docs',
        'compliance_quarantine',
        'storagePath',
        'bucket',
      ]) {
        expect(
          visible.contains(leak),
          isFalse,
          reason: '$leak must not be shown',
        );
      }
    });

    testWidgets('the screen offers no publication or classification control', (
      tester,
    ) async {
      final service = _FakeReviewService(documentStream: Stream.value(_item()));
      await _pumpDetail(tester, service: service);
      await _loadAndView(tester);
      for (final forbidden in [
        'Publish',
        'Activate',
        'Classify',
        'Eligib',
        'Link product',
        'Effective',
      ]) {
        expect(
          find.textContaining(forbidden),
          findsNothing,
          reason: 'Slice 4 introduces no $forbidden affordance',
        );
      }
    });
  });

  group('queue', () {
    testWidgets('only decidable rows are openable; others are inert', (
      tester,
    ) async {
      final service = _FakeReviewService(
        queueStream: Stream.value([
          _item(documentId: 'ok-1'),
          _item(documentId: 'weird-1', status: 'a_future_state'),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ComplianceEvidenceReviewListPage(service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ListTile>(
              find.byKey(const Key('complianceReviewQueueItem_ok-1')),
            )
            .onTap,
        isNotNull,
      );
      expect(
        tester
            .widget<ListTile>(
              find.byKey(const Key('complianceReviewQueueItem_weird-1')),
            )
            .onTap,
        isNull,
        reason: 'an unrecognised status is diagnostic only, never actionable',
      );
    });

    testWidgets('an empty queue says so rather than showing stale rows', (
      tester,
    ) async {
      final service = _FakeReviewService(queueStream: Stream.value(const []));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ComplianceEvidenceReviewListPage(service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('complianceReviewQueueEmpty')),
        findsOneWidget,
      );
    });
  });
}

class _SlowApproveService extends _FakeReviewService {
  _SlowApproveService(this.gate, Stream<ComplianceReviewItem?> docs)
    : super(documentStream: docs);
  final Completer<void> gate;

  @override
  Future<ComplianceDocumentStatus> approve(String documentId) async {
    approveCalls += 1;
    await gate.future;
    return ComplianceDocumentStatus.approved;
  }
}
