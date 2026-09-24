import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/templates/card_templates.dart';
import '../../data/services/brand_catalog_service.dart';
import '../../data/services/smart_card_import_service.dart';
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
  ScannerResult? pendingScan;
  String? pendingSuggestedName;

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
        return L10n.current.addQrCode;
      case 'Cadeaukaart':
        return L10n.current.addGiftCard;
      default:
        return L10n.current.addLoyaltyCard;
    }
  }

  Future<void> openManualForm({
    CardBrandTemplate? brand,
    ScannerResult? scan,
    String? suggestedName,
    String? codeFormat,
  }) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCardScreen(
          initialType: widget.type,
          initialName: brand?.name ?? suggestedName,
          initialCode: scan?.code,
          initialCodeFormat: scan?.codeFormat ?? codeFormat,
          initialBarcodeSymbology: scan?.barcodeSymbology,
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
    final readyScan = pendingScan;
    if (readyScan != null) {
      await _saveScannedBrand(brand, readyScan);
      return;
    }

    var manualEntry = false;
    final mode = await showCodeTypeDialog(
      context,
      onManualEntry: () => manualEntry = true,
    );
    if (!mounted) return;
    if (manualEntry) {
      await openManualForm(brand: brand, codeFormat: 'barcode');
      return;
    }
    if (mode == null) return;

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

    await _saveScannedBrand(brand, result);
  }

  Future<void> _saveScannedBrand(
    CardBrandTemplate brand,
    ScannerResult result,
  ) async {
    if (!mounted || result.code.trim().isEmpty) return;

    final now = DateTime.now().toIso8601String();

    Navigator.pop(context, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'Pasje',
      'name': brand.name,
      'code': result.code.trim(),
      'codeFormat': result.codeFormat,
      'barcodeSymbology': result.barcodeSymbology ?? '',
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

  Future<void> scanQuickCard() async {
    final result = await Navigator.push<ScannerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(
          mode: ScannerMode.auto,
          showManualAfterDelay: true,
          detailedResult: true,
        ),
      ),
    );
    if (!mounted || result == null || result.code.trim().isEmpty) return;
    setState(() {
      pendingScan = result;
      pendingSuggestedName = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text(L10n.current.codeDetectedNowChooseTheStore)),
    );
  }

  Future<void> importCardImage() async {
    SmartCardImportResult? imported;
    try {
      imported = await SmartCardImportService.pickAndAnalyze(
        source: ImageSource.gallery,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(L10n.current.theImageCouldNotBeRead)),
        );
      }
      return;
    }
    if (!mounted || imported == null) return;
    if (imported.code.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(L10n.current.noCardCodeFoundInThisImage)),
      );
      return;
    }

    final scan = ScannerResult(
      code: imported.code.trim(),
      codeFormat: imported.codeFormat,
      barcodeSymbology: imported.barcodeSymbology,
    );
    final brand = imported.brand;
    if (brand != null && brand.supportedTypes.contains('Pasje')) {
      final useDetectedBrand = await _confirmDetectedBrand(brand);
      if (!mounted || useDetectedBrand == null) return;
      if (useDetectedBrand) {
        await openManualForm(brand: brand, scan: scan);
        return;
      }
      setState(() {
        pendingScan = scan;
        pendingSuggestedName = imported?.name;
        searchQuery = '';
      });
      return;
    }

    setState(() {
      pendingScan = scan;
      pendingSuggestedName = imported?.name;
      searchQuery = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
        content: Text(
          L10n.current.weCouldNotIdentifyTheStoreChoose,
        ),
      ),
    );
  }

  Future<bool?> _confirmDetectedBrand(CardBrandTemplate brand) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:  Text(L10n.current.storeRecognised, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: 92,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: brand.color,
                borderRadius: BorderRadius.circular(18),
              ),
              child: BrandLogo(
                source: brand.logoAsset,
                scale: brand.logoLayout['pickerScale'] ?? 1,
                offsetX: brand.logoLayout['pickerX'] ?? 0,
                offsetY: brand.logoLayout['pickerY'] ?? 0,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              L10n.current.weRecogniseThisLoyaltyCardAsIs((brand.name).toString()),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.35),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child:  Text(L10n.current.differentStore),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(L10n.current.use((brand.name).toString())),
          ),
        ],
      ),
    );
  }

  String _usableSuggestedName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty ||
        name.toLowerCase() == 'klantenkaart' ||
        name.toLowerCase() == 'pasje') {
      return L10n.current.myLoyaltyCard;
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
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
              brand.id.toLowerCase().contains(query) ||
              brand.searchTerms.any((term) => term.contains(query)),
        )
        .toList();
    final popularBrands = availableBrands
        .where((brand) => brand.isFeatured)
        .toList();
    final listedBrands = query.isEmpty
        ? filteredBrands.where((brand) => !brand.isFeatured).toList()
        : filteredBrands;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4F6),
        elevation: 0,
        foregroundColor: const Color(0xFF303036),
        centerTitle: true,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            maxLines: 1,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => openManualForm(),
            child:  Text(
              L10n.current.manual,
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
          if (widget.type == 'Pasje') ...[
            if (pendingScan != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE7ED),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x33D51B46)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFFD51B46)),
                    const SizedBox(width: 10),
                     Expanded(
                      child: Text(
                        L10n.current.codeDetectedChooseTheStoreBelow,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: L10n.current.cancel,
                      onPressed: () => setState(() {
                        pendingScan = null;
                        pendingSuggestedName = null;
                      }),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              )
            else ...[
               Text(
                L10n.current.quickAdd,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF303036),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _QuickImportTile(
                      icon: Icons.qr_code_scanner_rounded,
                      title: L10n.current.scanCard,
                      onTap: scanQuickCard,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickImportTile(
                      icon: Icons.photo_library_rounded,
                      title: L10n.current.importPhoto,
                      onTap: importCardImage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ],
          TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: L10n.current.searchStores,
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
             Text(
              L10n.current.popularCards,
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
            query.isEmpty ? L10n.current.allStores : L10n.current.searchResults,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF303036),
            ),
          ),

          const SizedBox(height: 9),

          ...listedBrands.map((brand) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: BrandListTile(
                brand: brand,
                onTap: () => scanForBrand(brand),
              ),
            );
          }),

          if (listedBrands.isEmpty)
             Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  L10n.current.noStoresFound312,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),

          const SizedBox(height: 6),

          _CustomCardTile(
            title: pendingScan == null
                ? L10n.current.customCard
                : L10n.current.addAnotherStoreManually,
            onTap: () => openManualForm(
              scan: pendingScan,
              suggestedName: pendingScan == null
                  ? null
                  : _usableSuggestedName(pendingSuggestedName),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickImportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickImportTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFFFE7ED),
                child: Icon(icon, color: const Color(0xFFD51B46)),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
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
    L10n.watch(context);
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
  final String title;

  const _CustomCardTile({required this.onTap, required this.title});

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
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
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
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
