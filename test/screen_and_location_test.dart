import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:paskluis_v1/data/services/card_screen_session.dart';
import 'package:paskluis_v1/data/services/location_resolver.dart';
import 'package:paskluis_v1/shared/utils/device_description.dart';

void main() {
  test('device confirmation has an article, including older locale labels', () {
    expect(deviceDescription('Android-apparaat', dutch: true), 'een Android-apparaat');
    expect(deviceDescription('Android device', dutch: true), 'een Android-apparaat');
    expect(deviceDescription('Android-apparaat', dutch: false), 'an Android device');
    expect(deviceDescription('iPhone of iPad', dutch: true), 'een iPhone of iPad');
    expect(deviceDescription('', dutch: true), 'een ander apparaat');
    expect(deviceDescription('Ronalds telefoon', dutch: true), 'Ronalds telefoon');
  });

  test('nested card screens brighten once and restore system control at final exit', () async {
    final calls = <String>[];
    final controller = CardScreenController(
      brighten: () async { calls.add('maximum'); },
      reset: () async { calls.add('system'); },
      wake: () async { calls.add('wake'); },
      sleep: () async { calls.add('sleep'); },
    );
    final first = controller.open();
    await first.ready;
    final second = controller.open();
    await second.ready;
    await first.close();
    expect(calls, ['maximum', 'wake']);
    await second.close();
    await second.close();
    expect(calls, ['maximum', 'wake', 'system', 'sleep']);
  });

  test('closing during native setup cannot leave brightness overridden', () async {
    final setting = Completer<void>();
    final started = Completer<void>();
    final calls = <String>[];
    final controller = CardScreenController(
      brighten: () async { calls.add('maximum'); started.complete(); await setting.future; },
      reset: () async { calls.add('system'); },
      wake: () async { calls.add('wake'); },
      sleep: () async { calls.add('sleep'); },
    );
    final session = controller.open();
    await started.future;
    final closing = session.close();
    setting.complete();
    await closing;
    expect(calls, ['maximum', 'system']);
  });

  test('disabled preferences do not change screen settings', () async {
    Future<void> unexpected() async => fail('Screen settings changed');
    final controller = CardScreenController(
      brighten: unexpected, reset: unexpected, wake: unexpected, sleep: unexpected,
    );
    final session = controller.open(brighten: false, keepAwake: false);
    await session.ready;
    await session.close();
  });

  final now = DateTime.utc(2026, 9, 26, 12);
  Position fix({int age = 0, double accuracy = 10}) => Position(
    longitude: 5, latitude: 52, timestamp: now.subtract(Duration(seconds: age)),
    accuracy: accuracy, altitude: 0, altitudeAccuracy: 0, heading: 0,
    headingAccuracy: 0, speed: 0, speedAccuracy: 0,
  );

  test('a recent accurate location is returned without waiting for GPS', () async {
    final recent = fix(age: 20);
    var gpsCalls = 0;
    final resolver = LocationResolver(
      lastKnown: () async => recent,
      current: () async { gpsCalls++; return fix(); },
      now: () => now,
    );
    expect(await resolver.resolve(), same(recent));
    expect(gpsCalls, 0);
  });

  test('stale locations trigger one shared GPS request across screens', () async {
    var count = 0;
    final measured = Completer<Position>();
    final started = Completer<void>();
    final resolver = LocationResolver(
      lastKnown: () async => fix(age: 300),
      current: () { count++; started.complete(); return measured.future; },
      now: () => now,
    );
    final first = resolver.resolve();
    await started.future;
    final second = resolver.resolve();
    await Future<void>.delayed(Duration.zero);
    final fresh = fix();
    measured.complete(fresh);
    expect(await first, same(fresh));
    expect(await second, same(fresh));
    expect(count, 1);
  });

  test('inaccurate and expired fixes are not presented as nearby', () async {
    for (final cached in [fix(age: 121), fix(accuracy: 101), fix(accuracy: double.nan)]) {
      final resolver = LocationResolver(
        lastKnown: () async => cached,
        current: () async => throw StateError('GPS unavailable'),
        now: () => now,
      );
      expect(await resolver.resolve(), isNull);
    }
  });

  test('failed GPS retains the existing two-minute fallback and retries next time', () async {
    var count = 0;
    final cached = fix(age: 60);
    final resolver = LocationResolver(
      lastKnown: () async => cached,
      current: () async { count++; throw StateError('GPS unavailable'); },
      now: () => now,
    );
    expect(await resolver.resolve(), same(cached));
    expect(await resolver.resolve(), same(cached));
    expect(count, 2);
  });
}
