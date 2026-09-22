/// Received cards belong to an account; personal offline cards belong to the device.
abstract final class CardAccessPolicy {
  static bool isReceived(Map<dynamic, dynamic> card) =>
      card['isShared'] == true || card['isShared']?.toString() == 'true';

  static bool mayKeep(Map<dynamic, dynamic> card, String? userId) =>
      !isReceived(card) ||
      (userId != null && userId.isNotEmpty && card['shareRecipientId'] == userId);

  static int ownGiftCards(Iterable<dynamic> cards) => cards.where((card) =>
      card is Map && !isReceived(card) && card['type'] == 'Cadeaukaart' &&
      card['isArchived'] != true && card['isArchived']?.toString() != 'true').length;
}
