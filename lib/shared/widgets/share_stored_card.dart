import 'package:flutter/material.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/storage_service.dart';
import '../../l10n/l10n.dart';
import 'card_share_dialogs.dart';

Future<void> shareStoredCard(
  BuildContext context,
  Map<String, dynamic> item,
) async {
  if (item['isShared'] == true) return;
  if (!SettingsService.cardSharingAvailable) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L10n.current.cardSharingIsTemporarilyUnavailable)),
    );
    return;
  }
  final updated = await CardShareDialogs.share(context, item);
  if (updated == null) return;
  final id = item['id']?.toString();
  if (id == null || id.isEmpty) return;
  for (final key in StorageService.cardsBox.keys) {
    final current = StorageService.cardsBox.get(key);
    if (current is Map && current['id']?.toString() == id) {
      await StorageService.saveCard(key, {
        ...current,
        'sharedCardId': updated['sharedCardId'],
        'sharedVersion': updated['sharedVersion'],
      });
      break;
    }
  }
}
