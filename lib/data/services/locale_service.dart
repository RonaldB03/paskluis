import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device preference; never changes the identifiers stored on cards.
abstract final class LocaleService {
  static const preferenceKey = 'app_language';
  static const supportedLocales = [Locale('nl', 'NL'), Locale('en', 'GB')];
  static final locale = ValueNotifier<Locale>(const Locale('nl', 'NL'));
  static final preference = ValueNotifier<String>('nl');
  static SharedPreferences? _preferences;

  static String get languageCode => locale.value.languageCode;
  static String get flag => switch (preference.value) {
        'nl' => '🇳🇱',
        'en' => '🇬🇧',
        _ => '🌐',
      };

  static Locale resolve(Locale deviceLocale) => deviceLocale.languageCode == 'nl'
      ? supportedLocales.first
      : supportedLocales.last;

  static Future<void> init({bool hasSavedCards = false}) async {
    final prefs = await SharedPreferences.getInstance();
    _preferences = prefs;
    // Existing installations keep Dutch. A fresh install follows the phone.
    final stored = prefs.getString(preferenceKey);
    final selection = stored ??
        (hasSavedCards || prefs.getKeys().isNotEmpty ? 'nl' : 'system');
    await setLanguage(selection);
  }

  static Future<void> setLanguage(String selection) async {
    if (!const ['system', 'nl', 'en'].contains(selection)) {
      throw ArgumentError.value(selection, 'selection');
    }
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    _preferences = prefs;
    await prefs.setString(preferenceKey, selection);
    preference.value = selection;
    refreshSystemLocale();
  }

  static void refreshSystemLocale() {
    locale.value = preference.value == 'system'
        ? resolve(WidgetsBinding.instance.platformDispatcher.locale)
        : resolve(Locale(preference.value));
  }
}
