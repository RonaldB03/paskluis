import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _appLockKey = 'app_lock_enabled';
  static late SharedPreferences _preferences;

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  static bool get appLockEnabled => _preferences.getBool(_appLockKey) ?? false;

  static Future<void> setAppLockEnabled(bool enabled) async {
    await _preferences.setBool(_appLockKey, enabled);
  }
}
