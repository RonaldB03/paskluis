import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'terms_document.dart';

/// Receipts are scoped to the account that explicitly accepted, never to a
/// later account using the same phone. Offline receipts retry on resume.
abstract final class TermsService {
  static final revision = ValueNotifier(0);
  static SharedPreferences? _prefs;
  static bool _syncing = false;
  static String get owner => SupabaseService.client?.auth.currentUser?.id ?? 'guest';
  static String keyFor(String owner) => 'terms_receipt_${TermsDocument.version}_$owner';
  static bool get accepted => receiptFor(owner) != null;
  static Map<String, dynamic>? receiptFor(String owner) {
    try {
      final value = jsonDecode(_prefs?.getString(keyFor(owner)) ?? 'null');
      if (value is Map && value['version'] == TermsDocument.version &&
          value['document_hash'] == TermsDocument.sha256 &&
          DateTime.tryParse(value['accepted_at']?.toString() ?? '') != null) {
        return Map<String, dynamic>.from(value);
      }
    } catch (_) { /* A damaged receipt requires a fresh explicit acceptance. */ }
    return null;
  }
  static Future<void> init() async { _prefs = await SharedPreferences.getInstance(); }
  static void accountChanged() { revision.value++; }
  static Future<void> accept(String expectedOwner, String language) async {
    if (expectedOwner != owner) throw StateError('Account changed');
    final saved = await _prefs!.setString(keyFor(expectedOwner), jsonEncode({
      'version': TermsDocument.version, 'document_hash': TermsDocument.sha256,
      'accepted_at': DateTime.now().toUtc().toIso8601String(),
      'language': language, 'synced': false,
    }));
    if (!saved) throw StateError('Receipt could not be saved');
    revision.value++;
  }
  static Future<void> sync() async {
    if (_syncing) return;
    final client = SupabaseService.client;
    final id = client?.auth.currentUser?.id;
    if (client == null || id == null) return;
    final receipt = receiptFor(id);
    if (receipt == null || receipt['synced'] == true) return;
    _syncing = true;
    try {
      await client.from('terms_acceptances').upsert({
        'user_id': id, 'version': receipt['version'],
        'document_hash': receipt['document_hash'],
        'accepted_at': receipt['accepted_at'], 'language': receipt['language'],
      }, onConflict: 'user_id,version', ignoreDuplicates: true)
          .timeout(const Duration(seconds: 8));
      await _prefs!.setString(keyFor(id), jsonEncode({...receipt, 'synced': true}));
    } catch (_) {
      // Local acceptance remains valid; retry only for this account.
    } finally { _syncing = false; }
  }
}
