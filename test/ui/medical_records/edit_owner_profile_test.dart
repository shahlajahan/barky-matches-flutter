import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/vet/patients/edit_owner_profile_page.dart';

void main() {
  test('owner profile phone values are normalized canonically', () {
    expect(normalizeOwnerProfilePhone('0555 111 22 33'), '+905551112233');
    expect(normalizeOwnerProfilePhone('555-111-22-33'), '+905551112233');
    expect(normalizeOwnerProfilePhone('90 555 111 22 33'), '+905551112233');
    expect(normalizeOwnerProfilePhone('+90 (555) 111-22-33'), '+905551112233');
    expect(isValidOwnerProfilePhone('+905551112233'), isTrue);
  });

  test(
    'optional empty emergency contact fields are preserved as empty strings',
    () {
      final profile = buildEditableOwnerProfile(
        ownerName: 'Ada Lovelace',
        ownerPhone: '+905551112233',
        emergencyContact: '',
        emergencyPhone: '',
        city: 'Istanbul',
        district: 'Kadikoy',
        address: 'Moda Cd. 1',
      );

      expect(profile['emergencyContact'], '');
      expect(profile['emergencyPhone'], '');
    },
  );

  test('editable owner profile contains only approved form fields', () {
    final profile = buildEditableOwnerProfile(
      ownerName: 'Ada Lovelace',
      ownerPhone: '+905551112233',
      emergencyContact: 'Grace Hopper',
      emergencyPhone: '+905559998877',
      city: 'Istanbul',
      district: 'Kadikoy',
      address: 'Moda Cd. 1',
    );

    expect(profile.keys, {
      'ownerName',
      'ownerPhone',
      'emergencyContact',
      'emergencyPhone',
      'city',
      'district',
      'address',
    });
    expect(profile.keys, isNot(contains('email')));
    expect(profile.keys, isNot(contains('uid')));
    expect(profile.keys, isNot(contains('role')));
    expect(profile.keys, isNot(contains('subscription')));
  });

  test(
    'dog update uses ownerProfile field paths so unrelated fields remain',
    () {
      final update = buildOwnerProfileFieldUpdate(
        buildEditableOwnerProfile(
          ownerName: 'Ada Lovelace',
          ownerPhone: '+905551112233',
          emergencyContact: '',
          emergencyPhone: '',
          city: 'Istanbul',
          district: 'Kadikoy',
          address: 'Moda Cd. 1',
        ),
        serverTimestamp: 'SERVER_TIMESTAMP',
      );

      expect(update['ownerProfile.city'], 'Istanbul');
      expect(update['ownerProfile.district'], 'Kadikoy');
      expect(update['ownerProfile.address'], 'Moda Cd. 1');
      expect(update, isNot(contains('ownerProfile')));
      expect(update, containsPair('ownerProfileUpdatedAt', 'SERVER_TIMESTAMP'));
      expect(update, containsPair('updatedAt', 'SERVER_TIMESTAMP'));
    },
  );
}
