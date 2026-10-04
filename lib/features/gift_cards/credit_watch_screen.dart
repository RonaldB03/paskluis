import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../data/services/credit_watch_service.dart';
import '../../data/services/locale_service.dart';
import '../../data/services/storage_service.dart';
import '../cards/card_view_screen.dart';
import 'gift_card_view_screen.dart';

class CreditWatchScreen extends StatelessWidget {
  const CreditWatchScreen({super.key});
  String t(String nl, String en) =>
      LocaleService.languageCode == 'nl' ? nl : en;
  String money(int cents) => NumberFormat.currency(
    locale: LocaleService.languageCode,
    symbol: '€',
  ).format(cents / 100);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('Tegoedbewaker', 'Credit Watch'))),
    body: ValueListenableBuilder(
      valueListenable: StorageService.cardsBox.listenable(),
      builder: (context, box, _) {
        final groups = CreditWatchService.group(box.values);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              t('Gebruik je tegoed op tijd', 'Use your credit in time'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              t(
                'Saldo’s werk je zelf bij. Controleer het saldo bij de winkel; dit overzicht is geen live saldo.',
                'You update balances yourself. Check with the store; these are not live balances.',
              ),
            ),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  t(
                    'Geen actieve cadeaukaarten met onbekend of resterend tegoed.',
                    'No active gift cards with unknown or remaining credit.',
                  ),
                ),
              ),
            for (final group in groups)
              Card(
                margin: const EdgeInsets.only(top: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t(
                          'Geregistreerd tegoed: ${money(group.cents)}',
                          'Recorded credit: ${money(group.cents)}',
                        ),
                      ),
                      if (group.gifts.any(
                        (card) =>
                            CreditWatchService.cents(card['currentBalance']) ==
                            null,
                      ))
                        Text(
                          t(
                            'Onbekende saldi zijn niet meegerekend.',
                            'Unknown balances are not included.',
                          ),
                        ),
                      if (group.gifts.any(
                        (card) =>
                            (CreditWatchService.daysLeft(
                                  card,
                                  DateTime.now(),
                                ) ??
                                0) <
                            0,
                      ))
                        Text(
                          t(
                            'Inclusief kaarten met verstreken vervaldatum; vraag de winkel of deze nog geldig zijn.',
                            'Includes cards past their expiry date; check validity with the store.',
                          ),
                        ),
                      if (group.loyalty.isNotEmpty)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.credit_card),
                          label: Text(
                            t('Toon klantenkaart', 'Show loyalty card'),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CardViewScreen(
                                items: group.loyalty,
                                initialIndex: 0,
                              ),
                            ),
                          ),
                        ),
                      for (final card in group.gifts)
                        _gift(context, card, group.gifts),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
  Widget _gift(
    BuildContext context,
    Map<String, dynamic> card,
    List<Map<String, dynamic>> cards,
  ) {
    final days = CreditWatchService.daysLeft(card, DateTime.now());
    final updated = CreditWatchService.balanceDate(card);
    final amount = CreditWatchService.cents(card['currentBalance']);
    final date = updated == null
        ? t(
            'Nog geen saldocontrole vastgelegd',
            'No balance confirmation recorded',
          )
        : DateFormat.yMd(LocaleService.languageCode).format(updated.toLocal());
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            amount == null
                ? t('Saldo onbekend', 'Balance unknown')
                : money(amount),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(t('Saldo bijgewerkt: $date', 'Balance updated: $date')),
          if (days != null)
            Text(
              days < 0
                  ? t('Vervaldatum verstreken', 'Expiry date passed')
                  : days == 0
                  ? t('Vervalt vandaag', 'Expires today')
                  : t('Vervalt over $days dagen', 'Expires in $days days'),
              style: TextStyle(
                color: days <= 7 ? Theme.of(context).colorScheme.error : null,
              ),
            ),
          FilledButton.icon(
            icon: const Icon(Icons.card_giftcard),
            label: Text(t('Gebruik cadeaukaart', 'Use gift card')),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GiftCardViewScreen(
                  items: cards,
                  initialIndex: cards.indexOf(card),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
