import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Owns images selected by the user.
///
/// ImagePicker may return a temporary/cache path. Persisting that path directly
/// makes logos disappear when the operating system clears its cache.
class MediaStorageService {
  static const _directoryName = 'card_images';

  static Future<String> persistImage(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException(
        'De gekozen afbeelding bestaat niet meer.',
      );
    }

    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, _directoryName));
    await directory.create(recursive: true);

    final extension = path.extension(sourcePath).toLowerCase();
    final safeExtension = extension.isEmpty ? '.jpg' : extension;
    final filename = '${DateTime.now().microsecondsSinceEpoch}$safeExtension';
    final destination = File(path.join(directory.path, filename));

    await source.copy(destination.path);
    return destination.path;
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
}
