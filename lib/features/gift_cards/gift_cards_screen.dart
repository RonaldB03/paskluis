import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../shared/widgets/main_bottom_nav.dart';
import '../cards/cards_screen.dart';
import '../home/home_screen.dart';
import '../qr_codes/qr_codes_screen.dart';
import 'gift_card_view_screen.dart';

class GiftCardsScreen extends StatelessWidget {
  final VoidCallback onAdd;

  const GiftCardsScreen({
    super.key,
    required this.onAdd,
  });

  List<Map<String, dynamic>> getItems() {
    final items = StorageService.cardsBox.values
        .where((item) => item is Map && item['type'] == 'Cadeaukaart')
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    items.sort((a, b) {
      final aFavorite = a['isFavorite'] == true;
      final bFavorite = b['isFavorite'] == true;

      if (aFavorite != bFavorite) {
        return aFavorite ? -1 : 1;
      }

      final aDate = DateTime.tryParse(a['lastUsedAt']?.toString() ?? '') ??
          DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final bDate = DateTime.tryParse(b['lastUsedAt']?.toString() ?? '') ??
          DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return items;
  }

  void openTab(BuildContext context, int index) {
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CardsScreen(onAdd: () {})),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => QrCodesScreen(onAdd: () {})),
      );
    } else if (index == 3) {
      return;
    }
  }

  void openGiftCard(
      BuildContext context,
      List<Map<String, dynamic>> items,
      int index,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GiftCardViewScreen(
          items: items,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: StorageService.cardsBox.listenable(),
      builder: (context, box, _) {
        final items = getItems();

        return Scaffold(
          backgroundColor: const Color(0xFFF4F4F6),
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(
                Icons.home_rounded,
                color: Color(0xFFD51B46),
              ),
              onPressed: () => openTab(context, 0),
            ),
            title: const Text(
              'Cadeaukaarten',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF333333),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.add,
                  color: Color(0xFFD51B46),
                  size: 32,
                ),
                onPressed: onAdd,
              ),
            ],
          ),
          body: items.isEmpty
              ? _EmptyGiftCardState(onAdd: onAdd)
              : GridView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.28,
            ),
            itemBuilder: (context, index) {
              final item = items[index];

              return _GiftCardTile(
                item: item,
                onTap: () => openGiftCard(context, items, index),
              );
            },
          ),
          bottomNavigationBar: MainBottomNav(
            currentIndex: 3,
            onTap: (index) => openTab(context, index),
          ),
        );
      },
    );
  }
}

class _EmptyGiftCardState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyGiftCardState({
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 44,
              backgroundColor: Color(0xFFF8E3EA),
              child: Icon(
                Icons.card_giftcard,
                size: 48,
                color: Color(0xFFD51B46),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Nog geen cadeaukaarten toegevoegd',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Bewaar cadeaukaarten met barcode, saldo en eventueel een pincode of krascode.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.35,
                color: Color(0xFF555557),
              ),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Cadeaukaart toevoegen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftCardTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _GiftCardTile({
    required this.item,
    required this.onTap,
  });

  bool get hasCustomLogo {
    final path = item['customImage']?.toString() ?? '';
    return path.isNotEmpty && File(path).existsSync();
  }

  bool get hasAssetLogo => (item['logoAsset']?.toString() ?? '').isNotEmpty;

  Color get cardColor {
    final parsed = int.tryParse(item['brandColor']?.toString() ?? '');
    if (parsed != null) return Color(parsed);
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final title = item['name']?.toString() ?? 'Cadeaukaart';
    final logoAsset = item['logoAsset']?.toString() ?? '';
    final customImage = item['customImage']?.toString() ?? '';
    final balance = item['currentBalance']?.toString() ?? '';
    final isFavorite = item['isFavorite'] == true;
    final hasLogo = hasAssetLogo || hasCustomLogo;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: hasAssetLogo ? cardColor : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Icon(
                isFavorite ? Icons.star : Icons.card_giftcard,
                color: hasAssetLogo ? Colors.white : const Color(0xFFD51B46),
                size: 22,
              ),
            ),
            Expanded(
              child: Center(
                child: hasLogo
                    ? hasCustomLogo
                    ? Image.file(
                  File(customImage),
                  fit: BoxFit.contain,
                  height: 66,
                  width: double.infinity,
                )
                    : Image.asset(
                  logoAsset,
                  fit: BoxFit.contain,
                  height: 66,
                  width: double.infinity,
                )
                    : Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: hasAssetLogo
                        ? Colors.white
                        : const Color(0xFF333333),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: hasAssetLogo
                    ? Colors.white.withOpacity(0.18)
                    : const Color(0xFFF8E3EA),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                balance.isEmpty ? 'Saldo onbekend' : '€ $balance',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: hasAssetLogo ? Colors.white : const Color(0xFFD51B46),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}