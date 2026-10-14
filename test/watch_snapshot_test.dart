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
  test(
    'categories preserve original codes and gift secrets never leave the phone',
    () {
      for (final format in ['barcode', 'qr']) {
        final gift = {
          ...card('gift'),
          'type': 'Cadeaukaart',
          'codeFormat': format,
          'pinCode': 'PIN-SECRET',
          'balance': 123.45,
          'note': 'PRIVATE-NOTE',
        };
        final result = snapshot(
          [
            card(),
            {...card('qr'), 'type': 'QR-code'},
            gift,
          ],
          {'1', 'qr', 'gift'},
        );
        final rows = result['cards'] as List;
        expect(rows.map((c) => c['category']).toSet(), {
          'loyalty',
          'qr',
          'gift',
        });
        final exported = rows.firstWhere((c) => c['id'] == 'gift');
        expect(exported['code'], gift['code']);
        expect(exported['height'], format == 'qr' ? greaterThan(1) : 1);
        for (final secret in [
          'PIN-SECRET',
          '123.45',
          'PRIVATE-NOTE',
          'pinCode',
          'balance',
        ]) {
          expect(jsonEncode(result), isNot(contains(secret)));
        }
      }
    },
  );
  test('legacy numeric QR cards retain their QR format', () {
    for (final format in [null, '', 'barcode']) {
      final source = {...card(), 'type': 'QR-code', 'codeFormat': format};
      final result = WatchSnapshot.card(source);
      final explicitQr = WatchSnapshot.card({...source, 'codeFormat': 'qr'});
      expect(result['height'], greaterThan(1));
      expect(result['width'], result['height']);
      expect(result['bits'], explicitQr['bits']);
      expect(result['code'], source['code']);
    }
  });
  test('selection errors identify the card and reason without its code', () {
    final rejected = {
      ...card('2'),
      'name': 'Testpas',
      'barcodeSymbology': 'unknown',
    };
    expect(
      () => snapshot([card(), rejected], {'1', '2'}),
      throwsA(
        isA<FormatException>()
            .having((e) => e.message, 'reason', 'unsupported')
            .having((e) => e.source, 'card name', 'Testpas'),
      ),
    );
    expect(
      (snapshot(
                List.generate(12, (i) => card('$i')),
                Set.from(List.generate(12, (i) => '$i')),
              )['cards']
              as List)
          .length,
      12,
    );
  });
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
      'category',
      'width',
      'height',
      'bits',
    });
    expect(rows.single['code'], '0123456789012');
    expect(rows.single['width'], 95);
    expect(rows.single['height'], 1);
  });
  test('shared and archived cards cannot leak into snapshots', () {
    for (final extra in [
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
  });
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
