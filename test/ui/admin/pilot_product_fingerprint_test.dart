import 'package:barky_matches_fixed/ui/admin/pilot_product_fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

// Revision 28 pilot product approval contract — this Dart port of
// `pilotProductApproval.js`'s `computeContentFingerprint`/
// `canonicalStringify` must produce byte-identical SHA-256 hex digests
// to the server for the same bound-field content, or every real
// approval attempt would be rejected as `stale-content` even when
// nothing actually changed. The golden hash below was computed
// independently (Python `hashlib.sha256` over the exact canonical JSON
// string `pilotProductApproval.js`'s own algorithm produces for this
// input), not derived from this Dart implementation itself.
void main() {
  test(
    'a whole-number double price hashes identically to the server\'s own '
    'canonical JSON (which never keeps a trailing .0) — golden value '
    'independently computed via Python hashlib.sha256',
    () {
      final hash = computePilotProductContentFingerprint({
        'name': 'Test',
        'price': 100.0,
      });
      expect(
        hash,
        '99be0f34c015c8cdff50b9f7498a3fda55369998f18bb744f08eaded74c0b02b',
      );
    },
  );

  test('the same content produces the same fingerprint every time', () {
    final data = {
      'name': 'Premium dog food',
      'description': 'desc',
      'price': 149.99,
      'currency': 'TRY',
      'category': 'Food',
    };
    expect(
      computePilotProductContentFingerprint(data),
      computePilotProductContentFingerprint(Map<String, dynamic>.from(data)),
    );
  });

  test(
    'a second, multi-field golden value — independently cross-checked '
    'directly against a live run of the real '
    'functions/src/marketplace/compliance/pilotProductApproval.js '
    "'s own computeContentFingerprint for this exact input (node -e), "
    'not merely internally self-consistent',
    () {
      final hash = computePilotProductContentFingerprint({
        'name': 'Premium dog food',
        'description': 'desc',
        'price': 149.99,
        'currency': 'TRY',
        'category': 'Food',
      });
      expect(
        hash,
        '6a984acf903d7a8ec1d61015045b1494fa069c5dcbeca8c7bd90c74c2e1fa832',
      );
    },
  );

  test(
    'key insertion order never affects the fingerprint — keys are '
    'canonically sorted at every nesting level',
    () {
      final a = {'name': 'X', 'price': 10.0, 'category': 'Food'};
      final b = {'category': 'Food', 'price': 10.0, 'name': 'X'};
      expect(
        computePilotProductContentFingerprint(a),
        computePilotProductContentFingerprint(b),
      );
    },
  );

  test('a changed bound field changes the fingerprint', () {
    final before = {'name': 'X', 'price': 10.0};
    final after = {'name': 'X', 'price': 11.0};
    expect(
      computePilotProductContentFingerprint(before),
      isNot(computePilotProductContentFingerprint(after)),
    );
  });

  test(
    'a change to a field outside kPilotApprovalBoundFields never changes '
    'the fingerprint — only bound fields are picked',
    () {
      final before = {'name': 'X', 'price': 10.0, 'stock': 5};
      final after = {'name': 'X', 'price': 10.0, 'stock': 999};
      expect(
        computePilotProductContentFingerprint(before),
        computePilotProductContentFingerprint(after),
      );
    },
  );

  test(
    'an absent bound field is genuinely omitted (presence-checked), never '
    'defaulted to null — a product missing salePrice hashes differently '
    'from one with an explicit salePrice: null',
    () {
      final withoutKey = {'name': 'X', 'price': 10.0};
      final withNullKey = {'name': 'X', 'price': 10.0, 'salePrice': null};
      expect(
        computePilotProductContentFingerprint(withoutKey),
        isNot(computePilotProductContentFingerprint(withNullKey)),
      );
    },
  );

  test(
    'nested media entries are canonicalized (keys sorted) while array '
    'order is preserved — reordering media changes the fingerprint',
    () {
      final base = {
        'name': 'X',
        'media': [
          {'type': 'image', 'originalUrl': 'a.jpg'},
          {'type': 'image', 'originalUrl': 'b.jpg'},
        ],
      };
      final reordered = {
        'name': 'X',
        'media': [
          {'type': 'image', 'originalUrl': 'b.jpg'},
          {'type': 'image', 'originalUrl': 'a.jpg'},
        ],
      };
      final sameContentKeysSwapped = {
        'name': 'X',
        'media': [
          {'originalUrl': 'a.jpg', 'type': 'image'},
          {'originalUrl': 'b.jpg', 'type': 'image'},
        ],
      };
      expect(
        computePilotProductContentFingerprint(base),
        isNot(computePilotProductContentFingerprint(reordered)),
      );
      expect(
        computePilotProductContentFingerprint(base),
        computePilotProductContentFingerprint(sameContentKeysSwapped),
      );
    },
  );
}
