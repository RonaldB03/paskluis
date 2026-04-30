import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

class StorageService {
  static const String cardsBoxName = 'cards';
  static const String encryptionKeyName = 'paskluis_hive_key';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<void> init() async {
    await Hive.initFlutter();

    final encryptionKey = await _getEncryptionKey();

    await Hive.openBox(
      cardsBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }

  static Future<List<int>> _getEncryptionKey() async {
    final existingKey = await _secureStorage.read(key: encryptionKeyName);

    if (existingKey != null) {
      return base64Url.decode(existingKey);
    }

    final key = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final encodedKey = base64UrlEncode(key);

    await _secureStorage.write(
      key: encryptionKeyName,
      value: encodedKey,
    );

    return key;
  }

  static Box get cardsBox => Hive.box(cardsBoxName);
}