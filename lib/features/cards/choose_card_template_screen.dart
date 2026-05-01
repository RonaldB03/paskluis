import 'package:flutter/material.dart';

import '../../data/templates/card_templates.dart';
import '../scanner/scanner_screen.dart';
import 'add_card_screen.dart';

class ChooseCardTemplateScreen extends StatefulWidget {
  final String type;

  const ChooseCardTemplateScreen({
    super.key,
    required this.type,
  });

  @override
  State<ChooseCardTemplateScreen> createState() =>
      _ChooseCardTemplateScreenState();
}

class _ChooseCardTemplateScreenState extends State<ChooseCardTemplateScreen> {
  String searchQuery = '';

  String get title {
    switch (widget.type) {
      case 'QR-code':
        return 'QR-code toevoegen';
      case 'Cadeaukaart':
        return 'Cadeaukaart toevoegen';
      default:
        return 'Klantenkaart toevoegen';
    }
  }

  Future<void> openManualForm() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCardScreen(
          initialType: widget.type,
        ),
      ),
    );

    if (!mounted || result == null) return;
    Navigator.pop(context, result);
  }

  Future<void> scanForBrand(CardBrandTemplate brand) async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(),
      ),
    );

    if (!mounted || code == null || code.isEmpty) return;

    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCardScreen(
          initialType: widget.type,
          initialName: brand.name,
          initialCode: code,
          initialBrandId: brand.id,
          initialLogoAsset: brand.logoAsset,
          initialBrandColor: brand.color.value.toString(),
        ),
      ),
    );

    if (!mounted || result == null) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final filteredBrands = cardBrandTemplates.where((brand) {
      return brand.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          TextField(
            onChanged: (value) {
              setState(() => searchQuery = value);
            },
            decoration: InputDecoration(
              hintText: 'Zoek winkel of merk',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 24),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredBrands.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.65,
            ),
            itemBuilder: (context, index) {
              final brand = filteredBrands[index];

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => scanForBrand(brand),
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
                      height: 78,
                      width: double.infinity,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: openManualForm,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFF8E3EA),
                    child: Icon(
                      Icons.edit,
                      color: Color(0xFFD51B46),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Staat je kaart er niet tussen? Voeg handmatig toe',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}