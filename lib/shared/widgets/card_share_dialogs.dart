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
          title: const Text('Inloggen vereist'),
          content: const Text(
            'Log in met je PasKluis-account om kaarten veilig per e-mailadres te delen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Inloggen'),
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
        throw const AuthException(
          'Delen is alleen beschikbaar met PasKluis Plus.',
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
          title: const Text('Volledige cadeaukaart delen?'),
          content: const Text(
            'De ontvanger krijgt ook de pincode of krascode en kan het volledige saldo gebruiken.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Doorgaan'),
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
        title: Text('${_typeLabel(card)} delen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'E-mailadres ontvanger',
            hintText: 'naam@voorbeeld.nl',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Delen'),
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
                  ? 'Kaart gedeeld met $email. Jullie kunnen de kaart allebei bewerken.'
                  : 'Kaart gedeeld met $email als alleen-lezen.',
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
                const Text(
                  'Gedeelde toegang',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                if (shares.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Deze kaart is nog met niemand gedeeld.'),
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
                      subtitle: const Text(
                        'Zonder Plus alleen-lezen; met Plus bewerkbaar',
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
                              const SnackBar(
                                content: Text('Gedeelde toegang is gestopt.'),
                              ),
                            );
                          }
                        },
                        child: const Text('Stoppen'),
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
        'Cadeaukaart' => 'Cadeaukaart',
        'QR-code' || 'QR-set' => 'QR-code',
        _ => 'Klantenkaart',
      };

  static void _showError(BuildContext context, Object error) {
    var message = error.toString();
    message = message
        .replaceFirst('AuthException(message: ', '')
        .replaceFirst('PostgrestException(message: ', '')
        .split(', code:')
        .first;
    if (message.endsWith(')')) message = message.substring(0, message.length - 1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
