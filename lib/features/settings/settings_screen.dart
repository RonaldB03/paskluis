import 'package:flutter/material.dart';

import '../../data/services/location_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/security_service.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/account_service.dart';
import '../account/account_screen.dart';
import '../admin/admin_tools_screen.dart';
import '../support/support_screen.dart';
import 'help_center_screen.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _appLockEnabled;
  late bool _extraClearEnabled;
  late bool _locationCardsEnabled;
  late int _nearbyRadiusMeters;
  late bool _favoritesFirst;
  late bool _showFavoritesSection;
  late bool _showNearbySection;
  late bool _nearbyLoyaltyCardsFirst;
  late String _cardSortOrder;
  late String _defaultStartTab;
  late bool _autoBrightnessEnabled;
  late bool _keepScreenAwakeEnabled;
  late bool _hideSensitiveCodes;
  late bool _giftExpiryNotificationsEnabled;
  bool _savingLock = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _readSettings();
    SettingsService.refreshRemoteConfig().then((_) {
      if (!mounted) return;
      setState(_readSettings);
    });
    _loadAdminStatus();
  }

  Future<void> _loadAdminStatus() async {
    try {
      final isAdmin = await AccountService.isCurrentUserAdmin();
      if (mounted) setState(() => _isAdmin = isAdmin);
    } catch (_) {
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  void _readSettings() {
    _appLockEnabled = SettingsService.appLockEnabled;
    _extraClearEnabled = SettingsService.extraClearEnabled;
    _locationCardsEnabled = SettingsService.locationCardsEnabled;
    _nearbyRadiusMeters = SettingsService.nearbyRadiusMeters;
    _favoritesFirst = SettingsService.favoritesFirst;
    _showFavoritesSection = SettingsService.showFavoritesSection;
    _showNearbySection = SettingsService.showNearbySection;
    _nearbyLoyaltyCardsFirst = SettingsService.nearbyLoyaltyCardsFirst;
    _cardSortOrder = SettingsService.cardSortOrder;
    _defaultStartTab = SettingsService.defaultStartTab;
    _autoBrightnessEnabled = SettingsService.autoBrightnessEnabled;
    _keepScreenAwakeEnabled = SettingsService.keepScreenAwakeEnabled;
    _hideSensitiveCodes = SettingsService.hideSensitiveCodes;
    _giftExpiryNotificationsEnabled =
        SettingsService.giftExpiryNotificationsEnabled;
  }

  Future<void> _changeLocationCards(bool enabled) async {
    await SettingsService.setLocationCardsEnabled(enabled);
    if (!mounted) return;
    setState(() => _locationCardsEnabled = enabled);
    if (!enabled) return;
    final result = await LocationService.resolve(requestPermission: true);
    if (!mounted || result.state == LocationAccessState.ready) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Locatie staat aan in PasKluis. Geef ook toestemming in de instellingen van je telefoon.',
        ),
      ),
    );
  }

  Future<void> _changeExtraClear(bool enabled) async {
    await SettingsService.setExtraClearEnabled(enabled);
    if (mounted) setState(() => _extraClearEnabled = enabled);
  }

  Future<void> _changeAppLock(bool enabled) async {
    if (_savingLock) return;
    setState(() => _savingLock = true);
    if (enabled) {
      final authenticated = await SecurityService.authenticate(
        reason: 'Bevestig je identiteit om app-vergrendeling in te schakelen',
      );
      if (!authenticated) {
        if (mounted) setState(() => _savingLock = false);
        return;
      }
    }
    await SettingsService.setAppLockEnabled(enabled);
    if (!mounted) return;
    setState(() {
      _appLockEnabled = enabled;
      _savingLock = false;
    });
  }

  Future<void> _changeExpiryNotifications(bool enabled) async {
    await SettingsService.setGiftExpiryNotificationsEnabled(enabled);
    if (enabled) await NotificationService.requestPermission();
    for (final card in StorageService.cardsBox.values.whereType<Map>()) {
      await NotificationService.syncGiftCard(card);
    }
    if (mounted) {
      setState(() => _giftExpiryNotificationsEnabled = enabled);
    }
  }

  Future<void> _chooseRadius() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Afstand tot winkel',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Wanneer beschouwt PasKluis een opgeslagen kaart als dichtbij?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              for (final meters in const [100, 250, 500, 1000])
                RadioListTile<int>(
                  value: meters,
                  groupValue: _nearbyRadiusMeters,
                  title: Text(meters == 1000 ? '1 kilometer' : '$meters meter'),
                  onChanged: (value) => Navigator.pop(context, value),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    await SettingsService.setNearbyRadiusMeters(selected);
    if (mounted) setState(() => _nearbyRadiusMeters = selected);
  }

  Future<void> _chooseSorting() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Standaard sortering',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final option in const {
                'recent': 'Laatst gebruikt',
                'added': 'Laatst toegevoegd',
                'alphabetical': 'Alfabetisch',
              }.entries)
                RadioListTile<String>(
                  value: option.key,
                  groupValue: _cardSortOrder,
                  title: Text(option.value),
                  onChanged: (value) => Navigator.pop(context, value),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    await SettingsService.setCardSortOrder(selected);
    if (mounted) setState(() => _cardSortOrder = selected);
  }

  Future<void> _chooseStartTab() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Standaard startscherm',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final option in const {
                'home': 'Home',
                'cards': 'Klantenkaarten',
                'qr': 'QR-codes',
                'gift': 'Cadeaukaarten',
              }.entries)
                RadioListTile<String>(
                  value: option.key,
                  groupValue: _defaultStartTab,
                  title: Text(option.value),
                  onChanged: (value) => Navigator.pop(context, value),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    await SettingsService.setDefaultStartTab(selected);
    if (mounted) setState(() => _defaultStartTab = selected);
  }

  String get _radiusLabel =>
      _nearbyRadiusMeters == 1000 ? '1 km' : '$_nearbyRadiusMeters m';

  String get _sortLabel => switch (_cardSortOrder) {
        'alphabetical' => 'Alfabetisch',
        'added' => 'Laatst toegevoegd',
        _ => 'Laatst gebruikt',
      };

  String get _startTabLabel => switch (_defaultStartTab) {
        'cards' => 'Klantenkaarten',
        'qr' => 'QR-codes',
        'gift' => 'Cadeaukaarten',
        _ => 'Home',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F7),
      appBar: AppBar(
        title: const Text('Instellingen'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF28242C),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 32),
        children: [
          if (SettingsService.locationCardsAvailable)
            _SettingsSection(
              title: 'Slimme kaarten',
              children: [
                _SettingsSwitchTile(
                  icon: Icons.location_on_outlined,
                  iconColor: const Color(0xFF286DC8),
                  iconBackground: const Color(0xFFE7F0FF),
                  title: 'Kaarten op basis van locatie',
                  subtitle: 'Toon de juiste kaart bij een winkel in de buurt',
                  value: _locationCardsEnabled,
                  onChanged: _changeLocationCards,
                ),
                if (_locationCardsEnabled)
                  _SettingsTile(
                    icon: Icons.radar_rounded,
                    iconColor: const Color(0xFF7046B8),
                    iconBackground: const Color(0xFFEFE8FF),
                    title: 'Afstand',
                    subtitle: 'Hoe dichtbij een winkel moet zijn',
                    value: _radiusLabel,
                    onTap: _chooseRadius,
                  ),
                _SettingsSwitchTile(
                  icon: Icons.near_me_outlined,
                  iconColor: const Color(0xFF286DC8),
                  iconBackground: const Color(0xFFE7F0FF),
                  title: 'Dichtstbijzijnde klantenkaarten bovenaan',
                  subtitle: _locationCardsEnabled
                      ? 'Binnen de gekozen afstand: eerst dichtbij, daarna je favorieten en normale sortering'
                      : 'Zet kaarten op basis van locatie aan om deze optie te gebruiken',
                  value: _nearbyLoyaltyCardsFirst,
                  onChanged: !_locationCardsEnabled ? null : (value) async {
                    await SettingsService.setNearbyLoyaltyCardsFirst(value);
                    if (mounted) {
                      setState(() => _nearbyLoyaltyCardsFirst = value);
                    }
                  },
                ),
              ],
            ),
          _SettingsSection(
            title: 'Kaarten en weergave',
            children: [
              _SettingsSwitchTile(
                icon: Icons.star_outline_rounded,
                iconColor: const Color(0xFFA26D00),
                iconBackground: const Color(0xFFFFF2CC),
                title: 'Favorieten bovenaan',
                subtitle: _locationCardsEnabled && _nearbyLoyaltyCardsFirst
                    ? 'Favorieten volgen na klantenkaarten in de buurt'
                    : 'Je belangrijkste kaarten als eerste',
                value: _favoritesFirst,
                onChanged: (value) async {
                  await SettingsService.setFavoritesFirst(value);
                  if (mounted) setState(() => _favoritesFirst = value);
                },
              ),
              _SettingsSwitchTile(
                icon: Icons.dashboard_customize_outlined,
                iconColor: const Color(0xFFD51B46),
                iconBackground: const Color(0xFFFFE5E9),
                title: 'Favorietenblok op Home',
                subtitle: 'Toon een apart overzicht met favoriete kaarten',
                value: _showFavoritesSection,
                onChanged: (value) async {
                  await SettingsService.setShowFavoritesSection(value);
                  if (mounted) setState(() => _showFavoritesSection = value);
                },
              ),
              if (SettingsService.locationCardsAvailable)
                _SettingsSwitchTile(
                  icon: Icons.near_me_outlined,
                  iconColor: const Color(0xFF286DC8),
                  iconBackground: const Color(0xFFE7F0FF),
                  title: 'In de buurt op Home',
                  subtitle: _locationCardsEnabled
                      ? 'Toon een apart overzicht met klantenkaarten in de buurt'
                      : 'Het blok verschijnt zodra kaarten op basis van locatie aanstaat',
                  value: _showNearbySection,
                  onChanged: (value) async {
                    await SettingsService.setShowNearbySection(value);
                    if (mounted) setState(() => _showNearbySection = value);
                  },
                ),
              _SettingsTile(
                icon: Icons.swap_vert_rounded,
                iconColor: const Color(0xFF23814A),
                iconBackground: const Color(0xFFDDF5E5),
                title: 'Standaard sortering',
                subtitle: 'Volgorde in je kaartenoverzicht',
                value: _sortLabel,
                onTap: _chooseSorting,
              ),
              _SettingsTile(
                icon: Icons.home_outlined,
                iconColor: const Color(0xFF286DC8),
                iconBackground: const Color(0xFFE7F0FF),
                title: 'Standaard startscherm',
                subtitle: 'Open PasKluis direct op jouw favoriete onderdeel',
                value: _startTabLabel,
                onTap: _chooseStartTab,
              ),
              _SettingsSwitchTile(
                icon: Icons.visibility_outlined,
                iconColor: const Color(0xFF7046B8),
                iconBackground: const Color(0xFFEFE8FF),
                title: 'Extra duidelijk',
                subtitle: 'Grotere tekst, hoger contrast en grotere kaartvakken',
                value: _extraClearEnabled,
                onChanged: _changeExtraClear,
              ),
            ],
          ),
          _SettingsSection(
            title: 'Tijdens gebruik',
            children: [
              _SettingsSwitchTile(
                icon: Icons.light_mode_outlined,
                iconColor: const Color(0xFFA26D00),
                iconBackground: const Color(0xFFFFF2CC),
                title: 'Helderheid automatisch verhogen',
                subtitle: 'Barcodes zijn zo makkelijker te scannen',
                value: _autoBrightnessEnabled,
                onChanged: (value) async {
                  await SettingsService.setAutoBrightnessEnabled(value);
                  if (mounted) setState(() => _autoBrightnessEnabled = value);
                },
              ),
              _SettingsSwitchTile(
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFF7046B8),
                iconBackground: const Color(0xFFEFE8FF),
                title: 'Scherm wakker houden',
                subtitle: 'Voorkom dat het scherm uitgaat bij een kaart',
                value: _keepScreenAwakeEnabled,
                onChanged: (value) async {
                  await SettingsService.setKeepScreenAwakeEnabled(value);
                  if (mounted) setState(() => _keepScreenAwakeEnabled = value);
                },
              ),
              if (SettingsService.giftExpiryNotificationsAvailable)
                _SettingsSwitchTile(
                  icon: Icons.notifications_active_outlined,
                  iconColor: const Color(0xFFD51B46),
                  iconBackground: const Color(0xFFFFE5E9),
                  title: 'Cadeaukaartherinneringen',
                  subtitle: 'Meldingen vóór de vervaldatum',
                  value: _giftExpiryNotificationsEnabled,
                  onChanged: _changeExpiryNotifications,
                ),
            ],
          ),
          _SettingsSection(
            title: 'Beveiliging en privacy',
            children: [
              _SettingsSwitchTile(
                icon: Icons.face_rounded,
                iconColor: const Color(0xFF23814A),
                iconBackground: const Color(0xFFDDF5E5),
                title: 'Vergrendel PasKluis',
                subtitle: 'Gebruik Face ID, biometrie of je toestelcode',
                value: _appLockEnabled,
                onChanged: _savingLock ? null : _changeAppLock,
              ),
              _SettingsSwitchTile(
                icon: Icons.visibility_off_outlined,
                iconColor: const Color(0xFFD51B46),
                iconBackground: const Color(0xFFFFE5E9),
                title: 'Pincodes standaard verbergen',
                subtitle: 'Toon gevoelige codes pas na bevestiging',
                value: _hideSensitiveCodes,
                onChanged: (value) async {
                  await SettingsService.setHideSensitiveCodes(value);
                  if (mounted) setState(() => _hideSensitiveCodes = value);
                },
              ),
              _SettingsTile(
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFF286DC8),
                iconBackground: const Color(0xFFE7F0FF),
                title: 'Privacy en gegevens',
                subtitle: 'Bekijk wat PasKluis wel en niet bewaart',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Account en hulp',
            children: [
              _SettingsTile(
                icon: Icons.workspace_premium_outlined,
                iconColor: const Color(0xFFA26D00),
                iconBackground: const Color(0xFFFFF2CC),
                title: 'Account en PasKluis Plus',
                subtitle: 'Inloggen, Plus-status en accountbeheer',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.support_agent_rounded,
                iconColor: const Color(0xFFD51B46),
                iconBackground: const Color(0xFFFFE5E9),
                title: 'Klantenservice',
                subtitle: 'Stel een vraag of bekijk eerdere gesprekken',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SupportScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                iconColor: const Color(0xFF7046B8),
                iconBackground: const Color(0xFFEFE8FF),
                title: 'Hulp en uitleg',
                subtitle: 'Uitleg en veelgestelde vragen',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                ),
              ),
              if (_isAdmin)
                _SettingsTile(
                  icon: Icons.admin_panel_settings_rounded,
                  iconColor: const Color(0xFFD51B46),
                  iconBackground: const Color(0xFFFFE5E9),
                  title: 'Beheerder',
                  subtitle: 'Aparte beheerfuncties voor PasKluis',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminToolsScreen()),
                  ),
                ),
              _SettingsTile(
                icon: Icons.phone_iphone_rounded,
                iconColor: const Color(0xFF286DC8),
                iconBackground: const Color(0xFFE7F0FF),
                title: 'Gegevens op dit apparaat',
                subtitle: '${StorageService.cardsBox.length} kaarten lokaal opgeslagen',
              ),
            ],
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'PasKluis versie 1.4.1 (40)',
                style: TextStyle(color: Color(0xFF77717D), fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 0, 0, 7),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF77717D),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index < children.length - 1)
                    const Divider(height: 1, indent: 58),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 62,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: _SettingsIcon(
        icon: icon,
        color: iconColor,
        background: iconBackground,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null
          ? value == null
              ? null
              : Text(value!, style: const TextStyle(color: Color(0xFF77717D)))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null)
                  Text(value!, style: const TextStyle(color: Color(0xFF77717D))),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A858F)),
              ],
            ),
      onTap: onTap,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      secondary: _SettingsIcon(
        icon: icon,
        color: iconColor,
        background: iconBackground,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      activeColor: const Color(0xFFD51B46),
      onChanged: onChanged,
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;

  const _SettingsIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}
