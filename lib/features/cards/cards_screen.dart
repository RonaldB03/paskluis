import 'package:flutter/material.dart';

import 'add_card_screen.dart';
import 'card_detail_screen.dart';

class CardsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Function(String id) onDelete;
  final Function(String id) onToggleFavorite;
  final VoidCallback onAdd;

  const CardsScreen({
    super.key,
    required this.items,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onAdd,
  });

  static const defaultCards = [
    _DefaultCard(
      name: 'Albert Heijn',
      logoAsset: 'assets/logos/albert_heijn.png',
      color: Color(0xFF00A6D6),
    ),
    _DefaultCard(
      name: 'Kruidvat',
      logoAsset: 'assets/logos/kruidvat.png',
      color: Color(0xFFE30613),
    ),
    _DefaultCard(
      name: 'Jumbo',
      logoAsset: 'assets/logos/jumbo.png',
      color: Color(0xFFFFC400),
    ),
    _DefaultCard(
      name: 'HEMA',
      logoAsset: 'assets/logos/hema.png',
      color: Color(0xFFE30613),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
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
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
        children: [
          if (items.isEmpty) ...[
            const Text(
              'Nog geen klantenkaarten toegevoegd',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 34,
                height: 1.12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF444446),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Selecteer een winkel of tik op + om direct te scannen',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                height: 1.3,
                color: Color(0xFF555557),
              ),
            ),
            const SizedBox(height: 48),
            _DefaultCardsGrid(),
          ] else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.55,
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
                    padding: const EdgeInsets.all(18),
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
                        item['name']?.toString() ?? 'Kaart',
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
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DefaultCardsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: CardsScreen.defaultCards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.65,
      ),
      itemBuilder: (context, index) {
        final card = CardsScreen.defaultCards[index];

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddCardScreen(
                  initialType: 'Pasje',
                  initialName: card.name,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card.color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Image.asset(
                card.logoAsset,
                fit: BoxFit.contain,
                width: double.infinity,
                height: 76,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DefaultCard {
  final String name;
  final String logoAsset;
  final Color color;

  const _DefaultCard({
    required this.name,
    required this.logoAsset,
    required this.color,
  });
}