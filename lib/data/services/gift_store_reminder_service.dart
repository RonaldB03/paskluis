import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'location_service.dart';
import 'nearby_store_service.dart';
import 'settings_service.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import '../../shared/utils/money_input.dart';
import '../../shared/utils/amount_format.dart';
import '../../l10n/l10n.dart';

/// Only store name, coordinates, expiry and reminder text reach native storage.
/// Card numbers, PINs and account details are never passed to the monitor.
class GiftStoreReminderService with WidgetsBindingObserver {
  static final instance = GiftStoreReminderService();
  static const channel = MethodChannel('nl.paskluis.app/gift-store-reminders');
  static bool get supported => Platform.isIOS;
  StreamSubscription<dynamic>? _cards;
  int _generation = 0;
  Timer? _debounce;
  bool _started = false;

  void start() {
    if (_started || !supported) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    SettingsService.settingsRevision.addListener(_changed);
    _cards = StorageService.cardsBox.watch().listen((_) => _changed());
    unawaited(refresh());
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SettingsService.settingsRevision.removeListener(_changed);
    _cards?.cancel();
    _debounce?.cancel();
    _generation++;
    _started = false;
  }

  void _changed() {
    // Clear immediately: stale amounts or deleted cards must never notify.
    _generation++;
    unawaited(_clear());
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(refresh()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  Future<String> permission() async {
    if (!supported) return 'unsupported';
    return await channel.invokeMethod<String>('status') ?? 'unavailable';
  }

  Future<bool> requestPermission() async {
    if (!supported || !await NotificationService.requestPermission())
      return false;
    final location = await LocationService.resolve(requestPermission: true);
    if (location.state != LocationAccessState.ready) return false;
    await channel.invokeMethod<void>('requestAlways');
    return true; // iOS may ask for Always later; settings shows the actual status.
  }

  Future<void> _clear() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('replace', {'regions': <Object>[]});
    } catch (_) {}
  }

  Future<void> refresh() async {
    if (!supported) return;
    final generation = ++_generation;
    if (!SettingsService.nearbyGiftNotificationsEnabled ||
        !SettingsService.locationCardsEnabled) {
      await _clear();
      return;
    }
    // A region event may launch iOS in the background. Keep that work local:
    // only refresh store coordinates while the user is actually using the app.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
      return;
    final now = DateTime.now();
    final cards = StorageService.cardsBox.values
        .whereType<Map>()
        .where((card) => giftCardCanRemind(card, now))
        .map((card) => Map<String, dynamic>.from(card))
        .toList();
    if (cards.isEmpty) {
      await _clear();
      return;
    }
    try {
      final snapshot = await LocationService.resolve();
      if (snapshot.location == null || generation != _generation) return;
      final matches = await NearbyStoreService.resolveForCards(
        cards,
        snapshot.location!,
      );
      if (generation != _generation ||
          !SettingsService.nearbyGiftNotificationsEnabled ||
          !SettingsService.locationCardsEnabled)
        return;
      final regions = buildGiftStoreReminders(
        cards,
        matches,
        now: now,
        showAmount: SettingsService.nearbyGiftShowAmount,
      );
      await channel.invokeMethod<void>('replace', {'regions': regions});
    } catch (_) {
      // Keep the last verified regions during temporary network errors; native
      // expiry prevents notifying indefinitely with an old balance.
    }
  }
}

/// Builds a bounded, non-sensitive native snapshot from verified store matches.
List<Map<String, Object>> buildGiftStoreReminders(
  List<Map<String, dynamic>> cards,
  Map<String, NearbyStoreMatch> matches, {
  required DateTime now,
  required bool showAmount,
}) {
  final regions = <String, Map<String, Object>>{};
  final sorted = [...cards]
    ..sort(
      (a, b) => (matches[a['id']]?.distanceMeters ?? double.infinity).compareTo(
        matches[b['id']]?.distanceMeters ?? double.infinity,
      ),
    );
  for (final card in sorted) {
    if (!giftCardCanRemind(card, now)) continue;
    final store = matches[card['id']?.toString()];
    final lat = store?.latitude;
    final lon = store?.longitude;
    if (store == null ||
        lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180)
      continue;
    // Same physical store gets one region and one notification, even for multiple cards.
    final id = '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
    if (regions.containsKey(id)) continue;
    final expiry = DateTime.tryParse(card['expiryDate']?.toString() ?? '');
    final staleAfter = now.add(const Duration(days: 7));
    final end = expiry == null
        ? staleAfter
        : DateTime(expiry.year, expiry.month, expiry.day + 1);
    final until = end.isBefore(staleAfter) ? end : staleAfter;
    regions[id] = {
      'id': id,
      'latitude': lat,
      'longitude': lon,
      'radius': 100.0,
      'validUntil': until.millisecondsSinceEpoch / 1000,
      'title': 'PasKluis',
      'body': showAmount
          ? L10n.current.nearbyGiftAmount(
              store.storeName,
              formatAmountValue(card['currentBalance'].toString()),
            )
          : L10n.current.nearbyGiftAvailable(store.storeName),
    };
    if (regions.length == 20) break;
  }
  return regions.values.toList();
}

bool giftCardCanRemind(Map card, DateTime now) {
  final expiry = DateTime.tryParse(card['expiryDate']?.toString() ?? '');
  final today = DateTime(now.year, now.month, now.day);
  return card['type'] == 'Cadeaukaart' &&
      card['isArchived'] != true &&
      card['isArchived']?.toString() != 'true' &&
      (parseMoneyCents(card['currentBalance']?.toString() ?? '') ?? 0) > 0 &&
      (expiry == null ||
          !DateTime(expiry.year, expiry.month, expiry.day).isBefore(today));
}
