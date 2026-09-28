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

/// Keeps the short-lived login-link verifier in secure storage as well.
/// Pending login links from an older app migrate on first read.
class SecurePkceStorage extends GotrueAsyncStorage {
  final FlutterSecureStorage secure;
  final GotrueAsyncStorage legacy;

  SecurePkceStorage({
    this.secure = const FlutterSecureStorage(),
    GotrueAsyncStorage? legacy,
  }) : legacy = legacy ?? SharedPreferencesGotrueAsyncStorage();

  String _secureKey(String key) => 'paskluis-pkce-$key';

  @override
  Future<String?> getItem({required String key}) async {
    final current = await secure.read(key: _secureKey(key));
    if (current != null) {
      await legacy.removeItem(key: key);
      return current;
    }
    final previous = await legacy.getItem(key: key);
    if (previous != null) await setItem(key: key, value: previous);
    return previous;
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    final storageKey = _secureKey(key);
    await secure.write(key: storageKey, value: value);
    if (await secure.read(key: storageKey) != value) {
      throw StateError('Secure login verifier persistence failed');
    }
    await legacy.removeItem(key: key);
  }

  @override
  Future<void> removeItem({required String key}) async {
    await legacy.removeItem(key: key);
    await secure.delete(key: _secureKey(key));
  }
}
