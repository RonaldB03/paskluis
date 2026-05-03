import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../data/templates/card_templates.dart';
import '../../shared/widgets/main_bottom_nav.dart';
import '../gift_cards/gift_cards_screen.dart';
import '../home/home_screen.dart';
import '../qr_codes/qr_codes_screen.dart';
import 'card_view_screen.dart';

class CardsScreen extends StatelessWidget {
  final VoidCallback onAdd;

  const CardsScreen({
    super.key,
    required this.onAdd,
  });

  List<Map<String, dynamic>> getItems() {
    final items = StorageService.cardsBox.values
        .where((item) => item is Map && item['type'] == 'Pasje')
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
      return;
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => QrCodesScreen(onAdd: () {})),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GiftCardsScreen(onAdd: () {})),
      );
    }
  }

  void openCard(
      BuildContext context,
      List<Map<String, dynamic>> items,
      int index,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardViewScreen(
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
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Klantenkaarten',
              style: TextStyle(
                color: Color(0xFF333333),
                fontWeight: FontWeight.w800,
              ),
            ),
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
              ? _EmptyCardsState(onAdd: onAdd)
              : GridView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.45,
            ),
            itemBuilder: (context, index) {
              final item = items[index];

              return _StoredCardTile(
                item: item,
                onTap: () => openCard(context, items, index),
              );
            },
          ),
          bottomNavigationBar: MainBottomNav(
            currentIndex: 1,
            onTap: (index) => openTab(context, index),
          ),
        );
      },
    );
  }
}

class _EmptyCardsState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyCardsState({
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final previewBrands = cardBrandTemplates.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
      children: [
        const Text(
          'Nog geen klantenkaarten toegevoegd',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            height: 1.12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF444446),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Tik op + of kies een populaire winkel om je klantenkaart toe te voegen.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            height: 1.3,
            color: Color(0xFF555557),
          ),
        ),
        const SizedBox(height: 30),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Klantenkaart toevoegen'),
        ),
        const SizedBox(height: 34),
        const Text(
          'Populaire winkels',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: previewBrands.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) {
            final brand = previewBrands[index];

            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: brand.color,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Image.asset(
                    brand.logoAsset,
                    fit: BoxFit.contain,
                    height: 74,
                    width: double.infinity,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StoredCardTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _StoredCardTile({
    required this.item,
    required this.onTap,
  });

  Color get cardColor {
    final parsed = int.tryParse(item['brandColor']?.toString() ?? '');
    if (parsed != null) return Color(parsed);
    return Colors.white;
  }

  bool get hasAssetLogo => (item['logoAsset']?.toString() ?? '').isNotEmpty;

  bool get hasCustomLogo {
    final path = item['customImage']?.toString() ?? '';
    return path.isNotEmpty && File(path).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final logoAsset = item['logoAsset']?.toString() ?? '';
    final customImage = item['customImage']?.toString() ?? '';
    final title = item['name']?.toString() ?? 'Kaart';
    final isFavorite = item['isFavorite'] == true;
    final useImage = hasAssetLogo || hasCustomLogo;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(15),
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
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Icon(
                isFavorite ? Icons.star : Icons.card_membership,
                color: hasAssetLogo ? Colors.white : const Color(0xFFD51B46),
                size: 22,
              ),
            ),
            Expanded(
              child: Center(
                child: useImage
                    ? hasCustomLogo
                    ? Image.file(
                  File(customImage),
                  fit: BoxFit.contain,
                  height: 74,
                  width: double.infinity,
                )
                    : Image.asset(
                  logoAsset,
                  fit: BoxFit.contain,
                  height: 74,
                  width: double.infinity,
                )
                    : Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: hasAssetLogo
                        ? Colors.white
                        : const Color(0xFF333333),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}