import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/data/services/support_service.dart';

void main() {
  SupportThread thread(String status, bool unread) => SupportThread.fromJson({
    'id': 'thread', 'subject': 'Help', 'status': status,
    'created_at': '2026-09-28T10:00:00Z',
    'updated_at': '2026-09-28T11:00:00Z',
    'has_unread_reply': unread,
    'last_staff_reply_at': unread ? '2026-09-28T11:00:00Z' : null,
  });
  test('Closed conversations stay on Home until the final reply is read', () {
    expect(thread('closed', true).showOnHome, isTrue);
    expect(thread('closed', false).showOnHome, isFalse);
  });
  test('Open conversations stay accessible before and after replies', () {
    expect(thread('open', false).showOnHome, isTrue);
    expect(thread('waiting_for_user', true).showOnHome, isTrue);
    expect(thread('waiting_for_user', false).showOnHome, isTrue);
  });
  test('Inbox preserves server reply timestamp', () {
    expect(thread('closed', true).lastStaffReplyAt,
      DateTime.parse('2026-09-28T11:00:00Z'));
  });
}
