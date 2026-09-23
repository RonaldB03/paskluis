import 'package:paskluis_v1/l10n/l10n.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/media_storage_service.dart';
import '../../data/services/image_color_service.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/utils/amount_format.dart';
import '../scanner/scanner_screen.dart';

class EditGiftCardScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const EditGiftCardScreen({super.key, required this.item});

  @override
  State<EditGiftCardScreen> createState() => _EditGiftCardScreenState();
}

class _EditGiftCardScreenState extends State<EditGiftCardScreen> {
  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final noteController = TextEditingController();

  final cardNumberController = TextEditingController();
  final pinCodeController = TextEditingController();
  final initialBalanceController = TextEditingController();
  final currentBalanceController = TextEditingController();

  String logoAsset = '';
  String brandColor = '';
  String customImage = '';
  DateTime? expiryDate;
  bool expiryNotificationsEnabled = true;
  String codeFormat = 'barcode';
  String? barcodeSymbology;

  bool get hasPresetLogo => logoAsset.isNotEmpty;

  bool get hasCustomLogo =>
      customImage.isNotEmpty && File(customImage).existsSync();

  Color get logoBackground {
    final parsed = int.tryParse(brandColor);
    if (parsed != null) return Color(parsed);
    return Colors.white;
  }

  @override
  void initState() {
    super.initState();

    nameController.text = widget.item['name']?.toString() ?? '';
    codeController.text = widget.item['code']?.toString() ?? '';
    noteController.text = widget.item['note']?.toString() ?? '';

    cardNumberController.text = widget.item['cardNumber']?.toString() ?? '';
    pinCodeController.text = widget.item['pinCode']?.toString() ?? '';
    initialBalanceController.text = normalizeAmountValue(
      widget.item['initialBalance']?.toString() ?? '',
    );
    currentBalanceController.text = normalizeAmountValue(
      widget.item['currentBalance']?.toString() ?? '',
    );

    logoAsset = widget.item['logoAsset']?.toString() ?? '';
    brandColor = widget.item['brandColor']?.toString() ?? '';
    customImage = widget.item['customImage']?.toString() ?? '';
    expiryDate = DateTime.tryParse(widget.item['expiryDate']?.toString() ?? '');
    expiryNotificationsEnabled = widget.item['expiryNotificationsEnabled'] == true ||
        widget.item['expiryNotificationsEnabled']?.toString() == 'true';
    codeFormat = widget.item['codeFormat']?.toString() ?? 'barcode';
    barcodeSymbology = widget.item['barcodeSymbology']?.toString();
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    noteController.dispose();
    cardNumberController.dispose();
    pinCodeController.dispose();
    initialBalanceController.dispose();
    currentBalanceController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    try {
      final storedPath = await MediaStorageService.persistImage(image.path);
      final detectedColor = await ImageColorService.dominantEdgeColor(storedPath);
      if (!mounted) return;
      setState(() {
        customImage = storedPath;
        logoAsset = '';
        brandColor = detectedColor?.value.toString() ?? '';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text(L10n.current.theImageCouldNotBeSaved),
        ),
      );
    }
  }

  Future<void> scanCode() async {
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

    if (result == null || result.code.isEmpty) return;

    setState(() {
      codeController.text = result.code;
      codeFormat = result.codeFormat;
      barcodeSymbology = result.barcodeSymbology;
    });
  }

  void save() {
    if (nameController.text.trim().isEmpty ||
        codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(L10n.current.enterAtLeastANameAndBarcode)),
      );
      return;
    }

    final updated = Map<String, dynamic>.from(widget.item);

    updated['type'] = 'Cadeaukaart';
    updated['name'] = nameController.text.trim();
    updated['code'] = codeController.text.trim();
    updated['codeFormat'] = codeFormat;
    updated['barcodeSymbology'] = barcodeSymbology ?? '';
    updated['note'] = noteController.text.trim();

    updated['cardNumber'] = cardNumberController.text.trim();
    updated['pinCode'] = pinCodeController.text.trim();
    updated['initialBalance'] =
        normalizeAmountValue(initialBalanceController.text);
    updated['currentBalance'] =
        normalizeAmountValue(currentBalanceController.text);

    updated['logoAsset'] = logoAsset;
    updated['brandColor'] = brandColor;
    updated['customImage'] = customImage;
    updated['expiryDate'] = expiryDate?.toIso8601String() ?? '';
    updated['expiryNotificationsEnabled'] = expiryNotificationsEnabled;
    updated['updatedAt'] = DateTime.now().toIso8601String();

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title:  Text(L10n.current.editGiftCard),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: save,
            child:  Text(
              L10n.current.save,
              style: TextStyle(
                color: Color(0xFFD51B46),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _LogoPreview(
            logoAsset: logoAsset,
            customImage: customImage,
            backgroundColor: logoBackground,
            onPickImage: pickImage,
            onRemoveImage: () {
              setState(() {
                customImage = '';
                logoAsset = '';
                brandColor = '';
              });
            },
          ),
          const SizedBox(height: 18),
          TextField(
            controller: nameController,
            decoration:  InputDecoration(
              labelText: L10n.current.name,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: codeController,
            decoration: InputDecoration(
              labelText: L10n.current.barcode,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: scanCode,
                icon: const Icon(Icons.qr_code_scanner),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: scanCode,
            icon: const Icon(Icons.qr_code_scanner),
            label:  Text(L10n.current.scanBarcodeAgain),
          ),
          const SizedBox(height: 24),
           Text(
            L10n.current.giftCardDetails,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cardNumberController,
            decoration:  InputDecoration(
              labelText: L10n.current.cardNumber,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: pinCodeController,
            obscureText: true,
            decoration:  InputDecoration(
              labelText: L10n.current.pinScratchCode,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: initialBalanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:  InputDecoration(
              labelText: L10n.current.originalBalance,
              prefixText: '€ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: currentBalanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:  InputDecoration(
              labelText: L10n.current.currentBalance,
              prefixText: '€ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration:  InputDecoration(
              labelText: L10n.current.note,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_rounded, color: Color(0xFFD51B46)),
            title: Text(
              expiryDate == null
                  ? L10n.current.addExpiryDate
                  : '${expiryDate!.day.toString().padLeft(2, '0')}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.year}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: expiryDate ?? now.add(const Duration(days: 365)),
                firstDate: DateTime(2000),
                lastDate: DateTime(now.year + 20),
              );
              if (picked != null && mounted) setState(() => expiryDate = picked);
            },
          ),
          if (expiryDate != null)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: expiryNotificationsEnabled,
              title:  Text(L10n.current.expiryDateReminders),
              subtitle:  Text(L10n.current.text30Days7DaysAndOnThe374),
              onChanged: (value) => setState(() => expiryNotificationsEnabled = value),
            ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save),
            label:  Text(L10n.current.save),
          ),
        ],
      ),
    );
  }
}

class _LogoPreview extends StatelessWidget {
  final String logoAsset;
  final String customImage;
  final Color backgroundColor;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;

  const _LogoPreview({
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
    L10n.watch(context);
    final hasLogo = hasPresetLogo || hasCustomLogo;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasPresetLogo ? backgroundColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 110,
            child: Center(
              child: hasCustomLogo
                  ? Image.file(
                      File(customImage),
                      fit: BoxFit.contain,
                      height: 90,
                      width: double.infinity,
                    )
                  : hasPresetLogo
                  ? SizedBox(
                      height: 90,
                      width: double.infinity,
                      child: BrandLogo(source: logoAsset),
                    )
                  : const Icon(
                      Icons.image_outlined,
                      size: 56,
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
                  icon: const Icon(Icons.photo_library),
                  label: Text(hasLogo ? L10n.current.changeLogo : L10n.current.addLogo),
                ),
              ),
              if (hasLogo) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: onRemoveImage,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
