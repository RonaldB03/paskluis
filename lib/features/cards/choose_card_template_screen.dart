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
          initialLogoLayout: brand == null
              ? const {}
              : logoLayoutCardFields(brand),
        ),
      ),
    );

    if (!mounted || result == null) return;

    Navigator.pop(context, {...result, 'openPreviewAfterSave': 'true'});
  }

  Future<void> scanForBrand(CardBrandTemplate brand) async {
    final mode = await showCodeTypeDialog(context);
    if (!mounted || mode == null) return;

    final result = await Navigator.push<ScannerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
          mode: mode,
          showManualAfterDelay: true,
          detailedResult: true,
        ),
      ),
    );

    if (!mounted || result == null || result.code.trim().isEmpty) return;

    final now = DateTime.now().toIso8601String();

    Navigator.pop(context, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'Pasje',
      'name': brand.name,
      'code': result.code.trim(),
      'codeFormat': result.codeFormat,
      'note': '',
      'cardNumber': '',
      'pinCode': '',
      'initialBalance': '',
      'currentBalance': '',
      'brandId': brand.id,
      'logoAsset': brand.logoAsset,
      'brandColor': brand.color.value.toString(),
      ...logoLayoutCardFields(brand),
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
    final query = searchQuery.trim().toLowerCase();
    final availableBrands = brands
        .where(
          (brand) => brand.supportedTypes.contains(
            widget.type == 'Cadeaukaart' ? 'Cadeaukaart' : 'Pasje',
          ),
        )
        .toList()
      ..sort(
        (first, second) => first.name.toLowerCase().compareTo(
          second.name.toLowerCase(),
        ),
      );
    final filteredBrands = availableBrands
        .where(
          (brand) =>
              query.isEmpty ||
              brand.name.toLowerCase().contains(query) ||
              brand.id.toLowerCase().contains(query),
        )
        .toList();
    final popularBrands = availableBrands
        .where((brand) => brand.isFeatured)
        .toList();

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

          if (query.isEmpty && popularBrands.isNotEmpty) ...[
            const Text(
              'Populaire kaarten',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF303036),
              ),
            ),
            const SizedBox(height: 9),
            ...popularBrands.map((brand) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: BrandListTile(
                  brand: brand,
                  onTap: () => scanForBrand(brand),
                ),
              );
            }),
            const SizedBox(height: 14),
          ],

          Text(
            query.isEmpty ? 'Alle winkels' : 'Zoekresultaten',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF303036),
            ),
          ),

          const SizedBox(height: 9),

          ...filteredBrands.map((brand) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: BrandListTile(
                brand: brand,
                onTap: () => scanForBrand(brand),
              ),
            );
          }),

          if (filteredBrands.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  'Geen winkels gevonden.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),

          const SizedBox(height: 6),

          _CustomCardTile(onTap: () => openManualForm()),
        ],
      ),
    );
  }
}

class BrandListTile extends StatelessWidget {
  final CardBrandTemplate brand;
  final VoidCallback onTap;

  const BrandListTile({super.key, required this.brand, required this.onTap});

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
                  scale: brand.logoLayout['pickerScale'] ?? 1,
                  offsetX: brand.logoLayout['pickerX'] ?? 0,
                  offsetY: brand.logoLayout['pickerY'] ?? 0,
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
