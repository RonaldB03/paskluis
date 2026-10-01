import 'dart:io';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paskluis_v1/l10n/l10n.dart';

import 'app_menu_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'account_service.dart';
import 'backup_service.dart';
import 'locale_service.dart';
import 'settings_service.dart';
import 'supabase_service.dart';

class SupportModeSession {
  final String id;
  final String code;
  final DateTime codeExpiresAt;

  const SupportModeSession({
    required this.id,
    required this.code,
    required this.codeExpiresAt,
  });
}

abstract final class SupportModeService {
  static String? _sessionId;
  static String? _owner;
  static int _appliedRevision = 0;
  static Timer? _poll;
  static bool _busy = false;
  static bool _foreground = true;
  static Map<String, dynamic> _diagnostics = {};
  static final status = ValueNotifier<String>('pending');

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString('support_session_id');
    _owner = prefs.getString('support_session_owner');
    _appliedRevision = prefs.getInt('support_applied_revision') ?? 0;
    _poll ??= Timer.periodic(const Duration(seconds: 3), (_) => sync());
  }

  static void setForeground(bool value) {
    _foreground = value;
    if (value) unawaited(sync());
  }

  static Map<String, dynamic> settingsSnapshot() => {
    'language': LocaleService.preference.value,
    'extraClearEnabled': SettingsService.extraClearEnabled,
    'locationCardsEnabled': SettingsService.locationCardsEnabled,
    'nearbyRadiusMeters': SettingsService.nearbyRadiusMeters,
    'favoritesFirst': SettingsService.favoritesFirst,
    'showFavoritesSection': SettingsService.showFavoritesSection,
    'showNearbySection': SettingsService.showNearbySection,
    'showCardDistances': SettingsService.showCardDistances,
    'nearbyLoyaltyCardsFirst': SettingsService.nearbyLoyaltyCardsFirst,
    'cardSortOrder': SettingsService.cardSortOrder,
    'defaultStartTab': SettingsService.defaultStartTab,
    'autoBrightnessEnabled': SettingsService.autoBrightnessEnabled,
    'keepScreenAwakeEnabled': SettingsService.keepScreenAwakeEnabled,
    'hideSensitiveCodes': SettingsService.hideSensitiveCodes,
    'giftExpiryNotificationsEnabled':
        SettingsService.giftExpiryNotificationsEnabled,
  };

  static String _title(String action) => switch (action) {
    'help' => L10n.current.helpAndGuidance,
    'support' => L10n.current.customerSupport,
    'lock' => L10n.current.lockPaskluis,
    'hidePins' => L10n.current.hidePinsByDefault,
    'favoritesFirst' => L10n.current.favouritesFirst,
    'sorting' => L10n.current.defaultSorting,
    'start' => L10n.current.defaultStartScreen,
    'clarity' => L10n.current.extraClarity,
    'location' => L10n.current.locationBasedCards,
    'radius' => L10n.current.distance,
    'nearbyFirst' => L10n.current.nearestLoyaltyCardsFirst,
    'brightness' => L10n.current.automaticallyIncreaseBrightness,
    'awake' => L10n.current.keepScreenAwake,
    'notifications' => L10n.current.giftCardReminders,
    'language' => L10n.current.language,
    'favoritesHome' => L10n.current.favouritesOnHome,
    'nearbyHome' => L10n.current.nearbyOnHome,
    'privacy' => L10n.current.privacyAndData,
    'device' => L10n.current.dataOnThisDevice,
    _ => _fallbackTitle(action),
  };

  static String _fallbackTitle(String action) {
    final nl = LocaleService.languageCode == 'nl';
    final labels = <String, List<String>>{
      'share': ['Deel PasKluis', 'Share PasKluis'],
      'privacy': ['Privacy en gegevens', 'Privacy and data'],
      'backupAuto': ['Automatische back-up', 'Automatic backup'],
      'backupNow': ['Nu back-up maken', 'Back up now'],
      'restore': ['Herstellen en beheren', 'Restore and manage'],
      'favoritesHome': ['Favorieten op Home', 'Favorites on Home'],
      'nearbyHome': ['In de buurt op Home', 'Nearby on Home'],
      'distances': [
        'Afstanden op klantenkaarten',
        'Distances on loyalty cards',
      ],
      'plus': ['Ontdek PasKluis Plus', 'Discover PasKluis Plus'],
      'device': ['Apparaat en account', 'Device and account'],
    };
    return labels[action]?[nl ? 0 : 1] ?? action;
  }

  static String _description(String action) => switch (action) {
    'location' => L10n.current.showTheRightCardAtANearby,
    'radius' => L10n.current.howCloseAStoreNeedsToBe,
    'favoritesHome' => L10n.current.showASeparateSectionWithFavouriteCards,
    'sorting' => L10n.current.orderInYourCardOverview,
    'start' => L10n.current.openPaskluisInYourFavouriteSection,
    'clarity' => L10n.current.largerTextHigherContrastAndLargerCards,
    'brightness' => L10n.current.makesBarcodesEasierToScan,
    'awake' => L10n.current.preventTheScreenFromTurningOffWhile,
    'notifications' => L10n.current.notificationsBeforeTheExpiryDate,
    'lock' => L10n.current.useFaceIdBiometricsOrYourDevice,
    'hidePins' => L10n.current.showSensitiveCodesOnlyAfterConfirmation,
    'privacy' => L10n.current.seeWhatPaskluisDoesAndDoesNot,
    'support' => L10n.current.askAQuestionOrViewPreviousConversations,
    'help' => L10n.current.guidanceAndFrequentlyAskedQuestions,
    'device' => L10n.current.cardsStoredLocally,
    _ => '',
  };

  static String _sectionSummary(String id) {
    final nl = LocaleService.languageCode == 'nl';
    switch (id) {
      case 'security':
        return SettingsService.appLockEnabled
            ? (nl ? 'Appvergrendeling aan' : 'App lock on')
            : (nl ? 'Appvergrendeling uit' : 'App lock off');
      case 'cards':
        final sort = switch (SettingsService.cardSortOrder) {
          'alphabetical' => L10n.current.alphabetical,
          'added' => L10n.current.recentlyAdded,
          _ => L10n.current.lastUsed,
        };
        final start = switch (SettingsService.defaultStartTab) {
          'cards' => L10n.current.loyaltyCards,
          'qr' => L10n.current.qrCodes478,
          'gift' => L10n.current.giftCards,
          _ => L10n.current.home,
        };
        return '$sort · $start';
      case 'location':
        return !SettingsService.locationCardsEnabled
            ? (nl ? 'Locatie uit' : 'Location off')
            : SettingsService.nearbyRadiusMeters == 1000
            ? '1 km'
            : '${SettingsService.nearbyRadiusMeters} m';
      case 'screen':
        return nl
            ? 'Helderheid, scherm en herinneringen'
            : 'Brightness, screen and reminders';
      case 'language':
        return LocaleService.preference.value == 'system'
            ? L10n.current.followPhoneLanguage
            : nl
            ? 'Nederlands'
            : 'English';
      case 'backup':
        if (BackupService.busy)
          return nl ? 'Back-upstatus bijwerken…' : 'Updating backup status…';
        if (BackupService.error != null)
          return nl ? 'Back-up heeft aandacht nodig' : 'Backup needs attention';
        final date = DateTime.tryParse(BackupService.lastSuccess ?? '')
            ?.toLocal();
        if (date == null)
          return nl ? 'Nog geen geslaagde back-up' : 'No successful backup yet';
        return '${nl ? 'Laatste back-up: ' : 'Last backup: '}${date.day}-${date.month}-${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      default:
        return '';
    }
  }

  static List<Map<String, dynamic>> menuSnapshot() {
    final plus = _diagnostics['plusState'] == 'active';
    final lang = LocaleService.languageCode;
    final sections = <Map<String, dynamic>>[];
    for (final section
        in AppMenuService.current?.sections ?? <Map<String, dynamic>>[]) {
      if (section['hidden'] == true) continue;
      final items = <Map<String, dynamic>>[];
      for (final raw in section['items'] as List) {
        final item = raw as Map;
        final action = item['action'] as String;
        if (!AppMenu.visible(item, plus)) continue;
        if (!SettingsService.locationCardsAvailable &&
            {
              'location',
              'radius',
              'distances',
              'nearbyFirst',
              'nearbyHome',
            }.contains(action))
          continue;
        if (action == 'radius' && !SettingsService.locationCardsEnabled)
          continue;
        if (action == 'notifications' &&
            !SettingsService.giftExpiryNotificationsAvailable)
          continue;
        items.add({
          'action': action,
          'title': AppMenu.text(item['title'], lang, _title(action)),
          'description': AppMenu.text(
            item['description'],
            lang,
            _description(action),
          ),
          'locked': item['audience'] == 'locked' && !plus,
        });
      }
      if (items.isEmpty) continue;
      sections.add({
        'id': section['id'],
        'title': AppMenu.text(section['title'], lang),
        'description': AppMenu.text(
          section['description'],
          lang,
          _sectionSummary(section['id'] as String),
        ),
        'collapsed': section['collapsed'],
        'items': items,
      });
    }
    return sections;
  }

  static Map<String, dynamic> _snapshot() => {
    ..._diagnostics,
    'locale': LocaleService.languageCode,
    'backupEnabled': BackupService.enabled,
    'backupStatus': BackupService.error == null
        ? (BackupService.busy ? 'busy' : 'ready')
        : 'error',
    'backupLastSuccess': BackupService.lastSuccess,
    'appLockEnabled': SettingsService.appLockEnabled,
    'brightnessMode': SettingsService.autoBrightnessEnabled
        ? 'automatic'
        : 'system',
    'keepScreenAwake': SettingsService.keepScreenAwakeEnabled,
    'hideSensitiveCodes': SettingsService.hideSensitiveCodes,
    'defaultStartTab': SettingsService.defaultStartTab,
    'sortOrder': SettingsService.cardSortOrder,
    'capturedAt': DateTime.now().toUtc().toIso8601String(),
  };

  static Future<void> sync() async {
    final client = SupabaseService.client;
    final id = _sessionId;
    if (!_foreground || _busy || id == null || client == null) return;
    if (_owner != AccountService.currentUser?.id) {
      await _clear();
      return;
    }
    _busy = true;
    try {
      if (_diagnostics.isEmpty) await _captureDiagnostics();
      for (var attempt = 0; attempt < 2; attempt++) {
        final response = Map<String, dynamic>.from(
          await client.rpc(
            'sync_support_settings',
            params: {
              'p_session_id': id,
              'p_settings': settingsSnapshot(),
              'p_menu': menuSnapshot(),
              'p_diagnostics': _snapshot(),
              'p_applied_revision': _appliedRevision,
            },
          ) as Map,
        );
        if (_sessionId != id || _owner != AccountService.currentUser?.id)
          return;
        if (response['status'] == 'ended') {
          status.value = 'ended';
          await _clear();
          return;
        }
        status.value = response['status'].toString();
        final patch = Map<String, dynamic>.from(
          response['patch'] as Map? ?? {},
        );
        if (patch.isEmpty) break;
        // Changes are applied locally; only then is the revision acknowledged.
        await _apply(patch);
        _appliedRevision = (response['revision'] as num).toInt();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('support_applied_revision', _appliedRevision);
      }
    } catch (_) {
      // Offline or revoked sessions never prevent access to the local vault.
    } finally {
      _busy = false;
    }
  }

  static Future<void> _apply(Map<String, dynamic> patch) async {
    final setters = <String, Future<void> Function(bool)>{
      'extraClearEnabled': SettingsService.setExtraClearEnabled,
      'locationCardsEnabled': SettingsService.setLocationCardsEnabled,
      'favoritesFirst': SettingsService.setFavoritesFirst,
      'showFavoritesSection': SettingsService.setShowFavoritesSection,
      'showNearbySection': SettingsService.setShowNearbySection,
      'showCardDistances': SettingsService.setShowCardDistances,
      'nearbyLoyaltyCardsFirst': SettingsService.setNearbyLoyaltyCardsFirst,
      'autoBrightnessEnabled': SettingsService.setAutoBrightnessEnabled,
      'keepScreenAwakeEnabled': SettingsService.setKeepScreenAwakeEnabled,
      'hideSensitiveCodes': SettingsService.setHideSensitiveCodes,
      'giftExpiryNotificationsEnabled':
          SettingsService.setGiftExpiryNotificationsEnabled,
    };
    for (final entry in patch.entries) {
      final setter = setters[entry.key];
      if (setter != null && entry.value is bool)
        await setter(entry.value as bool);
      if (entry.key == 'nearbyRadiusMeters')
        await SettingsService.setNearbyRadiusMeters(entry.value as int);
      if (entry.key == 'cardSortOrder')
        await SettingsService.setCardSortOrder(entry.value as String);
      if (entry.key == 'defaultStartTab')
        await SettingsService.setDefaultStartTab(entry.value as String);
      if (entry.key == 'language')
        await LocaleService.setLanguage(entry.value as String);
    }
    if (patch.containsKey('giftExpiryNotificationsEnabled')) {
      for (final card in StorageService.cardsBox.values.whereType<Map>()) {
        await NotificationService.syncGiftCard(card);
      }
    }
  }

  static Future<void> _clear() async {
    _sessionId = null;
    _owner = null;
    _appliedRevision = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('support_session_id');
    await prefs.remove('support_session_owner');
    await prefs.remove('support_applied_revision');
  }

  static Future<void> _captureDiagnostics() async {
    final package = await PackageInfo.fromPlatform();
    final messaging = await FirebaseMessaging.instance
        .getNotificationSettings();
    final location = await Geolocator.checkPermission();
    final auth = LocalAuthentication();
    final diagnostics = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'appVersion': package.version,
      'buildNumber': package.buildNumber,
      'locale': LocaleService.languageCode,
      'accountState': 'signed_in',
      'plusState': (await AccountService.loadPlusStatus()).isActive
          ? 'active'
          : 'inactive',
      'backupEnabled': BackupService.enabled,
      'backupStatus': BackupService.error == null
          ? (BackupService.busy ? 'busy' : 'ready')
          : 'error',
      'backupLastSuccess': BackupService.lastSuccess,
      'notificationPermission': messaging.authorizationStatus.name,
      'locationPermission': location.name,
      'appLockEnabled': SettingsService.appLockEnabled,
      'biometricsAvailable': await auth.isDeviceSupported(),
      'brightnessMode': SettingsService.autoBrightnessEnabled
          ? 'automatic'
          : 'system',
      'keepScreenAwake': SettingsService.keepScreenAwakeEnabled,
      'hideSensitiveCodes': SettingsService.hideSensitiveCodes,
      'defaultStartTab': SettingsService.defaultStartTab,
      'sortOrder': SettingsService.cardSortOrder,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
    };
    _diagnostics = diagnostics;
  }

  static Future<SupportModeSession> create() async {
    final client = SupabaseService.client;
    if (client == null || AccountService.currentUser == null)
      throw StateError('ACCOUNT_REQUIRED');
    await init();
    await _captureDiagnostics();
    final response = Map<String, dynamic>.from(
      await client.rpc(
        'create_support_session',
        params: {'p_diagnostics': _snapshot()},
      ) as Map,
    );
    _sessionId = response['id'].toString();
    _owner = AccountService.currentUser!.id;
    _appliedRevision = 0;
    status.value = 'pending';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('support_session_id', _sessionId!);
    await prefs.setString('support_session_owner', _owner!);
    await prefs.setInt('support_applied_revision', 0);
    await sync();
    return SupportModeSession(
      id: response['id'].toString(),
      code: response['code'].toString(),
      codeExpiresAt: DateTime.parse(response['codeExpiresAt'].toString())
          .toLocal(),
    );
  }

  static Future<void> revoke(String id) async {
    final client = SupabaseService.client;
    if (client == null) return;
    await client.rpc('revoke_support_session', params: {'p_session_id': id});
    status.value = 'ended';
    await _clear();
  }
}
