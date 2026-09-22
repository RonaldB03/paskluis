import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/data/services/card_access_policy.dart';

void main() {
  test('personal offline cards survive signing out and changing accounts', () {
    expect(CardAccessPolicy.mayKeep({'code': 'test'}, null), isTrue);
    expect(CardAccessPolicy.mayKeep({'code': 'test'}, 'other'), isTrue);
  });
  test('received cards are only accessible to their recipient', () {
    final card = {'isShared': true, 'shareRecipientId': 'recipient'};
    expect(CardAccessPolicy.mayKeep(card, 'recipient'), isTrue);
    expect(CardAccessPolicy.mayKeep(card, 'other'), isFalse);
    expect(CardAccessPolicy.mayKeep(card, null), isFalse);
    expect(CardAccessPolicy.mayKeep({'isShared': 'true'}, 'recipient'), isFalse);
  });
  test('received and archived cards do not consume a personal free slot', () {
    expect(CardAccessPolicy.ownGiftCards([
      {'type': 'Cadeaukaart', 'isShared': true},
      {'type': 'Cadeaukaart', 'isArchived': 'true'},
      {'type': 'Cadeaukaart'},
      {'type': 'Pasje'},
    ]), 1);
  });
}
