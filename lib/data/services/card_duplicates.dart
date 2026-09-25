/// Compare payloads, never names: leading zeroes and QR case are meaningful.
abstract final class CardDuplicates {
  static Set<String> codes(Map card) => {
    if ((card['code']?.toString().trim() ?? '').isNotEmpty)
      card['code'].toString().trim(),
    if (card['type'] == 'QR-set')
      ...((card['codes']?.toString() ?? '').split('|||')
          .map((code) => code.trim()).where((code) => code.isNotEmpty)),
  };

  static List<Map> find(Iterable<dynamic> cards, Map candidate, {String? excludeId}) {
    final wanted = codes(candidate);
    if (wanted.isEmpty) return [];
    return cards.whereType<Map>().where((card) =>
      (excludeId == null || card['id']?.toString() != excludeId) &&
      codes(card).intersection(wanted).isNotEmpty).toList();
  }
}
