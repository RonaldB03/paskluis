import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../cards/add_card_screen.dart';
import '../cards/cards_screen.dart';
import '../gift_cards/gift_cards_screen.dart';
import '../qr_codes/qr_codes_screen.dart';
import '../scanner/scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  List<Map<String, dynamic>> getItemsByType(String type) {
    return StorageService.cardsBox.values
        .where((item) => item is Map && item['type'] == type)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  dynamic _findKeyById(String id) {
    for (final key in StorageService.cardsBox.keys) {
      final item = StorageService.cardsBox.get(key);

      if (item is Map && item['id'] == id) {
        return key;
      }
    }

    return null;
  }

  Future<void> saveNewCard(Map<String, String> result, {String? forcedType}) async {
    final now = DateTime.now().toIso8601String();

    final Map<String, dynamic> card = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': result['type'] ?? forcedType ?? '',
      'name': result['name'] ?? '',
      'code': result['code'] ?? '',
      'note': result['note'] ?? '',
      'cardNumber': result['cardNumber'] ?? '',
      'pinCode': result['pinCode'] ?? '',
      'initialBalance': result['initialBalance'] ?? '',
      'currentBalance': result['currentBalance'] ?? '',
      'isFavorite': false,
      'createdAt': now,
      'updatedAt': now,
    };

    await StorageService.cardsBox.add(card);

    setState(() {
      switch (card['type']) {
        case 'Pasje':
          _index = 0;
          break;
        case 'QR-code':
          _index = 1;
          break;
        case 'Cadeaukaart':
          _index = 2;
          break;
      }
    });
  }

  Future<void> openAddScreen({
    String type = 'Pasje',
    String? initialName,
    String? initialCode,
  }) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCardScreen(
          initialType: type,
          initialName: initialName,
          initialCode: initialCode,
        ),
      ),
    );

    if (result == null) return;

    await saveNewCard(result, forcedType: type);
  }

  Future<void> openScannerForLoyaltyCard() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(),
      ),
    );

    if (!mounted || code == null || code.isEmpty) return;

    await openAddScreen(
      type: 'Pasje',
      initialCode: code,
    );
  }

  Future<void> deleteCard(String id) async {
    final key = _findKeyById(id);

    if (key != null) {
      await StorageService.cardsBox.delete(key);
    }
  }

  Future<void> toggleFavorite(String id) async {
    final key = _findKeyById(id);

    if (key == null) return;

    final oldItem = StorageService.cardsBox.get(key);

    if (oldItem is! Map) return;

    final item = Map<String, dynamic>.from(oldItem);
    item['isFavorite'] = !(item['isFavorite'] == true);
    item['updatedAt'] = DateTime.now().toIso8601String();

    await StorageService.cardsBox.put(key, item);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: StorageService.cardsBox.listenable(),
      builder: (context, box, _) {
        final cards = getItemsByType('Pasje');
        final qrCodes = getItemsByType('QR-code');
        final giftCards = getItemsByType('Cadeaukaart');

        final screens = [
          CardsScreen(
            items: cards,
            onDelete: deleteCard,
            onToggleFavorite: toggleFavorite,
            onAdd: openScannerForLoyaltyCard,
          ),
          QrCodesScreen(
            items: qrCodes,
            onDelete: deleteCard,
            onToggleFavorite: toggleFavorite,
          ),
          GiftCardsScreen(
            items: giftCards,
            onDelete: deleteCard,
            onToggleFavorite: toggleFavorite,
          ),
        ];

        return Scaffold(
          body: screens[_index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              setState(() => _index = i);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.card_membership),
                label: 'Klantenkaarten',
              ),
              NavigationDestination(
                icon: Icon(Icons.qr_code),
                label: 'QR-codes',
              ),
              NavigationDestination(
                icon: Icon(Icons.card_giftcard),
                label: 'Cadeaukaarten',
              ),
            ],
          ),
        );
      },
    );
  }
}