import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'supabase_service.dart';

/// Store access belongs to the store receipt, independently of app sign-in.
/// Proofs stay in secure storage and are never part of card backups or logs.
abstract final class StoreAccessService {
  static const _secure = FlutterSecureStorage();
  static const _key = 'verified_store_access_v1';
  static Map<String, dynamic>? _cached;
  static bool _loaded = false;
  static Future<bool>? _refresh;
  static String? linkedUserId;

  static bool cacheIsActive(Map<String, dynamic>? row, DateTime now) {
    if (row?['active'] != true) return false;
    final checked = DateTime.tryParse(row?['verifiedAt']?.toString() ?? '');
    return checked != null &&
        !checked.isAfter(now) &&
        now.difference(checked) < const Duration(days: 7);
  }

  static Future<bool> load() async {
    if (!_loaded) {
      String? raw;
      try { raw = await _secure.read(key: _key); }
      catch (_) { return false; }
      try {
        _cached = raw == null
            ? null
            : Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {
        _cached = null;
      }
      _loaded = true;
    }
    final row = _cached;
    if (row == null) return false;
    linkedUserId = row['linkedUserId'] as String?;
    final checked = DateTime.tryParse(row['verifiedAt']?.toString() ?? '');
    if (checked != null &&
        DateTime.now().difference(checked).inMinutes < 15 &&
        !checked.isAfter(DateTime.now()))
      return cacheIsActive(row, DateTime.now());
    return _refresh ??= _refreshAccess(row).whenComplete(() => _refresh = null);
  }

  static Future<bool> _refreshAccess(Map<String, dynamic> row) async {
    try {
      return await verify(row['proof'] as String);
    } catch (_) {
      return cacheIsActive(_cached, DateTime.now());
    }
  }

  static Future<bool> verify(String proof, {bool linkAccount = false}) async {
    final client = SupabaseService.client;
    if (client == null) throw StateError('Store verification unavailable');
    final response = await client.functions.invoke(
      'verify-store-purchase',
      body: {
        'platform': Platform.isIOS ? 'apple' : 'google',
        'productId': 'paskluis_plus',
        'proof': proof,
        'linkAccount': linkAccount,
      },
    ).timeout(const Duration(seconds: 45));
    final data = response.data;
    if (data is! Map || data['verified'] != true || data['active'] is! bool) {
      throw StateError('Store verification failed');
    }
    linkedUserId = data['linkedUserId'] as String?;
    _cached = {
      'proof': proof,
      'active': data['active'],
      'linkedUserId': linkedUserId,
      'verifiedAt': DateTime.now().toUtc().toIso8601String(),
    };
    _loaded = true;
    await _secure.write(key: _key, value: jsonEncode(_cached));
    return data['active'] == true;
  }

  static Future<bool> linkToAccount() async {
    await load();
    final proof = _cached?['proof'];
    if (proof is! String) return false;
    return verify(proof, linkAccount: true);
  }
}
