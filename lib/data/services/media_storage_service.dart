import 'package:paskluis_v1/l10n/l10n.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Owns images selected by the user.
///
/// ImagePicker may return a temporary/cache path. Persisting that path directly
/// makes logos disappear when the operating system clears its cache.
class MediaStorageService {
  static const _directoryName = 'card_images';
  static final _cipher = AesGcm.with256bits();
  static const _header = [80, 75, 73, 77, 71, 1];
  static Future<SecretKey>? _key;
  static Future<SecretKey> _loadKey() => _key ??= () async {
    const storage = FlutterSecureStorage();
    final saved = await storage.read(key: 'paskluis_media_key_v1');
    if (saved != null) return SecretKey(base64Decode(saved));
    final key = await _cipher.newSecretKey();
    await storage.write(
      key: 'paskluis_media_key_v1',
      value: base64Encode(await key.extractBytes()),
    );
    return key;
  }().catchError((Object error, StackTrace stack) {
    _key = null;
    Error.throwWithStackTrace(error, stack);
  });

  static Future<Uint8List> readBytes(String sourcePath) async {
    final resolved = await resolveManagedImage(sourcePath);
    final bytes = await File(resolved ?? sourcePath).readAsBytes();
    if (!sourcePath.endsWith('.pkimg')) return bytes;
    if (bytes.length < 34 ||
        !List.generate(6, (i) => bytes[i] == _header[i]).every((v) => v)) {
      throw const FormatException('Invalid encrypted image');
    }
    return Uint8List.fromList(
      await _cipher.decrypt(
        SecretBox(
          bytes.sublist(18, bytes.length - 16),
          nonce: bytes.sublist(6, 18),
          mac: Mac(bytes.sublist(bytes.length - 16)),
        ),
        secretKey: await _loadKey(),
        aad: _header,
      ),
    );
  }

  static Future<String> persistBytes(List<int> bytes) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, _directoryName));
    await directory.create(recursive: true);
    final box = await _cipher.encrypt(
      bytes,
      secretKey: await _loadKey(),
      aad: _header,
    );
    final name =
        '${DateTime.now().microsecondsSinceEpoch}_${base64UrlEncode(box.nonce).replaceAll('=', '')}.pkimg';
    final target = File(path.join(directory.path, name));
    final staged = File('${target.path}.tmp');
    await staged.writeAsBytes([
      ..._header,
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ], flush: true);
    await staged.rename(target.path);
    final verified = await readBytes(target.path);
    if (!listEquals(verified, bytes)) {
      throw StateError('Image verification failed');
    }
    return target.path;
  }

  static Future<String> persistImage(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException(
        L10n.current.theSelectedImageIsNoLongerAvailable,
      );
    }

    return persistBytes(await readBytes(sourcePath));
  }

  /// iOS may assign the app container a new absolute path after an update.
  /// Rebuild the path from the stable card_images folder and filename.
  static Future<String?> resolveManagedImage(String storedPath) async {
    if (storedPath.isEmpty) return null;
    final original = File(storedPath);
    if (await original.exists()) return original.path;

    final marker = '${path.separator}$_directoryName${path.separator}';
    if (!storedPath.contains(marker)) return null;
    final documents = await getApplicationDocumentsDirectory();
    final candidate = File(
      path.join(documents.path, _directoryName, path.basename(storedPath)),
    );
    return await candidate.exists() ? candidate.path : null;
  }

  static Future<void> deleteIfManaged(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;

    final documents = await getApplicationDocumentsDirectory();
    final managedRoot = path.normalize(
      path.join(documents.path, _directoryName),
    );
    final candidate = path.normalize(imagePath);

    if (!path.isWithin(managedRoot, candidate)) return;

    final file = File(candidate);
    if (await file.exists()) await file.delete();
  }

  /// Finishes cleanup even if a previous launch stopped after committing Hive.
  static Future<void> removeUnreferencedLegacyImages(
    Iterable<String> references,
  ) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, _directoryName));
    if (!await directory.exists()) return;
    final referencedNames = references.map(path.basename).toSet();
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File ||
          entry.path.endsWith('.pkimg') ||
          entry.path.endsWith('.tmp'))
        continue;
      if (!referencedNames.contains(path.basename(entry.path)))
        await entry.delete();
    }
  }
}
