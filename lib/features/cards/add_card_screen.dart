import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../scanner/scanner_screen.dart';

class AddCardScreen extends StatefulWidget {
  final String initialType;
  final String? initialName;
  final String? initialCode;
  final String? initialBrandId;
  final String? initialLogoAsset;
  final String? initialBrandColor;

  const AddCardScreen({
    super.key,
    this.initialType = 'Pasje',
    this.initialName,
    this.initialCode,
    this.initialBrandId,
    this.initialLogoAsset,
    this.initialBrandColor,
  });

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  late String selectedType;

  final nameController = TextEditingController();
  final codeController = TextEditingController();

  File? customImage;

  bool get isBrandMode =>
      (widget.initialLogoAsset ?? '').isNotEmpty &&
          (widget.initialBrandColor ?? '').isNotEmpty;

  Color get brandColor {
    final parsed = int.tryParse(widget.initialBrandColor ?? '');
    if (parsed != null) return Color(parsed);
    return Colors.white;
  }

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType;
    nameController.text = widget.initialName ?? '';
    codeController.text = widget.initialCode ?? '';
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        customImage = File(image.path);
      });
    }
  }

  Future<void> scanCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
          mode: selectedType == 'QR-code'
              ? ScannerMode.qr
              : ScannerMode.barcode,
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        codeController.text = result;
      });
    }
  }

  void saveCard() {
    if (codeController.text.trim().isEmpty ||
        (!isBrandMode && nameController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vul de verplichte velden in')),
      );
      return;
    }

    Navigator.pop(context, {
      'type': selectedType,
      'name': nameController.text.trim(),
      'code': codeController.text.trim(),
      'logoAsset': widget.initialLogoAsset ?? '',
      'brandColor': widget.initialBrandColor ?? '',
      'customImage': customImage?.path ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF3A3A3C),
        title: const Text(
          'Kaart toevoegen',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          /// 🔷 BRAND OF HANDMATIG
          if (isBrandMode) ...[
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: brandColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Image.asset(
                  widget.initialLogoAsset!,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ] else ...[
            /// NAAM
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Naam',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            /// LOGO UPLOAD
            InkWell(
              onTap: pickImage,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: customImage != null
                    ? Image.file(customImage!, fit: BoxFit.cover)
                    : const Center(
                  child: Text(
                    'Logo toevoegen (optioneel)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          /// CODE
          TextField(
            controller: codeController,
            decoration: InputDecoration(
              labelText: 'Barcode / QR-code',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: scanCode,
              ),
            ),
          ),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: scanCode,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scannen'),
          ),

          const SizedBox(height: 28),

          FilledButton.icon(
            onPressed: saveCard,
            icon: const Icon(Icons.save),
            label: const Text('Opslaan'),
          ),
        ],
      ),
    );
  }
}