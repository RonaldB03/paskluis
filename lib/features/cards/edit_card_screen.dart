import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../scanner/scanner_screen.dart';

class EditCardScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const EditCardScreen({
    super.key,
    required this.item,
  });

  @override
  State<EditCardScreen> createState() => _EditCardScreenState();
}

class _EditCardScreenState extends State<EditCardScreen> {
  late String selectedType;

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
  bool get hasCustomLogo => customImage.isNotEmpty && File(customImage).existsSync();

  @override
  void initState() {
    super.initState();

    selectedType = widget.item['type']?.toString() ?? 'Pasje';

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

  Color get logoBackground {
    final parsed = int.tryParse(brandColor);
    if (parsed != null) return Color(parsed);
    return Colors.white;
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
        builder: (_) => ScannerScreen(
          mode: selectedType == 'QR-code' ? ScannerMode.qr : ScannerMode.barcode,
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
        const SnackBar(content: Text('Vul minimaal een naam en code in.')),
      );
      return;
    }

    final updated = Map<String, dynamic>.from(widget.item);

    updated['type'] = selectedType;
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
    final isGiftCard = selectedType == 'Cadeaukaart';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text('Kaart bewerken'),
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
          SegmentedButton<String>(
            selected: {selectedType},
            segments: const [
              ButtonSegment(
                value: 'Pasje',
                label: Text('Pasje'),
                icon: Icon(Icons.card_membership),
              ),
              ButtonSegment(
                value: 'QR-code',
                label: Text('QR'),
                icon: Icon(Icons.qr_code),
              ),
              ButtonSegment(
                value: 'Cadeaukaart',
                label: Text('Cadeau'),
                icon: Icon(Icons.card_giftcard),
              ),
            ],
            onSelectionChanged: (value) {
              setState(() => selectedType = value.first);
            },
          ),

          const SizedBox(height: 22),

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
              labelText: 'Barcode / QR-code',
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
            label: const Text('Opnieuw scannen'),
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

          if (isGiftCard) ...[
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
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Oorspronkelijk bedrag',
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: currentBalanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Resterend saldo',
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],

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