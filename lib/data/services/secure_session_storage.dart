import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Migrates existing sessions only after a verified secure write. A storage
/// failure never falls back to writing fresh credentials in preferences.
class SecureSessionStorage extends LocalStorage {
  final String key;
  final FlutterSecureStorage secure;
  final LocalStorage legacy;

  SecureSessionStorage({required this.key,
    this.secure = const FlutterSecureStorage(), LocalStorage? legacy})
      : legacy = legacy ?? SharedPreferencesLocalStorage(persistSessionKey: key);

  @override
  Future<void> initialize() async {
    await legacy.initialize();
    final current = await secure.read(key: key);
    if (current == null) {
      final previous = await legacy.accessToken();
      if (previous != null) await _verifiedWrite(previous);
    }
    await legacy.removePersistedSession();
  }

  Future<void> _verifiedWrite(String value) async {
    await secure.write(key: key, value: value);
    if (await secure.read(key: key) != value) {
      throw StateError('Secure session persistence failed');
    }
  }

  @override
  Future<String?> accessToken() => secure.read(key: key);
  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;
  @override
  Future<void> persistSession(String persistSessionString) async {
    await _verifiedWrite(persistSessionString);
    await legacy.removePersistedSession();
  }
  @override
  Future<void> removePersistedSession() async {
    // Remove the migration source first, so logout cannot resurrect it.
    await legacy.removePersistedSession();
    await secure.delete(key: key);
  }
}
