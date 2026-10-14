import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'locale_service.dart';
import 'storage_service.dart';
import 'watch_snapshot.dart';
import 'watch_logos.dart';

class WatchService extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = WatchService();
  static const channel = MethodChannel('nl.paskluis.app/watches');
  // Explicit beta build switch; ordinary production builds keep the current UI.
  static const betaEnabled = bool.fromEnvironment('WATCH_BETA');
  SharedPreferences? _prefs;
  StreamSubscription<dynamic>? _cards;
  Timer? _debounce;
  Timer? _retry;
  bool _disposed = false;
  bool _disconnecting = false;
  String? get pairedTarget => _prefs?.getString('watch.target');
  String get pairedName => _prefs?.getString('watch.name') ?? '';
  bool get locallyErased =>
      (status[pairedTarget] as Map?)?['locallyErased'] == true &&
      _prefs?.getBool('watch.dirty') != true;
  bool get waiting =>
      pairedTarget != null &&
      !locallyErased &&
      (_prefs?.getBool('watch.dirty') == true ||
          (status[pairedTarget] as Map?)?['confirmed'] != true);

  Future<List<Map>> wearDevices() async =>
      (await channel.invokeListMethod<dynamic>('wearDevices') ?? [])
          .whereType<Map>()
          .toList();

  Future<void> pair(String target, {String? id, String? name}) async {
    if (pairedTarget != null) {
      throw StateError('Unlink the current watch first');
    }
    if (target == 'wear') {
      if (id == null) throw StateError('Choose a watch');
      await channel.invokeMethod<void>('setWear', {'id': id});
    } else if (target == 'garmin') {
      if (id == null) throw StateError('Choose a watch');
      await channel.invokeMethod<void>('setGarmin', {'id': id});
    } else if (target == 'apple') {
      await refresh();
      if ((status['apple'] as Map?)?['installed'] != true) {
        throw StateError('Install the watch app first');
      }
    } else {
      throw StateError('Unsupported watch');
    }
    await _prefs!.setString('watch.target', target);
    await _prefs!.setString('watch.name', name ?? 'Apple Watch');
    for (final other in ['wear', 'garmin', 'apple']) {
      await _prefs!.setBool('watch.$other.enabled', other == target);
    }
    await _prefs!.setBool('watch.dirty', true);
    await sync(target);
  }

  Future<void> disconnect() async {
    if (busy) return;
    final target = pairedTarget;
    if (target == null) return;
    _disconnecting = true;
    try {
      if (target == 'wear') await channel.invokeMethod<void>('forgetWear');
      if (target == 'garmin') await channel.invokeMethod<void>('forgetGarmin');
      await _prefs!.setBool('watch.$target.enabled', false);
      await _prefs!.setStringList('watch.$target.selected', []);
      await _prefs!.remove('watch.target');
      await _prefs!.remove('watch.name');
      await _prefs!.setBool('watch.dirty', false);
      _pending.clear();
      error = null;
      await refresh();
    } finally {
      _disconnecting = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(retryPending());
  }

  Future<void> retryPending() async {
    if (_disposed || _disconnecting || busy || pairedTarget == null) return;
    await refresh();
    if (waiting && !_disposed && !busy) await sync(pairedTarget!);
  }

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
    WidgetsBinding.instance.addObserver(this);
    _retry = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(retryPending()),
    );
    await refresh();

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
    if (!_disposed) notifyListeners();
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
    if (pairedTarget != target) throw StateError('Pair a watch first');
    // Validate before storing, so a too-large selection never strands deletions.
    preview(target, ids);
    await _prefs!.setStringList('watch.$target.selected', ids.toList());
    await _prefs!.setBool('watch.$target.enabled', true);
    await _prefs!.setBool('watch.dirty', true);
    notifyListeners();
    await sync(target);
  }

  Future<void> clear(String target) async {
    if (pairedTarget != target) throw StateError('Pair a watch first');
    await _prefs!.setStringList('watch.$target.selected', []);
    // Keep enabled until the empty replacement has reached the watch.
    await _prefs!.setBool('watch.$target.enabled', true);
    await _prefs!.setBool('watch.dirty', true);
    notifyListeners();
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

  void schedule() {
    if (_prefs == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final target = pairedTarget;
      if (target != null && enabled(target)) {
        unawaited(
          _prefs!.setBool('watch.dirty', true).then((_) => sync(target)),
        );
      }
    });
  }

  Future<void> sync(String target) async {
    if (_prefs == null ||
        _disposed ||
        _disconnecting ||
        pairedTarget != target) {
      return;
    }
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
          final logos = next == 'wear'
              ? await WatchLogos.build(
                  StorageService.cardsBox.values.whereType<Map>(),
                  (snapshot['cards'] as List)
                      .map((c) => (c as Map)['id'].toString())
                      .toSet(),
                )
              : const <String, String>{};
          await channel
              .invokeMethod<void>('replace', {
                'target': next,
                'snapshot': jsonEncode(snapshot),
                if (next == 'wear') 'logos': jsonEncode(logos),
              })
              .timeout(const Duration(seconds: 30));
          if (_pending.isEmpty) await _prefs!.setBool('watch.dirty', false);
        } on PlatformException {
          await _prefs!.setBool('watch.dirty', true);
          error = 'connection';
        } on MissingPluginException {
          error = 'unavailable';
        } on TimeoutException {
          await _prefs!.setBool('watch.dirty', true);
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
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    _cards?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
