import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../shared/widgets/main_bottom_nav.dart';
import '../cards/card_detail_screen.dart';
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
            title: const Text('QR-codes'),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF333333),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFFD51B46), size: 32),
                onPressed: onAdd,
              ),
            ],
          ),
          body: items.isEmpty
              ? const Center(
            child: Text(
              'Nog geen QR-codes toegevoegd',
              style: TextStyle(fontSize: 18),
            ),
          )
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

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CardDetailScreen(item: item),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      item['name']?.toString() ?? 'QR-code',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
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