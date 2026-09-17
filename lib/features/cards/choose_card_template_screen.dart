import 'package:flutter/material.dart';

import '../../data/templates/card_templates.dart';
import '../../data/services/brand_catalog_service.dart';
import '../../shared/widgets/brand_logo.dart';
import '../scanner/scanner_screen.dart';
import 'add_card_screen.dart';

class ChooseCardTemplateScreen extends StatefulWidget {
  final String type;

  const ChooseCardTemplateScreen({super.key, required this.type});

  @override
  State<ChooseCardTemplateScreen> createState() =>
      _ChooseCardTemplateScreenState();
}

class _ChooseCardTemplateScreenState extends State<ChooseCardTemplateScreen> {
  String searchQuery = '';
  List<CardBrandTemplate> brands = cardBrandTemplates;

  @override
  void initState() {
    super.initState();
    BrandCatalogService.load().then((value) {
      if (mounted) setState(() => brands = value);
    });
  }

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

  Future<void> openManualForm({CardBrandTemplate? brand}) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCardScreen(
          initialType: widget.type,
          initialName: brand?.name,
          initialBrandId: brand?.id,
          initialLogoAsset: brand?.logoAsset,
          initialBrandColor: brand?.color.value.toString(),
        ),
      ),
    );

    if (!mounted || result == null) return;

    Navigator.pop(context, {...result, 'openPreviewAfterSave': 'true'});
  }

  Future<void> scanForBrand(CardBrandTemplate brand) async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(
          mode: ScannerMode.barcode,
          showManualAfterDelay: true,
        ),
      ),
    );

    if (!mounted || code == null || code.trim().isEmpty) return;

    if (code == ScannerScreen.manualEntryResult) {
      await openManualForm(brand: brand);
      return;
    }

    final now = DateTime.now().toIso8601String();

    Navigator.pop(context, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'Pasje',
      'name': brand.name,
      'code': code.trim(),
      'note': '',
      'cardNumber': '',
      'pinCode': '',
      'initialBalance': '',
      'currentBalance': '',
      'brandId': brand.id,
      'logoAsset': brand.logoAsset,
      'brandColor': brand.color.value.toString(),
      'customImage': '',
      'isFavorite': 'false',
      'createdAt': now,
      'updatedAt': now,
      'lastUsedAt': '',
      'openPreviewAfterSave': 'true',
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredBrands = brands.where((brand) {
      if (!brand.supportedTypes.contains(widget.type == 'Cadeaukaart' ? 'Cadeaukaart' : 'Pasje')) return false;
      return brand.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4F6),
        elevation: 0,
        foregroundColor: const Color(0xFF303036),
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: () => openManualForm(),
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
            'Populaire kaarten',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF303036),
            ),
          ),

          const SizedBox(height: 9),

          ...filteredBrands.map((brand) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _BrandListTile(
                brand: brand,
                onTap: () => scanForBrand(brand),
              ),
            );
          }),

          const SizedBox(height: 6),

          _CustomCardTile(onTap: () => openManualForm()),
        ],
      ),
    );
  }
}

class _BrandListTile extends StatelessWidget {
  final CardBrandTemplate brand;
  final VoidCallback onTap;

  const _BrandListTile({required this.brand, required this.onTap});

  double get logoScale {
    final name = brand.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (name.contains('gallgall')) return 1.75;
    if (name.contains('albertheijn')) return 1.15;
    return 1.25;
  }

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
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: brand.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: BrandLogo(
                  source: brand.logoAsset,
                  scale: logoScale,
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

class _CustomCardTile extends StatelessWidget {
  final VoidCallback onTap;

  const _CustomCardTile({required this.onTap});

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
                  'Aangepaste kaart',
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
