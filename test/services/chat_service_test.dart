import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/services/chat_service.dart';

void main() {
  test('canonical direct chat id is stable from either direction', () {
    const userA = 'HYAb5EPyTeWD8OB1jprkLX1my512';
    const userB = 'k3TttEuCF9eOnTzESgzMhPeV9BQ2';

    expect(
      canonicalDirectChatId(userA, userB),
      'HYAb5EPyTeWD8OB1jprkLX1my512_k3TttEuCF9eOnTzESgzMhPeV9BQ2',
    );
    expect(
      canonicalDirectChatId(userB, userA),
      canonicalDirectChatId(userA, userB),
    );
  });

  test('canonical direct chat participants are lexicographically sorted', () {
    expect(canonicalDirectChatParticipants('user-b', 'user-a'), [
      'user-a',
      'user-b',
    ]);
  });
}
