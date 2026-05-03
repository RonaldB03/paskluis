import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../shared/widgets/main_bottom_nav.dart';
import '../cards/card_view_screen.dart';
import '../cards/cards_screen.dart';
import '../gift_cards/gift_cards_screen.dart';
import '../home/home_screen.dart';

class QrCodesScreen extends StatelessWidget {
  final VoidCallback onAdd;

  const QrCodesScreen({
    super.key,
    required this.onAdd,
  });

  List<Map<String, dynamic>> getItems() {
    return StorageService.cardsBox.values
        .where((item) => item is Map && item['type'] == 'QR-code')
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CardsScreen(onAdd: () {}),
        ),
      );
    } else if (index == 2) {
      return;
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GiftCardsScreen(onAdd: () {}),
        ),
      );
    }
  }

  void openQrView(
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
            title: const Text(
              'QR-codes',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
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
              ? _EmptyQrState(onAdd: onAdd)
              : GridView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final item = items[index];

              return _QrTile(
                item: item,
                onTap: () => openQrView(context, items, index),
              );
            },
          ),
          bottomNavigationBar: MainBottomNav(
            currentIndex: 2,
            onTap: (index) => openTab(context, index),
          ),
        );
      },
    );
  }
}

class _EmptyQrState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyQrState({
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
                Icons.qr_code_2_rounded,
                size: 48,
                color: Color(0xFFD51B46),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Nog geen QR-codes toegevoegd',
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
              'Voeg bijvoorbeeld een ticket, toegangscode, link of andere QR-code toe.',
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
              label: const Text('QR-code toevoegen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _QrTile({
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
    final title = item['name']?.toString() ?? 'QR-code';
    final logoAsset = item['logoAsset']?.toString() ?? '';
    final customImage = item['customImage']?.toString() ?? '';
    final hasLogo = hasAssetLogo || hasCustomLogo;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: hasLogo
            ? Center(
          child: hasCustomLogo
              ? Image.file(
            File(customImage),
            fit: BoxFit.contain,
            height: 82,
            width: double.infinity,
          )
              : Image.asset(
            logoAsset,
            fit: BoxFit.contain,
            height: 82,
            width: double.infinity,
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.qr_code_2_rounded,
              size: 36,
              color: Color(0xFFD51B46),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }
}