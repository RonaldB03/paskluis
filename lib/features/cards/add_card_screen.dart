import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/media_storage_service.dart';
import '../../data/services/image_color_service.dart';
import '../../shared/widgets/brand_logo.dart';
import '../scanner/scanner_screen.dart';

class AddCardScreen extends StatefulWidget {
  final String initialType;
  final String? initialName;
  final String? initialCode;
  final String? initialBrandId;
  final String? initialLogoAsset;
  final String? initialBrandColor;
  final Map<String, String> initialLogoLayout;
  final String? initialCodeFormat;

  const AddCardScreen({
    super.key,
    this.initialType = 'Pasje',
    this.initialName,
    this.initialCode,
    this.initialBrandId,
    this.initialLogoAsset,
    this.initialBrandColor,
    this.initialLogoLayout = const {},
    this.initialCodeFormat,
  });

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  late String selectedType;
  late ScannerMode selectedCodeMode;

  final nameController = TextEditingController();
  final codeController = TextEditingController();

  File? customImage;
  String customBrandColor = '';

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
    selectedCodeMode = switch (widget.initialCodeFormat) {
      'qr' => ScannerMode.qr,
      'barcode' => ScannerMode.barcode,
      _ => ScannerMode.auto,
    };
    nameController.text = widget.initialName ?? '';
    codeController.text = widget.initialCode ?? '';
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    try {
      final storedPath = await MediaStorageService.persistImage(image.path);
      final detectedColor = await ImageColorService.dominantEdgeColor(storedPath);
      if (!mounted) return;
      setState(() {
        customImage = File(storedPath);
        customBrandColor = detectedColor?.value.toString() ?? '';
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

  Future<void> scanCode() async {
    FocusManager.instance.primaryFocus?.unfocus();

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

    if (result == null || result.code.isEmpty) return;

    setState(() {
      codeController.text = result.code;
      selectedCodeMode = result.codeFormat == 'qr'
          ? ScannerMode.qr
          : ScannerMode.barcode;
    });
  }

  void saveCard() {
    FocusManager.instance.primaryFocus?.unfocus();

    if (codeController.text.trim().isEmpty ||
        (!isBrandMode && nameController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vul de verplichte velden in.')),
      );
      return;
    }

    Navigator.pop(context, {
      'type': selectedType,
      'name': nameController.text.trim(),
      'code': codeController.text.trim(),
      'codeFormat': selectedCodeMode == ScannerMode.qr ? 'qr' : 'barcode',
      'note': '',
      'cardNumber': '',
      'pinCode': '',
      'initialBalance': '',
      'currentBalance': '',
      'brandId': widget.initialBrandId ?? '',
      'logoAsset': widget.initialLogoAsset ?? '',
      'brandColor': customImage != null
          ? customBrandColor
          : widget.initialBrandColor ?? '',
      ...widget.initialLogoLayout,
      'customImage': customImage?.path ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = selectedType == 'QR-code'
        ? 'QR-code toevoegen'
        : selectedType == 'Cadeaukaart'
        ? 'Cadeaukaart toevoegen'
        : 'Klantenkaart toevoegen';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF3A3A3C),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (isBrandMode) ...[
            Container(
              height: 120,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: brandColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: BrandLogo(
                      source: widget.initialLogoAsset!,
                      scale: double.tryParse(
                            widget.initialLogoLayout['logoPickerScale'] ?? '',
                          ) ??
                          1,
                      offsetX: double.tryParse(
                            widget.initialLogoLayout['logoPickerX'] ?? '',
                          ) ??
                          0,
                      offsetY: double.tryParse(
                            widget.initialLogoLayout['logoPickerY'] ?? '',
                          ) ??
                          0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    nameController.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Naam',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: pickImage,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 110,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: customImage != null
                    ? Image.file(
                        customImage!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      )
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
          DropdownButtonFormField<ScannerMode>(
            value: selectedCodeMode,
            decoration: const InputDecoration(
              labelText: 'Type code',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: ScannerMode.auto, child: Text('Automatisch herkennen')),
              DropdownMenuItem(value: ScannerMode.barcode, child: Text('Streepjescode')),
              DropdownMenuItem(value: ScannerMode.qr, child: Text('QR-code')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => selectedCodeMode = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: codeController,
            decoration: InputDecoration(
              labelText: 'Code',
              hintText: 'Scan of vul handmatig in',
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
            label: Text(
              'Code scannen',
            ),
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
