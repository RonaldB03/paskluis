import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';
import 'device_session_service.dart';
import 'push_notification_service.dart';

class PlusStatus {
  final bool isActive;
  final DateTime? expiresAt;
  final String? source;

  const PlusStatus({
    required this.isActive,
    this.expiresAt,
    this.source,
  });

  static const inactive = PlusStatus(isActive: false);
}

class ManagedAccount {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool plusActive;

  const ManagedAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.plusActive,
  });
}

abstract final class AccountService {
  static SupabaseClient get _client {
    final client = SupabaseService.client;
    if (client == null) {
      throw const AuthException(
        'De online diensten zijn momenteel niet beschikbaar.',
      );
    }
    return client;
  }

  static User? get currentUser => SupabaseService.client?.auth.currentUser;

  static Stream<AuthState>? get authChanges =>
      SupabaseService.client?.auth.onAuthStateChange;

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name.trim()},
      emailRedirectTo: 'nl.paskluis.app://login-callback/',
    );
  }

  static Future<void> signOut({bool releaseDevice = true}) async {
    await PushNotificationService.unregisterCurrentToken();
    if (releaseDevice) {
      try {
        await DeviceSessionService.release();
      } catch (_) {
        // Signing out must remain possible while the backend is unavailable.
      }
    }
    await _client.auth.signOut();
  }

  static Future<UserResponse> updatePassword(String password) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }

  static Future<bool> isCurrentUserAdmin() async {
    final user = currentUser;
    if (user == null) return false;
    final row = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    return row?['role']?.toString() == 'admin';
  }

  static Future<List<ManagedAccount>> loadManagedAccounts() async {
    if (!await isCurrentUserAdmin()) {
      throw const AuthException('Alleen beheerders hebben toegang.');
    }

    final profiles = await _client
        .from('profiles')
        .select('id, display_name, email, role')
        .order('created_at', ascending: false);
    final entitlements = await _client
        .from('entitlements')
        .select('user_id, expires_at')
        .eq('product_id', 'paskluis_plus')
        .isFilter('revoked_at', null);

    final now = DateTime.now();
    final activeIds = entitlements.where((row) {
      final expiresAt = DateTime.tryParse(row['expires_at']?.toString() ?? '');
      return expiresAt == null || expiresAt.isAfter(now);
    }).map((row) => row['user_id']?.toString()).toSet();

    return profiles.map((row) {
      final id = row['id']?.toString() ?? '';
      return ManagedAccount(
        id: id,
        name: row['display_name']?.toString() ?? '',
        email: row['email']?.toString() ?? '',
        role: row['role']?.toString() ?? 'user',
        plusActive: activeIds.contains(id),
      );
    }).where((account) => account.id.isNotEmpty).toList();
  }

  static Future<void> setComplimentaryPlus({
    required String userId,
    required bool active,
  }) async {
    if (!await isCurrentUserAdmin()) {
      throw const AuthException('Alleen beheerders hebben toegang.');
    }

    if (active) {
      final existing = await _client
          .from('entitlements')
          .select('id')
          .eq('user_id', userId)
          .eq('product_id', 'paskluis_plus')
          .isFilter('revoked_at', null)
          .limit(1);
      if (existing.isNotEmpty) return;

      await _client.from('entitlements').insert({
        'user_id': userId,
        'product_id': 'paskluis_plus',
        'source': 'complimentary',
        'created_by': currentUser!.id,
        'note': 'Handmatig geactiveerd via PasKluis beheer',
      });
      return;
    }

    await _client
        .from('entitlements')
        .update({'revoked_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .eq('product_id', 'paskluis_plus')
        .isFilter('revoked_at', null);
  }

  static Future<PlusStatus> loadPlusStatus() async {
    final user = currentUser;
    if (user == null) return PlusStatus.inactive;

    final rows = await _client
        .from('entitlements')
        .select('product_id, source, expires_at')
        .eq('user_id', user.id)
        .eq('product_id', 'paskluis_plus')
        .isFilter('revoked_at', null);

    final now = DateTime.now();
    for (final row in rows) {
      final expiresAt = DateTime.tryParse(
        row['expires_at']?.toString() ?? '',
      );
      if (expiresAt == null || expiresAt.isAfter(now)) {
        return PlusStatus(
          isActive: true,
          expiresAt: expiresAt,
          source: row['source']?.toString(),
        );
      }
    }

    return PlusStatus.inactive;
  }
}
