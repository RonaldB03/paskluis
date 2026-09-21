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
        title: const Text(
          'Meer cadeaukaarten bewaren',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Je eerste cadeaukaart is gratis. Met PasKluis Plus bewaar je '
          'onbeperkt cadeaukaarten voor € 1,99 eenmalig. Je krijgt levenslange '
          'toegang, zonder abonnement. Je kunt met Plus ook klanten- en cadeaukaarten delen.\n\n'
          'Tijdens deze test kan Plus via beheer op je account worden geactiveerd.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Niet nu'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              AccountService.currentUser == null
                  ? 'Inloggen of registreren'
                  : 'Bekijk Plus-status',
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
