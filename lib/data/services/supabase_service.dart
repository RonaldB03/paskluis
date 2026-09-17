import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

/// Initializes the optional online PasKluis services.
///
/// Cards remain stored locally and usable when Supabase or the internet is
/// unavailable. Authentication, Plus entitlements, managed brands and support
/// can use [client] after initialization succeeds.
abstract final class SupabaseService {
  static bool _isAvailable = false;

  static bool get isAvailable => _isAvailable;

  static SupabaseClient? get client =>
      _isAvailable ? Supabase.instance.client : null;

  static Future<void> init() async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      _isAvailable = true;
    } catch (_) {
      // PasKluis is local-first: a backend failure must never lock users out
      // of cards already stored securely on their device.
      _isAvailable = false;
    }
  }
}
