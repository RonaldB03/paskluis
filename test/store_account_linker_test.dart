import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/data/services/store_account_linker.dart';

void main() {
  test('concurrent account status reads link the guest purchase once', () async {
    final linker = StoreAccountLinker();
    final done = Completer<void>();
    var calls = 0;
    Future<void> link() => linker.link(
      userId: 'new-account', currentUserId: () => 'new-account',
      active: true, linkedUserId: null,
      verifyAndLink: () { calls++; return done.future; },
    );
    final first = link();
    final second = link();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    done.complete();
    await Future.wait([first, second]);
  });

  test('offline verification can retry when connection returns', () async {
    final linker = StoreAccountLinker();
    var calls = 0;
    Future<void> link() => linker.link(
      userId: 'account', currentUserId: () => 'account',
      active: true, linkedUserId: null,
      verifyAndLink: () async { if (++calls == 1) throw StateError('offline'); },
    );
    await expectLater(link(), throwsStateError);
    await link();
    expect(calls, 2);
  });

  test('never claims inactive or already owned purchases', () async {
    final linker = StoreAccountLinker();
    var calls = 0;
    for (final owner in [null, 'account', 'another-account']) {
      for (final active in [false, true]) {
        if (owner == null && active) continue;
        await linker.link(
          userId: 'account', currentUserId: () => 'account',
          active: active, linkedUserId: owner,
          verifyAndLink: () async { calls++; },
        );
      }
    }
    expect(calls, 0);
  });

  test('sign-out or account switch cancels queued linking', () async {
    for (final nextUser in [null, 'another-account']) {
      final linker = StoreAccountLinker();
      String? current = 'account';
      var calls = 0;
      final pending = linker.link(
        userId: 'account', currentUserId: () => current,
        active: true, linkedUserId: null,
        verifyAndLink: () async { calls++; },
      );
      current = nextUser;
      await pending;
      expect(calls, 0);
    }
  });
}
