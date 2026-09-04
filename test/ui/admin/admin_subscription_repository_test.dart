import 'package:barky_matches_fixed/ui/admin/subscriptions/admin_subscription_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminSubscriptionRepository.searchUsers', () {
    test('exact UID finds a user without a subscription document', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('user-without-sub').set({
        'username': 'Petaverse',
      });

      final repository = AdminSubscriptionRepository(firestore: firestore);
      final results = await repository.searchUsers('user-without-sub');

      expect(results, hasLength(1));
      expect(results.single.userId, 'user-without-sub');
      expect(results.single.displayName, 'Petaverse');
      expect(results.single.hasSubscription, isFalse);
      expect(results.single.status, 'none');
    });

    test('leading and trailing search whitespace is normalized', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('trimmed-uid').set({
        'username': 'Trimmed',
      });

      final repository = AdminSubscriptionRepository(firestore: firestore);
      final results = await repository.searchUsers('  trimmed-uid  ');

      expect(results.map((record) => record.userId), ['trimmed-uid']);
    });

    test('visually similar UID characters are not conflated', () async {
      const lowercaseL = 'nqBCGZiUc7YsyUUQwlLEKidaHUa2';
      const uppercaseI = 'nqBCGZiUc7YsyUUQwILEKidaHUa2';
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc(lowercaseL).set({
        'username': 'Petaverse',
      });

      final repository = AdminSubscriptionRepository(firestore: firestore);

      expect(await repository.searchUsers(uppercaseI), isEmpty);
      final target = await repository.searchUsers(lowercaseL);
      expect(target.map((record) => record.userId), [lowercaseL]);
    });

    test(
      'username search is a Firestore query, not recent-page filtering',
      () async {
        final firestore = FakeFirebaseFirestore();
        for (var i = 0; i < 60; i += 1) {
          await firestore.collection('users').doc('preloaded-$i').set({
            'username': 'User $i',
          });
        }
        await firestore.collection('users').doc('outside-recent-page').set({
          'username': 'Petaverse',
        });

        final repository = AdminSubscriptionRepository(firestore: firestore);
        final results = await repository.searchUsers('Petaverse');

        expect(results.map((record) => record.userId), ['outside-recent-page']);
      },
    );

    test(
      'email search supports stored normalized and original-case values',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('users').doc('lowercase-email').set({
          'email': 'petaverse@example.com',
        });
        await firestore.collection('users').doc('mixed-email').set({
          'email': 'Petaverse@Example.com',
        });

        final repository = AdminSubscriptionRepository(firestore: firestore);

        expect(
          (await repository.searchUsers(
            'PETAVERSE@example.com',
          )).map((record) => record.userId),
          ['lowercase-email'],
        );
        expect(
          (await repository.searchUsers(
            'Petaverse@Example.com',
          )).map((record) => record.userId),
          ['mixed-email', 'lowercase-email'],
        );
      },
    );

    test('loads canonical subscription by document id', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('subscribed-user').set({
        'username': 'Gold User',
      });
      await firestore.collection('subscriptions').doc('subscribed-user').set({
        'userId': 'subscribed-user',
        'plan': 'gold',
        'status': 'active',
        'source': 'admin_grant',
        'price': 9.99,
        'currency': 'USD',
      });

      final repository = AdminSubscriptionRepository(firestore: firestore);
      final results = await repository.searchUsers('subscribed-user');

      expect(results.single.hasSubscription, isTrue);
      expect(results.single.plan, 'gold');
      expect(results.single.status, 'active');
      expect(results.single.price, 9.99);
      expect(results.single.currency, 'USD');
    });
  });
}
