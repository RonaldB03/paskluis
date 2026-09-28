import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paskluis_v1/data/services/secure_session_storage.dart';

class MemoryLegacy extends LocalStorage {
  String? value;
  MemoryLegacy(this.value);
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() async => value;
  @override
  Future<bool> hasAccessToken() async => value != null;
  @override
  Future<void> persistSession(String session) async { value = session; }
  @override
  Future<void> removePersistedSession() async { value = null; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'test-session';
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('existing login migrates and plaintext copy is removed', () async {
    final legacy = MemoryLegacy('existing-session');
    final storage = SecureSessionStorage(key: key, legacy: legacy);
    await storage.initialize();
    expect(await storage.accessToken(), 'existing-session');
    expect(legacy.value, isNull);
    expect(await storage.hasAccessToken(), isTrue);
  });
  test('secure session wins over stale migration data', () async {
    FlutterSecureStorage.setMockInitialValues({key: 'new-session'});
    final legacy = MemoryLegacy('old-session');
    final storage = SecureSessionStorage(key: key, legacy: legacy);
    await storage.initialize();
    expect(await storage.accessToken(), 'new-session');
    expect(legacy.value, isNull);
  });
  test('refresh stays secure and logout cannot restore an old session', () async {
    final legacy = MemoryLegacy('old-session');
    final storage = SecureSessionStorage(key: key, legacy: legacy);
    await storage.initialize();
    await storage.persistSession('refreshed-session');
    expect(await storage.accessToken(), 'refreshed-session');
    expect(legacy.value, isNull);
    await storage.removePersistedSession();
    await SecureSessionStorage(key: key, legacy: legacy).initialize();
    expect(await storage.hasAccessToken(), isFalse);
  });
}
