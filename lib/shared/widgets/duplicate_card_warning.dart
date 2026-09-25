import 'package:flutter/material.dart';
import '../../data/services/card_duplicates.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/locale_service.dart';

Future<bool> confirmDuplicateCard(BuildContext context, Map candidate) async {
  final matches = CardDuplicates.find(StorageService.cardsBox.values, candidate);
  if (matches.isEmpty) return true;
  final nl = LocaleService.languageCode == 'nl';
  return await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
    title: Text(nl ? 'Deze code staat al in je kluis' : 'This code is already in your vault'),
    content: SingleChildScrollView(child: Text(
      '${nl ? 'Dezelfde code staat op:' : 'The same code appears on:'}\n\n'
      '${matches.take(5).map((c) => c['name']?.toString() ?? '').join('\n')}\n\n'
      '${nl ? 'Wil je de kaart toch toevoegen?' : 'Add the card anyway?'}')),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dialogContext, false),
        child: Text(nl ? 'Terug' : 'Go back')),
      FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
        child: Text(nl ? 'Toch toevoegen' : 'Add anyway')),
    ],
  )) ?? false;
}
