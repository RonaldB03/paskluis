import 'storage_service.dart';

/// Membership lives on the card so normal encrypted backups carry it too.
abstract final class CardFolders {
  static String name(Map card) => card['folderName']?.toString().trim() ?? '';
  static List<String> names(Iterable<dynamic> cards) =>
      cards.whereType<Map>().map(name).where((n) => n.isNotEmpty).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  static Future<void> assign(Set<dynamic> keys, String folder, {String? replacing}) async {
    final revision = StorageService.accountRevision;
    for (final key in StorageService.cardsBox.keys.toList()) {
      if (revision != StorageService.accountRevision) throw StateError('Account changed');
      final card = StorageService.cardsBox.get(key);
      if (card is! Map) continue;
      if (!keys.contains(key) && (replacing == null || name(card) != replacing)) continue;
      await StorageService.saveCard(key, {
        ...card,
        'folderName': keys.contains(key) ? folder : '',
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
    await StorageService.cardsBox.flush();
  }
}
