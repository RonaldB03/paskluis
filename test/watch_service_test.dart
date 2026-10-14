import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paskluis_v1/data/services/watch_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Box box;
  late WatchService service;
  final sent = <Map<String, dynamic>>[];
  Completer<void>? gate;
  bool offline = false;
  bool locallyErased = false;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('paskluis-watch-test-');
    Hive.init(directory.path);
    box = await Hive.openBox('cards');
    await box.put('test', {
      'id': '1',
      'name': 'Test',
      'type': 'Pasje',
      'code': '12345670',
      'barcodeSymbology': 'ean8',
    });
    SharedPreferences.setMockInitialValues({});
    sent.clear();
    gate = null;
    offline = false;
    locallyErased = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WatchService.channel, (call) async {
          if (call.method == 'status') {
            return <String, dynamic>{
              'garmin': {'locallyErased': locallyErased},
            };
          }
          if (call.method == 'replace') {
            if (offline) throw PlatformException(code: 'connection');
            sent.add(
              jsonDecode((call.arguments as Map)['snapshot'] as String)
                  as Map<String, dynamic>,
            );
            await gate?.future;
          }
          return null;
        });
    service = WatchService();
    await service.init();
  });
  tearDown(() async {
    service.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WatchService.channel, null);
  });
  test('no cards leave the phone before explicit selection', () async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(sent, isEmpty);
    expect(service.selected('garmin'), isEmpty);
  }, skip: !WatchService.betaEnabled);
  test('forgetting a Garmin disables future automatic transfers', () async {
    await service.pair('garmin', id: 'watch1', name: 'fenix 7');
    sent.clear();
    await service.select('garmin', {'1'});
    await service.disconnect();
    expect(service.enabled('garmin'), isFalse);
    expect(service.selected('garmin'), isEmpty);
    final count = sent.length;
    service.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(sent.length, count);
  }, skip: !WatchService.betaEnabled);
  test('selection followed by deletion sends an empty replacement', () async {
    await service.pair('garmin', id: 'watch1', name: 'fenix 7');
    sent.clear();
    await service.select('garmin', {'1'});
    expect((sent.last['cards'] as List).length, 1);
    final firstRevision = sent.last['revision'] as int;
    await box.delete('test');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(sent.last['cards'], isEmpty);
    expect(sent.last['revision'], greaterThan(firstRevision));
  }, skip: !WatchService.betaEnabled);
  test(
    'clearing while a transfer is in flight cannot leave the old snapshot last',
    () async {
      await service.pair('garmin', id: 'watch1');
      sent.clear();
      gate = Completer<void>();
      final first = service.select('garmin', {'1'});
      while (sent.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await service.clear('garmin');
      gate!.complete();
      await first;
      expect(sent.last['cards'], isEmpty);
      expect(sent.last['revision'], greaterThan(sent.first['revision'] as int));
    },
    skip: !WatchService.betaEnabled,
  );
  test(
    'an unrenderable edit revokes the stale code instead of retaining it',
    () async {
      await service.pair('garmin', id: 'watch1', name: 'fenix 7');
      sent.clear();
      await service.select('garmin', {'1'});
      await box.put('test', {
        'id': '1',
        'name': 'Test',
        'type': 'Pasje',
        'code': 'X' * 100,
        'barcodeSymbology': 'code128',
      });
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(sent.last['cards'], isEmpty);
      expect(service.error, 'invalid_cards');
    },
    skip: !WatchService.betaEnabled,
  );
  test(
    'fixed pairing survives reopening and blocks a second platform',
    () async {
      await service.pair('garmin', id: 'watch1', name: 'fenix 7');
      await service.select('garmin', {'1'});
      service.dispose();
      service = WatchService();
      await service.init();
      expect(service.pairedTarget, 'garmin');
      expect(service.pairedName, 'fenix 7');
      expect(service.selected('garmin'), {'1'});
      await expectLater(service.pair('wear', id: 'watch2'), throwsStateError);
      await expectLater(service.select('wear', {'1'}), throwsStateError);
    },
    skip: !WatchService.betaEnabled,
  );

  test(
    'offline remove and re-add retries only the latest saved selection',
    () async {
      await service.pair('garmin', id: 'watch1');
      await service.select('garmin', {'1'});
      offline = true;
      await service.select('garmin', {});
      await service.select('garmin', {'1'});
      expect(service.waiting, isTrue);
      service.dispose();
      service = WatchService();
      await service.init();
      offline = false;
      sent.clear();
      await service.retryPending();
      expect((sent.last['cards'] as List).single['id'], '1');
      await service.select('garmin', {});
      expect(sent.last['cards'], isEmpty);
    },
    skip: !WatchService.betaEnabled,
  );
  test(
    'automatic retry respects erasure on watch until selection changes',
    () async {
      await service.pair('garmin', id: 'watch1');
      await service.select('garmin', {'1'});
      locallyErased = true;
      sent.clear();
      await service.retryPending();
      expect(sent, isEmpty);
      expect(service.locallyErased, isTrue);
      await service.select('garmin', {});
      await service.select('garmin', {'1'});
      expect((sent.last['cards'] as List).length, 1);
    },
    skip: !WatchService.betaEnabled,
  );
}
