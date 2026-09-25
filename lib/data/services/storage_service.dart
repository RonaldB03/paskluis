import 'package:paskluis_v1/l10n/l10n.dart';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'media_storage_service.dart';
import 'card_access_policy.dart';
import 'notification_service.dart';

class StorageService {
  static const String cardsBoxName = 'cards';
  static const String encryptionKeyName = 'paskluis_hive_key';
  static String? accountId;
  static String? backupOwner;
  static int accountRevision = 0;

  /// Invalidate in-flight sync before removing account-bound records.
  static Future<void> reconcileAccount(String? userId) async {
    if (accountId != userId) { accountRevision++; backupOwner = null; }
    accountId = userId;
    for (final key in cardsBox.keys.toList()) {
      final card = cardsBox.get(key);
      if (card is Map && !CardAccessPolicy.mayKeep(card, accountId)) {
        await deleteCard(key);
      }
    }
  }

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

    await _secureStorage.write(key: encryptionKeyName, value: encodedKey);

    return key;
  }

  static Box get cardsBox => Hive.box(cardsBoxName);

  static Future<dynamic> addCard(Map<dynamic, dynamic> value) async {
    if (!CardAccessPolicy.mayKeep(value, accountId)) {
      throw StateError('Account changed during synchronization');
    }
    value = Map<dynamic,dynamic>.from(value);
    if (!CardAccessPolicy.isReceived(value) && value['backupOwnerId']==null && backupOwner==accountId && backupOwner!=null) value['backupOwnerId']=backupOwner;
    final key = await cardsBox.add(value);
    // Especially on Android, do not close the add flow until Hive has flushed
    // the encrypted box and the written record can be read back.
    await cardsBox.flush();
    final stored = cardsBox.get(key);
    final expectedId = value['id']?.toString() ?? '';
    if (stored is! Map ||
        (expectedId.isNotEmpty && stored['id']?.toString() != expectedId)) {
      throw StateError(L10n.current.theCardCouldNotBeVerifiedAfter);
    }
    return key;
  }

  static Future<void> saveCard(dynamic key, Map<dynamic, dynamic> value) async {
    if (!CardAccessPolicy.mayKeep(value, accountId)) return;
    final oldItem = cardsBox.get(key);
    value = Map<dynamic,dynamic>.from(value);
    // Editing screens can hold an older card map from before backup enrollment.
    // Keep the persisted owner so an edit cannot silently drop or reassign it.
    if (oldItem is Map && oldItem['backupOwnerId'] != null) value['backupOwnerId'] = oldItem['backupOwnerId'];
    if (oldItem is Map && !value.containsKey('folderName') && oldItem.containsKey('folderName')) value['folderName'] = oldItem['folderName'];
    final oldImage = oldItem is Map ? oldItem['customImage']?.toString() : null;
    final newImage = value['customImage']?.toString();

    await cardsBox.put(key, value);

    if (oldImage != null && oldImage.isNotEmpty && oldImage != newImage) {
      await MediaStorageService.deleteIfManaged(oldImage);
    }
  }

  static Future<void> deleteCard(dynamic key) async {
    final item = cardsBox.get(key);
    if (item is Map) {
      final id = item['id']?.toString() ?? '';
      // Remove access first; notification cancellation must not delay isolation.
      await cardsBox.delete(key);
      try {
        await NotificationService.cancelGiftCard(id);
      } catch (_) { /* Notifications may be unavailable on this device. */ }
      await MediaStorageService.deleteIfManaged(
        item['customImage']?.toString(),
      );
    }
    await cardsBox.delete(key);
  }
}
