import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:paskluis_v1/data/services/card_duplicates.dart';
import 'package:paskluis_v1/data/services/card_folders.dart';
import 'package:paskluis_v1/data/services/storage_service.dart';
import 'package:paskluis_v1/data/services/backup_codec.dart';
import 'package:paskluis_v1/shared/utils/money_input.dart';

void main() {
  test('duplicate detection includes QR sets and preserves meaningful payload differences', () {
    final cards = [
      {'id': 'a', 'code': '001234', 'name': 'Store'},
      {'id': 'b', 'type': 'QR-set', 'codes': 'AbC|||https://example.invalid/ticket'},
    ];
    expect(CardDuplicates.find(cards, {'code': ' 001234 '}).length, 1);
    expect(CardDuplicates.find(cards, {'code': '1234'}), isEmpty);
    expect(CardDuplicates.find(cards, {'code': 'abc'}), isEmpty);
    expect(CardDuplicates.find(cards, {'code': ''}), isEmpty);
    expect(CardDuplicates.find(cards, {'code': 'AbC'}).length, 1);
    expect(CardDuplicates.find(cards, {'code': '001234'}, excludeId: 'a'), isEmpty);
    expect(CardDuplicates.find(cards, {'type': 'QR-set', 'codes': 'other|||AbC'}).length, 1);
  });
  test('money input rejects invalid values and calculates exact remaining cents', () {
    expect(parseMoneyCents('12,34'), 1234);
    expect(parseMoneyCents('12.3'), 1230);
    expect(parseMoneyCents('0'), 0);
    expect(parseMoneyCents('0.30')! - parseMoneyCents('0.10')!, 20);
    for (final value in ['', '-1', 'NaN', 'Infinity', '1e2', '1.234', '1,2.3']) {
      expect(parseMoneyCents(value), isNull, reason: value);
    }
  });
  test('folder rename, move and delete preserve cards and backup ownership', () async {
    final dir = await Directory.systemTemp.createTemp('paskluis-folders-');
    Hive.init(dir.path);
    await Hive.openBox(StorageService.cardsBoxName);
    try {
      StorageService.accountId = 'test'; StorageService.backupOwner = 'test';
      final a = await StorageService.addCard({'id': 'a', 'type': 'Pasje', 'code': '123'});
      final b = await StorageService.addCard({'id': 'b', 'type': 'Cadeaukaart', 'code': '456', 'balanceHistory': '[]', 'currentBalance': '20'});
      await CardFolders.assign({a, b}, 'Family');
      await CardFolders.assign({a}, 'Shops', replacing: 'Family');
      expect(CardFolders.name(StorageService.cardsBox.get(a)), 'Shops');
      expect(CardFolders.name(StorageService.cardsBox.get(b)), '');
      expect(BackupCodec.portable(StorageService.cardsBox.get(a))['folderName'], 'Shops');
      await StorageService.saveCard(a, {'id': 'a', 'type': 'Pasje', 'code': '123', 'name': 'Edited'});
      expect(CardFolders.name(StorageService.cardsBox.get(a)), 'Shops');
      expect((StorageService.cardsBox.get(a) as Map)['backupOwnerId'], 'test');
      await CardFolders.assign({}, '', replacing: 'Shops');
      expect(StorageService.cardsBox.length, 2);
      expect(CardFolders.names(StorageService.cardsBox.values), isEmpty);
      expect((StorageService.cardsBox.get(b) as Map)['currentBalance'], '20');
    } finally {
      StorageService.accountId = null; StorageService.backupOwner = null;
      await Hive.close(); await dir.delete(recursive: true);
    }
  });
}
