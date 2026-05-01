import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../shared/widgets/main_bottom_nav.dart';
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

  Future<void> saveNewCard(
      Map<String, String> result, {
        required String forcedType,
      }) async {
    final now = DateTime.now().toIso8601String();

    final Map<String, dynamic> card = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': result['type'] ?? forcedType,
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
      'customImage': result['customImage'] ?? '',
      'isFavorite': false,
      'createdAt': now,
      'updatedAt': now,
    };

    await StorageService.cardsBox.add(card);
  }

  Future<void> openAddFlow(String type) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ChooseCardTemplateScreen(type: type),
      ),
    );

    if (result == null) return;

    await saveNewCard(result, forcedType: type);
  }

  void showAddChoices() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Wat wil je toevoegen?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                _AddChoiceTile(
                  icon: Icons.card_membership,
                  title: 'Klantenkaart toevoegen',
                  onTap: () {
                    Navigator.pop(context);
                    openAddFlow('Pasje');
                  },
                ),
                _AddChoiceTile(
                  icon: Icons.qr_code,
                  title: 'QR-code toevoegen',
                  onTap: () {
                    Navigator.pop(context);
                    openAddFlow('QR-code');
                  },
                ),
                _AddChoiceTile(
                  icon: Icons.card_giftcard,
                  title: 'Cadeaukaart toevoegen',
                  onTap: () {
                    Navigator.pop(context);
                    openAddFlow('Cadeaukaart');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openTab(int index) {
    if (index == 0) return;

    Widget screen;

    if (index == 1) {
      screen = CardsScreen(onAdd: () => openAddFlow('Pasje'));
    } else if (index == 2) {
      screen = QrCodesScreen(onAdd: () => openAddFlow('QR-code'));
    } else {
      screen = GiftCardsScreen(onAdd: () => openAddFlow('Cadeaukaart'));
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
            actions: [
              IconButton(
                onPressed: showAddChoices,
                icon: const Icon(Icons.add, color: Color(0xFFD51B46), size: 32),
              ),
            ],
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
                onActionTap:
                cards.isEmpty ? () => openAddFlow('Pasje') : () => openTab(1),
                onItemTap: openCardDetail,
              ),
              const SizedBox(height: 30),
              _CategorySection(
                title: 'QR-codes',
                icon: Icons.qr_code,
                items: getPreviewItems(qrCodes),
                hasItems: qrCodes.isNotEmpty,
                actionTitle:
                qrCodes.isEmpty ? 'Voeg QR-code toe' : 'Al je QR-codes',
                onActionTap: qrCodes.isEmpty
                    ? () => openAddFlow('QR-code')
                    : () => openTab(2),
                onItemTap: openCardDetail,
              ),
              const SizedBox(height: 30),
              _CategorySection(
                title: 'Cadeaukaarten',
                icon: Icons.card_giftcard,
                items: getPreviewItems(giftCards),
                hasItems: giftCards.isNotEmpty,
                actionTitle: giftCards.isEmpty
                    ? 'Voeg cadeaukaart toe'
                    : 'Al je cadeaukaarten',
                onActionTap: giftCards.isEmpty
                    ? () => openAddFlow('Cadeaukaart')
                    : () => openTab(3),
                onItemTap: openCardDetail,
              ),
            ],
          ),
          bottomNavigationBar: MainBottomNav(
            currentIndex: 0,
            onTap: openTab,
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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return _ActionCard(
                title: actionTitle,
                icon: hasItems ? Icons.apps : Icons.add,
                onTap: onActionTap,
              );
            }

            final item = items[index];

            return _PreviewCard(
              title: item['name']?.toString() ?? 'Kaart',
              logoAsset: item['logoAsset']?.toString() ?? '',
              customImage: item['customImage']?.toString() ?? '',
              brandColor: item['brandColor']?.toString() ?? '',
              onTap: () => onItemTap(item),
            );
          },
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String title;
  final String logoAsset;
  final String customImage;
  final String brandColor;
  final VoidCallback onTap;

  const _PreviewCard({
    required this.title,
    required this.logoAsset,
    required this.customImage,
    required this.brandColor,
    required this.onTap,
  });

  Color get cardColor {
    final parsed = int.tryParse(brandColor);
    if (parsed != null) return Color(parsed);
    return Colors.white;
  }

  bool get hasAssetLogo => logoAsset.isNotEmpty;
  bool get hasCustomLogo => customImage.isNotEmpty && File(customImage).existsSync();

  @override
  Widget build(BuildContext context) {
    final useImage = hasAssetLogo || hasCustomLogo;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasAssetLogo ? cardColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: useImage
            ? Center(
          child: hasCustomLogo
              ? Image.file(
            File(customImage),
            fit: BoxFit.contain,
            height: 72,
            width: double.infinity,
          )
              : Image.asset(
            logoAsset,
            fit: BoxFit.contain,
            height: 72,
            width: double.infinity,
          ),
        )
            : Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
    );
  }
}

class _AddChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AddChoiceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFF8E3EA),
        child: Icon(icon, color: const Color(0xFFD51B46)),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}