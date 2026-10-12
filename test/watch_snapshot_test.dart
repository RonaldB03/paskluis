import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/data/services/watch_snapshot.dart';

Map<String, dynamic> card([String id = '1']) => {
  'id': id,
  'name': 'Testwinkel',
  'type': 'Pasje',
  'code': '0123456789012',
  'barcodeSymbology': 'ean13',
  'codeFormat': 'barcode',
  'pinCode': 'secret',
  'note': 'private',
  'customImage': '/private/photo',
  'isFavorite': true,
};
Map<String, Object> snapshot(Iterable<Map> cards, Set<String> selected) =>
    WatchSnapshot.build(
      cards: cards,
      selected: selected,
      owner: 'test-owner',
      revision: 1,
      language: 'nl',
    );

void main() {
  test('selection is opt-in and has a strict field allowlist', () {
    expect(snapshot([card()], {})['cards'], isEmpty);
    final result = snapshot([card()], {'1'});
    final text = jsonEncode(result);
    expect(text, isNot(contains('secret')));
    expect(text, isNot(contains('private')));
    final rows = result['cards'] as List;
    expect((rows.single as Map).keys.toSet(), {
      'id',
      'name',
      'code',
      'favorite',
      'width',
      'height',
      'bits',
    });
    expect(rows.single['code'], '0123456789012');
    expect(rows.single['width'], 95);
    expect(rows.single['height'], 1);
  });
  test(
    'gift cards, shared cards and archived cards cannot leak into snapshots',
    () {
      for (final extra in [
        {'type': 'Cadeaukaart'},
        {'isShared': true},
        {'isShared': 'true'},
        {'isArchived': true},
      ]) {
        expect(
          snapshot(
            [
              {...card(), ...extra},
            ],
            {'1'},
          )['cards'],
          isEmpty,
        );
      }
    },
  );
  test('full replacement removes deleted records and de-duplicates ids', () {
    expect((snapshot([card(), card()], {'1'})['cards'] as List).length, 1);
    expect(snapshot([], {'1'})['cards'], isEmpty);
  });
  test('QR uses a square integer matrix and bounded hex data', () {
    final qr = WatchSnapshot.card({
      ...card(),
      'code': 'https://paskluis.nl',
      'codeFormat': 'qr',
    });
    expect(qr['width'], qr['height']);
    expect(
      (qr['bits'] as String).length,
      ((qr['width'] as int) * (qr['height'] as int) + 3) ~/ 4,
    );
    expect(qr['bits'], matches(RegExp(r'^[0-9a-f]+$')));
  });
  test('unsupported formats and too-wide barcodes fail explicitly', () {
    expect(
      () => WatchSnapshot.card({...card(), 'barcodeSymbology': 'unknown'}),
      throwsFormatException,
    );
    expect(
      () => WatchSnapshot.card({
        ...card(),
        'barcodeSymbology': 'code128',
        'code': 'x' * 100,
      }),
      throwsFormatException,
    );
  });
  test('size limit never silently drops a selected card', () {
    expect(
      () => snapshot(
        List.generate(13, (i) => card('$i')),
        Set.from(List.generate(13, (i) => '$i')),
      ),
      throwsFormatException,
    );
  });
}
