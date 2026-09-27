import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

/// Presentation only: this configuration never grants Plus or account rights.
class AppMenu {
  final Map<String, dynamic> json;
  AppMenu._(this.json);
  static const actions = {
    'help', 'support', 'share', 'lock', 'hidePins', 'privacy', 'backupAuto',
    'backupNow', 'restore', 'folders', 'favoritesFirst', 'favoritesHome',
    'sorting', 'start', 'clarity', 'location', 'radius', 'distances',
    'nearbyFirst', 'nearbyHome', 'brightness', 'awake', 'notifications',
    'language', 'plus', 'device', 'external',
  };
  static const icons = {'', 'help', 'share', 'security', 'backup', 'folder',
    'star', 'cards', 'home', 'display', 'location', 'notifications', 'language', 'link'};
  static bool safeUrl(Object? value) {
    if (value is! String || value.length > 2048 || RegExp(r'\s').hasMatch(value)) return false;
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.contains('.') && uri.userInfo.isEmpty;
  }
  static bool _localized(Object? value, int max, {bool requireText = false}) =>
      value is Map && ['nl', 'en'].every((lang) => value[lang] is String &&
          (value[lang] as String).length <= max &&
          (!requireText || (value[lang] as String).trim().isNotEmpty));

  static AppMenu? parse(Object? value) {
    try {
      if (value is! Map || value['schemaVersion'] != 1 || jsonEncode(value).length > 100000) return null;
      final share = value['share'];
      final sections = value['sections'];
      if (share is! Map || !safeUrl(share['url']) || !_localized(share['text'], 2000, requireText: true) ||
          sections is! List || sections.isEmpty || sections.length > 20) return null;
      final sectionIds = <String>{};
      final itemIds = <String>{};
      final actionIds = <String>{};
      var privacy = false;
      var count = 0;
      for (final section in sections) {
        if (section is! Map || !_id(section['id']) || !sectionIds.add(section['id']) ||
            !_localized(section['title'], 120, requireText: true) || !_localized(section['description'], 500) ||
            !icons.contains(section['icon']) || section['collapsed'] is! bool || section['hidden'] is! bool ||
            section['items'] is! List) return null;
        for (final item in section['items']) {
          if (++count > 100 || item is! Map || !_id(item['id']) || !itemIds.add(item['id']) ||
              !actions.contains(item['action']) || !icons.contains(item['icon']) ||
              !_localized(item['title'], 120) || !_localized(item['description'], 500) ||
              item['hidden'] is! bool || !{'all', 'free', 'plus', 'locked'}.contains(item['audience'])) return null;
          if (item['action'] != 'external' && !actionIds.add(item['action'])) return null;
          if (item['action'] == 'external' && (!safeUrl(item['url']) || !_localized(item['title'], 120, requireText: true))) return null;
          if (item['action'] == 'privacy' && section['hidden'] == false && item['hidden'] == false && item['audience'] == 'all') privacy = true;
        }
      }
      if (!privacy) return null;
      return AppMenu._(Map<String, dynamic>.from(jsonDecode(jsonEncode(value))));
    } catch (_) { return null; }
  }
  static bool _id(Object? value) => value is String && RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(value);
  static String text(Object? value, String language, [String fallback = '']) {
    if (value is! Map) return fallback;
    final s = value[language];
    return s is String && s.trim().isNotEmpty ? s : fallback;
  }
  static bool visible(Map item, bool plus) => item['hidden'] != true &&
      (item['audience'] != 'plus' || plus) && (item['audience'] != 'free' || !plus);
  List<Map<String, dynamic>> get sections => (json['sections'] as List).map((s) => Map<String, dynamic>.from(s)).toList();
  String shareText(String language) => '${text(json['share']['text'], language)}\n${json['share']['url']}';
}

abstract final class AppMenuService {
  static const cacheKey = 'app_menu_v1';
  static final revision = ValueNotifier(0);
  static AppMenu? current;
  static Future<void>? _loading;
  static Future<void> init() async {
    if (current != null) return;
    current = AppMenu.parse(jsonDecode(await rootBundle.loadString('assets/config/app_menu.json')));
    final prefs = await SharedPreferences.getInstance();
    try { current = AppMenu.parse(jsonDecode(prefs.getString(cacheKey) ?? 'null')) ?? current; } catch (_) { /* Keep built-in menu. */ }
  }
  static Future<void> refresh() => _loading ??= _refresh().whenComplete(() => _loading = null);
  static Future<void> _refresh() async {
    await init();
    try {
      final client = SupabaseService.client;
      if (client == null) return;
      final row = await client.from('app_menu_publication').select('config').eq('id', 1).maybeSingle().timeout(const Duration(seconds: 8));
      final menu = AppMenu.parse(row?['config']);
      if (menu == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(menu.json));
      current = menu;
      revision.value++;
    } catch (_) { /* Offline/invalid response retains the last valid menu. */ }
  }
}
