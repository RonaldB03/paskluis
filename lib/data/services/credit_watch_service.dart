import 'dart:convert';

class StoreCredit {
  final String name;
  final List<Map<String, dynamic>> gifts;
  final List<Map<String, dynamic>> loyalty;
  const StoreCredit(this.name, this.gifts, this.loyalty);
  int get cents => gifts.fold(
    0,
    (total, card) =>
        total + (CreditWatchService.cents(card['currentBalance']) ?? 0),
  );
}

abstract final class CreditWatchService {
  static int? cents(dynamic value) {
    final match = RegExp(
      r'^(\d+)(?:[,.](\d{1,2}))?$',
    ).firstMatch(value?.toString().trim() ?? '');
    if (match == null) return null;
    return int.parse(match[1]!) * 100 +
        int.parse((match[2] ?? '').padRight(2, '0'));
  }

  static String brand(Map card) {
    final id = card['brandId']?.toString().trim() ?? '';
    return id.isNotEmpty
        ? 'id:$id'
        : 'name:${(card['name']?.toString() ?? '').trim().toLowerCase()}';
  }

  static DateTime? balanceDate(Map card) {
    final explicit = DateTime.tryParse(
      card['balanceUpdatedAt']?.toString() ?? '',
    );
    if (explicit != null) return explicit;
    try {
      final entries = jsonDecode(card['balanceHistory']?.toString() ?? '[]');
      if (entries is List && entries.isNotEmpty && entries.last is Map) {
        return DateTime.tryParse(entries.last['createdAt']?.toString() ?? '');
      }
    } catch (_) {
      /* Older cards can have no history. */
    }
    return null;
  }

  static int? daysLeft(Map card, DateTime now) {
    final expiry = DateTime.tryParse(card['expiryDate']?.toString() ?? '');
    if (expiry == null) return null;
    // UTC calendar dates avoid 23/25-hour daylight-saving days.
    return DateTime.utc(
      expiry.year,
      expiry.month,
      expiry.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  }

  static List<StoreCredit> group(Iterable<dynamic> values, {DateTime? now}) {
    final cards = values
        .whereType<Map>()
        .where((c) => c['isArchived'] != true && c['isArchived'] != 'true')
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
    final gifts = <String, List<Map<String, dynamic>>>{};
    for (final card in cards.where((c) => c['type'] == 'Cadeaukaart')) {
      if (cents(card['currentBalance']) == 0) continue;
      (gifts[brand(card)] ??= []).add(card);
    }
    final today = now ?? DateTime.now();
    int priority(Map card) => daysLeft(card, today) ?? 100000;
    final groups = gifts.entries.map((e) {
      e.value.sort((a, b) => priority(a).compareTo(priority(b)));
      return StoreCredit(
        e.value.first['name']?.toString() ?? '',
        e.value,
        cards.where((c) => c['type'] == 'Pasje' && brand(c) == e.key).toList(),
      );
    }).toList();
    groups.sort((a, b) {
      final n = priority(a.gifts.first).compareTo(priority(b.gifts.first));
      return n != 0 ? n : a.name.compareTo(b.name);
    });
    return groups;
  }
}
