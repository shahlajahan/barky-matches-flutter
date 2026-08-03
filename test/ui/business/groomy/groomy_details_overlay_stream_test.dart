import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barky_matches_fixed/ui/business/groomy/groomy_details_overlay.dart';

void main() {
  test('public business document stream is created once and reused', () {
    final source = GroomyPublicBusinessDocumentStream(
      firestore: FakeFirebaseFirestore(),
      businessId: 'groomy-1',
    );

    expect(identical(source.stream, source.stream), isTrue);
    expect(identical(source.distinctStream, source.distinctStream), isTrue);
    expect(source.businessId, 'groomy-1');
  });

  test('cached services stream emits only active services', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('businesses')
        .doc('groomy-1')
        .collection('services')
        .add({
          'title': 'Full Grooming',
          'isActive': true,
          'price': 1800,
          'durationMin': 60,
        });
    await firestore
        .collection('businesses')
        .doc('groomy-1')
        .collection('services')
        .add({'title': 'Inactive Service', 'isActive': false});
    await firestore
        .collection('businesses')
        .doc('groomy-1')
        .collection('services')
        .add({
          'title': 'Nailing',
          'isActive': true,
          'price': 500.5,
          'durationMin': 40,
        });

    final source = GroomyServicesStream(
      firestore: firestore,
      businessId: 'groomy-1',
    );
    final first = await source.stream.first;

    expect(first.docs, hasLength(2));
    expect(
      first.docs.map((doc) => doc['title']),
      containsAll(<String>['Full Grooming', 'Nailing']),
    );
    expect(
      first.docs.map((doc) => doc['title']),
      isNot(contains('Inactive Service')),
    );
    expect(groomyServicePrice(first.docs.first.data()), isA<double>());
  });

  testWidgets('waiting changes to data and renders two services', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('businesses')
        .doc('groomy-1')
        .collection('services')
        .add({
          'title': 'Full Grooming',
          'isActive': true,
          'price': 1800,
          'durationMin': 60,
        });
    await firestore
        .collection('businesses')
        .doc('groomy-1')
        .collection('services')
        .add({
          'title': 'Nailing',
          'isActive': true,
          'price': 500.5,
          'durationMin': 40,
        });
    final source = GroomyServicesStream(
      firestore: firestore,
      businessId: 'groomy-1',
    );

    await tester.pumpWidget(_servicesHarness(source.stream));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.textContaining('Full Grooming'), findsOneWidget);
    expect(find.textContaining('Nailing'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('empty result renders the empty state', (tester) async {
    final source = GroomyServicesStream(
      firestore: FakeFirebaseFirestore(),
      businessId: 'empty',
    );

    await tester.pumpWidget(_servicesHarness(source.stream));
    await tester.pumpAndSettle();
    expect(find.text('No services'), findsOneWidget);
  });

  testWidgets('stream errors render the error state', (tester) async {
    final stream = Stream<QuerySnapshot<Map<String, dynamic>>>.error(
      StateError('services failed'),
    );

    await tester.pumpWidget(_servicesHarness(stream));
    await tester.pump();
    expect(find.text('Services error'), findsOneWidget);
  });

  test('int, double, and null numeric fields normalize safely', () {
    expect(groomyServicePrice({'price': 1800}), 1800.0);
    expect(groomyServicePrice({'price': 500.5}), 500.5);
    expect(groomyServicePrice({'price': null}), 0);
    expect(groomyServiceDuration({'durationMin': 60}), 60);
    expect(groomyServiceDuration({'durationMin': 40.5}), 40);
    expect(groomyServiceDuration({'depositAmount': null}), 60);
  });

  test('rebuilds reuse the same cached stream instance', () {
    final firestore = FakeFirebaseFirestore();
    final source = GroomyServicesStream(
      firestore: firestore,
      businessId: 'groomy-1',
    );

    expect(identical(source.stream, source.stream), isTrue);
  });
}

Widget _servicesHarness(Stream<QuerySnapshot<Map<String, dynamic>>> stream) {
  return MaterialApp(
    home: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Services error');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) return const Text('No services');
        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            return Text(
              '${data['title']} ${groomyServicePrice(data)} ${groomyServiceDuration(data)}',
            );
          }).toList(),
        );
      },
    ),
  );
}
