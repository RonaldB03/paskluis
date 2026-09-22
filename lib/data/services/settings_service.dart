import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';
import 'locale_service.dart';

abstract final class SettingsService {
  static const _appLockKey = 'app_lock_enabled';
  static const _extraClearKey = 'extra_clear_enabled';
  static const _locationCardsKey = 'location_cards_enabled';
  static const _nearbyRadiusKey = 'nearby_radius_meters';
  static const _favoritesFirstKey = 'favorites_first';
  static const _showFavoritesKey = 'show_favorites_section';
  static const _showNearbyKey = 'show_nearby_section';
  static const _nearbyCardsFirstKey = 'nearby_loyalty_cards_first';
  static const _cardSortKey = 'card_sort_order';
  static const _startTabKey = 'default_start_tab';
  static const _autoBrightnessKey = 'auto_brightness';
  static const _keepScreenAwakeKey = 'keep_screen_awake';
  static const _hideSensitiveCodesKey = 'hide_sensitive_codes';
  static const _giftExpiryNotificationsKey =
      'gift_expiry_notifications_enabled';

  static late SharedPreferences _preferences;
  static final Map<String, dynamic> _remote = {};

  static final ValueNotifier<bool> extraClearNotifier = ValueNotifier(false);
  static final ValueNotifier<int> settingsRevision = ValueNotifier(0);

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
    extraClearNotifier.value = extraClearEnabled;
  }

  static Future<void> refreshRemoteConfig() async {
    final client = SupabaseService.client;
    if (client == null) return;
    try {
      final rows = await client
          .from('app_settings')
          .select('key, value')
          .eq('is_public', true);
      _remote
        ..clear()
        ..addEntries(
          rows.map(
            (row) => MapEntry(row['key']?.toString() ?? '', row['value']),
          ),
        );
      settingsRevision.value++;
    } catch (_) {
      // Remote defaults are optional. Stored choices keep working offline.
    }
  }

  static bool _remoteBool(String key, bool fallback) {
    final value = _remote[key];
    if (value is bool) return value;
    return switch (value?.toString().toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => fallback,
    };
  }

  static int _remoteInt(String key, int fallback) =>
      int.tryParse(_remote[key]?.toString() ?? '') ?? fallback;

  static String _remoteString(String key, String fallback) =>
      _remote[key]?.toString() ?? fallback;

  static void _notify() => settingsRevision.value++;

  static bool get appLockEnabled => _preferences.getBool(_appLockKey) ?? false;

  static Future<void> setAppLockEnabled(bool enabled) async {
    await _preferences.setBool(_appLockKey, enabled);
    _notify();
  }

  static bool get extraClearEnabled =>
      _preferences.getBool(_extraClearKey) ?? false;

  static Future<void> setExtraClearEnabled(bool enabled) async {
    await _preferences.setBool(_extraClearKey, enabled);
    extraClearNotifier.value = enabled;
    _notify();
  }

  static bool get locationCardsAvailable =>
      _remoteBool('feature_location_cards', true);

  static bool get locationCardsEnabled =>
      locationCardsAvailable &&
      (_preferences.getBool(_locationCardsKey) ??
          _remoteBool('default_location_cards_enabled', true));

  static Future<void> setLocationCardsEnabled(bool enabled) async {
    await _preferences.setBool(_locationCardsKey, enabled);
    _notify();
  }

  static int get nearbyRadiusMeters =>
      _preferences.getInt(_nearbyRadiusKey) ??
      _remoteInt('default_nearby_radius_meters', 250);

  static Future<void> setNearbyRadiusMeters(int meters) async {
    await _preferences.setInt(_nearbyRadiusKey, meters);
    _notify();
  }

  static bool get favoritesFirst =>
      _preferences.getBool(_favoritesFirstKey) ??
      _remoteBool('default_favorites_first', true);

  static Future<void> setFavoritesFirst(bool enabled) async {
    await _preferences.setBool(_favoritesFirstKey, enabled);
    _notify();
  }

  static bool get showFavoritesSection =>
      _preferences.getBool(_showFavoritesKey) ??
      _remoteBool('default_show_favorites_section', true);

  static Future<void> setShowFavoritesSection(bool enabled) async {
    await _preferences.setBool(_showFavoritesKey, enabled);
    _notify();
  }

  static String get cardSortOrder =>
      _preferences.getString(_cardSortKey) ??
      _remoteString('default_card_sort_order', 'recent');

  static bool get showNearbySection =>
      _preferences.getBool(_showNearbyKey) ??
      _remoteBool('default_show_nearby_section', true);

  static Future<void> setShowNearbySection(bool enabled) async {
    await _preferences.setBool(_showNearbyKey, enabled);
    _notify();
  }

  static bool get nearbyLoyaltyCardsFirst =>
      _preferences.getBool(_nearbyCardsFirstKey) ??
      _remoteBool('default_nearby_loyalty_cards_first', false);

  static Future<void> setNearbyLoyaltyCardsFirst(bool enabled) async {
    await _preferences.setBool(_nearbyCardsFirstKey, enabled);
    _notify();
  }

  static Future<void> setCardSortOrder(String value) async {
    await _preferences.setString(_cardSortKey, value);
    _notify();
  }

  static String get defaultStartTab =>
      _preferences.getString(_startTabKey) ??
      _remoteString('default_start_tab', 'home');

  static Future<void> setDefaultStartTab(String value) async {
    await _preferences.setString(_startTabKey, value);
    _notify();
  }

  static bool get autoBrightnessEnabled =>
      _preferences.getBool(_autoBrightnessKey) ??
      _remoteBool('default_auto_brightness', true);

  static Future<void> setAutoBrightnessEnabled(bool enabled) async {
    await _preferences.setBool(_autoBrightnessKey, enabled);
    _notify();
  }

  static bool get keepScreenAwakeEnabled =>
      _preferences.getBool(_keepScreenAwakeKey) ??
      _remoteBool('default_keep_screen_awake', true);

  static Future<void> setKeepScreenAwakeEnabled(bool enabled) async {
    await _preferences.setBool(_keepScreenAwakeKey, enabled);
    _notify();
  }

  static bool get hideSensitiveCodes =>
      _preferences.getBool(_hideSensitiveCodesKey) ??
      _remoteBool('default_hide_sensitive_codes', true);

  static Future<void> setHideSensitiveCodes(bool enabled) async {
    await _preferences.setBool(_hideSensitiveCodesKey, enabled);
    _notify();
  }

  static bool get giftExpiryNotificationsAvailable =>
      _remoteBool('feature_gift_expiry_notifications', true);

  static bool get giftExpiryNotificationsEnabled =>
      giftExpiryNotificationsAvailable &&
      (_preferences.getBool(_giftExpiryNotificationsKey) ??
          _remoteBool('default_gift_expiry_notifications', true));

  static Future<void> setGiftExpiryNotificationsEnabled(bool enabled) async {
    await _preferences.setBool(_giftExpiryNotificationsKey, enabled);
    _notify();
  }

  static bool get cardSharingAvailable =>
      _remoteBool('feature_card_sharing', true);

  static int get freeGiftCardLimit => _remoteInt('free_gift_card_limit', 1).clamp(1, 100);

  static String get privacyMessage => _remoteString(
        LocaleService.languageCode == 'en' ? 'privacy_message_en' : 'privacy_message',
        L10n.current.yourCardsCodesAndPinsStayOn,
      );

  static String get helpText => _remoteString(
        LocaleService.languageCode == 'en' ? 'help_add_card_text_en' : 'help_add_card_text',
        L10n.current.tapToAddALoyaltyCardQr,
      );
}
