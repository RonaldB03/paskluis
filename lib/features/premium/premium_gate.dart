import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../data/services/account_service.dart';
import '../../data/services/storage_service.dart';
import '../account/account_screen.dart';

abstract final class PremiumGate {
  static int get giftCardCount => StorageService.cardsBox.values.where((item) {
        return item is Map &&
            item['type'] == 'Cadeaukaart' &&
            item['isArchived'] != true &&
            item['isArchived']?.toString() != 'true';
      }).length;

  static Future<bool> canAddGiftCard(BuildContext context) async {
    // Everyone can actively use one gift card for free.
    if (giftCardCount < 1) return true;

    var status = PlusStatus.inactive;
    if (AccountService.currentUser != null) {
      try {
        status = await AccountService.loadPlusStatus();
      } catch (_) {
        // A failed status refresh must never affect existing local cards.
      }
    }
    if (status.isActive) return true;
    if (!context.mounted) return false;

    final openAccount = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.workspace_premium_rounded,
          color: Color(0xFFD5A021),
          size: 42,
        ),
        title:  Text(
          L10n.current.storeMoreGiftCards,
          textAlign: TextAlign.center,
        ),
        content:  Text(
          L10n.current.storeOneGiftCardForFreeWith,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child:  Text(L10n.current.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              AccountService.currentUser == null
                  ? L10n.current.signInOrRegister
                  : L10n.current.viewPlusStatus,
            ),
          ),
        ],
      ),
    );

    if (openAccount == true && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AccountScreen()),
      );

      if (AccountService.currentUser != null) {
        try {
          return (await AccountService.loadPlusStatus()).isActive;
        } catch (_) {
          return false;
        }
      }
    }
    return false;
  }
}
