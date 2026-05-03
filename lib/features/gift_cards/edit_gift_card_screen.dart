import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../scanner/scanner_screen.dart';

class EditGiftCardScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const EditGiftCardScreen({
    super.key,
    required this.item,
  });

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
    initialBalanceController.text =
        widget.item['initialBalance']?.toString() ?? '';
    currentBalanceController.text =
        widget.item['currentBalance']?.toString() ?? '';

    logoAsset = widget.item['logoAsset']?.toString() ?? '';
    brandColor = widget.item['brandColor']?.toString() ?? '';
    customImage = widget.item['customImage']?.toString() ?? '';
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

    setState(() {
      customImage = image.path;
      logoAsset = '';
      brandColor = '';
    });
  }

  Future<void> scanCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(
          mode: ScannerMode.barcode,
          showManualAfterDelay: true,
        ),
      ),
    );

    if (result == null || result.isEmpty) return;

    setState(() {
      codeController.text = result;
    });
  }

  void save() {
    if (nameController.text.trim().isEmpty ||
        codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vul minimaal een naam en barcode in.')),
      );
      return;
    }

    final updated = Map<String, dynamic>.from(widget.item);

    updated['type'] = 'Cadeaukaart';
    updated['name'] = nameController.text.trim();
    updated['code'] = codeController.text.trim();
    updated['note'] = noteController.text.trim();

    updated['cardNumber'] = cardNumberController.text.trim();
    updated['pinCode'] = pinCodeController.text.trim();
    updated['initialBalance'] = initialBalanceController.text.trim();
    updated['currentBalance'] = currentBalanceController.text.trim();

    updated['logoAsset'] = logoAsset;
    updated['brandColor'] = brandColor;
    updated['customImage'] = customImage;
    updated['updatedAt'] = DateTime.now().toIso8601String();

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text('Cadeaukaart bewerken'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: save,
            child: const Text(
              'Opslaan',
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
            decoration: const InputDecoration(
              labelText: 'Naam',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: codeController,
            decoration: InputDecoration(
              labelText: 'Barcode',
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
            label: const Text('Barcode opnieuw scannen'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Cadeaukaartgegevens',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cardNumberController,
            decoration: const InputDecoration(
              labelText: 'Kaartnummer',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: pinCodeController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Pincode / krascode',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: initialBalanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Oorspronkelijk saldo',
              prefixText: '€ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: currentBalanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Huidig saldo',
              prefixText: '€ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notitie',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save),
            label: const Text('Opslaan'),
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
                  ? Image.asset(
                logoAsset,
                fit: BoxFit.contain,
                height: 90,
                width: double.infinity,
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
                  label: Text(hasLogo ? 'Logo wijzigen' : 'Logo toevoegen'),
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