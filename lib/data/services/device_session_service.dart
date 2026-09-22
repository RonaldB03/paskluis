import 'package:paskluis_v1/l10n/l10n.dart';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'supabase_service.dart';

class DeviceSessionStatus {
  final bool hasActiveDevice;
  final bool isCurrentDevice;
  final String activeDeviceName;

  const DeviceSessionStatus({
    required this.hasActiveDevice,
    required this.isCurrentDevice,
    required this.activeDeviceName,
  });
}

abstract final class DeviceSessionService {
  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'paskluis_device_id_v1';

  static final ValueNotifier<String?> sessionNotice = ValueNotifier(null);

  static Future<String> get deviceId async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final created = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _storage.write(key: _deviceIdKey, value: created);
    return created;
  }

  static String get deviceName {
    if (Platform.isIOS) return L10n.current.iphoneOrIpad;
    if (Platform.isAndroid) return L10n.current.androidDevice;
    if (Platform.isMacOS) return 'Mac';
    if (Platform.isWindows) return L10n.current.windowsDevice;
    return L10n.current.anotherDevice;
  }

  static Future<DeviceSessionStatus> inspect() async {
    final client = SupabaseService.client;
    if (client?.auth.currentUser == null) {
      return const DeviceSessionStatus(
        hasActiveDevice: false,
        isCurrentDevice: false,
        activeDeviceName: '',
      );
    }
    final response = await client!.rpc(
      'check_device_session',
      params: {'p_device_id': await deviceId},
    );
    final row = Map<String, dynamic>.from(response as Map);
    return DeviceSessionStatus(
      hasActiveDevice: row['has_active_device'] == true,
      isCurrentDevice: row['is_current_device'] == true,
      activeDeviceName: row['active_device_name']?.toString() ?? '',
    );
  }

  static Future<bool> claim({bool replace = false}) async {
    final client = SupabaseService.client;
    if (client?.auth.currentUser == null) return false;
    final response = await client!.rpc(
      'claim_device_session',
      params: {
        'p_device_id': await deviceId,
        'p_device_name': deviceName,
        'p_replace': replace,
      },
    );
    final row = Map<String, dynamic>.from(response as Map);
    final allowed = row['allowed'] == true;
    if (allowed) sessionNotice.value = null;
    return allowed;
  }

  static Future<bool> ensureCurrentSession() async {
    final client = SupabaseService.client;
    if (client?.auth.currentUser == null) return true;
    final status = await inspect();
    if (!status.hasActiveDevice) return claim();
    if (!status.isCurrentDevice) return false;
    return validate();
  }

  static Future<bool> validate() async {
    final client = SupabaseService.client;
    if (client?.auth.currentUser == null) return true;
    final response = await client!.rpc(
      'validate_device_session',
      params: {'p_device_id': await deviceId},
    );
    return response == true;
  }

  static Future<void> release() async {
    final client = SupabaseService.client;
    if (client?.auth.currentUser == null) return;
    await client!.rpc(
      'release_device_session',
      params: {'p_device_id': await deviceId},
    );
  }
}
