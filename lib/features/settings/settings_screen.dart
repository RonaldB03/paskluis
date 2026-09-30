import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../data/services/app_menu_service.dart';
import '../../data/services/backup_service.dart';
import 'backup_actions.dart';
import 'package:paskluis_v1/l10n/l10n.dart';
import '../../shared/widgets/language_picker.dart';
import '../../data/services/locale_service.dart';
import 'package:flutter/material.dart';

import '../../data/services/location_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/security_service.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/account_service.dart';
import '../account/account_screen.dart';
import '../premium/plus_information_screen.dart';
import '../admin/admin_tools_screen.dart';
import '../support/support_screen.dart';
import 'help_center_screen.dart';
import 'privacy_screen.dart';
import 'backup_screen.dart';

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
  bool _plus = false;
  String _version = SettingsService.appVersion;
  StreamSubscription? _auth;
  int _accountRequest = 0;
  String t(String nl, String en) => LocaleService.languageCode == 'nl' ? nl : en;
  void _changed() { if (mounted) setState(_readSettings); }
  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) { _changed(); await _loadAccount(); }
  }
  Future<void> _loadAccount() async {
    final request = ++_accountRequest;
    final id = AccountService.currentUser?.id;
    if (mounted) setState(() { _plus = false; _isAdmin = false; });
    final plus = await AccountService.loadPlusStatus().catchError((Object _) => PlusStatus.inactive);
    final admin = await AccountService.isCurrentUserAdmin().catchError((Object _) => false);
    if (mounted && request == _accountRequest && id == AccountService.currentUser?.id) {
      setState(() { _plus = plus.isActive; _isAdmin = admin; });
    }
  }
  @override
  void dispose() {
    _auth?.cancel();
    BackupService.revision.removeListener(_changed);
    AppMenuService.revision.removeListener(_changed);
    SettingsService.settingsRevision.removeListener(_changed);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _readSettings();
    SettingsService.refreshRemoteConfig().then((_) {
      if (!mounted) return;
      setState(_readSettings);
    });
    BackupService.revision.addListener(_changed);
    AppMenuService.revision.addListener(_changed);
    SettingsService.settingsRevision.addListener(_changed);
    _auth = AccountService.authChanges?.listen((_) { _loadAccount(); BackupService.refresh(); });
    _loadAccount();
    BackupService.refresh();
    AppMenuService.init().then((_) { _changed(); AppMenuService.refresh(); });
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    }).catchError((Object _) {});
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
       SnackBar(
        content: Text(
          L10n.current.locationIsEnabledInPaskluisAlsoGrant,
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
        reason: L10n.current.confirmYourIdentityToEnableAppLock,
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
               Text(
                L10n.current.distanceToStore,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
               Text(
                L10n.current.whenShouldPaskluisConsiderASavedCard,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              for (final meters in const [100, 250, 500, 1000])
                RadioListTile<int>(
                  value: meters,
                  groupValue: _nearbyRadiusMeters,
                  title: Text(meters == 1000 ? L10n.current.text1Kilometre : L10n.current.metres((meters).toString())),
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
               Text(
                L10n.current.defaultSorting,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final option in  {
                'recent': L10n.current.lastUsed,
                'added': L10n.current.recentlyAdded,
                'alphabetical': L10n.current.alphabetical,
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
               Text(
                L10n.current.defaultStartScreen,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final option in  {
                'home': L10n.current.home,
                'cards': L10n.current.loyaltyCards,
                'qr': L10n.current.qrCodes478,
                'gift': L10n.current.giftCards,
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
        'alphabetical' => L10n.current.alphabetical,
        'added' => L10n.current.recentlyAdded,
        _ => L10n.current.lastUsed,
      };

  String get _startTabLabel => switch (_defaultStartTab) {
        'cards' => L10n.current.loyaltyCards,
        'qr' => L10n.current.qrCodes478,
        'gift' => L10n.current.giftCards,
        _ => L10n.current.home,
      };

  Future<void> _share(BuildContext anchor) async {
    final menu = AppMenuService.current;
    if (menu == null) return;
    try {
      final box = anchor.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
        text: menu.shareText(LocaleService.languageCode), subject: 'PasKluis',
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (_) { _failure(); }
  }
  void _failure() {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('De actie is niet gelukt. Probeer opnieuw.', 'The action failed. Please try again.'))));
  }
  Future<void> _external(String value) async {
    if (!AppMenu.safeUrl(value)) return;
    try { if (!await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication)) _failure(); }
    catch (_) { _failure(); }
  }
  String get _backupSummary {
    if (AccountService.currentUser == null) return t('Log in voor back-up', 'Sign in to back up');
    if (BackupService.busy) return t('Back-upstatus bijwerken…', 'Updating backup status…');
    if (BackupService.error != null) return t('Back-up heeft aandacht nodig', 'Backup needs attention');
    final date = DateTime.tryParse(BackupService.lastSuccess ?? '')?.toLocal();
    if (date == null) return t('Nog geen geslaagde back-up', 'No successful backup yet');
    return t('Laatste back-up: ', 'Last backup: ') + '${date.day}-${date.month}-${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  Widget _plain(Map item, String title, IconData icon, VoidCallback onTap, {String? subtitle}) =>
    _SettingsTile(menuItem: item, icon: icon, iconColor: const Color(0xFFD51B46),
      iconBackground: const Color(0xFFFFE5E9), title: title, subtitle: subtitle, onTap: onTap);

  Widget? _action(Map item) {
    final action = item['action'];
    if (const {'location','radius','distances','nearbyFirst','nearbyHome'}.contains(action) && !SettingsService.locationCardsAvailable) return null;
    if (action == 'radius' && !_locationCardsEnabled) return null;
    if (action == 'notifications' && !SettingsService.giftExpiryNotificationsAvailable) return null;
    if (item['audience'] == 'locked' && !_plus) {
      final original = _action({...item, 'audience': 'all'});
      final title = original is _SettingsTile ? original.title : original is _SettingsSwitchTile ? original.title : 'PasKluis Plus';
      return _plain(item, title, Icons.lock_outline,
        () => _open(const AccountScreen()), subtitle: t('Beschikbaar met Plus', 'Available with Plus'));
    }
    switch (action) {
      case 'location': return _SettingsSwitchTile(menuItem: item, 
                  icon: Icons.location_on_outlined,
                  iconColor: const Color(0xFF286DC8),
                  iconBackground: const Color(0xFFE7F0FF),
                  title: L10n.current.locationBasedCards,
                  subtitle: L10n.current.showTheRightCardAtANearby,
                  value: _locationCardsEnabled,
                  onChanged: _changeLocationCards,
                );
      case 'radius': return _SettingsTile(menuItem: item, 
                    icon: Icons.radar_rounded,
                    iconColor: const Color(0xFF7046B8),
                    iconBackground: const Color(0xFFEFE8FF),
                    title: L10n.current.distance,
                    subtitle: L10n.current.howCloseAStoreNeedsToBe,
                    value: _radiusLabel,
                    onTap: _chooseRadius,
                  );
      case 'nearbyFirst': return _SettingsSwitchTile(menuItem: item, 
                  icon: Icons.near_me_outlined,
                  iconColor: const Color(0xFF286DC8),
                  iconBackground: const Color(0xFFE7F0FF),
                  title: L10n.current.nearestLoyaltyCardsFirst,
                  subtitle: _locationCardsEnabled
                      ? L10n.current.withinTheChosenDistanceNearestFirstThen
                      : L10n.current.enableLocationBasedCardsToUseThis,
                  value: _nearbyLoyaltyCardsFirst,
                  onChanged: !_locationCardsEnabled ? null : (value) async {
                    await SettingsService.setNearbyLoyaltyCardsFirst(value);
                    if (mounted) {
                      setState(() => _nearbyLoyaltyCardsFirst = value);
                    }
                  },
                );
      case 'favoritesFirst': return _SettingsSwitchTile(menuItem: item, 
                icon: Icons.star_outline_rounded,
                iconColor: const Color(0xFFA26D00),
                iconBackground: const Color(0xFFFFF2CC),
                title: L10n.current.favouritesFirst,
                subtitle: _locationCardsEnabled && _nearbyLoyaltyCardsFirst
                    ? L10n.current.favouritesFollowNearbyLoyaltyCards
                    : L10n.current.yourMostImportantCardsFirst,
                value: _favoritesFirst,
                onChanged: (value) async {
                  await SettingsService.setFavoritesFirst(value);
                  if (mounted) setState(() => _favoritesFirst = value);
                },
              );
      case 'favoritesHome': return _SettingsSwitchTile(menuItem: item, 
                icon: Icons.dashboard_customize_outlined,
                iconColor: const Color(0xFFD51B46),
                iconBackground: const Color(0xFFFFE5E9),
                title: L10n.current.favouritesOnHome,
                subtitle: L10n.current.showASeparateSectionWithFavouriteCards,
                value: _showFavoritesSection,
                onChanged: (value) async {
                  await SettingsService.setShowFavoritesSection(value);
                  if (mounted) setState(() => _showFavoritesSection = value);
                },
              );
      case 'nearbyHome': return _SettingsSwitchTile(menuItem: item, 
                  icon: Icons.near_me_outlined,
                  iconColor: const Color(0xFF286DC8),
                  iconBackground: const Color(0xFFE7F0FF),
                  title: L10n.current.nearbyOnHome,
                  subtitle: _locationCardsEnabled
                      ? L10n.current.showASeparateSectionWithNearbyLoyalty
                      : L10n.current.theSectionAppearsWhenLocationBasedCards,
                  value: _showNearbySection,
                  onChanged: (value) async {
                    await SettingsService.setShowNearbySection(value);
                    if (mounted) setState(() => _showNearbySection = value);
                  },
                );
      case 'sorting': return _SettingsTile(menuItem: item, 
                icon: Icons.swap_vert_rounded,
                iconColor: const Color(0xFF23814A),
                iconBackground: const Color(0xFFDDF5E5),
                title: L10n.current.defaultSorting,
                subtitle: L10n.current.orderInYourCardOverview,
                value: _sortLabel,
                onTap: _chooseSorting,
              );
      case 'start': return _SettingsTile(menuItem: item, 
                icon: Icons.home_outlined,
                iconColor: const Color(0xFF286DC8),
                iconBackground: const Color(0xFFE7F0FF),
                title: L10n.current.defaultStartScreen,
                subtitle: L10n.current.openPaskluisInYourFavouriteSection,
                value: _startTabLabel,
                onTap: _chooseStartTab,
              );
      case 'clarity': return _SettingsSwitchTile(menuItem: item, 
                icon: Icons.visibility_outlined,
                iconColor: const Color(0xFF7046B8),
                iconBackground: const Color(0xFFEFE8FF),
                title: L10n.current.extraClarity,
                subtitle: L10n.current.largerTextHigherContrastAndLargerCards,
                value: _extraClearEnabled,
                onChanged: _changeExtraClear,
              );
      case 'brightness': return _SettingsSwitchTile(menuItem: item, 
                icon: Icons.light_mode_outlined,
                iconColor: const Color(0xFFA26D00),
                iconBackground: const Color(0xFFFFF2CC),
                title: L10n.current.automaticallyIncreaseBrightness,
                subtitle: L10n.current.makesBarcodesEasierToScan,
                value: _autoBrightnessEnabled,
                onChanged: (value) async {
                  await SettingsService.setAutoBrightnessEnabled(value);
                  if (mounted) setState(() => _autoBrightnessEnabled = value);
                },
              );
      case 'awake': return _SettingsSwitchTile(menuItem: item, 
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFF7046B8),
                iconBackground: const Color(0xFFEFE8FF),
                title: L10n.current.keepScreenAwake,
                subtitle: L10n.current.preventTheScreenFromTurningOffWhile,
                value: _keepScreenAwakeEnabled,
                onChanged: (value) async {
                  await SettingsService.setKeepScreenAwakeEnabled(value);
                  if (mounted) setState(() => _keepScreenAwakeEnabled = value);
                },
              );
      case 'notifications': return _SettingsSwitchTile(menuItem: item, 
                  icon: Icons.notifications_active_outlined,
                  iconColor: const Color(0xFFD51B46),
                  iconBackground: const Color(0xFFFFE5E9),
                  title: L10n.current.giftCardReminders,
                  subtitle: L10n.current.notificationsBeforeTheExpiryDate,
                  value: _giftExpiryNotificationsEnabled,
                  onChanged: _changeExpiryNotifications,
                );
      case 'lock': return _SettingsSwitchTile(menuItem: item, 
                icon: Icons.face_rounded,
                iconColor: const Color(0xFF23814A),
                iconBackground: const Color(0xFFDDF5E5),
                title: L10n.current.lockPaskluis,
                subtitle: L10n.current.useFaceIdBiometricsOrYourDevice,
                value: _appLockEnabled,
                onChanged: _savingLock ? null : _changeAppLock,
              );
      case 'hidePins': return _SettingsSwitchTile(menuItem: item, 
                icon: Icons.visibility_off_outlined,
                iconColor: const Color(0xFFD51B46),
                iconBackground: const Color(0xFFFFE5E9),
                title: L10n.current.hidePinsByDefault,
                subtitle: L10n.current.showSensitiveCodesOnlyAfterConfirmation,
                value: _hideSensitiveCodes,
                onChanged: (value) async {
                  await SettingsService.setHideSensitiveCodes(value);
                  if (mounted) setState(() => _hideSensitiveCodes = value);
                },
              );
      case 'privacy': return _SettingsTile(menuItem: item, 
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFF286DC8),
                iconBackground: const Color(0xFFE7F0FF),
                title: L10n.current.privacyAndData,
                subtitle: L10n.current.seeWhatPaskluisDoesAndDoesNot,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              );
      case 'support': return _SettingsTile(menuItem: item, 
                icon: Icons.support_agent_rounded,
                iconColor: const Color(0xFFD51B46),
                iconBackground: const Color(0xFFFFE5E9),
                title: L10n.current.customerSupport,
                subtitle: L10n.current.askAQuestionOrViewPreviousConversations,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SupportScreen()),
                ),
              );
      case 'help': return _SettingsTile(menuItem: item, 
                icon: Icons.help_outline_rounded,
                iconColor: const Color(0xFF7046B8),
                iconBackground: const Color(0xFFEFE8FF),
                title: L10n.current.helpAndGuidance,
                subtitle: L10n.current.guidanceAndFrequentlyAskedQuestions,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                ),
              );
      case 'device': return _SettingsTile(menuItem: item, 
                icon: Icons.phone_iphone_rounded,
                iconColor: const Color(0xFF286DC8),
                iconBackground: const Color(0xFFE7F0FF),
                title: L10n.current.dataOnThisDevice,
                subtitle: L10n.current.cardsStoredLocally((StorageService.cardsBox.length).toString()),
              );
      case 'language': return _plain(item, L10n.current.language, Icons.language, () => showLanguagePicker(context), subtitle: LocaleService.preference.value == 'system' ? L10n.current.followPhoneLanguage : LocaleService.languageCode == 'nl' ? 'Nederlands' : 'English');
      case 'share': return Builder(builder: (anchor) => _plain(item, t('Deel PasKluis', 'Share PasKluis'), Icons.share_outlined, () => _share(anchor), subtitle: t('Stuur de app door naar vrienden of familie', 'Share the app with friends or family')));
      case 'external': return _plain(item, AppMenu.text(item['title'], LocaleService.languageCode), Icons.open_in_new, () => _external(item['url']));
      case 'plus': return _plain(item, t('Ontdek PasKluis Plus', 'Discover PasKluis Plus'), Icons.workspace_premium_outlined, () => _open(const AccountScreen()), subtitle: t('Meer eigen cadeaukaarten en delen', 'More gift cards and sharing'));
      case 'distances': return _SettingsSwitchTile(menuItem: item, icon: Icons.place_outlined, iconColor: const Color(0xFF286DC8), iconBackground: const Color(0xFFE7F0FF), title: t('Afstanden op klantenkaarten', 'Distances on loyalty cards'), subtitle: t('Toon afstanden binnen je gekozen straal; behoud je eigen sortering', 'Show distances within your chosen radius; keep your sorting'), value: SettingsService.showCardDistances, onChanged: !_locationCardsEnabled ? null : (value) => SettingsService.setShowCardDistances(value));
      case 'backupAuto': return _SettingsSwitchTile(menuItem: item, icon: Icons.cloud_sync_outlined, iconColor: const Color(0xFF286DC8), iconBackground: const Color(0xFFE7F0FF), title: t('Automatische back-up', 'Automatic backup'), subtitle: t('Bij wijzigingen, met internet en terwijl de app actief is', 'After changes, while online and the app is active'), value: BackupService.enabled, onChanged: BackupService.busy ? null : (value) async {
        if (AccountService.currentUser == null) { await _open(const AccountScreen()); if (mounted) await BackupService.refresh(); return; }
        await BackupActions.enable(context, value);
      });
      case 'backupNow': return _plain(item, t('Nu back-up maken', 'Back up now'), Icons.backup_outlined, () async {
        if (AccountService.currentUser == null) { await _open(const AccountScreen()); if (mounted) await BackupService.refresh(); return; }
        if (!BackupService.busy) await BackupActions.upload(context);
      }, subtitle: _backupSummary);
      case 'restore': return _plain(item, t('Herstellen en beheren', 'Restore and manage'), Icons.restore, () => _open(const BackupScreen()));
    }
    return null;
  }
  String _summary(Map section) {
    final custom = AppMenu.text(section['description'], LocaleService.languageCode);
    if (custom.isNotEmpty) return custom;
    return switch (section['id']) {
      'backup' => _backupSummary,
      'security' => _appLockEnabled ? t('Appvergrendeling aan', 'App lock on') : t('Appvergrendeling uit', 'App lock off'),
      'cards' => '$_sortLabel · $_startTabLabel',
      'location' => _locationCardsEnabled ? _radiusLabel : t('Locatie uit', 'Location off'),
      'screen' => t('Helderheid, scherm en herinneringen', 'Brightness, screen and reminders'),
      'language' => LocaleService.preference.value == 'system' ? L10n.current.followPhoneLanguage : LocaleService.languageCode == 'nl' ? 'Nederlands' : 'English',
      _ => '',
    };
  }
  Widget _section(Map section) {
    if (section['hidden'] == true) return const SizedBox.shrink();
    final children = <Widget>[];
    for (final item in section['items']) {
      if (!AppMenu.visible(item, _plus)) continue;
      final child = _action(item);
      if (child != null) children.add(child);
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return _SettingsSection(
      key: ValueKey(section['id']), title: AppMenu.text(section['title'], LocaleService.languageCode),
      summary: _summary(section), icon: menuIcon(section['icon'], Icons.tune),
      collapsed: section['collapsed'] == true, children: children,
    );
  }
  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    final user = AccountService.currentUser;
    final name = user?.userMetadata?['display_name']?.toString();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F7),
      appBar: AppBar(title: Text(L10n.current.settings)),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 18, 14, 32), children: [
        Card(color: Colors.white, elevation: 0, child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(user == null ? t('Mijn account', 'My account') : (name?.isNotEmpty == true ? name! : t('Mijn account', 'My account')), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(user == null ? t('Log in of maak een account voor back-up', 'Sign in or create an account for backup') : '${user.email ?? ''}\n${_plus ? 'PasKluis Plus' : t('Gratis', 'Free')}\n$_backupSummary'),
          trailing: const Icon(Icons.chevron_right), onTap: () => _open(const AccountScreen()),
        )),
        if (_plus) Card(
          color: const Color(0xFFFFF1C8), elevation: 0,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const Icon(Icons.verified_rounded, color: Color(0xFF785500)),
            title: Text(t('PasKluis Plus · Actief', 'PasKluis Plus · Active'),
                style: const TextStyle(color: Color(0xFF513900), fontWeight: FontWeight.w800)),
            subtitle: Text(t('Je hebt onbeperkt toegang tot alle Plus-functies.',
                'You have unlimited access to all Plus features.')),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF785500)),
            onTap: () => _open(const PlusInformationScreen(isActive: true)),
          ),
        ),
        if (BackupService.error != null && user != null) Card(color: Theme.of(context).colorScheme.errorContainer, child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined), title: Text(t('Je back-up heeft aandacht nodig', 'Your backup needs attention')),
          subtitle: Text(t('Tik om de status te controleren en opnieuw te proberen', 'Tap to check the status and retry')),
          onTap: () => _open(const BackupScreen()),
        )),
        const SizedBox(height: 12),
        if (AppMenuService.current == null) const Center(child: CircularProgressIndicator())
        else for (final section in AppMenuService.current!.sections) _section(section),
        if (_isAdmin) _plain(const {}, L10n.current.administrator, Icons.admin_panel_settings_outlined, () => _open(const AdminToolsScreen())),
        Center(child: Padding(padding: const EdgeInsets.only(top: 12), child: Text('PasKluis $_version', style: const TextStyle(color: Color(0xFF77717D), fontSize: 12)))),
      ]),
    );
  }
}

IconData menuIcon(Object? id, IconData fallback) => switch (id) {
  'help' => Icons.help_outline, 'share' => Icons.share_outlined, 'security' => Icons.shield_outlined,
  'backup' => Icons.cloud_outlined, 'folder' => Icons.folder_outlined, 'star' => Icons.star_outline,
  'cards' => Icons.credit_card, 'home' => Icons.home_outlined, 'display' => Icons.brightness_6_outlined,
  'location' => Icons.place_outlined, 'notifications' => Icons.notifications_outlined,
  'language' => Icons.language, 'link' => Icons.open_in_new, _ => fallback,
};

class _SettingsSection extends StatelessWidget {
  final String title;
  final String summary;
  final IconData icon;
  final bool collapsed;
  final List<Widget> children;
  const _SettingsSection({super.key, required this.title, required this.summary, required this.icon, required this.collapsed, required this.children});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(margin: EdgeInsets.zero, elevation: 0, color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: !collapsed,
        key: PageStorageKey(key), leading: Icon(icon, color: const Color(0xFFD51B46)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: summary.isEmpty ? null : Text(summary), children: children,
      ),
    ),
  );
}
class _SettingsTile extends StatelessWidget {
  final Map menuItem;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;

  const _SettingsTile({
    this.menuItem = const {},
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
    L10n.watch(context);
    return ListTile(
      minTileHeight: 62,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: _SettingsIcon(
        icon: menuIcon(menuItem['icon'], icon),
        color: iconColor,
        background: iconBackground,
      ),
      title: Text(AppMenu.text(menuItem['title'], LocaleService.languageCode, title), style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text([AppMenu.text(menuItem['description'], LocaleService.languageCode, subtitle ?? ''), if (value != null) value!].where((s) => s.isNotEmpty).join('\n')),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A858F)),
      onTap: onTap,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final Map menuItem;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SettingsSwitchTile({
    this.menuItem = const {},
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
    L10n.watch(context);
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      secondary: _SettingsIcon(
        icon: menuIcon(menuItem['icon'], icon),
        color: iconColor,
        background: iconBackground,
      ),
      title: Text(AppMenu.text(menuItem['title'], LocaleService.languageCode, title), style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(AppMenu.text(menuItem['description'], LocaleService.languageCode, subtitle ?? '')),
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
    L10n.watch(context);
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
