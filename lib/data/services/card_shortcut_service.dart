import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';
import 'locale_service.dart';
import 'storage_service.dart';
import '../../features/cards/card_view_screen.dart';
import '../../features/gift_cards/gift_card_view_screen.dart';
import '../../features/qr_codes/qr_codes_screen.dart';

/// Only opaque IDs and generic labels leave the protected vault.
class CardShortcutService {
  final GlobalKey<NavigatorState> navigatorKey;
  CardShortcutService(this.navigatorKey);
  final QuickActions _actions = const QuickActions();
  StreamSubscription? _changes;
  bool _disposed = false;
  bool _updating = false;
  bool _again = false;

  static List<Map<String, dynamic>> favorites(Iterable<dynamic> values) =>
      values
          .whereType<Map>()
          .where(
            (c) =>
                (c['isFavorite'] == true || c['isFavorite'] == 'true') &&
                c['isArchived'] != true &&
                c['isArchived'] != 'true' &&
                (c['id']?.toString() ?? '').isNotEmpty,
          )
          .take(3)
          .map((c) => Map<String, dynamic>.from(c))
          .toList();

  Future<void> start() async {
    try {
      await _actions.initialize(_open);
      if (_disposed) return;
      _changes = StorageService.cardsBox.watch().listen((_) => refresh());
      LocaleService.locale.addListener(refresh);
      await refresh();
    } catch (_) {
      /* Unsupported devices keep normal navigation. */
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    if (_updating) {
      _again = true;
      return;
    }
    _updating = true;
    try {
      do {
        _again = false;
        final cards = favorites(StorageService.cardsBox.values);
        final nl = LocaleService.languageCode == 'nl';
        await _actions.setShortcutItems([
          for (var i = 0; i < cards.length; i++)
            ShortcutItem(
              type: 'card:${cards[i]['id']}',
              localizedTitle: nl ? 'Favoriet ${i + 1}' : 'Favorite ${i + 1}',
            ),
        ]);
      } while (_again && !_disposed);
    } catch (_) {
      /* Shortcut updates must not block a local save. */
    } finally {
      _updating = false;
    }
  }

  void _open(String type) {
    if (_disposed || !type.startsWith('card:')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final cards = favorites(StorageService.cardsBox.values);
      final matches = cards.where(
        (c) => c['id'].toString() == type.substring(5),
      );
      if (matches.isEmpty)
        return; // Deleted, archived or revoked shortcuts expire.
      final card = matches.first;
      final Widget screen = switch (card['type']) {
        'Cadeaukaart' => GiftCardViewScreen(items: [card], initialIndex: 0),
        'QR-code' ||
        'QR-set' => QrCodeViewScreen(items: [card], initialIndex: 0),
        _ => CardViewScreen(items: [card], initialIndex: 0),
      };
      // The application's AppLockGate wraps this same Navigator.
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => screen),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void dispose() {
    _disposed = true;
    _changes?.cancel();
    LocaleService.locale.removeListener(refresh);
  }
}
