import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/account_service.dart';
import '../../data/services/card_share_service.dart';
import '../../features/account/account_screen.dart';

abstract final class CardShareDialogs {
  static Future<Map<String, dynamic>?> share(
    BuildContext context,
    Map<String, dynamic> card,
  ) async {
    if (AccountService.currentUser == null) {
      final open = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title:  Text(L10n.current.signInRequired),
          content:  Text(
            L10n.current.signInWithYourPaskluisAccountTo,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:  Text(L10n.current.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child:  Text(L10n.current.signIn),
            ),
          ],
        ),
      );
      if (open == true && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AccountScreen()),
        );
      }
      if (AccountService.currentUser == null) return null;
    }

    try {
      final plus = await AccountService.loadPlusStatus();
      if (!plus.isActive) {
        throw  AuthException(
          L10n.current.sharingIsOnlyAvailableWithPaskluisPlus,
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, error);
      return null;
    }

    if (card['type'] == 'Cadeaukaart') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD51B46),
            size: 40,
          ),
          title:  Text(L10n.current.shareTheEntireGiftCard),
          content:  Text(
            L10n.current.theRecipientWillAlsoReceiveThePin,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:  Text(L10n.current.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child:  Text(L10n.current.continue749),
            ),
          ],
        ),
      );
      if (confirmed != true) return null;
    }

    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(
          Icons.person_add_alt_1_rounded,
          color: Color(0xFFD51B46),
          size: 38,
        ),
        title: Text(L10n.current.share750((_typeLabel(card)).toString())),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration:  InputDecoration(
            labelText: L10n.current.recipientSEmailAddress,
            hintText: L10n.current.nameExampleCom,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:  Text(L10n.current.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child:  Text(L10n.current.share),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || !email.contains('@')) return null;

    try {
      final share = await CardShareService.shareWithEmail(card, email);
      final updated = Map<String, dynamic>.from(card);
      updated['sharedCardId'] = share['shared_card_id']?.toString() ?? '';
      updated['sharedVersion'] = share['version'] ?? 1;
      if (context.mounted) {
        final canEdit = share['recipient_can_edit'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              canEdit
                  ? L10n.current.cardSharedWithYouCanBothEdit((email).toString())
                  : L10n.current.cardSharedWithAsViewOnly((email).toString()),
            ),
          ),
        );
      }
      return updated;
    } catch (error) {
      if (context.mounted) _showError(context, error);
      return null;
    }
  }

  static Future<void> manage(
    BuildContext context,
    Map<String, dynamic> card,
  ) async {
    try {
      final shares = await CardShareService.outgoingForCard(
        card['id']?.toString() ?? '',
      );
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 Text(
                  L10n.current.sharedAccess,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                if (shares.isEmpty)
                   Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(L10n.current.thisCardHasNotBeenSharedWith),
                  )
                else
                  ...shares.map(
                    (share) => ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_rounded),
                      ),
                      title: Text(
                        share['recipient_email']?.toString() ?? '',
                      ),
                      subtitle:  Text(
                        L10n.current.viewOnlyWithoutPlusEditableWithPlus,
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          await CardShareService.revokeShare(
                            share['id']?.toString() ?? '',
                          );
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(
                                content: Text(L10n.current.sharedAccessHasBeenStopped),
                              ),
                            );
                          }
                        },
                        child:  Text(L10n.current.stop),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  static String _typeLabel(Map<String, dynamic> card) => switch (
        card['type']?.toString()
      ) {
        'Cadeaukaart' => L10n.current.cardTypeGift,
        'QR-code' || 'QR-set' => L10n.current.qrCode,
        _ => L10n.current.cardTypeLoyalty,
      };

  static void _showError(BuildContext context, Object error) {
    final message = L10n.current.pleaseTryAgain;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
