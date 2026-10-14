import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/services/garmin_store.dart';
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
  late String target =
      service.pairedTarget ?? (Platform.isIOS ? 'apple' : 'wear');
  List<Map> wearDevices = [];
  bool connecting = false;
  String category = 'loyalty';
  String t(String nl, String en) =>
      LocaleService.languageCode == 'nl' ? nl : en;
  @override
  void initState() {
    super.initState();
    service.addListener(_changed);
    service.retryPending();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    service.removeListener(_changed);
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() => connecting = true);
    try {
      await work();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'Koppelen niet gelukt. Open PasKluis op je horloge en probeer opnieuw.',
                'Could not connect. Open PasKluis on your watch and try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => connecting = false);
    }
  }

  Future<void> _select(Map card, bool checked) async {
    final ids = service.selected(target);
    checked
        ? ids.add(card['id'].toString())
        : ids.remove(card['id'].toString());
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

  Future<void> _disconnect() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Horloge ontkoppelen?', 'Disconnect watch?')),
        content: Text(
          t(
            'Er worden daarna geen wijzigingen meer verstuurd. Passen die al op het horloge staan kunnen daar blijven staan. Wis deze op het horloge via Instellingen → Pasjes wissen.',
            'No further changes will be sent. Cards already on the watch may remain there. Erase them on the watch under Settings → Erase cards.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Annuleren', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Ontkoppelen', 'Disconnect')),
          ),
        ],
      ),
    );
    if (yes == true) await _run(service.disconnect);
  }

  Future<void> _openGarminStore() async {
    final uri = GarminStore.uri;
    if (!WatchService.betaEnabled || uri == null) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Keep pairing and selection intact when the store cannot be opened.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'Connect IQ kon niet worden geopend. Probeer het later opnieuw.',
            'Could not open Connect IQ. Please try again later.',
          ),
        ),
      ),
    );
  }

  Widget _garminInstallation() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(
            'Koppel je horloge eerst in Garmin Connect. Installeer daarna PasKluis op je horloge en open de horloge-app.',
            'Pair your watch in Garmin Connect first. Then install PasKluis on your watch and open the watch app.',
          ),
        ),
        if (GarminStore.uri != null)
          OutlinedButton.icon(
            onPressed: _openGarminStore,
            icon: const Icon(Icons.open_in_new),
            label: Text(t('PasKluis in Connect IQ', 'PasKluis in Connect IQ')),
          )
        else
          Text(
            t(
              'De Garmin-testapp wordt voorlopig via USB geïnstalleerd. De Connect IQ-download volgt zodra deze beschikbaar is.',
              'The Garmin beta is currently installed via USB. The Connect IQ download will follow when available.',
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    target = service.pairedTarget ?? target;
    final paired = service.pairedTarget != null;
    final selected = service.selected(target);
    final devices = target == 'wear'
        ? wearDevices
        : (service.status['garminDevices'] as List? ?? [])
              .whereType<Map>()
              .toList();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Smartwatch · Testversie', 'Smartwatch · Beta')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!paired) ...[
            Text(
              t('Koppel je horloge', 'Connect your watch'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              t(
                'Kies één horloge. PasKluis onthoudt je keuze totdat je het ontkoppelt.',
                'Choose one watch. PasKluis remembers it until you disconnect it.',
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                if (Platform.isIOS)
                  const ButtonSegment(
                    value: 'apple',
                    label: Text('Apple Watch'),
                  ),
                if (Platform.isAndroid)
                  const ButtonSegment(value: 'wear', label: Text('Wear OS')),
                const ButtonSegment(value: 'garmin', label: Text('Garmin')),
              ],
              selected: {target},
              onSelectionChanged: connecting
                  ? null
                  : (v) => setState(() => target = v.first),
            ),
            const SizedBox(height: 16),
            Text(
              t(
                'Installeer en open PasKluis op je horloge.',
                'Install and open PasKluis on your watch.',
              ),
            ),
            if (target == 'garmin' && WatchService.betaEnabled)
              _garminInstallation(),
            FilledButton.icon(
              icon: const Icon(Icons.watch_outlined),
              label: Text(
                target == 'apple'
                    ? t('Apple Watch koppelen', 'Connect Apple Watch')
                    : t('Horloge zoeken', 'Find watch'),
              ),
              onPressed: connecting
                  ? null
                  : () => _run(() async {
                      if (target == 'garmin') {
                        await service.chooseGarmin();
                      } else if (target == 'wear') {
                        wearDevices = await service.wearDevices();
                        if (wearDevices.isEmpty) throw StateError('No watch');
                      } else {
                        await service.pair('apple');
                      }
                    }),
            ),
            if (target != 'apple')
              for (final device in devices)
                ListTile(
                  leading: const Icon(Icons.watch),
                  title: Text(device['name']?.toString() ?? target),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: connecting
                      ? null
                      : () => _run(
                          () => service.pair(
                            target,
                            id: device['id'].toString(),
                            name: device['name']?.toString() ?? target,
                          ),
                        ),
                ),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.watch),
              title: Text(t('Gekoppeld aan', 'Connected to')),
              subtitle: Text(
                service.pairedName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              t(
                'Vink je pasjes aan. Elke wijziging wordt automatisch naar dit horloge verstuurd.',
                'Select your cards. Every change is automatically sent to this watch.',
              ),
            ),
            const SizedBox(height: 12),
            if (target == 'garmin')
              Text(
                t(
                  'Open Garmin Connect en PasKluis op je horloge om wijzigingen te ontvangen.',
                  'Open Garmin Connect and PasKluis on your watch to receive changes.',
                ),
              ),
            if (target == 'garmin' && WatchService.betaEnabled)
              _garminInstallation(),
            Card(
              child: ListTile(
                leading: Icon(
                  service.busy || service.waiting
                      ? Icons.sync
                      : Icons.check_circle_outline,
                ),
                title: Text(
                  service.busy
                      ? t('Synchroniseren…', 'Syncing…')
                      : service.waiting
                      ? t('Wacht op verbinding', 'Waiting for connection')
                      : service.locallyErased
                      ? t('Gewist op het horloge', 'Erased on watch')
                      : t('Bijgewerkt', 'Up to date'),
                ),
                subtitle: service.waiting
                    ? Text(
                        t(
                          'Je selectie is bewaard. We proberen het automatisch opnieuw.',
                          'Your selection is saved. We will retry automatically.',
                        ),
                      )
                    : null,
              ),
            ),
            if (service.error == 'invalid_cards')
              Text(
                t(
                  'Een gewijzigde code past niet meer. Pas je selectie aan.',
                  'A changed code no longer fits. Update your selection.',
                ),
              ),
            if (service.busy || connecting) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              t(
                'Je pasjes (${selected.length})',
                'Your cards (${selected.length})',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: 'loyalty',
                  icon: const Icon(Icons.credit_card),
                  label: Text(t('Pasjes', 'Cards')),
                ),
                const ButtonSegment(
                  value: 'qr',
                  icon: Icon(Icons.qr_code),
                  label: Text('QR'),
                ),
                ButtonSegment(
                  value: 'gift',
                  icon: const Icon(Icons.card_giftcard),
                  label: Text(t('Cadeau', 'Gifts')),
                ),
              ],
              selected: {category},
              onSelectionChanged: (value) =>
                  setState(() => category = value.first),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(switch (category) {
                'qr' => t('QR-codes', 'QR codes'),
                'gift' => t('Cadeaukaarten', 'Gift cards'),
                _ => t('Klantenkaarten', 'Loyalty cards'),
              }),
            ),
            if (category == 'gift')
              Text(
                t(
                  'Je kopie op het horloge kan worden besteed. Pincodes en saldo worden niet meegestuurd.',
                  'The copy on your watch can be spent. PINs and balances are not sent.',
                ),
              ),
            for (final card in cards.where(
              (card) => WatchSnapshot.category(card) == category,
            ))
              CheckboxListTile(
                title: Text(card['name']?.toString() ?? 'PasKluis'),
                secondary: Icon(
                  card['isFavorite'] == true ? Icons.star : Icons.credit_card,
                ),
                value: selected.contains(card['id'].toString()),
                onChanged: connecting ? null : (v) => _select(card, v!),
              ),
            if (!cards.any((card) => WatchSnapshot.category(card) == category))
              Text(
                t(
                  'Geen passen in deze categorie. Voeg ze eerst toe in PasKluis.',
                  'No cards in this category. Add them in PasKluis first.',
                ),
              ),
            const SizedBox(height: 12),
            Text(
              t(
                'Je maakt een extra kopie op het horloge. De appvergrendeling van je telefoon beschermt die kopie niet.',
                'This creates an extra copy on the watch. Your phone app lock does not protect it.',
              ),
            ),
            TextButton(
              onPressed: service.busy || connecting ? null : _disconnect,
              child: Text(t('Horloge ontkoppelen', 'Disconnect watch')),
            ),
          ],
        ],
      ),
    );
  }
}
