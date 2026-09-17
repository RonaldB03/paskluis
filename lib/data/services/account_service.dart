import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

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

  static Future<void> signOut() => _client.auth.signOut();

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
