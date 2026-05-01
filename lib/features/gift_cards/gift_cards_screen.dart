import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../shared/widgets/main_bottom_nav.dart';
import '../cards/card_detail_screen.dart';
import '../cards/cards_screen.dart';
import '../home/home_screen.dart';
import '../qr_codes/qr_codes_screen.dart';

class GiftCardsScreen extends StatelessWidget {
  final VoidCallback onAdd;

  const GiftCardsScreen({
    super.key,
    required this.onAdd,
  });

  List<Map<String, dynamic>> getItems() {
    return StorageService.cardsBox.values
        .where((item) => item is Map && item['type'] == 'Cadeaukaart')
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QrCodesScreen(onAdd: () {}),
        ),
      );
    } else if (index == 3) {
      return;
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
            title: const Text('Cadeaukaarten'),
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
              'Nog geen cadeaukaarten toegevoegd',
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
                      item['name']?.toString() ?? 'Cadeaukaart',
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
            currentIndex: 3,
            onTap: (index) => openTab(context, index),
          ),
        );
      },
    );
  }
}