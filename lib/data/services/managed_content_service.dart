import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

abstract final class ManagedContentService {
  static const _cacheKey = 'managed_content_app_copy_v1';
  static final revision = ValueNotifier<int>(0);
  static Map<String, dynamic> _content = const {};

  static Future<void> init() async {
    final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
    if (raw != null) {
      try { _content = Map<String, dynamic>.from(jsonDecode(raw) as Map); } catch (_) {}
    }
  }

  static Future<void> refresh() async {
    final client = SupabaseService.client;
    if (client == null) return;
    try {
      final payload = Map<String, dynamic>.from(
        await client.rpc('get_published_content', params: {'p_key': 'app.copy'}) as Map,
      );
      final next = Map<String, dynamic>.from(payload['content'] as Map);
      _content = next;
      await (await SharedPreferences.getInstance()).setString(_cacheKey, jsonEncode(next));
      revision.value++;
    } catch (_) {
      // De ingebouwde teksten blijven beschikbaar zonder netwerk of tijdens onderhoud.
    }
  }

  static String text(String path, String language, String fallback) {
    dynamic value = _content;
    for (final segment in path.split('.')) {
      if (value is! Map || !value.containsKey(segment)) return fallback;
      value = value[segment];
    }
    if (value is Map) value = value[language] ?? value['nl'];
    return value is String && value.trim().isNotEmpty ? value : fallback;
  }
}
