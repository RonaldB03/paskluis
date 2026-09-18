import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _appLockKey = 'app_lock_enabled';
  static const _extraClearKey = 'extra_clear_enabled';
  static late SharedPreferences _preferences;
  static final ValueNotifier<bool> extraClearNotifier = ValueNotifier(false);

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
    extraClearNotifier.value = extraClearEnabled;
  }

  static bool get appLockEnabled => _preferences.getBool(_appLockKey) ?? false;

  static Future<void> setAppLockEnabled(bool enabled) async {
    await _preferences.setBool(_appLockKey, enabled);
  }

  static bool get extraClearEnabled =>
      _preferences.getBool(_extraClearKey) ?? false;

  static Future<void> setExtraClearEnabled(bool enabled) async {
    await _preferences.setBool(_extraClearKey, enabled);
    extraClearNotifier.value = enabled;
  }
}
