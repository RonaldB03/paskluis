import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../data/services/brand_catalog_service.dart';
import '../../data/services/brand_sync_service.dart';
import '../../data/templates/card_templates.dart';
import '../cards/card_view_screen.dart';
import '../cards/cards_screen.dart';
import '../cards/choose_card_template_screen.dart';
import '../gift_cards/add_gift_card_screen.dart';
import '../gift_cards/gift_card_view_screen.dart';
import '../gift_cards/gift_cards_screen.dart';
import '../home/home_screen.dart';

class BrandLogoLayoutScreen extends StatefulWidget {
  const BrandLogoLayoutScreen({super.key});

  @override
  State<BrandLogoLayoutScreen> createState() =>
      _BrandLogoLayoutScreenState();
}

class _BrandLogoLayoutScreenState extends State<BrandLogoLayoutScreen> {
  static const _variants = <_PreviewVariant>[
    _PreviewVariant('home', 'home', 'Home'),
    _PreviewVariant('loyalty', 'loyalty', 'Klantenkaarten'),
    _PreviewVariant('gift', 'gift', 'Cadeaukaarten'),
    _PreviewVariant('loyaltyDetail', 'detail', 'Klantdetail'),
    _PreviewVariant('giftDetail', 'detail', 'Cadeaudetail'),
    _PreviewVariant('giftReview', 'detail', 'Cadeau controleren'),
    _PreviewVariant('loyaltyPicker', 'picker', 'Klant kiezen'),
    _PreviewVariant('giftPicker', 'picker', 'Cadeau kiezen'),
  ];

  List<CardBrandTemplate> _brands = const [];
  CardBrandTemplate? _brand;
  Map<String, double> _layout = {};
  _PreviewVariant _variant = _variants.first;
  bool _loading = true;
  bool _saving = false;

  double get _scale => _layout['${_variant.storage}Scale'] ?? 1;
  double get _x => _layout['${_variant.storage}X'] ?? 0;
  double get _y => _layout['${_variant.storage}Y'] ?? 0;

  List<_PreviewVariant> get _availableVariants => _variants
      .where((variant) => _supportsVariant(_brand, variant))
      .toList();

  bool _supportsVariant(
    CardBrandTemplate? brand,
    _PreviewVariant variant,
  ) {
    if (brand == null || variant.key == 'home') return true;
    if (variant.key.startsWith('loyalty')) {
      return brand.supportedTypes.contains('Pasje');
    }
    if (variant.key.startsWith('gift')) {
      return brand.supportedTypes.contains('Cadeaukaart');
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final brands = await BrandCatalogService.loadForAdmin();
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _selectBrand(brands.isEmpty ? null : brands.first, notify: false);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('De winkels konden niet worden geladen.', error: true);
    }
  }

  void _selectBrand(CardBrandTemplate? brand, {bool notify = true}) {
    _brand = brand;
    if (!_supportsVariant(brand, _variant)) {
      _variant = _variants.first;
    }
    _layout = Map<String, double>.from(brand?.logoLayout ?? const {});
    for (final context in const [
      'home',
      'loyalty',
      'gift',
      'detail',
      'picker',
    ]) {
      _layout.putIfAbsent('${context}Scale', () => 1);
      _layout.putIfAbsent('${context}X', () => 0);
      _layout.putIfAbsent('${context}Y', () => 0);
    }
    if (notify) setState(() {});
  }

  void _setValue(String property, double value) {
    setState(() => _layout['${_variant.storage}$property'] = value);
  }

  void _resetCurrent() {
    setState(() {
      _layout['${_variant.storage}Scale'] = 1;
      _layout['${_variant.storage}X'] = 0;
      _layout['${_variant.storage}Y'] = 0;
    });
  }

  Future<void> _save() async {
    final brand = _brand;
    if (brand == null || _saving) return;
    setState(() => _saving = true);
    try {
      await BrandCatalogService.updateLogoLayout(
        brandSlug: brand.id,
        layout: _layout,
      );
      await BrandSyncService.refreshSavedCards();
      if (!mounted) return;
      final updatedBrand = CardBrandTemplate(
        id: brand.id,
        name: brand.name,
        logoAsset: brand.logoAsset,
        color: brand.color,
        isFeatured: brand.isFeatured,
        logoLayout: Map<String, double>.from(_layout),
        supportedTypes: brand.supportedTypes,
      );
      setState(() {
        final index = _brands.indexWhere((item) => item.id == brand.id);
        if (index >= 0) _brands[index] = updatedBrand;
        _brand = updatedBrand;
      });
      _message('${brand.name} is opgeslagen.');
    } catch (_) {
      if (mounted) {
        _message('Opslaan is niet gelukt. Controleer je verbinding.', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFFB42318) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final variants = _availableVariants;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text('Winkellogo’s afstellen'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF303036),
        actions: [
          TextButton(
            onPressed: _brand == null || _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Opslaan',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _brand == null
          ? const Center(child: Text('Geen winkels gevonden.'))
          : SafeArea(
              child: Column(
                children: [
                  _BrandSelector(
                    brands: _brands,
                    selected: _brand!,
                    onChanged: _selectBrand,
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: variants.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final variant = variants[index];
                        return ChoiceChip(
                          label: Text(variant.label),
                          selected: variant.key == _variant.key,
                          onSelected: (_) => setState(() => _variant = variant),
                          selectedColor: const Color(0xFFD51B46),
                          labelStyle: TextStyle(
                            color: variant.key == _variant.key
                                ? Colors.white
                                : const Color(0xFF303036),
                            fontWeight: FontWeight.w800,
                          ),
                          showCheckmark: false,
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: _ExactAppPreview(
                      variant: _variant.key,
                      brand: _brand!,
                      scale: _scale,
                      offsetX: _x,
                      offsetY: _y,
                    ),
                  ),
                  _Controls(
                    scale: _scale,
                    offsetX: _x,
                    offsetY: _y,
                    onScale: (value) => _setValue('Scale', value),
                    onX: (value) => _setValue('X', value),
                    onY: (value) => _setValue('Y', value),
                    onReset: _resetCurrent,
                  ),
                ],
              ),
            ),
    );
  }
}

class _PreviewVariant {
  final String key;
  final String storage;
  final String label;

  const _PreviewVariant(this.key, this.storage, this.label);
}

class _BrandSelector extends StatelessWidget {
  final List<CardBrandTemplate> brands;
  final CardBrandTemplate selected;
  final ValueChanged<CardBrandTemplate?> onChanged;

  const _BrandSelector({
    required this.brands,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: DropdownButtonFormField<CardBrandTemplate>(
        key: ValueKey(selected),
        initialValue: selected,
        decoration: InputDecoration(
          labelText: 'Winkel',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        items: brands
            .map(
              (brand) => DropdownMenuItem(
                value: brand,
                child: Text(
                  brand.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ExactAppPreview extends StatelessWidget {
  final String variant;
  final CardBrandTemplate brand;
  final double scale;
  final double offsetX;
  final double offsetY;

  const _ExactAppPreview({
    required this.variant,
    required this.brand,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  bool get _usesGiftCard =>
      variant == 'gift' ||
      variant == 'giftDetail' ||
      variant == 'giftReview';

  Map<String, dynamic> _itemForType({required bool giftCard}) => {
    'id': 'admin-logo-preview',
    'brandId': brand.id,
    'name': brand.name,
    'type': giftCard ? 'Cadeaukaart' : 'Pasje',
    'logoAsset': brand.logoAsset,
    'customImage': '',
    'brandColor': brand.color.toARGB32().toString(),
    'code': '6064364296989741156',
    'codeFormat': 'barcode',
    'currentBalance': '50',
    'isFavorite': true,
    for (final context in const [
      'home',
      'loyalty',
      'gift',
      'detail',
      'picker',
    ]) ...{
      'logo${context[0].toUpperCase()}${context.substring(1)}Scale':
          context == _storageContext
          ? scale
          : brand.logoLayout['${context}Scale'] ?? 1,
      'logo${context[0].toUpperCase()}${context.substring(1)}X':
          context == _storageContext
          ? offsetX
          : brand.logoLayout['${context}X'] ?? 0,
      'logo${context[0].toUpperCase()}${context.substring(1)}Y':
          context == _storageContext
          ? offsetY
          : brand.logoLayout['${context}Y'] ?? 0,
    },
  };

  Map<String, dynamic> get item =>
      _itemForType(giftCard: _usesGiftCard);

  String get _storageContext => switch (variant) {
    'loyaltyDetail' || 'giftDetail' || 'giftReview' => 'detail',
    'loyaltyPicker' || 'giftPicker' => 'picker',
    _ => variant,
  };

  CardBrandTemplate get pickerBrand => CardBrandTemplate(
    id: brand.id,
    name: brand.name,
    logoAsset: brand.logoAsset,
    color: brand.color,
    isFeatured: brand.isFeatured,
    logoLayout: {
      ...brand.logoLayout,
      'pickerScale': scale,
      'pickerX': offsetX,
      'pickerY': offsetY,
    },
    supportedTypes: brand.supportedTypes,
  );

  // In the logo editor the picker is a preview for the selected shop, not a
  // second shop selector. Showing other brands here made it look as though the
  // sliders also changed those logos. Keep the exact app layout, but filter the
  // preview to the shop selected at the top of this screen.
  List<CardBrandTemplate> get pickerBrands => [pickerBrand];

  @override
  Widget build(BuildContext context) {
    final usesFullWidth =
        variant == 'loyaltyDetail' ||
        variant == 'giftDetail' ||
        variant == 'giftPicker';
    return ColoredBox(
      color: variant == 'giftDetail'
          ? const Color(0xFFF8F8FA)
          : const Color(0xFFF4F4F6),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          usesFullWidth ? 0 : 16,
          12,
          usesFullWidth ? 0 : 16,
          16,
        ),
        child: switch (variant) {
          'home' => _home(),
          'loyalty' => _loyalty(),
          'gift' => _gift(),
          'loyaltyDetail' => _loyaltyDetail(),
          'giftDetail' => _giftDetail(),
          'giftReview' => _giftReview(),
          'loyaltyPicker' => _loyaltyPicker(),
          _ => _giftPicker(),
        },
      ),
    );
  }

  Widget _home() {
    final primaryIsGift = !brand.supportedTypes.contains('Pasje') &&
        brand.supportedTypes.contains('Cadeaukaart');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _homeSection(title: 'Favorieten', giftCard: primaryIsGift),
        const SizedBox(height: 24),
        _homeSection(title: 'In de buurt', giftCard: primaryIsGift),
        if (brand.supportedTypes.contains('Pasje')) ...[
          const SizedBox(height: 24),
          _homeSection(title: 'Klantenkaarten', giftCard: false),
        ],
        if (brand.supportedTypes.contains('Cadeaukaart')) ...[
          const SizedBox(height: 24),
          _homeSection(title: 'Cadeaukaarten', giftCard: true),
        ],
      ],
    );
  }

  Widget _homeSection({required String title, required bool giftCard}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = ((constraints.maxWidth - 16) / 3)
                  .clamp(80.0, 142.0)
                  .toDouble();
              final height = (width / 1.18).clamp(76.0, 112.0).toDouble();
              return SizedBox(
                height: height,
                child: Row(
                  children: List.generate(3, (index) {
                    return Padding(
                      padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
                      child: SizedBox(
                        width: width,
                        child: HomePreviewCard(
                          item: _itemForType(giftCard: giftCard),
                          title: brand.name,
                          logoAsset: brand.logoAsset,
                          customImage: '',
                          brandColor: brand.color.toARGB32().toString(),
                          balance: giftCard ? '50' : '',
                          type: giftCard ? 'Cadeaukaart' : 'Pasje',
                          onTap: () {},
                          onLongPress: () {},
                        ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ],
      );

  Widget _loyalty() => Row(
    children: [
      Expanded(
        child: AspectRatio(
          aspectRatio: 1.58,
          child: StoredCardTile(
            item: item,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
      const SizedBox(width: 8),
      const Expanded(child: SizedBox()),
    ],
  );

  Widget _gift() => Row(
    children: [
      Expanded(
        child: AspectRatio(
          aspectRatio: 1.42,
          child: GiftCardTile(
            item: item,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
      const SizedBox(width: 8),
      const Expanded(child: SizedBox()),
    ],
  );

  Widget _loyaltyDetail() => Align(
    alignment: Alignment.topCenter,
    child: FractionallySizedBox(
      widthFactor: 0.88,
      child: SizedBox(
        height: 515,
        child: LoyaltyBarcodeCard(
          item: item,
          barcode: Barcode.code128(),
          linkedGiftCards: const [],
          onDetails: () {},
          onOpenGiftCards: () {},
        ),
      ),
    ),
  );

  Widget _giftDetail() => Align(
    alignment: Alignment.topCenter,
    child: FractionallySizedBox(
      widthFactor: 0.84,
      child: SizedBox(
        height: 515,
        child: GiftBarcodeCard(
          item: item,
          barcode: Barcode.code128(),
          onDetails: () {},
          onUsed: () {},
        ),
      ),
    ),
  );

  Widget _giftReview() => GiftCardLivePreview(
    name: '${brand.name} cadeaukaart',
    code: '6064364296989741156',
    formattedCode: '6064 3642 9698 9741 156',
    barcode: Barcode.code128(),
    balance: '50',
    cardColor: brand.color,
    logoAsset: brand.logoAsset,
    customImage: '',
    isQr: false,
    logoLayout: {
      ...brand.logoLayout,
      'detailScale': scale,
      'detailX': offsetX,
      'detailY': offsetY,
    },
  );

  Widget _loyaltyPicker() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        readOnly: true,
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
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 9),
      ...pickerBrands
          .where((item) => item.supportedTypes.contains('Pasje'))
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: BrandListTile(brand: item, onTap: () {}),
            ),
          ),
    ],
  );

  Widget _giftPicker() => Material(
    color: const Color(0xFFF7F6FC),
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    clipBehavior: Clip.antiAlias,
    child: GiftBrandPickerSheet(
      brands: pickerBrands
          .where((item) => item.supportedTypes.contains('Cadeaukaart'))
          .toList(),
      previewOnly: true,
      showInlineHandle: true,
    ),
  );
}

class _Controls extends StatelessWidget {
  final double scale;
  final double offsetX;
  final double offsetY;
  final ValueChanged<double> onScale;
  final ValueChanged<double> onX;
  final ValueChanged<double> onY;
  final VoidCallback onReset;

  const _Controls({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.onScale,
    required this.onX,
    required this.onY,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _slider(
              'Grootte',
              '${(scale * 100).round()}%',
              scale,
              .5,
              2.5,
              onScale,
            ),
            _slider(
              'Links/rechts',
              '${offsetX.round()}%',
              offsetX,
              -100,
              100,
              onX,
            ),
            _slider(
              'Omhoog/omlaag',
              '${offsetY.round()}%',
              offsetY,
              -100,
              100,
              onY,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Herstellen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    String valueLabel,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            valueLabel,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFFD51B46),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
