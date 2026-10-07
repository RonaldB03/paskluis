import 'package:flutter/material.dart';
import '../../data/services/gift_store_reminder_service.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/location_service.dart';
import '../../l10n/l10n.dart';

class GiftStoreReminderSettings extends StatefulWidget {
  const GiftStoreReminderSettings({super.key});
  @override
  State<GiftStoreReminderSettings> createState() =>
      _GiftStoreReminderSettingsState();
}

class _GiftStoreReminderSettingsState extends State<GiftStoreReminderSettings>
    with WidgetsBindingObserver {
  bool _busy = false;
  String t(String nl, String en) =>
      L10n.current.localeName.startsWith('nl') ? nl : en;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  Future<void> change(bool enabled) async {
    setState(() => _busy = true);
    try {
      if (enabled) {
        final yes = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              t('Cadeaukaart bij een winkel', 'Gift card near a store'),
            ),
            content: Text(
              t(
                'Ontvang rond 100 meter van een opgeslagen winkel een herinnering aan je cadeaukaart, ook met gesloten app. Dit vraagt toestemming voor meldingen en locatie op Altijd. Maximaal één melding per winkel per 24 uur. Het saldo houd je zelf bij. Open PasKluis regelmatig om de winkels in je omgeving en saldi bij te werken. Zonder openen stoppen de meldingen na zeven dagen.',
                'Get a gift-card reminder around 100 metres from a saved store, even with the app closed. Notifications and Always location permission are needed. At most one reminder per store every 24 hours. Balances are entered by you. Open PasKluis regularly to refresh nearby stores and balances. Reminders stop after seven days without opening.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(L10n.current.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t('Inschakelen', 'Enable')),
              ),
            ],
          ),
        );
        if (yes != true || !mounted) return;
        await SettingsService.setLocationCardsEnabled(true);
        if (!await GiftStoreReminderService.instance.requestPermission()) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  t(
                    'Sta meldingen en locatie toe via de iPhone-instellingen.',
                    'Allow notifications and location in iPhone Settings.',
                  ),
                ),
              ),
            );
          return;
        }
      }
      await SettingsService.setNearbyGiftNotificationsEnabled(enabled);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'De instelling kon niet worden toegepast. Probeer opnieuw.',
                'Could not apply the setting. Please try again.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    if (!GiftStoreReminderService.supported) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: SettingsService.settingsRevision,
      builder: (context, _, child) => Column(
        children: [
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.near_me_outlined),
            title: Text(
              t('Cadeaukaart bij een winkel', 'Gift card near a store'),
            ),
            subtitle: Text(
              t(
                'Rond 100 meter. Maximaal eenmaal per winkel per 24 uur. Voor opgeslagen winkels in je laatst opgehaalde omgeving.',
                'Around 100 metres. At most once per store every 24 hours. For saved stores in your last refreshed area.',
              ),
            ),
            value: SettingsService.nearbyGiftNotificationsEnabled,
            onChanged: _busy ? null : change,
          ),
          if (SettingsService.nearbyGiftNotificationsEnabled) ...[
            FutureBuilder<String>(
              future: GiftStoreReminderService.instance.permission(),
              builder: (context, state) => ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(
                  state.data == 'always' && SettingsService.locationCardsEnabled
                      ? t(
                          'Achtergrondlocatie toegestaan',
                          'Background location allowed',
                        )
                      : t(
                          'Controleer locatietoestemming',
                          'Check location permission',
                        ),
                ),
                subtitle: Text(
                  t(
                    'Schakel locatie in PasKluis in en kies op je iPhone bij Locatie: Altijd. Sta ook meldingen toe.',
                    'Enable location in PasKluis and choose Always in iPhone location settings. Allow notifications too.',
                  ),
                ),
                onTap: () => LocationService.openAppSettings(),
              ),
            ),
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(
                t(
                  'Saldo in winkelmelding tonen',
                  'Show balance in store reminder',
                ),
              ),
              subtitle: Text(
                t(
                  'Uit: alleen melden dat je een cadeaukaart hebt.',
                  'Off: only say that you have a gift card.',
                ),
              ),
              value: SettingsService.nearbyGiftShowAmount,
              onChanged: (value) =>
                  SettingsService.setNearbyGiftShowAmount(value),
            ),
          ],
        ],
      ),
    );
  }
}
