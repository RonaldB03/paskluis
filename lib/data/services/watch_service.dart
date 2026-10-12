import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'locale_service.dart';
import 'storage_service.dart';
import 'watch_snapshot.dart';

class WatchService extends ChangeNotifier {
  static final instance = WatchService();
  static const channel = MethodChannel('nl.paskluis.app/watches');
  // Explicit beta build switch; ordinary production builds keep the current UI.
  static const betaEnabled = bool.fromEnvironment('WATCH_BETA');
  SharedPreferences? _prefs;
  StreamSubscription<dynamic>? _cards;
  Timer? _debounce;
  bool busy = false;
  String? error;
  Map<String, dynamic> status = {};
  final Set<String> _pending = {};
  Set<String> selected(String target) =>
      _prefs?.getStringList('watch.$target.selected')?.toSet() ?? {};
  bool enabled(String target) =>
      _prefs?.getBool('watch.$target.enabled') ?? false;

  Future<void> init() async {
    if (!betaEnabled || _prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    if (_prefs!.getString('watch.owner') == null) {
      final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
      await _prefs!.setString('watch.owner', base64UrlEncode(bytes));
    }
    _cards = StorageService.cardsBox.watch().listen((_) => schedule());
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await refresh();
    });
    await refresh();
    schedule();
  }

  Future<void> refresh() async {
    if (_prefs == null) return;
    try {
      status = Map<String, dynamic>.from(
        await channel.invokeMapMethod<String, dynamic>('status') ?? {},
      );
    } on PlatformException {
      error = 'unavailable';
    } on MissingPluginException {
      error = 'unavailable';
    }
    notifyListeners();
  }

  Map<String, Object> preview(
    String target,
    Set<String> ids, {
    int revision = 0,
  }) => WatchSnapshot.build(
    cards: StorageService.cardsBox.values.whereType<Map>(),
    selected: ids,
    owner: _prefs?.getString('watch.owner') ?? '',
    revision: revision,
    language: LocaleService.languageCode,
  );

  Future<void> select(String target, Set<String> ids) async {
    // Validate before storing, so a too-large selection never strands deletions.
    preview(target, ids);
    await _prefs!.setStringList('watch.$target.selected', ids.toList());
    await _prefs!.setBool('watch.$target.enabled', true);
    await sync(target);
  }

  Future<void> clear(String target) async {
    await _prefs!.setStringList('watch.$target.selected', []);
    // Keep enabled until the empty replacement has reached the watch.
    await _prefs!.setBool('watch.$target.enabled', true);
    await sync(target);
  }

  Future<void> chooseGarmin() async {
    try {
      await channel.invokeMethod<void>('chooseGarmin');
    } on PlatformException catch (_) {
      error = 'garmin_unavailable';
      notifyListeners();
    } on MissingPluginException {
      error = 'unavailable';
      notifyListeners();
    }
  }

  Future<void> setGarmin(String id) async {
    await channel.invokeMethod<void>('setGarmin', {'id': id});
    await refresh();
    if (enabled('garmin')) await sync('garmin');
  }

  Future<void> forgetGarmin() async {
    await channel.invokeMethod<void>('forgetGarmin');
    await _prefs!.setBool('watch.garmin.enabled', false);
    await _prefs!.setStringList('watch.garmin.selected', []);
    await refresh();
  }

  void schedule() {
    if (_prefs == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      for (final target in ['apple', 'wear', 'garmin']) {
        if (enabled(target)) unawaited(sync(target));
      }
    });
  }

  Future<void> sync(String target) async {
    if (_prefs == null) return;
    _pending.add(target);
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      while (_pending.isNotEmpty) {
        final next = _pending.first;
        _pending.remove(next);
        final revision = (_prefs!.getInt('watch.revision') ?? 0) + 1;
        await _prefs!.setInt('watch.revision', revision);
        Map<String, Object> snapshot;
        try {
          snapshot = preview(next, selected(next), revision: revision);
        } on FormatException {
          // If an edited code becomes unsupported, revoke the stale copy.
          snapshot = preview(next, {}, revision: revision);
          error = 'invalid_cards';
        }
        try {
          await channel
              .invokeMethod<void>('replace', {
                'target': next,
                'snapshot': jsonEncode(snapshot),
              })
              .timeout(const Duration(seconds: 30));
        } on PlatformException {
          error = 'connection';
        } on MissingPluginException {
          error = 'unavailable';
        } on TimeoutException {
          error = 'connection';
        }
      }
    } finally {
      busy = false;
      await refresh();
    }
  }

  @override
  void dispose() {
    _cards?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
