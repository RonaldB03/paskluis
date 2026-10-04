import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:paskluis_v1/data/services/media_storage_service.dart';
import 'package:paskluis_v1/data/services/storage_service.dart';

class TestPaths extends PathProviderPlatform {
  final String directory;
  TestPaths(this.directory);
  @override
  Future<String?> getApplicationDocumentsPath() async => directory;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform original;
  final plain = utf8.encode('synthetic private photo payload');
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('paskluis-media-test-');
    original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = TestPaths(directory.path);
    FlutterSecureStorage.setMockInitialValues({});
    Hive.init(directory.path);
    await Hive.openBox(StorageService.cardsBoxName);
  });
  tearDownAll(() async {
    await Hive.close();
    PathProviderPlatform.instance = original;
    await directory.delete(recursive: true);
  });
  test('images encrypt with unique nonces and reject tampering', () async {
    final first = await MediaStorageService.persistBytes(plain);
    final second = await MediaStorageService.persistBytes(plain);
    final bytes = await File(first).readAsBytes();
    expect(bytes, isNot(plain));
    expect(bytes, isNot(await File(second).readAsBytes()));
    expect(await MediaStorageService.readBytes(first), plain);
    expect(await MediaStorageService.readBytes(second), plain);
    expect(
      await const FlutterSecureStorage().read(key: 'paskluis_media_key_v1'),
      isNotNull,
    );
    bytes[18] ^= 1;
    await File(first).writeAsBytes(bytes);
    await expectLater(MediaStorageService.readBytes(first), throwsA(anything));
  });
  test(
    'legacy photos migrate once; removing one reference keeps another intact',
    () async {
      final legacy = File('${directory.path}/card_images/legacy.png');
      await legacy.parent.create(recursive: true);
      await legacy.writeAsBytes(plain);
      await StorageService.cardsBox.putAll({
        1: {'id': 'one', 'customImage': legacy.path},
        2: {'id': 'two', 'customImage': legacy.path},
        3: {'id': 'missing', 'customImage': '${directory.path}/missing.png'},
      });
      await StorageService.migrateImages();
      final image = StorageService.cardsBox.get(1)['customImage'] as String;
      expect(image.endsWith('.pkimg'), isTrue);
      expect(StorageService.cardsBox.get(2)['customImage'], image);
      expect(await legacy.exists(), isFalse);
      expect(await MediaStorageService.readBytes(image), plain);
      // Simulate a crash after Hive committed, before old plaintext was removed.
      await legacy.writeAsBytes(plain);
      await StorageService.migrateImages();
      expect(await legacy.exists(), isFalse);
      expect(StorageService.cardsBox.get(1)['customImage'], image);
      await StorageService.saveCard(1, {'id': 'one', 'customImage': ''});
      expect(await File(image).exists(), isTrue);
      await StorageService.saveCard(2, {'id': 'two', 'customImage': ''});
      expect(await File(image).exists(), isFalse);
      expect(
        StorageService.cardsBox.get(3)['customImage'],
        endsWith('missing.png'),
      );
    },
  );
}
