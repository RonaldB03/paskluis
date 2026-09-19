import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/smart_card_import_service.dart';
import 'add_gift_card_screen.dart';

class ChooseGiftCardTemplateScreen extends StatefulWidget {
  const ChooseGiftCardTemplateScreen({super.key});

  @override
  State<ChooseGiftCardTemplateScreen> createState() =>
      _ChooseGiftCardTemplateScreenState();
}

class _ChooseGiftCardTemplateScreenState
    extends State<ChooseGiftCardTemplateScreen> {
  Future<void> openCustomGiftCard() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => const AddGiftCardScreen()),
    );

    if (!mounted || result == null) return;
    Navigator.pop(context, result);
  }

  Future<void> startAutomaticImport(ImageSource source) async {
    SmartCardImportResult? scan;
    try {
      scan = await SmartCardImportService.pickAndAnalyze(source: source);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('De foto kon niet worden gelezen. Probeer het opnieuw.')),
        );
      }
      return;
    }
    if (!mounted || scan == null) return;
    final importResult = scan;
    if (importResult.code.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geen code gevonden. Probeer een duidelijkere foto.'),
        ),
      );
      return;
    }

    final brand = importResult.brand;
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddGiftCardScreen(
          initialName: brand == null ? null : '${brand.name} cadeaukaart',
          initialCode: importResult.code.trim(),
          initialCodeFormat: importResult.codeFormat,
          initialPinCode: importResult.pinCode,
          initialCurrentBalance: importResult.balance,
          initialExpiryDate: importResult.expiryDate,
          initialCardNumber: importResult.code.trim(),
          initialBrandId: brand?.id,
          initialLogoAsset: brand?.logoAsset,
          initialBrandColor: brand?.color.value.toString(),
        ),
      ),
    );

    if (!mounted || result == null) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4F6),
        elevation: 0,
        foregroundColor: const Color(0xFF303036),
        centerTitle: true,
        title: const Text(
          'Cadeaukaart toevoegen',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        children: [
          const Icon(
            Icons.document_scanner_rounded,
            size: 72,
            color: Color(0xFFD51B46),
          ),
          const SizedBox(height: 20),
          const Text(
            'Fotografeer de hele cadeaukaart',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF303036),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Zorg dat de code en eventuele pincode duidelijk zichtbaar zijn. PasKluis probeert de winkel, het logo, de kaartcode en de pincode automatisch te herkennen.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.45, color: Colors.black54),
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 58,
            child: FilledButton.icon(
              onPressed: () => startAutomaticImport(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Maak een foto'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD51B46),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => startAutomaticImport(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Kies foto of screenshot'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD51B46),
                side: const BorderSide(color: Color(0xFFD51B46)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: openCustomGiftCard,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Handmatig toevoegen'),
            style: TextButton.styleFrom(foregroundColor: Colors.black54),
          ),
          const SizedBox(height: 22),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: Colors.black38),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Herkenning gebeurt op je toestel; je foto wordt niet geüpload.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
