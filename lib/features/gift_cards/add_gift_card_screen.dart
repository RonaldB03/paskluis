import 'dart:io';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/services/media_storage_service.dart';
import '../../data/services/image_color_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/smart_card_import_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/brand_catalog_service.dart';
import '../../data/templates/card_templates.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/utils/amount_format.dart';
import '../scanner/scanner_screen.dart';

class AddGiftCardScreen extends StatefulWidget {
  final bool isEditing;
  final String? initialName;
  final String? initialCode;
  final String? initialCardNumber;
  final String? initialPinCode;
  final String? initialInitialBalance;
  final String? initialCurrentBalance;
  final String? initialNote;
  final String? initialBrandId;
  final String? initialLogoAsset;
  final String? initialBrandColor;
  final String? initialCustomImage;
  final String? initialExpiryDate;
  final bool initialExpiryNotificationsEnabled;
  final String? initialCodeFormat;
  final Map<String, double> initialLogoLayout;

  const AddGiftCardScreen({
    super.key,
    this.isEditing = false,
    this.initialName,
    this.initialCode,
    this.initialCardNumber,
    this.initialPinCode,
    this.initialInitialBalance,
    this.initialCurrentBalance,
    this.initialNote,
    this.initialBrandId,
    this.initialLogoAsset,
    this.initialBrandColor,
    this.initialCustomImage,
    this.initialExpiryDate,
    this.initialExpiryNotificationsEnabled = true,
    this.initialCodeFormat,
    this.initialLogoLayout = const {},
  });

  @override
  State<AddGiftCardScreen> createState() => _AddGiftCardScreenState();
}

class _AddGiftCardScreenState extends State<AddGiftCardScreen> {
  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final balanceController = TextEditingController();
  final pinCodeController = TextEditingController();
  final noteController = TextEditingController();

  String brandId = '';
  String logoAsset = '';
  String brandColor = '';
  Map<String, double> logoLayout = {};
  String customImage = '';
  DateTime? expiryDate;
  late bool expiryNotificationsEnabled;
  late ScannerMode selectedCodeMode;
  bool customBrandSelected = false;
  bool _saving = false;

  bool get hasAssetLogo => logoAsset.isNotEmpty;

  bool get hasCustomLogo =>
      customImage.isNotEmpty && File(customImage).existsSync();

  Color get cardColor {
    final parsed = int.tryParse(brandColor);
    if (parsed != null) return Color(parsed);
    return const Color(0xFFD51B46);
  }

  Barcode get barcodeType {
    final code = codeController.text.trim();
    final onlyDigits = RegExp(r'^\d+$').hasMatch(code);

    if (onlyDigits && code.length == 13) return Barcode.ean13();
    if (onlyDigits && code.length == 8) return Barcode.ean8();

    return Barcode.code128();
  }

  String get formattedCode {
    final code = codeController.text.trim();

    return code
        .replaceAllMapped(RegExp(r'.{1,4}'), (match) => '${match.group(0)} ')
        .trim();
  }

  @override
  void initState() {
    super.initState();

    nameController.text = widget.initialName ?? '';
    codeController.text = widget.initialCode ?? widget.initialCardNumber ?? '';
    balanceController.text = normalizeAmountValue(
      widget.initialCurrentBalance ?? '',
    );
    pinCodeController.text = widget.initialPinCode ?? '';
    noteController.text = widget.initialNote ?? '';

    brandId = widget.initialBrandId ?? '';
    logoAsset = widget.initialLogoAsset ?? '';
    brandColor = widget.initialBrandColor ?? '';
    logoLayout = Map<String, double>.from(widget.initialLogoLayout);
    customImage = widget.initialCustomImage ?? '';
    expiryDate = DateTime.tryParse(widget.initialExpiryDate ?? '');
    expiryNotificationsEnabled = widget.initialExpiryNotificationsEnabled;
    selectedCodeMode = switch (widget.initialCodeFormat) {
      'qr' => ScannerMode.qr,
      'barcode' => ScannerMode.barcode,
      _ => ScannerMode.auto,
    };
    customBrandSelected = brandId.isEmpty &&
        (widget.isEditing || nameController.text.trim().isNotEmpty);

    nameController.addListener(refresh);
    codeController.addListener(refresh);
    balanceController.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    balanceController.dispose();
    pinCodeController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> scanCode() async {
    HapticFeedback.selectionClick();

    final result = await Navigator.push<ScannerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
          mode: selectedCodeMode,
          showManualAfterDelay: true,
          detailedResult: true,
        ),
      ),
    );

    if (!mounted || result == null || result.code.trim().isEmpty) return;

    setState(() {
      codeController.text = result.code.trim();
      selectedCodeMode = result.codeFormat == 'qr'
          ? ScannerMode.qr
          : ScannerMode.barcode;
    });
  }

  Future<void> importGiftCardPhoto(ImageSource source) async {
    HapticFeedback.selectionClick();

    try {
      final result = await SmartCardImportService.pickAndAnalyze(source: source);
      if (!mounted) return;
      if (result == null) return;
      if (result.code.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geen barcode of QR-code gevonden in deze foto.'),
          ),
        );
        return;
      }
      setState(() {
        codeController.text = result.code;
        if (result.pinCode.isNotEmpty) pinCodeController.text = result.pinCode;
        if (result.balance.isNotEmpty) {
          balanceController.text = normalizeAmountValue(result.balance);
        }
        if (result.expiryDate.isNotEmpty) {
          expiryDate = DateTime.tryParse(result.expiryDate);
        }
        if (nameController.text.trim().isEmpty && result.name.isNotEmpty) {
          nameController.text = result.name;
        }
        if (result.brand != null && brandId.isEmpty) {
          brandId = result.brand!.id;
          logoAsset = result.brand!.logoAsset;
          brandColor = result.brand!.color.value.toString();
          logoLayout = result.brand!.logoLayout;
          customBrandSelected = false;
        }
        selectedCodeMode = result.codeFormat == 'qr'
            ? ScannerMode.qr
            : ScannerMode.barcode;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.pinCode.isEmpty
                ? 'Code gevonden. Controleer de gegevens voor opslaan.'
                : 'Code en pincode gevonden. Controleer ze voor opslaan.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('De afbeelding kon niet worden gelezen.')),
      );
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    try {
      final storedPath = await MediaStorageService.persistImage(image.path);
      final detectedColor = await ImageColorService.dominantEdgeColor(storedPath);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        customImage = storedPath;
        logoAsset = '';
        brandColor = detectedColor?.value.toString() ?? '';
        brandId = '';
        customBrandSelected = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('De afbeelding kon niet worden opgeslagen.'),
        ),
      );
    }
  }

  Future<void> chooseBrand() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    final catalog = await BrandCatalogService.load();
    if (!mounted) return;
    final brands = catalog
        .where((brand) => brand.supportedTypes.contains('Cadeaukaart'))
        .toList();
    final selected = await showModalBottomSheet<CardBrandTemplate>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      // Open the picker without focusing the search field. The keyboard should
      // only appear after the user explicitly starts searching.
      requestFocus: false,
      builder: (context) => GiftBrandPickerSheet(brands: brands),
    );
    if (selected == null || !mounted) return;
    setState(() {
      brandId = selected.id;
      logoAsset = selected.logoAsset;
      brandColor = selected.color.toARGB32().toString();
      logoLayout = selected.logoLayout;
      customImage = '';
      customBrandSelected = false;
      nameController.text = '${selected.name} cadeaukaart';
    });
  }

  void removeLogo() {
    HapticFeedback.selectionClick();
    setState(() {
      customImage = '';
      logoAsset = '';
      brandColor = '';
      logoLayout = {};
      brandId = '';
    });
  }

  String normalizeAmount(String value) {
    return normalizeAmountValue(value);
  }

  String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  Future<void> pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: expiryDate ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 20),
      helpText: 'Kies de vervaldatum',
    );
    if (picked != null && mounted) setState(() => expiryDate = picked);
  }

  Future<void> saveGiftCard() async {
    if (_saving) return;
    final name = nameController.text.trim();
    final code = codeController.text.trim();
    final balance = normalizeAmount(balanceController.text);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Naam is verplicht.')));
      return;
    }

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barcode / kaartnummer is verplicht.')),
      );
      return;
    }

    final now = DateTime.now().toIso8601String();

    final result = <String, String>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'Cadeaukaart',
      'name': name,
      'code': code,
      'codeFormat': selectedCodeMode == ScannerMode.qr ? 'qr' : 'barcode',
      'cardNumber': code,
      'pinCode': pinCodeController.text.trim(),
      'initialBalance': balance,
      'currentBalance': balance,
      'note': noteController.text.trim(),
      'brandId': brandId,
      'logoAsset': logoAsset,
      'brandColor': brandColor,
      for (final entry in logoLayout.entries)
        'logo${entry.key[0].toUpperCase()}${entry.key.substring(1)}':
            entry.value.toString(),
      'customImage': customImage,
      'isFavorite': 'false',
      'createdAt': now,
      'updatedAt': now,
      'lastUsedAt': '',
      'balanceHistory': '[]',
      'expiryDate': expiryDate?.toIso8601String() ?? '',
      'expiryNotificationsEnabled': expiryNotificationsEnabled.toString(),
      'isArchived': 'false',
    };

    if (!widget.isEditing) {
      setState(() => _saving = true);
      try {
        await StorageService.addCard(result);
        result['persisted'] = 'true';
        try {
          await NotificationService.syncGiftCard(result);
        } catch (_) {
          // The card is already safely stored. A notification problem must
          // never make saving the card appear to have failed.
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Opslaan is niet gelukt. Probeer het nog een keer.',
            ),
          ),
        );
        setState(() => _saving = false);
        return;
      }
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final name = nameController.text.trim().isEmpty
        ? 'Cadeaukaart'
        : nameController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Cadeaukaart bewerken' : 'Cadeaukaart afronden',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF4F4F6),
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : saveGiftCard,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Opslaan',
                    style: TextStyle(
                      color: Color(0xFFD51B46),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
        children: [
          if (brandId.isEmpty && logoAsset.isEmpty && !customBrandSelected) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3F6),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFD51B46).withOpacity(0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welke winkel hoort bij deze cadeaukaart?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    codeController.text.trim().isEmpty
                        ? 'Kies een bestaande winkel of maak een eigen cadeaukaart.'
                        : 'De kaartcode is gevonden, maar de winkel nog niet.',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: chooseBrand,
                    icon: const Icon(Icons.storefront_rounded),
                    label: const Text('Kies een winkel'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      customBrandSelected = true;
                      if (nameController.text.trim().isEmpty) {
                        nameController.text = 'Eigen cadeaukaart';
                      }
                    }),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Eigen cadeaukaart'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else if (brandId.isNotEmpty || customBrandSelected) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  if (logoAsset.isNotEmpty)
                    SizedBox(width: 58, height: 38, child: BrandLogo(source: logoAsset))
                  else
                    const Icon(Icons.card_giftcard_rounded, color: Color(0xFFD51B46)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      customBrandSelected ? 'Eigen cadeaukaart' : name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(onPressed: chooseBrand, child: const Text('Wijzigen')),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          GiftCardLivePreview(
            name: name,
            code: codeController.text.trim(),
            formattedCode: formattedCode,
            barcode: barcodeType,
            balance: balanceController.text.trim(),
            cardColor: cardColor,
            logoAsset: logoAsset,
            customImage: customImage,
            logoLayout: logoLayout,
            isQr: selectedCodeMode == ScannerMode.qr,
          ),

          const SizedBox(height: 16),

          _SectionCard(
            title: 'Wat is het saldo?',
            subtitle: 'Vul het huidige saldo van deze cadeaukaart in.',
            children: [
              _InputField(
                controller: balanceController,
                label: 'Saldo',
                icon: Icons.account_balance_wallet_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 14),
              _InputField(
                controller: pinCodeController,
                label: 'Pincode / krascode (optioneel)',
                icon: Icons.lock_outline_rounded,
                keyboardType: TextInputType.text,
              ),
            ],
          ),

          const SizedBox(height: 14),

          _SectionCard(
            title: 'Geldigheid',
            subtitle: 'Optioneel. PasKluis kan je herinneren voordat de kaart verloopt.',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded, color: Color(0xFFD51B46)),
                title: Text(
                  expiryDate == null ? 'Vervaldatum toevoegen' : formatDate(expiryDate!),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: expiryDate == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : IconButton(
                        tooltip: 'Vervaldatum verwijderen',
                        onPressed: () => setState(() => expiryDate = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                onTap: pickExpiryDate,
              ),
              if (expiryDate != null)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: expiryNotificationsEnabled,
                  activeColor: const Color(0xFFD51B46),
                  title: const Text('Herinneringen', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('30 dagen, 7 dagen en op de vervaldatum'),
                  onChanged: (value) => setState(() => expiryNotificationsEnabled = value),
                ),
            ],
          ),

          const SizedBox(height: 14),

          _SectionCard(
            title: 'Kaart',
            children: [
              _InputField(
                controller: nameController,
                label: 'Naam cadeaukaart',
                icon: Icons.card_giftcard_rounded,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              _InputField(
                controller: codeController,
                label: 'Kaartcode / kaartnummer',
                icon: Icons.qr_code_scanner_rounded,
                keyboardType: TextInputType.text,
                suffix: IconButton(
                  onPressed: scanCode,
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFFD51B46),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: scanCode,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Cadeaukaart opnieuw scannen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD51B46),
                    side: const BorderSide(
                      color: Color(0xFFD51B46),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => importGiftCardPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Foto maken en gegevens uitlezen'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD51B46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => importGiftCardPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text('Foto of screenshot importeren'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD51B46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          _SectionCard(
            title: 'Notitie',
            children: [
              _InputField(
                controller: noteController,
                label: 'Notitie',
                icon: Icons.notes_rounded,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),

          const SizedBox(height: 14),

          _SectionCard(
            title: 'Logo',
            children: [
              _LogoEditor(
                logoAsset: logoAsset,
                customImage: customImage,
                backgroundColor: cardColor,
                onPickImage: pickImage,
                onRemoveImage: removeLogo,
              ),
            ],
          ),

          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              onPressed: _saving ? null : saveGiftCard,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _saving
                    ? 'Opslaan…'
                    : widget.isEditing
                    ? 'Wijzigingen opslaan'
                    : 'Cadeaukaart opslaan',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD51B46),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GiftBrandPickerSheet extends StatefulWidget {
  final List<CardBrandTemplate> brands;
  final double? height;
  final bool previewOnly;
  final bool showInlineHandle;

  const GiftBrandPickerSheet({
    super.key,
    required this.brands,
    this.height,
    this.previewOnly = false,
    this.showInlineHandle = false,
  });

  @override
  State<GiftBrandPickerSheet> createState() =>
      _GiftBrandPickerSheetState();
}

class _GiftBrandPickerSheetState extends State<GiftBrandPickerSheet> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim().toLowerCase();
    final sortedBrands = [...widget.brands]
      ..sort(
        (first, second) => first.name.toLowerCase().compareTo(
          second.name.toLowerCase(),
        ),
      );
    final filteredBrands = sortedBrands.where((brand) {
      if (query.isEmpty) return true;
      return brand.name.toLowerCase().contains(query) ||
          brand.id.toLowerCase().contains(query) ||
          brand.searchTerms.any((term) => term.contains(query));
    }).toList();
    final popularBrands = sortedBrands
        .where((brand) => brand.isFeatured)
        .toList();
    final listedBrands = query.isEmpty
        ? filteredBrands.where((brand) => !brand.isFeatured).toList()
        : filteredBrands;

    return SafeArea(
      child: SizedBox(
        height: widget.height ?? MediaQuery.sizeOf(context).height * 0.86,
        child: Column(
          children: [
            if (widget.showInlineHandle)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF55555D),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Kies de winkel',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                readOnly: widget.previewOnly,
                onChanged: (value) => setState(() => searchQuery = value),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  hintText: 'Zoek winkel',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  if (query.isEmpty && popularBrands.isNotEmpty) ...[
                    _pickerSectionTitle('Populaire kaarten'),
                    ...popularBrands.map(_pickerBrandTile),
                    const SizedBox(height: 12),
                  ],
                  _pickerSectionTitle(
                    query.isEmpty ? 'Alle winkels' : 'Zoekresultaten',
                  ),
                  ...listedBrands.map(_pickerBrandTile),
                  if (listedBrands.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'Geen winkels gevonden.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerSectionTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: Color(0xFF303036),
      ),
    ),
  );

  Widget _pickerBrandTile(CardBrandTemplate brand) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: ListTile(
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: SizedBox(
        width: 62,
        child: BrandLogo(
          source: brand.logoAsset,
          scale: brand.logoLayout['pickerScale'] ?? 1,
          offsetX: brand.logoLayout['pickerX'] ?? 0,
          offsetY: brand.logoLayout['pickerY'] ?? 0,
        ),
      ),
      title: Text(
        brand.name,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: widget.previewOnly
          ? () {}
          : () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context, brand);
            },
    ),
  );
}

class GiftCardLivePreview extends StatelessWidget {
  final String name;
  final String code;
  final String formattedCode;
  final Barcode barcode;
  final String balance;
  final Color cardColor;
  final String logoAsset;
  final String customImage;
  final bool isQr;
  final Map<String, double> logoLayout;

  const GiftCardLivePreview({
    super.key,
    required this.name,
    required this.code,
    required this.formattedCode,
    required this.barcode,
    required this.balance,
    required this.cardColor,
    required this.logoAsset,
    required this.customImage,
    required this.isQr,
    required this.logoLayout,
  });

  bool get hasAssetLogo => logoAsset.isNotEmpty;

  bool get hasCustomLogo =>
      customImage.isNotEmpty && File(customImage).existsSync();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [cardColor, cardColor.withOpacity(0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(
          children: [
            Container(
              height: 108,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
              child: Column(
                children: [
                  Expanded(
                    child: hasCustomLogo
                        ? Image.file(File(customImage), fit: BoxFit.contain)
                        : hasAssetLogo
                        ? BrandLogo(
                            source: logoAsset,
                            scale: logoLayout['detailScale'] ?? 1,
                            offsetX: logoLayout['detailX'] ?? 0,
                            offsetY: logoLayout['detailY'] ?? 0,
                          )
                        : const Icon(
                            Icons.card_giftcard_rounded,
                            color: Colors.white,
                            size: 52,
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: code.isEmpty
                        ? const SizedBox(
                            height: 86,
                            child: Center(
                              child: Text(
                                'Nog geen barcode',
                                style: TextStyle(
                                  color: Colors.black38,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        : isQr
                        ? Center(
                            child: QrImageView(
                              data: code,
                              size: 118,
                              padding: EdgeInsets.zero,
                            ),
                          )
                        : BarcodeWidget(
                            barcode: barcode,
                            data: code,
                            width: double.infinity,
                            height: 86,
                            drawText: false,
                            errorBuilder: (_, __) {
                              return const SizedBox(
                                height: 86,
                                child: Center(
                                  child: Text(
                                    'Barcode kan niet worden weergegeven',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (code.isNotEmpty && !isQr) ...[
                    const SizedBox(height: 12),
                    Text(
                      formattedCode,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F1F24),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8E3EA),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      balance.trim().isEmpty
                          ? 'Saldo onbekend'
                          : '€ ${formatAmountValue(balance)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD51B46),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF2F2F34),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.black.withOpacity(0.52),
                fontSize: 13.5,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Widget? suffix;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.suffix,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: maxLines > 1 ? TextInputAction.newline : textInputAction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF4F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFD51B46), width: 1.4),
        ),
      ),
    );
  }
}

class _LogoEditor extends StatelessWidget {
  final String logoAsset;
  final String customImage;
  final Color backgroundColor;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;

  const _LogoEditor({
    required this.logoAsset,
    required this.customImage,
    required this.backgroundColor,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  bool get hasPresetLogo => logoAsset.isNotEmpty;

  bool get hasCustomLogo =>
      customImage.isNotEmpty && File(customImage).existsSync();

  @override
  Widget build(BuildContext context) {
    final hasLogo = hasPresetLogo || hasCustomLogo;

    return Column(
      children: [
        Container(
          height: 116,
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: hasPresetLogo ? backgroundColor : const Color(0xFFF4F4F6),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: hasCustomLogo
                ? Image.file(File(customImage), fit: BoxFit.contain)
                : hasPresetLogo
                ? BrandLogo(source: logoAsset)
                : const Icon(
                    Icons.image_outlined,
                    size: 52,
                    color: Colors.black38,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickImage,
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(hasLogo ? 'Logo wijzigen' : 'Logo toevoegen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD51B46),
                  side: const BorderSide(color: Color(0xFFD51B46), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (hasLogo) ...[
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                width: 54,
                child: IconButton(
                  onPressed: onRemoveImage,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.08),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
