import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/card_share_service.dart';
import '../../data/services/locale_service.dart';

/// Never presents a local change as saved while the server rejected it.
Future<Map<String, dynamic>?> saveSharedCardWithFeedback(
  BuildContext context,
  Map<String, dynamic> card,
) async {
  final nl = LocaleService.languageCode == 'nl';
  while (context.mounted) {
    try {
      return await CardShareService.updateSharedCard(card);
    } catch (error) {
      if (!context.mounted) return null;
      final conflict =
          error is PostgrestException &&
          RegExp(
            r'version|conflict|changed|gewijzigd',
            caseSensitive: false,
          ).hasMatch(error.message);
      final retry = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(nl ? 'Wijziging niet opgeslagen' : 'Change not saved'),
          content: Text(
            conflict
                ? (nl
                      ? 'Deze kaart is intussen gewijzigd. Sluit de kaart, ververs je kaarten en controleer het actuele saldo voordat je opnieuw bewerkt.'
                      : 'This card changed in the meantime. Close it, refresh your cards and check the current balance before editing again.')
                : (nl
                      ? 'De gedeelde kaart kon niet worden bijgewerkt. Controleer je verbinding. Je kunt deze wijziging opnieuw proberen of annuleren.'
                      : 'The shared card could not be updated. Check your connection. You can retry this change or cancel it.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(nl ? 'Sluiten' : 'Close'),
            ),
            if (!conflict)
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(nl ? 'Opnieuw proberen' : 'Retry'),
              ),
          ],
        ),
      );
      if (retry != true) return null;
    }
  }
  return null;
}
