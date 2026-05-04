import 'package:flutter/material.dart';

import '../../data/templates/card_templates.dart';
import 'add_gift_card_screen.dart';
import 'gift_card_scanner_screen.dart';

class ChooseGiftCardTemplateScreen extends StatefulWidget {
  const ChooseGiftCardTemplateScreen({super.key});

  @override
  State<ChooseGiftCardTemplateScreen> createState() =>
      _ChooseGiftCardTemplateScreenState();
}

class _ChooseGiftCardTemplateScreenState
    extends State<ChooseGiftCardTemplateScreen> {
  String searchQuery = '';

  Future<void> openCustomGiftCard() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddGiftCardScreen(),
      ),
    );

    if (!mounted || result == null) return;
    Navigator.pop(context, result);
  }

  Future<void> scanForBrand(CardBrandTemplate brand) async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const GiftCardScannerScreen(
          showManualAfterDelay: true,
        ),
      ),
    );

    if (!mounted || code == null || code.trim().isEmpty) return;

    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddGiftCardScreen(
          initialName: '${brand.name} cadeaukaart',
          initialCode: code.trim(),
          initialBrandId: brand.id,
          initialLogoAsset: brand.logoAsset,
          initialBrandColor: brand.color.value.toString(),
          initialCardNumber: code.trim(),
        ),
      ),
    );

    if (!mounted || result == null) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final brands = getTemplatesByType('Cadeaukaart').where((brand) {
      return brand.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4F6),
        elevation: 0,
        foregroundColor: const Color(0xFF303036),
        centerTitle: true,
        title: const Text(
          'Cadeaukaart toevoegen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: openCustomGiftCard,
            child: const Text(
              'Handmatig',
              style: TextStyle(
                color: Color(0xFFD51B46),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Zoek winkel',
              hintStyle: const TextStyle(fontSize: 15),
              prefixIcon: const Icon(Icons.search, size: 21),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Populaire cadeaukaarten',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF303036),
            ),
          ),

          const SizedBox(height: 9),

          ...brands.map((brand) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _BrandListTile(
                brand: brand,
                onTap: () => scanForBrand(brand),
              ),
            );
          }),

          const SizedBox(height: 6),

          _CustomGiftCardTile(
            onTap: openCustomGiftCard,
          ),
        ],
      ),
    );
  }
}

class _BrandListTile extends StatelessWidget {
  final CardBrandTemplate brand;
  final VoidCallback onTap;

  const _BrandListTile({
    required this.brand,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0.8,
      shadowColor: Colors.black.withOpacity(0.10),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 82,
                height: 44,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brand.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  brand.logoAsset,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  brand.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF303036),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.black26,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomGiftCardTile extends StatelessWidget {
  final VoidCallback onTap;

  const _CustomGiftCardTile({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0.8,
      shadowColor: Colors.black.withOpacity(0.10),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 82,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 30,
                  color: Color(0xFFD51B46),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Aangepaste cadeaukaart',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF303036),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.black26,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}