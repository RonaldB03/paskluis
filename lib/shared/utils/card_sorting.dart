/// Sorts a copy; only verified, finite store distances within the radius get
/// priority. Unknown distances retain the user's normal card ordering.
List<Map<String, dynamic>> sortLoyaltyCards(
  List<Map<String, dynamic>> cards, {
  required bool favoritesFirst,
  required String sortOrder,
  bool nearbyFirst = false,
  double nearbyRadiusMeters = 250,
  Map<String, double> distances = const {},
}) {
  double? nearbyDistance(Map<String, dynamic> card) {
    if (!nearbyFirst || card['type'] != 'Pasje') return null;
    final distance = distances[card['id']?.toString()];
    return distance != null && distance.isFinite && distance >= 0 &&
            distance <= nearbyRadiusMeters
        ? distance
        : null;
  }

  DateTime date(Map<String, dynamic> card, String key) =>
      DateTime.tryParse(card[key]?.toString() ?? '') ??
      DateTime.tryParse(card['createdAt']?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  final indexed = cards.asMap().entries.toList();
  indexed.sort((left, right) {
    final a = left.value;
    final b = right.value;
    final aDistance = nearbyDistance(a);
    final bDistance = nearbyDistance(b);
    if (aDistance != null || bDistance != null) {
      if (aDistance == null) return 1;
      if (bDistance == null) return -1;
      final result = aDistance.compareTo(bDistance);
      if (result != 0) return result;
    }
    final aFavorite = a['isFavorite'] == true;
    final bFavorite = b['isFavorite'] == true;
    if (favoritesFirst && aFavorite != bFavorite) return aFavorite ? -1 : 1;
    final result = switch (sortOrder) {
      'alphabetical' => (a['name']?.toString() ?? '').toLowerCase().compareTo(
          (b['name']?.toString() ?? '').toLowerCase()),
      'added' => date(b, 'createdAt').compareTo(date(a, 'createdAt')),
      _ => date(b, 'lastUsedAt').compareTo(date(a, 'lastUsedAt')),
    };
    return result != 0 ? result : left.key.compareTo(right.key);
  });
  return indexed.map((entry) => entry.value).toList();
}
