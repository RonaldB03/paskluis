import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../cards/card_detail_screen.dart';
import '../cards/cards_screen.dart';
import '../cards/choose_card_template_screen.dart';
import '../gift_cards/gift_cards_screen.dart';
import '../qr_codes/qr_codes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> getItemsByType(String type) {
    return StorageService.cardsBox.values
        .where((item) => item is Map && item['type'] == type)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  List<Map<String, dynamic>> getPreviewItems(List<Map<String, dynamic>> items) {
    final favorites = items.where((item) => item['isFavorite'] == true).toList();

    if (favorites.isNotEmpty) {
      return favorites.take(3).toList();
    }

    final sorted = [...items];
    sorted.sort((a, b) {
      final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return sorted.take(3).toList();
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

  Future<void> saveNewCard(
      Map<String, String> result, {
        String? forcedType,
      }) async {
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
      'brandId': result['brandId'] ?? '',
      'logoAsset': result['logoAsset'] ?? '',
      'brandColor': result['brandColor'] ?? '',
      'isFavorite': false,
      'createdAt': now,
      'updatedAt': now,
    };

    await StorageService.cardsBox.add(card);
  }

  Future<void> openAddScreen({
    String type = 'Pasje',
  }) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ChooseCardTemplateScreen(type: type),
      ),
    );

    if (result == null) return;

    await saveNewCard(result, forcedType: type);
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

  void openAllCardsScreen(String type, List<Map<String, dynamic>> items) {
    Widget screen;

    if (type == 'Pasje') {
      screen = CardsScreen(
        items: items,
        onDelete: deleteCard,
        onToggleFavorite: toggleFavorite,
        onAdd: () => openAddScreen(type: 'Pasje'),
      );
    } else if (type == 'QR-code') {
      screen = QrCodesScreen(
        items: items,
        onDelete: deleteCard,
        onToggleFavorite: toggleFavorite,
      );
    } else {
      screen = GiftCardsScreen(
        items: items,
        onDelete: deleteCard,
        onToggleFavorite: toggleFavorite,
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void openCardDetail(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardDetailScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: StorageService.cardsBox.listenable(),
      builder: (context, box, _) {
        final cards = getItemsByType('Pasje');
        final qrCodes = getItemsByType('QR-code');
        final giftCards = getItemsByType('Cadeaukaart');

        return Scaffold(
          backgroundColor: const Color(0xFFF4F4F6),
          appBar: AppBar(
            title: const Text('PasKluis'),
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
            foregroundColor: const Color(0xFF333333),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
            children: [
              _CategorySection(
                title: 'Klantenkaarten',
                icon: Icons.card_membership,
                items: getPreviewItems(cards),
                hasItems: cards.isNotEmpty,
                actionTitle: cards.isEmpty ? 'Voeg kaart toe' : 'Al je kaarten',
                onActionTap: cards.isEmpty
                    ? () => openAddScreen(type: 'Pasje')
                    : () => openAllCardsScreen('Pasje', cards),
                onItemTap: openCardDetail,
              ),
              const SizedBox(height: 26),
              _CategorySection(
                title: 'QR Codes',
                icon: Icons.qr_code,
                items: getPreviewItems(qrCodes),
                hasItems: qrCodes.isNotEmpty,
                actionTitle:
                qrCodes.isEmpty ? 'Voeg QR-code toe' : 'Al je QR-codes',
                onActionTap: qrCodes.isEmpty
                    ? () => openAddScreen(type: 'QR-code')
                    : () => openAllCardsScreen('QR-code', qrCodes),
                onItemTap: openCardDetail,
              ),
              const SizedBox(height: 26),
              _CategorySection(
                title: 'Cadeaukaarten',
                icon: Icons.card_giftcard,
                items: getPreviewItems(giftCards),
                hasItems: giftCards.isNotEmpty,
                actionTitle: giftCards.isEmpty
                    ? 'Voeg cadeaukaart toe'
                    : 'Al je cadeaukaarten',
                onActionTap: giftCards.isEmpty
                    ? () => openAddScreen(type: 'Cadeaukaart')
                    : () => openAllCardsScreen('Cadeaukaart', giftCards),
                onItemTap: openCardDetail,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final bool hasItems;
  final String actionTitle;
  final VoidCallback onActionTap;
  final Function(Map<String, dynamic> item) onItemTap;

  const _CategorySection({
    required this.title,
    required this.icon,
    required this.items,
    required this.hasItems,
    required this.actionTitle,
    required this.onActionTap,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalCards = items.length + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFD51B46)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: totalCards,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == items.length) {
                return _ActionMiniCard(
                  title: actionTitle,
                  icon: hasItems ? Icons.apps : Icons.add,
                  onTap: onActionTap,
                );
              }

              final item = items[index];

              return _PreviewMiniCard(
                title: item['name']?.toString() ?? 'Kaart',
                logoAsset: item['logoAsset']?.toString() ?? '',
                brandColor: item['brandColor']?.toString() ?? '',
                subtitle: item['isFavorite'] == true ? 'Favoriet' : 'Recent',
                onTap: () => onItemTap(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PreviewMiniCard extends StatelessWidget {
  final String title;
  final String logoAsset;
  final String brandColor;
  final String subtitle;
  final VoidCallback onTap;

  const _PreviewMiniCard({
    required this.title,
    required this.logoAsset,
    required this.brandColor,
    required this.subtitle,
    required this.onTap,
  });

  Color get cardColor {
    final parsed = int.tryParse(brandColor);
    if (parsed != null) return Color(parsed);
    return Colors.white;
  }

  bool get hasBrandStyle => logoAsset.isNotEmpty && brandColor.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasBrandStyle ? cardColor : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: hasBrandStyle
              ? Center(
            child: Image.asset(
              logoAsset,
              fit: BoxFit.contain,
              height: 70,
              width: double.infinity,
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.credit_card,
                color: Color(0xFFD51B46),
                size: 28,
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionMiniCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionMiniCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFD51B46),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}