import 'dart:io';

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
  static Future<SupportModeSession> create() async {
    final client = SupabaseService.client;
    if (client == null || AccountService.currentUser == null) {
      throw StateError('ACCOUNT_REQUIRED');
    }
    final package = await PackageInfo.fromPlatform();
    final messaging = await FirebaseMessaging.instance.getNotificationSettings();
    final location = await Geolocator.checkPermission();
    final auth = LocalAuthentication();
    final diagnostics = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'appVersion': package.version,
      'buildNumber': package.buildNumber,
      'locale': LocaleService.languageCode,
      'accountState': 'signed_in',
      'plusState': (await AccountService.loadPlusStatus()).isActive ? 'active' : 'inactive',
      'backupEnabled': BackupService.enabled,
      'backupStatus': BackupService.error == null ? (BackupService.busy ? 'busy' : 'ready') : 'error',
      'backupLastSuccess': BackupService.lastSuccess,
      'notificationPermission': messaging.authorizationStatus.name,
      'locationPermission': location.name,
      'appLockEnabled': SettingsService.appLockEnabled,
      'biometricsAvailable': await auth.isDeviceSupported(),
      'brightnessMode': SettingsService.autoBrightnessEnabled ? 'automatic' : 'system',
      'keepScreenAwake': SettingsService.keepScreenAwakeEnabled,
      'hideSensitiveCodes': SettingsService.hideSensitiveCodes,
      'defaultStartTab': SettingsService.defaultStartTab,
      'sortOrder': SettingsService.cardSortOrder,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
    };
    final response = Map<String, dynamic>.from(
      await client.rpc('create_support_session', params: {'p_diagnostics': diagnostics}) as Map,
    );
    return SupportModeSession(
      id: response['id'].toString(),
      code: response['code'].toString(),
      codeExpiresAt: DateTime.parse(response['codeExpiresAt'].toString()).toLocal(),
    );
  }

  static Future<void> revoke(String id) async {
    final client = SupabaseService.client;
    if (client == null) return;
    await client.rpc('revoke_support_session', params: {'p_session_id': id});
  }
}
