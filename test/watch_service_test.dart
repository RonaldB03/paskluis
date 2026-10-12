import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WatchService.channel, (call) async {
          if (call.method == 'status') return <String, dynamic>{};
          if (call.method == 'replace') {
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
    await service.select('garmin', {'1'});
    await service.forgetGarmin();
    expect(service.enabled('garmin'), isFalse);
    expect(service.selected('garmin'), isEmpty);
    final count = sent.length;
    service.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(sent.length, count);
  }, skip: !WatchService.betaEnabled);
  test('selection followed by deletion sends an empty replacement', () async {
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
}
