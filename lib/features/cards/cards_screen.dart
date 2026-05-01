import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../data/templates/card_templates.dart';
import '../../shared/widgets/main_bottom_nav.dart';
import '../gift_cards/gift_cards_screen.dart';
import '../home/home_screen.dart';
import '../qr_codes/qr_codes_screen.dart';
import 'add_card_screen.dart';
import 'card_view_screen.dart';

class CardsScreen extends StatelessWidget {
  final VoidCallback onAdd;

  const CardsScreen({
    super.key,
    required this.onAdd,
  });

  List<Map<String, dynamic>> getItems() {
    return StorageService.cardsBox.values
        .where((item) => item is Map && item['type'] == 'Pasje')
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
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
              icon: const Icon(Icons.home_rounded, color: Color(0xFFD51B46)),
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
                icon: const Icon(Icons.add, color: Color(0xFFD51B46), size: 32),
                onPressed: onAdd,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            children: [
              if (items.isEmpty) ...[
                const Text(
                  'Nog geen klantenkaarten toegevoegd',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    height: 1.12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444446),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Selecteer een winkel of tik op + om een klantenkaart toe te voegen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.3,
                    color: Color(0xFF555557),
                  ),
                ),
                const SizedBox(height: 36),
                _TemplateGrid(),
              ] else ...[
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CardViewScreen(
                              items: items,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ],
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

class _TemplateGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cardBrandTemplates.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final brand = cardBrandTemplates[index];

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddCardScreen(
                  initialType: 'Pasje',
                  initialName: brand.name,
                  initialBrandId: brand.id,
                  initialLogoAsset: brand.logoAsset,
                  initialBrandColor: brand.color.value.toString(),
                ),
              ),
            );
          },
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
    final useImage = hasAssetLogo || hasCustomLogo;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
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
            height: 76,
            width: double.infinity,
          )
              : Image.asset(
            logoAsset,
            fit: BoxFit.contain,
            height: 76,
            width: double.infinity,
          ),
        )
            : Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ),
    );
  }
}