import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/shared/utils/expiry_date.dart';
import 'package:paskluis_v1/data/services/backup_codec.dart';
import 'package:paskluis_v1/data/services/card_share_service.dart';

void main() {
  test('OCR rejects purchase dates and impossible dates', () {
    for (final text in [
      'Aankoop 12/10/2026',
      '12/10/2026',
      'Geldig tot 31/02/2027',
      'Expiry: 29/02/2027',
      'Geldig tot 12/202',
      'Geldig tot 12/20271',
      'Geldig tot 00/12/2027',
      'Geldig tot 12/00/2027',
      'Geldig tot 13/2027',
    ]) {
      expect(recogniseExpiryDate(text), isNull, reason: text);
    }
    expect(
      recogniseExpiryDate('Geldig tot: 29/02/2028'),
      DateTime(2028, 2, 29),
    );
    expect(recogniseExpiryDate('Expiry date: 12/2027'), DateTime(2027, 12, 31));
    expect(recogniseExpiryDate('Expires on 02/28'), DateTime(2028, 2, 29));
    expect(recogniseExpiryDate('Vervaldatum 04-10-26'), DateTime(2026, 10, 4));
  });
  test('coordinates stay local in exports and legacy restores', () {
    final card = {
      'id': '1',
      'code': '0001',
      'lastUsedLatitude': 52.1,
      'lastUsedLongitude': 5.1,
      'locationRecordedAt': 'today',
    };
    final exported = BackupCodec.portable(card);
    final restored = BackupCodec.readManifest(
      utf8.encode(
        jsonEncode({
          'schema': 1,
          'cards': [card],
        }),
      ),
      {},
    ).single;
    for (final copy in [exported, restored]) {
      expect(copy.keys, isNot(contains('lastUsedLatitude')));
      expect(copy.keys, isNot(contains('lastUsedLongitude')));
      expect(copy.keys, isNot(contains('locationRecordedAt')));
      expect(copy['code'], '0001');
    }
    expect(card['lastUsedLatitude'], 52.1);
  });
  test('remote content updates preserve personal organisation', () {
    final local = {
      'code': 'old',
      'isArchived': true,
      'archivedAt': 'yesterday',
      'isFavorite': true,
      'folderName': 'Vakantie',
      'lastUsedLatitude': 52.0,
    };
    final merged = CardShareService.keepLocalPreferences({
      'code': 'new',
      'isArchived': false,
    }, local);
    expect(merged['code'], 'new');
    expect(merged['isArchived'], true);
    expect(merged['isFavorite'], true);
    expect(merged['folderName'], 'Vakantie');
    expect(
      CardShareService.contentChanged(local, {
        ...local,
        'isFavorite': false,
        'folderName': 'other',
      }),
      false,
    );
    expect(
      CardShareService.contentChanged(local, {...local, 'code': 'new'}),
      true,
    );
    expect(
      CardShareService.safePayload(local).containsKey('lastUsedLatitude'),
      false,
    );
  });
}
