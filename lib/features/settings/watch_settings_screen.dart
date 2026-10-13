import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/services/locale_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/watch_service.dart';
import '../../data/services/watch_snapshot.dart';
import 'watch_selection_error.dart';

class WatchSettingsScreen extends StatefulWidget {
  const WatchSettingsScreen({super.key});
  @override
  State<WatchSettingsScreen> createState() => _WatchSettingsScreenState();
}

class _WatchSettingsScreenState extends State<WatchSettingsScreen> {
  final service = WatchService.instance;
  late String target = Platform.isIOS ? 'apple' : 'wear';
  String t(String nl, String en) =>
      LocaleService.languageCode == 'nl' ? nl : en;
  @override
  void initState() {
    super.initState();
    service.addListener(_changed);
    service.refresh();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    service.removeListener(_changed);
    super.dispose();
  }

  Future<void> _select(Map card, bool checked) async {
    final ids = service.selected(target);
    final id = card['id'].toString();
    checked ? ids.add(id) : ids.remove(id);
    try {
      await service.select(target, ids);
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              watchSelectionError(error, LocaleService.languageCode),
            ),
          ),
        );
      }
    }
  }

  Future<void> _forgetGarmin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          t('Garmin-verbinding vergeten?', 'Forget Garmin connection?'),
        ),
        content: Text(
          t(
            'Dit wist geen pasjes op het horloge. Een offline of verloren horloge kan de vorige kopie bewaren. Wis waar mogelijk eerst de PasKluis-app op dat horloge.',
            'This does not erase cards on the watch. An offline or lost watch may keep the previous copy. Where possible, remove the PasKluis app from that watch first.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Annuleren', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Verbinding vergeten', 'Forget connection')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await service.forgetGarmin();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('Probeer opnieuw.', 'Please try again.'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards =
        StorageService.cardsBox.values
            .whereType<Map>()
            .where(WatchSnapshot.eligible)
            .toList()
          ..sort(
            (a, b) => (a['name'] ?? '').toString().compareTo(
              (b['name'] ?? '').toString(),
            ),
          );
    final selected = service.selected(target);
    final state = Map<String, dynamic>.from(
      service.status[target] as Map? ?? {},
    );
    final devices = (service.status['garminDevices'] as List? ?? [])
        .whereType<Map>();
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Smartwatch · Testversie', 'Smartwatch · Beta')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: [
              if (Platform.isIOS)
                const ButtonSegment(value: 'apple', label: Text('Apple Watch')),
              if (Platform.isAndroid)
                const ButtonSegment(value: 'wear', label: Text('Wear OS')),
              const ButtonSegment(value: 'garmin', label: Text('Garmin')),
            ],
            selected: {target},
            onSelectionChanged: service.busy
                ? null
                : (v) => setState(() => target = v.first),
          ),
          const SizedBox(height: 20),
          Text(
            t('Je pasjes aan je pols', 'Your cards on your wrist'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            t(
              'Installeer de PasKluis-testapp op je horloge. Kies hieronder je eigen klantenkaarten en losse QR-codes. Na synchronisatie werken ze offline.',
              'Install the PasKluis beta app on your watch. Select your own loyalty cards and individual QR codes below. After syncing, they work offline.',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t(
              'Je maakt een extra kopie op het horloge. De appvergrendeling van je telefoon beschermt die kopie niet. Cadeaukaarten, PIN’s, gedeelde pasjes en QR-sets worden niet meegestuurd.',
              'This creates an extra copy on your watch. Your phone app lock does not protect it. Gift cards, PINs, shared cards and QR sets are not transferred.',
            ),
          ),
          if (target == 'garmin') ...[
            const SizedBox(height: 12),
            Text(
              t(
                'Open Garmin Connect en PasKluis op je horloge tijdens het synchroniseren. Garmin-opslag heeft niet dezelfde versleuteling als de telefoonkluis.',
                'Open Garmin Connect and PasKluis on your watch while syncing. Garmin storage does not use the same encryption as the phone vault.',
              ),
            ),
            OutlinedButton.icon(
              onPressed: service.busy ? null : service.chooseGarmin,
              icon: const Icon(Icons.watch_outlined),
              label: Text(
                t('Garmin zoeken / koppelen', 'Find / connect Garmin'),
              ),
            ),
            for (final device in devices)
              ListTile(
                leading: Icon(
                  state['device']?.toString() == device['id'].toString()
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(device['name']?.toString() ?? 'Garmin'),
                onTap: service.busy
                    ? null
                    : () async {
                        try {
                          await service.setGarmin(device['id'].toString());
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  t(
                                    'Wis eerst de vorige horlogekopie of probeer opnieuw.',
                                    'Clear the previous watch copy first or try again.',
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                      },
              ),
            if ((state['device']?.toString() ?? '').isNotEmpty &&
                state['device'] != '-1')
              TextButton(
                onPressed: service.busy ? null : _forgetGarmin,
                child: Text(t('Verbinding vergeten', 'Forget connection')),
              ),
          ],
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                state['confirmed'] == true &&
                        !service.busy &&
                        service.error == null
                    ? Icons.check_circle_outline
                    : Icons.sync,
              ),
              title: Text(
                state['confirmed'] == true &&
                        !service.busy &&
                        service.error == null
                    ? t('Door horloge bevestigd', 'Confirmed by watch')
                    : t(
                        'Nog niet door horloge bevestigd',
                        'Not yet confirmed by watch',
                      ),
              ),
              subtitle: Text(
                t(
                  'Wijzigingen en wissen zijn pas voltooid na ontvangst. Een offline horloge bewaart de vorige kopie.',
                  'Changes and erasure complete after receipt. An offline watch keeps its previous copy.',
                ),
              ),
            ),
          ),
          if (service.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                service.error == 'invalid_cards'
                    ? t(
                        'Een gewijzigde code past niet meer. De oude horlogekopie wordt gewist; pas je selectie aan.',
                        'A changed code no longer fits. The old watch copy is being cleared; update your selection.',
                      )
                    : t(
                        'Synchronisatie nog niet gelukt. Controleer de verbinding en open de horloge-app; probeer daarna opnieuw.',
                        'Sync has not completed. Check the connection and open the watch app, then try again.',
                      ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: service.busy ? null : () => service.sync(target),
                  icon: const Icon(Icons.sync),
                  label: Text(t('Synchroniseren', 'Sync')),
                ),
              ),
              IconButton(
                tooltip: t('Horlogekopie wissen', 'Erase watch copy'),
                onPressed: service.busy ? null : () => service.clear(target),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (service.busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            t(
              'Selectie (${selected.length}/12)',
              'Selection (${selected.length}/12)',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (cards.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                t(
                  'Voeg eerst een klantenkaart of losse QR-code toe.',
                  'Add a loyalty card or individual QR code first.',
                ),
              ),
            ),
          for (final card in cards)
            CheckboxListTile(
              title: Text(card['name']?.toString() ?? 'PasKluis'),
              secondary: Icon(
                card['isFavorite'] == true ? Icons.star : Icons.credit_card,
              ),
              value: selected.contains(card['id'].toString()),
              onChanged: service.busy ? null : (v) => _select(card, v!),
            ),
        ],
      ),
    );
  }
}
